#!/usr/bin/env bash
###############################################################################
# v31_agi_baby_deploy.sh - Minimal Yet Robust "AGI Baby" Deployment Script
#
# Purpose:
#   - Deploy your Docker Compose stack with optional pruning and optional AI steps.
#   - Provide minimal error checks, environment variable toggles, & final summary.
#
# Environment Variables (Optional):
#   DO_FULL_AGI_PIPE=true|false (default: false)
#     -> If "true", runs "scripts/doc_analysis.py" and "scripts/ai_refactor.py" if they exist.
#
#   PRUNE_BEFORE_DEPLOY=true|false (default: false)
#     -> If "true", automatically prunes Docker system before building.
#
# Usage:
#   1) Place this script in the same directory as your docker-compose.yml
#   2) chmod +x v31_agi_baby_deploy.sh
#   3) ./v31_agi_baby_deploy.sh
###############################################################################

set -Eeuo pipefail  # safer bash settings
SCRIPT_NAME="$(basename "$0")"

###############################################################################
# 0) Basic checks for Docker + Docker Compose
###############################################################################
check_prereqs() {
  if ! command -v docker &>/dev/null; then
    echo "[ERROR] Docker is not installed or not in PATH." >&2
    exit 1
  fi
  if ! command -v docker compose &>/dev/null; then
    echo "[ERROR] Docker Compose (v2) is not installed or 'docker compose' not in PATH." >&2
    exit 1
  fi
}

###############################################################################
# 1) Maybe Prune
###############################################################################
maybe_prune() {
  local PRUNE_BEFORE_DEPLOY="${PRUNE_BEFORE_DEPLOY:-false}"
  if [[ "$PRUNE_BEFORE_DEPLOY" == "true" ]]; then
    echo "[INFO] PRUNE_BEFORE_DEPLOY=true -> Pruning stale Docker containers/images/volumes..."
    docker compose down --remove-orphans || true
    docker system prune --all --volumes -f || true
  else
    # optional user prompt if you'd like to confirm
    echo "[INFO] Skipping Docker system prune. (Set PRUNE_BEFORE_DEPLOY=true to auto-prune.)"
  fi
}

###############################################################################
# 2) Build
###############################################################################
build_services() {
  echo "[INFO] Building services with 'docker compose build'..."
  docker compose build
}

###############################################################################
# 3) Up
###############################################################################
start_services() {
  echo "[INFO] Bringing containers up in the background => docker compose up -d"
  docker compose up -d
  echo "[INFO] Current running containers =>"
  docker ps
}

###############################################################################
# 4) Optional "AGI" Steps if DO_FULL_AGI_PIPE=true
###############################################################################
agi_baby_steps() {
  local DO_FULL_AGI_PIPE="${DO_FULL_AGI_PIPE:-false}"
  if [[ "$DO_FULL_AGI_PIPE" == "true" ]]; then
    echo "[INFO] DO_FULL_AGI_PIPE=true => Running optional doc analysis & AI refactor (placeholders)."
    if [[ -f "scripts/doc_analysis.py" ]]; then
      echo "[INFO] => Running doc_analysis.py..."
      python scripts/doc_analysis.py || echo "[WARN] doc_analysis.py encountered issues."
    fi
    if [[ -f "scripts/ai_refactor.py" ]]; then
      echo "[INFO] => Running ai_refactor.py..."
      python scripts/ai_refactor.py || echo "[WARN] ai_refactor.py encountered issues."
    fi
  else
    echo "[INFO] DO_FULL_AGI_PIPE != 'true' => Skipping AI/doc steps."
  fi
}

###############################################################################
# Main
###############################################################################
main() {
  echo "=== [$SCRIPT_NAME] Starting Deployment ==="

  check_prereqs
  maybe_prune
  build_services
  start_services
  agi_baby_steps

  echo "=== [$SCRIPT_NAME] Deployment Complete! ==="
  echo "Containers now running. Use 'docker compose logs -f' or 'docker ps' to check statuses."
}

main "$@"
