#!/bin/bash

# Colors
BLUE='\033[0;34m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

MAX_TEMP_FILE="$HOME/.monitor_max_temps_7days"
MAX_TEMP_DAYS=7
TEMP_THRESHOLD=55

# Load and clean max temps (keep last 7 days)
load_max_temps() {
  [[ -f $MAX_TEMP_FILE ]] || return
  cutoff=$(date -d "-$MAX_TEMP_DAYS days" +%Y-%m-%d)
  awk -v c=$cutoff '$1 >= c' "$MAX_TEMP_FILE" > "${MAX_TEMP_FILE}.tmp"
  mv "${MAX_TEMP_FILE}.tmp" "$MAX_TEMP_FILE"
}

# Save today's max temps
save_daily_max_temps() {
  today=$(date '+%Y-%m-%d')
  grep -v "^$today " "$MAX_TEMP_FILE" 2>/dev/null > "${MAX_TEMP_FILE}.tmp" || true
  echo "$today $1 $2" >> "${MAX_TEMP_FILE}.tmp"
  mv "${MAX_TEMP_FILE}.tmp" "$MAX_TEMP_FILE"
}

# Get 7-day max for type (CPU/SSD)
get_7day_max() {
  [[ -f $MAX_TEMP_FILE ]] || { echo 0; return; }
  awk -v t=$1 '{v=(t=="CPU")?$2:$3; if(v>max) max=v} END{print max+0}' "$MAX_TEMP_FILE"
}

# Check if temp crossed threshold in last 7 days
temp_crossed_threshold() {
  [[ -f $MAX_TEMP_FILE ]] || { echo 0; return; }
  awk -v t=$1 -v th=$TEMP_THRESHOLD '{v=(t=="CPU")?$2:$3; if(v>th) exit 1} END{print 0}' "$MAX_TEMP_FILE"
}

# Get SSD temp (NVMe) using smartctl -x
get_ssd_temp() {
  temp=$(sudo smartctl -x /dev/sda 2>/dev/null | awk '/Temperature:/ {print $2; exit}')
  if [[ $temp =~ ^[0-9]+$ ]]; then
    echo "$temp"
  else
    echo "N/A"
  fi
}

# Check internet
check_internet() {
  ping -I "$1" -c1 -W1 8.8.8.8 >/dev/null 2>&1 && echo 1 || echo 0
}

while true; do
  clear

  load_max_temps

  DATE_STR=$(date '+%A %d %B %Y %I:%M:%S %p %Z')
  IFACE="eth0"
  IP_ADDR=$(ip -4 -o addr show "$IFACE" | awk '{print $4}' | cut -d/ -f1)
  UPTIME=$(uptime -p)
  CPU_USAGE=$(top -bn1 | awk '/Cpu/{print 100 - $8"%"}')
  MEM_INFO=($(free -m | awk '/^Mem:/{print $3, $2}'))
  CPU_TEMP_RAW=$(vcgencmd measure_temp 2>/dev/null | sed "s/temp=//" | tr -d "'C")
  CPU_TEMP_INT=${CPU_TEMP_RAW%.*}
  SSD_TEMP_RAW=$(get_ssd_temp)
  SSD_TEMP_INT=$([[ $SSD_TEMP_RAW =~ ^[0-9]+$ ]] && echo $SSD_TEMP_RAW || echo 0)

  TODAY=$(date '+%Y-%m-%d')
  read EXISTING_TODAY_CPU EXISTING_TODAY_SSD < <(awk -v d=$TODAY '$1==d {print $2, $3}' "$MAX_TEMP_FILE" 2>/dev/null || echo "0 0")
  (( CPU_TEMP_INT > EXISTING_TODAY_CPU )) && EXISTING_TODAY_CPU=$CPU_TEMP_INT
  (( SSD_TEMP_INT > EXISTING_TODAY_SSD )) && EXISTING_TODAY_SSD=$SSD_TEMP_INT

  save_daily_max_temps $EXISTING_TODAY_CPU $EXISTING_TODAY_SSD

  MAX_CPU=$(get_7day_max CPU)
  MAX_SSD=$(get_7day_max SSD)
  CPU_OVER=$(temp_crossed_threshold CPU)
  SSD_OVER=$(temp_crossed_threshold SSD)

  PIHOLE_STATUS=$(systemctl is-active --quiet pihole-FTL && echo -e "${BLUE}UP${NC}" || echo -e "${RED}DOWN${NC}")
  WLAN_IF="wlan0"
  WLAN_IP=$(ip -4 -o addr show "$WLAN_IF" | awk '{print $4}' | cut -d/ -f1)
  WLAN_STATUS=$(pgrep hostapd >/dev/null && echo "AP Mode" || echo "Not AP")
  if systemctl is-active --quiet transmission-daemon; then
    TRANS_STATUS="Running"
    TRANS_IP=$IP_ADDR
    TRANS_PORT=9092
  else
    TRANS_STATUS="Stopped"
    TRANS_IP="N/A"
    TRANS_PORT=""
  fi

  IFACE_COLOR=$RED; [[ $(check_internet $IFACE) -eq 1 ]] && IFACE_COLOR=$GREEN

  # Disk usage
  read -r ROOT_TOTAL ROOT_USED ROOT_FREE ROOT_USE_PCT <<<$(df --block-size=1G / | awk 'NR==2 {print $2, $3, $4, $5}')
  ROOT_FREE_PCT=$(awk -v free=$ROOT_FREE -v total=$ROOT_TOTAL 'BEGIN { printf "%.1f", (free/total)*100 }')

  read -r SSD_TOTAL SSD_USED SSD_FREE SSD_USE_PCT <<<$(df --block-size=1G /mnt/ssd | awk 'NR==2 {print $2, $3, $4, $5}')
  SSD_FREE_PCT=$(awk -v free=$SSD_FREE -v total=$SSD_TOTAL 'BEGIN { printf "%.1f", (free/total)*100 }')

  # lnp.log size
  LNP_LOG_PATH="/mnt/ssd/lnp/lnp.log"
  if [[ -f "$LNP_LOG_PATH" ]]; then
    LNP_SIZE=$(du -h "$LNP_LOG_PATH" | awk '{print $1}')
    LNP_STATUS="running"
  else
    LNP_SIZE="N/A"
    LNP_STATUS="not found"
  fi

  # Get systemd status of lnp_rotate service and timer
  LNP_ROTATE_SERVICE_STATUS=$(systemctl is-active lnp_rotate.service 2>/dev/null)
  LNP_ROTATE_TIMER_STATUS=$(systemctl is-active lnp_rotate.timer 2>/dev/null)

  # Fallback in case they are empty:
  [[ -z "$LNP_ROTATE_SERVICE_STATUS" ]] && LNP_ROTATE_SERVICE_STATUS="unknown"
  [[ -z "$LNP_ROTATE_TIMER_STATUS" ]] && LNP_ROTATE_TIMER_STATUS="unknown"

  # --- OUTPUT ---
  printf "Date: %-42s\n" "$DATE_STR"
  printf "Current user: %-30s\n" "$USER"
  printf "Internet Interface: ${IFACE_COLOR}%-27s${NC}\n" "$IFACE"
  printf "IP Address: ${BLUE}%-38s${NC}\n" "$IP_ADDR"
  printf "Uptime: %-39s\n" "$UPTIME"
  printf "Memory Usage: %-30s\n" "${MEM_INFO[0]}MB / ${MEM_INFO[1]}MB"
  printf "CPU Usage: %-37s\n" "$CPU_USAGE"

  [[ $CPU_OVER -eq 1 ]] && C_COLOR=$RED || C_COLOR=$NC
  printf "CPU Temp: ${C_COLOR}%.1f'C (max: %d'C)${NC}\n" "$CPU_TEMP_RAW" "$MAX_CPU"

  if [[ $SSD_TEMP_RAW == "N/A" || $SSD_TEMP_RAW == 0 ]]; then
    printf "SSD Temp: ${RED}N/A (max: %d'C)${NC}\n" "$MAX_SSD"
  else
    [[ $SSD_OVER -eq 1 ]] && S_COLOR=$RED || S_COLOR=$NC
    printf "SSD Temp: ${S_COLOR}%d'C (max: %d'C)${NC}\n" "$SSD_TEMP_INT" "$MAX_SSD"
  fi

  echo ""
  printf "%-25s %b\n" "Pi-hole" "$PIHOLE_STATUS"
  printf "%-25s %s, ${BLUE}%-15s${NC}\n" "WLAN Interface ($WLAN_IF)" "$WLAN_STATUS" "${WLAN_IP:-N/A}"
  printf "%-25s %s, ${BLUE}%-15s${NC}\n" "Transmission Client" "$TRANS_STATUS" "${TRANS_IP}:${TRANS_PORT}"
  printf "%-25s %d GB left (%.1f%% free of %d GB)\n" "Memory Card (root)" "$ROOT_FREE" "$ROOT_FREE_PCT" "$ROOT_TOTAL"
  printf "%-25s %d GB left (%.1f%% free of %d GB)\n" "SSD (/mnt/ssd)" "$SSD_FREE" "$SSD_FREE_PCT" "$SSD_TOTAL"
  printf "%-25s %s Service: %s\n" "lnp.log size" "$LNP_SIZE" "$LNP_STATUS"
  printf "%-25s %s\n" "lnp_rotate.service" "$LNP_ROTATE_SERVICE_STATUS"
  printf "%-25s %s\n" "lnp_rotate.timer" "$LNP_ROTATE_TIMER_STATUS"


  echo ""
  echo "All processes and their memory usage (MB):"
  echo "-----------------------------------------"

  # Calculate total memory once for MB conversion
  TOTAL_MEM_MB=$(free -m | awk '/^Mem:/ {print $2}')

  ps -eo pid,comm,%mem --sort=-%mem | head -n 21 | awk -v total_mem_mb=$TOTAL_MEM_MB '
    NR==1 { printf "%-8s %-25s %-10s\n", $1, $2, "MEM(MB)" }
    NR>1 {
      mem_mb = ($3 / 100) * total_mem_mb;
      printf "%-8s %-25s %-10.1f\n", $1, $2, mem_mb
    }
  '

  echo ""

  sleep 30
done
