# Additional WordPress/WooCommerce tuning snippet for inclusion in default.vcl

# Drop WooCommerce / WP session cookies before hashing
if (req.http.Cookie) {
    if (req.http.Cookie ~ "(woocommerce_.*|wp_woocommerce_session_|wordpress_logged_in_|PHPSESSID)") {
        set req.http.X-Cacheable = "NO:WordPress Session";
        return (pass);
    }
    set req.http.Cookie = regsuball(req.http.Cookie, "(wp-settings-\d+|wp-settings-time-\d+)=[^;]+;?", "");
    if (req.http.Cookie ~ "^;?$") {
        unset req.http.Cookie;
    }
}

# Protect REST API and preview endpoints from caching
if (req.url ~ "^/wp-json" || req.url ~ "preview=true") {
    return (pass);
}
