#!/usr/bin/env bash
###############################################################################
# v10_trilogy_enterprise.sh
#
# Purpose:
#   This script automates a deployment pipeline with HPC microservices,
#   optional AI-driven code refactoring, and optional Solana steps. It uses
#   "Trilogy" memory (a local file) to track the last successful commit
#   for diff-based rebuilding and potential rollback.
#
# Usage:
#   chmod +x v10_trilogy_enterprise.sh
#   ./v10_trilogy_enterprise.sh [commit_msg] [branch] [custom_diff_range]
#
# Key differences from prior versions:
#   - Defaults to main if the requested branch does not exist on the remote.
#   - Gracefully handles Git checkout failure to avoid fatal errors.
#   - Other features (AI refactor, Solana build/test, health checks, rollback)
#     remain intact.
#
# Environment Variables of interest:
#   ENABLE_AI_REFACTOR=true|false
#   ENABLE_SOLANA_STUDY=true|false
#   ROLLBACK_ENABLED=true|false
#   HEALTH_CHECK_TYPE="container"|"endpoint"
#   ENDPOINT_HEALTH_CHECK_URL="http://localhost:3001/health"
#   ...
###############################################################################

set -Eeuo pipefail

# --- Global Vars ---
SCRIPT_VERSION="v10_trilogy_enterprise.sh"
START_TIME=$(date +%s)
TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
LOG_PREFIX="[$(date +'%Y-%m-%d %H:%M:%S')] [${SCRIPT_VERSION}]"
ERROR_COUNT=0
ERROR_THRESHOLD="${ERROR_THRESHOLD:-5}"

# Logging helpers
log_info()  { echo "$LOG_PREFIX [INFO] $*"; }
log_warn()  { echo "$LOG_PREFIX [WARN] $*" >&2; }
log_error() { echo "$LOG_PREFIX [ERROR] $*" >&2; }
bail_out()  { log_error "$*"; exit 1; }

# Args & Defaults
COMMIT_MSG="${1:-"auto: system update $TIMESTAMP"}"
REQUESTED_BRANCH="${2:-"main"}"
TRILOGY_MEMORY_FILE="${TRILOGY_MEMORY_FILE:-"./.trilogy_memory"}"

# Virtual Environment
VENV_DIR="${VIRTUAL_ENV_DIR:-"./venv"}"
REQS_FILE="${REQUIREMENTS_FILE:-"requirements.txt"}"

echo ""
log_info "=== [Step 0] Initializing: $SCRIPT_VERSION ==="
log_info "Deployment Environment: '${DEPLOYMENT_ENVIRONMENT:-unknown}'"
log_info "Requested commit_msg: '$COMMIT_MSG'"
log_info "Requested branch: '$REQUESTED_BRANCH'"

# --- 0a) Basic command checks ---
command -v git >/dev/null || bail_out "Error: 'git' not found."
command -v docker >/dev/null || bail_out "Error: 'docker' not found."
command -v docker-compose >/dev/null || bail_out "Error: 'docker-compose' not found."
command -v python3 >/dev/null || bail_out "Error: 'python3' not found."

# Step 1) Virtual environment
log_info "=== [Step 1] Virtual Environment Setup ==="
if [[ ! -d "$VENV_DIR" ]]; then
  log_info "Creating Python venv in $VENV_DIR..."
  python3 -m venv "$VENV_DIR"
fi
if [[ ! -f "$VENV_DIR/bin/activate" ]]; then
  bail_out "No activation script found in $VENV_DIR/bin/activate. Corrupted venv?"
fi

activate_venv() {
  source "$VENV_DIR/bin/activate"
  if [[ -f "$REQS_FILE" ]]; then
    log_info "Installing dependencies from $REQS_FILE..."
    pip install --upgrade pip
    pip install -r "$REQS_FILE"
  fi
}
deactivate_venv() {
  deactivate > /dev/null 2>&1 || true
}

# Step 2) Trilogy Memory + Diff Range
log_info "=== [Step 2] Trilogy Memory + Diff Range ==="
if [[ -f "$TRILOGY_MEMORY_FILE" ]]; then
  LAST_GOOD_COMMIT=$(cat "$TRILOGY_MEMORY_FILE")
  DIFF_RANGE="${3:-"$LAST_GOOD_COMMIT..HEAD"}"
  log_info "Loaded memory. Using diff range: $DIFF_RANGE"
else
  DIFF_RANGE="${3:-"HEAD~1..HEAD"}"
  log_info "No Trilogy Memory found. Defaulting diff range: $DIFF_RANGE"
fi
export DIFF_RANGE

# Step 3) Git fetch + check if branch exists, else fallback to main
log_info "=== [Step 3] Git fetch + handling branch existence ==="
git fetch origin || log_warn "Git fetch failed or partial."

# Is the requested branch valid on the remote?
if git ls-remote --exit-code --heads origin "$REQUESTED_BRANCH" >/dev/null 2>&1; then
  log_info "Branch '$REQUESTED_BRANCH' exists on remote. Proceeding."
  TARGET_BRANCH="$REQUESTED_BRANCH"
else
  log_warn "Branch '$REQUESTED_BRANCH' does not exist on remote. Falling back to 'main'."
  TARGET_BRANCH="main"
fi

# Attempt checkout
if ! git checkout "$TARGET_BRANCH"; then
  bail_out "Error: Cannot checkout '$TARGET_BRANCH'."
fi

# Attempt rebase (or fallback to merge if rebase fails)
if ! git pull --rebase origin "$TARGET_BRANCH"; then
  log_warn "Git rebase failed. Trying merge instead..."
  if ! git pull origin "$TARGET_BRANCH"; then
    bail_out "Error: Git pull/merge failed. Check your connection/permissions."
  fi
fi

# Step 4) AI refactor
log_info "=== [Step 4] Optional AI refactor ==="
if [[ "${ENABLE_AI_REFACTOR:-}" == "true" && -f scripts/ai_refactor.py ]]; then
  log_info "AI refactor script found. Activating venv and running..."
  activate_venv
  if python scripts/ai_refactor.py; then
    log_info "AI refactor completed."
    if [[ -n "${AI_REFACTOR_FEEDBACK_COMMAND:-}" ]]; then
      log_info "Running AI feedback command: $AI_REFACTOR_FEEDBACK_COMMAND..."
      eval "$AI_REFACTOR_FEEDBACK_COMMAND"
    fi
  else
    log_warn "AI refactor script failed. Continuing."
    ((ERROR_COUNT++))
  fi
  deactivate_venv
else
  log_info "AI refactor disabled or missing 'scripts/ai_refactor.py'."
fi

# Step 5) Identify changed microservices
log_info "=== [Step 5] Identify changed microservices ==="
SERVICES=("c_service" "go_service" "python_agent" "rust_service" "nextjs_dashboard")
declare -A SERVICE_MAP=(
  ["c_service"]="c_service"
  ["go_service"]="go_service"
  ["python_agent"]="python_agent"
  ["rust_service"]="rust_service"
  ["nextjs_dashboard"]="nextjs_dashboard"
)
CHANGED_FILES=$(git diff --name-only "$DIFF_RANGE" || true)
log_info "Changes found in range $DIFF_RANGE:"
echo "$CHANGED_FILES"
BUILD_LIST=()
for srvdir in "${SERVICES[@]}"; do
  if echo "$CHANGED_FILES" | grep -q "^$srvdir/"; then
    BUILD_LIST+=("$srvdir")
  fi
done

# Step 6) Rebuild changed services
log_info "=== [Step 6] Rebuild changed services ==="
if [[ ${#BUILD_LIST[@]} -eq 0 ]]; then
  log_info "No microservice changes. Skipping builds."
else
  ROLLBACK_TAG="preupdate_$(date +%Y%m%d_%H%M%S)"
  log_info "Tagging images for rollback => $ROLLBACK_TAG"

  for dir in "${BUILD_LIST[@]}"; do
    svc="${SERVICE_MAP[$dir]}"
    docker image tag "${svc}:latest" "${svc}:${ROLLBACK_TAG}" || log_warn "Could not tag ${svc}:latest"

    log_info "Building $svc (because $dir changed)..."
    if ! docker compose build --no-cache "$svc"; then
      log_error "Failed to build $svc."
      ((ERROR_COUNT++))
      continue
    fi

    # Start container
    log_info "Starting $svc..."
    if ! docker compose up -d "$svc"; then
      log_error "Failed to start $svc."
      ((ERROR_COUNT++))
      continue
    fi

    # Health check
    if ! bash -c "HEALTH_CHECK_TYPE=\${HEALTH_CHECK_TYPE:-container} $(declare -f perform_health_check); perform_health_check $svc"; then
      log_warn "Health check reported an issue with $svc."
    fi
  done
fi

# Step 7) Optional Solana steps
log_info "=== [Step 7] Solana integration (ENABLE_SOLANA_STUDY) ==="
if [[ "${ENABLE_SOLANA_STUDY:-}" == "true" ]]; then
  if [[ -d solana_program ]]; then
    pushd solana_program >/dev/null
    if [[ -f Anchor.toml ]]; then
      log_info "Anchor project detected. Building..."
      anchor build || log_warn "Anchor build failed."
      anchor test || log_warn "Anchor tests failed."
    else
      log_info "No Anchor.toml. Running cargo build..."
      cargo build --release || log_warn "Solana program build failed."
    fi
    popd >/dev/null

    # Optional Profit Sharing
    if [[ "${PROFIT_SHARING_ENABLED:-}" == "true" ]]; then
      WALLET_KEY="${PROFIT_SHARING_WALLET_PRIVATE_KEY:-}"
      if [[ -n "$WALLET_KEY" ]]; then
        TEMP_KEYFILE=$(mktemp)
        echo "$WALLET_KEY" > "$TEMP_KEYFILE"
        chmod 600 "$TEMP_KEYFILE"
        BAL=$(solana balance --keypair "$TEMP_KEYFILE" 2>/dev/null || true)
        if [[ -n "$BAL" ]]; then
          BAL_SOL=$(echo "$BAL" | awk '{print $1}')
          SHARE_PCT="${PROFIT_SHARING_PERCENTAGE:-0.9}"
          TRANSFER_AMT=$(echo "$BAL_SOL * $SHARE_PCT" | bc)
          log_info "Transferring $TRANSFER_AMT SOL to $PROFIT_SHARING_ADDRESS..."
          solana transfer "$PROFIT_SHARING_ADDRESS" "$TRANSFER_AMT" --keypair "$TEMP_KEYFILE" || log_warn "Profit sharing transfer failed."
        else
          log_warn "Could not read wallet balance. Skipping profit share."
        fi
        rm -f "$TEMP_KEYFILE"
      else
        log_warn "PROFIT_SHARING_WALLET_PRIVATE_KEY not set. Skipping profit share."
      fi
    fi
  else
    log_warn "No solana_program dir found. Skipping Solana steps."
  fi
else
  log_info "Solana integration disabled."
fi

# Step 8) Rollback if errors exceeded
log_info "=== [Step 8] Checking errors for potential rollback ==="
if [[ "$ERROR_COUNT" -gt 0 && "${ROLLBACK_ENABLED:-}" == "true" && -n "${ROLLBACK_TAG:-}" ]]; then
  log_warn "Errors occurred. Potential rollback to tag: $ROLLBACK_TAG"
  # You could prompt or automatically rollback; below is an auto-rollback example:
  for dir in "${BUILD_LIST[@]}"; do
    svc="${SERVICE_MAP[$dir]}"
    docker compose down "$svc"
    docker compose up -d "${svc}:${ROLLBACK_TAG}"
  done
  log_info "Rollback completed (for changed services)."
fi

# Step 9) Git commit & push
log_info "=== [Step 9] Git commit & push if no critical errors ==="
if [[ "$ERROR_COUNT" -ge "$ERROR_THRESHOLD" ]]; then
  log_error "Error threshold ($ERROR_THRESHOLD) reached. Not committing changes. Please investigate."
else
  git add .
  if ! git diff-index --quiet HEAD --; then
    log_info "Committing with message: '$COMMIT_MSG'"
    if git commit -m "$COMMIT_MSG"; then
      log_info "Pushing to branch: $TARGET_BRANCH"
      if git push origin "$TARGET_BRANCH"; then
        # Update memory
        HEAD_COMMIT=$(git rev-parse HEAD)
        echo "$HEAD_COMMIT" > "$TRILOGY_MEMORY_FILE"
        log_info "Trilogy memory updated with $HEAD_COMMIT."
      else
        log_warn "Git push failed. Check your network or perms."
      fi
    else
      log_error "Git commit failed."
    fi
  else
    log_info "No changes to commit. Skipping push."
  fi
fi

# Step 10) Finalize
log_info "=== [Step 10] Done. Deactivating venv and summarizing. ==="
deactivate_venv

DURATION=$(( $(date +%s) - START_TIME ))
log_info "Deployment finished in ${DURATION}s with ERROR_COUNT=$ERROR_COUNT."

cat << 'EOF'

   ____  _  _    ____                        _
  / ___|| || |  / ___| _   _ _ __ __ _  __ _| | ___
  \___ \| || |_ \___ \| | | | '__/ _` |/ _` | |/ _ \
   ___) |__   _| ___) | |_| | | | (_| | (_| | |  __/
  |____/   |_| |____/ \__,_|_|  \__,_|\__, |_|\___|
                                       |___/

Trilogy Enterprise Deployment: mission complete.


EOF

exit 0
