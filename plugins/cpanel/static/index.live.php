<?php
// cPanel Varnish user plugin API
// Handles API requests and serves the HTML interface

// Get the action from query string or POST body
$action = isset($_GET['action']) ? $_GET['action'] : '';
if (!$action && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = file_get_contents('php://input');
    $decoded = json_decode($input, true);
    $action = isset($decoded['action']) ? $decoded['action'] : '';
}

// If no action, serve the HTML interface
if (!$action) {
    header('Content-Type: text/html; charset=utf-8');
    readfile(__DIR__ . '/index.html');
    exit;
}

// Set JSON header for API responses
header('Content-Type: application/json');

// Find varnishctl.sh
$varnishctl_paths = [
    '/opt/varnish-whm-manager/bin/varnishctl.sh',
    '/usr/local/varnish-whm-manager/bin/varnishctl.sh',
];
$varnishctl = null;
foreach ($varnishctl_paths as $path) {
    if (is_executable($path)) {
        $varnishctl = $path;
        break;
    }
}

if (!$varnishctl) {
    echo json_encode(['status' => 'error', 'message' => 'varnishctl.sh not found']);
    exit;
}

try {
    switch ($action) {
        case 'status':
            $output = shell_exec("sudo -n " . escapeshellarg($varnishctl) . " status --format=json 2>&1");
            $data = json_decode($output, true);
            if ($data === null) {
                throw new Exception('Failed to parse status output: ' . $output);
            }
            echo json_encode(['status' => 'ok', 'data' => $data]);
            break;

        case 'purge':
            $url = isset($_GET['url']) ? $_GET['url'] : '';
            if (!$url && $_SERVER['REQUEST_METHOD'] === 'POST') {
                $input = file_get_contents('php://input');
                $decoded = json_decode($input, true);
                $url = isset($decoded['url']) ? $decoded['url'] : '';
            }
            if (!$url) {
                throw new Exception('Missing URL parameter');
            }
            $output = shell_exec("sudo -n " . escapeshellarg($varnishctl) . " purge " . escapeshellarg($url) . " 2>&1");
            echo json_encode(['status' => 'ok', 'message' => 'URL purge requested', 'log' => $output]);
            break;

        case 'flush':
            $output = shell_exec("sudo -n " . escapeshellarg($varnishctl) . " flush 2>&1");
            echo json_encode(['status' => 'ok', 'message' => 'Full cache flush requested', 'log' => $output]);
            break;

        case 'domains':
            // Get cPanel user from environment
            $cpanel_user = isset($_SERVER['REMOTE_USER']) ? $_SERVER['REMOTE_USER'] : '';
            if (!$cpanel_user) {
                throw new Exception('Could not determine cPanel user');
            }
            
            // Read domains from cPanel's userdata
            $userdata_dir = '/var/cpanel/userdata/' . $cpanel_user;
            if (!is_dir($userdata_dir)) {
                throw new Exception('User data directory not found');
            }
            
            $domains = [];
            $main_domain = '';
            
            // Read main domain from cache file
            $cache_file = $userdata_dir . '/cache';
            if (file_exists($cache_file)) {
                $cache_data = json_decode(file_get_contents($cache_file), true);
                if (isset($cache_data['main_domain'])) {
                    $main_domain = $cache_data['main_domain'];
                    $domains[] = $main_domain;
                }
            }
            
            // Scan for all domain conf files
            $files = glob($userdata_dir . '/*');
            foreach ($files as $file) {
                $basename = basename($file);
                if ($basename === 'main' || $basename === 'cache' || $basename === '.' || $basename === '..') {
                    continue;
                }
                if (is_file($file) && $basename !== $main_domain) {
                    $domains[] = $basename;
                }
            }
            
            $result = [
                'main_domain' => $main_domain,
                'addon_domains' => array_values(array_diff($domains, [$main_domain])),
            ];
            
            echo json_encode(['status' => 'ok', 'domains' => $result]);
            break;

        default:
            throw new Exception('Unknown action: ' . $action);
    }
} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => $e->getMessage()]);
}
