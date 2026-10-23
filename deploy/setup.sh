#!/usr/bin/env bash
# One-time setup for the portfolio on an Ubuntu droplet that already runs Nginx or Apache.
# Usage (from the cloned repo):  sudo bash deploy/setup.sh yourdomain.com
# It adds a NEW site for your domain only. Existing sites are left alone.
set -euo pipefail

DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then echo "Usage: sudo bash deploy/setup.sh yourdomain.com"; exit 1; fi
DOMAIN="${DOMAIN#http://}"; DOMAIN="${DOMAIN#https://}"; DOMAIN="${DOMAIN#www.}"; DOMAIN="${DOMAIN%%/*}"
if [ "$(id -u)" -ne 0 ]; then echo "Run this with sudo."; exit 1; fi

SITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAME="saurdev-portfolio"
echo "Site folder: $SITE_DIR"
echo "Domain:      $DOMAIN (and www.$DOMAIN)"

# Make sure the web server can read the files
chmod -R a+rX "$SITE_DIR"

if systemctl is-active --quiet nginx; then
  if grep -RIlE "server_name[^;]*[[:space:]](www\.)?${DOMAIN//./\\.}([[:space:];])" /etc/nginx/sites-enabled /etc/nginx/conf.d 2>/dev/null | grep -v "$NAME" ; then
    echo "Stopped: Nginx already has a site for $DOMAIN (files listed above)."
    echo "Nothing was changed. Tell Claude which site should own this domain."
    exit 1
  fi
  CONF="/etc/nginx/sites-available/$NAME"
  cat > "$CONF" <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    root $SITE_DIR;
    index index.html;

    location ~ /\.(?!well-known) { deny all; }
    location ^~ /deploy/ { deny all; }
    location = /README.md { deny all; }

    location / { try_files \$uri \$uri/ /index.html; }
    location ^~ /images/ { expires 30d; add_header Cache-Control "public"; }

    gzip on;
    gzip_types text/css application/javascript image/svg+xml;
}
NGINX
  ln -sf "$CONF" "/etc/nginx/sites-enabled/$NAME"
  nginx -t
  systemctl reload nginx
  SERVER=nginx
elif systemctl is-active --quiet apache2; then
  if grep -RIlE "Server(Name|Alias)[^#]*[[:space:]](www\.)?${DOMAIN//./\\.}([[:space:]]|$)" /etc/apache2/sites-enabled 2>/dev/null | grep -v "$NAME" ; then
    echo "Stopped: Apache already has a site for $DOMAIN (files listed above)."
    echo "Nothing was changed. Tell Claude which site should own this domain."
    exit 1
  fi
  CONF="/etc/apache2/sites-available/$NAME.conf"
  cat > "$CONF" <<APACHE
<VirtualHost *:80>
    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    DocumentRoot $SITE_DIR
    <Directory $SITE_DIR>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>
    <DirectoryMatch "/(\.git|deploy)">
        Require all denied
    </DirectoryMatch>
    <Files "README.md">
        Require all denied
    </Files>
</VirtualHost>
APACHE
  a2ensite "$NAME" >/dev/null
  apachectl configtest
  systemctl reload apache2
  SERVER=apache
else
  echo "Stopped: neither Nginx nor Apache is running on this droplet. Nothing was changed."
  exit 1
fi

# Pull new versions from GitHub every 5 minutes
cat > "/etc/cron.d/$NAME" <<CRON
*/5 * * * * root git -C $SITE_DIR pull --ff-only -q && chmod -R a+rX $SITE_DIR
CRON
chmod 644 "/etc/cron.d/$NAME"

echo
echo "Done. $DOMAIN is set up on $SERVER and will update itself from GitHub every 5 minutes."
echo "Once the domain points to this droplet, turn on HTTPS with:"
if [ "$SERVER" = nginx ]; then
  echo "  sudo apt install -y certbot python3-certbot-nginx && sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN"
else
  echo "  sudo apt install -y certbot python3-certbot-apache && sudo certbot --apache -d $DOMAIN -d www.$DOMAIN"
fi
