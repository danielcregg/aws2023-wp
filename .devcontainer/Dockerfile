FROM amazonlinux:2023

# Update all packages
RUN dnf upgrade -y

# Install Apache, PHP, and MariaDB
RUN dnf install -y httpd wget php-fpm php-mysqli php-json php php-devel mariadb105-server

# Set up permissions and ownership
RUN usermod -a -G apache ec2-user && \
    chown -R ec2-user:apache /var/www && \
    chmod 2775 /var/www && \
    find /var/www -type d -exec chmod 2775 {} \; && \
    find /var/www -type f -exec chmod 0664 {} \;

# Expose HTTP port
EXPOSE 80

# Start Apache when the container starts
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
