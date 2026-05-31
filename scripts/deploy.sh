#!/bin/bash
# ============================================================
# Zero-downtime deploy script for Node.js apps managed by PM2
#
# Usage:
#   bash scripts/deploy.sh <app-name> <app-directory> [branch]
#
# Examples:
#   bash scripts/deploy.sh my-api /var/www/my-api main
#   bash scripts/deploy.sh my-api /var/www/my-api
# ============================================================
set -euo pipefail

APP_NAME="${1:?Usage: $0 <app-name> <app-directory> [branch]}"
APP_DIR="${2:?Usage: $0 <app-name> <app-directory> [branch]}"
BRANCH="${3:-main}"
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

echo "============================================"
echo "  Deploy: $APP_NAME"
echo "  Dir:    $APP_DIR"
echo "  Branch: $BRANCH"
echo "  Time:   $TIMESTAMP"
echo "============================================"

# Ensure target directory exists
if [ ! -d "$APP_DIR" ]; then
  echo "[ERROR] Directory $APP_DIR does not exist."
  exit 1
fi

cd "$APP_DIR"

# ── 1. Pull latest code ────────────────────────────────────
echo "[1/5] Pulling latest code from $BRANCH..."
git fetch --all
git checkout "$BRANCH"
git pull origin "$BRANCH"

# ── 2. Install / update dependencies ──────────────────────
echo "[2/5] Installing dependencies..."
if [ -f "pnpm-lock.yaml" ]; then
  pnpm install --frozen-lockfile
elif [ -f "yarn.lock" ]; then
  yarn install --frozen-lockfile
else
  npm ci
fi

# ── 3. Build (if applicable) ───────────────────────────────
echo "[3/5] Building application..."
if [ -f "package.json" ] && grep -q '"build"' package.json; then
  npm run build 2>/dev/null || pnpm run build 2>/dev/null || true
else
  echo "  No build script found, skipping."
fi

# ── 4. Run database migrations (if applicable) ────────────
echo "[4/5] Running migrations (if any)..."
if [ -f "package.json" ] && grep -q '"migrate"' package.json; then
  npm run migrate 2>/dev/null || pnpm run migrate 2>/dev/null || true
else
  echo "  No migrate script found, skipping."
fi

# ── 5. Reload / start PM2 process ─────────────────────────
echo "[5/5] Reloading PM2 process '$APP_NAME'..."
if pm2 describe "$APP_NAME" > /dev/null 2>&1; then
  pm2 reload "$APP_NAME" --update-env
  echo "  PM2 process reloaded."
else
  pm2 start npm --name "$APP_NAME" -- start
  echo "  PM2 process started."
fi

pm2 save

echo ""
echo "✅  Deploy complete: $APP_NAME @ $TIMESTAMP"
echo ""
