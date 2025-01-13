#!/usr/bin/env bash
###############################################################################
# v13_agi_baby_visual.sh
#
# Purpose:
#   1) If DO_FULL_AGI_PIPE=true, run HPC + Next.js + optional Socket.IO + AI
#      refactor + doc analysis + optional Solana steps (the "all-in" approach).
#   2) Otherwise (BINARY PARTIAL mode), run HPC + Next.js only, skipping AI/doc.
#
# Visual Enhancements:
#   - Minimal approach to "progress bars" by printing [DONE] or [FAILED].
#   - Each major step prints a single-line status.
#   - For more advanced bars, see 'dialog' or 'whiptail' in Linux.
#
# HPC concurrency example:
#   - We *could* run HPC builds in parallel with "&" and then "wait".
#   - Currently sequential for clarity.
#
# Usage:
#   chmod +x v13_agi_baby_visual.sh
#   DO_FULL_AGI_PIPE=true ./v13_agi_baby_visual.sh [commit_msg] [branch]
#
# Environment Variables (Examples):
#   DO_FULL_AGI_PIPE=true|false
#   HPC_SERVICES="c_service go_service python_agent rust_service"
#   NEXTJS_SERVICE="nextjs_dashboard"
#   ENABLE_AI_REFACTOR=true|false
#   AI_REFACTOR_SCRIPT="scripts/ai_refactor.py"
#   ENABLE_DOC_ANALYSIS=true|false
#   DOC_ANALYSIS_SCRIPT="scripts/doc_analysis.py"
#   ENABLE_SOCKET_IO_BACKEND=true|false
#   SOCKETIO_SERVICE="socket_io_backend"
#   ENABLE_SOLANA_STUDY=true|false
#   VIRTUAL_ENV_DIR="./venv"
#   ENCRYPTED_SECRETS_FILE="./secrets.enc"
#   DECRYPT_CMD="gpg -d secrets.enc"
#   MAINTENANCE_WINDOW_START="02:00"
#   MAINTENANCE_WINDOW_END="04:00"
#   ENABLE_MAINTENANCE_WINDOW_CHECK=true|false
#
# Disclaimer:
#   - Actual "AGI baby" or "ASI" logic requires extensive AI code beyond this script.
#   - Secrets & security are simplified; use robust solutions in production.
###############################################################################

set -Eeuo pipefail

###############################################################################
# 0) GLOBAL CONFIG & LOGGING
###############################################################################
SCRIPT_NAME="$(basename -- "$0")"  # Safely parse script name
START_TIME=$(date +%s)
TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S')"
ERROR_COUNT=0

# Logging helpers
log_info()  { echo -e "\033[34m[INFO]\033[0m  $SCRIPT_NAME => $*"; }
log_warn()  { echo -e "\033[33m[WARN]\033[0m  $SCRIPT_NAME => $*" >&2; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $SCRIPT_NAME => $*" >&2; }
bail_out()  { log_error "$*"; exit 1; }

###############################################################################
# 1) CLI ARGS: COMMIT_MSG, BRANCH
###############################################################################
COMMIT_MSG="${1:-"auto: system update $TIMESTAMP"}"
BRANCH="${2:-"main"}"

###############################################################################
# 2) DETERMINE PIPELINE MODE
###############################################################################
if [[ "${DO_FULL_AGI_PIPE:-false}" == "true" ]]; then
  log_info "DO_FULL_AGI_PIPE=true => FULL pipeline (AGI baby) mode."
  FULL_AGI_MODE=true
else
  log_warn "DO_FULL_AGI_PIPE != 'true' => PARTIAL pipeline => skipping AI/doc steps."
  FULL_AGI_MODE=false
fi

###############################################################################
# (Optional) MAINTENANCE WINDOW CHECK
###############################################################################
if [[ "${ENABLE_MAINTENANCE_WINDOW_CHECK:-false}" == "true" ]]; then
  CURRENT_TIME=$(date +%H:%M)
  if [[ "$CURRENT_TIME" < "${MAINTENANCE_WINDOW_START:-"02:00"}" || "$CURRENT_TIME" > "${MAINTENANCE_WINDOW_END:-"04:00"}" ]]; then
    log_warn "Outside of maintenance window (${MAINTENANCE_WINDOW_START}-${MAINTENANCE_WINDOW_END})."
    # bail_out "Deployment aborted due to outside maintenance window"
  else
    log_info "Within maintenance window => proceeding."
  fi
fi

###############################################################################
# (Optional) DECRYPT SECRETS
###############################################################################
### if [[ -f "${ENCRYPTED_SECRETS_FILE:-}" ]]; then
###   echo -n "Decrypting secrets "
###   if ! ${DECRYPT_CMD:-true}; then
###     log_warn "Failed to decrypt secrets. Possibly no secrets or error."
###     echo " [WARN]"
###   else
###     echo " [DONE]"
###   fi
### else
log_warn "No secrets file => skipping secrets logic."
### fi

###############################################################################
# 3) PYTHON VENV
###############################################################################
if [[ -d "${VIRTUAL_ENV_DIR:-"./venv"}" ]]; then
  log_info "Python venv found => ${VIRTUAL_ENV_DIR:-"./venv"}"
else
  log_warn "No Python virtual environment => creating one..."
  python3 -m venv "${VIRTUAL_ENV_DIR:-"./venv"}" || bail_out "Failed to create venv"
fi

activate_venv() {
  source "${VIRTUAL_ENV_DIR:-"./venv"}/bin/activate" || bail_out "Failed to activate venv"
}

deactivate_venv() {
  deactivate || true
}

###############################################################################
# 4) GIT OPERATIONS
###############################################################################
log_info "GIT => branch: '$BRANCH', commit_msg: '$COMMIT_MSG'"

echo -n "Fetching origin "
if ! git fetch origin; then
  log_warn "Git fetch failed or no network."
  echo " [WARN]"
else
  echo " [DONE]"
fi

echo -n "Checking out => $BRANCH "
if ! git checkout "$BRANCH"; then
  bail_out "Cannot checkout branch: $BRANCH"
fi
echo " [DONE]"

echo -n "Rebase => origin/$BRANCH "
if ! git pull --rebase origin "$BRANCH"; then
  log_warn "Rebase => fail => attempting merge..."
  if ! git pull origin "$BRANCH"; then
    log_warn "Merge also failed => user must resolve manually."
    echo " [FAILED]"
  else
    echo " [MERGED]"
  fi
else
  echo " [DONE]"
fi

###############################################################################
# 5) COLLECT CHANGED FILES
###############################################################################
log_info "Collecting changed files => HEAD~1..HEAD"
CHANGED_FILES="$(git diff --name-only HEAD~1..HEAD || true)"
echo "$CHANGED_FILES"

###############################################################################
# 6) HPC & NEXTJS REBUILD
###############################################################################
HPC_SERVICES="${HPC_SERVICES:-"c_service go_service python_agent rust_service"}"
NEXTJS_SERVICE="${NEXTJS_SERVICE:-"nextjs_dashboard"}"

is_changed() {
  local dir="$1"
  echo "$CHANGED_FILES" | grep -q "^$dir/" && return 0 || return 1
}

rebuild_service() {
  local svc="$1"
  local dir="$2"

  if is_changed "$dir"; then
    log_info "Changes => $dir => Rebuilding Docker service: $svc"

    echo -n "Building $svc "
    if ! docker compose build --no-cache "$svc"; then
      log_error "Build failed for $svc."
      ((ERROR_COUNT++))
      echo " [FAILED]"
      return
    else
      echo " [DONE]"
    fi

    echo -n "Starting $svc "
    if ! docker compose up -d "$svc"; then
      log_error "Failed to start $svc."
      ((ERROR_COUNT++))
      echo " [FAILED]"
    else
      echo " [DONE]"
    fi
  else
    log_info "No changes => $dir => skip rebuild for $svc."
  fi
}

log_info "Building HPC services (currently sequential, can be parallel if you prefer)..."
for hpc_dir in $HPC_SERVICES; do
  # rebuild_service "$hpc_dir" "$hpc_dir" &  # uncomment for concurrency
  rebuild_service "$hpc_dir" "$hpc_dir"
done
# wait  # if concurrency is used

# Next.js
rebuild_service "$NEXTJS_SERVICE" "$NEXTJS_SERVICE"

###############################################################################
# 7) AI REFACTOR & DOC ANALYSIS (Only if FULL_AGI_MODE)
###############################################################################
if [[ "$FULL_AGI_MODE" == "true" ]]; then
  # AI REFACTOR
  if [[ "${ENABLE_AI_REFACTOR:-false}" == "true" && -f "${AI_REFACTOR_SCRIPT:-}" ]]; then
    log_info "AI refactor => ${AI_REFACTOR_SCRIPT}"
    echo -n "AI Refactor "
    activate_venv
    if ! python "${AI_REFACTOR_SCRIPT}"; then
      log_warn "AI refactor encountered issues."
      ((ERROR_COUNT++))
      echo " [WARN]"
    else
      echo " [DONE]"
    fi
    deactivate_venv
  else
    log_info "Skipping AI refactor => disabled or script not found."
  fi

  # DOC ANALYSIS
  if [[ "${ENABLE_DOC_ANALYSIS:-false}" == "true" && -f "${DOC_ANALYSIS_SCRIPT:-}" ]]; then
    log_info "Doc analysis => ${DOC_ANALYSIS_SCRIPT}"
    echo -n "Doc Analysis "
    activate_venv
    if ! python "${DOC_ANALYSIS_SCRIPT}"; then
      log_warn "Doc analysis encountered issues."
      ((ERROR_COUNT++))
      echo " [WARN]"
    else
      echo " [DONE]"
    fi
    deactivate_venv
  else
    log_info "Skipping doc analysis => disabled or script not found."
  fi

  # (Optional) Solana steps here...
  # if [[ "${ENABLE_SOLANA_STUDY:-false}" == "true" ]]; then
  #   log_info "Running Solana tasks..."
  #   # e.g. anchor build/anchor test
  # fi
else
  log_info "Skipping AI refactor & doc analysis => partial pipeline."
fi

###############################################################################
# 8) GIT COMMIT & PUSH
###############################################################################
echo -n "Staging => git add . "
git add .
echo " [DONE]"

echo -n "Committing => '$COMMIT_MSG' "
if git diff --cached --quiet; then
  echo " [NO CHANGES TO COMMIT]"
else
  if ! git commit -m "$COMMIT_MSG"; then
    log_error "Commit failed."
    ((ERROR_COUNT++))
    echo " [FAILED]"
  else
    echo " [DONE]"
    echo -n "Pushing => origin/$BRANCH "
    if ! git push origin "$BRANCH"; then
      log_error "Push failed."
      ((ERROR_COUNT++))
      echo " [FAILED]"
    else
      echo " [DONE]"
    fi
  fi
fi

###############################################################################
# 9) FINAL SUMMARY
###############################################################################
DURATION=$(( $(date +%s) - START_TIME ))

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
