<?php
// cPanel Varnish user plugin: serve HTML or JSON API without LIVEAPI

// Determine requested action
$action = isset($_GET['action']) ? $_GET['action'] : '';
if (!$action && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = file_get_contents('php://input');
    $decoded = json_decode($input, true);
    $action = isset($decoded['action']) ? $decoded['action'] : '';
}

// Serve UI when no action is requested
if (!$action) {
    header('Content-Type: text/html; charset=utf-8');
    readfile(__DIR__ . '/index.html');
    exit;
}

// Serve JSON for API
header('Content-Type: application/json');

function find_varnishctl() {
    $candidates = [
        '/usr/local/varnish-whm-manager/bin/varnishctl.sh',
        '/opt/varnish-whm-manager/bin/varnishctl.sh',
        '/usr/local/bin/varnishctl',
    ];
    foreach ($candidates as $c) {
        if (is_executable($c)) return $c;
    }
    return null;
}

function run_shell($cmd) {
    $out = shell_exec($cmd);
    return $out === null ? '' : $out;
}

function json_error($msg) {
    echo json_encode(['status' => 'error', 'message' => $msg]);
    exit;
}

try {
    switch ($action) {
        case 'status':
            $ctl = find_varnishctl();
            if (!$ctl) json_error('varnishctl.sh not found');
            $output = run_shell('sudo -n ' . escapeshellarg($ctl) . ' status --format=json 2>&1');
            $data = json_decode($output, true);
            if ($data === null) json_error('Failed to parse status output: ' . $output);
            echo json_encode(['status' => 'ok', 'data' => $data]);
            break;

        case 'purge':
            $url = isset($_GET['url']) ? $_GET['url'] : '';
            if (!$url && $_SERVER['REQUEST_METHOD'] === 'POST') {
                $input = file_get_contents('php://input');
                $decoded = json_decode($input, true);
                $url = isset($decoded['url']) ? $decoded['url'] : '';
            }
            if (!$url) json_error('Missing URL parameter');
            $ctl = find_varnishctl();
            if (!$ctl) json_error('varnishctl.sh not found');
            $log = run_shell('sudo -n ' . escapeshellarg($ctl) . ' purge ' . escapeshellarg($url) . ' 2>&1');
            echo json_encode(['status' => 'ok', 'message' => 'URL purge requested', 'log' => $log]);
            break;

        case 'flush':
            $ctl = find_varnishctl();
            if (!$ctl) json_error('varnishctl.sh not found');
            $log = run_shell('sudo -n ' . escapeshellarg($ctl) . ' flush 2>&1');
            echo json_encode(['status' => 'ok', 'message' => 'Full cache flush requested', 'log' => $log]);
            break;

        case 'domains':
            $uapi = '/usr/local/cpanel/bin/uapi';
            $user = isset($_SERVER['REMOTE_USER']) ? $_SERVER['REMOTE_USER'] : '';
            if (is_executable($uapi)) {
                $out = run_shell(escapeshellarg($uapi) . ' --output json Domains list_domains 2>&1');
                $dec = json_decode($out, true);
                if (is_array($dec) && isset($dec['status']) && $dec['status'] == 1) {
                    echo json_encode(['status' => 'ok', 'domains' => $dec['data']]);
                    break;
                }
                if ($user) {
                    $out2 = run_shell(escapeshellarg($uapi) . ' --output json ' . escapeshellarg('--user='.$user) . ' Domains list_domains 2>&1');
                    $dec2 = json_decode($out2, true);
                    if (is_array($dec2) && isset($dec2['status']) && $dec2['status'] == 1) {
                        echo json_encode(['status' => 'ok', 'domains' => $dec2['data']]);
                        break;
                    }
                }
            }
            if ($user) {
                $base = '/var/cpanel/userdata/' . $user;
                if (is_dir($base)) {
                    $entries = scandir($base);
                    $all = [];
                    foreach ($entries as $e) {
                        if ($e[0] === '.') continue;
                        if (preg_match('/^(main|cache|ssl|apache|nginx|subdomain|addons)(?:$|\.)/', $e)) continue;
                        if (preg_match('/^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/', $e)) {
                            $all[] = $e;
                        }
                    }
                    sort($all);
                    $main = '';
                    $mainFile = $base . '/main';
                    if (is_file($mainFile)) {
                        $contents = file_get_contents($mainFile);
                        if (preg_match('/main_domain:\s*([^\s]+)/', $contents, $m)) {
                            $main = $m[1];
                        }
                    }
                    if (!$main && count($all) > 0) $main = $all[0];
                    $addons = array_values(array_filter($all, function($d) use ($main) { return $d !== $main; }));
                    $data = [
                        'main_domain' => $main,
                        'addon_domains' => $addons,
                        'parked_domains' => [],
                        'sub_domains' => [],
                    ];
                    echo json_encode(['status' => 'ok', 'domains' => $data]);
                    break;
                }
            }
            json_error('Domain lookup failed');
            break;

        default:
            json_error('Unknown action: ' . $action);
    }
} catch (Throwable $e) {
    json_error($e->getMessage());
}