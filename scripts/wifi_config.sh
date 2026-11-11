#!/system/bin/sh
# Configuration persistence (0600 root:root) and daemon log access helpers.

cmd_get_config() {
  ensure_data_dir
  run_awk \
    -f "$SCRIPT_DIR/lib_json.awk" \
    -f "$SCRIPT_DIR/awk/get_config.awk" \
    -v cfg_file="$CONFIG_FILE"
}

cmd_save_config() {
  ensure_data_dir
  b64_input="$1"
  if [ -z "$b64_input" ]; then
    echo '{"ok":false,"error":"missing base64 payload"}'
    return 1
  fi

  tmp_in="$DATA_DIR/.in_cfg.tmp.$$"
  tmp_file="$CONFIG_FILE.tmp.$$"

  if ! printf '%s' "$b64_input" | tr -d ' \t\r\n' | run_base64 -d > "$tmp_in" 2>/dev/null || [ ! -s "$tmp_in" ]; then
    rm -f "$tmp_in"
    echo '{"ok":false,"error":"invalid base64 payload"}'
    return 1
  fi

  masked_out=$(run_awk \
    -f "$SCRIPT_DIR/lib_json.awk" \
    -f "$SCRIPT_DIR/lib_xml.awk" \
    -f "$SCRIPT_DIR/awk/save_config.awk" \
    -v old_file="$CONFIG_FILE" -v in_file="$tmp_in" -v out_file="$tmp_file")
  rc=$?
  rm -f "$tmp_in"
  if [ "$rc" -ne 0 ] || [ ! -s "$tmp_file" ]; then
    rm -f "$tmp_file"
    echo '{"ok":false,"error":"invalid config json"}'
    return 1
  fi

  chown 0:0 "$tmp_file" 2>/dev/null
  chmod 0600 "$tmp_file" 2>/dev/null
  mv -f "$tmp_file" "$CONFIG_FILE"
  chown 0:0 "$CONFIG_FILE" 2>/dev/null
  chmod 0600 "$CONFIG_FILE" 2>/dev/null
  append_log "INFO" "Configuration saved"
  printf '{"ok":true,"config":%s}\n' "$masked_out"
}

cmd_get_logs() {
  ensure_data_dir
  limit="$1"
  [ -z "$limit" ] && limit=80
  case "$limit" in
    *[!0-9]*) limit=80 ;;
  esac
  if [ ! -f "$LOG_FILE" ]; then
    echo '{"logs":[]}'
    return 0
  fi
  tail -n "$limit" "$LOG_FILE" | run_awk \
    -f "$SCRIPT_DIR/lib_json.awk" \
    -f "$SCRIPT_DIR/awk/logs.awk"
}

cmd_clear_logs() {
  ensure_data_dir
  : > "$LOG_FILE"
  chown 0:0 "$LOG_FILE" 2>/dev/null
  chmod 0600 "$LOG_FILE" 2>/dev/null
  echo '{"ok":true}'
}
