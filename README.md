# Pelican Ubuntu 26.04 Auto Installer

Automatic installer for the latest Pelican Panel and Wings daemon on Ubuntu 26.04 LTS.

---

## Features

* Automatic Pelican Panel installation
* Automatic Wings installation
* PHP 8.5 setup
* MariaDB configuration
* Nginx configuration
* Automatic Let's Encrypt SSL setup
* Optimized for Ubuntu 26.04 LTS
* One-line installation command
* GitHub-ready deployment

---

## Supported Operating Systems

| OS               | Supported   |
| ---------------- | ----------- |
| Ubuntu 26.04 LTS | ✅           |
| Ubuntu 24.04 LTS | ⚠️ Untested |
| Debian           | ❌           |
| CentOS           | ❌           |

---

## Requirements

### Minimum

* 2 CPU cores
* 4GB RAM
* 20GB storage
* Root access
* Domain name

### Recommended

* 4+ CPU cores
* 8GB+ RAM
* SSD storage
* Dedicated server or VPS

---

## Quick Install

Run this command as root:

```bash
bash <(curl -s https://raw.githubusercontent.com/HacksYT23-2/pelican-ubuntu26-installer/main/install.sh)
```

---

## What The Installer Does

The installer automatically:

1. Updates the system
2. Installs required dependencies
3. Installs PHP 8.5
4. Configures MariaDB
5. Downloads the latest Pelican Panel
6. Installs Composer dependencies
7. Configures Nginx
8. Sets file permissions
9. Configures SSL with Certbot
10. Installs Wings
11. Creates the admin account

---

## Installation Prompts

During installation you will be asked for:

* Domain name
* Email address
* Database password
* Admin account information

---

## After Installation

Open your browser and go to:

```text
https://your-domain.com
```

Then:

1. Login to the admin panel
2. Create a node
3. Copy the Wings configuration command
4. Run the command on your server

---

## Wings Setup

Example command:

```bash
sudo wings configure --panel-url https://panel.example.com --token YOUR_TOKEN --node 1
```

Start Wings:

```bash
sudo systemctl enable --now wings
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

## Optional Hairpin NAT Fix

Only needed if Wings cannot connect internally.

Edit:

```bash
sudo nano /etc/hosts
```

Add:

```text
192.168.1.100 panel.example.com
```

Replace:

* `192.168.1.100` with your local server IP
* `panel.example.com` with your domain

---

## Troubleshooting

### SSL Failed

Make sure:

* Ports 80 and 443 are open
* Your domain points to your server
* Cloudflare proxy is disabled during install

---

### Permission Issues

```bash
sudo chown -R www-data:www-data /var/www/pelican
sudo chmod -R 755 /var/www/pelican/storage /var/www/pelican/bootstrap/cache
```

---

## Repository

https://github.com/HacksYT23-2/pelican-ubuntu26-installer

---

## License

MIT License
