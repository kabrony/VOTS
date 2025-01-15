#!/usr/bin/env bash
###############################################################################
# v18_agi_baby_autoloop_v2.sh - Self-Improving Pipeline (Experimental)
#
# Purpose:
#   - Runs up to MAX_ITERATIONS in a loop, each time executing this pipeline:
#       1) HPC microservices build (parallel or sequential).
#       2) Next.js build, if changed.
#       3) Optional AI refactor & doc analysis (if DO_FULL_AGI_PIPE=true).
#       4) Commits/pushes changes (Git).
#   - Measures performance (time, error count).
#   - If errors or high runtime occur, may re-run certain steps in next iteration.
#   - Demonstrates a toy example of an "AGI baby" autoloop, not real AGI/ASI.
#
# Key Features:
#   - Partial vs. Full (DO_FULL_AGI_PIPE)
#   - HPC concurrency control (ENABLE_PARALLEL_HPC, PARALLEL_JOBS)
#   - AI refactor & Doc analysis with caching
#   - Loop-based "self-improvement" placeholders
#   - Clean logging & timing
#
# Usage (examples):
#   chmod +x v18_agi_baby_autoloop_v2.sh
#   DO_FULL_AGI_PIPE=true ./v18_agi_baby_autoloop_v2.sh "commit msg" "my-branch"
#
# Environment Variables (Examples):
#   DO_FULL_AGI_PIPE=true|false
#   HPC_SERVICES="c_service go_service python_agent rust_service"
#   NEXTJS_SERVICE="nextjs_dashboard"
#   ENABLE_AI_REFACTOR=true|false
#   AI_REFACTOR_SCRIPT="scripts/ai_refactor.py"
#   ENABLE_DOC_ANALYSIS=true|false
#   DOC_ANALYSIS_SCRIPT="scripts/doc_analysis.py"
#   ENABLE_PARALLEL_HPC=true|false
#   PARALLEL_JOBS=2
#   MAX_ITERATIONS=3
#   INITIAL_WAIT_TIME=5
#   LOOP_WAIT_TIME=10
###############################################################################

set -Eeuo pipefail

# ---[ GLOBAL CONFIG ]-------------------------------------------------------
SCRIPT_NAME="$(basename -- "$0")"
TIMESTAMP_FORMAT='%Y-%m-%d %H:%M:%S'
ERROR_COUNT=0

# CLI arguments
COMMIT_MSG="${1:-"auto: system update $(date +"${TIMESTAMP_FORMAT}")"}"
BRANCH="${2:-"main"}"

# HPC & Next.js config
HPC_SERVICES="${HPC_SERVICES:-"c_service go_service python_agent rust_service"}"
NEXTJS_SERVICE="${NEXTJS_SERVICE:-"nextjs_dashboard"}"

# Loop controls
MAX_ITERATIONS="${MAX_ITERATIONS:-3}"
INITIAL_WAIT_TIME="${INITIAL_WAIT_TIME:-5}"
LOOP_WAIT_TIME="${LOOP_WAIT_TIME:-10}"

# Flags / Feature toggles
DO_FULL_AGI_PIPE="${DO_FULL_AGI_PIPE:-false}"
ENABLE_AI_REFACTOR="${ENABLE_AI_REFACTOR:-false}"
AI_REFACTOR_SCRIPT="${AI_REFACTOR_SCRIPT:-"scripts/ai_refactor.py"}"
ENABLE_DOC_ANALYSIS="${ENABLE_DOC_ANALYSIS:-false}"
DOC_ANALYSIS_SCRIPT="${DOC_ANALYSIS_SCRIPT:-"scripts/doc_analysis.py"}"
ENABLE_PARALLEL_HPC="${ENABLE_PARALLEL_HPC:-false}"
PARALLEL_JOBS="${PARALLEL_JOBS:-2}"

# AI/Doc caching
AI_REFACTOR_CACHE_FILE=".ai_refactor_cache"
DOC_ANALYSIS_CACHE_FILE=".doc_analysis_cache"

# ---[ LOGGING ]-------------------------------------------------------------
log_info()  { echo -e "\033[34m[INFO]\033[0m  $(date +"${TIMESTAMP_FORMAT}") - $SCRIPT_NAME => $*"; }
log_warn()  { echo -e "\033[33m[WARN]\033[0m  $(date +"${TIMESTAMP_FORMAT}") - $SCRIPT_NAME => $*" >&2; }
log_error() { echo -e "\033[31m[ERROR]\033[0m $(date +"${TIMESTAMP_FORMAT}") - $SCRIPT_NAME => $*" >&2; }
bail_out()  { log_error "$*"; exit 1; }

# ---[ GIT OPERATIONS ]------------------------------------------------------
git_fetch_checkout() {
  log_info "Fetching origin..."
  if ! git fetch origin; then
    log_warn "git fetch failed or no network. Continuing with local changes only."
  fi

  log_info "Checking out => $BRANCH"
  if ! git checkout "$BRANCH"; then
    bail_out "Cannot checkout branch: $BRANCH"
  fi
}

git_pull_rebase_or_merge() {
  if ! git pull --rebase origin "$BRANCH"; then
    log_warn "Rebase => fail => attempting merge..."
    if ! git pull origin "$BRANCH"; then
      log_warn "git merge also failed. Manual conflict resolution needed."
    fi
  fi
}

# Collect changed files in HEAD~1..HEAD
collect_changed_files() {
  local range="HEAD~1..HEAD"
  log_info "Collecting changed files => $range"
  CHANGED_FILES="$(git diff --name-only $range 2>/dev/null || true)"
  if [[ -z "$CHANGED_FILES" ]]; then
    log_info "No changed files found in $range"
  else
    log_info "Changed files:\n$CHANGED_FILES"
  fi
}

is_dir_changed() {
  local dir="$1"
  # If any file changed under the $dir/ path
  if echo "$CHANGED_FILES" | grep -qE "^${dir}/"; then
    return 0
  else
    return 1
  fi
}

# ---[ HPC BUILD ]-----------------------------------------------------------
build_hpc_services() {
  log_info "=== HPC Build Phase ==="
  local pids=()

  # Build HPC in parallel or sequentially
  for svc_dir in $HPC_SERVICES; do
    if is_dir_changed "$svc_dir"; then
      log_info "Detected changes => building Docker service: $svc_dir"
      if [[ "$ENABLE_PARALLEL_HPC" == "true" ]]; then
        (
          if ! docker compose build --no-cache "$svc_dir"; then
            log_error "Failed build => $svc_dir"
            ((ERROR_COUNT++))
          fi
        ) &
        pids+=( "$!" )

        # Concurrency check
        if [[ "${#pids[@]}" -ge "$PARALLEL_JOBS" ]]; then
          wait -n || true
        fi
      else
        # sequential build
        if ! docker compose build --no-cache "$svc_dir"; then
          log_error "Failed build => $svc_dir"
          ((ERROR_COUNT++))
        fi
      fi
    else
      log_info "No changes => skip build => $svc_dir"
    fi
  done

  # Wait for all parallel HPC builds to finish
  if [[ "$ENABLE_PARALLEL_HPC" == "true" && "${#pids[@]}" -gt 0 ]]; then
    wait "${pids[@]}" || true
  fi

  # Start HPC containers
  for svc_dir in $HPC_SERVICES; do
    log_info "Starting HPC service => $svc_dir"
    if ! docker compose up -d "$svc_dir"; then
      log_error "Failed to start => $svc_dir"
      ((ERROR_COUNT++))
    fi
  done
}

# ---[ NEXTJS BUILD ]--------------------------------------------------------
build_nextjs() {
  log_info "=== Next.js Build Phase ==="
  local svc="$NEXTJS_SERVICE"

  if is_dir_changed "$svc"; then
    log_info "Detected changes => building Docker service: $svc"
    if ! docker compose build --no-cache "$svc"; then
      log_error "Failed build => $svc"
      ((ERROR_COUNT++))
    fi
    if ! docker compose up -d "$svc"; then
      log_error "Failed to start => $svc"
      ((ERROR_COUNT++))
    fi
  else
    log_info "No changes => skip build => $svc"
  fi
}

# ---[ AI & DOC STEPS ]------------------------------------------------------
run_ai_refactor() {
  if [[ ! -f "$AI_REFACTOR_SCRIPT" ]]; then
    log_warn "AI refactor script not found => skipping."
    return
  fi
  local input_hash
  input_hash="$(find . -name "*.py" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum || echo 'nohash')"

  if [[ -f "$AI_REFACTOR_CACHE_FILE" && "$(cat "$AI_REFACTOR_CACHE_FILE")" == "$input_hash" ]]; then
    log_info "AI refactor => no code changes => skipping (cached)."
    return
  fi

  log_info "AI refactor => running script => $AI_REFACTOR_SCRIPT"
  if python "$AI_REFACTOR_SCRIPT"; then
    echo "$input_hash" > "$AI_REFACTOR_CACHE_FILE"
  else
    log_error "AI refactor => script failed."
    ((ERROR_COUNT++))
  fi
}

run_doc_analysis() {
  if [[ ! -f "$DOC_ANALYSIS_SCRIPT" ]]; then
    log_warn "Doc analysis script not found => skipping."
    return
  fi
  local doc_hash
  doc_hash="$(find ./docs -type f -name '*.md' -print0 | sort -z | xargs -0 sha256sum | sha256sum || echo 'nohash')"

  if [[ -f "$DOC_ANALYSIS_CACHE_FILE" && "$(cat "$DOC_ANALYSIS_CACHE_FILE")" == "$doc_hash" ]]; then
    log_info "Doc analysis => no doc changes => skipping (cached)."
    return
  fi

  log_info "Doc analysis => running script => $DOC_ANALYSIS_SCRIPT"
  if python "$DOC_ANALYSIS_SCRIPT"; then
    echo "$doc_hash" > "$DOC_ANALYSIS_CACHE_FILE"
  else
    log_error "Doc analysis => script failed."
    ((ERROR_COUNT++))
  fi
}

# ---[ MAIN AUTOLOOP ]-------------------------------------------------------
main_autoloop() {
  log_info "=== Starting AGI Baby Autoloop (max iterations: $MAX_ITERATIONS) ==="
  sleep "$INITIAL_WAIT_TIME"

  local iteration=1
  while [[ "$iteration" -le "$MAX_ITERATIONS" ]]; do
    log_info "--- [AUTOLOOP ITERATION: $iteration] ---"
    ERROR_COUNT=0
    local loop_start
    loop_start="$(date +%s)"

    # Git ops
    git_fetch_checkout
    git_pull_rebase_or_merge

    # Collect changed files
    collect_changed_files

    # HPC build
    build_hpc_services

    # Next.js build
    build_nextjs

    # Optional AI/doc if FULL
    if [[ "$DO_FULL_AGI_PIPE" == "true" ]]; then
      if [[ "$ENABLE_AI_REFACTOR" == "true" ]]; then
        run_ai_refactor
      fi
      if [[ "$ENABLE_DOC_ANALYSIS" == "true" ]]; then
        run_doc_analysis
      fi
    else
      log_info "Skipping AI & doc => partial pipeline mode."
    fi

    # Stage/commit/push
    log_info "Staging => git add ."
    if ! git add .; then
      log_error "git add => failed"
      ((ERROR_COUNT++))
    fi

    log_info "Committing => '$COMMIT_MSG'"
    if ! git commit -m "$COMMIT_MSG"; then
      log_info "No changes to commit => skipping commit."
    fi

    log_info "Pushing => origin/$BRANCH"
    if ! git push origin "$BRANCH"; then
      log_warn "Push => failed => might require manual fix."
      ((ERROR_COUNT++))
    fi

    # Evaluate performance
    local loop_end
    loop_end="$(date +%s)"
    local duration=$(( loop_end - loop_start ))
    log_info "Iteration $iteration => finished in ${duration}s with $ERROR_COUNT errors."

    # Basic adaptation (toy example)
    if [[ "$DO_FULL_AGI_PIPE" == "true" ]]; then
      if [[ "$ERROR_COUNT" -gt 0 ]]; then
        log_warn "Errors encountered => next iteration might re-run AI or doc steps to fix issues."
      elif [[ "$duration" -gt 60 ]]; then
        log_warn "Pipeline took > 60s => next iteration might re-run doc or AI for optimization."
      fi
      # A real system would store these toggles and forcibly re-run or tweak configs next time.
    fi

    log_info "Iteration $iteration done => waiting $LOOP_WAIT_TIME seconds before next iteration."
    sleep "$LOOP_WAIT_TIME"

    iteration=$(( iteration + 1 ))
  done

  log_info "AGI Baby Autoloop => completed after $MAX_ITERATIONS iterations."

  cat << 'EOF_ASCII'
  ____  _  _     ____                        _
 / ___|| || |   / ___| _   _ _ __ __ _  __ _| | ___
 \___ \| || |_  \___ \| | | | '__/ _` |/ _` | |/ _ \
  ___) |__   _|  ___) | |_| | | | (_| | (_| | |  __/
 |____/   |_|  |____/ \__,_|_|  \__,_|\__, |_|\___|
                                       |___/
EOF_ASCII

  if [[ "$DO_FULL_AGI_PIPE" == "true" ]]; then
    echo "[BINARY => AGI BABY ENABLED] => Autoloop completed."
  else
    echo "[BINARY => AGI BABY DISABLED] => Partial pipeline autoloop completed."
  fi
  echo "Have a nice day!"
}

main_autoloop

###############################################################################
# END NOTES:
# 1. This remains a toy example for demonstration; real "AGI" logic requires
#    advanced AI/ML plus robust guardrails.
# 2. Secrets, conflict resolution, advanced concurrency checks, and real code
#    refactoring/analysis are placeholders or simplistic here.
# 3. Always test carefully in non-production environments!
###############################################################################
