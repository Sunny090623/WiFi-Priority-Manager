# WiFi Priority Manager

A lightweight Magisk module with a Material Design 3 WebUI that enforces multi-level WiFi connection priorities, active preemption, and automatic fallback.

## NOTE

This module does not modify `/system` partitions, inject `sepolicy.rule`, or run `post-fs-data.sh`. Its daemon starts asynchronously after `sys.boot_completed=1`, and it reads `/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml` strictly read-only to preserve system integrity checksums.

## Tutorial

You will need root via [Magisk](https://github.com/topjohnwu/Magisk) (or KernelSU / APatch) and a WebUI-compatible manager such as [KsuWebUI](https://github.com/5ec1cff/KsuWebUIStandalone) or [MMRL](https://github.com/DerGoogler/MMRL).

1. Flash `wifi-priority-manager-v1.0.0.zip` in your root manager and reboot.
2. Open the module WebUI from KsuWebUI / MMRL.
3. Tap **Add WiFi** to pick saved networks from the dropdown (or select **Manual input...** at the bottom) and order them from `#1` downward.
4. Click **Save** to apply changes. You can also trigger an immediate check via the WebUI button or the manager's **Action** button (`action.sh`).

## Options

All settings are stored in `/data/adb/wifi_priority/config.json` (`0600 root:root`) and can be configured directly from the WebUI:

- **enabled**: Enable or pause the background priority daemon, enabled by default.
- **preempt_enabled**: Actively switch from a lower-ranked WiFi to a higher-ranked WiFi when signal and freshness criteria are met, enabled by default. When disabled, the module keeps any currently connected network that exists in `priority_list`.
- **check_interval_sec**: Polling interval in seconds (`15`–`300`, default `30`). Automatically multiplied by `screen_off_multiplier` (default `2`, capped at `300s`) while the screen is asleep.
- **rssi_threshold**: Minimum RSSI in dBm (`-95` to `-30`, default `-78`) required before connecting or preempting.
- **cooldown_sec**: Minimum interval in seconds (`10`–`300`, default `45`) after a successful switch before preempting again while connected, preventing ping-pong switching on weak signal edges.
- **priority_list**: Ordered queue (`#1 → #2 → #3 ...`) supporting `saved` networks and `manual` entries (`wpa2`, `wpa3`, `open`, `owe`).

> [!NOTE]
> - To save power and avoid scan throttling, the daemon skips `cmd wifi start-scan` whenever you are already connected to `#1` (or any listed network while `preempt_enabled` is off).
> - Scan results older than `45` seconds (`Age(sec) > 45`) are ignored to avoid switching to stale cached APs after leaving an area.
> - If none of the networks in `priority_list` are in range, the module stops intervening and leaves WiFi selection to Android.

> [!WARNING]
> Do not manually edit `/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml`, as invalidating its checksum causes Android to discard saved networks.
> The WebUI manages all module settings safely via Base64-encoded payloads; 802.1X EAP enterprise networks are not supported for manual creation or `cmd wifi` triggering.

## CLI & Debugging

You can inspect status or trigger enforcement directly from a root terminal:

```sh
# Check current WiFi and daemon status
su -c '/system/bin/sh /data/adb/modules/wifi_priority_manager/scripts/wifi_ctl.sh status'

# List parsed saved networks (read-only)
su -c '/system/bin/sh /data/adb/modules/wifi_priority_manager/scripts/wifi_ctl.sh saved_networks'

# Force an immediate priority check
su -c '/system/bin/sh /data/adb/modules/wifi_priority_manager/scripts/wifi_ctl.sh enforce_once --force'

# View recent daemon logs
su -c '/system/bin/sh /data/adb/modules/wifi_priority_manager/scripts/wifi_ctl.sh get_logs 50'
```

## Build

Ensure all `.sh`, `.awk`, and `module.prop` files use Unix `LF` line endings, and package the module root directly (without a parent folder):

```sh
zip -r9 wifi-priority-manager-v1.0.0.zip \
  module.prop customize.sh service.sh action.sh uninstall.sh \
  scripts/ webroot/ README.md
```

## Uninstall

Disable or remove the module in Magisk / KernelSU and reboot. `uninstall.sh` stops `wifi_daemon.sh` and removes `/data/adb/wifi_priority`, leaving system WiFi configuration untouched.
