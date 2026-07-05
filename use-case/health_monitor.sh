#!/usr/bin/env bash
# Checks CPU load, memory usage, and disk usage.
# Prints a warning if any metric is above its threshold.
#
# Usage: ./health_monitor.sh [cpu_threshold] [mem_threshold] [disk_threshold]
# Example: ./health_monitor.sh 80 85 90

set -euo pipefail

# ---------- Colours ----------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# ---------- Thresholds (default if not passed as arguments) ----------
CPU_WARN="${1:-80}"
MEM_WARN="${2:-85}"
DISK_WARN="${3:-90}"

ALERTS=0   # We count alerts to summarise at the end

# ---------- Helper: print OK or WARN ----------
check() {
    local LABEL="$1"
    local VALUE="$2"
    local THRESHOLD="$3"

    if [[ "$VALUE" -ge "$THRESHOLD" ]]; then
        echo -e "  ${RED}[WARN]${NC} $LABEL: ${VALUE}% (threshold: ${THRESHOLD}%)"
        (( ALERTS++ )) || true
    else
        echo -e "  ${GREEN}[ OK ]${NC} $LABEL: ${VALUE}%"
    fi
}

echo "==============================="
echo "  System Health Check"
echo "  $(date)"
echo "==============================="

# ---------- CPU ----------
# top -bn1: run top in batch mode for 1 iteration
# We grab the "idle" percentage and subtract from 100
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%,id')
CPU_USED=$(echo "100 - $CPU_IDLE" | bc | cut -d. -f1)
check "CPU used" "$CPU_USED" "$CPU_WARN"

# ---------- Memory ----------
# /proc/meminfo gives us total and available memory in kB
MEM_TOTAL=$(awk '/^MemTotal:/  {print $2}' /proc/meminfo)
MEM_AVAIL=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)
MEM_USED=$(( MEM_TOTAL - MEM_AVAIL ))
MEM_PCT=$(( 100 * MEM_USED / MEM_TOTAL ))
check "Memory used" "$MEM_PCT" "$MEM_WARN"

# ---------- Disk ----------
# df -h shows each mounted partition; we check each one
echo ""
echo "  Disk usage per partition:"
while read -r LINE; do
    USAGE=$(echo "$LINE" | awk '{print $5}' | tr -d '%')
    MOUNT=$(echo "$LINE" | awk '{print $6}')
    check "  Disk $MOUNT" "$USAGE" "$DISK_WARN"
done < <(df -h | awk 'NR > 1 && $1 !~ /^(tmpfs|devtmpfs)$/')

# ---------- Summary ----------
echo ""
if [[ $ALERTS -eq 0 ]]; then
    echo -e "${GREEN}All checks passed.${NC}"
else
    echo -e "${RED}$ALERTS alert(s) triggered.${NC}"
fi
