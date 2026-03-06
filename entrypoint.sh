#!/bin/bash
set -e

# Fix volume permissions so Apache can write the CSS and configuration
chown -R www-data:www-data /var/www/html/web/sites
chmod -R 777 /var/www/html/web/sites/default/files
chmod -R 777 /var/www/html/web/sites/private_files

# Ensure Drush is executable
chmod +x /var/www/html/vendor/bin/drush || true

# Start Apache
exec apache2-foreground
