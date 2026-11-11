# Emits masked config.json for WebUI consumption.
# Requires: lib_json.awk

BEGIN {
  init_ascii()
  cfg_raw = read_entire_file(cfg_file)
  if (cfg_raw == "" || !parse_config_str(cfg_raw)) {
    cfg_enabled = 1; cfg_preempt = 1; cfg_interval = 30
    cfg_rssi = -78; cfg_cooldown = 45; cfg_multiplier = 2; item_count = 0
  }
  clamp_config()
  emit_masked_config()
}
