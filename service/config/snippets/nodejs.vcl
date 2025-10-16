# Node.js / Express.js upstream helper snippet

backend express_app {
    .host = "127.0.0.1";
    .port = "3000";
    .probe = {
        .request = "HEAD /health HTTP/1.1" "Host: localhost" "Connection: close";
        .interval = 10s;
        .timeout = 2s;
        .window = 5;
        .threshold = 3;
    }
}

if (req.http.Host == "node.example.com") {
    set req.backend_hint = express_app;
}
