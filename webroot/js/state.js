(() => {
  'use strict';

  const UI = (window.WifiUI = window.WifiUI || {});

  UI.MANUAL_OPTION_VALUE = '__MANUAL__';
  UI.MOCK_STORAGE_KEY = 'wifi_priority_mock_config_v2';
  UI.CTL_PREFIX =
    'CTL=/data/adb/modules/wifi_priority_manager/scripts/wifi_ctl.sh; ' +
    '[ -f ./scripts/wifi_ctl.sh ] && CTL=./scripts/wifi_ctl.sh; ' +
    '/system/bin/sh "$CTL"';

  UI.SEC_LABELS = {
    open: 'Open 无密码',
    owe: 'OWE 增强开放',
    wpa2: 'WPA2-PSK',
    wpa3: 'WPA3-SAE',
    wep: 'WEP',
    eap: '802.1X EAP',
    auto: '自动匹配',
  };

  UI.state = {
    isKsu: typeof window.ksu !== 'undefined' && typeof window.ksu.exec === 'function',
    status: null,
    savedNetworks: [],
    scanMap: {},
    config: {
      enabled: true,
      preempt_enabled: true,
      check_interval_sec: 30,
      rssi_threshold: -78,
      cooldown_sec: 45,
      screen_off_multiplier: 2,
      priority_list: [],
    },
    dirty: false,
    busy: false,
    refreshing: false,
    refreshPromise: null,
    pollTimer: null,
    postSwitchTimer: null,
    lastLiveSig: '',
    lastLogsText: '',
    editIndex: -1,
    snackTimer: null,
  };

  UI.el = {
    envBadge: document.getElementById('env-badge'),
    btnRefresh: document.getElementById('btn-refresh'),
    statusSsid: document.getElementById('status-ssid'),
    statusDetail: document.getElementById('status-detail'),
    daemonPill: document.getElementById('daemon-pill'),
    daemonPillText: document.getElementById('daemon-pill-text'),
    chipRssi: document.getElementById('chip-rssi'),
    chipBand: document.getElementById('chip-band'),
    chipIp: document.getElementById('chip-ip'),
    btnEnforce: document.getElementById('btn-enforce'),
    btnDaemonToggle: document.getElementById('btn-daemon-toggle'),
    btnDaemonLabel: document.getElementById('btn-daemon-label'),
    cfgEnabled: document.getElementById('cfg-enabled'),
    cfgPreempt: document.getElementById('cfg-preempt'),
    cfgInterval: document.getElementById('cfg-interval'),
    cfgRssi: document.getElementById('cfg-rssi'),
    cfgCooldown: document.getElementById('cfg-cooldown'),
    queueCountBadge: document.getElementById('queue-count-badge'),
    priorityList: document.getElementById('priority-list'),
    emptyState: document.getElementById('empty-state'),
    btnOpenAdd: document.getElementById('btn-open-add'),
    logsBox: document.getElementById('logs-box'),
    btnLogsRefresh: document.getElementById('btn-logs-refresh'),
    btnLogsClear: document.getElementById('btn-logs-clear'),
    dirtyDot: document.getElementById('dirty-dot'),
    saveHint: document.getElementById('save-hint'),
    btnSave: document.getElementById('btn-save'),
    addBackdrop: document.getElementById('add-modal-backdrop'),
    addModalTitle: document.getElementById('add-modal-title'),
    selectFieldBox: document.getElementById('select-field-box'),
    addSelect: document.getElementById('add-wifi-select'),
    selectHelper: document.getElementById('select-helper'),
    manualFields: document.getElementById('manual-fields'),
    manualSsid: document.getElementById('manual-ssid'),
    manualSecurity: document.getElementById('manual-security'),
    manualPasswordGroup: document.getElementById('manual-password-group'),
    manualPassword: document.getElementById('manual-password'),
    btnTogglePw: document.getElementById('btn-toggle-pw'),
    btnAddCancel: document.getElementById('btn-add-cancel'),
    btnAddConfirm: document.getElementById('btn-add-confirm'),
    snackbar: document.getElementById('snackbar'),
  };
})();
