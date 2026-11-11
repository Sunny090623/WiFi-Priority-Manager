#!/system/bin/sh
# Magisk module customization script for WiFi Priority Manager
# Note: Only writes to $MODPATH and /data/adb/wifi_priority. Never touches /system or WifiConfigStore.xml.

SKIPMOUNT=1

DATA_DIR="/data/adb/wifi_priority"
CONFIG_FILE="$DATA_DIR/config.json"

ui_print "****************************************"
ui_print "  WiFi Priority Manager v1.0.0"
ui_print "  Safe Root Daemon + KsuWebUI (MD3)"
ui_print "****************************************"

ui_print "- Normalizing script line endings (LF)"
for f in "$MODPATH/module.prop" "$MODPATH/service.sh" "$MODPATH/action.sh" "$MODPATH/uninstall.sh"; do
  [ -f "$f" ] && sed -i 's/\r$//' "$f" 2>/dev/null
done
find "$MODPATH/scripts" -type f 2>/dev/null | while read -r f; do
  sed -i 's/\r$//' "$f" 2>/dev/null
done

ui_print "- Setting executable permissions"
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm_recursive "$MODPATH/scripts" 0 0 0755 0755

ui_print "- Initializing persistent config directory"
mkdir -p "$DATA_DIR"
chown 0:0 "$DATA_DIR"
chmod 0700 "$DATA_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  ui_print "- Creating default config.json"
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
fi

chown 0:0 "$CONFIG_FILE"
chmod 0600 "$CONFIG_FILE"

ui_print "- Installation complete (webroot contexts preserved)"
