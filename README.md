# 🪽 Pelican Panel Auto Installer

🚀 Automatic installer for Pelican Panel and Wings daemon.

## ✨ Features

- ✅ Multi-distro support
- ✅ Automatic PHP setup
- ✅ Automatic SSL setup
- ✅ Nginx configuration
- ✅ MariaDB configuration
- ✅ Wings daemon installer
- ✅ SELinux support
- ✅ Repair utilities

---

# 📦 Repository

🌐 GitHub Repository:

https://github.com/HacksYT23-2/pelican-ubuntu26-installer

## ⚡ Quick Install

```bash
bash <(curl -s https://raw.githubusercontent.com/HacksYT23-2/pelican-ubuntu26-installer/main/install.sh)
```

---

# 🐧 Supported Operating Systems

| OS | PHP | Status |
|---|---|---|
| Ubuntu 22.04 | 8.3 / 8.4 | ✅ |
| Ubuntu 24.04 | 8.3 / 8.4 | ✅ |
| Ubuntu 26.04 | 8.5 | ✅ |
| Debian 12 | 8.3 | ✅ |
| Debian 13 | 8.4 | ✅ |
| RHEL / Rocky / Alma 9 | 8.4 | ✅ |
| RHEL / Rocky / Alma 10 | 8.4 | ✅ |
| Fedora | 8.4 | ⚠️ Experimental |
| Alpine 3.19+ | 8.3 / 8.4 | ⚠️ Experimental |

---

# ✨ Features

- ✅ Automatic OS detection
- ✅ Automatic dependency installation
- ✅ Automatic PHP repository setup
- ✅ Automatic Nginx configuration
- ✅ Automatic MariaDB setup
- ✅ Automatic Let's Encrypt SSL
- ✅ Automatic file permission fixes
- ✅ SELinux compatibility
- ✅ Wings daemon installer
- ✅ Repair & cleanup tools

---

# ☁️ Tested Providers

- ✅ Oracle Cloud
- ✅ Hetzner
- ✅ OVH
- ✅ Contabo
- ✅ DigitalOcean
- ✅ Vultr
- ✅ Proxmox VPS
- ✅ Home Servers

---

# 💻 Recommended Specs

## Minimum

- ✅ 2 CPU Cores
- ✅ 4GB RAM
- ✅ 20GB Storage
- ✅ Root Access

## Recommended

- ✅ 4+ CPU Cores
- ✅ 8GB+ RAM
- ✅ SSD Storage
- ✅ Dedicated VPS or Server

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

Before installation:

- ✅ Set DNS records to DNS Only
- ✅ Disable the orange cloud
- ✅ Re-enable proxy after SSL finishes

Recommended SSL Mode:

```text
Full (Strict)
```

❌ Do NOT use Flexible SSL

---

# 🐳 Docker Notes

Wings requires Docker.

Check Docker:

```bash
sudo systemctl status docker
```

Enable Docker:

```bash
sudo systemctl enable --now docker
```

---

# ❗ Common Problems

## 🌩️ Cloudflare SSL Loop

- ✅ Disable Cloudflare proxy
- ✅ Use Full or Full (Strict)
- ❌ Do NOT use Flexible SSL

## 🪽 Wings Offline

```bash
sudo systemctl status wings
sudo journalctl -u wings -f
```

Verify:

- ✅ Port 8080 is open
- ✅ Domain points correctly
- ✅ SSL certificate works

---

# ⭐ Star The Repo

If this installer helped you, consider starring the repo:

⭐ https://github.com/HacksYT23-2/pelican-ubuntu26-installer

---

# 📜 License

MIT License

Copyright (c) 2026 Ian / HacksYT23-2

---

# ⚠️ Disclaimer

This installer is provided AS-IS.

Always back up important data before running automated installation scripts.
