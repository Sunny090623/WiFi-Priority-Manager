(() => {
  'use strict';

  const UI = window.WifiUI;
  const { state, el } = UI;

  function syncManualFieldsVisibility() {
    const isManual = state.editIndex >= 0 || el.addSelect.value === UI.MANUAL_OPTION_VALUE;
    el.manualFields.classList.toggle('hidden', !isManual);
    const sec = el.manualSecurity.value;
    const needsPass = sec !== 'open' && sec !== 'owe';
    el.manualPasswordGroup.classList.toggle('hidden', !needsPass);
  }

  function populateAddSelect() {
    const configuredSet = new Set((state.config.priority_list || []).map((x) => x.ssid));
    el.addSelect.innerHTML = '';

    const available = (state.savedNetworks || []).filter((n) => !configuredSet.has(n.ssid));
    if (available.length > 0) {
      available.forEach((n) => {
        const opt = document.createElement('option');
        opt.value = n.ssid;
        opt.dataset.security = n.security || 'auto';
        const secLabel = UI.SEC_LABELS[n.security] || n.security;
        if (!n.connectable) {
          opt.disabled = true;
          opt.textContent = `${n.ssid} (${secLabel} - 暂不支持自动触发)`;
        } else {
          opt.textContent = `${n.ssid} (${secLabel})`;
        }
        el.addSelect.appendChild(opt);
      });
    }

    const manualOpt = document.createElement('option');
    manualOpt.value = UI.MANUAL_OPTION_VALUE;
    manualOpt.textContent = '➕ 手动输入...';
    el.addSelect.appendChild(manualOpt);

    const firstEnabled = Array.from(el.addSelect.options).find((o) => !o.disabled);
    el.addSelect.value = firstEnabled ? firstEnabled.value : UI.MANUAL_OPTION_VALUE;
    syncManualFieldsVisibility();
  }

  function openAddModal() {
    state.editIndex = -1;
    el.addModalTitle.textContent = '添加常驻 WiFi';
    el.btnAddConfirm.textContent = '添加到队列';
    el.selectFieldBox.classList.remove('hidden');
    el.manualSsid.value = '';
    el.manualSecurity.value = 'wpa2';
    el.manualPassword.value = '';
    el.manualPassword.placeholder = '输入 WiFi 密码';
    el.manualPassword.type = 'password';
    populateAddSelect();
    el.addBackdrop.classList.remove('hidden');
  }

  function openEditModal(idx) {
    const list = state.config.priority_list || [];
    const item = list[idx];
    if (!item) return;
    state.editIndex = idx;
    el.addModalTitle.textContent = '编辑常驻 WiFi';
    el.btnAddConfirm.textContent = '保存修改';
    el.selectFieldBox.classList.add('hidden');
    el.manualSsid.value = item.ssid || '';
    el.manualSecurity.value = item.security && item.security !== 'auto' ? item.security : 'wpa2';
    el.manualPassword.value = '';
    el.manualPassword.placeholder = item.has_password ? '留空则保留原密码' : '输入 WiFi 密码';
    el.manualPassword.type = 'password';
    syncManualFieldsVisibility();
    el.addBackdrop.classList.remove('hidden');
  }

  function closeAddModal() {
    state.editIndex = -1;
    el.addBackdrop.classList.add('hidden');
  }

  function confirmAddWifi() {
    const list = state.config.priority_list || (state.config.priority_list = []);

    if (state.editIndex >= 0) {
      const idx = state.editIndex;
      const prev = list[idx];
      const ssid = el.manualSsid.value.trim();
      const security = el.manualSecurity.value;
      const password = el.manualPassword.value;
      const needsPass = security !== 'open' && security !== 'owe';
      const ssidChanged = prev ? ssid !== prev.ssid : true;

      if (!ssid) {
        UI.showToast('请输入 WiFi SSID 名称');
        el.manualSsid.focus();
        return;
      }
      if (list.some((x, i) => i !== idx && x.ssid === ssid)) {
        UI.showToast('该 WiFi 已在优先级队列中');
        return;
      }
      if (needsPass && !password && (ssidChanged || !prev || !prev.has_password)) {
        UI.showToast('WPA2 / WPA3 网络需要输入密码');
        el.manualPassword.focus();
        return;
      }

      const keepPw = needsPass && !password && !ssidChanged && Boolean(prev && prev.has_password);
      list[idx] = {
        ssid,
        source: 'manual',
        security,
        password: needsPass ? password : '',
        has_password: needsPass ? (Boolean(password) || keepPw) : false,
        keep_password: keepPw,
      };
      UI.setDirty(true);
      UI.renderPriorityList();
      closeAddModal();
      UI.showToast('已更新条目，请记得点击“保存配置”');
      return;
    }

    const choice = el.addSelect.value;

    if (choice === UI.MANUAL_OPTION_VALUE) {
      const ssid = el.manualSsid.value.trim();
      const security = el.manualSecurity.value;
      const password = el.manualPassword.value;

      if (!ssid) {
        UI.showToast('请输入 WiFi SSID 名称');
        el.manualSsid.focus();
        return;
      }
      if (list.some((x) => x.ssid === ssid)) {
        UI.showToast('该 WiFi 已在优先级队列中');
        return;
      }
      if ((security === 'wpa2' || security === 'wpa3') && !password) {
        UI.showToast('WPA2 / WPA3 网络需要输入密码');
        el.manualPassword.focus();
        return;
      }

      list.push({
        ssid,
        source: 'manual',
        security,
        password: security === 'open' || security === 'owe' ? '' : password,
        has_password: Boolean(password),
        keep_password: false,
      });
    } else {
      const selectedOpt = el.addSelect.selectedOptions[0];
      if (!selectedOpt || selectedOpt.disabled) {
        UI.showToast('请选择有效的 WiFi 或使用手动输入');
        return;
      }
      const ssid = choice;
      const security = selectedOpt.dataset.security || 'auto';
      if (list.some((x) => x.ssid === ssid)) {
        UI.showToast('该 WiFi 已在优先级队列中');
        return;
      }
      list.push({
        ssid,
        source: 'saved',
        security,
        has_password: false,
        keep_password: false,
      });
    }

    UI.setDirty(true);
    UI.renderPriorityList();
    closeAddModal();
    UI.showToast('已加入队列，请记得点击“保存配置”');
  }

  UI.syncManualFieldsVisibility = syncManualFieldsVisibility;
  UI.openAddModal = openAddModal;
  UI.openEditModal = openEditModal;
  UI.closeAddModal = closeAddModal;
  UI.confirmAddWifi = confirmAddWifi;
})();
