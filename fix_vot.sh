#!/usr/bin/env bash
#
# fix_vots.sh - A script to diagnose & fix Docker Compose build issues in VOTS.
# Usage:  ./fix_vots.sh
#

set -euo pipefail

echo "=== 1) Checking Docker & Docker Compose versions ==="
docker --version || {
  echo "[ERROR] Docker not installed or not in PATH."
  exit 1
}
docker compose version || {
  echo "[ERROR] Docker Compose v2 not found."
  exit 1
}

echo "=== 2) Confirm subfolders & Dockerfiles exist. ==="

# List of expected subfolders with Dockerfiles
SERVICES=("c_service" "go_service" "python_agent" "nextjs_dashboard" "rust_service")

for SVC in "${SERVICES[@]}"; do
  if [[ ! -d "$SVC" ]]; then
    echo "[WARN] Folder '$SVC' does not exist in $(pwd)."
    continue
  fi
  DOCKERFILE="$SVC/Dockerfile"
  if [[ ! -f "$DOCKERFILE" ]]; then
    echo "[WARN] '$DOCKERFILE' not found. Possibly spelled differently or missing."
  else
    echo "Found Dockerfile -> $DOCKERFILE"
  fi
done

echo "=== 3) Converting all Dockerfiles to Unix line-endings (dos2unix) ==="
# Make sure dos2unix is installed:
if ! command -v dos2unix &>/dev/null; then
  echo "[INFO] Installing dos2unix via apt-get..."
  sudo apt-get update -y && sudo apt-get install -y dos2unix
fi

for SVC in "${SERVICES[@]}"; do
  DOCKERFILE="$SVC/Dockerfile"
  if [[ -f "$DOCKERFILE" ]]; then
    echo "dos2unix: $DOCKERFILE"
    dos2unix "$DOCKERFILE"
  fi
done

echo "=== 4) Checking for 'daemon' conflict in c_service/main.c ==="
C_MAIN="c_service/main.c"
if [[ -f "$C_MAIN" ]]; then
  # grep to see if there's a line with "static struct MHD_Daemon *daemon;"
  if grep -q "static struct MHD_Daemon *daemon;" "$C_MAIN"; then
    echo "[INFO] c_service/main.c has a 'daemon' variable that can conflict with <unistd.h> 'daemon()'."
    echo "[INFO] Attempting to rename 'daemon' -> 'server_daemon'..."
    sed -i 's/static struct MHD_Daemon *daemon;/static struct MHD_Daemon *server_daemon;/g' "$C_MAIN"
    sed -i 's/(daemon)/(server_daemon)/g' "$C_MAIN"
    # also fix references in code
    sed -i 's/if (daemon)/if (server_daemon)/g' "$C_MAIN"
    sed -i 's/MHD_stop_daemon(daemon)/MHD_stop_daemon(server_daemon)/g' "$C_MAIN"
    sed -i 's/daemon = MHD_start_daemon/server_daemon = MHD_start_daemon/g' "$C_MAIN"
    echo "[OK] Renamed 'daemon' -> 'server_daemon'. You might need to rebuild c_service."
  fi
fi

echo "=== 5) Checking for cargo lock mismatch in rust_service. ==="
if [[ -d "rust_service" ]]; then
  # If we see "lock file version `4` was found"
  if grep -q '"version": 4' rust_service/Cargo.lock 2>/dev/null; then
    echo "[INFO] Cargo.lock is format v4, which old Cargo can't parse (e.g. 1.72)."
    echo "    Options:"
    echo "    A) Switch Dockerfile to rust:latest or a newer version (1.74+)."
    echo "    B) Regenerate lock with an older cargo."
    echo "Attempting fix A: Using 'rust:latest' in rust_service/Dockerfile..."

    RUSTFILE="rust_service/Dockerfile"
    if [[ -f "$RUSTFILE" ]]; then
      # Switch the FROM line from rust:1.72-slim -> rust:latest
      sed -i 's|^FROM rust:1\.72.*|FROM rust:latest AS builder|g' "$RUSTFILE"
      echo "[OK] Rewrote Dockerfile to FROM rust:latest. You can revert if you like."
    else
      echo "[WARN] No rust_service/Dockerfile found to fix."
    fi
  fi
fi

echo "=== 6) Attempt Docker Compose build again... ==="
docker compose build --progress=plain || {
  echo "[ERROR] Docker Compose build failed. See logs above."
  exit 1
}

echo "=== 7) If build succeeded, start containers in the background ==="
docker compose up -d || {
  echo "[ERROR] docker compose up -d failed. Possibly a container is unhealthy."
  exit 1
}

echo
echo "[DONE] If you still see errors, check logs with 'docker compose logs -f <service>'."
exit 0
