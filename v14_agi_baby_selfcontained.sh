#!/usr/bin/env bash
###############################################################################
# v14_agi_baby_selfcontained.sh
#
# Purpose:
#   - If DO_FULL_AGI_PIPE=true => HPC + Next.js + (optionally) AI refactor, doc
#     analysis, Solana steps (the "all-in" approach).
#   - Else => partial pipeline (HPC + Next.js only). 
#
# Visual Enhancements:
#   - Minimal "progress bars" -> printing [DONE]/[FAILED].
#   - HPC concurrency is possible, but default is sequential for clarity.
#
# Usage:
#   chmod +x v14_agi_baby_selfcontained.sh
#   DO_FULL_AGI_PIPE=true ./v14_agi_baby_selfcontained.sh [commit_msg] [branch]
#
# Environment Variables:
#   DO_FULL_AGI_PIPE=true|false
#   HPC_SERVICES="c_service go_service python_agent rust_service"
#   NEXTJS_SERVICE="nextjs_dashboard"
#   ENABLE_AI_REFACTOR=true|false
#   AI_REFACTOR_SCRIPT="scripts/ai_refactor.py"
#   ENABLE_DOC_ANALYSIS=true|false
#   DOC_ANALYSIS_SCRIPT="scripts/doc_analysis.py"
#   ...
#
# Disclaimer:
#   - Real "AGI" logic requires more advanced AI code outside of this script.
###############################################################################

set -Eeuo pipefail

# 0) GLOBAL CONFIG
SCRIPT_NAME="$(basename -- "$0")"
START_TIME=$(date +%s)
TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S')"
ERROR_COUNT=0

# Logging
log_info()  { echo -e "\033[34m[INFO]\033[0m  $SCRIPT_NAME => $*"; }
log_warn()  { echo -e "\033[33m[WARN]\033[0m  $SCRIPT_NAME => $*" >&2; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $SCRIPT_NAME => $*" >&2; }
bail_out()  { log_error "$*"; exit 1; }

# 1) CLI ARGS
COMMIT_MSG="${1:-"auto: system update $TIMESTAMP"}"
BRANCH="${2:-"main"}"

# 2) DETERMINE MODE
if [[ "${DO_FULL_AGI_PIPE:-false}" == "true" ]]; then
  log_info "DO_FULL_AGI_PIPE=true => FULL pipeline (AGI baby) mode."
  FULL_AGI_MODE=true
else
  log_warn "DO_FULL_AGI_PIPE != 'true' => PARTIAL pipeline => skipping AI/doc steps."
  FULL_AGI_MODE=false
fi

# 3) HPC & Next.js config
HPC_SERVICES="${HPC_SERVICES:-"c_service go_service python_agent rust_service"}"
NEXTJS_SERVICE="${NEXTJS_SERVICE:-"nextjs_dashboard"}"

# 4) GIT OPS
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
  log_warn "Rebase => fail => merging instead..."
  if ! git pull origin "$BRANCH"; then
    log_warn "Merge also failed => user must resolve manually."
    echo " [FAILED]"
  else
    echo " [MERGED]"
  fi
else
  echo " [DONE]"
fi

# 5) DETECT CHANGES
log_info "Collecting changed files => HEAD~1..HEAD"
CHANGED_FILES="$(git diff --name-only HEAD~1..HEAD || true)"
echo "$CHANGED_FILES"

# Helper to check if a directory changed
is_changed() {
  local dir="$1"
  echo "$CHANGED_FILES" | grep -q "^$dir/" && return 0 || return 1
}

# Minimal progress
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

# 6) HPC & NEXTJS
log_info "Building HPC services (sequential; concurrency possible w/ & and wait)..."
for hpc_dir in $HPC_SERVICES; do
  rebuild_service "$hpc_dir" "$hpc_dir"
done

# Next.js build
rebuild_service "$NEXTJS_SERVICE" "$NEXTJS_SERVICE"

# 7) OPTIONAL AI & DOC
if [[ "$FULL_AGI_MODE" == "true" ]]; then
  if [[ "${ENABLE_AI_REFACTOR:-false}" == "true" && -f "${AI_REFACTOR_SCRIPT:-}" ]]; then
    log_info "AI refactor => ${AI_REFACTOR_SCRIPT}"
    echo -n "AI Refactor "
    if ! python "${AI_REFACTOR_SCRIPT}"; then
      log_warn "AI refactor encountered issues."
      ((ERROR_COUNT++))
      echo " [WARN]"
    else
      echo " [DONE]"
    fi
  else
    log_info "Skipping AI refactor => disabled or script not found."
  fi

  if [[ "${ENABLE_DOC_ANALYSIS:-false}" == "true" && -f "${DOC_ANALYSIS_SCRIPT:-}" ]]; then
    log_info "Doc analysis => ${DOC_ANALYSIS_SCRIPT}"
    echo -n "Doc Analysis "
    if ! python "${DOC_ANALYSIS_SCRIPT}"; then
      log_warn "Doc analysis encountered issues."
      ((ERROR_COUNT++))
      echo " [WARN]"
    else
      echo " [DONE]"
    fi
  else
    log_info "Skipping doc analysis => disabled or script not found."
  fi

  # e.g., Solana steps if ENABLE_SOLANA_STUDY=true ...
else
  log_info "Skipping AI refactor & doc analysis => partial pipeline."
fi

# 8) COMMIT & PUSH
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

# 9) FINAL SUMMARY
DURATION=$(( $(date +%s) - START_TIME ))
if [[ "$ERROR_COUNT" -eq 0 ]]; then
  log_info "Deployment => finished in ${DURATION}s => 0 errors => success!"
else
  log_warn "Deployment => finished in ${DURATION}s => $ERROR_COUNT errors => investigate!"
fi

cat << "BANNER_EOF"
  ____  _  _     ____                        _
 / ___|| || |   / ___| _   _ _ __ __ _  __ _| | ___
 \___ \| || |_  \___ \| | | | '__/ _` |/ _` | |/ _ \
  ___) |__   _|  ___) | |_| | | | (_| | (_| | |  __/
 |____/   |_|  |____/ \__,_|_|  \__,_|\__, |_|\___|
                                       |___/
BANNER_EOF

if [[ "$FULL_AGI_MODE" == "true" ]]; then
  echo "[BINARY => AGI BABY ENABLED] => Full pipeline completed."
else
  echo "[BINARY => AGI BABY DISABLED] => Partial pipeline completed."
fi

echo "Have a nice day!"
