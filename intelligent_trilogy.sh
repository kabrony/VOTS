#!/usr/bin/env bash
###############################################################################
# intelligent_trilogy.sh
#
# A streamlined version of our "Trilogy Enterprise" pipeline:
#   - HPC microservices detection
#   - Next.js + Socket.IO integration
#   - AI refactoring
#   - Maintenance window checks
#   - Documentation analysis (self-improvement)
#   - Docker-based build & health checks
#   - Rollback mechanism
#
###############################################################################

set -Eeuo pipefail

SCRIPT_NAME="intelligent_trilogy.sh"
START_TIME=$(date +%s)
TIMESTAMP=$(date +'%Y-%m-%d %H:%M:%S')
ERROR_COUNT=0
LOG_PREFIX="[${SCRIPT_NAME}]"

# Logging
log_info()   { echo -e "\033[34m${LOG_PREFIX} [INFO]   \033[0m$*"; }
log_warn()   { echo -e "\033[33m${LOG_PREFIX} [WARN]   \033[0m$*" >&2; }
log_error()  { echo -e "\033[31m${LOG_PREFIX} [ERROR]  \033[0m$*" >&2; }
bail_out()   { log_error "$*"; exit 1; }

# CLI / Env
COMMIT_MSG="${1:-"auto: system update ${TIMESTAMP}"}"
BRANCH="${2:-"main"}"
TRILOGY_MEMORY_FILE="${TRILOGY_MEMORY_FILE:-"./.trilogy_memory"}"
VIRTUAL_ENV_DIR="${VIRTUAL_ENV_DIR:-"./venv"}"
REQUIREMENTS_FILE="${REQUIREMENTS_FILE:-"requirements.txt"}"
MAINTENANCE_WINDOW_START="${MAINTENANCE_WINDOW_START:-"02:00"}"
MAINTENANCE_WINDOW_END="${MAINTENANCE_WINDOW_END:-"04:00"}"
HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-3}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-10}"
ERROR_THRESHOLD="${ERROR_THRESHOLD:-5}"

NEXTJS_SERVICE_NAME="${NEXTJS_SERVICE_NAME:-"nextjs_dashboard"}"
SOCKET_IO_BACKEND_SERVICE="${SOCKET_IO_BACKEND_SERVICE:-"socket_io_backend"}"

ENABLE_AI_REFACTOR="${ENABLE_AI_REFACTOR:-false}"
ENABLE_MAINTENANCE_WINDOW_CHECK="${ENABLE_MAINTENANCE_WINDOW_CHECK:-false}"
ROLLBACK_ENABLED="${ROLLBACK_ENABLED:-false}"
ENABLE_DOC_ANALYSIS="${ENABLE_DOC_ANALYSIS:-false}"
DOC_ANALYSIS_SCRIPT="${DOC_ANALYSIS_SCRIPT:-"scripts/analyze_documentation.py"}"
DOCUMENTATION_SOURCES="${DOCUMENTATION_SOURCES:-""}"
ENABLE_SOLANA_STUDY="${ENABLE_SOLANA_STUDY:-false}"
PROFIT_SHARING_ENABLED="${PROFIT_SHARING_ENABLED:-false}"
PROFIT_SHARING_PERCENTAGE="${PROFIT_SHARING_PERCENTAGE:-0.90}"

# AI keys
OPENAI_API_KEY="${OPENAI_API_KEY:-""}"
GEMINI_API_KEY="${GEMINI_API_KEY:-""}"

# Step 0: Basic checks
log_info "=== [Step 0] Initializing: ${SCRIPT_NAME} ==="
log_info "Deployment Environment: '${DEPLOYMENT_ENVIRONMENT:-"unknown"}'"
log_info "CLI => commit_msg: '${COMMIT_MSG}', branch: '${BRANCH}'"

command -v git  >/dev/null || bail_out "git not installed!"
command -v docker  >/dev/null || bail_out "docker not installed!"
command -v docker-compose >/dev/null || bail_out "docker-compose not installed!"
command -v python3 >/dev/null || bail_out "python3 not installed!"

if [[ "${HEALTH_CHECK_TYPE:-}" == "endpoint" ]]; then
  command -v curl >/dev/null || log_warn "curl not installed => endpoint checks may fail!"
fi

###############################################################################
# Maintenance Window
###############################################################################
check_maintenance_window() {
  if [[ "${ENABLE_MAINTENANCE_WINDOW_CHECK}" == "true" ]]; then
    local current_time=$(date +%H:%M)
    if [[ "$current_time" < "$MAINTENANCE_WINDOW_START" || "$current_time" > "$MAINTENANCE_WINDOW_END" ]]; then
      log_warn "Current time ($current_time) outside $MAINTENANCE_WINDOW_START-$MAINTENANCE_WINDOW_END."
      # bail_out "Outside maintenance window => aborting." # or just warn
    else
      log_info "Inside maintenance window => proceeding."
    fi
  fi
}
check_maintenance_window

###############################################################################
# Virtual Env
###############################################################################
log_info "=== [Step 1] Virtual Environment Setup ==="
ensure_virtual_env() {
  if [[ ! -d "$VIRTUAL_ENV_DIR" ]]; then
    log_info "Creating venv => $VIRTUAL_ENV_DIR..."
    python3 -m venv "$VIRTUAL_ENV_DIR"
  elif [[ ! -f "$VIRTUAL_ENV_DIR/bin/activate" ]]; then
    bail_out "Venv dir found but no activation script => $VIRTUAL_ENV_DIR"
  else
    log_info "Venv found => $VIRTUAL_ENV_DIR"
  fi
}

activate_venv() {
  if [[ -f "$VIRTUAL_ENV_DIR/bin/activate" ]]; then
    source "$VIRTUAL_ENV_DIR/bin/activate"
    if [[ -f "$REQUIREMENTS_FILE" ]]; then
      log_info "Installing requirements from $REQUIREMENTS_FILE..."
      pip install --upgrade pip
      pip install -r "$REQUIREMENTS_FILE"
    fi
  else
    bail_out "Cannot activate => missing $VIRTUAL_ENV_DIR/bin/activate"
  fi
}

deactivate_venv() { deactivate >/dev/null 2>&1 || true; }

ensure_virtual_env

###############################################################################
# Step 2: Trilogy Memory + Diff Range
###############################################################################
log_info "=== [Step 2] Trilogy Memory + Diff Range ==="
if [[ -f "$TRILOGY_MEMORY_FILE" ]]; then
  LAST_SUCCESSFUL_COMMIT=$(cat "$TRILOGY_MEMORY_FILE")
  DIFF_RANGE="${3:-"$LAST_SUCCESSFUL_COMMIT..HEAD"}"
  log_info "Trilogy memory => diff range: $DIFF_RANGE"
else
  DIFF_RANGE="${3:-"HEAD~1..HEAD"}"
  log_info "No trilogy memory => using diff range $DIFF_RANGE"
fi
export DIFF_RANGE

###############################################################################
# Step 3: Git Ops => fetch, checkout, rebase
###############################################################################
log_info "=== [Step 3] Git Ops ==="
perform_git_ops() {
  if ! git diff --quiet || ! git diff --cached --quiet; then
    log_warn "Local uncommitted changes found => proceed with caution."
  fi

  if ! git fetch origin; then
    log_warn "git fetch => fail or no 'origin' remote."
  fi
  if ! git checkout "$BRANCH"; then
    bail_out "Cannot checkout branch => '$BRANCH'"
  fi
  if ! git pull --rebase origin "$BRANCH"; then
    log_warn "Rebase failed => trying merge"
    if ! git pull origin "$BRANCH"; then
      log_warn "Merge also failed => check your remote perms"
    fi
  fi
}
perform_git_ops

###############################################################################
# Step 4: AI Refactor (optional)
###############################################################################
log_info "=== [Step 4] AI Refactor ==="
ai_refactor() {
  if [[ "${ENABLE_AI_REFACTOR}" == "true" ]]; then
    local ai_script="scripts/ai_refactor.py"
    if [[ -f "$ai_script" ]]; then
      activate_venv
      log_info "Running $ai_script..."
      if python "$ai_script"; then
        log_info "AI refactor => success"
      else
        log_warn "AI refactor => fail"
        ((ERROR_COUNT++))
      fi
      deactivate_venv
    else
      log_warn "No $ai_script => skipping"
    fi
  else
    log_info "AI refactor => disabled"
  fi
}
ai_refactor

###############################################################################
# Step 5: Identify Changed Services
###############################################################################
SERVICES=(
  "c_service"
  "go_service"
  "rust_service"
  "python_agent"
  "nextjs_dashboard"
  "${SOCKET_IO_BACKEND_SERVICE}"
)

declare -A SERVICE_MAP=(
  ["c_service"]="c_service"
  ["go_service"]="go_service"
  ["rust_service"]="rust_service"
  ["python_agent"]="python_agent"
  ["nextjs_dashboard"]="${NEXTJS_SERVICE_NAME}"
  ["${SOCKET_IO_BACKEND_SERVICE}"]="${SOCKET_IO_BACKEND_SERVICE}"
)

log_info "Collecting changed files from range: $DIFF_RANGE"
CHANGED_FILES=$(git diff --name-only "$DIFF_RANGE" || true)

build_list=()
for dir in "${SERVICES[@]}"; do
  if echo "$CHANGED_FILES" | grep -q "^$dir/"; then
    build_list+=("$dir")
  fi
done

###############################################################################
# Health Check
###############################################################################
health_check() {
  local svc="$1"
  local check_type="${HEALTH_CHECK_TYPE:-"container"}"
  local retries="$HEALTH_CHECK_RETRIES"
  local timeout="$HEALTH_CHECK_TIMEOUT"

  for i in $(seq 1 "$retries"); do
    case "$check_type" in
      "container")
        log_info "Container check => $svc (Attempt $i/$retries)"
        if docker compose ps --services --filter "status=running" | grep -q "^$svc\$"; then
          log_info "$svc => running"
          return 0
        fi
        ;;
      "endpoint")
        if [[ -n "${ENDPOINT_HEALTH_CHECK_URL:-}" ]]; then
          log_info "Endpoint check => Attempt $i/$retries => ${ENDPOINT_HEALTH_CHECK_URL}"
          if curl -fsS "${ENDPOINT_HEALTH_CHECK_URL}" >/dev/null; then
            log_info "Endpoint => healthy"
            return 0
          else
            log_warn "Endpoint => fail"
          fi
        else
          log_warn "No ENDPOINT_HEALTH_CHECK_URL => skip"
          return 0
        fi
        ;;
      *)
        log_warn "Unknown check type => container by default"
        if docker compose ps --services --filter "status=running" | grep -q "^$svc\$"; then
          log_info "$svc => running"
          return 0
        fi
        ;;
    esac
    sleep "$timeout"
  done
  log_error "Health checks => $svc failed after $retries tries!"
  ((ERROR_COUNT++))
  return 1
}

###############################################################################
# Rebuild & Restart
###############################################################################
rebuild_services() {
  if [[ ${#build_list[@]} -eq 0 ]]; then
    log_info "No service changes => skipping build"
    return
  fi

  local OLD_TAG="preupdate_$(date +%Y%m%d_%H%M%S)"
  log_info "Tagging existing images => $OLD_TAG"

  for dir in "${build_list[@]}"; do
    local svc="${SERVICE_MAP[$dir]}"
    docker image tag "${svc}:latest" "${svc}:${OLD_TAG}" || log_warn "Tag fail => $svc"

    log_info "Building $svc => changes in $dir/"
    if ! docker compose build --no-cache "$svc"; then
      log_error "Build fail => $svc"
      ((ERROR_COUNT++))
      continue
    fi
    log_info "Starting (up -d) => $svc"
    if ! docker compose up -d "$svc"; then
      log_error "docker compose up => fail for $svc"
      ((ERROR_COUNT++))
      continue
    fi
    health_check "$svc"
  done
}

###############################################################################
# Step 6: Documentation Analysis
###############################################################################
perform_doc_analysis() {
  if [[ "${ENABLE_DOC_ANALYSIS}" == "true" ]]; then
    if [[ -f "$DOC_ANALYSIS_SCRIPT" ]]; then
      activate_venv
      log_info "Doc analysis => $DOC_ANALYSIS_SCRIPT"
      export DOCUMENTATION_SOURCES
      if python "$DOC_ANALYSIS_SCRIPT"; then
        log_info "Doc analysis => success"
      else
        log_warn "Doc analysis => error"
        ((ERROR_COUNT++))
      fi
      deactivate_venv
    else
      log_warn "No $DOC_ANALYSIS_SCRIPT => skipping"
    fi
  else
    log_info "Doc analysis => disabled"
  fi
}

###############################################################################
# Step 7: Solana Integration
###############################################################################
perform_solana_ops() {
  if [[ "${ENABLE_SOLANA_STUDY}" == "true" ]]; then
    if [[ -d "solana_program" ]]; then
      pushd solana_program >/dev/null
      if [[ -f "Anchor.toml" ]]; then
        log_info "Anchor => build/test"
        anchor build && log_info "Anchor build => ok" || log_warn "build => fail"
        anchor test  && log_info "Anchor test => ok"  || log_warn "test => fail"
      else
        log_info "No Anchor => cargo build"
        cargo build --release && log_info "Solana => build ok" || log_warn "build => fail"
      fi
      popd >/dev/null

      if [[ "${PROFIT_SHARING_ENABLED}" == "true" ]]; then
        log_info "Profit sharing => WIP"
        # same logic from previous versions if you want
      fi
    else
      log_warn "No solana_program => skipping"
    fi
  else
    log_info "Solana => disabled"
  fi
}

###############################################################################
# Step 8: Rollback Mechanism
###############################################################################
perform_rollback() {
  if [[ "${ROLLBACK_ENABLED}" == "true" && -n "${OLD_TAG:-}" ]]; then
    log_warn "Rollback => $OLD_TAG"
    for dir in "${build_list[@]}"; do
      local svc="${SERVICE_MAP[$dir]}"
      docker compose down "$svc"
      docker compose up -d "${svc}:${OLD_TAG}"
    done
    log_info "Rollback => complete"
  else
    log_info "Rollback => disabled or no OLD_TAG"
  fi
}

###############################################################################
# Step 9: Git Commit + Push
###############################################################################
git_commit_push() {
  log_info "Checking for new changes => commit/push"
  git add .
  if ! git diff-index --quiet HEAD --; then
    if ! git commit -m "$COMMIT_MSG"; then
      log_error "git commit => fail"
      return 1
    fi
    log_info "Pushing => origin/$BRANCH"
    if ! git push origin "$BRANCH"; then
      log_warn "git push => fail"
      return 1
    fi
    echo "$(git rev-parse HEAD)" > "$TRILOGY_MEMORY_FILE"
    log_info "Trilogy memory => updated"
  else
    log_info "No changes => skipping push"
  fi
  return 0
}

###############################################################################
# Step 10: Final Summation
###############################################################################
final_summation() {
  local duration=$(( $(date +%s) - START_TIME ))

  if [[ "$ERROR_COUNT" -gt 0 && "${ROLLBACK_ENABLED}" == "true" ]]; then
    perform_rollback
  fi

  if [[ "$ERROR_COUNT" -eq 0 ]]; then
    git_commit_push || ((ERROR_COUNT++))
  else
    log_warn "Error count => $ERROR_COUNT => skipping final git push"
  fi

  deactivate_venv
  log_info "Deployment finished in ${duration}s with ERROR_COUNT=${ERROR_COUNT}."

  cat << 'EOBANNER'

  ____  _  _    ____                        _
 / ___|| || |  / ___| _   _ _ __ __ _  __ _| | ___
 \___ \| || |_ \___ \| | | | '__/ _` |/ _` | |/ _ \
  ___) |__   _| ___) | |_| | | | (_| | (_| | |  __/
 |____/   |_| |____/ \__,_|_|  \__,_|\__, |_|\___|
                                      |___/

Trilogy Enterprise "Intelligent" Deployment => mission complete!

EOBANNER
  exit 0
}

###############################################################################
# Main
###############################################################################
activate_venv
rebuild_services
perform_doc_analysis
perform_solana_ops
final_summation

