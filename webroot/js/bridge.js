(() => {
  'use strict';

  const UI = window.WifiUI;
  const { state, el } = UI;

  function encodeUtf8Base64(str) {
    const bytes = new TextEncoder().encode(str);
    let bin = '';
    for (let i = 0; i < bytes.length; i += 1) {
      bin += String.fromCharCode(bytes[i]);
    }
    return btoa(bin);
  }

  function decodeUtf8Base64(b64) {
    const bin = atob(b64);
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i += 1) {
      bytes[i] = bin.charCodeAt(i);
    }
    return new TextDecoder().decode(bytes);
  }

  function showToast(msg) {
    if (state.isKsu && typeof window.ksu.toast === 'function') {
      try {
        window.ksu.toast(msg);
      } catch (_) {}
    }
    el.snackbar.textContent = msg;
    el.snackbar.classList.remove('hidden');
    clearTimeout(state.snackTimer);
    state.snackTimer = setTimeout(() => {
      el.snackbar.classList.add('hidden');
    }, 2800);
  }

  function ksuExec(subcmd) {
    return new Promise((resolve, reject) => {
      const cb = `_ksu_cb_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
      window[cb] = (errno, stdout, stderr) => {
        try {
          delete window[cb];
        } catch (_) {
          window[cb] = undefined;
        }
        if (Number(errno) === 0) {
          resolve((stdout || '').trim());
        } else {
          const out = (stdout || '').trim();
          try {
            const parsed = JSON.parse(out);
            if (parsed && parsed.error) {
              reject(new Error(parsed.error));
              return;
            }
          } catch (_) {}
          reject(new Error((stderr || out || `errno=${errno}`).trim()));
        }
      };
      try {
        window.ksu.exec(`${UI.CTL_PREFIX} ${subcmd}`, '{}', cb);
      } catch (err) {
        delete window[cb];
        reject(err);
      }
    });
  }

  function loadMockConfig() {
    try {
      const raw = localStorage.getItem(UI.MOCK_STORAGE_KEY);
      if (raw) return JSON.parse(raw);
    } catch (_) {}
    return {
      enabled: true,
      preempt_enabled: true,
      check_interval_sec: 30,
      rssi_threshold: -78,
      cooldown_sec: 45,
      screen_off_multiplier: 2,
      priority_list: [],
    };
  }

  const MOCK_SAVED = [
    { network_id: 0, ssid: 'Home_WiFi_5G', security: 'wpa3', has_password: true, hidden: false, connectable: true },
    { network_id: 1, ssid: 'Home_WiFi_2.4G', security: 'wpa2', has_password: true, hidden: false, connectable: true },
    { network_id: 2, ssid: 'Office_Guest', security: 'open', has_password: false, hidden: false, connectable: true },
    { network_id: 3, ssid: 'Campus_8021X', security: 'eap', has_password: false, hidden: false, connectable: false },
  ];

  const MOCK_SCAN = [
    { ssid: 'Home_WiFi_5G', rssi: -54, frequency_mhz: 5180 },
    { ssid: 'Home_WiFi_2.4G', rssi: -68, frequency_mhz: 2437 },
  ];

  const MOCK_RUNTIME = {
    ssid: 'Home_WiFi_2.4G',
    rssi: -68,
    frequency_mhz: 2437,
    ip: '192.168.31.102',
    daemon_running: true,
    daemon_pid: 4120,
  };

  async function apiCall(action, arg = '') {
    if (state.isKsu) {
      const raw = await ksuExec(arg ? `${action} '${arg}'` : action);
      return JSON.parse(raw || '{}');
    }

    if (action === 'status') {
      const cfg = loadMockConfig();
      return {
        wifi_enabled: true,
        connected: Boolean(MOCK_RUNTIME.ssid),
        ssid: MOCK_RUNTIME.ssid,
        rssi: MOCK_RUNTIME.rssi,
        frequency_mhz: MOCK_RUNTIME.frequency_mhz,
        ip: MOCK_RUNTIME.ip,
        supplicant_state: 'COMPLETED',
        daemon_running: MOCK_RUNTIME.daemon_running,
        daemon_pid: MOCK_RUNTIME.daemon_running ? MOCK_RUNTIME.daemon_pid : 0,
        enabled: cfg.enabled,
        preempt_enabled: cfg.preempt_enabled,
      };
    }
    if (action === 'saved_networks') return { networks: MOCK_SAVED };
    if (action === 'scan_results') return { scan_results: MOCK_SCAN };
    if (action === 'get_config') return loadMockConfig();
    if (action === 'save_config') {
      const parsed = JSON.parse(decodeUtf8Base64(arg));
      const masked = {
        ...parsed,
        priority_list: (parsed.priority_list || []).map((item) => {
          const hasPw = Boolean(item.password || item.keep_password);
          return {
            ssid: item.ssid,
            source: item.source,
            security: item.security,
            has_password: hasPw,
            keep_password: hasPw,
          };
        }),
      };
      localStorage.setItem(UI.MOCK_STORAGE_KEY, JSON.stringify(masked));
      return { ok: true, config: masked };
    }
    if (action === 'enforce_once') {
      const cfg = loadMockConfig();
      const first = (cfg.priority_list || [])[0];
      if (!first) {
        return { ok: true, action: 'none', reason: 'empty_priority_list', current_ssid: MOCK_RUNTIME.ssid };
      }
      const targetSsid = first.ssid || 'Home_WiFi_5G';
      const scan = MOCK_SCAN.find((x) => x.ssid === targetSsid);
      MOCK_RUNTIME.ssid = targetSsid;
      MOCK_RUNTIME.rssi = scan ? scan.rssi : -54;
      MOCK_RUNTIME.frequency_mhz = scan ? scan.frequency_mhz : 5180;
      MOCK_RUNTIME.ip = '192.168.31.88';
      return { ok: true, action: 'connect', target_ssid: targetSsid, rssi: MOCK_RUNTIME.rssi, rank: 1 };
    }
    if (action === 'get_logs') {
      return {
        logs: [
          '2026-11-10 22:40:00 [INFO] Daemon started (PID 4120)',
          `2026-11-10 22:41:05 [SWITCH] Connected to #1 '${MOCK_RUNTIME.ssid}' (${MOCK_RUNTIME.rssi} dBm)`,
        ],
      };
    }
    if (action === 'clear_logs') return { ok: true };
    if (action === 'daemon_control') {
      MOCK_RUNTIME.daemon_running = arg !== 'stop';
      return { ok: true, running: MOCK_RUNTIME.daemon_running, pid: MOCK_RUNTIME.daemon_running ? MOCK_RUNTIME.daemon_pid : 0 };
    }
    return {};
  }

  UI.encodeUtf8Base64 = encodeUtf8Base64;
  UI.showToast = showToast;
  UI.apiCall = apiCall;
})();
