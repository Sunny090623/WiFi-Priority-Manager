# Validates incoming JSON config, preserves unchanged manual passwords, writes out_file.
# Requires: lib_json.awk, lib_xml.awk

BEGIN {
  init_ascii()
  old_raw = read_entire_file(old_file)
  if (old_raw != "" && parse_config_str(old_raw)) {
    for (i = 1; i <= item_count; i++) {
      if (item_ssid[i] != "" && item_password[i] != "") {
        old_pw[item_ssid[i]] = item_password[i]
      }
    }
  }

  new_raw = read_entire_file(in_file)
  if (new_raw == "" || !parse_config_str(new_raw)) {
    print "ERROR:INVALID_JSON"
    exit 1
  }
  clamp_config()

  clean_n = 0
  for (i = 1; i <= item_count; i++) {
    s = trim(item_ssid[i])
    if (s == "" || (s in seen_ssid)) continue
    seen_ssid[s] = 1
    src = (item_source[i] == "manual" ? "manual" : "saved")
    sec = norm_sec(item_security[i])
    if (sec != "open" && sec != "owe" && sec != "wpa2" && sec != "wpa3" && sec != "wep" && sec != "auto") {
      sec = "auto"
    }
    pw = item_password[i]
    if (src == "manual" && pw == "" && item_keep_pw[i] && (s in old_pw)) {
      pw = old_pw[s]
    }
    if (src == "saved") pw = ""
    clean_n++
    c_ssid[clean_n] = s; c_src[clean_n] = src; c_sec[clean_n] = sec; c_pw[clean_n] = pw
  }

  printf "{\n" > out_file
  printf "  \"enabled\": %s,\n", (cfg_enabled ? "true" : "false") > out_file
  printf "  \"preempt_enabled\": %s,\n", (cfg_preempt ? "true" : "false") > out_file
  printf "  \"check_interval_sec\": %d,\n", cfg_interval > out_file
  printf "  \"rssi_threshold\": %d,\n", cfg_rssi > out_file
  printf "  \"cooldown_sec\": %d,\n", cfg_cooldown > out_file
  printf "  \"screen_off_multiplier\": %d,\n", cfg_multiplier > out_file
  printf "  \"priority_list\": [\n" > out_file
  for (i = 1; i <= clean_n; i++) {
    printf "    {\"ssid\": \"%s\", \"source\": \"%s\", \"security\": \"%s\", \"password\": \"%s\"}%s\n",
      json_escape(c_ssid[i]), json_escape(c_src[i]), json_escape(c_sec[i]), json_escape(c_pw[i]),
      (i < clean_n ? "," : "") > out_file
  }
  printf "  ]\n}\n" > out_file
  close(out_file)

  item_count = clean_n
  for (i = 1; i <= clean_n; i++) {
    item_ssid[i] = c_ssid[i]; item_source[i] = c_src[i]
    item_security[i] = c_sec[i]; item_password[i] = c_pw[i]
  }
  emit_masked_config()
}
