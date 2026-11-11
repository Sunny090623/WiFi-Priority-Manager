# Checks if `cmd wifi status` reports connected to target_hex SSID.
# Requires: lib_json.awk, lib_status.awk

BEGIN {
  init_ascii()
  init_status_parser()
  target_ssid = from_hex(target_hex)
}
{
  parse_status_line($0)
}
END {
  if (connected && target_ssid != "" && cur_ssid == target_ssid) {
    print "CONNECTED"
  } else {
    print "PENDING"
  }
}
