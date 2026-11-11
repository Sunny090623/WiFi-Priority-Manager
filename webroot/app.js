(() => {
  'use strict';

  const UI = window.WifiUI;
  const { state, el } = UI;

  function initEvents() {
    el.btnRefresh.addEventListener('click', () => UI.refreshAll({ showFeedback: true }));
    el.btnEnforce.addEventListener('click', UI.runEnforceNow);
    el.btnDaemonToggle.addEventListener('click', UI.toggleDaemon);
    el.btnSave.addEventListener('click', UI.saveConfig);
    el.btnOpenAdd.addEventListener('click', UI.openAddModal);
    el.btnAddCancel.addEventListener('click', UI.closeAddModal);
    el.btnAddConfirm.addEventListener('click', UI.confirmAddWifi);
    el.addSelect.addEventListener('change', UI.syncManualFieldsVisibility);
    el.manualSecurity.addEventListener('change', UI.syncManualFieldsVisibility);

    el.addBackdrop.addEventListener('click', (e) => {
      if (e.target === el.addBackdrop) UI.closeAddModal();
    });

    el.btnTogglePw.addEventListener('click', () => {
      el.manualPassword.type = el.manualPassword.type === 'password' ? 'text' : 'password';
    });

    [el.cfgEnabled, el.cfgPreempt, el.cfgInterval, el.cfgRssi, el.cfgCooldown].forEach((input) => {
      input.addEventListener('change', () => UI.setDirty(true));
    });

    el.btnLogsRefresh.addEventListener('click', () => UI.refreshLogs(true));
    el.btnLogsClear.addEventListener('click', async () => {
      await UI.apiCall('clear_logs');
      state.lastLogsText = '';
      await UI.refreshLogs(true);
      UI.showToast('日志已清空');
    });

    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        UI.startAutoRefresh();
        UI.refreshAll();
      } else {
        UI.stopAutoRefresh();
      }
    });

    window.addEventListener('focus', () => {
      if (document.visibilityState === 'visible' && !state.busy) {
        UI.refreshLiveState();
      }
    });

    window.addEventListener('online', () => {
      if (!state.busy) {
        UI.refreshLiveState();
        clearTimeout(state.postSwitchTimer);
        state.postSwitchTimer = setTimeout(UI.refreshLiveState, 1800);
      }
    });
  }

  function init() {
    el.envBadge.textContent = state.isKsu ? 'KsuWebUI Root 已就绪' : '浏览器预览模式 (Mock)';
    el.envBadge.className = `badge ${state.isKsu ? 'badge-success' : 'badge-primary'}`;
    initEvents();
    UI.refreshAll();
    UI.startAutoRefresh();
  }

  init();
})();
