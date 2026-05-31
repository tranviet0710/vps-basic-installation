# VPS Basic Installation

A collection of scripts and Nginx configuration templates for setting up and hosting services on a fresh Ubuntu/Debian VPS.

---

## Table of Contents

- [What's Included](#whats-included)
- [Quick Start](#quick-start)
- [What Gets Installed](#what-gets-installed)
- [Repository Structure](#repository-structure)
- [Nginx Templates](#nginx-templates)
- [Helper Scripts](#helper-scripts)
- [Best Practices](#best-practices)
- [Post-Install Checklist](#post-install-checklist)

---

## What's Included

| File / Directory | Purpose |
|---|---|
| `vps-install.sh` | One-shot setup script — installs all core tools |
| `nginx/node-app.conf` | Nginx reverse-proxy template for Node.js/PM2 apps |
| `nginx/static-site.conf` | Nginx template for static sites and SPAs |
| `scripts/deploy.sh` | Zero-downtime deployment helper (Git pull + PM2 reload) |
| `scripts/ssl-setup.sh` | Automated SSL certificate provisioning via Certbot |

---

## Quick Start

> **Requirements:** Ubuntu 22.04 / Debian 12 or later. Run as `root` or with `sudo`.

```bash
# 1. Clone this repository
git clone https://github.com/tranviet0710/vps-basic-installation.git
cd vps-basic-installation

# 2. Make scripts executable
chmod +x vps-install.sh scripts/*.sh

# 3. Run the setup script
sudo bash vps-install.sh
```

The script is fully automated. It will print a summary of all installed tools when it finishes.

---

## What Gets Installed

| Tool | Purpose |
|---|---|
| **Git** | Source code management |
| **NVM + Node.js 22** | JavaScript runtime (LTS) |
| **npm / pnpm** | Package managers |
| **PM2** | Production process manager for Node.js with auto-restart |
| **MySQL** | Relational database server |
| **Nginx** | High-performance web server / reverse proxy |
| **Redis** | In-memory data store (cache, sessions, queues) |
| **Certbot** | Free SSL/TLS certificates via Let's Encrypt |
| **Fail2ban** | Automatic IP banning for brute-force protection |
| **UFW** | Simplified firewall (allows SSH + HTTP/HTTPS by default) |

---

## Repository Structure

```
vps-basic-installation/
├── vps-install.sh            # Main installation script
├── nginx/
│   ├── node-app.conf         # Reverse-proxy template (Node.js / PM2)
│   └── static-site.conf      # Static site / SPA template
└── scripts/
    ├── deploy.sh             # Zero-downtime deploy helper
    └── ssl-setup.sh          # Certbot SSL automation
```

---

## Nginx Templates

### Node.js / PM2 Reverse Proxy (`nginx/node-app.conf`)

Use this when your app runs as a Node.js process managed by PM2.

```bash
# 1. Copy and edit the template
cp nginx/node-app.conf /etc/nginx/sites-available/yourdomain.com
nano /etc/nginx/sites-available/yourdomain.com  # replace yourdomain.com + APP_PORT

# 2. Enable the site
ln -s /etc/nginx/sites-available/yourdomain.com /etc/nginx/sites-enabled/

# 3. Test and reload Nginx
nginx -t && systemctl reload nginx
```

Features included in the template:
- HTTP → HTTPS redirect
- HTTP/2 with SSL (certificate paths filled by Certbot)
- Hardened security headers (HSTS, CSP, X-Frame-Options, …)
- Gzip compression
- Rate limiting (`limit_req_zone`)
- WebSocket support (`Upgrade` / `Connection` headers)
- Static asset caching with long `Cache-Control` TTL

### Static Site / SPA (`nginx/static-site.conf`)

Use this for plain HTML/CSS/JS sites or React/Vue/Angular builds.

```bash
cp nginx/static-site.conf /etc/nginx/sites-available/yourdomain.com
nano /etc/nginx/sites-available/yourdomain.com

ln -s /etc/nginx/sites-available/yourdomain.com /etc/nginx/sites-enabled/
nginx -t && systemctl reload nginx
```

Place your build output in `/var/www/yourdomain.com/html/`. The template includes an SPA fallback (`try_files … /index.html`) so client-side routing works.

---

## Helper Scripts

### `scripts/deploy.sh` — Zero-downtime Deploy

Pulls the latest code, installs/updates dependencies, builds, runs migrations, and reloads PM2 without downtime.

```bash
# Usage
bash scripts/deploy.sh <app-name> <app-directory> [branch]

# Example
bash scripts/deploy.sh my-api /var/www/my-api main
```

The script:
1. Runs `git pull origin <branch>`
2. Installs dependencies (`pnpm install --frozen-lockfile` / `yarn --frozen-lockfile` / `npm ci`)
3. Runs `npm run build` if a `build` script exists
4. Runs `npm run migrate` if a `migrate` script exists
5. Calls `pm2 reload <app-name>` (or starts it if new)

### `scripts/ssl-setup.sh` — Automated SSL

Issues a Let's Encrypt certificate for a domain and enables auto-renewal.

```bash
# Usage
bash scripts/ssl-setup.sh <domain> [email]

# Example
bash scripts/ssl-setup.sh example.com admin@example.com
```

The script:
1. Creates a temporary Nginx server block if none exists (for the ACME challenge)
2. Runs `certbot --nginx` to issue the certificate and patch Nginx config
3. Enables the `certbot.timer` systemd unit for automatic renewal

---

## Best Practices

### Security

- **Never expose MySQL publicly.** Connect via `localhost` or SSH tunnel. UFW is configured to block port 3306 by default.
- **Secure MySQL** immediately after install:
  ```bash
  mysql_secure_installation
  ```
- **Use strong, unique passwords** for every database user. Avoid `root` for application connections.
- **SSH hardening** — disable password auth, use key-based authentication only:
  ```bash
  # /etc/ssh/sshd_config
  PasswordAuthentication no
  PermitRootLogin prohibit-password
  ```
  Then: `systemctl restart sshd`
- **Keep packages up to date** (`apt-get upgrade -y`) or enable `unattended-upgrades`.
- **Fail2ban** is pre-configured to ban IPs after 5 failed SSH attempts within 10 minutes.

### Application Deployment

- Use **PM2** to manage Node.js processes — it handles restarts on crash and on reboot.
  ```bash
  pm2 start app.js --name my-app
  pm2 save       # persist process list
  pm2 logs       # tail logs
  pm2 monit      # live dashboard
  ```
- Store secrets in **environment variables**, not in source code. Use a `.env` file loaded by your app and excluded from Git:
  ```bash
  # .gitignore
  .env
  ```
- Run your app on an **unprivileged port** (e.g. 3000) and let Nginx proxy it.

### SSL / TLS

- Always redirect HTTP → HTTPS (already in both Nginx templates).
- Let Certbot manage your certificates — they auto-renew every 60 days via `certbot.timer`.
- Verify renewal works:
  ```bash
  certbot renew --dry-run
  ```

### Nginx

- Test config before reloading: `nginx -t`
- Reload (not restart) to avoid downtime: `systemctl reload nginx`
- Put each site in its own file under `/etc/nginx/sites-available/`, symlinked to `sites-enabled/`.
- Remove the default site if unused:
  ```bash
  rm /etc/nginx/sites-enabled/default
  ```

### Backups

- Schedule regular MySQL dumps:
  ```bash
  # Example cron job (daily at 2 AM)
  0 2 * * * mysqldump -u root mydb > /backups/mydb-$(date +\%F).sql
  ```
- Consider off-site backup (S3, Backblaze B2, etc.) for disaster recovery.

---

## Post-Install Checklist

After running `vps-install.sh`, complete these steps before going live:

- [ ] **Secure MySQL**: `mysql_secure_installation`
- [ ] **Create a dedicated DB user** (avoid using `root` in apps)
- [ ] **Disable SSH password auth** — use key-based login only
- [ ] **Copy an Nginx template** to `/etc/nginx/sites-available/` and enable it
- [ ] **Issue an SSL certificate**: `bash scripts/ssl-setup.sh yourdomain.com`
- [ ] **Deploy your app** and start it with PM2
- [ ] **Verify auto-renewal**: `certbot renew --dry-run`
- [ ] **Check UFW status**: `ufw status verbose`
- [ ] **Check Fail2ban status**: `fail2ban-client status sshd`
- [ ] **Set up backups** for your database and application files
