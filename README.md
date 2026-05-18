# 🪽 Pelican Panel Auto Installer

🚀 A fully automated installer for the latest version of Pelican Panel and Wings daemon.

This installer is designed to simplify the deployment process for Pelican Panel across multiple Linux distributions with automatic OS detection, automatic dependency installation, automatic SSL setup, and automatic service configuration.

Instead of manually configuring PHP, MariaDB, Nginx, SSL certificates, Docker, Wings, and permissions, this installer handles nearly everything automatically.

Perfect for:

- 🎮 Minecraft hosting
- 🎮 Game server hosting
- ☁️ VPS deployments
- 🖥️ Dedicated servers
- 🏠 Home labs
- 🐧 Linux beginners
- ⚡ Fast Pelican deployments

---

# 📦 Repository

🌐 GitHub Repository:

https://github.com/HacksYT23-2/pelican-ubuntu26-installer

⚡ Quick Install:

```bash
bash <(curl -s https://raw.githubusercontent.com/HacksYT23-2/pelican-ubuntu26-installer/main/install.sh)
```

---

# ✨ What This Installer Does

This script automatically performs the following:

- ✅ Detects your Linux distribution automatically
- ✅ Installs the correct PHP version
- ✅ Installs PHP-FPM and required extensions
- ✅ Configures Nginx automatically
- ✅ Creates the Pelican database
- ✅ Configures MariaDB permissions
- ✅ Installs SSL certificates using Let's Encrypt
- ✅ Downloads and installs the latest Pelican Panel
- ✅ Installs Composer dependencies
- ✅ Installs Wings daemon
- ✅ Applies SELinux permissions
- ✅ Includes repair and cleanup utilities

---

# 🐧 Supported Operating Systems

| Operating System | PHP Version | Status |
|---|---|---|
| Ubuntu 22.04 LTS | PHP 8.3 / 8.4 | ✅ Supported |
| Ubuntu 24.04 LTS | PHP 8.3 / 8.4 | ✅ Supported |
| Ubuntu 26.04 LTS | PHP 8.5 | ✅ Supported |
| Debian 12 Bookworm | PHP 8.3 | ✅ Supported |
| Debian 13 Trixie | PHP 8.4 | ✅ Supported |
| CentOS / RHEL 9 | PHP 8.4 | ✅ Supported |
| CentOS / RHEL 10 | PHP 8.4 | ✅ Supported |
| Rocky Linux 9 | PHP 8.4 | ✅ Supported |
| AlmaLinux 9 | PHP 8.4 | ✅ Supported |
| Fedora | PHP 8.4 | ⚠️ Experimental |
| Alpine Linux 3.19+ | PHP 8.3 / 8.4 | ⚠️ Experimental |

---

# 🌐 Required Ports

| Service | Port |
|---|---|
| HTTP | 80 |
| HTTPS | 443 |
| Wings API | 8080 |
| Wings SFTP | 2022 |

---

# ⚡ Quick Install

Run as root:

```bash
bash <(curl -s https://raw.githubusercontent.com/HacksYT23-2/pelican-ubuntu26-installer/main/install.sh)
```

---

# 📦 Clone The Repository

```bash
git clone https://github.com/HacksYT23-2/pelican-ubuntu26-installer.git

cd pelican-ubuntu26-installer

sudo bash install.sh
```

---

# 📋 Installer Menu

```text
1) Install Panel only
2) Install Wings only
3) Install Panel + Wings
4) Repair Web Server
5) Remove broken PHP repo/PPA/module
6) Exit
```

---

# 🔧 Permission Fixes

If you encounter permission problems after installation, use the appropriate commands below.

## 🐧 Ubuntu / Debian Permission Fix

```bash
sudo chown -R www-data:www-data /var/www/pelican

sudo chmod -R 755 \
/var/www/pelican/storage \
/var/www/pelican/bootstrap/cache
```

Restart services:

```bash
sudo systemctl restart php8.5-fpm
sudo systemctl restart nginx
```

---

## 🪨 CentOS / RHEL / Rocky / AlmaLinux Permission Fix

```bash
sudo chown -R nginx:nginx /var/www/pelican

sudo chmod -R 755 \
/var/www/pelican/storage \
/var/www/pelican/bootstrap/cache

sudo chcon -R -t httpd_sys_rw_content_t \
/var/www/pelican/storage \
/var/www/pelican/bootstrap/cache
```

Restart services:

```bash
sudo systemctl restart php-fpm
sudo systemctl restart nginx
```

---
## Alpine Linux Permission Fix (500 Internal Server Error)

If you receive a `500 Internal Server Error` on Alpine Linux after installing Pelican Panel, it is usually caused by Laravel log permission issues.

Example error:

```text
The stream or file "/var/www/pelican/storage/logs/laravel-YYYY-MM-DD.log" could not be opened in append mode: Permission denied
```

Run the following commands:

```bash
cd /var/www/pelican

rm -f storage/logs/laravel-*.log

mkdir -p storage/logs bootstrap/cache storage/framework/{cache,sessions,views}

chown -R nginx:nginx /var/www/pelican

chmod -R 775 storage bootstrap/cache

touch storage/logs/laravel-$(date +%F).log
chown nginx:nginx storage/logs/laravel-$(date +%F).log
chmod 664 storage/logs/laravel-$(date +%F).log

rc-service php-fpm84 restart
rc-service nginx restart
```

Also verify PHP-FPM is running as the `nginx` user:

```bash
grep -E '^(user|group|listen)' /etc/php84/php-fpm.d/www.conf
```

If it shows `user = nobody`, fix it:

```bash
sed -i 's/^user = .*/user = nginx/' /etc/php84/php-fpm.d/www.conf
sed -i 's/^group = .*/group = nginx/' /etc/php84/php-fpm.d/www.conf

rc-service php-fpm84 restart
rc-service nginx restart
```

After applying the fix, reload the panel in your browser.
---

# 🌐 Ubuntu 26.04 PHP 8.5 Nginx Fix

If PHP downloads instead of loading, or Nginx cannot connect to PHP-FPM, run:

```bash
sudo sed -i 's|fastcgi_pass unix:/run/php/php.*-fpm.sock;|fastcgi_pass unix:/run/php/php8.5-fpm.sock;|g' \
/etc/nginx/sites-available/pelican.conf
```

Enable Pelican config:

```bash
sudo ln -sf /etc/nginx/sites-available/pelican.conf \
/etc/nginx/sites-enabled/pelican.conf
```

Remove default Nginx config:

```bash
sudo rm -f /etc/nginx/sites-enabled/default
```

Test Nginx:

```bash
sudo nginx -t
```

Restart services:

```bash
sudo systemctl restart php8.5-fpm
sudo systemctl restart nginx
```

Check PHP socket:

```bash
ls /run/php/
```

Expected output:

```text
php8.5-fpm.sock
```

---

# ❗ Troubleshooting

## 🌩️ SSL Certificate Failed

Verify:

- Domain points correctly
- Ports 80/443 are open
- Cloudflare proxy disabled
- Nginx running correctly

Retry:

```bash
certbot --nginx -d your-domain.com
```

---

## 🗄️ MariaDB Socket Error

Fix:

```bash
sudo systemctl enable --now mariadb
sudo systemctl restart mariadb
```

---

## 🪽 Wings Offline

Verify:

- Port 8080 open
- SSL valid
- Correct node configuration
- Docker running

---

# ⭐ Star The Repository

If this installer helped you, consider starring the repository:

⭐ https://github.com/HacksYT23-2/pelican-ubuntu26-installer

---

# 🤝 Contributing

Pull requests and fixes are welcome.

Please include:

- Logs
- OS version
- Installer output
- Error screenshots if possible

---

# 📜 License

MIT License

Copyright (c) 2026 Jaimston / HacksYT23-2

---

# ⚠️ Disclaimer

This installer is provided AS-IS without warranty.

Always back up important data before running automated installation scripts.

Use at your own risk.
