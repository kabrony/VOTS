#!/usr/bin/env bash
###############################################################################
# fix_build_and_run_dashboard.sh
# 
# A script to:
#   1. Stop and remove Docker containers (optional prune).
#   2. Rebuild images.
#   3. Start services with docker-compose.
#   4. Check logs for the Next.js dashboard.
#   5. Optionally curl the dashboard port to confirm it's running.
#
# Usage:
#   chmod +x fix_build_and_run_dashboard.sh
#   ./fix_build_and_run_dashboard.sh
###############################################################################

set -Eeuo pipefail

echo "=== [Step 1/5] Stopping Docker containers..."
docker compose down || true

read -rp "Do you also want to prune all unused images/volumes? (y/N) " prune_confirm
if [[ "$prune_confirm" =~ ^[Yy]$ ]]; then
  echo "[INFO] Pruning system..."
  docker system prune -af
  docker volume prune -f
fi

echo "=== [Step 2/5] Rebuilding Docker images..."
docker compose build --no-cache

echo "=== [Step 3/5] Starting Docker containers..."
docker compose up -d

echo "=== [Step 4/5] Checking logs for 'nextjs_dashboard' container..."
docker compose logs --tail=50 --follow nextjs_dashboard &
LOG_PID=$!

# Sleep a few seconds to gather logs
sleep 10

# We can kill the tail logs if needed
kill $LOG_PID || true
echo "[INFO] Logs tailed for ~10 seconds. You can run 'docker compose logs -f nextjs_dashboard' to continue."

echo "=== [Step 5/5] Testing the Next.js dashboard port..."
# Adjust if your dashboard port is different
NEXTJS_PORT=3001
curl -I "http://localhost:${NEXTJS_PORT}" || {
  echo "[WARN] Could not curl the Next.js dashboard at port ${NEXTJS_PORT}."
  echo "Check logs or your environment. If it's running behind a reverse proxy, adjust this step."
  exit 1
}

echo "=== Done! If you see a 200 or 301 status above, Next.js dashboard is likely OK. ==="
