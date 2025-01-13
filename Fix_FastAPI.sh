#!/usr/bin/env bash
################################################################################
# Fix_FastAPI.sh
#
# This script updates or removes a pinned fastapi==0.108.0 line from
# python_agent/requirements.txt because that version is incompatible with
# chromadb (>=0.95.2) and gradio 5.x (>=0.115.2, <1.0).
#
# We'll choose fastapi==0.120.0 as a valid example. If you prefer removing the
# pin entirely, just uncomment the "Remove pinned line" section and comment out
# the "Replace pinned line" section.
#
# USAGE:
#   1) Place this script in ~/qmcs/VOTS/
#   2) chmod +x Fix_FastAPI.sh
#   3) ./Fix_FastAPI.sh
#   4) docker compose build --no-cache python_agent
#   5) docker compose up -d
################################################################################
set -e

REQ_FILE="python_agent/requirements.txt"

if [ ! -f "$REQ_FILE" ]; then
  echo "[ERROR] Could not find $REQ_FILE. Are you in the correct folder?"
  exit 1
fi

echo "=== Checking for 'fastapi==0.108.0' pinned line in $REQ_FILE ..."

if grep -Eq 'fastapi==0\.108\.0' "$REQ_FILE"; then
  echo "[INFO] Found pinned fastapi==0.108.0. Patching..."

  # ---------------------------------------------------------------------------
  # OPTION A) Replace pinned line with fastapi==0.120.0 (example)
  sed -i 's|fastapi==0\.108\.0|fastapi==0.120.0|' "$REQ_FILE"
  echo "[INFO] Replaced fastapi==0.108.0 with fastapi==0.120.0."

  # ---------------------------------------------------------------------------
  # OPTION B) (Alternate) Remove pinned line entirely
  # sed -i '/fastapi==0\.108\.0/d' "$REQ_FILE"
  # echo "[INFO] Removed pinned fastapi line. Let pip auto-resolve."
  # ---------------------------------------------------------------------------

else
  echo "[INFO] No pinned fastapi==0.108.0 found. No changes made."
fi

echo "=== Done patching fastapi. Please review $REQ_FILE. Next steps: ==="
echo "  1) docker compose build --no-cache python_agent"
echo "  2) docker compose up -d"
echo "  3) Confirm the conflict error for fastapi==0.108.0 is resolved."
echo "[DONE]"
