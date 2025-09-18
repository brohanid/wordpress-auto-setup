#!/bin/bash
set -e

# ========================
# CONFIG
# ========================
WP_ADMIN_USER="admin"
WP_ADMIN_PASS="Bismillah1jt$"
WP_ADMIN_EMAIL="admin@example.com"

# Domain list
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

# ========================
# 1. AUTO WIPE SERVER
# ========================
echo "[INFO] Wiping old services..."
apt purge -y nginx* apache2* mysql* mariadb* php* certbot* || true
apt autoremove -y
apt clean

# ========================
# 2. INSTALL STACK
# ========================
echo "[INFO] Installing fresh stack..."
apt update
apt install -y nginx mariadb-server php-fpm php-mysql php-cli php-curl php-gd php-xml php-mbstring unzip wget curl certbot python3-certbot-nginx

# ========================
# 3. SECURE DATABASE
# ========================
DB_ROOT_PASS=$(openssl rand -base64 18)
echo "[INFO] Setting DB root password..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}'; FLUSH PRIVILEGES;"

# ========================
# 4. INSTALL WP-CLI
# ========================
echo "[INFO] Installing WP-CLI..."
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
chmod +x wp-cli.phar
mv wp-cli.phar /usr/local/bin/wp

# ========================
# 5. LOOP DOMAIN
# ========================
RESULTS=""
for DOMAIN in "${DOMAINS[@]}"; do
    echo "[INFO] Setting up WordPress for $DOMAIN"

    # Create DB user & database
    DB_NAME="wp_$(echo $DOMAIN | tr . _)"
    DB_USER="u_$(openssl rand -hex 4)"
    DB_PASS=$(openssl rand -base64 18)

    mysql -uroot -p"${DB_ROOT_PASS}" -e "CREATE DATABASE ${DB_NAME};"
    mysql -uroot -p"${DB_ROOT_PASS}" -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    mysql -uroot -p"${DB_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

    # Setup web root
    WEBROOT="/var/www/${DOMAIN}"
    mkdir -p $WEBROOT
    cd $WEBROOT

    # Download & configure WordPress
    wp core download --allow-root
    wp config create --dbname=$DB_NAME --dbuser=$DB_USER --dbpass=$DB_PASS --dbhost=localhost --skip-check --allow-root
    wp core install --url="https://${DOMAIN}" --title="$DOMAIN" --admin_user=$WP_ADMIN_USER --admin_password=$WP_ADMIN_PASS --admin_email=$WP_ADMIN_EMAIL --skip-email --allow-root

    # Create App Password
    APP_PASS=$(wp user application-password create $WP_ADMIN_USER "default-app" --porcelain --allow-root)

    # Nginx config
    NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
    cat > $NGINX_CONF <<EOF
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
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

    ln -sf $NGINX_CONF /etc/nginx/sites-enabled/

    # Certbot SSL
    certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $WP_ADMIN_EMAIL --redirect || true

    # Add result to output
    RESULTS+="$DOMAIN | $WP_ADMIN_USER | $WP_ADMIN_PASS | $APP_PASS"$'\n'
done

# ========================
# 6. FINALIZE
# ========================
echo "[INFO] Restarting Nginx & PHP..."
systemctl restart nginx php8.3-fpm mariadb

echo ""
echo "============================================"
echo " ALL WORDPRESS INSTALLATIONS COMPLETE "
echo "============================================"
echo "DB ROOT PASSWORD: ${DB_ROOT_PASS}"
echo ""
echo "Domain | Username | Password | App Password"
echo "--------------------------------------------"
echo "$RESULTS"
echo "============================================"