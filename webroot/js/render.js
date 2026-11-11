(() => {
  'use strict';

  const UI = window.WifiUI;
  const { state, el } = UI;

  function setDirty(dirty) {
    state.dirty = dirty;
    el.dirtyDot.classList.toggle('hidden', !dirty);
    el.saveHint.textContent = dirty ? '有未保存的更改' : '配置已同步';
  }

  function formatBand(mhz) {
    if (!mhz || mhz <= 0) return '--';
    if (mhz >= 5925) return '6 GHz';
    if (mhz >= 4900) return '5 GHz';
    return '2.4 GHz';
  }

  function makeIconButton(label, disabled, pathD, onClick, isDanger = false) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `icon-btn${isDanger ? ' icon-btn-danger' : ''}`;
    btn.title = label;
    btn.setAttribute('aria-label', label);
    btn.disabled = disabled;
    btn.innerHTML = `<svg viewBox="0 0 24 24" width="18" height="18" fill="currentColor"><path d="${pathD}"/></svg>`;
    btn.addEventListener('click', onClick);
    return btn;
  }

  function renderStatus() {
    const st = state.status;
    if (!st) return;

    if (!st.wifi_enabled) {
      el.statusSsid.textContent = 'WiFi 已关闭';
      el.statusDetail.textContent = '尊重系统 WiFi 开关状态，暂不干预';
    } else if (st.connected && st.ssid) {
      el.statusSsid.textContent = st.ssid;
      el.statusDetail.textContent = `状态: ${st.supplicant_state || 'COMPLETED'}`;
    } else {
      el.statusSsid.textContent = '未连接 WiFi';
      el.statusDetail.textContent = '等待检测到队列中的可用网络';
    }

    el.chipRssi.textContent = st.connected && st.rssi > -120 ? `信号: ${st.rssi} dBm` : '信号: --';
    el.chipBand.textContent = `频段: ${formatBand(st.frequency_mhz)}`;
    el.chipIp.textContent = `IP: ${st.ip || '--'}`;

    const running = Boolean(st.daemon_running);
    el.daemonPill.className = `status-pill ${running ? 'pill-on' : 'pill-off'}`;
    el.daemonPillText.textContent = running ? `守护运行中 (${st.daemon_pid})` : '守护未运行';
    el.btnDaemonLabel.textContent = running ? '停止守护' : '启动守护';
  }

  function renderStrategy() {
    const c = state.config;
    el.cfgEnabled.checked = Boolean(c.enabled);
    el.cfgPreempt.checked = Boolean(c.preempt_enabled);
    el.cfgInterval.value = c.check_interval_sec ?? 30;
    el.cfgRssi.value = c.rssi_threshold ?? -78;
    el.cfgCooldown.value = c.cooldown_sec ?? 45;
  }

  function renderPriorityList() {
    const list = state.config.priority_list || [];
    el.queueCountBadge.textContent = `${list.length} 项`;
    el.priorityList.innerHTML = '';
    el.emptyState.classList.toggle('hidden', list.length > 0);

    const currentSsid = state.status && state.status.connected ? state.status.ssid : '';

    list.forEach((item, idx) => {
      const row = document.createElement('div');
      const isCurrent = currentSsid && currentSsid === item.ssid;
      row.className = `queue-item${isCurrent ? ' is-connected' : ''}`;

      const left = document.createElement('div');
      left.className = 'queue-left';

      const rank = document.createElement('div');
      rank.className = 'rank-badge';
      rank.textContent = `#${idx + 1}`;

      const meta = document.createElement('div');
      meta.className = 'queue-meta';

      const title = document.createElement('div');
      title.className = 'queue-ssid';
      title.textContent = item.ssid;

      const tags = document.createElement('div');
      tags.className = 'queue-tags';

      const srcBadge = document.createElement('span');
      srcBadge.className = 'badge badge-neutral';
      srcBadge.textContent = item.source === 'manual' ? '手动输入' : '系统已保存';
      tags.appendChild(srcBadge);

      const secBadge = document.createElement('span');
      secBadge.className = 'badge badge-neutral';
      secBadge.textContent = UI.SEC_LABELS[item.security] || item.security || '自动';
      tags.appendChild(secBadge);

      if (isCurrent) {
        const curBadge = document.createElement('span');
        curBadge.className = 'badge badge-success';
        curBadge.textContent = '当前连接';
        tags.appendChild(curBadge);
      } else if (state.scanMap[item.ssid]) {
        const scanBadge = document.createElement('span');
        scanBadge.className = 'badge badge-primary';
        scanBadge.textContent = `范围内 ${state.scanMap[item.ssid].rssi} dBm`;
        tags.appendChild(scanBadge);
      }

      meta.appendChild(title);
      meta.appendChild(tags);
      left.appendChild(rank);
      left.appendChild(meta);

      const actions = document.createElement('div');
      actions.className = 'queue-actions';

      const btnUp = makeIconButton('上移', idx === 0, 'M7.41 15.41L12 10.83l4.59 4.58L18 14l-6-6-6 6z', () => {
        if (idx === 0) return;
        [list[idx - 1], list[idx]] = [list[idx], list[idx - 1]];
        setDirty(true);
        renderPriorityList();
      });

      const btnDown = makeIconButton('下移', idx === list.length - 1, 'M7.41 8.59L12 13.17l4.59-4.58L18 10l-6 6-6-6z', () => {
        if (idx >= list.length - 1) return;
        [list[idx], list[idx + 1]] = [list[idx + 1], list[idx]];
        setDirty(true);
        renderPriorityList();
      });

      if (item.source === 'manual') {
        const btnEdit = makeIconButton(
          '编辑密码/加密方式',
          false,
          'M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 000-1.41l-2.34-2.34a1 1 0 00-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z',
          () => UI.openEditModal(idx)
        );
        actions.appendChild(btnEdit);
      }

      const btnDel = makeIconButton(
        '删除',
        false,
        'M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z',
        () => {
          list.splice(idx, 1);
          setDirty(true);
          renderPriorityList();
        },
        true
      );

      actions.appendChild(btnUp);
      actions.appendChild(btnDown);
      actions.appendChild(btnDel);

      row.appendChild(left);
      row.appendChild(actions);
      el.priorityList.appendChild(row);
    });
  }

  function applyScanResults(scanRes) {
    const scanArr = (scanRes && scanRes.scan_results) || [];
    state.scanMap = {};
    scanArr.forEach((s) => {
      state.scanMap[s.ssid] = s;
    });
  }

  function computeLiveSignature() {
    const st = state.status || {};
    const scanSig = Object.keys(state.scanMap)
      .sort()
      .map((k) => `${k}:${state.scanMap[k].rssi}`)
      .join(',');
    return `${st.wifi_enabled ? 1 : 0}|${st.connected ? 1 : 0}|${st.ssid || ''}|${scanSig}`;
  }

  UI.setDirty = setDirty;
  UI.renderStatus = renderStatus;
  UI.renderStrategy = renderStrategy;
  UI.renderPriorityList = renderPriorityList;
  UI.applyScanResults = applyScanResults;
  UI.computeLiveSignature = computeLiveSignature;
})();
