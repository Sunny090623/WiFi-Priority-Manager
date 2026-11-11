# Phase 1 fast pre-scan decision for enforce_once.
# Requires: lib_json.awk, lib_status.awk

BEGIN {
  init_ascii()
  init_status_parser()
  cfg_raw = read_entire_file(cfg_file)
  if (cfg_raw == "" || !parse_config_str(cfg_raw)) { print "SKIP|invalid_config|"; exit 0 }
  clamp_config()
  if (!cfg_enabled && !force_mode) { print "SKIP|disabled|"; exit 0 }
  if (item_count == 0) { print "SKIP|empty_priority_list|"; exit 0 }
  last_ts = 0
  if (last_file != "") {
    if ((getline lline < last_file) > 0) {
      sub(/\r$/, "", lline)
      tpos = index(lline, "\t")
      if (tpos > 0) last_ts = substr(lline, 1, tpos - 1) + 0
    }
    close(last_file)
  }
}
{
  parse_status_line($0)
}
END {
  if (item_count == 0 || (!cfg_enabled && !force_mode)) exit 0
  if (!wifi_enabled) { print "SKIP|wifi_disabled|"; exit 0 }
  if (connected && cur_ssid == item_ssid[1]) {
    print "SKIP|already_highest_priority|" to_hex(cur_ssid); exit 0
  }
  if (!cfg_preempt && connected) {
    for (i = 1; i <= item_count; i++) {
      if (cur_ssid == item_ssid[i]) {
        print "SKIP|preempt_disabled_in_list|" to_hex(cur_ssid); exit 0
      }
    }
  }
  if (!force_mode && connected && last_ts > 0 && now_ts >= last_ts && (now_ts - last_ts) < cfg_cooldown) {
    print "SKIP|cooldown|" to_hex(cur_ssid); exit 0
  }
  print "SCAN|" to_hex(cur_ssid) "|" (connected ? "1" : "0")
}
