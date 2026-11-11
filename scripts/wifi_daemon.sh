#!/system/bin/sh
# Background WiFi Priority Manager daemon.
# Enforces single-instance PID lock, polls dynamically from config.json,
# and scales polling interval when screen is off to save battery.

case "$0" in
  */*) SCRIPT_DIR=$(CDPATH= cd -- "${0%/*}" && pwd) ;;
  *)   SCRIPT_DIR=$(pwd) ;;
esac
MODDIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CTL="$SCRIPT_DIR/wifi_ctl.sh"

. "$SCRIPT_DIR/lib_common.sh"

ensure_data_dir

# Terminate any previous running instance before taking the PID lock
OLD_PID=$(get_daemon_pid)
if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ]; then
  kill "$OLD_PID" 2>/dev/null
  sleep 1
  kill -9 "$OLD_PID" 2>/dev/null
fi

echo "$$" > "$PID_FILE"
chown 0:0 "$PID_FILE" 2>/dev/null
chmod 0644 "$PID_FILE" 2>/dev/null

SLEEP_PID=""

cleanup_and_exit() {
  if [ -n "$SLEEP_PID" ]; then
    kill "$SLEEP_PID" 2>/dev/null
  fi
  if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null | tr -dc '0-9')" = "$$" ]; then
    rm -f "$PID_FILE"
  fi
  exit 0
}

trap 'cleanup_and_exit' INT TERM EXIT

read_loop_settings() {
  # Returns: enabled|interval|multiplier
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "1|30|2"
    return
  fi
  run_awk '
  BEGIN { en=1; iv=30; mul=2 }
  /"enabled"[ \t]*:/ {
    if ($0 ~ /false/) en=0
    else if ($0 ~ /true/) en=1
  }
  /"check_interval_sec"[ \t]*:/ {
    line=$0; sub(/.*:/, "", line); gsub(/[^0-9]/, "", line)
    if (line != "") iv = line + 0
  }
  /"screen_off_multiplier"[ \t]*:/ {
    line=$0; sub(/.*:/, "", line); gsub(/[^0-9]/, "", line)
    if (line != "") mul = line + 0
  }
  END {
    if (iv < 15) iv = 15
    if (iv > 300) iv = 300
    if (mul < 1) mul = 1
    if (mul > 6) mul = 6
    printf "%d|%d|%d\n", en, iv, mul
  }' "$CONFIG_FILE" 2>/dev/null
}

is_screen_off() {
  pwr=$(dumpsys power 2>/dev/null | grep -m1 -E 'mWakefulness=|Display Power: state=')
  case "$pwr" in
    *Asleep*|*Dozing*|*state=OFF*) return 0 ;;
    *) return 1 ;;
  esac
}

append_log "INFO" "Daemon started (PID $$)"

while true; do
  if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
    append_log "INFO" "Module disabled or removed; daemon exiting"
    break
  fi

  settings=$(read_loop_settings)
  IFS='|' read -r d_enabled d_interval d_mult << EOF
$settings
EOF
  [ -z "$d_enabled" ] && d_enabled=1
  [ -z "$d_interval" ] && d_interval=30
  [ -z "$d_mult" ] && d_mult=2

  if [ "$d_enabled" = "1" ]; then
    /system/bin/sh "$CTL" enforce_once >/dev/null 2>&1
  fi

  sleep_sec="$d_interval"
  if [ "$d_mult" -gt 1 ] && is_screen_off; then
    sleep_sec=$((d_interval * d_mult))
    [ "$sleep_sec" -gt 300 ] && sleep_sec=300
  fi

  sleep "$sleep_sec" &
  SLEEP_PID=$!
  wait "$SLEEP_PID" 2>/dev/null
  SLEEP_PID=""
done
