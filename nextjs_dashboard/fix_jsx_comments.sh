#!/usr/bin/env bash
# fix_jsx_comments.sh
#
# A quick script to address "react/jsx-no-comment-textnodes" by converting
# HTML-style comments <!-- comment --> to JSX style {/* comment */} in app/page.tsx.
#
# If multiple lines or edge cases exist, a manual fix may still be needed.

set -e

TARGET_FILE="app/page.tsx"

if [ ! -f "$TARGET_FILE" ]; then
  echo "[ERROR] $TARGET_FILE not found. Make sure you're in the correct directory."
  exit 1
fi

timestamp=$(date +%Y%m%d_%H%M%S)
backup_file="app/page_backup_${timestamp}.tsx"

echo "[INFO] Creating backup: $backup_file"
cp "$TARGET_FILE" "$backup_file"

echo "[INFO] Attempting to replace <!-- comment --> lines with {/* comment */}..."
# The following sed command searches for something like: <!-- ... -->
# Then captures the contents between, and rewrites it as {/* ... */}
# This is a best-effort approach for single-line comments.
#
# Explanation of the regex:
#   - Find a literal '<!--'
#   - Capture everything (non-greedy) up to '-->'
#   - Then replace with '{/*...*/}'
#
# If your comment has multiple dashes or is multi-line, you might need manual adjustments.
sed -i.bak \
  's/<!--\([^>]*\)-->/{\/* \1 *\/}/g' \
  "$TARGET_FILE"

rm -f "$TARGET_FILE.bak"

echo "[INFO] Done. Updated $TARGET_FILE"
echo "[INFO] Original file backed up at $backup_file"
