# nginx Setup Guide (RHEL)
---

## Prerequisites

Confirm the following:

```bash
# Ports 80 and 443 are not already in use       # Have sudo/root access ?   # System is up to date ?
ss -tlnp | grep -E ':80|:443'                     id                          RHEL: dnf update -y
                                                                              Ubuntu: apt update && apt upgrade -y

# Disk space (nginx logs can grow — /var should have headroom)               # Version
  df -h /var /etc                                                              nginx -v
```
---
Follow installation guide on the [NGINX website](https://nginx.org/en/docs/install.html)

## First Start & Smoke Test

```bash

# Running ?                              # If not, start                     # Enable on boot
     systemctl status nginx                systemctl start nginx               systemctl enable nginx
     ps aux | grep nginx

# Test the config                        # Expected output:
  nginx -t                               # nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
                                         # nginx: configuration file /etc/nginx/nginx.conf test is successful

# Smoke test                             # You should see:
   curl -I http://localhost                HTTP/1.1 200 OK
                                           Server: nginx/1.26.x
```
## Directory Structure
```
/etc/nginx/                        ← Main config directory
├── nginx.conf                     ← Root config file (includes others)
├── conf.d/                        ← Drop-in server block configs (RHEL convention)
│   └── default.conf               ← Default server block
├── sites-available/               ← Available vhosts (Debian convention)
├── sites-enabled/                 ← Symlinks to active vhosts
├── snippets/                      ← Reusable config fragments
├── mime.types                     ← MIME type mappings
└── fastcgi_params                 ← FastCGI parameter defaults

/var/log/nginx/                    ← Log files
├── access.log                     ← Every request
└── error.log                      ← Errors and warnings

/var/www/html/                     ← Default web root (Debian)
/usr/share/nginx/html/             ← Default web root (RHEL)

/usr/lib/systemd/system/nginx.service  ← Systemd unit file
/etc/logrotate.d/nginx             ← Log rotation config
/run/nginx.pid                     ← PID file (running instance)
```

> RHEL puts server blocks in `conf.d/`. Debian uses `sites-available/` + `sites-enabled/` with symlinks.

---

## Default Server Block

After install, review and replace the default config. On RHEL: `/etc/nginx/conf.d/default.conf`. On Debian: `/etc/nginx/sites-available/default`.

A clean, minimal starting point:

```nginx
server {
    listen       80;
    listen       [::]:80;
    server_name  _;     # catches all hostnames — replace with your domain

    root   /usr/share/nginx/html;
    index  index.html index.htm;

    location / {
        try_files $uri $uri/ =404;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }

    error_page 404              /404.html;
    error_page 500 502 503 504  /50x.html;
}
```

Place your content in ` /usr/share/nginx/html` or `/var/www/html/` and reload:

```bash
systemctl reload nginx
```

---

## Firewall Configuration

```bash
firewalld:                                               ufw:

# Allow HTTP and HTTPS permanently                       ufw allow 'Nginx Full'     # opens both 80 and 443
firewall-cmd --permanent --add-service=http              ufw reload
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Verify
firewall-cmd --list-all
```
---

## SELinux / AppArmor Considerations

### SELinux (RHEL/CentOS/Rocky)

By default, SELinux restricts what nginx can do. Common fixes:

```bash
# Check current SELinux mode
getenforce

# Allow nginx to make network connections (needed for reverse proxy)
setsebool -P httpd_can_network_connect 1

# Allow nginx to connect to upstream on non-standard ports
semanage port -a -t http_port_t -p tcp 8080

# Allow nginx to serve files from a non-default web root
semanage fcontext -a -t httpd_sys_content_t "/opt/myapp/public(/.*)?"
restorecon -Rv /opt/myapp/public

# If nginx is being denied and you're not sure why
ausearch -m avc -ts recent | grep nginx
audit2allow -a   # shows what policy would allow it
```

### AppArmor (Debian/Ubuntu)

```bash
# Check nginx profile status
aa-status | grep nginx

# If nginx is in enforce mode and blocking operations, switch to complain mode
aa-complain /etc/apparmor.d/usr.sbin.nginx

# Or add a local override for a specific path
echo "/opt/myapp/public/** r," >> /etc/apparmor.d/local/usr.sbin.nginx
systemctl reload apparmor
```

---

## TLS Setup

### Certbot 

```bash
dnf install certbot python3-certbot-nginx -y

# Obtain and install certificate (modifies nginx config automatically)
certbot --nginx -d example.com -d www.example.com

# Test auto-renewal
certbot renew --dry-run

# Auto-renewal is handled by a systemd timer (confirm it's active)
systemctl status certbot.timer
```

### Manual / Internal CA Certificate

```bash
# Create directory for certs
mkdir -p /etc/nginx/ssl

# Copy signed certificate and private key
cp /path/to/example.com.crt /etc/nginx/ssl/
cp /path/to/example.com.key /etc/nginx/ssl/

# Set secure permissions
chmod 600 /etc/nginx/ssl/example.com.key
chmod 644 /etc/nginx/ssl/example.com.crt
chown root:root /etc/nginx/ssl/*

# If you have a CA bundle, concatenate it with your cert:
cat example.com.crt ca-bundle.crt > example.com.chained.crt
```

Then reference in your server block — see `configs/ssl-termination.conf`.

### Verify TLS is working

```bash
# Check certificate presented by the server
openssl s_client -connect example.com:443 -showcerts

# Check expiry date
echo | openssl s_client -connect example.com:443 2>/dev/null \
  | openssl x509 -noout -dates

# Test TLS version support
curl -v --tlsv1.2 https://example.com
curl -v --tlsv1.3 https://example.com
```

---

## Post-Install Hardening

Before going to production...........

### In `nginx.conf` — http block

```nginx
http {
    # Hide nginx version number from error pages and headers
    server_tokens off;

    # Limit request body size (prevent large upload abuse)
    client_max_body_size 10m;

    # Timeouts — prevent slow-client attacks
    client_body_timeout   12;
    client_header_timeout 12;
    keepalive_timeout     15;
    send_timeout          10;

    # Disable unused HTTP methods at server level
    # (allow only GET, HEAD, POST in location blocks as needed)
}
```

### Disable unused modules

If compiling from source, exclude modules you don't need:

```bash
./configure --without-http_autoindex_module \
            --without-http_ssi_module \
            --without-http_scgi_module
```

If using a package, check what's compiled in and disable via config:

```nginx
# Disable directory listing
autoindex off;
```

### Run nginx as a non-root user

The main nginx process must start as root (to bind port 80/443) but worker processes should run as a limited user:

```nginx
# In nginx.conf — top level
user nginx;    # or www-data on Debian
```

Confirm:

```bash
ps aux | grep nginx
# Master process: root
# Worker processes: nginx (or www-data)
```

### Set worker process limits

```nginx
# In nginx.conf — top level
worker_processes auto;          # one per CPU core

events {http://192.168.0.117/
    worker_connections 1024;    # max connections per worker
}
```

### Restrict access to sensitive paths

```nginx
# Deny .git, .env, hidden files
location ~ /\.(git|env|htaccess|htpasswd) {
    deny all;
    return 404;
}
```

---
Run this checklist after setup and after any significant change:

```bash
# 1. Config syntax is valid
nginx -t

# 2. Service is running
systemctl status nginx

# 3. Correct ports are listening
ss -tlnp | grep nginx

# 4. HTTP responds
curl -I http://localhost

# 5. HTTPS responds (if TLS configured)
curl -I https://your-domain.com

# 6. Correct certificate is presented
openssl s_client -connect your-domain.com:443 -showcerts 2>/dev/null \
  | openssl x509 -noout -subject -dates

# 7. nginx version is hidden
curl -I http://localhost | grep Server
# Should show: Server: nginx (no version number)

# 8. Logs are being written
tail -5 /var/log/nginx/access.log
tail -5 /var/log/nginx/error.log

# 9. Log rotation is configured
cat /etc/logrotate.d/nginx

# 10. nginx starts on reboot
systemctl is-http://192.168.0.117/enabled nginx
```
