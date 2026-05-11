#!/bin/bash
set -e

echo "Pelican Panel Ubuntu 26.04 Installer"

if [ "$EUID" -ne 0 ]; then
  echo "Run this as root: sudo bash install.sh"
  exit 1
fi

read -p "Domain name: " DOMAIN
read -p "Email for SSL: " EMAIL
read -s -p "Database password: " DBPASS
echo

apt update
apt install -y \
  php8.5 php8.5-cli php8.5-fpm php8.5-gd php8.5-mysql php8.5-mbstring \
  php8.5-bcmath php8.5-xml php8.5-curl php8.5-zip php8.5-intl php8.5-sqlite3 \
  nginx mariadb-server curl tar unzip git certbot python3-certbot-nginx

systemctl enable --now mariadb nginx php8.5-fpm

mariadb -e "CREATE DATABASE IF NOT EXISTS panel;"
mariadb -e "CREATE USER IF NOT EXISTS 'pelican'@'127.0.0.1' IDENTIFIED BY '${DBPASS}';"
mariadb -e "GRANT ALL PRIVILEGES ON panel.* TO 'pelican'@'127.0.0.1';"
mariadb -e "FLUSH PRIVILEGES;"

rm -rf /var/www/pelican
mkdir -p /var/www/pelican
cd /var/www/pelican

curl -L https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz | tar -xzv

if ! command -v composer >/dev/null 2>&1; then
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
fi

COMPOSER_ALLOW_SUPERUSER=1 composer install --no-dev --optimize-autoloader

cp .env.example .env
php artisan key:generate --force

cat > /etc/nginx/sites-available/pelican.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    root /var/www/pelican/public;
    index index.php;

    client_max_body_size 100m;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php8.5-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/pelican.conf /etc/nginx/sites-enabled/pelican.conf
rm -f /etc/nginx/sites-enabled/default

chown -R www-data:www-data /var/www/pelican
chmod -R 755 /var/www/pelican/storage /var/www/pelican/bootstrap/cache

nginx -t
systemctl restart nginx

certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL" || true

php artisan migrate --seed --force
php artisan p:user:make

mkdir -p /etc/pelican
curl -L https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_amd64 -o /usr/local/bin/wings
chmod +x /usr/local/bin/wings

echo
echo "Install done."
echo "Panel: https://${DOMAIN}"
echo
echo "Next: create a node in Pelican, then run the Wings configure command from the panel."
