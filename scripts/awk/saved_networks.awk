# Cross-references `cmd wifi list-networks` with read-only WifiConfigStore.xml.
# Requires: lib_json.awk, lib_xml.awk

BEGIN {
  init_ascii()
  parse_xml_file(xml_path)
  net_count = 0
}
{
  line = trim($0)
  if (line == "" || line ~ /^Network Id/) next
  if (!match(line, /^[0-9]+[ \t]+/)) next
  nid = trim(substr(line, RSTART, RLENGTH)) + 0
  rest = trim(substr(line, RSTART + RLENGTH))
  if (rest == "") next
  if (!match(rest, /[ \t]+[^ \t]+$/)) next
  sec_raw = trim(substr(rest, RSTART))
  ssid = trim(substr(rest, 1, RSTART - 1))
  if (ssid == "") next

  is_auto = (substr(sec_raw, length(sec_raw), 1) == "^" ? 1 : 0)
  sec = norm_sec(sec_raw)

  if (!(nid in seen_nid) || (!is_auto && nid_auto[nid])) {
    if (!(nid in seen_nid)) {
      net_count++
      nid_order[net_count] = nid
    }
    seen_nid[nid] = 1
    nid_auto[nid] = is_auto
    nid_ssid[nid] = ssid
    nid_sec[nid] = sec
  }
}
END {
  out_n = 0
  for (i = 1; i <= net_count; i++) {
    nid = nid_order[i]; ssid = nid_ssid[nid]; sec = nid_sec[nid]
    if (ssid in emitted_ssid) continue
    emitted_ssid[ssid] = 1

    pair_key = ssid SUBSEP sec
    has_pw = 0; hidden = 0
    if (pair_key in xml_seen_pair) {
      has_pw = (xml_psk_pair[pair_key] != "" ? 1 : 0)
      hidden = xml_hidden_pair[pair_key]
    } else if (ssid in xml_seen) {
      has_pw = (xml_psk[ssid] != "" ? 1 : 0)
      hidden = xml_hidden[ssid]
      if (sec == "" || sec == "auto") sec = xml_sec[ssid]
    }
    connectable = (sec == "open" || sec == "owe" || sec == "wpa2" || sec == "wpa3" || sec == "wep") ? 1 : 0
    if ((sec == "wpa2" || sec == "wpa3" || sec == "wep") && !has_pw) connectable = 0

    out_n++
    out_nid[out_n] = nid; out_ssid[out_n] = ssid; out_sec[out_n] = sec
    out_pw[out_n] = has_pw; out_hid[out_n] = hidden; out_conn[out_n] = connectable
  }

  printf "{\n  \"networks\": [\n"
  for (i = 1; i <= out_n; i++) {
    printf "    {\"network_id\": %d, \"ssid\": \"%s\", \"security\": \"%s\", \"has_password\": %s, \"hidden\": %s, \"connectable\": %s}%s\n",
      out_nid[i], json_escape(out_ssid[i]), json_escape(out_sec[i]),
      (out_pw[i] ? "true" : "false"), (out_hid[i] ? "true" : "false"),
      (out_conn[i] ? "true" : "false"), (i < out_n ? "," : "")
  }
  printf "  ]\n}\n"
}
