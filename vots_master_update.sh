#!/usr/bin/env bash
###############################################################################
# vots_master_update.sh
#
# Purpose:
#   - Provide a single "master script" to:
#       1) Check .env presence (no overwrite).
#       2) Optionally prune old Docker images/volumes.
#       3) Rebuild c_service, go_service, python_agent, rust_service, nextjs_dashboard.
#       4) Start containers in the background.
#       5) Tail logs to confirm everything is up.
#
# Usage:
#   chmod +x vots_master_update.sh
#   ./vots_master_update.sh
#
# Notes:
#   - This script runs in the VOTS root folder (where docker-compose.yml is).
#   - It does not overwrite .env, only checks if it exists.
#   - You can comment/uncomment the Docker prune prompt for fully automated usage.
###############################################################################

set -Eeuo pipefail

echo "=== [Step 1] Checking .env file in current directory..."
if [[ ! -f .env ]]; then
  echo "[WARN] No .env found in $(pwd). Some services might need environment vars."
  echo "[INFO] You can create .env or ignore if you want purely default environment."
else
  echo "[OK] Found .env, no overwriting. Good to go."
fi

echo ""
echo "=== [Step 2] (Optional) Docker prune? (Remove old images/volumes) ==="
read -rp "Do you want to prune old Docker images & volumes? (y/N) " confirm_prune
if [[ "$confirm_prune" =~ ^[Yy]$ ]]; then
  echo "[INFO] Pruning old images and volumes..."
  docker system prune -af || true
  docker volume prune -f || true
else
  echo "[SKIP] No prune done."
fi

echo ""
echo "=== [Step 3] Stopping existing containers (if any)... ==="
docker compose down || true

echo ""
echo "=== [Step 4] Building containers (c_service, go_service, python_agent, rust_service, nextjs_dashboard) --no-cache... ==="
docker compose build --no-cache

echo ""
echo "=== [Step 5] Starting containers... ==="
docker compose up -d

echo ""
echo "[DONE] Docker containers rebuilt & running. Checking logs for nextjs_dashboard in 3 seconds..."
sleep 3

docker compose logs --tail=30 -f nextjs_dashboard
