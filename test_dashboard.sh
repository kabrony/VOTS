# cat test_dashboard.sh
# -------------------------------------------------------------------------
#!/usr/bin/env bash
# Purpose: Rebuild & test your Next.js dashboard container in VOTS.
# Usage:   ./test_dashboard.sh

set -e

echo "[INFO] Rebuilding nextjs_dashboard container..."
docker compose build --no-cache nextjs_dashboard

echo "[INFO] Starting nextjs_dashboard container..."
docker compose up -d nextjs_dashboard

echo "[INFO] Checking logs (Ctrl+C to quit)..."
docker compose logs -f nextjs_dashboard


# -------------------------------------------------------------------------
# cat new_rust_tool.sh
