#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# 1) Install code2prompt (via Cargo) if not already installed
#    (Make sure you have Rust & Cargo installed, or skip if you installed manually)
# ------------------------------------------------------------------------------
if ! command -v code2prompt &> /dev/null; then
  echo "[INFO] Installing code2prompt via cargo..."
  cargo install code2prompt
else
  echo "[INFO] code2prompt is already installed."
fi

# ------------------------------------------------------------------------------
# 2) cd into the target code directory you want to analyze
#    Replace /path/to/your/repo with the actual path
# ------------------------------------------------------------------------------
cd /path/to/your/repo || {
  echo "[ERROR] Could not cd to /path/to/your/repo - check path!"
  exit 1
}

# ------------------------------------------------------------------------------
# 3) Run code2prompt with some example flags:
#    - Show token count
#    - Only include certain file types (example: *.py, *.rs)
#    - Exclude any huge or unneeded files (example: *.md)
#    - Use the built-in 'improve-performance' template
# ------------------------------------------------------------------------------
code2prompt . \
  --tokens \
  --include="*.py,*.rs" \
  --exclude="*.md,*.txt" \
  -t "templates/improve-performance.hbs" \
  --output=generated_prompt.md

# ------------------------------------------------------------------------------
# 4) Show summary
# ------------------------------------------------------------------------------
echo "--------------------------------------------------------------------------"
echo "[DONE] The prompt has been saved to generated_prompt.md"
echo "You can open it or copy it into your LLM (e.g. GPT-4, Claude) to analyze."
echo "--------------------------------------------------------------------------"
