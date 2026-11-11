#!/system/bin/sh
# Priority state machine: short-circuit check, scan evaluation, and cmd wifi connect-network.

is_connect_cmd_accepted() {
  c_rc="$1"
  c_out="$2"
  [ "$c_rc" -ne 0 ] && return 1
  case "$c_out" in
    *[Ff]ailed*|*[Ee]rror*|*Exception*|*Unknown*|*Invalid*|*Usage:*|*usage:*)
      return 1
      ;;
  esac
  return 0
}

run_connect_cmd() {
  use_hex="$1"; t_ssid="$2"; t_hex="$3"; t_sec="$4"; t_pass="$5"; t_hidden="$6"
  if [ "$use_hex" = "1" ]; then
    if [ "$t_sec" = "open" ] || [ "$t_sec" = "owe" ]; then
      if [ "$t_hidden" = "1" ]; then
        $CMD_WIFI connect-network "$t_hex" "$t_sec" -x -h 2>&1
      else
        $CMD_WIFI connect-network "$t_hex" "$t_sec" -x 2>&1
      fi
    else
      if [ "$t_hidden" = "1" ]; then
        $CMD_WIFI connect-network "$t_hex" "$t_sec" "$t_pass" -x -h 2>&1
      else
        $CMD_WIFI connect-network "$t_hex" "$t_sec" "$t_pass" -x 2>&1
      fi
    fi
  else
    if [ "$t_sec" = "open" ] || [ "$t_sec" = "owe" ]; then
      if [ "$t_hidden" = "1" ]; then
        $CMD_WIFI connect-network "$t_ssid" "$t_sec" -h 2>&1
      else
        $CMD_WIFI connect-network "$t_ssid" "$t_sec" 2>&1
      fi
    else
      if [ "$t_hidden" = "1" ]; then
        $CMD_WIFI connect-network "$t_ssid" "$t_sec" "$t_pass" -h 2>&1
      else
        $CMD_WIFI connect-network "$t_ssid" "$t_sec" "$t_pass" 2>&1
      fi
    fi
  fi
}

connect_wifi_network() {
  t_ssid="$1"; t_hex="$2"; t_sec="$3"; t_pass="$4"; t_hidden="$5"

  conn_out=$(run_connect_cmd 0 "$t_ssid" "$t_hex" "$t_sec" "$t_pass" "$t_hidden")
  conn_rc=$?
  if is_connect_cmd_accepted "$conn_rc" "$conn_out"; then
    printf '%s' "$conn_out"
    return 0
  fi

  # Fallback to -x (Hex SSID) strictly when plain connect-network failed
  conn_out=$(run_connect_cmd 1 "$t_ssid" "$t_hex" "$t_sec" "$t_pass" "$t_hidden")
  conn_rc=$?
  printf '%s' "$conn_out"
  is_connect_cmd_accepted "$conn_rc" "$conn_out"
  return $?
}

wait_for_connection() {
  target_hex="$1"
  tries=0
  while [ "$tries" -lt 4 ]; do
    sleep 2
    st_res=$($CMD_WIFI status 2>/dev/null | run_awk \
      -f "$SCRIPT_DIR/lib_json.awk" \
      -f "$SCRIPT_DIR/lib_status.awk" \
      -f "$SCRIPT_DIR/awk/check_connected.awk" \
      -v target_hex="$target_hex")
    if [ "$st_res" = "CONNECTED" ]; then
      return 0
    fi
    tries=$((tries + 1))
  done
  return 1
}

write_last_switch() {
  ts_val=$(date +%s 2>/dev/null)
  [ -z "$ts_val" ] && ts_val=0
  printf '%s\t%s\n' "$ts_val" "$1" > "$LAST_SWITCH_FILE"
  chown 0:0 "$LAST_SWITCH_FILE" 2>/dev/null
  chmod 0600 "$LAST_SWITCH_FILE" 2>/dev/null
}

emit_enforce_reply() {
  run_awk -f "$SCRIPT_DIR/lib_json.awk" -f "$SCRIPT_DIR/awk/enforce_reply.awk" "$@"
}

eval_pre_status() {
  printf '%s\n' "$1" | run_awk \
    -f "$SCRIPT_DIR/lib_json.awk" \
    -f "$SCRIPT_DIR/lib_status.awk" \
    -f "$SCRIPT_DIR/awk/enforce_pre.awk" \
    -v cfg_file="$CONFIG_FILE" -v last_file="$last_file" \
    -v force_mode="$force_mode" -v now_ts="$now_ts"
}

cmd_enforce_once() {
  ensure_data_dir
  force_mode=0
  if [ "$1" = "--force" ] || [ "$1" = "-f" ]; then
    force_mode=1
  fi

  if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
    echo '{"ok":true,"action":"skipped","reason":"module_disabled"}'
    return 0
  fi

  if ! acquire_lock "$force_mode"; then
    echo '{"ok":true,"action":"skipped","reason":"concurrent_lock"}'
    return 0
  fi

  tmp_list="$DATA_DIR/.list_net.tmp.$$"
  trap 'rm -f "$tmp_list"; release_lock' EXIT INT TERM

  last_file=""
  [ -f "$LAST_SWITCH_FILE" ] && last_file="$LAST_SWITCH_FILE"
  now_ts=$(date +%s 2>/dev/null)
  [ -z "$now_ts" ] && now_ts=0

  status_out=$($CMD_WIFI status 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$status_out" ]; then
    rm -f "$tmp_list"; release_lock; trap - EXIT INT TERM
    echo '{"ok":false,"action":"error","reason":"wifi_service_unavailable"}'
    return 1
  fi

  # Phase 1: Fast pre-scan check (skips scan when already optimal or disabled)
  pre_decision=$(eval_pre_status "$status_out")
  IFS='|' read -r p_action p_arg1 p_arg2 << EOF
$pre_decision
EOF

  if [ "$p_action" = "SKIP" ]; then
    rm -f "$tmp_list"; release_lock; trap - EXIT INT TERM
    emit_enforce_reply -v kind="skip" -v reason="$p_arg1" -v s_hex="$p_arg2" </dev/null
    return 0
  fi

  # Phase 2: Trigger scan and wait; re-sync status afterward in case AutoJoin finished
  $CMD_WIFI start-scan >/dev/null 2>&1
  sleep 3

  status_after=$($CMD_WIFI status 2>/dev/null)
  if [ $? -eq 0 ] && [ -n "$status_after" ]; then
    now_ts=$(date +%s 2>/dev/null)
    [ -z "$now_ts" ] && now_ts=0
    post_decision=$(eval_pre_status "$status_after")
    IFS='|' read -r p2_action p2_arg1 p2_arg2 << EOF
$post_decision
EOF
    if [ "$p2_action" = "SKIP" ]; then
      rm -f "$tmp_list"; release_lock; trap - EXIT INT TERM
      emit_enforce_reply -v kind="skip" -v reason="$p2_arg1" -v s_hex="$p2_arg2" </dev/null
      return 0
    fi
    p_arg1="$p2_arg1"
    p_arg2="$p2_arg2"
  fi

  $CMD_WIFI list-networks > "$tmp_list" 2>/dev/null
  xml_path=$(resolve_xml_path)

  # Phase 3: Traverse priority list in order against fresh scan results & credentials
  eval_result=$($CMD_WIFI list-scan-results 2>/dev/null | run_awk \
    -f "$SCRIPT_DIR/lib_json.awk" \
    -f "$SCRIPT_DIR/lib_xml.awk" \
    -f "$SCRIPT_DIR/awk/enforce_eval.awk" \
    -v cfg_file="$CONFIG_FILE" -v xml_path="$xml_path" \
    -v list_file="$tmp_list" -v cur_hex="$p_arg1" -v connected="$p_arg2")
  rm -f "$tmp_list"

  connect_line=""
  while IFS= read -r eline; do
    [ -z "$eline" ] && continue
    IFS='|' read -r ekind e1 e2 e3 e4 e5 e6 e7 << EOF
$eline
EOF
    case "$ekind" in
      WARN_NO_PASS)     append_log "WARN" "Missing passphrase for '$(printf '%b' "$e1")' ($e2); skipping" ;;
      WARN_EAP)         append_log "WARN" "Enterprise 802.1X EAP '$(printf '%b' "$e1")' unsupported by cmd wifi; skipping" ;;
      WARN_UNSUPPORTED) append_log "WARN" "Unsupported security '$e2' for '$(printf '%b' "$e1")'; skipping" ;;
      HOLD|CONNECT|NO_MATCH) connect_line="$eline" ;;
    esac
  done << EOF
$eval_result
EOF

  IFS='|' read -r c_kind c1 c2 c3 c4 c5 c6 c7 << EOF
$connect_line
EOF

  if [ "$c_kind" = "HOLD" ]; then
    release_lock; trap - EXIT INT TERM
    emit_enforce_reply -v kind="hold" -v s_hex="$c1" -v rank="$c2" </dev/null
    return 0
  fi

  if [ "$c_kind" = "CONNECT" ]; then
    t_ssid=$(printf '%b' "$c1"); t_hex="$c2"; t_sec="$c3"
    t_pass=$(printf '%b' "$c4"); t_rssi="$c5"; t_hidden="$c6"; t_rank="$c7"

    conn_out=$(connect_wifi_network "$t_ssid" "$t_hex" "$t_sec" "$t_pass" "$t_hidden")
    conn_rc=$?

    if [ "$conn_rc" -eq 0 ]; then
      write_last_switch "$t_ssid"
      if wait_for_connection "$t_hex"; then
        write_last_switch "$t_ssid"
        append_log "SWITCH" "Connected to #$t_rank '$t_ssid' ($t_sec, RSSI ${t_rssi} dBm)"
      else
        append_log "SWITCH" "Connection initiated to #$t_rank '$t_ssid' ($t_sec, RSSI ${t_rssi} dBm)"
      fi
      release_lock; trap - EXIT INT TERM
      emit_enforce_reply -v kind="connect" -v s_hex="$t_hex" -v sec="$t_sec" -v rssi="$t_rssi" -v rank="$t_rank" </dev/null
      return 0
    else
      append_log "ERROR" "Failed connecting '$t_ssid' ($t_sec): $conn_out"
      release_lock; trap - EXIT INT TERM
      printf '%s' "$conn_out" | emit_enforce_reply -v kind="error" -v s_hex="$t_hex"
      return 1
    fi
  fi

  release_lock; trap - EXIT INT TERM
  emit_enforce_reply -v kind="no_match" -v s_hex="$c1" </dev/null
  return 0
}
