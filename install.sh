#!/usr/bin/env bash
set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

DISTRO=''
PKG_MGR=''
INIT_SYS='systemd'
WEB_USER='www-data'
PHP_VER='8.4'
PHP_PKG_PREFIX='php8.4'
PHP_FPM_SVC='php8.4-fpm'
PHP_FPM_SOCK='unix:/run/php/php8.4-fpm.sock'
NGINX_CONF_DIR=''
NGINX_LINK_DIR=''
REMI_RPM=''
PANEL_DIR='/var/www/pelican'
DOMAIN=''
EMAIL=''
DBPASS=''
OPTION=''

banner() {
  clear || true
  echo -e "${CYAN}"
  echo '██████╗ ███████╗██╗     ██╗ ██████╗ █████╗ ███╗   ██╗'
  echo '██╔══██╗██╔════╝██║     ██║██╔════╝██╔══██╗████╗  ██║'
  echo '██████╔╝█████╗  ██║     ██║██║     ███████║██╔██╗ ██║'
  echo '██╔═══╝ ██╔══╝  ██║     ██║██║     ██╔══██║██║╚██╗██║'
  echo '██║     ███████╗███████╗██║╚██████╗██║  ██║██║ ╚████║'
  echo '╚═╝     ╚══════╝╚══════╝╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝'
  echo -e "${NC}"
  echo -e "${GREEN}Pelican Panel + Wings Auto Installer${NC}"
  echo -e "${YELLOW}Ubuntu/Debian | RHEL/Rocky/Alma/CentOS/Fedora | openSUSE | Alpine${NC}"
  echo
}

step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$*${NC}"; }
warn() { echo -e "${YELLOW}WARN:${NC} $*"; }
error() { echo -e "${RED}ERROR:${NC} $*"; exit 1; }

check_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || error 'Run this as root: sudo bash install.sh'
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "Missing required command: $1"
}

svc_enable() {
  local svc="$1"
  if [[ "$INIT_SYS" == 'openrc' ]]; then
    rc-update add "$svc" default >/dev/null 2>&1 || true
    rc-service "$svc" start
  else
    systemctl enable --now "$svc"
  fi
}

svc_restart() {
  local svc="$1"
  if [[ "$INIT_SYS" == 'openrc' ]]; then
    rc-service "$svc" restart
  else
    systemctl restart "$svc"
  fi
}

version_major() { echo "${1%%.*}"; }

set_apt_php() {
  PHP_PKG_PREFIX="php${PHP_VER}"
  PHP_FPM_SVC="php${PHP_VER}-fpm"
  PHP_FPM_SOCK="unix:/run/php/php${PHP_VER}-fpm.sock"
}

set_rpm_php() {
  PHP_PKG_PREFIX='php'
  PHP_FPM_SVC='php-fpm'
  PHP_FPM_SOCK='unix:/run/php-fpm/www.sock'
}

set_suse_php() {
  PHP_PKG_PREFIX="php${PHP_VER/./}"
  PHP_FPM_SVC='php-fpm'
  PHP_FPM_SOCK='unix:/run/php-fpm/www.sock'
}

set_alpine_php() {
  local n="${PHP_VER/./}"
  PHP_PKG_PREFIX="php${n}"
  PHP_FPM_SVC="php-fpm${n}"
  PHP_FPM_SOCK="unix:/run/php-fpm${n}/php-fpm.sock"
}

detect_os() {
  [[ -f /etc/os-release ]] || error 'Cannot detect OS: /etc/os-release not found.'
  # shellcheck disable=SC1091
  . /etc/os-release

  local id="${ID:-}"
  local version_id="${VERSION_ID:-}"
  local codename="${VERSION_CODENAME:-}"
  local major
  major="$(version_major "$version_id")"

  case "$id" in
    ubuntu)
      PKG_MGR='apt'
      INIT_SYS='systemd'
      WEB_USER='www-data'
      NGINX_CONF_DIR='/etc/nginx/sites-available'
      NGINX_LINK_DIR='/etc/nginx/sites-enabled'
      case "$version_id" in
        22.04) DISTRO='ubuntu2204'; PHP_VER='8.4' ;;
        24.04) DISTRO='ubuntu2404'; PHP_VER='8.4' ;;
        26.04) DISTRO='ubuntu2604'; PHP_VER='8.5' ;;
        *) error "Unsupported Ubuntu $version_id. Supported: 22.04, 24.04, 26.04." ;;
      esac
      set_apt_php
      ;;
    debian)
      PKG_MGR='apt'
      INIT_SYS='systemd'
      WEB_USER='www-data'
      NGINX_CONF_DIR='/etc/nginx/sites-available'
      NGINX_LINK_DIR='/etc/nginx/sites-enabled'
      case "$codename" in
        bookworm) DISTRO='debian12'; PHP_VER='8.3' ;;
        trixie) DISTRO='debian13'; PHP_VER='8.4' ;;
        *) error "Unsupported Debian codename '$codename'. Supported: bookworm/12 and trixie/13." ;;
      esac
      set_apt_php
      ;;
    centos|rhel|rocky|almalinux)
      PKG_MGR='dnf'
      INIT_SYS='systemd'
      WEB_USER='nginx'
      NGINX_CONF_DIR='/etc/nginx/conf.d'
      NGINX_LINK_DIR=''
      case "$major" in
        9) DISTRO='rhel9'; PHP_VER='8.4'; REMI_RPM='https://rpms.remirepo.net/enterprise/remi-release-9.rpm' ;;
        10) DISTRO='rhel10'; PHP_VER='8.4'; REMI_RPM='https://rpms.remirepo.net/enterprise/remi-release-10.rpm' ;;
        *) error "Unsupported RHEL-family version $version_id. Supported: 9 and 10." ;;
      esac
      set_rpm_php
      ;;
    fedora)
      PKG_MGR='dnf'
      INIT_SYS='systemd'
      WEB_USER='nginx'
      NGINX_CONF_DIR='/etc/nginx/conf.d'
      NGINX_LINK_DIR=''
      DISTRO="fedora${major}"
      PHP_VER='8.4'
      set_rpm_php
      ;;
    opensuse-leap|opensuse-tumbleweed|sles)
      PKG_MGR='zypper'
      INIT_SYS='systemd'
      WEB_USER='nginx'
      NGINX_CONF_DIR='/etc/nginx/conf.d'
      NGINX_LINK_DIR=''
      DISTRO="$id"
      PHP_VER='8.4'
      set_suse_php
      ;;
    alpine)
      PKG_MGR='apk'
      INIT_SYS='openrc'
      WEB_USER='nginx'
      NGINX_CONF_DIR='/etc/nginx/http.d'
      NGINX_LINK_DIR=''
      local alpine_ver=''
      alpine_ver="$(cut -d. -f1,2 /etc/alpine-release 2>/dev/null || true)"
      case "$alpine_ver" in
        3.19|3.20) PHP_VER='8.3' ;;
        *) PHP_VER='8.4' ;;
      esac
      DISTRO='alpine'
      set_alpine_php
      ;;
    *)
      error "Unsupported OS: $id. Supported: Ubuntu/Debian, RHEL/Rocky/Alma/CentOS/Fedora, openSUSE, Alpine."
      ;;
  esac

  echo -e "${GREEN}Detected:${NC} ${PRETTY_NAME:-$id} -> package manager: ${PKG_MGR}, PHP: ${PHP_VER}"
}

ask_common_questions() {
  read -r -p 'Domain name: ' DOMAIN
  [[ -n "$DOMAIN" ]] || error 'Domain cannot be empty.'
  read -r -p 'Email for SSL: ' EMAIL
  [[ -n "$EMAIL" ]] || error 'Email cannot be empty.'
  read -r -s -p 'Database password: ' DBPASS
  echo
  [[ -n "$DBPASS" ]] || error 'Database password cannot be empty.'
}

setup_php_repo() {
  step "Preparing PHP ${PHP_VER} repository"
  case "$DISTRO" in
    ubuntu2204|ubuntu2404)
      apt-get update
      apt-get install -y software-properties-common ca-certificates curl lsb-release gnupg
      add-apt-repository -y ppa:ondrej/php
      apt-get update
      ;;
    debian12|debian13)
      apt-get update
      apt-get install -y ca-certificates curl lsb-release gnupg apt-transport-https
      curl -fsSL https://packages.sury.org/php/apt.gpg -o /usr/share/keyrings/deb.sury.org-php.gpg
      echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/sury-php.list
      apt-get update
      ;;
    ubuntu2604)
      apt-get update
      apt-get install -y ca-certificates curl lsb-release gnupg apt-transport-https
      ;;
    rhel9|rhel10)
      dnf install -y epel-release
      dnf install -y "$REMI_RPM"
      dnf module reset php -y || true
      dnf module enable "php:remi-${PHP_VER}" -y
      ;;
    fedora*)
      dnf module reset php -y || true
      ;;
    opensuse*|sles)
      zypper --non-interactive refresh
      ;;
    alpine)
      apk update
      ;;
  esac
}

remove_broken_php_repo() {
  step 'Removing known broken PHP repositories/modules if present'
  case "$PKG_MGR" in
    apt)
      rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list \
            /etc/apt/sources.list.d/ondrej-php*.list \
            /etc/apt/sources.list.d/ondrej-ubuntu-php-*.sources \
            /etc/apt/sources.list.d/ondrej-php*.sources \
            /etc/apt/sources.list.d/php.list \
            /etc/apt/sources.list.d/sury-php*.list \
            /usr/share/keyrings/deb.sury.org-php.gpg
      apt-get update || true
      ;;
    dnf)
      dnf module reset php -y || true
      rm -f /etc/yum.repos.d/remi*.repo || true
      ;;
    zypper)
      zypper --non-interactive refresh || true
      ;;
    apk)
      warn 'Alpine uses native apk repositories; nothing special to remove.'
      ;;
  esac
}

install_dependencies() {
  setup_php_repo
  step 'Installing dependencies'
  case "$PKG_MGR" in
    apt)
      apt-get install -y \
        "$PHP_PKG_PREFIX" "$PHP_PKG_PREFIX-cli" "$PHP_PKG_PREFIX-fpm" \
        "$PHP_PKG_PREFIX-gd" "$PHP_PKG_PREFIX-mysql" "$PHP_PKG_PREFIX-mbstring" \
        "$PHP_PKG_PREFIX-bcmath" "$PHP_PKG_PREFIX-xml" "$PHP_PKG_PREFIX-curl" \
        "$PHP_PKG_PREFIX-zip" "$PHP_PKG_PREFIX-intl" "$PHP_PKG_PREFIX-sqlite3" \
        nginx mariadb-server mariadb-client curl tar unzip git certbot python3-certbot-nginx cron
      ;;
    dnf)
      dnf install -y \
        php php-cli php-fpm php-gd php-mysqlnd php-mbstring php-bcmath php-xml \
        php-curl php-zip php-intl php-sqlite3 nginx mariadb-server mariadb \
        curl tar unzip git certbot python3-certbot-nginx cronie policycoreutils-python-utils
      ;;
    zypper)
      zypper --non-interactive install -y \
        "$PHP_PKG_PREFIX" "$PHP_PKG_PREFIX-cli" "$PHP_PKG_PREFIX-fpm" \
        "$PHP_PKG_PREFIX-gd" "$PHP_PKG_PREFIX-mysql" "$PHP_PKG_PREFIX-mbstring" \
        "$PHP_PKG_PREFIX-bcmath" "$PHP_PKG_PREFIX-xmlreader" "$PHP_PKG_PREFIX-curl" \
        "$PHP_PKG_PREFIX-zip" "$PHP_PKG_PREFIX-intl" "$PHP_PKG_PREFIX-sqlite" \
        nginx mariadb mariadb-client curl tar unzip git certbot python3-certbot-nginx cron
      ;;
    apk)
      apk add --no-cache \
        "$PHP_PKG_PREFIX" "$PHP_PKG_PREFIX-cli" "$PHP_PKG_PREFIX-fpm" \
        "$PHP_PKG_PREFIX-gd" "$PHP_PKG_PREFIX-pdo_mysql" "$PHP_PKG_PREFIX-mysqli" \
        "$PHP_PKG_PREFIX-mbstring" "$PHP_PKG_PREFIX-bcmath" "$PHP_PKG_PREFIX-xml" \
        "$PHP_PKG_PREFIX-curl" "$PHP_PKG_PREFIX-zip" "$PHP_PKG_PREFIX-intl" \
        "$PHP_PKG_PREFIX-sqlite3" "$PHP_PKG_PREFIX-pdo_sqlite" \
        "$PHP_PKG_PREFIX-tokenizer" "$PHP_PKG_PREFIX-session" \
        "$PHP_PKG_PREFIX-dom" "$PHP_PKG_PREFIX-openssl" \
        "$PHP_PKG_PREFIX-phar" "$PHP_PKG_PREFIX-simplexml" \
        "$PHP_PKG_PREFIX-xmlreader" "$PHP_PKG_PREFIX-xmlwriter" \
        "$PHP_PKG_PREFIX-fileinfo" "$PHP_PKG_PREFIX-iconv" \
        "$PHP_PKG_PREFIX-sodium" "$PHP_PKG_PREFIX-posix" \
        nginx mariadb mariadb-client docker \
        curl tar unzip git certbot certbot-nginx \
        composer dcron bash sudo nano wget ca-certificates tzdata

      rc-update add nginx default
      rc-update add mariadb default
      rc-update add "$PHP_FPM_SVC" default
      rc-update add docker default
      rc-update add dcron default

      rc-service nginx start
      rc-service mariadb start
      rc-service "$PHP_FPM_SVC" start
      rc-service docker start
      ;;
  esac
}

repair_webserver() {
  step 'Repairing/checking Nginx'
  case "$PKG_MGR" in
    apt)
      [[ -f /etc/nginx/nginx.conf ]] || { apt-get purge -y nginx nginx-common nginx-core || true; apt-get install -y nginx; }
      rm -f /etc/nginx/sites-enabled/default
      ;;
    dnf)
      [[ -f /etc/nginx/nginx.conf ]] || dnf reinstall -y nginx
      ;;
    zypper)
      [[ -f /etc/nginx/nginx.conf ]] || zypper --non-interactive install -y --force nginx
      ;;
    apk)
      [[ -f /etc/nginx/nginx.conf ]] || apk add --no-cache nginx
      rm -f /etc/nginx/http.d/default.conf
      ;;
  esac
  nginx -t || error 'Nginx config test failed.'
  svc_enable nginx
  svc_restart nginx
}

setup_database() {
  step 'Setting up MariaDB'
  if [[ "$DISTRO" == 'alpine' && ! -d /var/lib/mysql/mysql ]]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql >/dev/null
  fi
  svc_enable mariadb
  mariadb -e 'SELECT VERSION();' >/dev/null
  mariadb -e 'CREATE DATABASE IF NOT EXISTS panel;'
  mariadb -e "CREATE USER IF NOT EXISTS 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
  mariadb -e "ALTER USER 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
  mariadb -e "GRANT ALL PRIVILEGES ON panel.* TO 'pelican'@'127.0.0.1';"
  mariadb -e 'FLUSH PRIVILEGES;'
}

configure_php_fpm() {
  step 'Configuring PHP-FPM'
  case "$PKG_MGR" in
    dnf|zypper)
      if [[ -f /etc/php-fpm.d/www.conf ]]; then
        sed -i "s/^user = .*/user = ${WEB_USER}/" /etc/php-fpm.d/www.conf || true
        sed -i "s/^group = .*/group = ${WEB_USER}/" /etc/php-fpm.d/www.conf || true
        sed -i 's#^listen = .*#listen = /run/php-fpm/www.sock#' /etc/php-fpm.d/www.conf || true
        sed -i "s/^listen.owner = .*/listen.owner = ${WEB_USER}/" /etc/php-fpm.d/www.conf || true
        sed -i "s/^listen.group = .*/listen.group = ${WEB_USER}/" /etc/php-fpm.d/www.conf || true
      fi
      ;;
  esac
}

configure_nginx() {
  step 'Configuring Nginx'
  mkdir -p "$NGINX_CONF_DIR"
  local conf_file="${NGINX_CONF_DIR}/pelican.conf"

  cat > "$conf_file" <<EOF_NGINX
server {
    listen 80;
    server_name ${DOMAIN};

    root ${PANEL_DIR}/public;
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
        fastcgi_pass ${PHP_FPM_SOCK};
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
EOF_NGINX

  if [[ -n "$NGINX_LINK_DIR" ]]; then
    mkdir -p "$NGINX_LINK_DIR"
    rm -f "${NGINX_LINK_DIR}/default" "${NGINX_LINK_DIR}/pelican.conf"
    ln -sf "$conf_file" "${NGINX_LINK_DIR}/pelican.conf"
  fi

  [[ "$DISTRO" == 'alpine' ]] && rm -f /etc/nginx/http.d/default.conf
}

configure_selinux() {
  if [[ "$PKG_MGR" == 'dnf' ]] && command -v setsebool >/dev/null 2>&1; then
    step 'Configuring SELinux'
    setsebool -P httpd_can_network_connect 1 || true
    chcon -R -t httpd_sys_content_t "$PANEL_DIR" 2>/dev/null || true
    chcon -R -t httpd_sys_rw_content_t "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache" 2>/dev/null || true
  fi
}

install_composer() {
  if ! command -v composer >/dev/null 2>&1; then
    step 'Installing Composer'
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  fi
}

install_panel() {
  step 'Downloading Pelican Panel'
  rm -rf "$PANEL_DIR"
  mkdir -p "$PANEL_DIR"
  cd "$PANEL_DIR"
  curl -fsSL https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xz

  install_composer
  COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

  [[ -f .env ]] || cp .env.example .env
  php artisan key:generate --force

  configure_php_fpm
  configure_nginx

  chown -R "${WEB_USER}:${WEB_USER}" "$PANEL_DIR"
  chmod -R 755 "$PANEL_DIR/storage" "$PANEL_DIR/bootstrap/cache"
  configure_selinux

  svc_enable "$PHP_FPM_SVC"
  nginx -t
  svc_restart nginx

  step "Setting up SSL with Let's Encrypt"
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || \
    warn 'SSL setup failed. Check DNS, ports 80/443, and disable Cloudflare proxy during validation.'

  step 'Running migrations'
  php artisan migrate --seed --force

  step 'Creating admin user'
  php artisan p:user:make
}

install_docker_for_wings() {
  if command -v docker >/dev/null 2>&1; then
    return 0
  fi
  step 'Docker is not installed; installing distro Docker package'
  case "$PKG_MGR" in
    apt) apt-get install -y docker.io ;;
    dnf) dnf install -y docker || dnf install -y moby-engine ;;
    zypper) zypper --non-interactive install -y docker ;;
    apk) apk add --no-cache docker ;;
  esac
  svc_enable docker
}

wings_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo 'amd64' ;;
    aarch64|arm64) echo 'arm64' ;;
    *) error "Unsupported Wings architecture: $(uname -m)." ;;
  esac
}

install_wings() {
  step 'Installing Wings'
  install_docker_for_wings
  mkdir -p /etc/pelican /var/run/wings
  local arch
  arch="$(wings_arch)"
  curl -fsSL "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_${arch}" -o /usr/local/bin/wings
  chmod +x /usr/local/bin/wings

  if [[ "$INIT_SYS" == 'openrc' ]]; then
    cat > /etc/init.d/wings <<'EOF_OPENRC'
#!/sbin/openrc-run

description="Pelican Wings Daemon"
command="/usr/local/bin/wings"
command_background=true
pidfile="/var/run/wings/daemon.pid"
directory="/etc/pelican"

start_pre() {
    checkpath --directory --mode 0755 /var/run/wings
}

depend() {
    need docker
    after docker
}
EOF_OPENRC
    chmod +x /etc/init.d/wings
    rc-update add wings default
  else
    cat > /etc/systemd/system/wings.service <<'EOF_SYSTEMD'
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
EOF_SYSTEMD
    systemctl daemon-reload
  fi

  warn 'Wings installed. Create a node in the panel, copy the configure command, then start Wings.'
}

finish_message() {
  echo
  echo -e "${GREEN}Install step complete.${NC}"
  [[ -n "$DOMAIN" ]] && echo -e "Panel URL: ${CYAN}https://${DOMAIN}${NC}"
  echo
  echo 'Useful commands:'
  if [[ "$INIT_SYS" == 'openrc' ]]; then
    echo '  rc-service nginx status'
    echo '  rc-service wings start'
  else
    echo '  systemctl status nginx'
    echo '  systemctl enable --now wings'
    echo '  journalctl -u wings -f'
  fi
}

main_menu() {
  echo 'What do you want to install?'
  echo
  echo '1) Install Panel only'
  echo '2) Install Wings only'
  echo '3) Install Panel + Wings'
  echo '4) Repair Web Server'
  echo '5) Remove broken PHP repo/PPA/module'
  echo '6) Exit'
  echo
  read -r -p 'Select an option [1-6]: ' OPTION

  case "$OPTION" in
    1) ask_common_questions; remove_broken_php_repo; install_dependencies; repair_webserver; setup_database; install_panel; finish_message ;;
    2) install_wings; finish_message ;;
    3) ask_common_questions; remove_broken_php_repo; install_dependencies; repair_webserver; setup_database; install_panel; install_wings; finish_message ;;
    4) repair_webserver ;;
    5) remove_broken_php_repo ;;
    6) echo 'Exiting.' ;;
    *) error 'Invalid option.' ;;
  esac
}

banner
check_root
require_cmd curl
detect_os
main_menu
