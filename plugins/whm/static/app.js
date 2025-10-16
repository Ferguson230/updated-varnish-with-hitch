const API_ENDPOINT = 'varnish_manager.cgi';
const activityLog = document.getElementById('activityLog');
const stateLabel = document.getElementById('stackState');
const timestamp = document.getElementById('statusTimestamp');
const toast = document.getElementById('toast');
const securityForm = document.getElementById('securityForm');
const securityEnabled = document.getElementById('securityEnabled');
const securityIncludeSubdomains = document.getElementById('securityIncludeSubdomains');
const securityPreload = document.getElementById('securityPreload');
const securityMaxAge = document.getElementById('securityMaxAge');
const securityFrameOptions = document.getElementById('securityFrameOptions');
const securityReferrerPolicy = document.getElementById('securityReferrerPolicy');
const securityPermissionsPolicy = document.getElementById('securityPermissionsPolicy');

const metricFields = Array.from(document.querySelectorAll('[data-field]'));

async function apiRequest(action, payload = {}) {
    const body = JSON.stringify({ ...payload, action });
    const response = await fetch(`${API_ENDPOINT}?action=${encodeURIComponent(action)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body,
        credentials: 'same-origin',
    });
    if (!response.ok) {
        throw new Error(`Request failed (${response.status})`);
    }
    const data = await response.json();
    if (data.status === 'error') {
        throw new Error(data.message || 'Operation failed');
    }
    return data;
}

function logLine(message) {
    const ts = new Date().toLocaleString();
    activityLog.textContent = `[${ts}] ${message}\n${activityLog.textContent}`;
}

function showToast(message, tone = 'info') {
    toast.textContent = message;
    toast.className = `toast show ${tone}`;
    setTimeout(() => toast.classList.remove('show'), 3500);
}

function updateMetricsView(data) {
    if (!data) { return; }
    metricFields.forEach((field) => {
        const path = field.dataset.field.split('.');
        let cursor = data;
        for (const part of path) {
            if (cursor && Object.prototype.hasOwnProperty.call(cursor, part)) {
                cursor = cursor[part];
            } else {
                cursor = undefined;
                break;
            }
        }
        if (cursor === undefined) { return; }
        field.textContent = cursor;
    });
    const varnishState = data.services?.varnish || 'unknown';
    stateLabel.textContent = `Stack: ${varnishState}`;
    stateLabel.style.background = varnishState === 'active' ? 'rgba(0, 163, 42, 0.2)' : 'rgba(204, 24, 24, 0.2)';
    timestamp.textContent = `Last updated ${new Date().toLocaleTimeString()}`;
}

async function refreshStatus() {
    try {
        const result = await apiRequest('status');
        updateMetricsView(result.data);
    } catch (error) {
        logLine(`Status refresh failed: ${error.message}`);
        showToast('Unable to refresh status', 'error');
    }
}

async function handleProvision() {
    toggleButtons(true);
    logLine('Starting provisioning workflow');
    try {
        await apiRequest('install');
        logLine('Provisioning completed');
        showToast('Provisioning completed');
        await refreshStatus();
    } catch (error) {
        logLine(`Provisioning failed: ${error.message}`);
        showToast('Provisioning failed', 'error');
    } finally {
        toggleButtons(false);
    }
}

async function handleCertSync() {
    toggleButtons(true);
    logLine('Syncing certificates to Hitch');
    try {
        await apiRequest('update_certs');
        logLine('Certificate sync completed');
        showToast('Certificates synced');
    } catch (error) {
        logLine(`Certificate sync failed: ${error.message}`);
        showToast('Certificate sync failed', 'error');
    } finally {
        toggleButtons(false);
    }
}

async function serviceControl(action) {
    toggleButtons(true);
    logLine(`Service action requested: ${action}`);
    try {
        await apiRequest('service', { operation: action });
        logLine(`Service ${action} completed`);
        showToast(`Service ${action} succeeded`);
        await refreshStatus();
    } catch (error) {
        logLine(`Action ${action} failed: ${error.message}`);
        showToast(`Action ${action} failed`, 'error');
    } finally {
        toggleButtons(false);
    }
}

async function purgeUrl(event) {
    event.preventDefault();
    const input = document.getElementById('purgeUrl');
    if (!input.value) {
        showToast('Enter a URL to purge', 'warning');
        return;
    }
    toggleButtons(true);
    logLine(`Purging URL ${input.value}`);
    try {
        await apiRequest('purge', { scope: 'url', url: input.value });
        logLine('URL purged successfully');
        showToast('URL purged');
        input.value = '';
    } catch (error) {
        logLine(`URL purge failed: ${error.message}`);
        showToast('URL purge failed', 'error');
    } finally {
        toggleButtons(false);
    }
}

async function flushAll() {
    if (!confirm('This will ban every cached object. Continue?')) {
        return;
    }
    toggleButtons(true);
    logLine('Flushing entire cache store');
    try {
        await apiRequest('purge', { scope: 'all' });
        logLine('Global flush requested');
        showToast('Full cache flush issued');
    } catch (error) {
        logLine(`Global flush failed: ${error.message}`);
        showToast('Flush failed', 'error');
    } finally {
        toggleButtons(false);
    }
}

function toggleButtons(disabled) {
    document.querySelectorAll('button').forEach((btn) => {
        btn.disabled = disabled;
    });
}

function applySecuritySettingsForm(settings) {
    if (!securityForm) { return; }
    const sec = settings?.security_headers || {};
    securityEnabled.checked = !!sec.enabled;
    securityIncludeSubdomains.checked = !!sec.include_subdomains;
    securityPreload.checked = !!sec.preload;
    securityMaxAge.value = sec.max_age ?? 31536000;
    securityFrameOptions.value = sec.frame_options ?? 'SAMEORIGIN';
    securityReferrerPolicy.value = sec.referrer_policy ?? 'strict-origin-when-cross-origin';
    securityPermissionsPolicy.value = sec.permissions_policy ?? 'geolocation=()';
    toggleSecurityFields();
}

function toggleSecurityFields() {
    if (!securityForm) { return; }
    const disabled = !securityEnabled.checked;
    [
        securityIncludeSubdomains,
        securityPreload,
        securityMaxAge,
        securityFrameOptions,
        securityReferrerPolicy,
        securityPermissionsPolicy,
    ].forEach((field) => {
        field.disabled = disabled;
    });
}

async function loadSecuritySettings() {
    if (!securityForm) { return; }
    try {
        const result = await apiRequest('settings_get');
        applySecuritySettingsForm(result.settings);
        logLine('Loaded security header settings');
    } catch (error) {
        logLine(`Unable to load settings: ${error.message}`);
        showToast('Failed to load security settings', 'error');
    }
}

async function handleSecuritySubmit(event) {
    event.preventDefault();
    toggleButtons(true);
    logLine('Updating security header policy');
    try {
        let maxAge = Number.parseInt(securityMaxAge.value, 10);
        if (Number.isNaN(maxAge) || maxAge < 0) {
            maxAge = 31536000;
        }
        const payload = {
            security_headers: {
                enabled: securityEnabled.checked,
                include_subdomains: securityIncludeSubdomains.checked,
                preload: securityPreload.checked,
                max_age: maxAge,
                frame_options: securityFrameOptions.value.trim(),
                referrer_policy: securityReferrerPolicy.value.trim(),
                permissions_policy: securityPermissionsPolicy.value.trim(),
            },
        };
        const result = await apiRequest('settings_update', payload);
        applySecuritySettingsForm(result.settings);
        logLine('Security headers updated and Varnish reloaded');
        showToast('Security policy applied');
    } catch (error) {
        logLine(`Security update failed: ${error.message}`);
        showToast('Failed to update security policy', 'error');
    } finally {
        toggleButtons(false);
    }
}

function bootstrap() {
    document.querySelectorAll('[data-action]').forEach((btn) => {
        btn.addEventListener('click', () => serviceControl(btn.dataset.action));
    });
    document.getElementById('provisionBtn').addEventListener('click', handleProvision);
    document.getElementById('certSyncBtn').addEventListener('click', handleCertSync);
    document.getElementById('flushAll').addEventListener('click', flushAll);
    document.getElementById('purgeForm').addEventListener('submit', purgeUrl);
    if (securityForm) {
        securityForm.addEventListener('submit', handleSecuritySubmit);
        securityEnabled.addEventListener('change', toggleSecurityFields);
        loadSecuritySettings();
    }
    refreshStatus();
    setInterval(refreshStatus, 30000);
}

bootstrap();
