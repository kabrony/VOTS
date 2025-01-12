#!/usr/bin/env bash
#
# fix_and_start_vots_gemini.sh
# A script to fix Dockerfiles, patch c_service "daemon" naming, handle Cargo lock version,
# add a snippet to integrate “Gemini 2.0” in python_agent, rebuild, and start all containers.

set -euo pipefail

###############################################################################
# 0) Ensure we are in the VOTS/ folder
###############################################################################
cd "$(dirname "$0")"

###############################################################################
# 1) Convert Dockerfiles to UNIX line endings
###############################################################################
if ! command -v dos2unix &>/dev/null; then
  echo "[INFO] Installing dos2unix (requires sudo)..."
  sudo apt-get update -y && sudo apt-get install -y dos2unix
fi

SERVICES=(c_service go_service python_agent nextjs_dashboard rust_service)
for svc in "${SERVICES[@]}"; do
  if [[ -f "$svc/Dockerfile" ]]; then
    echo "[STEP] Converting $svc/Dockerfile to Unix line endings..."
    dos2unix "$svc/Dockerfile"
  fi
done

###############################################################################
# 2) If cargo lock version is 4 => use a newer Rust base image
###############################################################################
if [[ -f "rust_service/Cargo.lock" ]]; then
  if grep -q '"version": 4' rust_service/Cargo.lock; then
    echo "[WARN] Detected Cargo.lock version=4; switching to rust:latest"
    sed -i 's|^FROM rust:.*|FROM rust:latest AS builder|' rust_service/Dockerfile || true
  fi
fi

###############################################################################
# 3) c_service: rename “daemon” if needed
###############################################################################
if [[ -f "c_service/main.c" ]]; then
  if grep -q 'static struct MHD_Daemon *daemon;' c_service/main.c; then
    echo "[STEP] Patching c_service 'daemon' -> 'server_daemon'..."
    sed -i 's/static struct MHD_Daemon *daemon;/static struct MHD_Daemon *server_daemon;/g' c_service/main.c
    sed -i 's/\bdaemon\b/server_daemon/g' c_service/main.c
    echo "[OK] Done c_service rename."
  fi
fi

###############################################################################
# 4) Python agent: Insert snippet referencing “Gemini 2.0”
###############################################################################
# This is purely illustrative. If your python_agent/agent.py wants to load a hypothetical “Gemini 2.0”:
if grep -q 'def run_fastapi()' python_agent/agent.py; then
  echo "[STEP] Checking if 'Gemini 2.0 snippet' is present..."
  if ! grep -q 'GEMINI_2_0_PLACEHOLDER' python_agent/agent.py; then
    echo "[STEP] Adding a small placeholder to agent.py for Gemini 2.0."
    cat <<'EOF' >> python_agent/agent.py

# GEMINI_2_0_PLACEHOLDER:
# Hypothetical snippet for advanced Gemini integration
import os

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "fake-gemini-key")
def gemini_2_infer(prompt: str) -> str:
    """
    Pretend we call some advanced Gemini 2.0 API here...
    """
    print("[Gemini 2.0] Using key:", GEMINI_API_KEY)
    return "Gemini 2.0 hypothetical response to: " + prompt

EOF
    echo "[OK] Inserted example Gemini snippet in python_agent/agent.py."
  else
    echo "[INFO] Gemini 2.0 snippet already present; skipping insertion."
  fi
fi

###############################################################################
# 5) Force static linking for Go microservice (optional if GLIBC mismatch occurs)
###############################################################################
# If your go_service logs show “GLIBC_2.32 not found,” you can build a static binary:
if [[ -f "go_service/Dockerfile" ]]; then
  if ! grep -q "CGO_ENABLED" go_service/Dockerfile; then
    echo "[STEP] Patching go_service Dockerfile to enable static build..."
    sed -i '/go build -o/a \ \ RUN CGO_ENABLED=0 go build -o /app/go_service main.go' go_service/Dockerfile
    echo "[OK] Added CGO_ENABLED=0 for static linking in go_service Dockerfile."
  else
    echo "[INFO] go_service Dockerfile already has CGO_ENABLED=0 step or similar."
  fi
fi

###############################################################################
# 6) Docker prune & rebuild
###############################################################################
echo "[STEP] Stopping & removing old containers/images..."
docker compose down --rmi all --volumes || true

echo "[STEP] Docker system prune..."
docker system prune -af || true

echo "[STEP] Building all services..."
docker compose build --progress=plain

echo "[STEP] Starting VOTS..."
docker compose up -d

echo "[DONE] Use 'docker compose logs -f <service>' to see real-time logs."
exit 0
