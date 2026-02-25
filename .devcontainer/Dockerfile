FROM amazonlinux:2023

# Install Apache, PHP, and MySQL
RUN dnf update -y && \
    dnf install -y httpd php php-mysqlnd mariadb105-server && \
    dnf clean all

# Expose port 80 for Apache
EXPOSE 80

# Start Apache by default
CMD ["/usr/sbin/httpd", "-D", "FOREGROUND"]
