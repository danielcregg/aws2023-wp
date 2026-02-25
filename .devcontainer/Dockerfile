FROM amazonlinux:2023

# =============================================================================
# Install LAMP stack — all in one layer to keep the image size small.
# dnf clean all removes the package cache after install.
#
#   httpd             : Apache web server
#   wget              : File downloader (used in postCreate.sh)
#   mariadb105-server : MySQL-compatible database server
#   php + extensions  : PHP runtime and all modules required by WordPress
# =============================================================================
RUN dnf upgrade -y && \
    dnf install -y \
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
        php-intl && \
    dnf clean all && \
    rm -rf /var/cache/dnf

# =============================================================================
# Web Root Permissions
#   - apache group owns /var/www so the web server can read and write files
#   - SGID bit on directories ensures new files inherit the apache group
# =============================================================================
RUN chown -R apache:apache /var/www && \
    chmod 2775 /var/www && \
    find /var/www -type d -exec chmod 2775 {} \; && \
    find /var/www -type f -exec chmod 0664 {} \;

EXPOSE 80

# Run Apache in the foreground so the container stays alive
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
