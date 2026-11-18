# nginx - RHEL
---

Confirm:

```bash
# Ports 80 and 443 are not already in use       # Have sudo/root access ?   # System is up to date ?
ss -tlnp | grep -E ':80|:443'                     id                          dnf update -y

# Disk space (nginx logs can grow — /var should have headroom)               # Version
  df -h /var /etc                                                              nginx -v
```
---
Installation guide: [NGINX website](https://nginx.org/en/docs/install.html)

## Smoke Test

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
---

## Firewall

```bash
firewalld:                                              
# Allow HTTP and HTTPS permanently                     
firewall-cmd --permanent --add-service=http             
firewall-cmd --permanent --add-service=https
firewall-cmd --reload

# Verify
firewall-cmd --list-all
```
---

## TLS

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

### Local CA Certificate

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

### Verify TLS

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


### Restrict access to sensitive paths

```nginx
# Deny .git, .env, hidden files
location ~ /\.(git|env|htaccess|htpasswd) {
    deny all;
    return 404;
}
```

---
Troubleshooting:

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
