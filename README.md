# Pelican Panel Auto Installer

Automatic installer for the latest Pelican Panel and Wings daemon.
Supports multiple Linux distributions with automatic OS detection.

---

## Supported Operating Systems

| OS                    | Version      | PHP   | Status       |
| --------------------- | ------------ | ----- | ------------ |
| Ubuntu LTS            | 22.04 Jammy  | 8.3   | ✅ Supported  |
| Ubuntu LTS            | 24.04 Noble  | 8.3   | ✅ Supported  |
| Ubuntu LTS            | 26.04        | 8.5   | ✅ Supported  |
| Debian                | 13 Trixie    | 8.3   | ✅ Supported  |
| CentOS / RHEL Stream  | 9            | 8.3   | ✅ Supported  |
| Rocky Linux           | 9            | 8.3   | ✅ Supported  |
| AlmaLinux             | 9            | 8.3   | ✅ Supported  |

> PHP repos are handled automatically per distro:
> - Ubuntu 22.04 → Ondrej PPA
> - Ubuntu 24.04 / 26.04 / Debian 13 → native packages
> - CentOS / RHEL 9 → Remi repo

---

## Features

- Automatic OS detection — no manual config needed
- Pelican Panel installation
- Wings daemon installation
- PHP setup (version matched per OS)
- MariaDB configuration
- Nginx configuration
- Automatic Let's Encrypt SSL
- SELinux support for CentOS / RHEL
- Broken PHP repo cleanup tool
- Nginx repair tool
- One-line install command

---

## Requirements

### Minimum

- 2 CPU cores
- 4 GB RAM
- 20 GB storage
- Root access
- A domain name pointed at your server

### Recommended

- 4+ CPU cores
- 8 GB+ RAM
- SSD storage
- Dedicated server or VPS

### Pre-install Checklist

- [ ] Domain A record points to your server's public IP
- [ ] Ports 80 and 443 are open in your firewall
- [ ] Cloudflare proxy (orange cloud) is **disabled** during install
- [ ] Docker is installed if you plan to use Wings

---

## Quick Install

Run as root:

```bash
bash <(curl -s https://raw.githubusercontent.com/HacksYT23-2/pelican-ubuntu26-installer/main/install.sh)
```

Or clone and run:

```bash
git clone https://github.com/HacksYT23-2/pelican-ubuntu26-installer.git
cd pelican-ubuntu26-installer
sudo bash install.sh
```

---

## Installer Menu

```
1) Install Panel only
2) Install Wings only
3) Install Panel + Wings
4) Repair Web Server
5) Remove broken PHP repo/PPA
6) Exit
```

---

## What The Installer Does

1. Detects your OS and sets the correct PHP version
2. Adds any required PHP repo (Ondrej PPA / Remi)
3. Installs PHP, Nginx, MariaDB, Certbot, and other dependencies
4. Downloads the latest Pelican Panel release
5. Installs Composer dependencies
6. Configures Nginx (with correct socket path per OS)
7. Sets correct file permissions and SELinux contexts (CentOS)
8. Obtains a Let's Encrypt SSL certificate
9. Runs database migrations
10. Prompts to create your admin account
11. Optionally installs the Wings daemon

---

## Installation Prompts

You will be asked for:

| Prompt            | Example                  |
| ----------------- | ------------------------ |
| Domain name       | `panel.example.com`      |
| Email for SSL     | `you@example.com`        |
| Database password | *(your choice)*          |
| Admin account     | *(entered after install)*|

---

## After Installation

Open your browser and go to:

```
https://your-domain.com
```

Then:

1. Log in to the admin panel
2. Go to **Admin → Nodes → Create Node**
3. Copy the Wings configuration command shown
4. Run it on your server
5. Start Wings:

```bash
sudo systemctl enable --now wings
```

---

## Wings Setup

Example configure command (get the real one from your panel node page):

```bash
sudo wings configure --panel-url https://panel.example.com --token YOUR_TOKEN --node 1
```

Check Wings status:

```bash
sudo systemctl status wings
```

View Wings logs:

```bash
sudo journalctl -u wings -f
```

---

## Updating Pelican

```bash
cd /var/www/pelican
php artisan down
curl -L https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xzv
COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader
php artisan migrate --seed --force
php artisan up
```

---

## Troubleshooting

### SSL Certificate Failed

- Make sure your domain's A record points to this server
- Make sure ports 80 and 443 are open
- Disable the Cloudflare proxy (orange cloud) during install
- Re-run certbot manually:

```bash
certbot --nginx -d your-domain.com
```

### Permission Issues (Ubuntu / Debian)

```bash
sudo chown -R www-data:www-data /var/www/pelican
sudo chmod -R 755 /var/www/pelican/storage /var/www/pelican/bootstrap/cache
```

### Permission Issues (CentOS / RHEL)

```bash
sudo chown -R nginx:nginx /var/www/pelican
sudo chmod -R 755 /var/www/pelican/storage /var/www/pelican/bootstrap/cache
sudo chcon -R -t httpd_sys_rw_content_t /var/www/pelican/storage /var/www/pelican/bootstrap/cache
```

### Nginx Won't Start

Use the built-in repair option from the installer menu (option 4), or run:

```bash
nginx -t
sudo systemctl restart nginx
```

### Broken PHP Repo

Use option 5 from the installer menu to clean up any broken PHP PPA or repo files, then re-run the installer.

### Hairpin NAT (Wings Can't Connect Internally)

If Wings is on the same machine as the panel and can't reach it via your domain:

```bash
sudo nano /etc/hosts
```

Add:

```
192.168.1.100   panel.example.com
```

Replace `192.168.1.xxx` with your server's local IP and `panel.example.com` with your domain.

---

## Repository

https://github.com/HacksYT23-2/pelican-ubuntu26-installer

---

## License

MIT License
