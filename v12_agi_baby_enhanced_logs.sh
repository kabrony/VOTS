#!/usr/bin/env bash
###############################################################################
# v12_agi_baby_enhanced_logs.sh
#
# Purpose:
#   1) If DO_FULL_AGI_PIPE=true => run the entire HPC + Next.js + optional
#      Socket.IO, AI refactor, doc analysis, Solana steps, with Docker logs check.
#   2) Otherwise => partial pipeline (HPC & Next.js only), skipping advanced AI,
#      but still logs after each container start to see if there's an error.
#
# Enhanced Features:
#   - Binary approach: FULL vs PARTIAL pipeline
#   - HPC concurrency example
#   - Next.js rebuild with Docker
#   - Optional Socket.IO backend
#   - Optional AI refactor & doc analysis
#   - Optional Solana steps
#   - Maintenance window check
#   - Basic secrets placeholder
#   - Docker logs retrieval after each service start
#   - Minimal log-based error scanning (example suggestion)
#   - Clean final summary (no truncated lines, no partial exit statements)
#
# Usage:
#   chmod +x v12_agi_baby_enhanced_logs.sh
#   DO_FULL_AGI_PIPE=true ./v12_agi_baby_enhanced_logs.sh [commit_msg] [branch]
#
# Environment Variables (examples):
#   DO_FULL_AGI_PIPE=true|false
#   ENABLE_MAINTENANCE_WINDOW_CHECK=true|false
#   MAINTENANCE_WINDOW_START="02:00"
#   MAINTENANCE_WINDOW_END="04:00"
#   VIRTUAL_ENV_DIR="./venv"
#   HPC_SERVICES="c_service go_service python_agent rust_service"
#   NEXTJS_SERVICE="nextjs_dashboard"
#   SOCKETIO_SERVICE="socket_io_backend"
#   ENABLE_SOCKET_IO_BACKEND=true|false
#   ENABLE_AI_REFACTOR=true|false
#   AI_REFACTOR_SCRIPT="scripts/ai_refactor.py"
#   ENABLE_DOC_ANALYSIS=true|false
#   DOC_ANALYSIS_SCRIPT="scripts/doc_analysis.py"
#   ENABLE_SOLANA_STUDY=true|false
#   ENCRYPTED_SECRETS_FILE="./secrets.enc"
#   DECRYPT_CMD="gpg -d secrets.enc"
#   LOG_TAIL_LINES=30      # how many lines to tail for logs
#   LOG_ERROR_PATTERN="(ERROR|FATAL|panic)"  # pattern to match in logs
#
# Disclaimer:
#   - Real "AGI" or "ASI" logic requires extensive AI code far beyond this script.
#   - The secrets management approach here is simplistic and for demonstration only.
###############################################################################

set -Eeuo pipefail

###############################################################################
# GLOBAL CONFIG & LOGGING
###############################################################################
SCRIPT_NAME="$(basename -- "$0")"
START_TIME="$(date +%s)"
TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S')"
ERROR_COUNT=0

log_info()  { echo -e "\033[34m[INFO]\033[0m  $SCRIPT_NAME => $*"; }
log_warn()  { echo -e "\033[33m[WARN]\033[0m  $SCRIPT_NAME => $*" >&2; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $SCRIPT_NAME => $*" >&2; }
bail_out()  { log_error "$*"; exit 1; }

###############################################################################
# CLI ARGS => COMMIT_MSG & BRANCH
###############################################################################
COMMIT_MSG="${1:-"auto: system update $TIMESTAMP"}"
BRANCH="${2:-"main"}"

###############################################################################
# DETERMINE FULL OR PARTIAL PIPELINE
###############################################################################
if [[ "${DO_FULL_AGI_PIPE:-false}" == "true" ]]; then
  log_info "DO_FULL_AGI_PIPE=true => FULL pipeline (AGI baby) mode."
  FULL_AGI_MODE=true
else
  log_warn "DO_FULL_AGI_PIPE != 'true' => PARTIAL pipeline => skipping advanced AI steps."
  FULL_AGI_MODE=false
fi

###############################################################################
# OPTIONAL => MAINTENANCE WINDOW CHECK
###############################################################################
if [[ "${ENABLE_MAINTENANCE_WINDOW_CHECK:-false}" == "true" ]]; then
  current_time="$(date +%H:%M)"
  mw_start="${MAINTENANCE_WINDOW_START:-"02:00"}"
  mw_end="${MAINTENANCE_WINDOW_END:-"04:00"}"
  if [[ "$current_time" < "$mw_start" || "$current_time" > "$mw_end" ]]; then
    log_warn "Currently $current_time => outside maintenance window ($mw_start-$mw_end)."
    # Optionally bail_out or just continue
    # bail_out "Deployment aborted => not in window."
  else
    log_info "Within maintenance window ($mw_start-$mw_end). Proceeding."
  fi
fi

###############################################################################
# DECRYPT SECRETS (PLACEHOLDER)
###############################################################################
ENCRYPTED_SECRETS_FILE="${ENCRYPTED_SECRETS_FILE:-"./secrets.enc"}"
DECRYPT_CMD="${DECRYPT_CMD:-"cat $ENCRYPTED_SECRETS_FILE"}"
if [[ -f "$ENCRYPTED_SECRETS_FILE" ]]; then
  log_info "Decrypting secrets => $ENCRYPTED_SECRETS_FILE (placeholder)."
  # Real usage example:
  # $DECRYPT_CMD || bail_out "Secrets decryption => fail!"
  # export MY_API_KEY="$(...)"
else
  log_warn "No secrets file => skipping secrets logic."
fi

###############################################################################
# PYTHON VENV MANAGEMENT
###############################################################################
VIRTUAL_ENV_DIR="${VIRTUAL_ENV_DIR:-"./venv"}"

ensure_venv() {
  if [[ ! -d "$VIRTUAL_ENV_DIR" ]]; then
    log_info "Creating Python venv => $VIRTUAL_ENV_DIR"
    python3 -m venv "$VIRTUAL_ENV_DIR" || bail_out "venv creation => failed!"
  else
    log_info "Python venv found => $VIRTUAL_ENV_DIR"
  fi
}

activate_venv() {
  if [[ -f "$VIRTUAL_ENV_DIR/bin/activate" ]]; then
    source "$VIRTUAL_ENV_DIR/bin/activate"
  else
    bail_out "venv activate not found => $VIRTUAL_ENV_DIR/bin/activate"
  fi
}

deactivate_venv() {
  deactivate &>/dev/null || true
}

ensure_venv

###############################################################################
# GIT OPS => FETCH, CHECKOUT, REBASE
###############################################################################
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  bail_out "Not in a git repository => aborting."
fi

log_info "GIT => branch: '$BRANCH', commit_msg: '$COMMIT_MSG'"
log_info "Fetching origin..."
if ! git fetch origin; then
  log_warn "git fetch => fail => continuing offline or local only."
fi

log_info "Checking out => $BRANCH"
if ! git checkout "$BRANCH"; then
  bail_out "Git checkout => fail => $BRANCH not found?"
fi

log_info "Rebase => origin/$BRANCH"
if ! git pull --rebase origin "$BRANCH"; then
  log_warn "Rebase => fail => attempting merge..."
  if ! git pull origin "$BRANCH"; then
    log_warn "Merge => also fail => manual fix needed."
  fi
fi

###############################################################################
# DETECT CHANGED FILES => HEAD~1..HEAD
###############################################################################
log_info "Collecting changed files => HEAD~1..HEAD"
CHANGED_FILES="$(git diff --name-only HEAD~1..HEAD || true)"
echo "$CHANGED_FILES"

###############################################################################
# HPC & NEXTJS & SOCKET.IO DEPLOY
###############################################################################
HPC_SERVICES=(${HPC_SERVICES:-"c_service go_service python_agent rust_service"})
NEXTJS_SERVICE="${NEXTJS_SERVICE:-"nextjs_dashboard"}"
SOCKETIO_SERVICE="${SOCKETIO_SERVICE:-"socket_io_backend"}"
ENABLE_SOCKET_IO_BACKEND="${ENABLE_SOCKET_IO_BACKEND:-false}"

LOG_TAIL_LINES="${LOG_TAIL_LINES:-30}"
LOG_ERROR_PATTERN="${LOG_ERROR_PATTERN:-"(ERROR|FATAL|panic)"}"

build_service() {
  local svc="$1"
  log_info "Building => $svc"
  if ! docker compose build --no-cache "$svc"; then
    log_error "Build => fail => $svc"
    ((ERROR_COUNT++))
    return
  fi
  if ! docker compose up -d "$svc"; then
    log_error "Start => fail => $svc"
    ((ERROR_COUNT++))
    return
  fi

  # Check logs quickly
  log_info "Checking logs => $svc (tail=$LOG_TAIL_LINES lines, pattern=$LOG_ERROR_PATTERN)"
  local logs="$(docker compose logs --tail "$LOG_TAIL_LINES" "$svc" 2>&1 || true)"
  echo "$logs"
  if [[ "$logs" =~ $LOG_ERROR_PATTERN ]]; then
    log_warn "Log check => found potential errors in $svc logs => investigate!"
    ((ERROR_COUNT++))
  else
    log_info "No matching $LOG_ERROR_PATTERN found in last $LOG_TAIL_LINES lines of $svc logs."
  fi
}

rebuild_if_changed() {
  local svc_name="$1"
  local dir_name="$2"
  # Check changes in dir_name
  if git diff --quiet HEAD~1 HEAD -- "$dir_name" 2>/dev/null; then
    log_info "No changes => $dir_name => skip $svc_name"
  else
    log_info "Changes => $dir_name => rebuilding => $svc_name"
    build_service "$svc_name"
  fi
}

# HPC concurrency
log_info "Building HPC services concurrently..."
for hpc_dir in "${HPC_SERVICES[@]}"; do
  rebuild_if_changed "$hpc_dir" "$hpc_dir" &
done
wait

# Next.js
rebuild_if_changed "$NEXTJS_SERVICE" "$NEXTJS_SERVICE"

# Socket.IO backend (optional)
if [[ "$ENABLE_SOCKET_IO_BACKEND" == "true" ]]; then
  rebuild_if_changed "$SOCKETIO_SERVICE" "$SOCKETIO_SERVICE"
fi

###############################################################################
# AI REFACTOR (IF FULL MODE)
###############################################################################
AI_REFACTOR_SCRIPT="${AI_REFACTOR_SCRIPT:-"scripts/ai_refactor.py"}"
if [[ "$FULL_AGI_MODE" == "true" && "${ENABLE_AI_REFACTOR:-false}" == "true" && -f "$AI_REFACTOR_SCRIPT" ]]; then
  log_info "AI refactor => $AI_REFACTOR_SCRIPT"
  activate_venv
  log_info "ML Equation => e.g. Loss = Σ(prediction - target)^2 + λ||W||^2"
  if ! python "$AI_REFACTOR_SCRIPT"; then
    log_warn "AI refactor => encountered issues => see logs."
    ((ERROR_COUNT++))
  fi
  deactivate_venv
else
  log_info "Skipping AI refactor => partial mode or disabled or missing script."
fi

###############################################################################
# DOC ANALYSIS (IF FULL MODE)
###############################################################################
DOC_ANALYSIS_SCRIPT="${DOC_ANALYSIS_SCRIPT:-"scripts/doc_analysis.py"}"
if [[ "$FULL_AGI_MODE" == "true" && "${ENABLE_DOC_ANALYSIS:-false}" == "true" && -f "$DOC_ANALYSIS_SCRIPT" ]]; then
  log_info "Doc analysis => $DOC_ANALYSIS_SCRIPT"
  activate_venv
  log_info "Vector Summation => e.g. Σ(embedding•doc_vector) for advanced search"
  if ! python "$DOC_ANALYSIS_SCRIPT"; then
    log_warn "Doc analysis => had issues => see logs."
    ((ERROR_COUNT++))
  fi
  deactivate_venv
else
  log_info "Skipping doc analysis => partial mode or disabled or missing script."
fi

###############################################################################
# OPTIONAL SOLANA STEPS (IF FULL MODE)
###############################################################################
if [[ "$FULL_AGI_MODE" == "true" && "${ENABLE_SOLANA_STUDY:-false}" == "true" ]]; then
  log_info "Solana study => e.g. anchor build/test (placeholder)."
  # anchor build || log_warn "anchor build => fail"
  # anchor test  || log_warn "anchor test => fail"
fi

###############################################################################
# GIT ADD/COMMIT/PUSH
###############################################################################
log_info "Staging => git add ."
git add .
if ! git diff --quiet --cached; then
  log_info "Committing => '$COMMIT_MSG'"
  if ! git commit -m "$COMMIT_MSG"; then
    log_warn "Git commit => fail => possibly conflict or empty."
  else
    log_info "Pushing => origin/$BRANCH"
    if ! git push origin "$BRANCH"; then
      log_warn "Git push => fail => possibly large file or perms issue."
      ((ERROR_COUNT++))
    fi
  fi
else
  log_info "No changes to commit => skipping push."
fi

###############################################################################
# FINAL SUMMARY
###############################################################################
END_TIME="$(date +%s)"
DURATION=$((END_TIME - START_TIME))

if [[ "$ERROR_COUNT" -eq 0 ]]; then
  log_info "Deployment => finished in ${DURATION}s => 0 errors => success!"
else
  log_warn "Deployment => finished in ${DURATION}s => $ERROR_COUNT errors => investigate!"
fi

cat << "EOF"

  ____  _  _     ____                        _
 / ___|| || |   / ___| _   _ _ __ __ _  __ _| | ___
 \___ \| || |_  \___ \| | | | '__/ _` |/ _` | |/ _ \
  ___) |__   _|  ___) | |_| | | | (_| | (_| | |  __/
 |____/   |_|  |____/ \__,_|_|  \__,_|\__, |_|\___|
                                       |___/

EOF

if [[ "$FULL_AGI_MODE" == "true" ]]; then
  echo "[BINARY => AGI BABY ENABLED] => Full pipeline completed."
else
  echo "[BINARY => AGI BABY DISABLED] => Partial pipeline completed."
fi

echo "Have a nice day!"
exit 0
