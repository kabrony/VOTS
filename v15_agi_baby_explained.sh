#!/usr/bin/env bash
###############################################################################
# v15_agi_baby_explained.sh
#
# Purpose:
#   - If DO_FULL_AGI_PIPE=true => HPC + Next.js + optional AI & doc steps => FULL
#   - Otherwise => HPC + Next.js only => PARTIAL
#   - Minimal "[DONE]/[FAILED]" progress lines for each step
#
# Usage:
#   chmod +x v15_agi_baby_explained.sh
#   DO_FULL_AGI_PIPE=true ./v15_agi_baby_explained.sh [commit_msg] [branch]
###############################################################################

set -Eeuo pipefail

SCRIPT_NAME="$(basename -- "$0")"
START_TIME=$(date +%s)
TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S')"
ERROR_COUNT=0

log_info()  { echo -e "\033[34m[INFO]\033[0m  $SCRIPT_NAME => $*"; }
log_warn()  { echo -e "\033[33m[WARN]\033[0m  $SCRIPT_NAME => $*" >&2; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $SCRIPT_NAME => $*" >&2; }
bail_out()  { log_error "$*"; exit 1; }

COMMIT_MSG="${1:-"auto: system update $TIMESTAMP"}"
BRANCH="${2:-"main"}"

# HPC & Next.js (override if you want):
HPC_SERVICES="${HPC_SERVICES:-"c_service go_service python_agent rust_service"}"
NEXTJS_SERVICE="${NEXTJS_SERVICE:-"nextjs_dashboard"}"

if [[ "${DO_FULL_AGI_PIPE:-false}" == "true" ]]; then
  log_info "DO_FULL_AGI_PIPE=true => FULL pipeline (AGI baby) mode."
  AGI_MODE=true
else
  log_warn "DO_FULL_AGI_PIPE != 'true' => PARTIAL pipeline => skipping AI/doc steps."
  AGI_MODE=false
fi

progress_step() {
  local label="$1"
  shift
  echo -n "$label "
  if "$@"; then
    echo "[DONE]"
  else
    echo "[FAILED]"
    ((ERROR_COUNT++))
  fi
}

log_info "GIT => branch: '$BRANCH', commit_msg: '$COMMIT_MSG'"

progress_step "Fetching origin..."       git fetch origin
progress_step "Checking out => $BRANCH" git checkout "$BRANCH" || bail_out "Cannot checkout branch: $BRANCH"

# Attempt rebase; fallback to merge
if ! git pull --rebase origin "$BRANCH"; then
  log_warn "Rebase => fail => attempting merge..."
  git pull origin "$BRANCH" || log_warn "git merge also failed"
fi

log_info "Collecting changed files => HEAD~1..HEAD"
CHANGED_FILES="$(git diff --name-only HEAD~1..HEAD || true)"

is_changed() {
  local dir="$1"
  if echo "$CHANGED_FILES" | grep -q "^$dir/"; then
    return 0
  else
    return 1
  fi
}

# HPC Rebuild
log_info "Building HPC services (sequential; concurrency possible w/ & and wait)..."

rebuild_service() {
  local svc="$1"
  local dir="$2"
  if is_changed "$dir"; then
    log_info "Changes => $dir => rebuilding Docker service: $svc"

    echo -n "Building $svc "
    if ! docker compose build --no-cache "$svc"; then
      echo "[FAILED]"
      ((ERROR_COUNT++))
      return
    else
      echo "[DONE]"
    fi

    echo -n "Starting $svc "
    if ! docker compose up -d "$svc"; then
      echo "[FAILED]"
      ((ERROR_COUNT++))
    else
      echo "[DONE]"
    fi
  else
    log_info "No changes => $dir => skip rebuild for $svc."
  fi
}

for hpc_svc in $HPC_SERVICES; do
  rebuild_service "$hpc_svc" "$hpc_svc"
done

# Next.js
rebuild_service "$NEXTJS_SERVICE" "$NEXTJS_SERVICE"

# Optional AI/doc if FULL
if $AGI_MODE; then
  if [[ "${ENABLE_AI_REFACTOR:-false}" == "true" && -f "${AI_REFACTOR_SCRIPT:-}" ]]; then
    log_info "AI refactor => ${AI_REFACTOR_SCRIPT}"
    echo -n "Running AI refactor "
    if ! python "${AI_REFACTOR_SCRIPT}"; then
      echo "[FAILED]"
      ((ERROR_COUNT++))
    else
      echo "[DONE]"
    fi
  fi
  if [[ "${ENABLE_DOC_ANALYSIS:-false}" == "true" && -f "${DOC_ANALYSIS_SCRIPT:-}" ]]; then
    log_info "Doc analysis => ${DOC_ANALYSIS_SCRIPT}"
    echo -n "Running doc analysis "
    if ! python "${DOC_ANALYSIS_SCRIPT}"; then
      echo "[FAILED]"
      ((ERROR_COUNT++))
    else
      echo "[DONE]"
    fi
  fi
else
  log_info "Skipping AI refactor & doc analysis => partial pipeline."
fi

# Stage & commit
echo -n "Staging => git add . "
if git add .; then
  echo "[DONE]"
else
  echo "[FAILED]"
  ((ERROR_COUNT++))
fi

echo -n "Committing => '$COMMIT_MSG' "
if git commit -m "$COMMIT_MSG"; then
  echo "[DONE]"
else
  echo "[NO CHANGES TO COMMIT]"
fi

# Push
echo -n "Pushing => origin/$BRANCH "
if git push origin "$BRANCH"; then
  echo "[DONE]"
else
  echo "[FAILED]"
  ((ERROR_COUNT++))
fi

# Final summary
DURATION=$(( $(date +%s) - START_TIME ))
log_info "Deployment => finished in ${DURATION}s => $ERROR_COUNT errors => $( [[ $ERROR_COUNT -eq 0 ]] && echo success || echo 'check logs' )"

cat << 'EOF_ASCII'
  ____  _  _     ____                        _
 / ___|| || |   / ___| _   _ _ __ __ _  __ _| | ___
 \___ \| || |_  \___ \| | | | '__/ _` |/ _` | |/ _ \
  ___) |__   _|  ___) | |_| | | | (_| | (_| | |  __/
 |____/   |_|  |____/ \__,_|_|  \__,_|\__, |_|\___|
                                       |___/
EOF_ASCII

if $AGI_MODE; then
  echo "[BINARY => AGI BABY ENABLED] => Full pipeline completed."
else
  echo "[BINARY => AGI BABY DISABLED] => Partial pipeline completed."
fi

echo "Have a nice day!"
