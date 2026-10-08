#!/usr/bin/env bash
set -Eeuo pipefail

# Pelican Panel + Wings installer
# Alpine Linux / OpenRC focused, with support for Debian/Ubuntu/RHEL-family where practical.

export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

DISTRO=''
PKG_MGR=''
INIT_SYS=''
WEB_USER=''
PHP_VER=''
PHP_PKG_PREFIX=''
PHP_FPM_SVC=''
PHP_FPM_SOCK=''
NGINX_CONF_DIR=''
NGINX_LINK_DIR=''
PANEL_DIR='/var/www/pelican'
DOMAIN=''
EMAIL=''
DBPASS=''
DBNAME='panel'
DBUSER='pelican'
OPTION=''

banner() {
  clear 2>/dev/null || true
  echo -e "${CYAN}"
  echo '██████╗ ███████╗██╗     ██╗ ██████╗ █████╗ ███╗   ██╗'
  echo '██╔══██╗██╔════╝██║     ██║██╔════╝██╔══██╗████╗  ██║'
  echo '██████╔╝█████╗  ██║     ██║██║     ███████║██╔██╗ ██║'
  echo '██╔═══╝ ██╔══╝  ██║     ██║██║     ██╔══██║██║╚██╗██║'
  echo '██║     ███████╗███████╗██║╚██████╗██║  ██║██║ ╚████║'
  echo '╚═╝     ╚══════╝╚══════╝╚═╝ ╚═════╝╚═╝  ╚═══╝╚═╝  ╚═══╝'
  echo -e "${NC}"
  echo -e "${GREEN}Pelican Panel + Wings Auto Installer${NC}"
  echo -e "${YELLOW}Alpine Linux / OpenRC optimized${NC}"
  echo
}

step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}WARN:${NC} $*"; }
error() { echo -e "${RED}ERROR:${NC} $*" >&2; exit 1; }

check_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || error "Run as root."
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "Missing command: $1"
}

svc_enable() {
  local svc="$1"
  if [[ "$INIT_SYS" == openrc ]]; then
    rc-update add "$svc" default >/dev/null 2>&1 || true
    rc-service "$svc" start >/dev/null 2>&1 || true
  else
    systemctl enable --now "$svc"
  fi
}

svc_restart() {
  local svc="$1"
  if [[ "$INIT_SYS" == openrc ]]; then
    rc-service "$svc" restart
  else
    systemctl restart "$svc"
  fi
}

wait_for_service() {
  local cmd="$1" tries="${2:-30}"
  for ((i=1; i<=tries; i++)); do
    if eval "$cmd" >/dev/null 2>&1; then return 0; fi
    sleep 1
  done
  return 1
}

detect_os() {
  [[ -f /etc/os-release ]] || error "/etc/os-release not found."
  . /etc/os-release

  case "${ID:-}" in
    alpine)
      DISTRO='alpine'
      PKG_MGR='apk'
      INIT_SYS='openrc'
      WEB_USER='nginx'
      NGINX_CONF_DIR='/etc/nginx/http.d'

      local av
      av="$(cut -d. -f1,2 /etc/alpine-release)"
      case "$av" in
        3.19|3.20|3.21|3.22|3.23) PHP_VER='8.4' ;;
        *) warn "Untested Alpine version: $av; attempting PHP 8.4." ; PHP_VER='8.4' ;;
      esac

      PHP_PKG_PREFIX="php${PHP_VER/./}"
      PHP_FPM_SVC="php-fpm${PHP_VER/./}"
      PHP_FPM_SOCK="unix:/run/php-fpm${PHP_VER/./}/php-fpm.sock"
      ;;
    ubuntu)
      DISTRO="ubuntu${VERSION_ID//./}"
      PKG_MGR='apt'; INIT_SYS='systemd'; WEB_USER='www-data'
      NGINX_CONF_DIR='/etc/nginx/sites-available'
      NGINX_LINK_DIR='/etc/nginx/sites-enabled'
      PHP_VER='8.4'
      PHP_PKG_PREFIX="php${PHP_VER}"
      PHP_FPM_SVC="php${PHP_VER}-fpm"
      PHP_FPM_SOCK="unix:/run/php/php${PHP_VER}-fpm.sock"
      ;;
    debian)
      DISTRO='debian'
      PKG_MGR='apt'; INIT_SYS='systemd'; WEB_USER='www-data'
      NGINX_CONF_DIR='/etc/nginx/sites-available'
      NGINX_LINK_DIR='/etc/nginx/sites-enabled'
      PHP_VER='8.4'
      PHP_PKG_PREFIX="php${PHP_VER}"
      PHP_FPM_SVC="php${PHP_VER}-fpm"
      PHP_FPM_SOCK="unix:/run/php/php${PHP_VER}-fpm.sock"
      ;;
    *)
      error "Unsupported OS: ${ID:-unknown}. This version is optimized for Alpine."
      ;;
  esac

  echo -e "${GREEN}Detected:${NC} ${PRETTY_NAME:-$ID} | PHP ${PHP_VER} | ${INIT_SYS}"
}

ask_questions() {
  read -r -p "Panel domain: " DOMAIN
  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || error "Invalid domain."

  read -r -p "Email for Let's Encrypt: " EMAIL
  [[ -n "$EMAIL" ]] || error "Email cannot be empty."

  read -r -s -p "MariaDB password for Pelican: " DBPASS
  echo
  [[ -n "$DBPASS" ]] || error "Database password cannot be empty."
}

install_dependencies() {
  step "Installing dependencies"

  if [[ "$PKG_MGR" == apk ]]; then
    apk update
    apk add --no-cache \
      bash curl ca-certificates tzdata openssl \
      nginx mariadb mariadb-client \
      git tar unzip wget nano \
      composer certbot certbot-nginx \
      docker \
      dcron \
      "${PHP_PKG_PREFIX}" \
      "${PHP_PKG_PREFIX}-cli" \
      "${PHP_PKG_PREFIX}-fpm" \
      "${PHP_PKG_PREFIX}-curl" \
      "${PHP_PKG_PREFIX}-dom" \
      "${PHP_PKG_PREFIX}-fileinfo" \
      "${PHP_PKG_PREFIX}-gd" \
      "${PHP_PKG_PREFIX}-iconv" \
      "${PHP_PKG_PREFIX}-intl" \
      "${PHP_PKG_PREFIX}-mbstring" \
      "${PHP_PKG_PREFIX}-mysqli" \
      "${PHP_PKG_PREFIX}-mysqlnd" \
      "${PHP_PKG_PREFIX}-openssl" \
      "${PHP_PKG_PREFIX}-pdo" \
      "${PHP_PKG_PREFIX}-pdo_mysql" \
      "${PHP_PKG_PREFIX}-pdo_sqlite" \
      "${PHP_PKG_PREFIX}-phar" \
      "${PHP_PKG_PREFIX}-posix" \
      "${PHP_PKG_PREFIX}-session" \
      "${PHP_PKG_PREFIX}-simplexml" \
      "${PHP_PKG_PREFIX}-sodium" \
      "${PHP_PKG_PREFIX}-tokenizer" \
      "${PHP_PKG_PREFIX}-xml" \
      "${PHP_PKG_PREFIX}-xmlreader" \
      "${PHP_PKG_PREFIX}-xmlwriter" \
      "${PHP_PKG_PREFIX}-zip"

    rc-update add nginx default || true
    rc-update add mariadb default || true
    rc-update add "$PHP_FPM_SVC" default || true
    rc-update add docker default || true
    rc-update add dcron default || true

    rc-service nginx start || true
    rc-service mariadb start || true
    rc-service "$PHP_FPM_SVC" start || true
    rc-service docker start || true
    rc-service dcron start || true
  else
    apt-get update
    apt-get install -y \
      nginx mariadb-server mariadb-client curl git tar unzip ca-certificates \
      certbot python3-certbot-nginx composer docker.io cron \
      "${PHP_PKG_PREFIX}" "${PHP_PKG_PREFIX}-cli" "${PHP_PKG_PREFIX}-fpm" \
      "${PHP_PKG_PREFIX}-curl" "${PHP_PKG_PREFIX}-gd" \
      "${PHP_PKG_PREFIX}-mbstring" "${PHP_PKG_PREFIX}-bcmath" \
      "${PHP_PKG_PREFIX}-xml" "${PHP_PKG_PREFIX}-zip" \
      "${PHP_PKG_PREFIX}-intl" "${PHP_PKG_PREFIX}-mysql"
  fi
}

init_mariadb() {
  step "Initializing MariaDB"

  if [[ "$DISTRO" == alpine ]]; then
    if [[ ! -d /var/lib/mysql/mysql ]]; then
      mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null
    fi
    rc-service mariadb start || true
    wait_for_service "mariadb -e 'SELECT 1'" 45 || error "MariaDB failed to start."
  else
    svc_enable mariadb
    wait_for_service "mariadb -e 'SELECT 1'" 45 || error "MariaDB failed to start."
  fi
}

setup_database() {
  init_mariadb
  step "Creating Pelican database"

  mariadb <<SQL
CREATE DATABASE IF NOT EXISTS \`${DBNAME}\`;
CREATE USER IF NOT EXISTS '${DBUSER}'@'127.0.0.1' IDENTIFIED BY '${DBPASS//\'/\'\'}';
ALTER USER '${DBUSER}'@'127.0.0.1' IDENTIFIED BY '${DBPASS//\'/\'\'}';
GRANT ALL PRIVILEGES ON \`${DBNAME}\`.* TO '${DBUSER}'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
}

configure_php() {
  step "Configuring PHP-FPM"

  if [[ "$DISTRO" == alpine ]]; then
    local fpm="/etc/php${PHP_VER/./}/php-fpm.d/www.conf"
    [[ -f "$fpm" ]] || error "PHP-FPM pool not found: $fpm"

    sed -i "s#^user = .*#user = nginx#" "$fpm"
    sed -i "s#^group = .*#group = nginx#" "$fpm"
    sed -i "s#^listen = .*#listen = /run/php-fpm${PHP_VER/./}/php-fpm.sock#" "$fpm"
    sed -i "s#^;listen.owner = .*#listen.owner = nginx#" "$fpm"
    sed -i "s#^;listen.group = .*#listen.group = nginx#" "$fpm"
    sed -i "s#^listen.owner = .*#listen.owner = nginx#" "$fpm"
    sed -i "s#^listen.group = .*#listen.group = nginx#" "$fpm"
  fi

  svc_restart "$PHP_FPM_SVC"
}

configure_nginx() {
  step "Configuring Nginx"

  mkdir -p "$NGINX_CONF_DIR"
  local conf="${NGINX_CONF_DIR}/pelican.conf"

  cat > "$conf" <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root ${PANEL_DIR}/public;
    index index.php;

    client_max_body_size 100m;
    client_body_timeout 120s;
    sendfile off;

    access_log /var/log/nginx/pelican-access.log;
    error_log /var/log/nginx/pelican-error.log warn;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        include fastcgi_params;
        fastcgi_pass ${PHP_FPM_SOCK};
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\. {
        deny all;
    }
}
EOF

  if [[ "$PKG_MGR" == apk ]]; then
    rm -f /etc/nginx/http.d/default.conf
  else
    rm -f "${NGINX_LINK_DIR}/default"
    ln -sf "$conf" "${NGINX_LINK_DIR}/pelican.conf"
  fi

  nginx -t
  svc_enable nginx
  svc_restart nginx
}

install_panel() {
  step "Installing Pelican Panel"

  rm -rf "$PANEL_DIR"
  mkdir -p "$PANEL_DIR"
  cd "$PANEL_DIR"

  curl -fL https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xz

  if ! command -v composer >/dev/null 2>&1; then
    curl -fsSL https://getcomposer.org/installer | php -- \
      --install-dir=/usr/local/bin --filename=composer
  fi

  COMPOSER_ALLOW_SUPERUSER=1 composer install \
    --no-dev --optimize-autoloader --no-interaction

  [[ -f .env ]] || cp .env.example .env
  php artisan key:generate --force

  # Configure the database used by Pelican.
  php artisan p:environment:database \
    --host=127.0.0.1 \
    --port=3306 \
    --database="$DBNAME" \
    --username="$DBUSER" \
    --password="$DBPASS" || warn "Automatic database environment setup failed; configure .env manually."

  chown -R nginx:nginx "$PANEL_DIR" 2>/dev/null || chown -R www-data:www-data "$PANEL_DIR"
  chmod -R 755 storage bootstrap/cache

  configure_php
  configure_nginx

  step "Running migrations"
  php artisan migrate --seed --force

  step "Creating administrator"
  php artisan p:user:make

  step "Configuring HTTPS"
  certbot --nginx \
    -d "$DOMAIN" \
    --non-interactive \
    --agree-tos \
    -m "$EMAIL" || warn "SSL failed. Verify DNS and that ports 80/443 are reachable."
}

install_openrc_pelican_services() {
  [[ "$DISTRO" == alpine ]] || return 0

  step "Installing Pelican OpenRC workers"

  cat > /etc/init.d/pelican-worker <<'EOF'
#!/sbin/openrc-run
name="pelican-worker"
description="Pelican queue worker"

command="/usr/bin/php"
command_args="/var/www/pelican/artisan queue:work --sleep=3 --tries=3 --max-time=3600"
command_user="nginx:nginx"
directory="/var/www/pelican"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"

depend() {
    need mariadb
    need nginx
    after php-fpm84
}
EOF

  cat > /etc/init.d/pelican-schedule <<'EOF'
#!/sbin/openrc-run
name="pelican-schedule"
description="Pelican scheduler"

command="/usr/bin/php"
command_args="/var/www/pelican/artisan schedule:work"
command_user="nginx:nginx"
directory="/var/www/pelican"
command_background=true
pidfile="/run/${RC_SVCNAME}.pid"

depend() {
    need mariadb
    after php-fpm84
}
EOF

  chmod +x /etc/init.d/pelican-worker /etc/init.d/pelican-schedule
  rc-update add pelican-worker default || true
  rc-update add pelican-schedule default || true
  rc-service pelican-worker restart || rc-service pelican-worker start || true
  rc-service pelican-schedule restart || rc-service pelican-schedule start || true

  # Laravel scheduler can also be driven by cron; keep a simple Alpine cron entry.
  mkdir -p /etc/periodic/minute
  cat > /etc/periodic/minute/pelican-schedule <<'EOF'
#!/bin/sh
cd /var/www/pelican || exit 1
/usr/bin/php artisan schedule:run >/dev/null 2>&1
EOF
  chmod +x /etc/periodic/minute/pelican-schedule
}

install_docker() {
  command -v docker >/dev/null 2>&1 && return 0

  step "Installing Docker"
  if [[ "$PKG_MGR" == apk ]]; then
    apk add --no-cache docker
  else
    apt-get install -y docker.io
  fi
  svc_enable docker
}

install_wings() {
  step "Installing Pelican Wings"
  install_docker

  mkdir -p /etc/pelican /var/run/wings

  local arch
  case "$(uname -m)" in
    x86_64|amd64) arch='amd64' ;;
    aarch64|arm64) arch='arm64' ;;
    *) error "Unsupported architecture: $(uname -m)" ;;
  esac

  curl -fL \
    "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_${arch}" \
    -o /usr/local/bin/wings
  chmod 755 /usr/local/bin/wings

  if [[ "$INIT_SYS" == openrc ]]; then
    cat > /etc/init.d/wings <<'EOF'
#!/sbin/openrc-run
name="wings"
description="Pelican Wings"

command="/usr/local/bin/wings"
command_args=""
command_background=true
directory="/etc/pelican"
pidfile="/run/wings.pid"

depend() {
    need docker
    after docker
}
EOF
    chmod +x /etc/init.d/wings
    rc-update add wings default || true
  else
    cat > /etc/systemd/system/wings.service <<'EOF'
[Unit]
Description=Pelican Wings
After=docker.service
Requires=docker.service

[Service]
User=root
WorkingDirectory=/etc/pelican
ExecStart=/usr/local/bin/wings
Restart=on-failure
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
  fi

  warn "Wings is installed. Create your node in Pelican, copy its configuration into /etc/pelican/config.yml, then start Wings."
}

health_check() {
  step "Running health checks"

  require_cmd nginx
  require_cmd php
  require_cmd mariadb

  nginx -t

  php -m | grep -qi pdo_mysql || error "PHP pdo_mysql extension is missing."
  php -m | grep -qi curl || error "PHP curl extension is missing."
  php -m | grep -qi mbstring || error "PHP mbstring extension is missing."
  php -m | grep -qi xml || error "PHP XML extension is missing."

  mariadb -e 'SELECT 1;' >/dev/null || error "MariaDB health check failed."

  [[ -S "${PHP_FPM_SOCK#unix:}" ]] || warn "PHP-FPM socket not found at ${PHP_FPM_SOCK#unix:}"

  echo -e "${GREEN}Health checks completed.${NC}"
}

finish() {
  echo
  echo -e "${GREEN}========================================${NC}"
  echo -e "${GREEN} Pelican installation complete${NC}"
  echo -e "${GREEN}========================================${NC}"
  echo
  echo "Panel: https://${DOMAIN}"
  echo "Panel directory: ${PANEL_DIR}"
  echo "Database: ${DBNAME}"
  echo

  if [[ "$INIT_SYS" == openrc ]]; then
    echo "Useful Alpine commands:"
    echo "  rc-service nginx status"
    echo "  rc-service ${PHP_FPM_SVC} status"
    echo "  rc-service mariadb status"
    echo "  rc-service docker status"
    echo "  rc-service wings start"
    echo "  rc-service pelican-worker status"
    echo "  rc-service pelican-schedule status"
  else
    echo "Useful commands:"
    echo "  systemctl status nginx"
    echo "  systemctl status ${PHP_FPM_SVC}"
    echo "  systemctl enable --now wings"
  fi
}

menu() {
  echo "1) Install Panel"
  echo "2) Install Wings"
  echo "3) Install Panel + Wings"
  echo "4) Health Check"
  echo "5) Exit"
  echo
  read -r -p "Select [1-5]: " OPTION

  case "$OPTION" in
    1)
      ask_questions
      install_dependencies
      setup_database
      install_panel
      install_openrc_pelican_services
      health_check
      finish
      ;;
    2)
      install_dependencies
      install_wings
      finish
      ;;
    3)
      ask_questions
      install_dependencies
      setup_database
      install_panel
      install_openrc_pelican_services
      install_wings
      health_check
      finish
      ;;
    4)
      health_check
      ;;
    5)
      exit 0
      ;;
    *) error "Invalid option." ;;
  esac
}

banner
check_root
require_cmd curl
detect_os
menu
