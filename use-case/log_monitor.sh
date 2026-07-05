#!/usr/bin/env bash
# Monitors /var/log/secure and /var/log/messages for security and system events.
# Alerts via email when event counts exceed defined thresholds.
# Designed to run on a cron schedule (e.g. every 10 minutes).
#
# Usage: sudo ./log_monitor.sh
#
# Cron example (every 10 minutes):
#   */10 * * * * root /path/to/log_monitor.sh
#
# Requires: ~/.curlEmail containing:
#   ADMIN_EMAIL="you@example.com"
#   SMTP_USER="you@example.com"
#   SMTP_PASS="your-app-specific-password"
#   SMTP_SERVER="smtps://smtp.example.com:465"

set -euo pipefail

# ---------- Credentials ----------
CREDENTIALS_FILE="${HOME}/.curlEmail"

if [[ ! -f "$CREDENTIALS_FILE" ]]; then
    echo "Error: Credentials file not found: $CREDENTIALS_FILE"
    echo "Create it with the required variables and run: chmod 600 $CREDENTIALS_FILE"
    exit 1
fi

# shellcheck source=/dev/null
source "$CREDENTIALS_FILE"

for var in ADMIN_EMAIL SMTP_USER SMTP_PASS SMTP_SERVER; do
    if [[ -z "${!var:-}" ]]; then
        echo "Error: $var is not set in $CREDENTIALS_FILE"
        exit 1
    fi
done

# ---------- Configuration ----------
SECURE_LOG="/var/log/secure"
MESSAGES_LOG="/var/log/messages"
LOGFILE="/var/log/log_monitor.log"
WINDOW_MINUTES=10                   # How far back to look on each run

# Alert thresholds — set to 0 to disable an alert
THRESHOLD_FAILED_LOGIN=5            # Failed SSH/auth login attempts
THRESHOLD_SERVICE_CRASH=1           # Service crash/failure events
THRESHOLD_DISK_ERROR=1              # Disk I/O or filesystem errors
THRESHOLD_SUDO_USAGE=10             # Sudo commands executed

# ---------- Must run as root ----------
if [[ "$EUID" -ne 0 ]]; then
    echo "Error: This script must be run as root. Use: sudo $0"
    exit 1
fi

# ---------- Logging ----------
touch "$LOGFILE"
chmod 640 "$LOGFILE"

log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" | tee -a "$LOGFILE"
}

# ---------- Send Email ----------
send_email() {
    local subject="$1"
    local body="$2"

    curl --silent --show-error \
        --url "$SMTP_SERVER" \
        --ssl-reqd \
        --user "$SMTP_USER:$SMTP_PASS" \
        --mail-from "$SMTP_USER" \
        --mail-rcpt "$ADMIN_EMAIL" \
        --upload-file - \
        <<MAIL
From: $SMTP_USER
To: $ADMIN_EMAIL
Subject: $subject

$body
MAIL

    if [[ $? -eq 0 ]]; then
        log "INFO" "Alert email sent to $ADMIN_EMAIL"
    else
        log "WARN" "Failed to send alert email"
    fi
}

# ---------- Scan log for pattern within time window ----------
# Returns the count of matching lines and the matching lines themselves
scan_log() {
    local logfile="$1"
    local pattern="$2"

    if [[ ! -f "$logfile" ]]; then
        echo ""
        return
    fi

    # Build a timestamp to filter lines from the last WINDOW_MINUTES
    local since
    since=$(date --date="-${WINDOW_MINUTES} minutes" '+%b %e %H:%M' 2>/dev/null || \
            date -v-"${WINDOW_MINUTES}"M '+%b %e %H:%M' 2>/dev/null)

    # Use awk to filter lines within the time window then grep for pattern
    awk -v since="$since" '
        $0 >= since { print }
    ' "$logfile" 2>/dev/null | grep -iE "$pattern" || true
}

# ---------- Check and alert ----------
check_and_alert() {
    local label="$1"
    local threshold="$2"
    local matches="$3"

    if [[ "$threshold" -le 0 ]]; then
        return
    fi

    local count
    count=$(echo "$matches" | grep -c . || true)

    log "INFO" "[$label] $count event(s) found in last ${WINDOW_MINUTES} min (threshold: $threshold)"

    if [[ "$count" -ge "$threshold" ]]; then
        log "WARN" "[$label] Threshold exceeded — sending alert"

        send_email "⚠️ Alert: $label on $(hostname) - $(date '+%Y-%m-%d %H:%M')" \
"Log Monitor Alert
=================
Host:       $(hostname)
Event:      $label
Count:      $count in the last ${WINDOW_MINUTES} minutes
Threshold:  $threshold
Timestamp:  $(date)

Matching log entries:
---------------------
$matches

--
This is an automated alert from log_monitor.sh"
    fi
}

# ==========================================================
# Main
# ==========================================================
log "INFO" "=== Log monitor started (window: ${WINDOW_MINUTES} min) ==="

# ---------- Failed logins (/var/log/secure) ----------
FAILED_LOGIN_MATCHES=$(scan_log "$SECURE_LOG" \
    "failed password|authentication failure|invalid user")
check_and_alert "Failed Logins" "$THRESHOLD_FAILED_LOGIN" "$FAILED_LOGIN_MATCHES"

# ---------- Sudo usage (/var/log/secure) ----------
SUDO_MATCHES=$(scan_log "$SECURE_LOG" "sudo:.*COMMAND")
check_and_alert "Sudo Usage" "$THRESHOLD_SUDO_USAGE" "$SUDO_MATCHES"

# ---------- Service crashes (/var/log/messages) ----------
SERVICE_CRASH_MATCHES=$(scan_log "$MESSAGES_LOG" \
    "failed|segfault|core dumped|killed process|out of memory")
check_and_alert "Service Crashes" "$THRESHOLD_SERVICE_CRASH" "$SERVICE_CRASH_MATCHES"

# ---------- Disk errors (/var/log/messages) ----------
DISK_ERROR_MATCHES=$(scan_log "$MESSAGES_LOG" \
    "I/O error|bad sector|disk error|EXT4-fs error|XFS.*error|Buffer I/O error")
check_and_alert "Disk Errors" "$THRESHOLD_DISK_ERROR" "$DISK_ERROR_MATCHES"

log "INFO" "=== Log monitor finished ==="
