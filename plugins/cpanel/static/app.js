const API_ENDPOINT = 'index.php';
const logOutput = document.getElementById('logOutput');
const toast = document.getElementById('toast');
const statusBadge = document.getElementById('statusBadge');
const updatedAt = document.getElementById('updatedAt');
const metricFields = Array.from(document.querySelectorAll('[data-field]'));
const domainGrid = document.getElementById('domainGrid');

async function apiRequest(action, payload = {}) {
    const response = await fetch(`${API_ENDPOINT}?action=${encodeURIComponent(action)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        credentials: 'same-origin',
        body: JSON.stringify({ ...payload, action }),
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

function log(message) {
    const line = `[${new Date().toLocaleTimeString()}] ${message}`;
    logOutput.textContent = `${line}\n${logOutput.textContent}`;
}

function toastMessage(message, tone = 'info') {
    toast.textContent = message;
    toast.className = `toast show ${tone}`;
    setTimeout(() => toast.classList.remove('show'), 3000);
}

function updateMetrics(data) {
    if (!data) { return; }
    metricFields.forEach((field) => {
        const path = field.dataset.field.split('.');
        let cursor = data;
        for (const key of path) {
            if (cursor && Object.prototype.hasOwnProperty.call(cursor, key)) {
                cursor = cursor[key];
            } else {
                cursor = undefined;
                break;
            }
        }
        if (cursor !== undefined) {
            field.textContent = cursor;
        }
    });
    const varnishState = data.services?.varnish || 'unknown';
    statusBadge.textContent = `Cache: ${varnishState}`;
    statusBadge.style.background = varnishState === 'active' ? 'rgba(16, 185, 129, 0.25)' : 'rgba(220, 38, 38, 0.25)';
    updatedAt.textContent = `Updated ${new Date().toLocaleTimeString()}`;
}

function renderDomains(domains) {
    if (!domains || !domains.main_domain) {
        domainGrid.innerHTML = '<p class="muted">No domains detected for this account.</p>';
        return;
    }

    const allDomains = new Set();
    ['main_domain', 'addon_domains', 'parked_domains', 'sub_domains'].forEach((key) => {
        const entries = domains[key];
        if (Array.isArray(entries)) {
            entries.forEach((d) => allDomains.add(d));
        } else if (typeof entries === 'string' && entries) {
            allDomains.add(entries);
        }
    });

    if (!allDomains.size) {
        domainGrid.innerHTML = '<p class="muted">No domains available.</p>';
        return;
    }

    domainGrid.innerHTML = '';
    allDomains.forEach((domain) => {
        const card = document.createElement('div');
        card.className = 'domain-card';
        card.innerHTML = `
            <strong>${domain}</strong>
            <span class="badge">Accelerated</span>
            <div class="domain-actions">
                <button class="btn primary" data-domain="${domain}"><i class="fas fa-bolt"></i> Purge</button>
                <a class="btn" href="https://${domain}" target="_blank" rel="noopener"><i class="fas fa-arrow-up-right-from-square"></i> Visit</a>
            </div>
        `;
        card.querySelector('[data-domain]').addEventListener('click', () => purgeDomain(domain));
        domainGrid.appendChild(card);
    });
}

async function refreshStatus() {
    try {
        const result = await apiRequest('status');
        updateMetrics(result.data);
    } catch (error) {
        log(`Status refresh failed: ${error.message}`);
        toastMessage('Unable to refresh status', 'error');
    }
}

async function refreshDomains() {
    try {
        const result = await apiRequest('domains');
        renderDomains(result.domains);
    } catch (error) {
        log(`Domain load failed: ${error.message}`);
        domainGrid.innerHTML = '<p class="muted">Failed to load domains.</p>';
    }
}

async function purgeDomain(domain) {
    toggleButtons(true);
    log(`Purging domain ${domain}`);
    try {
        await apiRequest('purge', { url: `https://${domain}` });
        log(`Domain ${domain} purge sent`);
        toastMessage('Domain purge requested');
    } catch (error) {
        log(`Domain purge failed: ${error.message}`);
        toastMessage('Domain purge failed', 'error');
    } finally {
        toggleButtons(false);
    }
}

async function purgeUrl(event) {
    event.preventDefault();
    const input = document.getElementById('purgeUrl');
    toggleButtons(true);
    log(`Purging URL ${input.value}`);
    try {
        await apiRequest('purge', { url: input.value });
        log('URL purge sent');
        toastMessage('URL purge requested');
        input.value = '';
    } catch (error) {
        log(`URL purge failed: ${error.message}`);
        toastMessage('URL purge failed', 'error');
    } finally {
        toggleButtons(false);
    }
}

async function flushAll() {
    if (!confirm('Flush all cached content for your account?')) {
        return;
    }
    toggleButtons(true);
    log('Flushing entire cache for account');
    try {
        await apiRequest('flush');
        log('Flush request sent');
        toastMessage('Cache flush requested');
    } catch (error) {
        log(`Flush failed: ${error.message}`);
        toastMessage('Flush failed', 'error');
    } finally {
        toggleButtons(false);
    }
}

function toggleButtons(disabled) {
    document.querySelectorAll('button').forEach((btn) => {
        btn.disabled = disabled;
    });
}

function bootstrap() {
    document.getElementById('purgeForm').addEventListener('submit', purgeUrl);
    document.getElementById('flushBtn').addEventListener('click', flushAll);
    refreshStatus();
    refreshDomains();
    setInterval(refreshStatus, 30000);
}

bootstrap();
