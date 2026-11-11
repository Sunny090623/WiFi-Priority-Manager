(() => {
  'use strict';

  const UI = window.WifiUI;
  const { state, el } = UI;

  function collectStrategyToConfig() {
    state.config.enabled = el.cfgEnabled.checked;
    state.config.preempt_enabled = el.cfgPreempt.checked;
    state.config.check_interval_sec = Math.min(300, Math.max(15, parseInt(el.cfgInterval.value || '30', 10)));
    state.config.rssi_threshold = Math.min(-30, Math.max(-95, parseInt(el.cfgRssi.value || '-78', 10)));
    state.config.cooldown_sec = Math.min(300, Math.max(10, parseInt(el.cfgCooldown.value || '45', 10)));
  }

  async function saveConfig() {
    if (state.busy) return;
    collectStrategyToConfig();
    state.busy = true;
    el.btnSave.disabled = true;
    try {
      const payload = UI.encodeUtf8Base64(JSON.stringify(state.config));
      const res = await UI.apiCall('save_config', payload);
      if (res && res.ok) {
        if (res.config) state.config = res.config;
        UI.setDirty(false);
        UI.renderStrategy();
        UI.renderPriorityList();
        UI.showToast('配置已保存并生效');
        await refreshLogs();
      } else {
        UI.showToast(`保存失败: ${(res && res.error) || '未知错误'}`);
      }
    } catch (err) {
      UI.showToast(`保存失败: ${err.message}`);
    } finally {
      state.busy = false;
      el.btnSave.disabled = false;
    }
  }

  async function refreshLogs(forceScroll = false) {
    try {
      const res = await UI.apiCall('get_logs', '80');
      const lines = (res && res.logs) || [];
      const nextText = lines.length > 0 ? lines.join('\n') : '暂无运行日志';
      if (nextText !== state.lastLogsText || forceScroll) {
        state.lastLogsText = nextText;
        el.logsBox.textContent = nextText;
        el.logsBox.scrollTop = el.logsBox.scrollHeight;
      }
    } catch (err) {
      el.logsBox.textContent = `日志读取失败: ${err.message}`;
    }
  }

  async function refreshLiveState() {
    if (state.refreshing) return state.refreshPromise;
    state.refreshing = true;
    state.refreshPromise = (async () => {
      try {
        const [statusRes, scanRes] = await Promise.all([
          UI.apiCall('status'),
          UI.apiCall('scan_results').catch(() => ({ scan_results: [] })),
        ]);
        state.status = statusRes;
        UI.applyScanResults(scanRes);
        UI.renderStatus();

        const nextSig = UI.computeLiveSignature();
        if (nextSig !== state.lastLiveSig) {
          state.lastLiveSig = nextSig;
          UI.renderPriorityList();
        }
        await refreshLogs();
      } catch (_) {
        // Silent during background polling to avoid toast spam
      } finally {
        state.refreshing = false;
        state.refreshPromise = null;
      }
    })();
    return state.refreshPromise;
  }

  async function refreshAll(options = {}) {
    const showFeedback = Boolean(options && options.showFeedback);
    if (state.refreshing && state.refreshPromise) {
      if (!showFeedback) return state.refreshPromise;
      try {
        await state.refreshPromise;
      } catch (_) {}
    }

    state.refreshing = true;
    if (showFeedback) {
      el.btnRefresh.disabled = true;
      el.btnRefresh.classList.add('is-spinning');
    }

    state.refreshPromise = (async () => {
      try {
        const [statusRes, savedRes, cfgRes, scanRes] = await Promise.all([
          UI.apiCall('status'),
          UI.apiCall('saved_networks').catch(() => null),
          UI.apiCall('get_config').catch(() => null),
          UI.apiCall('scan_results').catch(() => ({ scan_results: [] })),
        ]);

        state.status = statusRes;
        if (savedRes && Array.isArray(savedRes.networks)) {
          state.savedNetworks = savedRes.networks;
        }
        UI.applyScanResults(scanRes);

        if (!state.dirty && cfgRes && Array.isArray(cfgRes.priority_list)) {
          state.config = cfgRes;
          UI.renderStrategy();
        }

        UI.renderStatus();
        UI.renderPriorityList();
        state.lastLiveSig = UI.computeLiveSignature();
        await refreshLogs(showFeedback);

        if (showFeedback) {
          const st = state.status;
          if (st && st.connected && st.ssid) {
            UI.showToast(`状态已刷新: ${st.ssid}`);
          } else if (st && !st.wifi_enabled) {
            UI.showToast('状态已刷新: WiFi 已关闭');
          } else {
            UI.showToast('状态已刷新');
          }
        }
      } catch (err) {
        UI.showToast(`加载状态失败: ${err.message}`);
      } finally {
        state.refreshing = false;
        state.refreshPromise = null;
        if (showFeedback) {
          el.btnRefresh.disabled = false;
          el.btnRefresh.classList.remove('is-spinning');
        }
      }
    })();

    return state.refreshPromise;
  }

  function startAutoRefresh() {
    stopAutoRefresh();
    state.pollTimer = setInterval(() => {
      if (document.visibilityState === 'visible' && !state.busy && !state.refreshing) {
        refreshLiveState();
      }
    }, 4000);
  }

  function stopAutoRefresh() {
    if (state.pollTimer) {
      clearInterval(state.pollTimer);
      state.pollTimer = null;
    }
  }

  async function runEnforceNow() {
    if (state.busy) return;
    if (state.dirty) {
      await saveConfig();
    }
    state.busy = true;
    el.btnEnforce.disabled = true;
    try {
      const res = await UI.apiCall('enforce_once', '--force');
      if (res.action === 'connect') {
        UI.showToast(`正在切换至 #${res.rank} ${res.target_ssid} (${res.rssi} dBm)`);
      } else if (res.action === 'hold') {
        UI.showToast(`已处于最优可用网络 #${res.rank} ${res.current_ssid}`);
      } else if (res.reason === 'already_highest_priority') {
        UI.showToast(`已连接第 1 顺位 ${res.current_ssid}`);
      } else if (res.reason === 'wifi_disabled') {
        UI.showToast('系统 WiFi 已关闭，未执行操作');
      } else if (res.reason === 'empty_priority_list') {
        UI.showToast('请先添加至少一个常驻 WiFi');
      } else if (res.reason === 'no_configured_wifi_in_range') {
        UI.showToast('当前未扫描到列表中的常驻 WiFi');
      } else if (res.action === 'error') {
        UI.showToast(`连接失败: ${res.error || '未知错误'}`);
      } else {
        UI.showToast(`检测完成: ${res.reason || res.action || 'OK'}`);
      }
      await refreshAll();
      if (res.action === 'connect') {
        clearTimeout(state.postSwitchTimer);
        state.postSwitchTimer = setTimeout(refreshLiveState, 2000);
      }
    } catch (err) {
      UI.showToast(`执行失败: ${err.message}`);
    } finally {
      state.busy = false;
      el.btnEnforce.disabled = false;
    }
  }

  async function toggleDaemon() {
    if (state.busy) return;
    state.busy = true;
    el.btnDaemonToggle.disabled = true;
    const isRunning = state.status && state.status.daemon_running;
    try {
      const res = await UI.apiCall('daemon_control', isRunning ? 'stop' : 'start');
      UI.showToast(res.running ? `守护进程已启动 (PID ${res.pid})` : '守护进程已停止');
      await refreshAll();
    } catch (err) {
      UI.showToast(`守护操作失败: ${err.message}`);
    } finally {
      state.busy = false;
      el.btnDaemonToggle.disabled = false;
    }
  }

  UI.saveConfig = saveConfig;
  UI.refreshLogs = refreshLogs;
  UI.refreshLiveState = refreshLiveState;
  UI.refreshAll = refreshAll;
  UI.startAutoRefresh = startAutoRefresh;
  UI.stopAutoRefresh = stopAutoRefresh;
  UI.runEnforceNow = runEnforceNow;
  UI.toggleDaemon = toggleDaemon;
})();
