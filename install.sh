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
echo -e "${GREEN}Pelican Panel Ubuntu 26.04 Auto Installer${NC}"
echo -e "${YELLOW}Made for Ubuntu 26.04 + PHP 8.5${NC}"
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

banner
check_root

echo "What do you want to install?"
echo
echo "1) Install Panel only"
echo "2) Install Wings only"
echo "3) Install Panel + Wings"
echo "4) Repair Nginx"
echo "5) Remove broken Ondrej PHP PPA"
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

remove_ondrej() {
  step "Removing broken Ondrej PHP PPA if present"
  rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.list
  rm -f /etc/apt/sources.list.d/ondrej-php*.list
  rm -f /etc/apt/sources.list.d/ondrej-ubuntu-php-*.sources
  rm -f /etc/apt/sources.list.d/ondrej-php*.sources
}

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

install_dependencies() {
  step "Updating package list"
  apt update

  step "Installing dependencies"
  apt install -y \
    php8.5 php8.5-cli php8.5-fpm php8.5-gd php8.5-mysql php8.5-mbstring \
    php8.5-bcmath php8.5-xml php8.5-curl php8.5-zip php8.5-intl php8.5-sqlite3 \
    nginx mariadb-server curl tar unzip git certbot python3-certbot-nginx
}

setup_database() {
  step "Setting up MariaDB"
  systemctl enable --now mariadb

  mariadb -e "CREATE DATABASE IF NOT EXISTS panel;"
  mariadb -e "CREATE USER IF NOT EXISTS 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
  mariadb -e "ALTER USER 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
  mariadb -e "GRANT ALL PRIVILEGES ON panel.* TO 'pelican'@'127.0.0.1';"
  mariadb -e "FLUSH PRIVILEGES;"
}

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
        fastcgi_pass unix:/run/php/php8.5-fpm.sock;
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

  systemctl enable --now php8.5-fpm
  nginx -t
  systemctl restart nginx

  step "Setting up SSL"
  certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || true

  step "Running migrations"
  php artisan migrate --seed --force

  step "Creating admin user"
  php artisan p:user:make
}

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

case "$OPTION" in
  1)
    remove_ondrej
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
    remove_ondrej
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
    remove_ondrej
    apt update
    ;;
  *)
    error "Invalid option"
    ;;
esac
