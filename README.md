# Supported Architectures

- x86_64 / amd64 → Supported
- ARM64 / aarch64 → Supported

---

# Tested Providers

- Oracle Cloud
- Hetzner
- OVH
- Contabo
- DigitalOcean
- Vultr
- Proxmox VPS
- Home Server

---

# Security Notes

This installer automatically:

- Enables HTTPS using Let's Encrypt
- Configures secure PHP-FPM settings
- Removes broken PHP repositories
- Applies SELinux permissions on RHEL-family systems
- Sets secure file permissions for Pelican

Recommended:

- Use SSH keys
- Disable password login
- Enable a firewall
- Keep your server updated

Ubuntu/Debian firewall example:

sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8080/tcp
sudo ufw enable

---

# Optional Ports

- HTTP → 80
- HTTPS → 443
- Wings API → 8080
- Wings SFTP → 2022

---

# Example DNS Layout

- panel.example.com → Pelican Panel
- node.example.com → Wings Node
- files.example.com → File storage

---

# Example Cloudflare Setup

During installation:

- Set DNS records to DNS Only
- Disable the orange cloud temporarily
- Re-enable proxy after SSL finishes

Recommended SSL mode:

Full (Strict)

---

# Alpine Linux Notes

Alpine uses:

- OpenRC instead of systemd
- apk instead of apt/dnf
- Different PHP package names

Example commands:

rc-service nginx restart
rc-service mariadb restart
rc-service wings start

---

# SELinux Notes

Manual SELinux fix:

sudo setsebool -P httpd_can_network_connect 1

sudo chcon -R -t httpd_sys_rw_content_t \
/var/www/pelican/storage \
/var/www/pelican/bootstrap/cache

---

# Docker Notes

Check Docker:

sudo systemctl status docker

Enable Docker:

sudo systemctl enable --now docker

---

# Updating Wings

curl -L https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_amd64 \
-o /usr/local/bin/wings

chmod +x /usr/local/bin/wings

sudo systemctl restart wings

---

# Common Problems

## Cloudflare SSL Loop

- Disable Cloudflare proxy
- Use Full or Full (Strict)
- Do NOT use Flexible SSL

---

## Wings Shows Offline

sudo systemctl status wings
sudo journalctl -u wings -f

Verify:

- Port 8080 is open
- Domain points correctly
- SSL certificate works

---

## MariaDB Socket Error

sudo systemctl enable --now mariadb
sudo systemctl restart mariadb

---

# Roadmap

Planned:

- Automatic Docker installation
- Firewall setup
- Swap setup
- Multi-node deployment
- Backup tools
- Uninstall tool
- Auto updater

---

# Contributing

Pull requests welcome.

Please include:

- Logs
- Distro/version
- Installer output

---

# Star The Repo

If this installer helped you, consider starring the repo.

---

# Credits

- Pelican Panel Developers
- Nginx
- PHP
- MariaDB
- Certbot / Let's Encrypt

---

# Disclaimer

Use at your own risk.

Always back up important data before running automated install scripts.
