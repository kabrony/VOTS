#!/usr/bin/env bash
###############################################################################
# Minimal one-script example for RustScan (greppable) + basic parsing
# Usage: 
#   1) chmod +x ./scan_greppable.sh 
#   2) ./scan_greppable.sh <target-host-or-ip>
###############################################################################
set -e

if ! command -v rustscan &>/dev/null; then
  echo "[ERROR] RustScan not found."
  read -rp "Install RustScan via cargo? (y/N): " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    if command -v cargo &>/dev/null; then
      cargo install rustscan
    else
      echo "[FATAL] cargo not installed. Please install cargo or RustScan manually."
      exit 1
    fi
  else
    echo "[ABORT] Cannot proceed without RustScan."
    exit 1
  fi
fi

TARGET="${1:-}"

if [ -z "$TARGET" ]; then
  echo "[USAGE] $0 <target-ip-or-host>"
  exit 1
fi

echo "[INFO] Scanning $TARGET with RustScan (greppable)..."
rustscan -a "$TARGET" \
  --range 1-65535 \
  --timeout 200 \
  --tries 1 \
  --batch-size 1500 \
  -g -- \
  -sV > rustscan_output.txt 2>rustscan_error.log || {
    echo "[ERROR] RustScan failed, see rustscan_error.log."
    exit 1
}

echo "[INFO] Parsing open ports from rustscan_output.txt..."
grep -Eo '^Open [0-9]+' rustscan_output.txt || echo "No open ports found."

echo "[INFO] Done."
