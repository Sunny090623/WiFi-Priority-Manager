#!/system/bin/sh
# Magisk / KSU Action button handler: runs an immediate forced priority check.

case "$0" in
  */*) MODDIR=$(CDPATH= cd -- "${0%/*}" && pwd) ;;
  *)   MODDIR=$(pwd) ;;
esac
CTL="$MODDIR/scripts/wifi_ctl.sh"

echo "========================================"
echo "  WiFi Priority Manager - Action"
echo "========================================"

if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
  echo "[!] Module is disabled or scheduled for removal."
  exit 0
fi

echo "[*] Running immediate WiFi priority check..."
OUT=$(/system/bin/sh "$CTL" enforce_once --force 2>&1)
echo "$OUT"

# Ensure daemon is running if module is enabled (after forced check to avoid lock contention)
/system/bin/sh "$CTL" daemon_control ensure >/dev/null 2>&1

echo ""
echo "[*] Current status:"
/system/bin/sh "$CTL" status
