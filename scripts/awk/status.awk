# Parses `cmd wifi status` output + config/last-switch metadata into status JSON.
# Requires: lib_json.awk, lib_status.awk

BEGIN {
  init_ascii()
  init_status_parser()
  last_ts = 0; last_ssid = ""
  if (last_file != "") {
    if ((getline lline < last_file) > 0) {
      sub(/\r$/, "", lline)
      tpos = index(lline, "\t")
      if (tpos > 0) {
        last_ts = substr(lline, 1, tpos - 1) + 0
        last_ssid = substr(lline, tpos + 1)
      }
    }
    close(last_file)
  }
  cfg_raw = read_entire_file(cfg_file)
  if (cfg_raw != "" && parse_config_str(cfg_raw)) {
    clamp_config()
  } else {
    cfg_enabled = 1; cfg_preempt = 1; item_count = 0
  }
}
{
  parse_status_line($0)
}
END {
  printf "{\n"
  printf "  \"wifi_enabled\": %s,\n", (wifi_enabled ? "true" : "false")
  printf "  \"connected\": %s,\n", (connected ? "true" : "false")
  printf "  \"ssid\": \"%s\",\n", json_escape(cur_ssid)
  printf "  \"bssid\": \"%s\",\n", json_escape(bssid)
  printf "  \"rssi\": %d,\n", rssi
  printf "  \"supplicant_state\": \"%s\",\n", json_escape(sup_state)
  printf "  \"ip\": \"%s\",\n", json_escape(ip)
  printf "  \"frequency_mhz\": %d,\n", freq
  printf "  \"daemon_running\": %s,\n", (d_running ? "true" : "false")
  printf "  \"daemon_pid\": %d,\n", d_pid
  printf "  \"last_switch_ts\": %d,\n", last_ts + 0
  printf "  \"last_switch_ssid\": \"%s\",\n", json_escape(last_ssid)
  printf "  \"enabled\": %s,\n", (cfg_enabled ? "true" : "false")
  printf "  \"preempt_enabled\": %s,\n", (cfg_preempt ? "true" : "false")
  printf "  \"priority_count\": %d\n", item_count
  printf "}\n"
}
