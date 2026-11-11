#!/system/bin/sh
# Magisk uninstall cleanup script for WiFi Priority Manager

DATA_DIR="/data/adb/wifi_priority"
PID_FILE="$DATA_DIR/daemon.pid"

if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ]; then
    kill "$OLD_PID" 2>/dev/null
    sleep 1
    kill -9 "$OLD_PID" 2>/dev/null
  fi
fi

pkill -f "wifi_priority_manager/scripts/wifi_daemon.sh" 2>/dev/null
rm -rf "$DATA_DIR"
