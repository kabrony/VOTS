#!/usr/bin/env bash
################################################################################
# VOTS_Patch_OpenAI_Fix.sh
#
# Patches any mention of `openai==0.30.0` in your pinned requirements to
# `openai==1.59.6` or later. Also optionally checks for other pinned references
# that may cause conflicts (like websockets constraints).
#
# USAGE:
#   1) Place in ~/qmcs/VOTS/ next to python_agent.
#   2) chmod +x VOTS_Patch_OpenAI_Fix.sh
#   3) ./VOTS_Patch_OpenAI_Fix.sh
#   4) Rebuild the python_agent container.
################################################################################
set -e

# We'll assume your pinned references are in python_agent/requirements.txt
REQ_FILE="python_agent/requirements.txt"

if [ ! -f "$REQ_FILE" ]; then
  echo "[ERROR] Could not find $REQ_FILE - are you in the correct folder?"
  exit 1
fi

echo "=== [Step 1] Checking for 'openai==0.30.0' in $REQ_FILE ..."

# We do a quick grep
if grep -q 'openai==0\.30\.0' "$REQ_FILE"; then
  echo "[INFO] Found 'openai==0.30.0'. Will replace with 'openai==1.59.6' ..."
  sed -i 's/openai==0\.30\.0/openai==1.59.6/' "$REQ_FILE"
  echo "[INFO] Replacement done. Confirm changes in $REQ_FILE."
else
  echo "[INFO] No line with 'openai==0.30.0' found. Not modifying openai version."
fi

# OPTIONAL: also check if user wants to remove pinned websockets or other constraints
echo "=== [Step 2] Checking if you want to remove or update anything else... ==="
# If you had leftover pinned lines, you can add more sed lines. Example:
# sed -i 's/websockets==10.4/websockets==13.4.2/' "$REQ_FILE" || true

echo "=== [Step 3] Done patching $REQ_FILE. Next steps: ==="
echo "1) docker compose build --no-cache python_agent"
echo "2) docker compose up -d"
echo "3) Check logs if any new error arises."
echo "[DONE]"
