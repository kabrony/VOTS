#!/usr/bin/env bash
###############################################################################
# v01.11_trilogy_enterprise.sh
#
# Purpose:
#   A refined, autonomous deployment script for:
#     1) HPC microservices (C, Go, Python, Rust).
#     2) Next.js dashboard with Socket.IO real-time data.
#     3) Optional ML-based performance checks (e.g. Lighthouse, load predictions).
#     4) Rollback / memory-based logic ("Trilogy Memory").
#
# Environment Variables (key ones):
#   ENABLE_AI_REFACTOR=true|false
#   ENABLE_SOLANA_STUDY=true|false
#   ROLLBACK_ENABLED=true|false
#   HEALTH_CHECK_TYPE="container"|"endpoint"
#   ENDPOINT_HEALTH_CHECK_URL="http://localhost:3001"
#   HEALTH_CHECK_RETRIES=3
#   HEALTH_CHECK_TIMEOUT=10
#   PROFIT_SHARING_ENABLED=true|false
#   PROFIT_SHARING_WALLET_PRIVATE_KEY=...
#   TRILOGY_MEMORY_FILE="./.trilogy_memory"
#   VIRTUAL_ENV_DIR="./venv"
#   REQUIREMENTS_FILE="requirements.txt"
#   AI_REFACTOR_FEEDBACK_COMMAND="python scripts/run_linters_tests.sh"
#   DEPLOYMENT_ENVIRONMENT="production"|"staging"|"development"
#   ERROR_THRESHOLD=5
#
# Next.js + Socket.IO specifics:
#   NEXTJS_APP_DIR="nextjs_dashboard"
#   DOCKER_SERVICE_NAME="nextjs_dashboard"
#   SOCKET_IO_HEALTH_CHECK_URL="http://localhost:3001"
#   LIGHTHOUSE_SCRIPT="scripts/run_lighthouse.js"
#   PREDICT_LOAD_SCRIPT="scripts/predict_load.py"
#
# Usage:
#   chmod +x v01.11_trilogy_enterprise.sh
#   ./v01.11_trilogy_enterprise.sh [commit_msg] [branch] [diff_range]
#
# Notes:
#   - Integrates a small ML pipeline for performance checks if scripts are found.
#   - Socket.IO check ensures the real-time backend is reachable before final deploy.
###############################################################################

set -Eeuo pipefail

SCRIPT_VERSION="v01.11_trilogy_enterprise.sh"
START_TIME=$(date +%s)
TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
LOG_PREFIX="[$(date +'%Y-%m-%d %H:%M:%S')] [${SCRIPT_VERSION}]"
ERROR_COUNT=0

# --- Helper Functions ---
log_info()  { echo -e "\033[34m${LOG_PREFIX} [INFO] $*\033[0m"; }
log_warn()  { echo -e "\033[33m${LOG_PREFIX} [WARN] $*\033[0m" >&2; }
log_error() { echo -e "\033[31m${LOG_PREFIX} [ERROR] $*\033[0m" >&2; }
bail_out()  { log_error "$*"; exit 1; }

# --- Configuration from CLI ---
COMMIT_MSG="${1:-"auto: system update ${TIMESTAMP}"}"
BRANCH="${2:-"main"}"
TRILOGY_MEMORY_FILE="${TRILOGY_MEMORY_FILE:-"./.trilogy_memory"}"
DIFF_RANGE="${3:-}"

# --- Additional Config (with defaults) ---
VIRTUAL_ENV_DIR="${VIRTUAL_ENV_DIR:-"./venv"}"
REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-"requirements.txt"}"
HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-3}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"
ERROR_THRESHOLD="${ERROR_THRESHOLD:-5}"
NEXTJS_APP_DIR="${NEXTJS_APP_DIR:-"nextjs_dashboard"}"
DOCKER_SERVICE_NAME="${DOCKER_SERVICE_NAME:-"nextjs_dashboard"}"
LIGHTHOUSE_SCRIPT="${LIGHTHOUSE_SCRIPT:-"scripts/run_lighthouse.js"}"
PREDICT_LOAD_SCRIPT="${PREDICT_LOAD_SCRIPT:-"scripts/predict_load.py"}"
SOCKET_IO_HEALTH_CHECK_URL="${SOCKET_IO_HEALTH_CHECK_URL:-""}"  # optional

# --- Step 0: Initialize & Check Basic Tools ---
log_info "=== [Step 0] Initializing: $SCRIPT_VERSION ==="
log_info "Deployment Environment: ${DEPLOYMENT_ENVIRONMENT:-'unknown'}"

command -v git    >/dev/null || bail_out "git is required but not installed."
command -v docker >/dev/null || bail_out "docker is required but not installed."
command -v docker-compose >/dev/null || bail_out "docker-compose is required but not installed."
command -v python3 >/dev/null || bail_out "python3 is required but not installed."

log_info "CLI args => commit_msg: '$COMMIT_MSG', branch: '$BRANCH', diff_range: '${DIFF_RANGE:-"(not specified)"}'"

# --- Step 1: Virtual Environment Setup ---
log_info "=== [Step 1] Virtual Environment Setup ==="
ensure_virtual_environment() {
    if [[ ! -d "$VIRTUAL_ENV_DIR" ]]; then
        log_info "Creating Python venv in $VIRTUAL_ENV_DIR..."
        python3 -m venv "$VIRTUAL_ENV_DIR"
    elif [[ ! -f "$VIRTUAL_ENV_DIR/bin/activate" ]]; then
        bail_out "Virtual environment directory exists but is corrupted."
    else
        log_info "Virtual environment found at $VIRTUAL_ENV_DIR."
    fi
}

activate_venv() {
    if [[ -f "$VIRTUAL_ENV_DIR/bin/activate" ]]; then
        source "$VIRTUAL_ENV_DIR/bin/activate"
        if [[ -f "$REQUIREMENTS_FILE" ]]; then
            log_info "Installing Python deps from $REQUIREMENTS_FILE..."
            pip install --upgrade pip
            pip install -r "$REQUIREMENTS_FILE"
        fi
    else
        bail_out "Cannot activate virtual environment; missing $VIRTUAL_ENV_DIR/bin/activate"
    fi
}

deactivate_venv() {
    deactivate >/dev/null 2>&1 || true
}

ensure_virtual_environment

# --- Step 2: Trilogy Memory & Diff Range ---
log_info "=== [Step 2] Trilogy Memory + Diff Range ==="
if [[ -f "$TRILOGY_MEMORY_FILE" ]]; then
    LAST_SUCCESS_COMMIT=$(cat "$TRILOGY_MEMORY_FILE")
    if [[ -z "$DIFF_RANGE" ]]; then
        DIFF_RANGE="${LAST_SUCCESS_COMMIT}..HEAD"
        log_info "Found Trilogy memory. Using diff range: $DIFF_RANGE"
    else
        log_info "Using user-specified diff range: $DIFF_RANGE"
    fi
else
    if [[ -z "$DIFF_RANGE" ]]; then
        DIFF_RANGE="HEAD~1..HEAD"
        log_info "No trilogy memory found; defaulting diff range: $DIFF_RANGE"
    else
        log_info "Using user-specified diff range: $DIFF_RANGE"
    fi
fi
export DIFF_RANGE

# --- Step 3: Git Ops (pull, checkout, rebase) ---
log_info "=== [Step 3] Git Fetch, Checkout, Rebase ==="
git fetch origin || log_warn "git fetch failed or no network."
if ! git checkout "$BRANCH"; then
    bail_out "Error: cannot checkout branch '$BRANCH'."
fi
if ! git pull --rebase origin "$BRANCH"; then
    log_warn "Rebase failed; attempting merge."
    git pull origin "$BRANCH"
fi

# --- Step 4: (Optional) AI Refactor Step ---
log_info "=== [Step 4] Optional AI Refactor ==="
perform_ai_refactor() {
    if [[ "${ENABLE_AI_REFACTOR:-}" == "true" && -f scripts/ai_refactor.py ]]; then
        activate_venv
        log_info "Running AI refactor script..."
        if python scripts/ai_refactor.py; then
            log_info "AI refactor completed successfully."
            if [[ -n "${AI_REFACTOR_FEEDBACK_COMMAND:-}" ]]; then
                log_info "Providing feedback to AI refactor..."
                eval "$AI_REFACTOR_FEEDBACK_COMMAND" || log_warn "AI feedback command encountered issues."
            fi
        else
            log_warn "AI refactor script failed. Proceeding but watch for potential breakage."
            ((ERROR_COUNT++))
        fi
        deactivate_venv
    else
        log_info "AI refactor disabled or script not found."
    fi
}
perform_ai_refactor

# --- Step 5: Identify Changed Files & Build HPC Microservices (As needed) ---
log_info "=== [Step 5] HPC / Microservices Build Steps (Selective) ==="
SERVICES=("c_service" "go_service" "python_agent" "rust_service" "nextjs_dashboard")
declare -A SERVICE_MAP=(
  ["c_service"]="c_service"
  ["go_service"]="go_service"
  ["python_agent"]="python_agent"
  ["rust_service"]="rust_service"
  ["nextjs_dashboard"]="nextjs_dashboard"
)

CHANGED_FILES=$(git diff --name-only "$DIFF_RANGE" || true)
log_info "Changed files (in $DIFF_RANGE):"
echo "$CHANGED_FILES" | sed 's/^/  - /'

build_list=()
for dir in "${SERVICES[@]}"; do
  if echo "$CHANGED_FILES" | grep -q "^$dir/"; then
    build_list+=("$dir")
  fi
done

rebuild_and_restart() {
    local svc="$1"
    local old_tag="$2"

    docker image tag "${svc}:latest" "${svc}:${old_tag}" || log_warn "Failed to tag ${svc}:latest -> ${svc}:${old_tag}"
    log_info "Building service: $svc..."
    if ! docker compose build --no-cache "$svc"; then
        log_error "Failed to build $svc."
        ((ERROR_COUNT++))
        return
    fi
    log_info "Restarting service: $svc..."
    if ! docker compose up -d "$svc"; then
        log_error "Failed to start $svc."
        ((ERROR_COUNT++))
        return
    fi
}

if [[ ${#build_list[@]} -eq 0 ]]; then
    log_info "No HPC or nextjs_dashboard changes detected; skipping microservice builds."
else
    OLD_TAG="preupdate_$(date +%Y%m%d_%H%M%S)"
    log_info "Tagging old images with $OLD_TAG for rollback."

    for dir in "${build_list[@]}"; do
        local_svc="${SERVICE_MAP[$dir]}"
        rebuild_and_restart "$local_svc" "$OLD_TAG"

        # (Optional) Perform container-level health check
        # ...
    done
fi

# --- Step 6: Next.js Deploy + ML Performance + Socket.IO Check ---
log_info "=== [Step 6] Next.js Deploy & ML Performance Steps ==="

deploy_nextjs_ml() {
    # 1) Build Next.js if changed
    if [[ "${build_list[*]}" =~ "nextjs_dashboard" ]]; then
        # 2) (Optional) ML Perf (Lighthouse)
        log_info "Running Lighthouse analysis if $LIGHTHOUSE_SCRIPT exists..."
        if [[ -f "$LIGHTHOUSE_SCRIPT" ]]; then
            node "$LIGHTHOUSE_SCRIPT" || {
                log_error "Lighthouse script failed. Aborting nextjs deploy."
                ((ERROR_COUNT++))
                return 1
            }
        else
            log_info "No Lighthouse script found at $LIGHTHOUSE_SCRIPT. Skipping."
        fi

        # 3) (Optional) ML Load Prediction
        log_info "Running ML load prediction if $PREDICT_LOAD_SCRIPT exists..."
        if [[ -f "$PREDICT_LOAD_SCRIPT" ]]; then
            python "$PREDICT_LOAD_SCRIPT" || {
                log_error "ML load prediction failed. Aborting nextjs deploy."
                ((ERROR_COUNT++))
                return 1
            }
        else
            log_info "No load prediction script found at $PREDICT_LOAD_SCRIPT. Skipping."
        fi

        # 4) Check Socket.IO server if env var is set
        if [[ -n "$SOCKET_IO_HEALTH_CHECK_URL" ]]; then
            log_info "Verifying Socket.IO server at: $SOCKET_IO_HEALTH_CHECK_URL"
            if curl -sSf "$SOCKET_IO_HEALTH_CHECK_URL/socket.io/" >/dev/null; then
                log_info "Socket.IO server is reachable."
            else
                log_error "Socket.IO server not reachable at $SOCKET_IO_HEALTH_CHECK_URL/socket.io/"
                ((ERROR_COUNT++))
                return 1
            fi
        else
            log_warn "No SOCKET_IO_HEALTH_CHECK_URL set. Skipping Socket.IO check."
        fi
    else
        log_info "No changes in Next.js directory. Skipping Next.js ML steps."
    fi
}

deploy_nextjs_ml
NEXTJS_STATUS="$?"
if [[ "$NEXTJS_STATUS" -ne 0 ]]; then
    log_error "Next.js ML steps encountered errors. Potential rollback recommended."
fi

# --- Step 7: (Optional) Solana Study Steps ---
log_info "=== [Step 7] (Optional) Solana Steps ==="
perform_solana_ops() {
    if [[ "${ENABLE_SOLANA_STUDY:-}" == "true" && -d "solana_program" ]]; then
        pushd solana_program >/dev/null
        if [[ -f "Anchor.toml" ]]; then
            log_info "Anchor build/test..."
            anchor build  || log_warn "Anchor build failed"
            anchor test   || log_warn "Anchor tests failed"
        else
            log_info "Basic cargo build for Solana program..."
            cargo build --release || log_warn "Basic solana cargo build failed"
        fi
        popd >/dev/null
        # Optional: profit sharing & wallet steps
    else
        log_info "Solana study disabled or solana_program not found."
    fi
}
perform_solana_ops

# --- Step 8: Rollback Mechanism (If Errors) ---
log_info "=== [Step 8] Rollback Logic ==="
rollback_if_needed() {
    if [[ "${ROLLBACK_ENABLED:-}" == "true" && -n "${OLD_TAG:-}" ]]; then
        if [[ "$ERROR_COUNT" -gt 0 ]]; then
            log_warn "Errors encountered; rolling back to $OLD_TAG..."
            for dir in "${build_list[@]}"; do
                local_svc="${SERVICE_MAP[$dir]}"
                docker compose down "$local_svc"
                docker compose up -d "${local_svc}:${OLD_TAG}"
            done
            log_info "Rollback complete."
        fi
    else
        log_info "Rollback is disabled or no old tag available."
    fi
}
rollback_if_needed

# --- Step 9: Git Commit & Push (If no errors) ---
log_info "=== [Step 9] Git commit & push (Trilogy Memory) ==="
commit_and_push_changes() {
    if [[ "$ERROR_COUNT" -eq 0 ]]; then
        git add .
        if ! git diff-index --quiet HEAD --; then
            log_info "Committing changes with message: $COMMIT_MSG"
            if ! git commit -m "$COMMIT_MSG"; then
                log_warn "Commit failed. Might need manual fix."
            else
                log_info "Pushing to branch: $BRANCH"
                if ! git push origin "$BRANCH"; then
                    log_warn "Git push failed. Check perms or network."
                else
                    # Update Trilogy memory
                    NEW_HEAD=$(git rev-parse HEAD)
                    echo "$NEW_HEAD" > "$TRILOGY_MEMORY_FILE"
                    log_info "Trilogy Memory updated with $NEW_HEAD"
                fi
            fi
        else
            log_info "No new changes to commit. Skipping push."
        fi
    else
        log_warn "Not committing/pushing due to errors encountered ($ERROR_COUNT)."
    fi
}

commit_and_push_changes

# --- Step 10: Final Summary ---
log_info "=== [Step 10] Final Summary & Exit ==="
duration=$(( $(date +%s) - START_TIME ))
log_info "Deployment finished in $duration seconds with ERROR_COUNT=$ERROR_COUNT."

if [[ "$ERROR_COUNT" -gt "$ERROR_THRESHOLD" ]]; then
    log_error "Error threshold exceeded ($ERROR_THRESHOLD). Investigate immediately."
    exit 1
fi

cat << "EOF"

   ____  _  _    ____                        _
  / ___|| || |  / ___| _   _ _ __ __ _  __ _| | ___
  \___ \| || |_ \___ \| | | | '__/ _` |/ _` | |/ _ \
   ___) |__   _| ___) | |_| | | | (_| | (_| | |  __/
  |____/   |_| |____/ \__,_|_|  \__,_|\__, |_|\___|
                                       |___/

     v01.11_trilogy_enterprise.sh => HPC + AI + Next.js + Socket.IO synergy
EOF

exit 0
