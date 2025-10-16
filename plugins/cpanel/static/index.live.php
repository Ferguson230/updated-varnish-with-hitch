<?php
// Proxy for cPanel Varnish user plugin
// Handles API requests and serves the HTML interface

header('Content-Type: application/json');

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

// Execute the CGI script via system call
$cgi_script = __DIR__ . '/varnish_user.cgi';
if (!is_executable($cgi_script)) {
    echo json_encode(['status' => 'error', 'message' => 'CGI script not executable']);
    exit;
}

// Set up environment for CGI
$env = [
    'REQUEST_METHOD' => $_SERVER['REQUEST_METHOD'],
    'CONTENT_TYPE' => 'application/json',
    'QUERY_STRING' => http_build_query(['action' => $action]),
    'REMOTE_USER' => $_SERVER['REMOTE_USER'] ?? '',
    'SCRIPT_NAME' => $_SERVER['SCRIPT_NAME'] ?? '',
];

// Get POST data if present
$post_data = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $post_data = file_get_contents('php://input');
    $env['CONTENT_LENGTH'] = strlen($post_data);
}

// Build environment string
$env_string = '';
foreach ($env as $key => $value) {
    $env_string .= escapeshellarg($key) . '=' . escapeshellarg($value) . ' ';
}

// Execute CGI and capture output
$descriptors = [
    0 => ['pipe', 'r'],  // stdin
    1 => ['pipe', 'w'],  // stdout
    2 => ['pipe', 'w'],  // stderr
];

$process = proc_open($env_string . escapeshellarg($cgi_script), $descriptors, $pipes);

if (!is_resource($process)) {
    echo json_encode(['status' => 'error', 'message' => 'Failed to execute CGI']);
    exit;
}

// Send POST data to stdin
if ($post_data) {
    fwrite($pipes[0], $post_data);
}
fclose($pipes[0]);

// Read output
$output = stream_get_contents($pipes[1]);
fclose($pipes[1]);

$errors = stream_get_contents($pipes[2]);
fclose($pipes[2]);

$return_code = proc_close($process);

// Parse CGI output (skip headers if present)
$parts = preg_split('/\r?\n\r?\n/', $output, 2);
$body = count($parts) > 1 ? $parts[1] : $parts[0];

echo $body;
