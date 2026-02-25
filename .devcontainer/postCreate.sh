#!/bin/bash
# =============================================================================
# postCreate.sh
# Runs once after the dev container is built.
# Sets up a fully working WordPress + phpMyAdmin environment.
# =============================================================================
set -e

# =============================================================================
# 1. Start Services
# =============================================================================
echo "Starting services..."
sudo systemctl start mariadb
sudo systemctl start httpd
sudo systemctl start php-fpm

# =============================================================================
# 2. WordPress Database Setup
#    Creates a dedicated database and user for WordPress.
#    Skipped automatically if the database already exists (e.g. on rebuild).
# =============================================================================
if ! sudo mysql -e "SHOW DATABASES;" | grep -q '^wordpress$'; then
    echo "Creating WordPress database and user..."
    sudo mysql <<EOF
CREATE DATABASE wordpress;
CREATE USER 'wordpressuser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpressuser'@'localhost';
FLUSH PRIVILEGES;
EOF
    echo "WordPress database and user created."
else
    echo "WordPress database already exists, skipping."
fi

# =============================================================================
# 3. Install WordPress
#    Downloads the latest WordPress release, extracts it to /var/www/html/,
#    and sets Apache as the owner.
#    Skipped automatically if WordPress is already installed.
# =============================================================================
if [ ! -f /var/www/html/wp-login.php ]; then
    echo "Downloading WordPress..."
    wget -q -P /home/$USER/ https://wordpress.org/latest.tar.gz
    tar zxf /home/$USER/latest.tar.gz -C /home/$USER/
    rm /home/$USER/latest.tar.gz
    sudo cp -rf /home/$USER/wordpress/* /var/www/html/
    rm -rf /home/$USER/wordpress
    sudo chown -R apache:apache /var/www/html/
    sudo chmod -R 755 /var/www/html/
    echo "WordPress installed at /var/www/html/"
else
    echo "WordPress already installed, skipping."
fi

# =============================================================================
# 4. Install phpMyAdmin
#    Downloads the latest phpMyAdmin release and extracts it to
#    /var/www/html/phpMyAdmin/ for browser-based database management.
#    Skipped automatically if phpMyAdmin is already installed.
# =============================================================================
if [ ! -d /var/www/html/phpMyAdmin ]; then
    echo "Downloading phpMyAdmin..."
    wget -q -P /tmp/ https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
    mkdir -p /var/www/html/phpMyAdmin
    tar -xzf /tmp/phpMyAdmin-latest-all-languages.tar.gz -C /var/www/html/phpMyAdmin --strip-components 1
    rm /tmp/phpMyAdmin-latest-all-languages.tar.gz
    sudo chown -R apache:apache /var/www/html/phpMyAdmin
    echo "phpMyAdmin installed at /var/www/html/phpMyAdmin"
else
    echo "phpMyAdmin already installed, skipping."
fi

# =============================================================================
# 5. Restart Apache
#    Ensures all PHP extensions and new files are picked up cleanly.
# =============================================================================
sudo systemctl restart httpd

# =============================================================================
# Done
# =============================================================================
echo ""
echo "============================================"
echo " Setup complete!"
echo " WordPress  : http://localhost/"
echo " phpMyAdmin : http://localhost/phpMyAdmin"
echo "============================================"
