<?php

// Varnish Manager - cPanel Plugin
// This file acts as the cPanel-native interface to the Varnish management backend

// Ensure the script is run within the cPanel environment
if (!defined('IN_CPANEL')) {
    die('This file cannot be accessed directly.');
}

// Include cPanel's CPANEL class
require_once "/usr/local/cpanel/php/cpanel.php";

// Create a CPANEL object
$cpanel = new CPANEL();

// Get the current cPanel user
$username = $cpanel->cpanelprint('$user');

// Fetch all domains associated with the cPanel user
try {
    $domains_data = $cpanel->uapi('DomainInfo', 'list_domains');
    
    // Extract the list of domains
    $domains = array();
    if (isset($domains_data['cpanelresult']['result']['data']['main_domain'])) {
        $domains[] = $domains_data['cpanelresult']['result']['data']['main_domain'];
    }
    if (isset($domains_data['cpanelresult']['result']['data']['addon_domains'])) {
        $domains = array_merge($domains, $domains_data['cpanelresult']['result']['data']['addon_domains']);
    }
    if (isset($domains_data['cpanelresult']['result']['data']['sub_domains'])) {
        $domains = array_merge($domains, $domains_data['cpanelresult']['result']['data']['sub_domains']);
    }
    if (isset($domains_data['cpanelresult']['result']['data']['parked_domains'])) {
        $domains = array_merge($domains, $domains_data['cpanelresult']['result']['data']['parked_domains']);
    }
} catch (Exception $e) {
    $domains = array();
}

// Get action from request
$action = isset($_REQUEST['action']) ? sanitize_input($_REQUEST['action']) : '';
$domain = isset($_REQUEST['domain']) ? sanitize_input($_REQUEST['domain']) : '';

// Validate that the requested domain belongs to the user
if ($domain && !in_array($domain, $domains)) {
    $error = "You do not have permission to manage cache for this domain.";
}

/**
 * Call varnishctl backend via sudo
 */
function call_varnishctl($action, $domain = null) {
    $cmd_path = '/usr/local/bin/varnishctl';
    $output = '';
    
    if ($action === 'status') {
        // Status command with JSON output
        $cmd = sprintf('sudo %s status --format json 2>&1', escapeshellarg($cmd_path));
    } elseif ($action === 'purge' && $domain) {
        // Purge specific domain - use varnishadm ban command directly
        // Format: ban req.http.host ~ .domain.com
        $cmd = sprintf('sudo varnishadm "ban req.http.host ~ .%s" 2>&1', escapeshellarg($domain));
    } elseif ($action === 'flush') {
        // Flush all cache for user's domains
        $cmd = sprintf('sudo varnishadm "ban req.url ~ ." 2>&1', escapeshellarg($cmd_path));
    } else {
        return array('error' => 'Invalid action');
    }
    
    $output = shell_exec($cmd);
    
    // Try to parse as JSON first (for status command)
    if ($output) {
        $decoded = json_decode($output, true);
        if (is_array($decoded)) {
            return $decoded;
        }
        
        // If it's a purge or flush, check for success indicators
        if ($action === 'purge' || $action === 'flush') {
            // varnishadm returns empty on success
            if (trim($output) === '' || strpos($output, 'error') === false) {
                return array('success' => true, 'message' => ucfirst($action) . ' completed successfully');
            } else {
                return array('error' => trim($output));
            }
        }
    }
    
    // Fallback for status when JSON isn't available
    if ($action === 'status') {
        return array('status' => 'unknown', 'raw_output' => $output);
    }
    
    return array('raw_output' => $output);
}

/**
 * Sanitize user input
 */
function sanitize_input($input) {
    return preg_replace('/[^a-zA-Z0-9._-]/', '', $input);
}

// Handle AJAX requests
if (isset($_REQUEST['ajax']) && $_REQUEST['ajax'] === '1') {
    header('Content-Type: application/json');
    
    if ($action === 'get_status') {
        echo json_encode(call_varnishctl('status'));
    } elseif ($action === 'purge' && $domain) {
        echo json_encode(call_varnishctl('purge', $domain));
    } elseif ($action === 'flush') {
        echo json_encode(call_varnishctl('flush'));
    } else {
        echo json_encode(array('error' => 'Invalid action'));
    }
    exit;
}

// Display page header
$cpanel->header('Varnish Manager');
?>

<style>
    .varnish-container {
        max-width: 1000px;
        margin: 20px auto;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
    }
    
    .varnish-status-box {
        background: #f5f5f5;
        border: 1px solid #ddd;
        border-radius: 4px;
        padding: 15px;
        margin-bottom: 20px;
    }
    
    .status-item {
        display: flex;
        justify-content: space-between;
        padding: 8px 0;
        border-bottom: 1px solid #eee;
    }
    
    .status-item:last-child {
        border-bottom: none;
    }
    
    .status-label {
        font-weight: 600;
        color: #333;
    }
    
    .status-value {
        color: #666;
    }
    
    .domain-list {
        list-style: none;
        padding: 0;
        margin: 10px 0;
    }
    
    .domain-item {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 12px;
        background: #fff;
        border: 1px solid #ddd;
        border-radius: 4px;
        margin-bottom: 10px;
    }
    
    .domain-name {
        font-weight: 500;
        color: #333;
    }
    
    .domain-actions {
        display: flex;
        gap: 10px;
    }
    
    .btn {
        padding: 6px 12px;
        border: none;
        border-radius: 4px;
        cursor: pointer;
        font-size: 12px;
        font-weight: 600;
        transition: all 0.3s;
    }
    
    .btn-primary {
        background: #0073e6;
        color: white;
    }
    
    .btn-primary:hover {
        background: #0056cc;
    }
    
    .btn-danger {
        background: #dc3545;
        color: white;
    }
    
    .btn-danger:hover {
        background: #c82333;
    }
    
    .btn-success {
        background: #28a745;
        color: white;
    }
    
    .btn-success:hover {
        background: #218838;
    }
    
    .alert {
        padding: 12px;
        border-radius: 4px;
        margin-bottom: 15px;
        border-left: 4px solid;
    }
    
    .alert-success {
        background: #d4edda;
        color: #155724;
        border-left-color: #28a745;
    }
    
    .alert-error {
        background: #f8d7da;
        color: #721c24;
        border-left-color: #dc3545;
    }
    
    .alert-info {
        background: #d1ecf1;
        color: #0c5460;
        border-left-color: #17a2b8;
    }
    
    .loading {
        display: inline-block;
        width: 14px;
        height: 14px;
        border: 2px solid #f3f3f3;
        border-top: 2px solid #0073e6;
        border-radius: 50%;
        animation: spin 1s linear infinite;
    }
    
    @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
    }
    
    .hidden {
        display: none;
    }
</style>

<div class="varnish-container">
    <h2>Varnish Manager</h2>
    
    <div id="message-container"></div>
    
    <!-- Status Section -->
    <div class="varnish-status-box">
        <h3>Varnish Status</h3>
        <button class="btn btn-primary" id="refresh-status-btn">Refresh Status</button>
        <div id="status-content" style="margin-top: 15px;">
            <p><span class="loading"></span> Loading status...</p>
        </div>
    </div>
    
    <!-- Cache Management Section -->
    <div class="varnish-status-box">
        <h3>Cache Management</h3>
        
        <div style="margin-bottom: 20px;">
            <button class="btn btn-success" id="flush-all-btn">Flush All Cache</button>
            <p style="font-size: 12px; color: #666; margin-top: 5px;">This will flush cache for all your domains</p>
        </div>
        
        <h4>Your Domains</h4>
        <ul class="domain-list" id="domain-list">
            <?php if (empty($domains)): ?>
                <li><p style="color: #999;">No domains found</p></li>
            <?php else: ?>
                <?php foreach ($domains as $dom): ?>
                    <li class="domain-item">
                        <span class="domain-name"><?php echo htmlspecialchars($dom); ?></span>
                        <span class="domain-actions">
                            <button class="btn btn-primary purge-domain-btn" data-domain="<?php echo htmlspecialchars($dom); ?>">
                                Purge Cache
                            </button>
                        </span>
                    </li>
                <?php endforeach; ?>
            <?php endif; ?>
        </ul>
    </div>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
    // Load initial status
    loadStatus();
    
    // Refresh status button
    document.getElementById('refresh-status-btn').addEventListener('click', loadStatus);
    
    // Flush all button
    document.getElementById('flush-all-btn').addEventListener('click', function() {
        if (confirm('Are you sure you want to flush cache for all domains?')) {
            callVarnishctl('flush');
        }
    });
    
    // Purge individual domain buttons
    document.querySelectorAll('.purge-domain-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const domain = this.dataset.domain;
            if (confirm('Purge cache for ' + domain + '?')) {
                callVarnishctl('purge', domain);
            }
        });
    });
});

function loadStatus() {
    const statusContent = document.getElementById('status-content');
    statusContent.innerHTML = '<p><span class="loading"></span> Loading status...</p>';
    
    callVarnishctl('get_status', null, function(response) {
        let html = '';
        
        if (response.error) {
            html = '<p class="alert alert-error">Error: ' + response.error + '</p>';
        } else if (response.status) {
            html = '<div class="status-item"><span class="status-label">Service:</span><span class="status-value">' + 
                   (response.status === 'running' ? '✓ Running' : '✗ Stopped') + '</span></div>';
            
            if (response.uptime) {
                html += '<div class="status-item"><span class="status-label">Uptime:</span><span class="status-value">' + 
                        response.uptime + '</span></div>';
            }
            
            if (response.version) {
                html += '<div class="status-item"><span class="status-label">Version:</span><span class="status-value">' + 
                        response.version + '</span></div>';
            }
            
            if (response.connections) {
                html += '<div class="status-item"><span class="status-label">Connections:</span><span class="status-value">' + 
                        response.connections + '</span></div>';
            }
        } else if (response.raw_output) {
            html = '<pre style="background: #f5f5f5; padding: 10px; border-radius: 4px; font-size: 12px;">' + 
                   escapeHtml(response.raw_output) + '</pre>';
        }
        
        statusContent.innerHTML = html;
    });
}

function callVarnishctl(action, domain = null, callback = null) {
    const params = new URLSearchParams();
    params.append('ajax', '1');
    params.append('action', action);
    if (domain) {
        params.append('domain', domain);
    }
    
    fetch(window.location.href, {
        method: 'POST',
        body: params
    })
    .then(response => response.json())
    .then(data => {
        showMessage(data, action);
        if (callback) {
            callback(data);
        } else {
            loadStatus();
        }
    })
    .catch(error => {
        showMessage({error: 'Network error: ' + error}, null);
    });
}

function showMessage(response, action) {
    const container = document.getElementById('message-container');
    let message = '';
    let alertClass = 'alert-info';
    
    if (response.error) {
        message = 'Error: ' + response.error;
        alertClass = 'alert-error';
    } else if (response.success) {
        message = response.message || 'Operation completed successfully';
        alertClass = 'alert-success';
    } else {
        switch(action) {
            case 'flush':
                message = 'Cache flushed successfully for all domains';
                alertClass = 'alert-success';
                break;
            case 'purge':
                message = 'Cache purged successfully';
                alertClass = 'alert-success';
                break;
            case 'get_status':
                return; // Don't show message for status refresh
            default:
                message = 'Operation completed';
                alertClass = 'alert-success';
        }
    }
    
    if (message) {
        container.innerHTML = '<div class="alert ' + alertClass + '">' + message + '</div>';
        setTimeout(() => {
            container.innerHTML = '';
        }, 5000);
    }
}

function escapeHtml(text) {
    const map = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;'
    };
    return text.replace(/[&<>"']/g, m => map[m]);
}
</script>

<?php
// Display page footer
$cpanel->footer();
?>
