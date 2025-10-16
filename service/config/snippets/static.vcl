# Static site hard cache (HTML TTL) – adjust as required.

# Place inside sub vcl_recv
if (req.url ~ "\.(?:html|htm)$") {
    unset req.http.Cookie;
}

# Place inside sub vcl_backend_response
if (bereq.url ~ "\.(?:html|htm)$") {
    set beresp.ttl = 5m;
    set beresp.grace = 5m;
}
