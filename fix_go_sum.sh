#!/usr/bin/env bash
# fix_go_sum.sh
#
# This script ensures go_service has go.sum and then re-builds
# with Docker Compose. It solves the "failed to compute cache key:
# ... '/go.sum': not found" error.

set -euo pipefail

# Move into the VOTS folder if not already
# (Adjust the path if needed.)
cd "$(dirname "$0")"

if [[ ! -d "go_service" ]]; then
  echo "[ERROR] No 'go_service' folder found here. Aborting."
  exit 1
fi

echo "[STEP 1] Ensuring 'go_service/go.sum' exists..."

pushd go_service >/dev/null

if [[ ! -f "go.mod" ]]; then
  echo " - [ERROR] 'go.mod' is missing! You need at least a go.mod for Go modules. Aborting."
  popd >/dev/null
  exit 1
fi

# Attempt to create or refresh go.sum
if command -v go &>/dev/null; then
  echo " - [INFO] Running 'go mod tidy' to create or refresh go.sum..."
  go mod tidy || true
else
  echo " - [WARN] 'go' not installed locally, so let's just create an empty go.sum..."
  touch go.sum
fi

# Double-check
if [[ ! -f "go.sum" ]]; then
  echo " - [WARN] go.sum still not found; creating empty go.sum."
  touch go.sum
fi

popd >/dev/null

echo "[STEP 2] Rebuilding Docker containers with Docker Compose..."

# If you want a complete rebuild:
docker compose down --rmi all || true

echo "[STEP 3] Build + Up with Docker Compose"
docker compose build --progress=plain
docker compose up -d

echo "[DONE] You can now check logs via 'docker compose logs -f go_service'."
