#!/bin/bash
set -e

# Start MariaDB
sudo systemctl start mariadb

# Start Apache
sudo systemctl start httpd

# Start PHP-FPM
sudo systemctl start php-fpm

# Install phpMyAdmin
cd /var/www/html

if [ ! -d "phpMyAdmin" ]; then
    echo "Downloading phpMyAdmin..."
    wget -q https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
    mkdir phpMyAdmin && tar -xzf phpMyAdmin-latest-all-languages.tar.gz -C phpMyAdmin --strip-components 1
    rm phpMyAdmin-latest-all-languages.tar.gz
    echo "phpMyAdmin installed at /var/www/html/phpMyAdmin"
else
    echo "phpMyAdmin already installed, skipping."
fi
