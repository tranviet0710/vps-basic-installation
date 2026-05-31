#!/bin/bash
# ============================================================
# SSL certificate setup using Certbot + Nginx
#
# Usage:
#   bash scripts/ssl-setup.sh <domain> [email]
#
# Examples:
#   bash scripts/ssl-setup.sh example.com admin@example.com
#   bash scripts/ssl-setup.sh example.com             # prompts for email
# ============================================================
set -euo pipefail

DOMAIN="${1:?Usage: $0 <domain> [email]}"
EMAIL="${2:-}"

echo "============================================"
echo "  SSL Setup for: $DOMAIN"
echo "============================================"

# ── Prerequisite checks ────────────────────────────────────
if ! command -v certbot &>/dev/null; then
  echo "[ERROR] Certbot is not installed."
  echo "  Run the main vps-install.sh first, or:"
  echo "  apt-get install -y certbot python3-certbot-nginx"
  exit 1
fi

if ! command -v nginx &>/dev/null; then
  echo "[ERROR] Nginx is not installed."
  exit 1
fi

# ── Ensure a basic HTTP server block exists so ACME challenge works ──
NGINX_AVAILABLE="/etc/nginx/sites-available/$DOMAIN"
NGINX_ENABLED="/etc/nginx/sites-enabled/$DOMAIN"

if [ ! -f "$NGINX_AVAILABLE" ]; then
  echo "[INFO] Creating a temporary Nginx config for $DOMAIN..."
  cat > "$NGINX_AVAILABLE" << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF
  ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"
  nginx -t && systemctl reload nginx
fi

# ── Obtain certificate ─────────────────────────────────────
echo "[INFO] Requesting certificate..."
CERTBOT_OPTS="--nginx -d $DOMAIN -d www.$DOMAIN --redirect --agree-tos --non-interactive"

if [ -n "$EMAIL" ]; then
  CERTBOT_OPTS="$CERTBOT_OPTS --email $EMAIL"
else
  CERTBOT_OPTS="$CERTBOT_OPTS --register-unsafely-without-email"
fi

# shellcheck disable=SC2086
certbot $CERTBOT_OPTS

# ── Enable auto-renewal ────────────────────────────────────
echo "[INFO] Enabling automatic renewal via systemd timer..."
systemctl enable certbot.timer
systemctl start certbot.timer

echo ""
echo "✅  SSL setup complete for $DOMAIN"
echo ""
echo "  Certificate location: /etc/letsencrypt/live/$DOMAIN/"
echo "  Auto-renewal:         enabled (certbot.timer)"
echo "  Test renewal:         certbot renew --dry-run"
echo ""
