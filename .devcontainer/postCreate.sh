#!/bin/bash
# =============================================================================
# postCreate.sh
# Runs once after the dev container is built.
# Sets up a fully working WordPress + phpMyAdmin environment using WP-CLI.
# =============================================================================
set -e

# =============================================================================
# Configuration Flags
#   Set to true/false to enable or disable each installation step.
# =============================================================================
INSTALL_WORDPRESS=true
INSTALL_PHPMYADMIN=true

# =============================================================================
# Output Helper Functions
#   rstep  — prints a bold section header
#   rspin  — starts a spinner with a status message
#   rstop  — stops the spinner
#   rok    — prints a green success message
#   rfail  — prints a red failure message
# =============================================================================
SPINNER_PID=""

rstep() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ▶  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

rspin() {
    local msg="$1"
    local frames='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    (
        i=0
        while true; do
            printf "\r  %s  %s  " "${frames:$((i % ${#frames})):1}" "$msg"
            sleep 0.1
            i=$((i + 1))
        done
    ) &
    SPINNER_PID=$!
}

rstop() {
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        kill "$SPINNER_PID" 2>/dev/null
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        printf "\r\033[K"
    fi
}

rok() {
    rstop
    echo "  ✔  $1"
}

rfail() {
    rstop
    echo "  ✘  $1" >&2
}

# =============================================================================
# 1. Start Services
# =============================================================================
rstep "Services"
rspin "Starting MariaDB"
sudo systemctl start mariadb
rok "MariaDB running"

rspin "Starting Apache"
sudo systemctl start httpd
rok "Apache running"

rspin "Starting PHP-FPM"
sudo systemctl start php-fpm
rok "PHP-FPM running"

# =============================================================================
# 2. WordPress
#    Uses WP-CLI for a fully automated, scriptable install.
#    - Installs WP-CLI globally
#    - Downloads WordPress core as the apache user
#    - Compiles the Imagick PHP extension from source (no EPEL needed)
#    - Creates the database, generates wp-config.php, and runs the installer
#    - Tunes PHP upload/execution limits
#    - Removes default inactive plugins and themes
#    - Installs the All-in-One WP Migration plugin
# =============================================================================
if [ "$INSTALL_WORDPRESS" = true ]; then
    rstep "WordPress"

    # -- WP-CLI --
    rspin "Installing WP-CLI"
    curl -sO https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    chmod +x wp-cli.phar
    sudo mv wp-cli.phar /usr/local/bin/wp
    rok "WP-CLI installed"

    # -- WordPress core --
    rspin "Downloading WordPress core"
    sudo mkdir -p /usr/share/httpd/.wp-cli/cache
    sudo chown -R apache:apache /usr/share/httpd/.wp-cli
    sudo -u apache wp core download --path=/var/www/html/ --quiet 2>/dev/null
    rok "WordPress downloaded"

    # -- PHP extensions --
    rspin "Installing PHP extensions"
    sudo dnf install -y php php-mysqlnd php-gd php-curl php-dom php-mbstring php-zip php-intl > /dev/null 2>&1
    rok "PHP extensions installed"

    # -- Imagick (compiled from source — no EPEL required) --
    rspin "Compiling PHP Imagick from source (this may take a minute)"
    sudo dnf check-release-update > /dev/null 2>&1 || true
    sudo dnf upgrade --releasever=latest -y > /dev/null 2>&1
    sudo dnf install -y php-devel php-pear gcc ImageMagick ImageMagick-devel > /dev/null 2>&1
    pecl download Imagick > /dev/null 2>&1
    tar -xf imagick*.tgz
    IMAGICK_DIR=$(find . -type d -name "imagick*" | head -1)
    cd "$IMAGICK_DIR"
    phpize > /dev/null 2>&1
    ./configure > /dev/null 2>&1
    make > /dev/null 2>&1
    sudo make install > /dev/null 2>&1
    echo "extension=imagick.so" | sudo tee /etc/php.d/25-imagick.ini > /dev/null
    sudo systemctl restart php-fpm 2>/dev/null || true
    sudo systemctl restart httpd > /dev/null 2>&1
    cd ..
    rm -rf imagick*
    rok "Imagick compiled and loaded"

    # -- Database --
    # Grant broad privileges temporarily so WP-CLI can create the DB,
    # then immediately restrict the user to the wordpress database only.
    rspin "Creating WordPress database"
    sudo mysql -Bse "
        CREATE USER IF NOT EXISTS wordpressuser@localhost IDENTIFIED BY 'password';
        GRANT ALL PRIVILEGES ON *.* TO wordpressuser@localhost;
        FLUSH PRIVILEGES;" 2>/dev/null
    sudo -u apache wp config create \
        --dbname=wordpress \
        --dbuser=wordpressuser \
        --dbpass=password \
        --path=/var/www/html/ \
        --quiet 2>/dev/null
    sudo -u apache wp db create --path=/var/www/html/ --quiet 2>/dev/null
    sudo mysql -Bse "
        REVOKE ALL PRIVILEGES, GRANT OPTION FROM wordpressuser@localhost;
        GRANT ALL PRIVILEGES ON wordpress.* TO wordpressuser@localhost;
        FLUSH PRIVILEGES;" 2>/dev/null
    rok "Database created and secured"

    # -- WordPress configuration --
    rspin "Configuring WordPress"
    sudo mkdir -p /var/www/html/wp-content/uploads
    sudo chmod 775 /var/www/html/wp-content/uploads
    sudo chown apache:apache /var/www/html/wp-content/uploads
    # Increase PHP limits for media uploads and long-running operations
    sudo sed -i.bak -e "s/^upload_max_filesize.*/upload_max_filesize = 512M/" \
                    -e "s/^post_max_size.*/post_max_size = 512M/" \
                    -e "s/^max_execution_time.*/max_execution_time = 300/" \
                    -e "s/^max_input_time.*/max_input_time = 300/" \
                    /etc/php.ini
    sudo systemctl restart httpd > /dev/null 2>&1
    sudo -u apache wp core install \
        --url="$(curl -s ifconfig.me)" \
        --title="Website Title" \
        --admin_user="admin" \
        --admin_password="password" \
        --admin_email="x@y.com" \
        --path=/var/www/html/ \
        --quiet 2>/dev/null
    rok "WordPress configured"

    # -- Cleanup defaults --
    rspin "Cleaning up default inactive plugins and themes"
    sudo -u apache wp plugin list --status=inactive --field=name --path=/var/www/html/ 2>/dev/null \
        | xargs --no-run-if-empty --replace=% sudo -u apache wp plugin delete % --path=/var/www/html/ --quiet 2>/dev/null
    sudo -u apache wp theme list --status=inactive --field=name --path=/var/www/html/ 2>/dev/null \
        | xargs --no-run-if-empty --replace=% sudo -u apache wp theme delete % --path=/var/www/html/ --quiet 2>/dev/null
    rok "Inactive plugins and themes removed"

    # -- All-in-One WP Migration --
    rspin "Installing All-in-One WP Migration plugin"
    sudo -u apache wp plugin install all-in-one-wp-migration --activate \
        --path=/var/www/html/ --quiet 2>/dev/null
    rok "Plugin installed and activated"

    # -- Theme updates --
    rspin "Updating themes"
    sudo -u apache wp theme update --all --path=/var/www/html/ --quiet 2>/dev/null
    rok "Themes up to date"
fi

# =============================================================================
# 3. phpMyAdmin
#    Downloads the latest release and extracts it to /var/www/html/phpMyAdmin/
#    for browser-based database management.
#    Skipped automatically if already installed.
# =============================================================================
if [ "$INSTALL_PHPMYADMIN" = true ]; then
    rstep "phpMyAdmin"

    if [ ! -d /var/www/html/phpMyAdmin ]; then
        rspin "Downloading phpMyAdmin"
        wget -q -P /tmp/ https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.tar.gz
        mkdir -p /var/www/html/phpMyAdmin
        tar -xzf /tmp/phpMyAdmin-latest-all-languages.tar.gz \
            -C /var/www/html/phpMyAdmin --strip-components 1
        rm /tmp/phpMyAdmin-latest-all-languages.tar.gz
        sudo chown -R apache:apache /var/www/html/phpMyAdmin
        rok "phpMyAdmin installed at /var/www/html/phpMyAdmin"
    else
        rok "phpMyAdmin already installed, skipping"
    fi
fi

# =============================================================================
# 4. Restart Apache
#    Final restart to ensure all extensions and config changes are active.
# =============================================================================
rstep "Finalising"
rspin "Restarting Apache"
sudo systemctl restart httpd
rok "Apache restarted"

# =============================================================================
# Done
# =============================================================================
echo ""
echo "  ╔══════════════════════════════════════════╗"
echo "  ║           Setup Complete! 🎉             ║"
echo "  ╠══════════════════════════════════════════╣"
echo "  ║  WordPress  : http://localhost/          ║"
echo "  ║  phpMyAdmin : http://localhost/phpMyAdmin║"
echo "  ╚══════════════════════════════════════════╝"
echo ""

