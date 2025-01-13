#!/usr/bin/env bash
################################################################################
# Fix_FastAPI_And_Clean.sh
#
# 1) Removes any pinned fastapi==... line in python_agent/requirements.txt,
#    so pip can auto-resolve an appropriate FastAPI version. 
#
# 2) Cleans Docker cache & volumes (optional but helps ensure a fresh build).
#
# 3) Rebuilds the python_agent container with --no-cache.
#
# USAGE:
#   1) Place in ~/qmcs/VOTS
#   2) chmod +x Fix_FastAPI_And_Clean.sh
#   3) ./Fix_FastAPI_And_Clean.sh
#
# WARNINGS:
#   - Removing Docker volumes/images can cause data loss if volumes are important.
#   - The pinned fastapi line is permanently removed from python_agent/requirements.txt!
################################################################################
set -e

REQ_FILE="python_agent/requirements.txt"

echo "=== Step 0) Checking if $REQ_FILE exists..."
if [ ! -f "$REQ_FILE" ]; then
  echo "[ERROR] $REQ_FILE not found. Please run this script from the ~/qmcs/VOTS/ folder."
  exit 1
fi

echo "=== Step 1) Removing pinned 'fastapi==' line in $REQ_FILE if any..."
if grep -Eq '^fastapi==[0-9]+\.[0-9]+' "$REQ_FILE"; then
  sed -i '/^fastapi==[0-9]\+\.[0-9].*/d' "$REQ_FILE"
  echo "[INFO] Removed pinned line(s) matching 'fastapi==...'. Let pip auto-resolve now."
else
  echo "[INFO] No pinned fastapi== lines found. Skipping."
fi

echo
echo "=== Step 2) (Optional) Clean Docker cache/images/volumes to ensure a truly fresh build."
echo "    This step may remove containers, images, volumes not in use. You can skip if you want."
read -rp "Proceed with full Docker prune? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  echo "[INFO] Pruning Docker system (containers, images, networks not used, plus volumes)."
  docker compose down || true
  docker system prune --volumes -f
else
  echo "[INFO] Skipping Docker prune."
fi

echo
echo "=== Step 3) Rebuild python_agent container from scratch with --no-cache..."
docker compose build --no-cache python_agent
echo "[INFO] Build completed."

echo
echo "=== Step 4) Starting up containers..."
docker compose up -d python_agent

echo
echo "[DONE] Check logs with 'docker compose logs -f python_agent'."
echo "If there's no pinned 'fastapi==...' conflict, the fix was successful."
