#!/bin/bash
set -e

### CONFIG
ADMIN_USER="admin"
ADMIN_PASS="Bismillah1jt$"
ADMIN_EMAIL="admin@example.com"
DOMAINS=(
lionsapp.gwit.xyz
portal.greywolfit.com
rvhv.greywolfit.com
dev.greywolfit.com
docs.easttroylions.org
happy.gwit.xyz
old.emeraldcitycatering.com
packergonia.gwit.xyz
af.gwit.xyz
ftp.seafloor.biz
ftp.seafloorinvestigations.com
swd.greywolfit.com
locke.gwit.xyz
wfc.gwit.xyz
)

### 1. AUTO WIPE SERVER
echo "[INFO] Removing old services..."
sudo systemctl stop apache2 nginx mysql mariadb || true
sudo apt purge -y apache2* nginx* mysql* mariadb* php* || true
sudo apt autoremove -y
sudo rm -rf /var/www/*

### 2. INSTALL DEPENDENCIES
echo "[INFO] Installing fresh stack..."
sudo apt update
sudo apt install -y nginx mariadb-server php php-cli php-mysql php-curl php-xml php-mbstring unzip curl certbot python3-certbot-nginx

# Secure MySQL root
DB_ROOT_PASS=$(openssl rand -base64 16)
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}'; FLUSH PRIVILEGES;"

### 3. INSTALL WP-CLI
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
sudo mv wp-cli.phar /usr/local/bin/wp

### 4. SETUP WORDPRESS PER DOMAIN
OUTPUT_FILE="/root/wp-credentials.txt"
echo "=== WordPress Credentials ===" | tee $OUTPUT_FILE
echo "MySQL Root Password: $DB_ROOT_PASS" | tee -a $OUTPUT_FILE
echo "" | tee -a $OUTPUT_FILE

for DOMAIN in "${DOMAINS[@]}"; do
    echo "[INFO] Setting up $DOMAIN ..."

    # DB name & user unik
    DB_NAME="wp_$(echo $DOMAIN | tr . _)"
    DB_USER="u$(openssl rand -hex 3)"
    DB_PASS=$(openssl rand -base64 12)

    sudo mysql -uroot -p${DB_ROOT_PASS} -e "CREATE DATABASE ${DB_NAME};"
    sudo mysql -uroot -p${DB_ROOT_PASS} -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    sudo mysql -uroot -p${DB_ROOT_PASS} -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

    # Folder web
    WEBROOT="/var/www/${DOMAIN}"
    sudo mkdir -p $WEBROOT
    sudo chown -R $USER:$USER $WEBROOT

    # Download & install WordPress
    wp core download --path=$WEBROOT --allow-root
    wp config create --path=$WEBROOT --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --allow-root
    wp core install --path=$WEBROOT --url="https://$DOMAIN" --title="$DOMAIN" \
        --admin_user=$ADMIN_USER --admin_password=$ADMIN_PASS --admin_email=$ADMIN_EMAIL --skip-email --allow-root

    # Generate Application Password
    APP_PASS=$(wp user application-password create $ADMIN_USER "default" --porcelain --path=$WEBROOT --allow-root)

    # Install plugins/themes
    wp plugin install yoast-seo --activate --path=$WEBROOT --allow-root
    wp theme install generatepress --activate --path=$WEBROOT --allow-root

    # Nginx config
    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
    sudo tee $NGINX_CONF > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root $WEBROOT;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx

    # SSL
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $ADMIN_EMAIL --redirect

    # Output credentials
    echo "$DOMAIN|$ADMIN_USER|$ADMIN_PASS|$APP_PASS" | tee -a $OUTPUT_FILE
done

echo "[DONE] All sites installed! Credentials saved at $OUTPUT_FILE"
