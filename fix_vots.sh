#!/usr/bin/env bash
#
# fix_vots.sh - Attempt to fix Dockerfile & source issues, then rebuild VOTS.
# Usage: ./fix_vots.sh
#
# Steps:
#   1) Convert Dockerfiles to Unix line endings (optional if dos2unix is installed).
#   2) Rename 'daemon' -> 'server_daemon' in c_service/main.c if found.
#   3) If Cargo.lock has "version 4", set rust_service Dockerfile to use rust:latest.
#   4) docker compose down, prune, rebuild, up.
#

set -euo pipefail

# --------------------------------------------------------
# 0) Ensure we’re in the same folder as docker-compose.yml
# --------------------------------------------------------
cd "$(dirname "$0")"

if [[ ! -f "docker-compose.yml" ]]; then
  echo "[ERROR] No docker-compose.yml found in $(pwd). Exiting."
  exit 1
fi

echo "[INFO] fix_vots.sh starting..."

# --------------------------------------------------------
# 1) Convert Dockerfiles to UNIX line endings (if dos2unix is available)
# --------------------------------------------------------
if ! command -v dos2unix &>/dev/null; then
  echo "[WARN] 'dos2unix' not installed. If CRLF line endings exist, it won't convert them."
  echo "[INFO] On Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y dos2unix"
fi

convert_to_unix() {
  local file="$1"
  if command -v dos2unix &>/dev/null; then
    echo "[INFO] Converting $file to UNIX line endings..."
    dos2unix "$file"
  fi
}

for svc in c_service go_service python_agent nextjs_dashboard rust_service; do
  df="$svc/Dockerfile"
  if [[ -f "$df" ]]; then
    convert_to_unix "$df"
  fi
done

# --------------------------------------------------------
# 2) Rename 'daemon' => 'server_daemon' in c_service/main.c, if present
# --------------------------------------------------------
C_MAIN="c_service/main.c"
if [[ -f "$C_MAIN" ]]; then
  if grep -q 'static struct MHD_Daemon *daemon;' "$C_MAIN"; then
    echo "[INFO] Renaming 'daemon' => 'server_daemon' in c_service/main.c to avoid symbol conflicts."
    sed -i 's/static struct MHD_Daemon \*daemon;/static struct MHD_Daemon *server_daemon;/g' "$C_MAIN"
    sed -i 's/\bdaemon\b/server_daemon/g' "$C_MAIN"
  else
    echo "[INFO] No 'static struct MHD_Daemon *daemon;' found in c_service/main.c; skipping rename."
  fi
fi

# --------------------------------------------------------
# 3) If Cargo.lock has version=4 => switch to rust:latest
# --------------------------------------------------------
RUST_LOCK="rust_service/Cargo.lock"
RUST_DOCKER="rust_service/Dockerfile"
if [[ -f "$RUST_LOCK" && -f "$RUST_DOCKER" ]]; then
  if grep -q '"version": 4' "$RUST_LOCK"; then
    echo "[WARN] cargo lock version=4 => using 'rust:latest' in rust_service Dockerfile..."
    sed -i 's|^FROM rust:.* AS builder|FROM rust:latest AS builder|g' "$RUST_DOCKER" || true
  else
    echo "[INFO] cargo lock file does not indicate version=4; no Dockerfile change needed."
  fi
fi

# --------------------------------------------------------
# 4) Docker cleanup: remove old containers, images, volumes
# --------------------------------------------------------
echo "[STEP] docker compose down --rmi all -v ..."
docker compose down --rmi all -v || true

echo "[STEP] docker system prune -af ..."
docker system prune -af || true

echo "[STEP] docker volume prune -f ..."
docker volume prune -f || true

# --------------------------------------------------------
# 5) Rebuild & up
# --------------------------------------------------------
echo "[STEP] docker compose build --progress=plain ..."
docker compose build --progress=plain

echo "[STEP] docker compose up -d ..."
docker compose up -d

echo "[DONE] fix_vots.sh completed. Check status/logs via:"
echo "       docker compose ps"
echo "       docker compose logs -f <service_name>"

