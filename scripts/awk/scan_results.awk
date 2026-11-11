# Parses `cmd wifi list-scan-results` deduplicated by SSID (keeping strongest RSSI).
# Requires: lib_json.awk

BEGIN { init_ascii(); n = 0 }
{
  line = trim($0)
  if (line == "" || line ~ /^BSSID/) next
  if (!match(line, /^[0-9A-Fa-f:]+[ \t]+[0-9]+[ \t]+-?[0-9]+[ \t]+[0-9.]+[ \t]*/)) next
  prefix = trim(substr(line, RSTART, RLENGTH))
  split(prefix, f, /[ \t]+/)
  bssid = f[1]; freq = f[2] + 0; rssi = f[3] + 0; age = f[4] + 0
  rest = substr(line, RSTART + RLENGTH)
  flags = ""; ssid = ""
  if (match(rest, /[ \t]*(\[[^\[\]]+\])+[ \t]*$/)) {
    flags = trim(substr(rest, RSTART))
    ssid = trim(substr(rest, 1, RSTART - 1))
  } else {
    ssid = trim(rest)
  }
  if (ssid == "") next
  if (!(ssid in seen) || rssi > best_rssi[ssid]) {
    if (!(ssid in seen)) { n++; order[n] = ssid; seen[ssid] = 1 }
    best_rssi[ssid] = rssi; best_freq[ssid] = freq; best_bssid[ssid] = bssid
    best_age[ssid] = age; best_flags[ssid] = flags
  }
}
END {
  printf "{\n  \"scan_results\": [\n"
  for (i = 1; i <= n; i++) {
    s = order[i]
    printf "    {\"ssid\": \"%s\", \"bssid\": \"%s\", \"frequency_mhz\": %d, \"rssi\": %d, \"age_sec\": %.1f, \"flags\": \"%s\"}%s\n",
      json_escape(s), json_escape(best_bssid[s]), best_freq[s], best_rssi[s], best_age[s], json_escape(best_flags[s]), (i < n ? "," : "")
  }
  printf "  ]\n}\n"
}
