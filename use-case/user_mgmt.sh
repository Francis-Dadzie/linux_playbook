#!/usr/bin/env bash
# Manages Linux user accounts: add, remove, lock, unlock, list, and status.
# Must be run as root (sudo).
#
# Usage: sudo ./user_mgmt.sh <command> [username] [options]
#
# Commands:
#   list                                    — list non-system users
#   add <username> [group] [expiry-date]    — create user, optionally add to group and set expiry
#   remove <username>                       — delete user and their home directory (with confirmation)
#   lock <username>                         — prevent the user from logging in
#   unlock <username>                       — re-enable login
#   status <username>                       — show account details, groups, and last login
#
# Examples:
#   sudo ./user_mgmt.sh list
#   sudo ./user_mgmt.sh add finn developers
#   sudo ./user_mgmt.sh add dadzie contractors 2025-12-31
#   sudo ./user_mgmt.sh status thabo
#   sudo ./user_mgmt.sh lock chane
#   sudo ./user_mgmt.sh remove Aliecia

set -euo pipefail

# ---------- Colours ----------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ---------- Logging ----------
LOGFILE="/var/log/user_mgmt.log"

log() {
    local level="$1"
    local msg="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] [operator:$(logname 2>/dev/null || echo root)] $msg" >> "$LOGFILE"
}

# ---------- Must run as root ----------
if [[ "$EUID" -ne 0 ]]; then
    error "This script must be run as root. Use: sudo $0"
    exit 1
fi

# Ensure log file exists and is root-owned
touch "$LOGFILE"
chmod 640 "$LOGFILE"

CMD="${1:-list}"

# =====================================================================
# list — show all non-system users (UID >= 1000)
# =====================================================================
if [[ "$CMD" == "list" ]]; then
    printf "%-20s %-6s %-12s %-18s %s\n" "USERNAME" "UID" "STATUS" "EXPIRY" "SHELL"
    printf '%s\n' "$(printf '%.0s-' {1..80})"
    while IFS=: read -r NAME _ USER_UID _ _ HOME SHELL; do
        if [[ "$USER_UID" -ge 1000 ]]; then
            LOCK_RAW=$(passwd -S "$NAME" 2>/dev/null | awk '{print $2}')
            case "$LOCK_RAW" in
                L|LK) STATUS="LOCKED" ;;
                P|PS) STATUS="Active" ;;
                NP)   STATUS="No password" ;;
                *)    STATUS="Unknown" ;;
            esac
            EXPIRY=$(chage -l "$NAME" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
            printf "%-20s %-6s %-12s %-18s %s\n" "$NAME" "$USER_UID" "$STATUS" "${EXPIRY:-never}" "$SHELL"
        fi
    done < /etc/passwd

# =====================================================================
# add — create a user, optionally add to group and set expiry date
# =====================================================================
elif [[ "$CMD" == "add" ]]; then
    USERNAME="${2:-}"
    GROUP="${3:-}"
    EXPIRY="${4:-}"

    if [[ -z "$USERNAME" ]]; then
        error "Usage: $0 add <username> [group] [expiry-date YYYY-MM-DD]"
        exit 1
    fi

    if id "$USERNAME" &>/dev/null; then
        warn "User '$USERNAME' already exists."
        log "WARN" "Attempted to add already-existing user: $USERNAME"
    else
        info "Creating user: $USERNAME"

        if [[ -n "$EXPIRY" ]]; then
            useradd --create-home --shell /bin/bash --expiredate "$EXPIRY" "$USERNAME"
            info "Account expiry set to: $EXPIRY"
        else
            useradd --create-home --shell /bin/bash "$USERNAME"
        fi

        log "INFO" "User created: $USERNAME${EXPIRY:+ (expires: $EXPIRY)}"
        info "User '$USERNAME' created. Setting password now..."
        passwd "$USERNAME"
        log "INFO" "Password set for: $USERNAME"
    fi

    if [[ -n "$GROUP" ]]; then
        if ! getent group "$GROUP" &>/dev/null; then
            info "Group '$GROUP' not found — creating it."
            groupadd "$GROUP"
            log "INFO" "Group created: $GROUP"
        fi
        usermod -aG "$GROUP" "$USERNAME"
        info "Added '$USERNAME' to group '$GROUP'."
        log "INFO" "User $USERNAME added to group: $GROUP"
    fi

# =====================================================================
# remove — delete the user and their home directory
# =====================================================================
elif [[ "$CMD" == "remove" ]]; then
    USERNAME="${2:-}"

    if [[ -z "$USERNAME" ]]; then
        error "Usage: $0 remove <username>"
        exit 1
    fi

    if ! id "$USERNAME" &>/dev/null; then
        warn "User '$USERNAME' does not exist."
        log "WARN" "Attempted to remove non-existent user: $USERNAME"
        exit 0
    fi

    # Refuse to delete system accounts
    UID_VAL=$(id -u "$USERNAME")
    if [[ "$UID_VAL" -lt 1000 ]]; then
        error "Refusing to remove system account '$USERNAME' (UID $UID_VAL)."
        log "WARN" "Refused to remove system account: $USERNAME (UID $UID_VAL)"
        exit 1
    fi

    # Confirmation prompt
    warn "This will permanently delete user '$USERNAME' and their home directory."
    read -rp "Are you sure? [y/N]: " CONFIRM
    if [[ "${CONFIRM,,}" != "y" ]]; then
        info "Aborted. No changes made."
        log "INFO" "Remove aborted by operator for user: $USERNAME"
        exit 0
    fi

    # Kill any active sessions before removing
    if pkill -u "$USERNAME" 2>/dev/null; then
        info "Active sessions for '$USERNAME' terminated."
        log "INFO" "Active sessions terminated for: $USERNAME"
        sleep 1
    fi

    userdel --remove "$USERNAME"
    info "User '$USERNAME' removed."
    log "INFO" "User removed: $USERNAME (UID was $UID_VAL)"

# =====================================================================
# lock / unlock
# =====================================================================
elif [[ "$CMD" == "lock" ]]; then
    USERNAME="${2:-}"
    [[ -z "$USERNAME" ]] && { error "Usage: $0 lock <username>"; exit 1; }

    if ! id "$USERNAME" &>/dev/null; then
        error "User '$USERNAME' does not exist."
        exit 1
    fi

    passwd --lock "$USERNAME"
    info "Account '$USERNAME' locked."
    log "INFO" "Account locked: $USERNAME"

elif [[ "$CMD" == "unlock" ]]; then
    USERNAME="${2:-}"
    [[ -z "$USERNAME" ]] && { error "Usage: $0 unlock <username>"; exit 1; }

    if ! id "$USERNAME" &>/dev/null; then
        error "User '$USERNAME' does not exist."
        exit 1
    fi

    passwd --unlock "$USERNAME"
    info "Account '$USERNAME' unlocked."
    log "INFO" "Account unlocked: $USERNAME"

# =====================================================================
# status — show account details, groups, expiry, and last login
# =====================================================================
elif [[ "$CMD" == "status" ]]; then
    USERNAME="${2:-}"
    [[ -z "$USERNAME" ]] && { error "Usage: $0 status <username>"; exit 1; }

    if ! id "$USERNAME" &>/dev/null; then
        error "User '$USERNAME' does not exist."
        exit 1
    fi

    echo ""
    printf "%-15s %s\n" "Username:"  "$USERNAME"
    printf "%-15s %s\n" "UID:"       "$(id -u "$USERNAME")"
    printf "%-15s %s\n" "Groups:"    "$(id -Gn "$USERNAME" | tr ' ' ',')"
    printf "%-15s %s\n" "Home:"      "$(getent passwd "$USERNAME" | cut -d: -f6)"
    printf "%-15s %s\n" "Shell:"     "$(getent passwd "$USERNAME" | cut -d: -f7)"

    # Lock status
    LOCK_STATUS=$(passwd -S "$USERNAME" 2>/dev/null | awk '{print $2}')
    case "$LOCK_STATUS" in
        L|LK) printf "%-15s %s\n" "Lock status:" "LOCKED" ;;
        P|PS) printf "%-15s %s\n" "Lock status:" "Active" ;;
        NP)   printf "%-15s %s\n" "Lock status:" "No password set" ;;
        *)    printf "%-15s %s\n" "Lock status:" "$LOCK_STATUS" ;;
    esac

    # Expiry date
    EXPIRY=$(chage -l "$USERNAME" 2>/dev/null | grep "Account expires" | cut -d: -f2 | xargs)
    printf "%-15s %s\n" "Expiry:"    "${EXPIRY:-never}"

    # Last login
    LAST=$(last -n 1 -w "$USERNAME" 2>/dev/null | head -n 1)
    if [[ -z "$LAST" || "$LAST" == *"wtmp begins"* ]]; then
        printf "%-15s %s\n" "Last login:" "Never"
    else
        printf "%-15s %s\n" "Last login:" "$LAST"
    fi
    echo ""

else
    error "Unknown command: $CMD"
    echo "Commands: list | add | remove | lock | unlock | status"
    exit 1
fi
