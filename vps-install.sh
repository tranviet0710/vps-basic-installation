#!/bin/bash
set -e

# ============================================
# VPS Setup Script (Ubuntu/Debian)
# Run as root or with sudo
# ============================================

echo "=========================================="
echo "  VPS Setup Script - Starting..."
echo "=========================================="

# ------------------------------------------
# 1. System Update & Essential Packages
# ------------------------------------------
echo "[1/10] Updating system and installing essentials..."
apt-get update -y
apt-get upgrade -y
apt-get install -y \
  curl wget git build-essential software-properties-common \
  ufw unzip zip htop net-tools dnsutils ca-certificates gnupg lsb-release

# ------------------------------------------
# 2. Git Configuration
# ------------------------------------------
echo "[2/10] Configuring Git..."
git config --global credential.helper store

# ------------------------------------------
# 3. Install NVM & Node.js 22
# ------------------------------------------
echo "[3/10] Installing NVM and Node.js 22..."
export NVM_DIR="/root/.nvm"

curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash

# Load nvm into current shell
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Add nvm to shell profile so it persists
if ! grep -q 'NVM_DIR' /root/.bashrc 2>/dev/null; then
  cat >> /root/.bashrc << 'EOF'
export NVM_DIR="/root/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
fi

nvm install 22
nvm use 22
nvm alias default 22

echo "Node version: $(node -v)"
echo "NPM version: $(npm -v)"

# ------------------------------------------
# 4. Install Global Node.js Tools
# ------------------------------------------
echo "[4/10] Installing PM2, pnpm..."
npm install -g pm2
npm install -g pnpm

# Setup PM2 to start on boot
pm2 startup systemd -u root --hp /root
pm2 save

# ------------------------------------------
# 5. Install & Configure MySQL
# ------------------------------------------
echo "[5/10] Installing MySQL Server..."
apt-get install -y mysql-server

systemctl start mysql
systemctl enable mysql

echo "MySQL is running:"
systemctl status mysql --no-pager

echo ""
echo ">>> To secure MySQL, run: sudo mysql_secure_installation"
echo ">>> To create a user, run:"
echo "    sudo mysql"
echo "    CREATE USER 'myuser'@'localhost' IDENTIFIED BY 'your_password';"
echo "    GRANT ALL PRIVILEGES ON *.* TO 'myuser'@'localhost' WITH GRANT OPTION;"
echo "    FLUSH PRIVILEGES;"
echo ""

# ------------------------------------------
# 6. Install & Configure Nginx
# ------------------------------------------
echo "[6/10] Installing Nginx..."
apt-get install -y nginx

systemctl start nginx
systemctl enable nginx

echo "Nginx is running:"
systemctl status nginx --no-pager

# ------------------------------------------
# 7. Install Redis
# ------------------------------------------
echo "[7/10] Installing Redis..."
apt-get install -y redis-server

# Bind Redis to localhost only for security
sed -i 's/^bind .*/bind 127.0.0.1 ::1/' /etc/redis/redis.conf
# Enable supervised mode for systemd
sed -i 's/^supervised .*/supervised systemd/' /etc/redis/redis.conf

systemctl restart redis-server
systemctl enable redis-server

echo "Redis is running:"
systemctl status redis-server --no-pager

# ------------------------------------------
# 8. Install Certbot (SSL)
# ------------------------------------------
echo "[8/10] Installing Certbot for SSL..."
apt-get install -y certbot python3-certbot-nginx

echo ">>> To obtain a certificate, run:"
echo "    certbot --nginx -d yourdomain.com -d www.yourdomain.com"

# ------------------------------------------
# 9. Install Fail2ban (Intrusion Prevention)
# ------------------------------------------
echo "[9/10] Installing Fail2ban..."
apt-get install -y fail2ban

# Create a local jail config
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true
EOF

systemctl restart fail2ban
systemctl enable fail2ban

echo "Fail2ban is running:"
systemctl status fail2ban --no-pager

# ------------------------------------------
# 10. Configure Firewall (UFW)
# ------------------------------------------
echo "[10/10] Configuring firewall..."
ufw allow OpenSSH
ufw allow 'Nginx Full'
# MySQL should NOT be exposed publicly — use SSH tunneling instead.
# Uncomment the line below only if an external connection is strictly required
# and you have restricted it to a specific IP via: ufw allow from <trusted-ip> to any port 3306
# ufw allow 3306/tcp
ufw --force enable

echo ""
echo "=========================================="
echo "  VPS Setup Complete!"
echo "=========================================="
echo ""
echo "Installed:"
echo "  - Git:      $(git --version)"
echo "  - Node:     $(node -v)"
echo "  - NPM:      $(npm -v)"
echo "  - pnpm:     $(pnpm -v)"
echo "  - PM2:      $(pm2 -v)"
echo "  - MySQL:    $(mysql --version)"
echo "  - Nginx:    $(nginx -v 2>&1)"
echo "  - Redis:    $(redis-server --version)"
echo "  - Certbot:  $(certbot --version 2>&1)"
echo "  - Fail2ban: $(fail2ban-server --version 2>&1 | head -1)"
echo ""
echo "Next steps:"
echo "  1. Run 'mysql_secure_installation' to secure MySQL"
echo "  2. Copy nginx configs from nginx/ to /etc/nginx/sites-available/"
echo "  3. Deploy your app and manage with PM2 (see scripts/deploy.sh)"
echo "  4. Issue an SSL cert: certbot --nginx -d yourdomain.com"
echo "  5. Or use the helper: bash scripts/ssl-setup.sh yourdomain.com"
echo ""