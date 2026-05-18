#!/bin/bash
set -e

clear

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
  echo -e "${CYAN}"
  echo "██████╗ ███████╗██╗     ██╗ ██████╗ █████╗ ███╗   ██╗"
  echo "██╔══██╗██╔════╝██║     ██║██╔════╝██╔══██╗████╗  ██║"
  echo "██████╔╝█████╗  ██║     ██║██║     ███████║██╔██╗ ██║"
  echo "██╔═══╝ ██╔══╝  ██║     ██║██║     ██╔══██║██║╚██╗██║"
  echo "██║     ███████╗███████╗██║╚██████╗██║  ██║██║ ╚████║"
  echo "╚═╝     ╚══════╝╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝"
  echo -e "${NC}"
  echo -e "${GREEN}Pelican Panel Auto Installer${NC}"
  echo -e "${YELLOW}Supports: Ubuntu 22.04 / 24.04 / 26.04 | Debian 13 | CentOS 9 Stream${NC}"
  echo
}

step() {
  echo
  echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"
}

error() {
  echo -e "${RED}ERROR:${NC} $1"
  exit 1
}

check_root() {
  if [ "$EUID" -ne 0 ]; then
    error "Run this as root: sudo bash install.sh"
  fi
}

# ── OS Detection ────────────────────────────────────────────────────────────────
detect_os() {
  if [ ! -f /etc/os-release ]; then
    error "Cannot detect OS. /etc/os-release not found."
  fi

  . /etc/os-release
  OS_ID="$ID"
  OS_CODENAME="${VERSION_CODENAME:-}"
  OS_VERSION_ID="${VERSION_ID:-}"

  case "$OS_ID" in
    ubuntu)
      PKG_MGR="apt"
      WEB_USER="www-data"
      case "$OS_VERSION_ID" in
        22.04)
          DISTRO="ubuntu2204"
          PHP_VER="8.3"
          echo -e "${GREEN}Detected: Ubuntu 22.04 LTS → using PHP 8.3 (via Ondrej PPA)${NC}"
          ;;
        24.04)
          DISTRO="ubuntu2404"
          PHP_VER="8.3"
          echo -e "${GREEN}Detected: Ubuntu 24.04 LTS → using PHP 8.3 (native)${NC}"
          ;;
        26.04)
          DISTRO="ubuntu2604"
          PHP_VER="8.5"
          echo -e "${GREEN}Detected: Ubuntu 26.04 LTS → using PHP 8.5 (native)${NC}"
          ;;
        *)
          error "Unsupported Ubuntu version: $OS_VERSION_ID. Supported: 22.04, 24.04, 26.04."
          ;;
      esac
      ;;
    debian)
      PKG_MGR="apt"
      WEB_USER="www-data"
      case "$OS_CODENAME" in
        trixie)
          DISTRO="debian13"
          PHP_VER="8.3"
          echo -e "${GREEN}Detected: Debian 13 (Trixie) → using PHP 8.3 (native)${NC}"
          ;;
        *)
          error "Unsupported Debian version: $OS_CODENAME. Supported: trixie (13)."
          ;;
      esac
      ;;
    centos|rhel|rocky|almalinux)
      PKG_MGR="dnf"
      WEB_USER="nginx"
      case "$OS_VERSION_ID" in
        9*)
          DISTRO="centos9"
          PHP_VER="8.3"
          echo -e "${GREEN}Detected: CentOS/RHEL 9 → using PHP 8.3 (via Remi repo)${NC}"
          ;;
        *)
          error "Unsupported CentOS/RHEL version: $OS_VERSION_ID. Supported: 9 Stream."
          ;;
      esac
      ;;
    *)
      error "Unsupported OS: $OS_ID. Supported: Ubuntu, Debian, CentOS/RHEL."
      ;;
  esac
}

banner
check_root
detect_os

echo
echo "What do you want to install?"
echo
echo "1) Install Panel only"
echo "2) Install Wings only"
echo "3) Install Panel + Wings"
echo "4) Repair Web Server"
echo "5) Remove broken PHP repo/PPA"
echo "6) Exit"
echo

read -p "Select an option [1-6]: " OPTION

if [ "$OPTION" = "6" ]; then
  echo "Exiting."
  exit 0
fi

read -p "Domain name: " DOMAIN
read -p "Email for SSL: " EMAIL
read -s -p "Database password: " DBPASS
echo

# ── PHP Repo Setup ──────────────────────────────────────────────────────────────
setup_php_repo() {
  case "$DISTRO" in
    ubuntu2204)
      step "Adding Ondrej PHP PPA for Ubuntu 22.04"
      apt install -y software-properties-common
      add-apt-repository -y ppa:ondrej/php
      apt update
      ;;
    ubuntu2404|ubuntu2604)
      step "Using native PHP ${PHP_VER} packages"
      ;;
    debian13)
      step "Using native Debian 13 PHP ${PHP_VER} packages"
      apt install -y apt-transport-https ca-certificates curl lsb-release
      ;;
    centos9)
      step "Adding EPEL and Remi repos for PHP ${PHP_VER}"
      dnf install -y epel-release
      dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm
      dnf module reset php -y
      dnf module enable php:remi-${PHP_VER} -y
      ;;
  esac
}

# ── Remove Broken PHP Repos ─────────────────────────────────────────────────────
remove_broken_php_repo() {
  case "$PKG_MGR" in
    apt)
      step "Removing broken PHP repos (if present)"
      # Ubuntu Ondrej PPA files
      rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list
      rm -f /etc/apt/sources.list.d/ondrej-php*.list
      rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.sources
      rm -f /etc/apt/sources.list.d/ondrej-php*.sources
      # Debian Sury repo files
      rm -f /etc/apt/sources.list.d/php.list
      rm -f /etc/apt/sources.list.d/sury-php*.list
      rm -f /usr/share/keyrings/deb.sury.org-php.gpg
      echo -e "${YELLOW}Done. Re-run the installer to set up the correct repo.${NC}"
      ;;
    dnf)
      step "Removing broken Remi PHP repo (if present)"
      dnf module reset php -y || true
      rm -f /etc/yum.repos.d/remi*.repo || true
      echo -e "${YELLOW}Done. Re-run the installer to set up the correct repo.${NC}"
      ;;
  esac
}

# ── Install Dependencies ────────────────────────────────────────────────────────
install_dependencies() {
  setup_php_repo

  step "Installing PHP ${PHP_VER} and dependencies"

  if [ "$PKG_MGR" = "apt" ]; then
    apt update
    apt install -y \
      php${PHP_VER} php${PHP_VER}-cli php${PHP_VER}-fpm \
      php${PHP_VER}-gd php${PHP_VER}-mysql php${PHP_VER}-mbstring \
      php${PHP_VER}-bcmath php${PHP_VER}-xml php${PHP_VER}-curl \
      php${PHP_VER}-zip php${PHP_VER}-intl php${PHP_VER}-sqlite3 \
      nginx mariadb-server curl tar unzip git certbot python3-certbot-nginx

  elif [ "$PKG_MGR" = "dnf" ]; then
    dnf install -y \
      php php-cli php-fpm \
      php-gd php-mysqlnd php-mbstring \
      php-bcmath php-xml php-curl \
      php-zip php-intl php-sqlite3 \
      nginx mariadb-server curl tar unzip git \
      certbot python3-certbot-nginx
  fi
}

# ── Web Server Repair ───────────────────────────────────────────────────────────
repair_webserver() {
  step "Checking Nginx"

  if [ "$PKG_MGR" = "apt" ]; then
    if [ ! -f /etc/nginx/nginx.conf ]; then
      echo "Nginx config missing. Reinstalling..."
      apt purge -y nginx nginx-common nginx-core || true
      apt autoremove -y || true
      apt install -y nginx
    fi
    rm -f /etc/nginx/sites-enabled/default

  elif [ "$PKG_MGR" = "dnf" ]; then
    if [ ! -f /etc/nginx/nginx.conf ]; then
      echo "Nginx config missing. Reinstalling..."
      dnf reinstall -y nginx
    fi
  fi

  nginx -t || error "Nginx config test failed"
  systemctl enable --now nginx
  systemctl restart nginx
}

# ── MariaDB Setup ───────────────────────────────────────────────────────────────
setup_database() {
  step "Setting up MariaDB"
  systemctl enable --now mariadb

  mariadb -e "CREATE DATABASE IF NOT EXISTS panel;"
  mariadb -e "CREATE USER IF NOT EXISTS 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
  mariadb -e "ALTER USER 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
  mariadb -e "GRANT ALL PRIVILEGES ON panel.* TO 'pelican'@'127.0.0.1';"
  mariadb -e "FLUSH PRIVILEGES;"
}

# ── Nginx Config ────────────────────────────────────────────────────────────────
configure_nginx() {
  step "Configuring Nginx"

  # PHP-FPM socket path differs by distro
  if [ "$PKG_MGR" = "apt" ]; then
    PHP_SOCK="unix:/run/php/php${PHP_VER}-fpm.sock"
  else
    PHP_SOCK="unix:/run/php-fpm/www.sock"
  fi

  NGINX_CONF_CONTENT="server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/pelican/public;
    index index.php;

    access_log /var/log/nginx/pelican-access.log;
    error_log /var/log/nginx/pelican-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \\.php\$ {
        fastcgi_split_path_info ^(.+\\.php)(/.+)\$;
        fastcgi_pass ${PHP_SOCK};
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE \"upload_max_filesize = 100M \\n post_max_size=100M\";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY \"\";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\\.ht {
        deny all;
    }
}"

  if [ "$PKG_MGR" = "apt" ]; then
    rm -f /etc/nginx/sites-enabled/pelican.conf
    rm -f /etc/nginx/sites-available/pelican.conf
    echo "$NGINX_CONF_CONTENT" > /etc/nginx/sites-available/pelican.conf
    ln -sf /etc/nginx/sites-available/pelican.conf /etc/nginx/sites-enabled/pelican.conf
    rm -f /etc/nginx/sites-enabled/default

  elif [ "$PKG_MGR" = "dnf" ]; then
    echo "$NGINX_CONF_CONTENT" > /etc/nginx/conf.d/pelican.conf
    # Remove default server block that ships with CentOS nginx
    sed -i 's/^[[:space:]]*listen[[:space:]]*80[[:space:]]*default_server/    listen 80/' \
      /etc/nginx/nginx.conf 2>/dev/null || true
  fi
}

# ── SELinux Config (CentOS only) ────────────────────────────────────────────────
configure_selinux() {
  if [ "$DISTRO" = "centos9" ]; then
    step "Configuring SELinux for Pelican"
    if command -v setsebool >/dev/null 2>&1; then
      setsebool -P httpd_can_network_connect 1 || true
      chcon -R -t httpd_sys_content_t /var/www/pelican 2>/dev/null || true
      chcon -R -t httpd_sys_rw_content_t /var/www/pelican/storage \
        /var/www/pelican/bootstrap/cache 2>/dev/null || true
    fi
  fi
}

# ── Panel Install ───────────────────────────────────────────────────────────────
install_panel() {
  step "Downloading Pelican Panel"

  rm -rf /var/www/pelican
  mkdir -p /var/www/pelican
  cd /var/www/pelican

  curl -L https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xzv

  if ! command -v composer >/dev/null 2>&1; then
    step "Installing Composer"
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  fi

  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

  cp .env.example .env
  php artisan key:generate --force

  configure_nginx

  chown -R ${WEB_USER}:${WEB_USER} /var/www/pelican
  chmod -R 755 /var/www/pelican/storage /var/www/pelican/bootstrap/cache

  configure_selinux

  if [ "$PKG_MGR" = "apt" ]; then
    systemctl enable --now php${PHP_VER}-fpm
  else
    systemctl enable --now php-fpm
  fi

  nginx -t
  systemctl restart nginx

  step "Setting up SSL"
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || \
    echo -e "${YELLOW}SSL setup failed — check that your domain points to this server and ports 80/443 are open.${NC}"

  step "Running migrations"
  php artisan migrate --seed --force

  step "Creating admin user"
  php artisan p:user:make
}

# ── Wings Install ───────────────────────────────────────────────────────────────
install_wings() {
  step "Installing Wings"

  mkdir -p /etc/pelican
  curl -L https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_amd64 \
    -o /usr/local/bin/wings
  chmod +x /usr/local/bin/wings

  cat > /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pelican Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pelican
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload

  echo
  echo -e "${YELLOW}Wings installed.${NC}"
  echo "Create a node in the panel, copy the Wings configure command, and run it here."
  echo "Then start Wings with: sudo systemctl enable --now wings"
}

# ── Finish Message ──────────────────────────────────────────────────────────────
finish_message() {
  echo
  echo -e "${GREEN}╔═══════════════════════════════════╗${NC}"
  echo -e "${GREEN}║        Install Complete!          ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════╝${NC}"
  echo
  echo -e "Panel URL:  ${CYAN}https://${DOMAIN}${NC}"
  echo
  echo "Next steps:"
  echo "  1. Login to the Pelican panel"
  echo "  2. Create a node"
  echo "  3. Copy the Wings configure command"
  echo "  4. Run it on this server"
  echo "  5. sudo systemctl enable --now wings"
  echo
}

# ── Main ─────────────────────────────────────────────────────────────────────────
case "$OPTION" in
  1)
    remove_broken_php_repo
    install_dependencies
    repair_webserver
    setup_database
    install_panel
    finish_message
    ;;
  2)
    install_wings
    finish_message
    ;;
  3)
    remove_broken_php_repo
    install_dependencies
    repair_webserver
    setup_database
    install_panel
    install_wings
    finish_message
    ;;
  4)
    repair_webserver
    ;;
  5)
    remove_broken_php_repo
    if [ "$PKG_MGR" = "apt" ]; then apt update; else dnf check-update || true; fi
    ;;
  *)
    error "Invalid option"
    ;;
esac#!/bin/bash
set -e

clear

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

banner() {
echo -e "${CYAN}"
echo "██████╗ ███████╗██╗     ██╗ ██████╗ █████╗ ███╗   ██╗"
echo "██╔══██╗██╔════╝██║     ██║██╔════╝██╔══██╗████╗  ██║"
echo "██████╔╝█████╗  ██║     ██║██║     ███████║██╔██╗ ██║"
echo "██╔═══╝ ██╔══╝  ██║     ██║██║     ██╔══██║██║╚██╗██║"
echo "██║     ███████╗███████╗██║╚██████╗██║  ██║██║ ╚████║"
echo "╚═╝     ╚══════╝╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝"
echo -e "${NC}"
echo -e "${GREEN}Pelican Panel Auto Installer${NC}"
echo -e "${YELLOW}Supports: Ubuntu 26.04 (PHP 8.5) | Debian 13 Trixie (PHP 8.3)${NC}"
echo
}

step() {
  echo
  echo -e "${BLUE}==>${NC} ${GREEN}$1${NC}"
}

error() {
  echo -e "${RED}ERROR:${NC} $1"
  exit 1
}

check_root() {
  if [ "$EUID" -ne 0 ]; then
    error "Run this as root: sudo bash install.sh"
  fi
}

# ── OS Detection ────────────────────────────────────────────────────────────────
detect_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_CODENAME="${VERSION_CODENAME:-}"
    OS_VERSION_ID="${VERSION_ID:-}"
  else
    error "Cannot detect OS. /etc/os-release not found."
  fi

  if [ "$OS_ID" = "ubuntu" ] && [ "$OS_VERSION_ID" = "26.04" ]; then
    DISTRO="ubuntu2604"
    PHP_VER="8.5"
    echo -e "${GREEN}Detected: Ubuntu 26.04 → using PHP 8.5${NC}"
  elif [ "$OS_ID" = "debian" ] && [ "$OS_CODENAME" = "trixie" ]; then
    DISTRO="debian13"
    PHP_VER="8.3"
    echo -e "${GREEN}Detected: Debian 13 (Trixie) → using PHP 8.3${NC}"
  else
    error "Unsupported OS: $OS_ID $OS_VERSION_ID ($OS_CODENAME). Only Ubuntu 26.04 and Debian 13 Trixie are supported."
  fi
}

banner
check_root
detect_os

echo
echo "What do you want to install?"
echo
echo "1) Install Panel only"
echo "2) Install Wings only"
echo "3) Install Panel + Wings"
echo "4) Repair Nginx"
echo "5) Remove broken PHP repo/PPA"
echo "6) Exit"
echo

read -p "Select an option [1-6]: " OPTION

if [ "$OPTION" = "6" ]; then
  echo "Exiting."
  exit 0
fi

read -p "Domain name: " DOMAIN
read -p "Email for SSL: " EMAIL
read -s -p "Database password: " DBPASS
echo

# ── PHP repo setup ──────────────────────────────────────────────────────────────
setup_php_repo() {
  if [ "$DISTRO" = "ubuntu2604" ]; then
    step "Using Ubuntu 26.04 native PHP 8.5 packages"

  elif [ "$DISTRO" = "debian13" ]; then
    step "Using Debian 13 native PHP 8.3 packages"
    apt install -y apt-transport-https ca-certificates curl lsb-release
  fi
}

# ── Remove broken PHP repos ─────────────────────────────────────────────────────
remove_broken_php_repo() {
  if [ "$DISTRO" = "ubuntu2604" ]; then
    step "Removing broken Ondrej Ubuntu PHP PPA if present"
    rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list
    rm -f /etc/apt/sources.list.d/ondrej-php*.list
    rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.sources
    rm -f /etc/apt/sources.list.d/ondrej-php*.sources

  elif [ "$DISTRO" = "debian13" ]; then
    step "Removing broken Sury Debian PHP repo if present"
    rm -f /etc/apt/sources.list.d/php.list
    rm -f /etc/apt/sources.list.d/sury-php*.list
    rm -f /usr/share/keyrings/deb.sury.org-php.gpg
    echo -e "${YELLOW}Sury PHP repo removed. Debian 13 native PHP 8.3 will be used instead.${NC}"
  fi
}

# ── Nginx repair ────────────────────────────────────────────────────────────────
repair_nginx() {
  step "Checking Nginx"
  if [ ! -f /etc/nginx/nginx.conf ]; then
    echo "Nginx config missing. Reinstalling Nginx..."
    apt purge -y nginx nginx-common nginx-core || true
    apt autoremove -y || true
    apt install -y nginx
  fi

  rm -f /etc/nginx/sites-enabled/default
  nginx -t || error "Nginx config test failed"
  systemctl enable --now nginx
  systemctl restart nginx
}

# ── Install dependencies ────────────────────────────────────────────────────────
install_dependencies() {
  setup_php_repo

  step "Updating package list"
  apt update

  step "Installing PHP ${PHP_VER} and dependencies"
  apt install -y \
    php${PHP_VER} php${PHP_VER}-cli php${PHP_VER}-fpm \
    php${PHP_VER}-gd php${PHP_VER}-mysql php${PHP_VER}-mbstring \
    php${PHP_VER}-bcmath php${PHP_VER}-xml php${PHP_VER}-curl \
    php${PHP_VER}-zip php${PHP_VER}-intl php${PHP_VER}-sqlite3 \
    nginx mariadb-server curl tar unzip git certbot python3-certbot-nginx
}

# ── MariaDB setup ───────────────────────────────────────────────────────────────
setup_database() {
  step "Setting up MariaDB"
  systemctl enable --now mariadb

  mariadb -e "CREATE DATABASE IF NOT EXISTS panel;"
  mariadb -e "CREATE USER IF NOT EXISTS 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
  mariadb -e "ALTER USER 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
  mariadb -e "GRANT ALL PRIVILEGES ON panel.* TO 'pelican'@'127.0.0.1';"
  mariadb -e "FLUSH PRIVILEGES;"
}

# ── Panel install ───────────────────────────────────────────────────────────────
install_panel() {
  step "Installing Pelican Panel"

  rm -rf /var/www/pelican
  mkdir -p /var/www/pelican
  cd /var/www/pelican

  curl -L https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xzv

  if ! command -v composer >/dev/null 2>&1; then
    step "Installing Composer"
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  fi

  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

  cp .env.example .env
  php artisan key:generate --force

  step "Configuring Nginx"

  rm -f /etc/nginx/sites-enabled/default
  rm -f /etc/nginx/sites-enabled/pelican.conf
  rm -f /etc/nginx/sites-available/pelican.conf

  cat > /etc/nginx/sites-available/pelican.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/pelican/public;
    index index.php;

    access_log /var/log/nginx/pelican-access.log;
    error_log /var/log/nginx/pelican-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_pass unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

  ln -sf /etc/nginx/sites-available/pelican.conf /etc/nginx/sites-enabled/pelican.conf

  chown -R www-data:www-data /var/www/pelican
  chmod -R 755 /var/www/pelican/storage /var/www/pelican/bootstrap/cache

  systemctl enable --now php${PHP_VER}-fpm
  nginx -t
  systemctl restart nginx

  step "Setting up SSL"
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || true

  step "Running migrations"
  php artisan migrate --seed --force

  step "Creating admin user"
  php artisan p:user:make
}

# ── Wings install ───────────────────────────────────────────────────────────────
install_wings() {
  step "Installing Wings"

  mkdir -p /etc/pelican
  curl -L https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_amd64 -o /usr/local/bin/wings
  chmod +x /usr/local/bin/wings

  cat > /etc/systemd/system/wings.service <<EOF
[Unit]
Description=Pelican Wings Daemon
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pelican
LimitNOFILE=4096
PIDFile=/var/run/wings/daemon.pid
ExecStart=/usr/local/bin/wings
Restart=on-failure
StartLimitInterval=600

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload

  echo
  echo -e "${YELLOW}Wings installed.${NC}"
  echo "Create a node in the panel, then run the Wings configure command."
}

# ── Finish ───────────────────────────────────────────────────────────────────────
finish_message() {
  echo
  echo -e "${GREEN}Install finished!${NC}"
  echo
  echo "Panel URL:"
  echo "https://${DOMAIN}"
  echo
  echo "Next steps:"
  echo "1. Login to Pelican."
  echo "2. Create a node."
  echo "3. Copy the Wings configure command."
  echo "4. Run it on this server."
  echo "5. Start Wings with:"
  echo
  echo "sudo systemctl enable --now wings"
  echo
}

# ── Main ─────────────────────────────────────────────────────────────────────────
case "$OPTION" in
  1)
    remove_broken_php_repo
    install_dependencies
    repair_nginx
    setup_database
    install_panel
    finish_message
    ;;
  2)
    install_wings
    finish_message
    ;;
  3)
    remove_broken_php_repo
    install_dependencies
    repair_nginx
    setup_database
    install_panel
    install_wings
    finish_message
    ;;
  4)
    repair_nginx
    ;;
  5)
    remove_broken_php_repo
    apt update
    ;;
  *)
    error "Invalid option"
    ;;
esac
