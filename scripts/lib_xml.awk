# Read-only WifiConfigStore.xml parser and WiFi security type normalizers.
# Depends on functions in lib_json.awk.

function xml_unescape(s,    out, pos, semi, ent, val, i, c) {
  out = ""
  while ((pos = index(s, "&#")) > 0) {
    out = out substr(s, 1, pos - 1)
    s = substr(s, pos + 2)
    semi = index(s, ";")
    if (semi <= 1 || semi > 10) { out = out "&#"; continue }
    ent = substr(s, 1, semi - 1)
    s = substr(s, semi + 1)
    val = 0
    if (substr(ent, 1, 1) == "x" || substr(ent, 1, 1) == "X") {
      for (i = 2; i <= length(ent); i++) {
        c = substr(ent, i, 1)
        if (!(c in _HEX_VAL)) { val = -1; break }
        val = val * 16 + _HEX_VAL[c]
      }
    } else if (ent ~ /^[0-9]+$/) {
      val = ent + 0
    } else {
      val = -1
    }
    if (val > 0) out = out cp_to_utf8(val)
    else out = out "&#" ent ";"
  }
  s = out s
  s = str_replace(s, "&lt;", "<")
  s = str_replace(s, "&gt;", ">")
  s = str_replace(s, "&apos;", "'")
  s = str_replace(s, "&quot;", "\"")
  s = str_replace(s, "&amp;", "&")
  return s
}

function strip_outer_quotes(s) {
  if (length(s) >= 2 && substr(s, 1, 1) == "\"" && substr(s, length(s), 1) == "\"") {
    return substr(s, 2, length(s) - 2)
  }
  return s
}

function norm_sec(s,    l) {
  l = tolower(trim(s))
  sub(/\^$/, "", l)
  if (l == "open" || l == "none") return "open"
  if (l == "owe") return "owe"
  if (l == "wpa2" || l == "wpa2-psk" || l == "wpa_psk") return "wpa2"
  if (l == "wpa3" || l == "wpa3-sae" || l == "sae") return "wpa3"
  if (l == "wep") return "wep"
  if (index(l, "eap") > 0 || index(l, "suite") > 0) return "eap"
  if (l == "auto" || l == "") return "auto"
  return l
}

function sec_from_type(t) {
  if (t == "0") return "open"
  if (t == "1") return "wep"
  if (t == "2") return "wpa2"
  if (t == "3") return "eap"
  if (t == "4") return "wpa3"
  if (t == "5") return "eap"
  if (t == "6") return "owe"
  if (t == "9") return "eap"
  return ""
}

function sec_from_config_key(ck) {
  if (ck ~ /NONE$/) return "open"
  if (ck ~ /OWE$/) return "owe"
  if (ck ~ /WPA_PSK$/) return "wpa2"
  if (ck ~ /SAE$/) return "wpa3"
  if (ck ~ /WEP$/) return "wep"
  if (ck ~ /WPA_EAP$/ || ck ~ /SUITE_B_192$/) return "eap"
  return ""
}

function extract_tag_value(line, tag,    p1, p2) {
  p1 = index(line, ">")
  p2 = index(line, "</" tag ">")
  if (p1 > 0 && p2 > p1) return substr(line, p1 + 1, p2 - p1 - 1)
  return ""
}

function has_name_attr(line, target) {
  return (index(line, "name=\"" target "\"") > 0 || index(line, "name='" target "'") > 0)
}

function extract_attr_value(line,    s, q, p2) {
  if (!match(line, /value[ \t]*=[ \t]*["']/)) return ""
  s = substr(line, RSTART + RLENGTH)
  q = substr(line, RSTART + RLENGTH - 1, 1)
  p2 = index(s, q)
  if (p2 <= 0) return ""
  return substr(s, 1, p2 - 1)
}

function parse_xml_file(xml_path,    line, in_wc, in_sp, cur_ssid, cur_quoted, cur_psk, cur_ck, cur_hidden, cur_sec, sp_type, sp_auto, v, sec_m, key) {
  if (xml_path == "") return
  in_wc = 0; in_sp = 0
  while ((getline line < xml_path) > 0) {
    if (index(line, "<WifiConfiguration>") > 0) {
      in_wc = 1
      cur_ssid = ""; cur_quoted = 0; cur_psk = ""; cur_ck = ""; cur_hidden = 0; cur_sec = ""
      continue
    }
    if (!in_wc) continue
    if (index(line, "</WifiConfiguration>") > 0) {
      in_wc = 0
      if (cur_sec == "" && cur_ck != "") cur_sec = sec_from_config_key(cur_ck)
      if (cur_ssid != "") {
        key = cur_ssid SUBSEP cur_sec
        if (!(key in xml_seen_pair) || cur_quoted) {
          xml_seen_pair[key] = 1
          xml_psk_pair[key] = cur_psk
          xml_hidden_pair[key] = cur_hidden
        }
        if (!(cur_ssid in xml_seen) || (cur_quoted && !xml_quoted[cur_ssid]) || (cur_psk != "" && xml_psk[cur_ssid] == "")) {
          xml_seen[cur_ssid] = 1
          xml_quoted[cur_ssid] = cur_quoted
          xml_sec[cur_ssid] = cur_sec
          xml_psk[cur_ssid] = cur_psk
          xml_hidden[cur_ssid] = cur_hidden
        }
      }
      continue
    }
    if (has_name_attr(line, "SSID") && index(line, "</string>") > 0) {
      v = xml_unescape(extract_tag_value(line, "string"))
      if (length(v) >= 2 && substr(v, 1, 1) == "\"" && substr(v, length(v), 1) == "\"") {
        cur_quoted = 1
        cur_ssid = substr(v, 2, length(v) - 2)
      } else {
        cur_quoted = 0
        cur_ssid = v
      }
    } else if (has_name_attr(line, "ConfigKey") && index(line, "</string>") > 0) {
      cur_ck = xml_unescape(extract_tag_value(line, "string"))
    } else if (has_name_attr(line, "PreSharedKey") && index(line, "</string>") > 0) {
      v = xml_unescape(extract_tag_value(line, "string"))
      cur_psk = strip_outer_quotes(v)
    } else if (has_name_attr(line, "HiddenSSID")) {
      cur_hidden = (extract_attr_value(line) == "true" ? 1 : 0)
    } else if (index(line, "<SecurityParams>") > 0) {
      in_sp = 1; sp_type = ""; sp_auto = 0
    } else if (index(line, "</SecurityParams>") > 0) {
      if (in_sp) {
        sec_m = sec_from_type(sp_type)
        if (sec_m != "" && (!sp_auto || cur_sec == "")) cur_sec = sec_m
      }
      in_sp = 0
    } else if (in_sp) {
      if (has_name_attr(line, "SecurityType")) sp_type = extract_attr_value(line)
      else if (has_name_attr(line, "IsAddedByAutoUpgrade")) sp_auto = (extract_attr_value(line) == "true" ? 1 : 0)
    }
  }
  close(xml_path)
}
