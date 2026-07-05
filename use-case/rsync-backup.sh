#!/usr/bin/env bash
# Efficient rsync incremental backup with optional remote support + occasional tar.gz
# Keeps only the last N backups. Logs to file + emails admin on success/failure.
#
# Usage: ./rsync-backup.sh <source_dir> <backup_dir> [keep] [tar_frequency_days]
# Example (local):  ./rsync-backup.sh ~/docs ~/backups 7 7
# Example (remote): ./rsync-backup.sh ~/docs user@server:/backups 10 30
#
# Requires: ~/.curlEmail containing:
#   ADMIN_EMAIL="you@company.com"
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
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# ---------- Arguments ----------
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source_dir> <backup_dir> [keep] [tar_frequency_days]"
    echo "Example (local):  $0 ~/docs ~/backups 7 7"
    echo "Example (remote): $0 ~/docs user@server:/backups 10 30"
    exit 1
fi

SOURCE="$1"
DEST="$2"
KEEP="${3:-7}"
TAR_FREQ="${4:-7}"  # Create .tar.gz every N days (default: 7). Set 0 to disable.

# ---------- Detect remote ----------
if [[ "$DEST" == *@*:* ]]; then
    IS_REMOTE=true
    REMOTE_HOST="${DEST%%:*}"
    REMOTE_PATH="${DEST#*:}"
else
    IS_REMOTE=false
    mkdir -p "$DEST"
fi

# ---------- Setup logging ----------
# For remote backups the log is kept locally under a directory named after the destination
if $IS_REMOTE; then
    LOG_DIR="${HOME}/.backup-logs/$(echo "$DEST" | tr '/:@' '_')"
    mkdir -p "$LOG_DIR"
    LOGFILE="$LOG_DIR/backup.log"
else
    LOGFILE="$DEST/backup.log"
fi

touch "$LOGFILE"

# ---------- Logging ----------
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
Destination: $DEST
Timestamp: $(date)
Log file: $LOGFILE

Please check the log for details."
    fi
' EXIT

# ---------- Validate ----------
if [[ ! -d "$SOURCE" ]]; then
    log "ERROR" "Source directory not found: $SOURCE"
    echo -e "${RED}Error:${NC} Source directory not found: $SOURCE"
    exit 1
fi

log "INFO" "=== Backup started for $SOURCE (Keep: $KEEP, Tar every: ${TAR_FREQ}d) ==="

if $IS_REMOTE; then
    log "INFO" "Remote backup detected: $REMOTE_HOST"
    echo -e "${GREEN}Remote backup detected${NC} -> $REMOTE_HOST"
fi

# ---------- Create timestamped backup ----------
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_NAME="$(basename "$SOURCE")_$TIMESTAMP"

log "INFO" "Creating backup: $SOURCE -> $DEST/$BACKUP_NAME"
echo -e "${GREEN}Creating backup${NC} $SOURCE -> $BACKUP_NAME"

# Find latest previous backup for hard linking
if $IS_REMOTE; then
    LATEST=$(ssh "$REMOTE_HOST" "ls -1dt $REMOTE_PATH/$(basename "$SOURCE")_* 2>/dev/null | head -n 1" || true)
else
    LATEST=$(ls -1dt "$DEST"/$(basename "$SOURCE")_* 2>/dev/null | head -n 1 || true)
fi

if [[ -n "${LATEST:-}" ]]; then
    log "INFO" "Using previous backup for hard links: $(basename "$LATEST")"
    echo "  Using previous backup for hard links: $(basename "$LATEST")"
    LINK_DEST="--link-dest=$LATEST"
else
    log "INFO" "No previous backup found — performing full backup"
    LINK_DEST=""
fi

# Perform the rsync
if $IS_REMOTE; then
    rsync -aAXH --delete --info=progress2 $LINK_DEST "$SOURCE/" "$DEST/$BACKUP_NAME/"
else
    rsync -aAXH --delete --info=progress2 $LINK_DEST "$SOURCE/" "$DEST/$BACKUP_NAME/"
fi

BACKUP_SIZE=$(du -sh "$DEST/$BACKUP_NAME" 2>/dev/null | cut -f1 || echo "unknown")
log "INFO" "Backup completed. Size: $BACKUP_SIZE"
echo -e "${GREEN}Done.${NC} Size: $BACKUP_SIZE"

# ---------- Occasional tar.gz (local only) ----------
ARCHIVE_INFO="N/A (remote or disabled)"

if [[ "$IS_REMOTE" == false && $TAR_FREQ -gt 0 ]]; then
    LAST_TAR=$(ls -1t "$DEST"/$(basename "$SOURCE")_*.tar.gz 2>/dev/null | head -n 1 || true)

    if [[ -z "$LAST_TAR" ]] || [[ $(find "$LAST_TAR" -mtime +"$TAR_FREQ" 2>/dev/null) ]]; then
        log "INFO" "Creating archival .tar.gz (every ${TAR_FREQ} days)..."
        echo -e "${YELLOW}Creating archival .tar.gz (every $TAR_FREQ days)${NC}"
        ARCHIVE="$DEST/$(basename "$SOURCE")_$TIMESTAMP.tar.gz"
        tar -czf "$ARCHIVE" -C "$DEST" "$BACKUP_NAME"
        ARCHIVE_INFO="$(basename "$ARCHIVE") ($(du -sh "$ARCHIVE" | cut -f1))"
        log "INFO" "Archive created: $ARCHIVE_INFO"
        echo "  Archive created: $ARCHIVE_INFO"
    else
        log "INFO" "Skipping tar.gz — last archive is less than ${TAR_FREQ} days old"
        ARCHIVE_INFO="Skipped (last archive < ${TAR_FREQ} days old)"
    fi
fi

# ---------- Rotate old backups ----------
log "INFO" "Rotating backups (keeping $KEEP)..."

if $IS_REMOTE; then
    echo -e "${YELLOW}Rotating remote backups...${NC}"
    ssh "$REMOTE_HOST" "
        BACKUPS=(\$(ls -1dt $REMOTE_PATH/$(basename "$SOURCE")_* 2>/dev/null))
        if [[ \${#BACKUPS[@]} -gt $KEEP ]]; then
            for OLD in \"\${BACKUPS[@]:$KEEP}\"; do
                echo \"  Removing: \$(basename \"\$OLD\")\"
                rm -rf \"\$OLD\"
            done
        fi
    "
else
    mapfile -t BACKUPS < <(ls -1dt "$DEST"/$(basename "$SOURCE")_* 2>/dev/null || true)
    if [[ ${#BACKUPS[@]} -gt $KEEP ]]; then
        for OLD in "${BACKUPS[@]:$KEEP}"; do
            log "INFO" "Removing old backup: $(basename "$OLD")"
            echo "  Removing: $(basename "$OLD")"
            rm -rf "$OLD"
        done
    else
        log "INFO" "No old backups to remove."
    fi
fi

# ---------- Final count ----------
if $IS_REMOTE; then
    KEPT=$(ssh "$REMOTE_HOST" "ls -1d $REMOTE_PATH/$(basename "$SOURCE")_* 2>/dev/null | wc -l")
else
    KEPT=$(ls -1d "$DEST"/$(basename "$SOURCE")_* 2>/dev/null | wc -l)
fi

log "INFO" "Backups kept: $KEPT"
log "INFO" "=== Backup completed successfully ==="

# ---------- Send success email ----------
send_email "Backup Success: $(basename "$SOURCE") - $(date '+%Y-%m-%d')" \
"Backup completed successfully.

Source:        $SOURCE
Destination:   $DEST
Backup name:   $BACKUP_NAME
Size:          $BACKUP_SIZE
Archive:       $ARCHIVE_INFO
Backups kept:  $KEPT / $KEEP
Timestamp:     $(date)
Log file:      $LOGFILE

This is an automated message from the backup cron job."

echo "Backup completed successfully. Log: $LOGFILE"
