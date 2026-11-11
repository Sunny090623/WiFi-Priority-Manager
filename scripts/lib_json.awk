# Shared JSON parser/emitter, hex codec, and string utilities (POSIX/bwk awk compatible).

function init_ascii(    _i, _c) {
  for (_i = 0; _i < 256; _i++) {
    _c = sprintf("%c", _i)
    _ORD[_c] = _i
  }
  _HEX_VAL["0"]=0; _HEX_VAL["1"]=1; _HEX_VAL["2"]=2; _HEX_VAL["3"]=3; _HEX_VAL["4"]=4
  _HEX_VAL["5"]=5; _HEX_VAL["6"]=6; _HEX_VAL["7"]=7; _HEX_VAL["8"]=8; _HEX_VAL["9"]=9
  _HEX_VAL["a"]=10; _HEX_VAL["b"]=11; _HEX_VAL["c"]=12; _HEX_VAL["d"]=13; _HEX_VAL["e"]=14; _HEX_VAL["f"]=15
  _HEX_VAL["A"]=10; _HEX_VAL["B"]=11; _HEX_VAL["C"]=12; _HEX_VAL["D"]=13; _HEX_VAL["E"]=14; _HEX_VAL["F"]=15
}

function trim(s) {
  sub(/^[ \t\r\n]+/, "", s)
  sub(/[ \t\r\n]+$/, "", s)
  return s
}

function read_entire_file(path,    line, out) {
  if (path == "") return ""
  out = ""
  while ((getline line < path) > 0) {
    out = out line "\n"
  }
  close(path)
  return out
}

function str_replace(s, old, rep,    pos, out, olen) {
  olen = length(old)
  if (olen == 0) return s
  out = ""
  while ((pos = index(s, old)) > 0) {
    out = out substr(s, 1, pos - 1) rep
    s = substr(s, pos + olen)
  }
  return out s
}

function json_escape(s,    i, n, ch, o, code) {
  o = ""
  n = length(s)
  for (i = 1; i <= n; i++) {
    ch = substr(s, i, 1)
    if (ch == "\\") o = o "\\\\"
    else if (ch == "\"") o = o "\\\""
    else if (ch == "\n") o = o "\\n"
    else if (ch == "\r") o = o "\\r"
    else if (ch == "\t") o = o "\\t"
    else if (ch == "\b") o = o "\\b"
    else if (ch == "\f") o = o "\\f"
    else {
      code = _ORD[ch]
      if (code >= 0 && code < 32) o = o sprintf("\\u%04x", code)
      else o = o ch
    }
  }
  return o
}

function to_hex(s,    i, n, out) {
  out = ""
  n = length(s)
  for (i = 1; i <= n; i++) out = out sprintf("%02x", _ORD[substr(s, i, 1)])
  return out
}

function from_hex(h,    i, n, out, c1, c2) {
  out = ""
  n = length(h)
  for (i = 1; i + 1 <= n; i += 2) {
    c1 = substr(h, i, 1)
    c2 = substr(h, i + 1, 1)
    if ((c1 in _HEX_VAL) && (c2 in _HEX_VAL)) {
      out = out sprintf("%c", _HEX_VAL[c1] * 16 + _HEX_VAL[c2])
    }
  }
  return out
}

function to_printf_esc(s,    i, n, out) {
  out = ""
  n = length(s)
  for (i = 1; i <= n; i++) out = out sprintf("\\x%02x", _ORD[substr(s, i, 1)])
  return out
}

function cp_to_utf8(cp,    b1, b2, b3) {
  if (cp <= 0) return ""
  if (cp < 128) return sprintf("%c", cp)
  if (cp < 2048) {
    b1 = 192 + int(cp / 64)
    b2 = 128 + (cp % 64)
    return sprintf("%c%c", b1, b2)
  }
  if (cp < 65536) {
    b1 = 224 + int(cp / 4096)
    b2 = 128 + (int(cp / 64) % 64)
    b3 = 128 + (cp % 64)
    return sprintf("%c%c%c", b1, b2, b3)
  }
  return ""
}

function jp_ws() {
  while (JP <= JL) {
    _jc = substr(JS, JP, 1)
    if (_jc == " " || _jc == "\t" || _jc == "\n" || _jc == "\r") JP++
    else break
  }
}

function jp_str(    out, ch, esc, h4, i, val, c) {
  jp_ws()
  if (JP > JL || substr(JS, JP, 1) != "\"") { JP_OK = 0; return "" }
  JP++
  out = ""
  while (JP <= JL) {
    ch = substr(JS, JP, 1)
    JP++
    if (ch == "\"") return out
    if (ch == "\\") {
      if (JP > JL) { JP_OK = 0; return "" }
      esc = substr(JS, JP, 1)
      JP++
      if (esc == "\"") out = out "\""
      else if (esc == "\\") out = out "\\"
      else if (esc == "/") out = out "/"
      else if (esc == "b") out = out "\b"
      else if (esc == "f") out = out "\f"
      else if (esc == "n") out = out "\n"
      else if (esc == "r") out = out "\r"
      else if (esc == "t") out = out "\t"
      else if (esc == "u") {
        if (JP + 3 > JL) { JP_OK = 0; return "" }
        h4 = substr(JS, JP, 4)
        JP += 4
        val = 0
        for (i = 1; i <= 4; i++) {
          c = substr(h4, i, 1)
          if (!(c in _HEX_VAL)) { JP_OK = 0; return "" }
          val = val * 16 + _HEX_VAL[c]
        }
        out = out cp_to_utf8(val)
      } else out = out esc
    } else out = out ch
  }
  JP_OK = 0
  return ""
}

function jp_scalar(    start, ch, tok) {
  jp_ws()
  if (JP > JL) { JP_OK = 0; return "" }
  ch = substr(JS, JP, 1)
  if (ch == "\"") return jp_str()
  start = JP
  while (JP <= JL) {
    ch = substr(JS, JP, 1)
    if (ch == "," || ch == "}" || ch == "]" || ch == " " || ch == "\t" || ch == "\n" || ch == "\r") break
    JP++
  }
  tok = substr(JS, start, JP - start)
  if (tok == "true") return 1
  if (tok == "false") return 0
  if (tok == "null") return ""
  if (tok ~ /^-?[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?$/) return tok + 0
  JP_OK = 0
  return ""
}

function jp_skip(    ch) {
  jp_ws()
  if (JP > JL) { JP_OK = 0; return }
  ch = substr(JS, JP, 1)
  if (ch == "\"") {
    jp_str()
  } else if (ch == "{") {
    JP++; jp_ws()
    if (substr(JS, JP, 1) == "}") { JP++; return }
    while (JP <= JL && JP_OK) {
      jp_str(); jp_ws()
      if (substr(JS, JP, 1) != ":") { JP_OK = 0; return }
      JP++; jp_skip(); jp_ws()
      ch = substr(JS, JP, 1)
      if (ch == ",") { JP++; continue }
      if (ch == "}") { JP++; return }
      JP_OK = 0; return
    }
  } else if (ch == "[") {
    JP++; jp_ws()
    if (substr(JS, JP, 1) == "]") { JP++; return }
    while (JP <= JL && JP_OK) {
      jp_skip(); jp_ws()
      ch = substr(JS, JP, 1)
      if (ch == ",") { JP++; continue }
      if (ch == "]") { JP++; return }
      JP_OK = 0; return
    }
  } else {
    jp_scalar()
  }
}

function jp_parse_item(idx,    ch, k) {
  jp_ws()
  if (substr(JS, JP, 1) != "{") { JP_OK = 0; return }
  JP++
  item_ssid[idx] = ""; item_source[idx] = "saved"; item_security[idx] = "auto"
  item_password[idx] = ""; item_keep_pw[idx] = 0
  jp_ws()
  if (substr(JS, JP, 1) == "}") { JP++; return }
  while (JP <= JL && JP_OK) {
    k = jp_str(); jp_ws()
    if (substr(JS, JP, 1) != ":") { JP_OK = 0; return }
    JP++
    if (k == "ssid") item_ssid[idx] = jp_scalar()
    else if (k == "source") item_source[idx] = jp_scalar()
    else if (k == "security") item_security[idx] = jp_scalar()
    else if (k == "password") item_password[idx] = jp_scalar()
    else if (k == "keep_password") item_keep_pw[idx] = (jp_scalar() ? 1 : 0)
    else jp_skip()
    jp_ws()
    ch = substr(JS, JP, 1)
    if (ch == ",") { JP++; continue }
    if (ch == "}") { JP++; return }
    JP_OK = 0; return
  }
}

function jp_parse_priority_list(    ch, idx) {
  jp_ws()
  if (substr(JS, JP, 1) != "[") { JP_OK = 0; return }
  JP++; item_count = 0; jp_ws()
  if (substr(JS, JP, 1) == "]") { JP++; return }
  while (JP <= JL && JP_OK) {
    idx = item_count + 1
    jp_parse_item(idx)
    if (!JP_OK) return
    item_count = idx; jp_ws()
    ch = substr(JS, JP, 1)
    if (ch == ",") { JP++; continue }
    if (ch == "]") { JP++; return }
    JP_OK = 0; return
  }
}

function parse_config_str(raw,    _k, _ch) {
  JS = raw; JL = length(JS); JP = 1; JP_OK = 1
  cfg_enabled = 1; cfg_preempt = 1; cfg_interval = 30
  cfg_rssi = -78; cfg_cooldown = 45; cfg_multiplier = 2; item_count = 0

  jp_ws()
  if (JP > JL || substr(JS, JP, 1) != "{") { JP_OK = 0; return 0 }
  JP++; jp_ws()
  if (substr(JS, JP, 1) == "}") { JP++; return 1 }
  while (JP <= JL && JP_OK) {
    _k = jp_str(); jp_ws()
    if (substr(JS, JP, 1) != ":") { JP_OK = 0; return 0 }
    JP++
    if (_k == "enabled") cfg_enabled = (jp_scalar() ? 1 : 0)
    else if (_k == "preempt_enabled") cfg_preempt = (jp_scalar() ? 1 : 0)
    else if (_k == "check_interval_sec") cfg_interval = int(jp_scalar())
    else if (_k == "rssi_threshold") cfg_rssi = int(jp_scalar())
    else if (_k == "cooldown_sec") cfg_cooldown = int(jp_scalar())
    else if (_k == "screen_off_multiplier") cfg_multiplier = int(jp_scalar())
    else if (_k == "priority_list") jp_parse_priority_list()
    else jp_skip()
    jp_ws()
    _ch = substr(JS, JP, 1)
    if (_ch == ",") { JP++; continue }
    if (_ch == "}") { JP++; jp_ws(); return JP_OK }
    JP_OK = 0; return 0
  }
  return 0
}

function clamp_config() {
  if (cfg_interval < 15) cfg_interval = 15
  if (cfg_interval > 300) cfg_interval = 300
  if (cfg_rssi < -95) cfg_rssi = -95
  if (cfg_rssi > -30) cfg_rssi = -30
  if (cfg_cooldown < 10) cfg_cooldown = 10
  if (cfg_cooldown > 300) cfg_cooldown = 300
  if (cfg_multiplier < 1) cfg_multiplier = 1
  if (cfg_multiplier > 6) cfg_multiplier = 6
}

function emit_masked_config(    i, has_pw) {
  printf "{\n"
  printf "  \"enabled\": %s,\n", (cfg_enabled ? "true" : "false")
  printf "  \"preempt_enabled\": %s,\n", (cfg_preempt ? "true" : "false")
  printf "  \"check_interval_sec\": %d,\n", cfg_interval
  printf "  \"rssi_threshold\": %d,\n", cfg_rssi
  printf "  \"cooldown_sec\": %d,\n", cfg_cooldown
  printf "  \"screen_off_multiplier\": %d,\n", cfg_multiplier
  printf "  \"priority_list\": [\n"
  for (i = 1; i <= item_count; i++) {
    has_pw = (item_password[i] != "" ? 1 : 0)
    printf "    {\"ssid\": \"%s\", \"source\": \"%s\", \"security\": \"%s\", \"has_password\": %s, \"keep_password\": %s}%s\n",
      json_escape(item_ssid[i]), json_escape(item_source[i]), json_escape(item_security[i]),
      (has_pw ? "true" : "false"), (has_pw ? "true" : "false"), (i < item_count ? "," : "")
  }
  printf "  ]\n}\n"
}
