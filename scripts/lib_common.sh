#!/system/bin/sh
# Shared paths, locking, logging, and utility wrappers for WiFi Priority Manager.

DATA_DIR="/data/adb/wifi_priority"
CONFIG_FILE="$DATA_DIR/config.json"
PID_FILE="$DATA_DIR/daemon.pid"
LOG_FILE="$DATA_DIR/daemon.log"
LAST_SWITCH_FILE="$DATA_DIR/last_switch"
LOCK_DIR="$DATA_DIR/enforce.lock"

CMD_WIFI="/system/bin/cmd wifi"

run_awk() {
  if [ -x /system/bin/awk ]; then
    /system/bin/awk "$@"
  elif [ -x /data/adb/magisk/busybox ]; then
    /data/adb/magisk/busybox awk "$@"
  else
    awk "$@"
  fi
}

run_base64() {
  if [ -x /system/bin/base64 ]; then
    /system/bin/base64 "$@"
  elif [ -x /data/adb/magisk/busybox ]; then
    /data/adb/magisk/busybox base64 "$@"
  else
    base64 "$@"
  fi
}

resolve_xml_path() {
  if [ -r /data/misc/apexdata/com.android.wifi/WifiConfigStore.xml ]; then
    echo "/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml"
  elif [ -r /data/misc/wifi/WifiConfigStore.xml ]; then
    echo "/data/misc/wifi/WifiConfigStore.xml"
  else
    echo ""
  fi
}

ensure_data_dir() {
  if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
    chown 0:0 "$DATA_DIR" 2>/dev/null
    chmod 0700 "$DATA_DIR" 2>/dev/null
  fi
  if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
  "enabled": true,
  "preempt_enabled": true,
  "check_interval_sec": 30,
  "rssi_threshold": -78,
  "cooldown_sec": 45,
  "screen_off_multiplier": 2,
  "priority_list": []
}
EOF
    chown 0:0 "$CONFIG_FILE" 2>/dev/null
    chmod 0600 "$CONFIG_FILE" 2>/dev/null
  fi
}

append_log() {
  ensure_data_dir
  ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
  [ -z "$ts" ] && ts="0"
  printf '%s [%s] %s\n' "$ts" "$1" "$2" >> "$LOG_FILE"
  if [ -f "$LOG_FILE" ]; then
    lines=$(wc -l < "$LOG_FILE" 2>/dev/null)
    if [ -n "$lines" ] && [ "$lines" -gt 240 ]; then
      tail -n 200 "$LOG_FILE" > "$LOG_FILE.tmp.$$" 2>/dev/null && mv -f "$LOG_FILE.tmp.$$" "$LOG_FILE"
      chown 0:0 "$LOG_FILE" 2>/dev/null
      chmod 0600 "$LOG_FILE" 2>/dev/null
    fi
  fi
}

is_daemon_running() {
  [ ! -f "$PID_FILE" ] && return 1
  dpid=$(cat "$PID_FILE" 2>/dev/null | tr -dc '0-9')
  [ -z "$dpid" ] && return 1
  if kill -0 "$dpid" 2>/dev/null; then
    args=$(ps -p "$dpid" -o args= 2>/dev/null)
    case "$args" in
      *wifi_daemon.sh*) return 0 ;;
      "")
        grep -q "wifi_daemon.sh" "/proc/$dpid/cmdline" 2>/dev/null && return 0
        ;;
    esac
  fi
  return 1
}

get_daemon_pid() {
  if is_daemon_running; then
    cat "$PID_FILE" 2>/dev/null | tr -dc '0-9'
  else
    echo ""
  fi
}

acquire_lock() {
  wait_force="${1:-0}"
  tries=0
  while true; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then
      echo "$$" > "$LOCK_DIR/pid"
      return 0
    fi
    old_lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null | tr -dc '0-9')
    if [ -z "$old_lock_pid" ] || ! kill -0 "$old_lock_pid" 2>/dev/null; then
      rm -rf "$LOCK_DIR"
      continue
    fi
    [ "$wait_force" != "1" ] && return 1
    [ "$tries" -ge 10 ] && return 1
    tries=$((tries + 1))
    sleep 1
  done
}

release_lock() {
  rm -rf "$LOCK_DIR" 2>/dev/null
}
