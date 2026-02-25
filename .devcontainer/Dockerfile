FROM amazonlinux:2023

# =============================================================================
# System Update
# =============================================================================
RUN dnf upgrade -y

# =============================================================================
# Install LAMP Stack and WordPress Dependencies
#   - httpd         : Apache web server
#   - wget          : File downloader (used in postCreate.sh)
#   - mariadb105-server : MySQL-compatible database server
#   - php           : PHP runtime (core)
#   - php-fpm       : PHP FastCGI Process Manager
#   - php-mysqli    : MySQL/MariaDB database connectivity
#   - php-mysqlnd   : Native driver for MySQL (required by WordPress)
#   - php-json      : JSON encoding/decoding
#   - php-devel     : PHP development headers
#   - php-mbstring  : Multi-byte string support (required by WordPress/phpMyAdmin)
#   - php-xml       : XML parsing for feeds and plugins
#   - php-gd        : Image resizing and thumbnail generation
#   - php-curl      : External HTTP requests (plugin updates, APIs)
#   - php-zip       : Installing/updating plugins and themes
#   - php-intl      : Internationalisation support
# =============================================================================
RUN dnf install -y \
    httpd \
    wget \
    mariadb105-server \
    php \
    php-fpm \
    php-mysqli \
    php-mysqlnd \
    php-json \
    php-devel \
    php-mbstring \
    php-xml \
    php-gd \
    php-curl \
    php-zip \
    php-intl

# =============================================================================
# Web Root Permissions
#   - Set apache as owner of /var/www so the web server can read/write files
#   - Set SGID bit on directories so new files inherit the apache group
# Note: ec2-user is not present in a container — ownership goes directly to
#       apache, which is equivalent for development purposes.
# =============================================================================
RUN chown -R apache:apache /var/www && \
    chmod 2775 /var/www && \
    find /var/www -type d -exec chmod 2775 {} \; && \
    find /var/www -type f -exec chmod 0664 {} \;

# =============================================================================
# Network
# =============================================================================
EXPOSE 80

# =============================================================================
# Entrypoint — run Apache in the foreground so the container stays alive
# =============================================================================
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
