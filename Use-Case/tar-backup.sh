#!/usr/bin/env bash
# Backs up a directory to a timestamped .tar.gz archive.
# Keeps only the last N backups. Logs to file + emails admin on success/failure.
#
# Usage: ./tar-backup.sh <source_dir> <backup_dir> [keep]
# Example: ./tar-backup.sh ~/documents ~/backups 5
#
# Requires: ~/.curlEmail containing:
#   ADMIN_EMAIL="admin@company.com"
#   SMTP_USER="you@icloud.com"
#   SMTP_PASS="your-app-specific-password"
#   SMTP_SERVER="smtps://smtp.mail.me.com:465"
#
# Create it with:
#   touch ~/.curlEmail && chmod 600 ~/.curlEmail

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

# ---------- Colours (for terminal only) ----------
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'

# ---------- Logging ----------
LOGFILE=""  # Set after DEST is known

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
        log "INFO" "Email sent to $ADMIN_EMAIL"
    else
        log "WARN" "Failed to send email"
    fi
}

# ---------- Trap for errors ----------
trap '
    EXIT_CODE=$?
    if [[ $EXIT_CODE -ne 0 ]]; then
        log "ERROR" "Backup failed with exit code $EXIT_CODE"
        send_email "Backup FAILED: $(basename "$SOURCE")" \
"Backup FAILED!

Source: $SOURCE
Backup directory: $DEST
Timestamp: $(date)
Log file: $LOGFILE

Please check the log for details."
    fi
' EXIT

# ---------- Arguments ----------
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source_dir> <backup_dir> [keep]"
    exit 1
fi

SOURCE="$1"
DEST="$2"
KEEP="${3:-7}"

# ---------- Setup logging ----------
LOGFILE="$DEST/backup.log"
mkdir -p "$DEST"
touch "$LOGFILE"

log "INFO" "=== Backup started for $SOURCE (Keep: $KEEP) ==="

# ---------- Validate ----------
if [[ ! -d "$SOURCE" ]]; then
    log "ERROR" "Source directory not found: $SOURCE"
    echo -e "${RED}Error:${NC} Source directory not found: $SOURCE"
    exit 1
fi

# ---------- Create archive ----------
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
ARCHIVE="$DEST/$(basename "$SOURCE")_$TIMESTAMP.tar.gz"

log "INFO" "Creating backup: $SOURCE -> $ARCHIVE"
echo -e "${GREEN}Backing up${NC} $SOURCE -> $ARCHIVE"

tar -czf "$ARCHIVE" -C "$(dirname "$SOURCE")" "$(basename "$SOURCE")"

ARCHIVE_SIZE=$(du -sh "$ARCHIVE")
log "INFO" "Backup completed. Size: $ARCHIVE_SIZE"
echo -e "${GREEN}Done.${NC} Size: $ARCHIVE_SIZE"

# ---------- Rotate old backups ----------
log "INFO" "Rotating backups (keeping $KEEP)..."

mapfile -t BACKUPS < <(find "$DEST" -maxdepth 1 -name "$(basename "$SOURCE")_*.tar.gz" \
    -printf '%T@ %p\n' 2>/dev/null | sort -nr | cut -d' ' -f2-)

if [[ ${#BACKUPS[@]} -gt $KEEP ]]; then
    for OLD in "${BACKUPS[@]:$KEEP}"; do
        log "INFO" "Removing old backup: $(basename "$OLD")"
        echo "  Removing: $(basename "$OLD")"
        rm -f "$OLD"
    done
else
    log "INFO" "No old backups to remove."
fi

KEPT=$(ls -1 "$DEST"/$(basename "$SOURCE")_*.tar.gz 2>/dev/null | wc -l)
log "INFO" "Backups kept: $KEPT"

log "INFO" "=== Backup completed successfully ==="

# ---------- Send success email ----------
send_email "Backup Success: $(basename "$SOURCE") - $(date '+%Y-%m-%d')" \
"Backup completed successfully.

Source: $SOURCE
Archive: $(basename "$ARCHIVE")
Size: $ARCHIVE_SIZE
Backups kept: $KEPT / $KEEP
Timestamp: $(date)
Log file: $LOGFILE

This is an automated message from the backup cron job."

echo "Backup completed successfully. Log: $LOGFILE"
