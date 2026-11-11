#!/system/bin/sh
# Read-only query helpers: WiFi status, saved networks, and scan results.

cmd_status() {
  ensure_data_dir
  dpid=$(get_daemon_pid)
  if [ -n "$dpid" ]; then
    d_running=1
  else
    d_running=0
    dpid=0
  fi
  last_file=""
  [ -f "$LAST_SWITCH_FILE" ] && last_file="$LAST_SWITCH_FILE"

  $CMD_WIFI status 2>/dev/null | run_awk \
    -f "$SCRIPT_DIR/lib_json.awk" \
    -f "$SCRIPT_DIR/lib_status.awk" \
    -f "$SCRIPT_DIR/awk/status.awk" \
    -v d_running="$d_running" -v d_pid="$dpid" \
    -v cfg_file="$CONFIG_FILE" -v last_file="$last_file"
}

cmd_saved_networks() {
  ensure_data_dir
  xml_path=$(resolve_xml_path)

  $CMD_WIFI list-networks 2>/dev/null | run_awk \
    -f "$SCRIPT_DIR/lib_json.awk" \
    -f "$SCRIPT_DIR/lib_xml.awk" \
    -f "$SCRIPT_DIR/awk/saved_networks.awk" \
    -v xml_path="$xml_path"
}

cmd_scan_results() {
  $CMD_WIFI list-scan-results 2>/dev/null | run_awk \
    -f "$SCRIPT_DIR/lib_json.awk" \
    -f "$SCRIPT_DIR/awk/scan_results.awk"
}
