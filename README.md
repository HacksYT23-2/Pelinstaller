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

# ✨ What This Installer Does

This script automatically performs the following:

## 🔍 Operating System Detection

The installer automatically detects your Linux distribution and configures the correct package manager, PHP version, and service configuration.

Supported package managers:

- `apt`
- `dnf`
- `apk`

---

## 🐘 PHP Installation & Configuration

Automatically installs the correct PHP version for your OS.

The installer configures:

- PHP CLI
- PHP-FPM
- Required PHP extensions
- PHP socket configuration
- PHP-FPM startup services

Supported PHP versions:

| PHP Version | Status |
|---|---|
| PHP 8.3 | ✅ |
| PHP 8.4 | ✅ |
| PHP 8.5 | ✅ |

---

## 🌐 Nginx Configuration

The installer automatically:

- Installs Nginx
- Creates a Pelican virtual host
- Configures PHP-FPM sockets
- Enables the site
- Removes default configs
- Applies upload limits
- Configures fastcgi settings
- Tests the configuration automatically

No manual Nginx editing required.

---

## 🗄️ MariaDB Setup

Automatically installs and configures MariaDB.

The installer:

- Creates the Pelican database
- Creates the Pelican database user
- Applies permissions
- Flushes privileges
- Starts and enables MariaDB

---

## 🔒 SSL Certificates

The installer automatically configures HTTPS using Let's Encrypt and Certbot.

Automatic features:

- SSL certificate generation
- Nginx SSL configuration
- HTTPS redirect support
- Automatic certificate renewal support

---

## 🪽 Wings Installation

The installer can automatically install Wings daemon.

Features:

- Downloads latest Wings release
- Creates Wings service
- Enables startup on boot
- Supports systemd and OpenRC
- Configures Wings binary permissions

---

## 🐳 Docker Support

Wings requires Docker.

The installer supports Docker-enabled systems and can integrate directly with Wings.

Supported container environments:

- Docker Engine
- Containerized game servers
- Docker networking
- Docker bridge interfaces

---

## 🔐 SELinux Support

For RHEL-family systems:

- CentOS
- Rocky Linux
- AlmaLinux
- RHEL

The installer automatically configures SELinux permissions required for Pelican Panel.

---

## 🛠️ Repair Utilities

The installer includes built-in repair tools.

### Repair Web Server

Automatically repairs:

- Missing Nginx configs
- Broken Nginx installs
- Invalid Nginx configuration files

### Remove Broken PHP Repositories

Automatically cleans:

- Broken Ondrej PPAs
- Broken Sury repos
- Broken Remi repositories

Useful when package installs fail.

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

# ⚙️ Automatic PHP Repository Handling

The installer automatically configures the correct PHP repositories for your system.

| OS | Repository |
|---|---|
| Ubuntu 22.04 | Ondrej PHP PPA |
| Ubuntu 24.04 | Native packages |
| Ubuntu 26.04 | Native packages |
| Debian 12 | Native packages |
| Debian 13 | Native packages |
| CentOS/RHEL | Remi repository |
| Alpine | Native apk packages |

---

# 💻 Recommended Server Specs

## 📌 Minimum Requirements

- ✅ 2 CPU cores
- ✅ 4GB RAM
- ✅ 20GB storage
- ✅ Root access
- ✅ Public IPv4 address
- ✅ Domain name

## 🚀 Recommended Requirements

- ✅ 4+ CPU cores
- ✅ 8GB+ RAM
- ✅ SSD/NVMe storage
- ✅ Dedicated VPS or server
- ✅ Gigabit network connection

---

# 🌐 Required Ports

| Service | Port |
|---|---|
| HTTP | 80 |
| HTTPS | 443 |
| Wings API | 8080 |
| Wings SFTP | 2022 |

---

# ☁️ Cloudflare Notes

If using Cloudflare:

Before installation:

- ✅ Set DNS records to DNS Only
- ✅ Disable the orange cloud
- ✅ Wait for DNS propagation

Recommended SSL mode:

```text
Full (Strict)
```

❌ Do NOT use Flexible SSL.

Flexible SSL may cause:

- Redirect loops
- SSL validation failures
- Wings connection failures

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

# 🔧 Example Installation Flow

1. Run installer
2. Select install option
3. Enter domain name
4. Enter email for SSL
5. Enter database password
6. Wait for dependencies to install
7. SSL certificate is generated
8. Pelican database is created
9. Admin account is created
10. Wings daemon installed (optional)

---

# 🌍 Example DNS Setup

| Record Type | Name | Target |
|---|---|---|
| A | panel | your-server-ip |
| A | node | your-server-ip |

Example:

```text
panel.example.com -> your server IP
node.example.com -> your server IP
```

---

# 🐳 Docker Commands

Check Docker:

```bash
sudo systemctl status docker
```

Enable Docker:

```bash
sudo systemctl enable --now docker
```

---

# 🪽 Wings Commands

Check Wings:

```bash
sudo systemctl status wings
```

View logs:

```bash
sudo journalctl -u wings -f
```

Restart Wings:

```bash
sudo systemctl restart wings
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

Copyright (c) 2026 Ian / HacksYT23-2

---

# ⚠️ Disclaimer

This installer is provided AS-IS without warranty.

Always back up important data before running automated installation scripts.

Use at your own risk.
