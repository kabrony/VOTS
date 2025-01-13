#!/usr/bin/env bash
###############################################################################
# VOTS // DYSTOLABS :: scan_and_analyze.sh
#
# A one-click script to:
#   1) Ensure RustScan is installed (or attempt to install).
#   2) Ensure Python + required packages exist.
#   3) Prompt the user for an IP or host to scan.
#   4) Run RustScan, parse the output in Python, feed to LLM (OpenAI/Gemini).
#   5) Print final analysis to the console.
#
# Place this script in your VOTS folder. Make sure it has +x permissions:
#   chmod +x scan_and_analyze.sh
# Then run:
#   ./scan_and_analyze.sh
#
# Dependencies:
#   - Bash, Python 3.9+ (with 'openai' and/or 'requests' for Gemini)
#   - RustScan either installed system-wide or local
#
###############################################################################

set -Eeuo pipefail
# Explanation of flags:
#  -E  : propagate traps
#  -e  : exit on error
#  -u  : treat unset variables as an error
#  -o pipefail : catch errors in piped commands

# >>> FUNCTIONS <<<

function check_rustscan_installed {
  echo "[INFO] Checking if RustScan is installed..."
  if ! command -v rustscan &>/dev/null; then
    echo "[WARN] RustScan is not installed on this system."
    echo "Do you want to install RustScan via cargo? (y/N)"
    read -r install_rustscan
    if [[ "$install_rustscan" =~ ^[Yy]$ ]]; then
      if command -v cargo &>/dev/null; then
        echo "[INFO] Installing RustScan via cargo install rustscan..."
        cargo install rustscan
      else
        echo "[ERROR] cargo not found. Install cargo (Rust) or install RustScan manually."
        exit 1
      fi
    else
      echo "[ERROR] RustScan not installed, script cannot proceed."
      exit 1
    fi
  else
    echo "[INFO] RustScan is installed."
  fi
}

function check_python_and_packages {
  echo "[INFO] Checking Python and required packages..."
  if ! command -v python3 &>/dev/null; then
    echo "[ERROR] python3 is not found. Please install Python 3.9+."
    exit 1
  fi

  # Optional: create or use a virtual environment
  # e.g. source .venv/bin/activate if you have a local venv
  # For now, we just check globally:

  # We need openai (and possibly requests for Gemini).
  local missing_pkg=()
  
  python3 -c "import openai" &>/dev/null || missing_pkg+=("openai")
  # If you plan to use Gemini via requests or a gemini library, check that too:
  python3 -c "import requests" &>/dev/null || missing_pkg+=("requests")

  if [ ${#missing_pkg[@]} -gt 0 ]; then
    echo "[INFO] Missing Python packages: ${missing_pkg[*]}"
    echo "Do you want to install them via pip? (y/N)"
    read -r install_pkgs
    if [[ "$install_pkgs" =~ ^[Yy]$ ]]; then
      pip3 install "${missing_pkg[@]}"
    else
      echo "[ERROR] Required Python packages not installed. Exiting."
      exit 1
    fi
  fi

  echo "[INFO] Python environment looks good."
}

function create_python_script {
  # This function will create (or overwrite) a small Python script in the same folder
  # that handles the RustScan output => LLM logic.
  # Adjust if you want to keep it in a separate file, or if you already have a robust script.

  cat <<'EOF' > rustscan_llm.py
#!/usr/bin/env python3
"""
rustscan_llm.py
A Python snippet that:
  1) Reads the rustscan output from a file (rustscan_output.json or similar).
  2) Parses it as JSON or raw text.
  3) Feeds it to an LLM (OpenAI or Gemini) for summarization.
  4) Prints the result.

Usage:
  python rustscan_llm.py --file rustscan_output.json [--use-gemini]
"""

import json
import os
import sys
import argparse

import openai
# import requests  # For Gemini or other usage if needed

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

def analyze_openai(parsed_data):
    # Convert parsed_data to a short string
    message_content = f"Here is the RustScan result:\n{parsed_data}\n\n" \
                      f"Please provide a brief summary of open ports and any potential security concerns."

    # ChatCompletion
    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": message_content}],
        temperature=0.3
    )

    return response["choices"][0]["message"]["content"]


def analyze_gemini(parsed_data):
    # Pseudo-code for Gemini usage:
    # url = "https://gemini.googleapis.com/v1/models/gemini-2.0-flash:generateText"
    # headers = {"Authorization": f"Bearer {GEMINI_API_KEY}", "Content-Type": "application/json"}
    # payload = {...}
    # resp = requests.post(url, json=payload, headers=headers)
    # return resp.json()["content"]
    return f"[Gemini mock] Summarizing: {parsed_data}"


def main():
    parser = argparse.ArgumentParser(description="Analyze RustScan JSON output with LLM")
    parser.add_argument("--file", required=True, help="Path to the RustScan output file")
    parser.add_argument("--use-gemini", action="store_true", help="Use Gemini LLM instead of OpenAI")
    args = parser.parse_args()

    if not os.path.isfile(args.file):
        print(f"[ERROR] File not found: {args.file}")
        sys.exit(1)

    # Load the RustScan output
    with open(args.file, "r", encoding="utf-8") as f:
        raw_data = f.read().strip()

    # Attempt to parse JSON
    try:
        parsed_data = json.loads(raw_data)
    except json.JSONDecodeError:
        print("[WARN] Could not parse JSON, using raw text.")
        parsed_data = raw_data

    # Check which LLM
    if args.use_gemini:
        if not GEMINI_API_KEY:
            print("[ERROR] Missing environment variable GEMINI_API_KEY.")
            sys.exit(1)
        analysis = analyze_gemini(parsed_data)
    else:
        if not OPENAI_API_KEY:
            print("[ERROR] Missing environment variable OPENAI_API_KEY.")
            sys.exit(1)
        analysis = analyze_openai(parsed_data)

    print("=== LLM ANALYSIS RESULT ===")
    print(analysis)

if __name__ == "__main__":
    main()
EOF

  chmod +x rustscan_llm.py
  echo "[INFO] Created/updated python script: rustscan_llm.py"
}

# >>> MAIN SCRIPT LOGIC <<<

echo "=== VOTS // DYSTOLABS :: scan_and_analyze.sh ==="

# Step 1: Check RustScan
check_rustscan_installed

# Step 2: Check Python & packages
check_python_and_packages

# Step 3: Create or update the Python LLM script
create_python_script

# Step 4: Prompt for target host/IP
echo -n "Enter the target IP or hostname to scan (e.g. 127.0.0.1): "
read -r TARGET
if [ -z "$TARGET" ]; then
  echo "[ERROR] No target provided."
  exit 1
fi

# Step 5: Run RustScan
echo "[STEP] Running RustScan on $TARGET..."
# We'll output JSON for the python script to parse
# Adjust flags/timeouts as needed:
if rustscan -a "$TARGET" --range 1-65535 --timeout 200 --tries 1 --batch-size 1500 --format json -- -sV \
   > rustscan_output.json 2>rustscan_error.log; then
  echo "[INFO] RustScan completed successfully. Output -> rustscan_output.json"
else
  echo "[ERROR] RustScan failed. Check rustscan_error.log"
  exit 1
fi

# Step 6: Ask if user wants to use Gemini or OpenAI
echo "Use Gemini LLM instead of OpenAI? (y/N)"
read -r use_gemini
LLM_FLAG=""
if [[ "$use_gemini" =~ ^[Yy]$ ]]; then
  LLM_FLAG="--use-gemini"
fi

# Step 7: Run Python script
echo "[STEP] Running python script to feed RustScan output to LLM..."
python3 rustscan_llm.py --file rustscan_output.json $LLM_FLAG

echo "=== DONE! ==="
echo "If you'd like to re-run the analysis or try a different LLM, just run the python script again with the desired flags."
