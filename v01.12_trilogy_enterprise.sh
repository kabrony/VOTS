#!/usr/bin/env bash
###############################################################################
# v01.12_trilogy_enterprise.sh
#
# Purpose:
#   An updated version of the trilogy script that ensures the 'origin' remote is
#   set to "git@github.com:kabrony/VOTS.git" if it doesn't exist, preventing
#   errors when fetching or rebasing from origin.
#
# Usage:
#   chmod +x v01.12_trilogy_enterprise.sh
#   ./v01.12_trilogy_enterprise.sh [commit_msg] [branch] [custom_diff_range]
#
# Environment Variables:
#   (same as previous scripts, e.g., ENABLE_AI_REFACTOR, ROLLBACK_ENABLED, etc.)
#
###############################################################################

set -Eeuo pipefail

SCRIPT_VERSION="v01.12_trilogy_enterprise.sh"
START_TIME=$(date +%s)
TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
LOG_PREFIX="[$(date +'%Y-%m-%d %H:%M:%S')] [${SCRIPT_VERSION}]"
ERROR_COUNT=0

# --- Configuration ---
COMMIT_MSG="${1:-"auto: system update $TIMESTAMP"}"
BRANCH="${2:-"main"}"
DIFF_RANGE="${3:-""}"

# Hardcoded remote URL for this example:
GIT_REMOTE_URL="git@github.com:kabrony/VOTS.git"

# --- Helper Functions ---
log_info() { echo "$LOG_PREFIX [INFO] $*"; }
log_warn() { echo "$LOG_PREFIX [WARN] $*" >&2; }
log_error() { echo "$LOG_PREFIX [ERROR] $*" >&2; }
bail_out() { log_error "$*"; exit 1; }

echo ""
log_info "=== [Step 0] Initializing: $SCRIPT_VERSION ==="
log_info "Deployment Environment: '${DEPLOYMENT_ENVIRONMENT:-'unknown'}'"
log_info "CLI args => commit_msg: '$COMMIT_MSG', branch: '$BRANCH', diff_range: '${DIFF_RANGE:-'(not specified)'}'"

# Step 1) Virtual Env Setup (optional)
echo ""
log_info "=== [Step 1] Virtual Environment Setup ==="
if [[ ! -d "./venv" ]]; then
  log_info "No venv found. Creating one at ./venv ..."
  python3 -m venv ./venv
fi

if [[ ! -f "./venv/bin/activate" ]]; then
  bail_out "Virtual environment is missing or corrupted."
fi
log_info "Virtual environment found at ./venv."

# Step 2) Trilogy Memory + Diff Range
echo ""
log_info "=== [Step 2] Trilogy Memory + Diff Range ==="
TRILOGY_MEMORY_FILE="${TRILOGY_MEMORY_FILE:-"./.trilogy_memory"}"
if [[ -f "$TRILOGY_MEMORY_FILE" ]]; then
  LAST_SUCCESSFUL_COMMIT=$(cat "$TRILOGY_MEMORY_FILE")
  if [[ -z "$DIFF_RANGE" ]]; then
    DIFF_RANGE="$LAST_SUCCESSFUL_COMMIT..HEAD"
  fi
  log_info "Loaded trilogy memory => Using diff range: '$DIFF_RANGE'"
else
  if [[ -z "$DIFF_RANGE" ]]; then
    DIFF_RANGE="HEAD~1..HEAD"
    log_info "No trilogy memory found; defaulting diff range: $DIFF_RANGE"
  else
    log_info "Using user-supplied diff range: $DIFF_RANGE"
  fi
fi

# Step 3) Git Fetch, Checkout, Rebase
echo ""
log_info "=== [Step 3] Git Fetch, Checkout, Rebase ==="

# 3a) Ensure that the 'origin' remote is set correctly
HAS_ORIGIN=$(git remote -v | grep "^origin\s" || true)
if [[ -z "$HAS_ORIGIN" ]]; then
  log_warn "No 'origin' remote found. Adding 'origin' => $GIT_REMOTE_URL"
  git remote add origin "$GIT_REMOTE_URL"
fi

# 3b) Attempt to fetch from origin
if ! git fetch origin; then
  log_warn "git fetch failed or no network. Script will attempt to proceed but it may fail."
fi

# 3c) Checkout + Rebase
if ! git checkout "$BRANCH"; then
  bail_out "Error: cannot checkout branch '$BRANCH'."
fi

if ! git pull --rebase origin "$BRANCH"; then
  log_warn "Rebase failed; attempting merge."
  if ! git pull origin "$BRANCH"; then
    bail_out "Merge also failed. Check your network or permissions."
  fi
fi

# --- Insert HPC/AI build steps or Next.js deployment steps here if needed ---

echo ""
log_info "=== [Step 5] Done. Summarizing & concluding. ==="
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

log_info "Deployment finished in ${DURATION}s with ERROR_COUNT=${ERROR_COUNT}."
cat << "EOF"

  ____  _  _    ____                        _
 / ___|| || |  / ___| _   _ _ __ __ _  __ _| | ___
 \___ \| || |_ \___ \| | | | '__/ _` |/ _` | |/ _ \
  ___) |__   _| ___) | |_| | | | (_| | (_| | |  __/
 |____/   |_| |____/ \__,_|_|  \__,_|\__, |_|\___|
                                      |___/

Trilogy Enterprise Deployment: mission complete.
EOF

exit 0
