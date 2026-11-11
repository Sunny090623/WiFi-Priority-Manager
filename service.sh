#!/system/bin/sh
# Magisk late_start service script for WiFi Priority Manager
# Runs asynchronously after sys.boot_completed=1 so it never blocks system boot.

case "$0" in
  */*) MODDIR=$(CDPATH= cd -- "${0%/*}" && pwd) ;;
  *)   MODDIR=$(pwd) ;;
esac

(
  # Wait for Android framework boot completion
  while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
  done

  # Wait for Mainline WiFi service binder to become responsive (bounded up to 60s)
  tries=0
  while [ "$tries" -lt 30 ]; do
    if /system/bin/cmd wifi status >/dev/null 2>&1; then
      break
    fi
    tries=$((tries + 1))
    sleep 2
  done

  # Extra grace delay after WiFi service startup
  sleep 3

  # Respect Magisk disable / remove flags
  if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
    exit 0
  fi

  exec /system/bin/sh "$MODDIR/scripts/wifi_daemon.sh"
) </dev/null >/dev/null 2>&1 &

exit 0
