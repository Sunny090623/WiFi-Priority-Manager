# Formats enforce_once result JSON cleanly based on `kind` variable.
# Requires: lib_json.awk

BEGIN { init_ascii(); msg = "" }
{ if (kind == "error") msg = (msg == "" ? $0 : msg " " $0) }
END {
  if (kind == "skip") {
    printf "{\"ok\":true,\"action\":\"none\",\"reason\":\"%s\",\"current_ssid\":\"%s\"}\n",
      json_escape(reason), json_escape(from_hex(s_hex))
  } else if (kind == "hold") {
    printf "{\"ok\":true,\"action\":\"hold\",\"reason\":\"already_best_in_range\",\"current_ssid\":\"%s\",\"rank\":%d}\n",
      json_escape(from_hex(s_hex)), rank + 0
  } else if (kind == "connect") {
    printf "{\"ok\":true,\"action\":\"connect\",\"target_ssid\":\"%s\",\"security\":\"%s\",\"rssi\":%d,\"rank\":%d}\n",
      json_escape(from_hex(s_hex)), json_escape(sec), rssi + 0, rank + 0
  } else if (kind == "error") {
    printf "{\"ok\":false,\"action\":\"error\",\"target_ssid\":\"%s\",\"error\":\"%s\"}\n",
      json_escape(from_hex(s_hex)), json_escape(msg)
  } else {
    printf "{\"ok\":true,\"action\":\"none\",\"reason\":\"no_configured_wifi_in_range\",\"current_ssid\":\"%s\"}\n",
      json_escape(from_hex(s_hex))
  }
}
