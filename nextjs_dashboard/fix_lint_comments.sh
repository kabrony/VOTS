#!/usr/bin/env bash
set -e

# 1) Clean up old backup files so ESLint doesn't parse them
#    Choose either "rm" or "mv" approach:

echo "[INFO] Searching for page_backup_*.tsx files..."

BACKUP_FILES=$(find ./app -maxdepth 1 -type f -name "page_backup_*.tsx" 2>/dev/null || true)

if [ -z "$BACKUP_FILES" ]; then
  echo "[INFO] No page_backup_*.tsx backups found. Skipping cleanup."
else
  # Option A: Delete them
  # echo "[INFO] Removing backup .tsx files..."
  # rm -f $BACKUP_FILES

  # Option B: Rename them to .bak so lint won't parse them
  # (Less destructive. Adjust as you wish.)
  echo "[INFO] Renaming backups from *.tsx to *.bak..."
  for f in $BACKUP_FILES; do
    mv "$f" "${f%.tsx}.bak"
    echo "    Renamed $f -> ${f%.tsx}.bak"
  done
fi

echo

# 2) Attempt to fix HTML comments in app/page.tsx by converting
#    <!-- comment --> to {/* comment */}
TARGET_FILE="./app/page.tsx"

if [ ! -f "$TARGET_FILE" ]; then
  echo "[ERROR] $TARGET_FILE not found; aborting fix."
  exit 1
fi

echo "[INFO] Creating backup for $TARGET_FILE before replacing..."
BACKUP_NAME="$(dirname "$TARGET_FILE")/page_autofix_$(date +%Y%m%d_%H%M%S).tsx"
cp "$TARGET_FILE" "$BACKUP_NAME"
echo "    Created backup at: $BACKUP_NAME"

echo "[INFO] Replacing all <!-- comment --> style with {/* comment */}..."
# The below sed uses a regex to find:
#    `<!-- ... -->`
# and rewrite it as
#    `{/* ... */}`
#
# Note that multi-line HTML comments or special nested syntax might need more robust solutions.
#
# Also removes trailing space if any before --> to keep it tidy.
sed -i -E 's/<!--(.*)-->/<{\/*\1*\/}>/g' "$TARGET_FILE"

echo "[INFO] Done. Updated $TARGET_FILE with curly-braced comments."
echo

# 3) Optionally ensure .eslintignore excludes any leftover backups
IGNORE_FILE=".eslintignore"
PATTERN="app/page_backup_*.tsx"

if [ -f "$IGNORE_FILE" ]; then
  echo "[INFO] Ensuring $PATTERN is in $IGNORE_FILE..."
  if ! grep -q "^$PATTERN" "$IGNORE_FILE" 2>/dev/null; then
    echo "$PATTERN" >> "$IGNORE_FILE"
    echo "    Added '$PATTERN' to $IGNORE_FILE"
  else
    echo "    Already found '$PATTERN' in $IGNORE_FILE"
  fi
else
  echo "[INFO] No .eslintignore found. (Skipping ignore insertion.)"
fi

echo
echo "[SUCCESS] Lint comment fix + backup rename done."
echo "Now try building again:"
echo "  npm run build"
