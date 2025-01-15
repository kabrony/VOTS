#!/usr/bin/env bash
#
# This script scans all files in the current directory (including hidden ones),
# ignoring certain large or irrelevant folders. It attempts syntax checks for
# Python (.py), C (.c), and Rust (.rs). Log output is saved to full_analysis.log.

LOGFILE="full_analysis.log"
echo "Full Code Analysis started at $(date)" > "$LOGFILE"
echo "Logging results to $LOGFILE ..."
echo "" >> "$LOGFILE"

###############################################################################
# 2) Define a "check_python" function for .py files
###############################################################################
check_python() {
  local pyfile="$1"
  echo " [PYTHON] Checking: $pyfile" >> "$LOGFILE"
  python -m py_compile "$pyfile" 2>> "$LOGFILE"
  if [ $? -eq 0 ]; then
    echo "   -> OK" >> "$LOGFILE"
  else
    echo "   -> ERROR (see log for details)" >> "$LOGFILE"
  fi
}

###############################################################################
# 3) Define a "check_c" function for .c files
###############################################################################
check_c() {
  local cfile="$1"
  echo " [C] Checking: $cfile" >> "$LOGFILE"
  gcc -fsyntax-only "$cfile" 2>> "$LOGFILE"
  if [ $? -eq 0 ]; then
    echo "   -> OK" >> "$LOGFILE"
  else
    echo "   -> ERROR (see log for details)" >> "$LOGFILE"
  fi
}

###############################################################################
# 4) Define a "check_rust" function for .rs files
###############################################################################
check_rust() {
  local rsfile="$1"
  echo " [RUST] Checking: $rsfile" >> "$LOGFILE"
  # Single-file check with rustc; won't produce a full binary
  rustc --edition=2021 --emit=metadata "$rsfile" 2>> "$LOGFILE"
  if [ $? -eq 0 ]; then
    echo "   -> OK" >> "$LOGFILE"
  else
    echo "   -> ERROR (see log for details)" >> "$LOGFILE"
  fi
}

###############################################################################
# 5) Find all files, including hidden, ignoring some big/noisy folders:
#    - ".git" (Git folder)
#    - "node_modules"
#    - ".venv"
#    - etc.
###############################################################################
# We'll parse each file and decide if it's .py, .c, or .rs.
# The "mindepth 1" avoids matching the current dir itself if it's empty.
# The "-path" lines exclude the directories we don't want to traverse.

echo "Gathering files, ignoring .git, node_modules, .venv..." >> "$LOGFILE"

find . \
  -mindepth 1 \
  -type f \
  \( ! -path "*/.git/*" \) \
  \( ! -path "*/node_modules/*" \) \
  \( ! -path "*/.venv/*" \) \
  | while read -r file; do
      # We'll check the extension
      ext="${file##*.}"

      case "$ext" in
        py)
          check_python "$file"
          ;;
        c)
          check_c "$file"
          ;;
        rs)
          check_rust "$file"
          ;;
        *)
          # Not a .py/.c/.rs file, we ignore
          ;;
      esac
    done

echo "" >> "$LOGFILE"
echo "Analysis completed at $(date)" >> "$LOGFILE"
echo "Results are in $LOGFILE"
