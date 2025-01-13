#!/usr/bin/env bash
################################################################################
# Fix_Gradio_OpenAI.sh
#
# This script updates references to older or missing pinned Gradio / OpenAI versions
# in your python_agent’s requirements. If you had `gradio==4.53.0` or
# `openai==0.30.0` (both may be missing from PyPI or incompatible), it patches them
# to the latest stable (as of early 2025):
#   - gradio==5.12.0
#   - openai==1.59.6
#
# Then you can rebuild to avoid "No matching distribution found" errors.
#
# USAGE:
#   1) Place this script in ~/qmcs/VOTS/
#   2) chmod +x Fix_Gradio_OpenAI.sh
#   3) ./Fix_Gradio_OpenAI.sh
#   4) docker compose build --no-cache python_agent
#   5) docker compose up -d
################################################################################
set -e

REQ_FILE="python_agent/requirements.txt"

if [ ! -f "$REQ_FILE" ]; then
  echo "[ERROR] Could not find $REQ_FILE. Are you in the correct folder?"
  exit 1
fi

echo "=== [Step 1] Checking for 'gradio==4.' or 'openai==0.' pinned lines in $REQ_FILE ..."

# If you have pinned lines for older Gradio / OpenAI, patch them:
# For example, if you see: gradio==4.53.0 => replace with gradio==5.12.0
# And openai==0.30.0 => replace with openai==1.59.6
# Adjust below if you want different pinned versions.

# Patch old gradio references
if grep -Eq 'gradio==4\.[0-9]+\.[0-9]+' "$REQ_FILE"; then
  echo "[INFO] Found a pinned Gradio 4.x in $REQ_FILE. Replacing with 'gradio==5.12.0' ..."
  sed -i 's/gradio==4\.[0-9]\+\.[0-9]\+/gradio==5.12.0/g' "$REQ_FILE"
  echo "[INFO] Replacement done for Gradio."
fi

# Patch old openai references
if grep -Eq 'openai==0\.[0-9]+\.[0-9]+' "$REQ_FILE"; then
  echo "[INFO] Found a pinned OpenAI 0.x in $REQ_FILE. Replacing with 'openai==1.59.6' ..."
  sed -i 's/openai==0\.[0-9]\+\.[0-9]\+/openai==1.59.6/g' "$REQ_FILE"
  echo "[INFO] Replacement done for OpenAI."
fi

# Optionally check if user pinned a random version of gradio or openai that doesn’t exist:
# e.g. 'gradio==7.99.0' or 'openai==0.30.0' specifically
if grep -q 'gradio==7\.99\.0' "$REQ_FILE"; then
  echo "[INFO] Found 'gradio==7.99.0' (does not exist). Replacing with 'gradio==5.12.0' ..."
  sed -i 's/gradio==7\.99\.0/gradio==5.12.0/' "$REQ_FILE"
fi
if grep -q 'openai==0\.30\.0' "$REQ_FILE"; then
  echo "[INFO] Found 'openai==0.30.0' (nonexistent). Replacing with 'openai==1.59.6' ..."
  sed -i 's/openai==0\.30\.0/openai==1.59.6/' "$REQ_FILE"
fi

echo "=== [Step 2] Checking for pinned 'websockets==' or other leftover constraints that break. ==="
# You can remove or relax pinned websockets to fix conflicts with Gradio + google-genai, etc.
if grep -Eqi 'websockets==1[0-2]\.' "$REQ_FILE"; then
  echo "[INFO] Found pinned websockets <=12.x. Removing pinned line to avoid conflict..."
  sed -i '/websockets==1[0-2]\./d' "$REQ_FILE"
  echo "[INFO] websockets pinned line removed. Let pip resolve the correct version."
fi

echo "=== [Step 3] Script done. Please review $REQ_FILE for changes. Next steps: ==="
echo "  1) docker compose build --no-cache python_agent"
echo "  2) docker compose up -d"
echo "  3) Check logs for any new or leftover conflict errors."
echo "[DONE]"
