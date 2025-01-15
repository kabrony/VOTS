#!/usr/bin/env bash
###############################################################################
# v19_check_and_update.sh
#
# Purpose:
#   1) Fetch & rebase from Git to ensure we're at the latest commit.
#   2) Identify which HPC service directories changed (e.g., c_service, go_service,
#      python_agent, rust_service) plus Next.js dashboard directory (if any).
#   3) Rebuild & restart only those changed Docker services, skipping unchanged ones.
#   4) If DO_FULL_AGI_PIPE=true, optionally run AI refactor or doc analysis scripts
#      (ENABLE_AI_REFACTOR / ENABLE_DOC_ANALYSIS).
#   5) Commit & push any code changes (e.g., from AI or doc scripts) back to Git.
#
# Environment Variables (example):
#   HPC_SERVICES="c_service go_service python_agent rust_service"
#   NEXTJS_SERVICE="nextjs_dashboard"
#   DO_FULL_AGI_PIPE=true|false
#   ENABLE_AI_REFACTOR=true|false
#   AI_REFACTOR_SCRIPT="scripts/ai_refactor.py"
#   ENABLE_DOC_ANALYSIS=true|false
#   DOC_ANALYSIS_SCRIPT="scripts/doc_analysis.py"
#
# Usage:
#   chmod +x v19_check_and_update.sh
#   DO_FULL_AGI_PIPE=true ./v19_check_and_update.sh "my commit" "main"
#
# Disclaimers:
#   - Make sure your docker-compose.yml has matching service names to HPC_SERVICES.
#   - Real AGI logic or advanced error handling can be extended as needed.
###############################################################################

set -Eeuo pipefail

###############################################################################
# 0) CONFIG & LOGGING
###############################################################################
SCRIPT_NAME="$(basename -- "$0")"
TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S')"
ERROR_COUNT=0

# CLI arguments
COMMIT_MSG="${1:-"auto: system update $TIMESTAMP"}"
BRANCH="${2:-"main"}"

# HPC & Next.js config
HPC_SERVICES="${HPC_SERVICES:-"c_service go_service python_agent rust_service"}"
NEXTJS_SERVICE="${NEXTJS_SERVICE:-"nextjs_dashboard"}"

# AGI/AI flags
DO_FULL_AGI_PIPE="${DO_FULL_AGI_PIPE:-false}"
ENABLE_AI_REFACTOR="${ENABLE_AI_REFACTOR:-false}"
AI_REFACTOR_SCRIPT="${AI_REFACTOR_SCRIPT:-"scripts/ai_refactor.py"}"
ENABLE_DOC_ANALYSIS="${ENABLE_DOC_ANALYSIS:-false}"
DOC_ANALYSIS_SCRIPT="${DOC_ANALYSIS_SCRIPT:-"scripts/doc_analysis.py"}"

# Logging
log_info()  { echo -e "\033[34m[INFO]\033[0m  $SCRIPT_NAME => $*"; }
log_warn()  { echo -e "\033[33m[WARN]\033[0m  $SCRIPT_NAME => $*" >&2; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $SCRIPT_NAME => $*" >&2; }

# Graceful exit on fatal error
bail_out() {
  log_error "$*"
  exit 1
}

###############################################################################
# 1) GIT UPDATE
###############################################################################
log_info "=== [Step 1] GIT fetch & rebase => branch: '$BRANCH', commit_msg: '$COMMIT_MSG'"
if ! git fetch origin; then
  log_warn "git fetch failed. Possibly no network or remote?"
fi

if ! git checkout "$BRANCH"; then
  bail_out "Cannot checkout branch: $BRANCH"
fi

if ! git pull --rebase origin "$BRANCH"; then
  log_warn "Rebase failed => attempting merge..."
  if ! git pull origin "$BRANCH"; then
    log_warn "Merge also failed => continuing anyway. (Check conflicts?)"
  fi
fi

###############################################################################
# 2) DETERMINE CHANGED FILES
###############################################################################
log_info "=== [Step 2] Checking changes => HEAD~1..HEAD"
CHANGED_FILES="$(git diff --name-only HEAD~1..HEAD || true)"

if [[ -z "$CHANGED_FILES" ]]; then
  log_info "No new changes => HPC & Next.js might be up-to-date. We'll still do optional AI/doc steps."
else
  log_info "Changed files:\n$CHANGED_FILES"
fi

###############################################################################
# 3) REBUILD & RESTART HPC (only changed)
###############################################################################
# Helper: check if HPC directory changed
dir_changed() {
  local dir="$1"
  if echo "$CHANGED_FILES" | grep -q "^$dir/"; then
    return 0
  else
    return 1
  fi
}

# Build HPC services that changed
log_info "=== [Step 3] HPC Rebuild if changed ==="
for svc_dir in $HPC_SERVICES; do
  if dir_changed "$svc_dir"; then
    log_info "Changes in $svc_dir => Rebuilding Docker service: $svc_dir"
    if ! docker compose build --no-cache "$svc_dir"; then
      log_error "Failed to build HPC service => $svc_dir"
      ((ERROR_COUNT++))
      continue
    fi
    log_info "Starting HPC service => $svc_dir"
    if ! docker compose up -d "$svc_dir"; then
      log_error "Failed to start HPC service => $svc_dir"
      ((ERROR_COUNT++))
    fi
  else
    log_info "No changes => skip build => $svc_dir"
    # Still ensure HPC is up
    log_info "Starting HPC service => $svc_dir"
    docker compose up -d "$svc_dir" || {
      log_error "Failed to start HPC service => $svc_dir"
      ((ERROR_COUNT++))
    }
  fi
done

###############################################################################
# 4) REBUILD & RESTART NEXTJS (only if changed)
###############################################################################
log_info "=== [Step 4] Next.js Rebuild if changed ==="
if dir_changed "$NEXTJS_SERVICE"; then
  log_info "Changes in $NEXTJS_SERVICE => Rebuilding Docker service => $NEXTJS_SERVICE"
  if ! docker compose build --no-cache "$NEXTJS_SERVICE"; then
    log_error "Failed to build Next.js => $NEXTJS_SERVICE"
    ((ERROR_COUNT++))
  else
    log_info "Starting Next.js => $NEXTJS_SERVICE"
    if ! docker compose up -d "$NEXTJS_SERVICE"; then
      log_error "Failed to start Next.js => $NEXTJS_SERVICE"
      ((ERROR_COUNT++))
    fi
  fi
else
  log_info "No changes => skip build => $NEXTJS_SERVICE"
  log_info "Starting Next.js => $NEXTJS_SERVICE"
  docker compose up -d "$NEXTJS_SERVICE" || {
    log_error "Failed to start Next.js => $NEXTJS_SERVICE"
    ((ERROR_COUNT++))
  }
fi

###############################################################################
# 5) OPTIONAL AI & DOC STEPS (if DO_FULL_AGI_PIPE=true)
###############################################################################
log_info "=== [Step 5] Optional AI & Doc Analysis ==="
if [[ "$DO_FULL_AGI_PIPE" == "true" ]]; then
  # AI Refactor
  if [[ "$ENABLE_AI_REFACTOR" == "true" && -f "$AI_REFACTOR_SCRIPT" ]]; then
    log_info "Running AI refactor => $AI_REFACTOR_SCRIPT"
    if ! python "$AI_REFACTOR_SCRIPT"; then
      log_warn "AI refactor encountered errors. Continue anyway."
      ((ERROR_COUNT++))
    fi
  else
    log_info "Skipping AI refactor => not enabled or script not found."
  fi

  # Doc Analysis
  if [[ "$ENABLE_DOC_ANALYSIS" == "true" && -f "$DOC_ANALYSIS_SCRIPT" ]]; then
    log_info "Running Doc Analysis => $DOC_ANALYSIS_SCRIPT"
    if ! python "$DOC_ANALYSIS_SCRIPT"; then
      log_warn "Doc analysis encountered errors. Continue anyway."
      ((ERROR_COUNT++))
    fi
  else
    log_info "Skipping doc analysis => not enabled or script not found."
  fi

else
  log_info "DO_FULL_AGI_PIPE != 'true' => partial pipeline => skipping AI/doc steps."
fi

###############################################################################
# 6) GIT ADD/COMMIT/PUSH
###############################################################################
log_info "=== [Step 6] Committing & Pushing if changes exist ==="
git add .
if ! git diff-index --quiet HEAD --; then
  log_info "We have changes => committing => '$COMMIT_MSG'"
  if ! git commit -m "$COMMIT_MSG"; then
    log_error "Commit failed => investigate."
    ((ERROR_COUNT++))
  else
    log_info "Pushing to branch => $BRANCH"
    if ! git push origin "$BRANCH"; then
      log_error "Push failed => check your connection or perms."
      ((ERROR_COUNT++))
    fi
  fi
else
  log_info "No changes to commit => skipping push."
fi

###############################################################################
# 7) FINAL SUMMARY
###############################################################################
log_info "Deployment => finished => $ERROR_COUNT errors => success if 0."
cat << 'EOF_ASCII'
  ____  _  _           ___         _
 /_  __/__ _(_)(_)__ __    / _ \__  ___| |___
  / / / _ `/ / / / // /   / ___/ _ \/ _  / -_)
 /_/  \_,_/_/_/_/\_, /   /_/   \___/\_,_/\__/
                 /___/   HPC + AI synergy pipeline
EOF_ASCII

if [[ "$DO_FULL_AGI_PIPE" == "true" ]]; then
  echo "[BINARY => AGI BABY ENABLED] => Full pipeline completed."
else
  echo "[BINARY => AGI BABY DISABLED] => Partial pipeline completed."
fi

if [[ "$ERROR_COUNT" -eq 0 ]]; then
  echo "Have a nice day! (No errors)."
  exit 0
else
  echo "We had $ERROR_COUNT errors => check logs."
  exit 1
fi
