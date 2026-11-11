# Shared `cmd wifi status` parser (Android 13-17 Mainline WiFi compatible).
# Requires: lib_json.awk

function init_status_parser() {
  wifi_enabled = 0
  connected = 0
  cur_ssid = ""
  bssid = ""
  rssi = -127
  sup_state = ""
  ip = ""
  freq = 0
  in_primary = 1
  has_primary_conn = 0
}

function extract_connected_line_ssid(tline,    s) {
  s = substr(tline, length("Wifi is connected to \"") + 1)
  if (length(s) > 0 && substr(s, length(s), 1) == "\"") {
    s = substr(s, 1, length(s) - 1)
  }
  return s
}

function extract_wifiinfo_ssid(tline,    p1, rest, p2) {
  p1 = index(tline, "SSID: \"")
  if (p1 <= 0) return ""
  rest = substr(tline, p1 + 7)
  p2 = index(rest, "\", BSSID:")
  if (p2 > 0) return substr(rest, 1, p2 - 1)
  p2 = index(rest, "\"")
  if (p2 > 0) return substr(rest, 1, p2 - 1)
  return ""
}

function parse_status_line(raw_line,    tline, s, is_sec_role) {
  sub(/\r$/, "", raw_line)
  tline = trim(raw_line)
  if (tline == "") return

  if (index(tline, "==== ClientModeManager") > 0 || tline ~ /^Role:[ \t]*/) {
    is_sec_role = (index(tline, "ROLE_CLIENT_SECONDARY") > 0 ||
                   index(tline, "ROLE_CLIENT_SCAN_ONLY") > 0 ||
                   index(tline, "ROLE_CLIENT_LOCAL_ONLY") > 0)
    if (is_sec_role) {
      in_primary = 0
    } else {
      # Keep primary active when header omits explicit ROLE_CLIENT_* token
      in_primary = 1
    }
    return
  }

  if (tline ~ /^Wifi is disabled/) {
    if (!has_primary_conn) wifi_enabled = 0
    return
  }
  if (tline ~ /^Wifi is enabled/) {
    wifi_enabled = 1
    return
  }

  if (!in_primary) return

  if (index(tline, "Wifi is connected to \"") == 1) {
    s = extract_connected_line_ssid(tline)
    if (s != "" && s != "<unknown ssid>") {
      cur_ssid = s
      connected = 1
      wifi_enabled = 1
      has_primary_conn = 1
    }
    return
  }

  if (index(tline, "WifiInfo:") == 1) {
    s = extract_wifiinfo_ssid(tline)
    if (s != "" && s != "<unknown ssid>") {
      if (cur_ssid == "" || !has_primary_conn) {
        cur_ssid = s
      }
    }
    if (match(tline, /BSSID: [^,]+/)) {
      if (bssid == "" || !has_primary_conn) {
        bssid = trim(substr(tline, RSTART + 7, RLENGTH - 7))
        if (bssid == "<none>" || bssid == "null") bssid = ""
      }
    }
    if (match(tline, /IP: [^,]+/)) {
      if (ip == "" || !has_primary_conn) {
        ip = trim(substr(tline, RSTART + 4, RLENGTH - 4))
        sub(/^\//, "", ip)
        if (ip == "null" || ip == "<none>") ip = ""
      }
    }
    if (match(tline, /Supplicant state: [^,]+/)) {
      if (sup_state == "" || !has_primary_conn) {
        sup_state = trim(substr(tline, RSTART + 18, RLENGTH - 18))
      }
    }
    if (match(tline, /RSSI: -?[0-9]+/)) {
      if (rssi <= -127 || !has_primary_conn) {
        rssi = substr(tline, RSTART + 6, RLENGTH - 6) + 0
      }
    }
    if (match(tline, /Frequency: -?[0-9]+MHz/)) {
      if (freq == 0 || !has_primary_conn) {
        freq = substr(tline, RSTART + 11, RLENGTH - 14) + 0
      }
    }
    if (cur_ssid != "" && sup_state == "COMPLETED") {
      connected = 1
      wifi_enabled = 1
      has_primary_conn = 1
    }
  }
}
