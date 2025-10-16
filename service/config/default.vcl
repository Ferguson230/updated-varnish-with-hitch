vcl 4.1;

import proxy;

backend default {
    .host = "__BACKEND_HOST__";
    .port = "8080";
}

acl purge {
    "localhost";
    "127.0.0.1";
    "::1";
    "__SERVER_IP__";
}

sub vcl_recv {
    set req.grace = 5m;

    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "PURGE not allowed for this IP address"));
        }
        if (req.http.X-Purge-Method == "regex") {
            ban("obj.http.x-url ~ " + req.url + " && obj.http.x-host == " + req.http.host);
            return (synth(200, "Purged"));
        }
        ban("obj.http.x-url == " + req.url + " && obj.http.x-host == " + req.http.host);
        return (synth(200, "Purged"));
    }

    if (!req.http.X-Forwarded-Proto) {
        if (proxy.is_ssl()) {
            set req.http.X-Forwarded-Proto = "https";
        } else {
            set req.http.X-Forwarded-Proto = "http";
        }
    }

    if (req.http.Accept-Encoding) {
        if (req.http.Accept-Encoding ~ "br") {
            set req.http.Accept-Encoding = "br, gzip";
        } elseif (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } else {
            unset req.http.Accept-Encoding;
        }
    }

    if (req.method != "GET" &&
        req.method != "HEAD") {
        set req.http.X-Cacheable = "NO:REQUEST-METHOD";
        return (pass);
    }

    if (req.http.Cookie) {
        if (req.http.Cookie ~ "(wordpress_|wp-|woocommerce_|PHPSESSID|session|logged_in)") {
            set req.http.X-Cacheable = "NO:Cookies Matched";
            return (pass);
        }
        if (req.url ~ "wp-admin" ||
            req.url ~ "wp-login.php" ||
            req.url ~ "my-account" ||
            req.url ~ "cart" ||
            req.url ~ "checkout" ||
            req.url ~ "preview") {
            set req.http.X-Cacheable = "NO:Bypassed Path";
            return (pass);
        }
    }

    if (req.url ~ "wp-login.php" ||
        req.url ~ "xmlrpc.php" ||
        req.url ~ ".*\?.*nocache" ||
        req.url ~ "^/wp-admin" ||
        req.url ~ "^/cart" ||
        req.url ~ "^/checkout" ||
        req.url ~ "^/my-account" ||
        req.url ~ "^/preview" ||
        req.url ~ "^/woocommerce") {
        set req.http.X-Cacheable = "NO:Rule Match";
        return (pass);
    }

    if (req.url ~ "[?&](utm_|gclid|fbclid|ref)=") {
        set req.url = regsuball(req.url, "&(utm_|gclid|fbclid|ref)=([^&]+)", "");
        set req.url = regsuball(req.url, "\?(utm_|gclid|fbclid|ref)=([^&]+)", "?");
        set req.url = regsub(req.url, "\?&", "?");
        set req.url = regsub(req.url, "\?$", "");
    }

    if (req.url ~ "\.(?:css|js|jpe?g|gif|png|webp|ico|woff2?|ttf|svg|eot|json|mp4|mp3|pdf)(\?.*)?$") {
        set req.http.X-Static-File = "true";
        unset req.http.Cookie;
        return (hash);
    }

    if (req.url ~ "\.(?:avif|heic|heif|webm|ogg|wav|bmp|svgz|txt|xml|csv|gz|zip|rar|7z|tar|tgz|bz2|xz)(\?.*)?$") {
        set req.http.X-Static-File = "true";
        unset req.http.Cookie;
        return (hash);
    }

    if (req.http.Authorization) {
        set req.http.X-Cacheable = "NO:Authorization";
        return (pass);
    }

    unset req.http.Cookie;
    return (hash);
}

sub vcl_hash {
    if (req.http.X-Forwarded-Proto) {
        hash_data(req.http.X-Forwarded-Proto);
    }
}

sub vcl_backend_response {
    if (beresp.http.Vary) {
        set beresp.http.Vary = beresp.http.Vary + ", X-Forwarded-Proto";
    } else {
        set beresp.http.Vary = "X-Forwarded-Proto";
    }

    set beresp.http.x-url = bereq.url;
    set beresp.http.x-host = bereq.http.host;

    set beresp.grace = 5m;
    set beresp.keep = 1h;
    if (beresp.ttl < 30s) {
        set beresp.ttl = 30s;
    }

    if (!beresp.http.Cache-Control) {
        set beresp.ttl = 1h;
        set beresp.http.X-Cacheable = "YES:Forced";
    }

    if (bereq.http.X-Static-File == "true") {
        unset beresp.http.Set-Cookie;
        set beresp.http.X-Cacheable = "YES:Static";
        set beresp.ttl = 1d;
        set beresp.grace = 2h;
    }

    if (beresp.http.Set-Cookie) {
        set beresp.http.X-Cacheable = "NO:Set-Cookie";
    } elseif (beresp.http.Cache-Control ~ "private") {
        set beresp.http.X-Cacheable = "NO:Private";
    }

    if (beresp.http.Cache-Control ~ "no-store" ||
        beresp.http.Cache-Control ~ "no-cache" ||
        beresp.status >= 500) {
        set beresp.uncacheable = true;
        return (deliver);
    }

    if (beresp.http.Content-Type &&
        beresp.http.Content-Type ~ "(?i)(text|application/(json|javascript|xml|wasm|xhtml|rss))") {
        set beresp.do_gzip = true;
    }

    set beresp.do_stream = true;
}

sub vcl_deliver {
    if (req.http.X-Cacheable) {
        set resp.http.X-Cacheable = req.http.X-Cacheable;
    } elseif (obj.uncacheable) {
        if (!resp.http.X-Cacheable) {
            set resp.http.X-Cacheable = "NO:Uncacheable";
        }
    } elseif (!resp.http.X-Cacheable) {
        set resp.http.X-Cacheable = "YES";
    }

    unset resp.http.x-url;
    unset resp.http.x-host;

__SECURITY_HEADERS__
}
