#!/usr/bin/env bash
################################################################################
# Fix_Sqlite_Batch.sh
#
# Purpose:
#   1) Update the python_agent Dockerfile to use a newer Debian base image
#      (bookworm or bullseye) that includes sqlite3 >= 3.35.0 by default.
#   2) Rebuild python_agent with --no-cache so the new sqlite3 is used.
#
# Usage:
#   1) Place in ~/qmcs/VOTS
#   2) chmod +x Fix_Sqlite_Batch.sh
#   3) ./Fix_Sqlite_Batch.sh
#
# Notes:
#   - By default, we replace "python:3.11-slim-buster" with "python:3.11-slim-bookworm".
#   - If you prefer bullseye, use "python:3.11-slim-bullseye" in the sed line below.
#   - Verify that your environment is okay with Debian 12 (bookworm).
################################################################################
set -e

DOCKERFILE_PATH="python_agent/Dockerfile"

echo "=== Step 0) Checking if $DOCKERFILE_PATH exists..."
if [ ! -f "$DOCKERFILE_PATH" ]; then
  echo "[ERROR] $DOCKERFILE_PATH not found. Please run this script from the ~/qmcs/VOTS/ folder."
  exit 1
fi

echo "=== Step 1) Updating Dockerfile to use python:3.11-slim-bookworm..."
# We search for 'python:3.11-slim-buster' and replace with 'python:3.11-slim-bookworm'.
# If your Dockerfile references it differently, adjust the sed pattern as needed.
if grep -q "python:3.11-slim-buster" "$DOCKERFILE_PATH"; then
  sed -i 's|python:3.11-slim-buster|python:3.11-slim-bookworm|' "$DOCKERFILE_PATH"
  echo "[INFO] Replaced python:3.11-slim-buster with python:3.11-slim-bookworm"
else
  echo "[INFO] python:3.11-slim-buster not found in $DOCKERFILE_PATH. Attempting direct usage anyway."
fi

echo
echo "=== Step 2) Rebuild python_agent container from scratch with --no-cache..."
docker compose build --no-cache python_agent
echo "[INFO] Build completed."

echo
echo "=== Step 3) Starting up python_agent container..."
docker compose up -d python_agent

echo
echo "[DONE] Check logs with 'docker compose logs -f python_agent'."
echo "If you no longer see 'sqlite3 < 3.35.0' errors, the fix was successful."
