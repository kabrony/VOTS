#!/usr/bin/env bash
################################################################################
# Fix_Websockets.sh
#
# This script removes (or updates) any pinned websockets==13.4.2 line from
# python_agent/requirements.txt because that version may not exist on PyPI.
# Adjust below if you want a specific pinned version (e.g. websockets==14.1).
#
# USAGE:
#   1) Place this script in ~/qmcs/VOTS/
#   2) chmod +x Fix_Websockets.sh
#   3) ./Fix_Websockets.sh
#   4) docker compose build --no-cache python_agent
#   5) docker compose up -d
################################################################################
set -e

REQ_FILE="python_agent/requirements.txt"

if [ ! -f "$REQ_FILE" ]; then
  echo "[ERROR] Could not find $REQ_FILE. Are you in the correct folder?"
  exit 1
fi

echo "=== Checking for 'websockets==13.4.2' pinned lines in $REQ_FILE ..."

# If you want to remove the pinned line entirely:
if grep -Eq 'websockets==13\.4\.2' "$REQ_FILE"; then
  echo "[INFO] Found websockets==13.4.2. Removing it so pip can auto-resolve..."
  sed -i '/websockets==13\.4\.2/d' "$REQ_FILE"
  # If you prefer to pin websockets to a valid version, e.g. 14.1, uncomment the next line:
  # sed -i 's/websockets==13\.4\.2/websockets==14.1/' "$REQ_FILE"
  echo "[INFO] websockets pin removed."
fi

echo "=== Done patching websockets. Please review $REQ_FILE for changes. Next steps: ==="
echo "  1) docker compose build --no-cache python_agent"
echo "  2) docker compose up -d"
echo "  3) Confirm the error 'No matching distribution found for websockets==13.4.2' is resolved."
echo "[DONE]"
