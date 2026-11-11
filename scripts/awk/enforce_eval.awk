# Phase 3 priority matching against fresh scan results and XML/config credentials.
# Requires: lib_json.awk, lib_xml.awk

function sec_from_scan_flags(flags) {
  if (flags == "") return ""
  if (index(flags, "EAP") > 0) return "eap"
  if (index(flags, "SAE") > 0 && index(flags, "PSK") == 0) return "wpa3"
  if (index(flags, "PSK") > 0) return "wpa2"
  if (index(flags, "OWE") > 0) return "owe"
  if (index(flags, "WEP") > 0) return "wep"
  if (index(flags, "[ESS]") > 0) return "open"
  return ""
}

BEGIN {
  init_ascii()
  parse_config_str(read_entire_file(cfg_file))
  clamp_config()
  parse_xml_file(xml_path)

  if (list_file != "") {
    while ((getline ln < list_file) > 0) {
      sub(/\r$/, "", ln); ln = trim(ln)
      if (ln == "" || ln ~ /^Network Id/) continue
      if (!match(ln, /^[0-9]+[ \t]+/)) continue
      rest = trim(substr(ln, RSTART + RLENGTH))
      if (!match(rest, /[ \t]+[^ \t]+$/)) continue
      sraw = trim(substr(rest, RSTART))
      lssid = trim(substr(rest, 1, RSTART - 1))
      if (lssid == "") continue
      is_auto = (substr(sraw, length(sraw), 1) == "^" ? 1 : 0)
      lsec = norm_sec(sraw)
      if (!(lssid in net_sec) || !is_auto) net_sec[lssid] = lsec
    }
    close(list_file)
  }
  cur_ssid = from_hex(cur_hex)
}
{
  line = trim($0)
  if (line == "" || line ~ /^BSSID/) next
  if (!match(line, /^[0-9A-Fa-f:]+[ \t]+[0-9]+[ \t]+-?[0-9]+[ \t]+[0-9.]+[ \t]*/)) next
  prefix = trim(substr(line, RSTART, RLENGTH))
  split(prefix, f, /[ \t]+/)
  rssi = f[3] + 0
  age = f[4] + 0
  if (age > 45 || age < 0) next

  rest = substr(line, RSTART + RLENGTH)
  flags = ""
  if (match(rest, /[ \t]*(\[[^\[\]]+\])+[ \t]*$/)) {
    flags = trim(substr(rest, RSTART))
    ssid = trim(substr(rest, 1, RSTART - 1))
  } else {
    ssid = trim(rest)
  }
  if (ssid == "") next
  if (!(ssid in scan_rssi) || rssi > scan_rssi[ssid]) {
    scan_rssi[ssid] = rssi
    scan_flags[ssid] = flags
  }
}
END {
  for (i = 1; i <= item_count; i++) {
    t_ssid = item_ssid[i]
    # Unconditional same-SSID guard: never reconnect to current active SSID
    if (cur_ssid != "" && t_ssid == cur_ssid) {
      print "HOLD|" to_hex(cur_ssid) "|" i; exit 0
    }
    if (!(t_ssid in scan_rssi) || scan_rssi[t_ssid] < cfg_rssi) continue

    t_sec = norm_sec(item_security[i]); t_pass = ""; t_hidden = 0
    ap_flags = (t_ssid in scan_flags ? scan_flags[t_ssid] : "")
    ap_sec = sec_from_scan_flags(ap_flags)

    if (item_source[i] == "manual") {
      t_pass = item_password[i]
      if (t_ssid in xml_seen) t_hidden = xml_hidden[t_ssid]
      if (t_pass == "") {
        if (t_ssid in xml_seen && xml_sec[t_ssid] != "") t_sec = xml_sec[t_ssid]
        if (t_ssid in xml_seen && xml_psk[t_ssid] != "") t_pass = xml_psk[t_ssid]
      }
      if (t_sec == "auto" || t_sec == "") {
        if (t_ssid in xml_seen && xml_sec[t_ssid] != "") t_sec = xml_sec[t_ssid]
        else if (ap_sec != "") t_sec = ap_sec
        else t_sec = "wpa2"
      } else if (ap_sec == "wpa3" && t_sec == "wpa2") {
        # AP broadcasts WPA3-SAE only (no PSK); avoid mismatched default wpa2
        t_sec = "wpa3"
      } else if (ap_sec == "wpa2" && t_sec == "wpa3") {
        t_sec = "wpa2"
      }
      if ((t_sec == "wpa2" || t_sec == "wpa3" || t_sec == "wep") && t_pass == "") {
        print "WARN_NO_PASS|" to_printf_esc(t_ssid) "|" t_sec; continue
      }
    } else {
      if (t_sec == "auto" || t_sec == "") {
        if (t_ssid in xml_seen && xml_sec[t_ssid] != "") t_sec = xml_sec[t_ssid]
        else if (t_ssid in net_sec) t_sec = net_sec[t_ssid]
      }
      pair_key = t_ssid SUBSEP t_sec
      if (pair_key in xml_seen_pair) {
        t_pass = xml_psk_pair[pair_key]; t_hidden = xml_hidden_pair[pair_key]
      } else if (t_ssid in xml_seen) {
        t_pass = xml_psk[t_ssid]; t_hidden = xml_hidden[t_ssid]
        if (xml_sec[t_ssid] != "") t_sec = xml_sec[t_ssid]
        else if (t_ssid in net_sec && net_sec[t_ssid] != "") t_sec = net_sec[t_ssid]
      } else if (t_ssid in net_sec && net_sec[t_ssid] != "") {
        t_sec = net_sec[t_ssid]
      }
      if (ap_sec == "wpa3" && t_sec == "wpa2") t_sec = "wpa3"
      if (t_sec == "eap") { print "WARN_EAP|" to_printf_esc(t_ssid); continue }
      if (t_sec != "open" && t_sec != "owe" && t_sec != "wpa2" && t_sec != "wpa3" && t_sec != "wep") {
        print "WARN_UNSUPPORTED|" to_printf_esc(t_ssid) "|" t_sec; continue
      }
      if ((t_sec == "wpa2" || t_sec == "wpa3" || t_sec == "wep") && t_pass == "") {
        print "WARN_NO_PASS|" to_printf_esc(t_ssid) "|" t_sec; continue
      }
    }
    print "CONNECT|" to_printf_esc(t_ssid) "|" to_hex(t_ssid) "|" t_sec "|" to_printf_esc(t_pass) "|" scan_rssi[t_ssid] "|" t_hidden "|" i
    exit 0
  }
  print "NO_MATCH|" to_hex(cur_ssid)
}
