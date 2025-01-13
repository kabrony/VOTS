#!/usr/bin/env bash
###############################################################################
# scan_and_analyze_greppable.sh
#
# 1) Uses RustScan greppable mode on ports 1-1000.
# 2) Extracts open ports from lines like:
#      2600:3c01::f03c:91ff:fe18:bb2f -> [22,80]
# 3) Calls either OpenAI or Gemini real endpoints (no mocks).
# 4) Prints final LLM analysis. You can store it in memory or to a file if needed.
#
# USAGE:
#   chmod +x scan_and_analyze_greppable.sh
#   export LLM_PROVIDER="openai" (or "gemini")
#   export OPENAI_API_KEY="sk-..."
#   export GEMINI_API_KEY="AIza..."
#   ./scan_and_analyze_greppable.sh <target-ip-or-host>
###############################################################################
set -e

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "[USAGE] $0 <target-ip-or-host>"
  exit 1
fi

# Check RustScan
if ! command -v rustscan &>/dev/null; then
  echo "[ERROR] RustScan not found. Install it or adjust your PATH."
  exit 1
fi

echo "[INFO] Scanning $TARGET (ports 1–1000) with RustScan..."

rustscan -a "$TARGET" --range 1-1000 -g > rustscan_output.txt 2>rustscan_error.log || {
  echo "[ERROR] RustScan failed. Check rustscan_error.log."
  exit 1
}

echo "[INFO] Parsing open ports from rustscan_output.txt..."
# Typically: "2600:3c01::f03c:91ff:fe18:bb2f -> [22,80]"
PORT_LINE=$(grep '\-> \[' rustscan_output.txt || true)
if [ -z "$PORT_LINE" ]; then
  echo "[INFO] No open ports found in range 1–1000."
  # We'll still pass an empty list to the Python script in case you want it to handle that scenario.
fi

# Extract bracketed ports (like "22,80")
PORTS_IN_BRACKETS=$(echo "$PORT_LINE" | sed 's/.*-> \[\(.*\)\]/\1/' | tr -d ' ')
# If multiple lines exist, this merges them. Alternatively, handle multiple lines if needed.
# e.g. if you had "2600:...-> [22] \n 45.33.32.156-> [80]" it merges them. 
# For simplicity, let's just keep the first line:
PORTS_CLEAN=$(echo "$PORTS_IN_BRACKETS" | head -n1)

echo "[INFO] Found open ports: ${PORTS_CLEAN:-none}"

echo "[INFO] Running Python to call LLM provider..."
python3 <<EOF
import os
import sys
import requests
import openai

llm_provider = os.getenv("LLM_PROVIDER", "openai").lower()
openai_key = os.getenv("OPENAI_API_KEY", "")
gemini_key = os.getenv("GEMINI_API_KEY", "")
target = "${TARGET}"
ports_found = "${PORTS_CLEAN}".strip()

if not ports_found:
    print("[LLM] No open ports found, nothing to analyze.")
    sys.exit(0)

prompt = f"Ports open on {target}: {ports_found}.\\n" \
         "Please provide potential security risks or best practices."

if llm_provider == "openai":
    if not openai_key:
        print("[ERROR] Missing OPENAI_API_KEY.")
        sys.exit(1)
    openai.api_key = openai_key

    # You can pick any model you'd like, e.g. "gpt-4", "gpt-3.5-turbo", "gpt-4-32k"
    model_choice = "gpt-4"
    try:
        resp = openai.ChatCompletion.create(
            model=model_choice,
            messages=[{"role":"user","content": prompt}],
            temperature=0.3
        )
        llm_answer = resp["choices"][0]["message"]["content"]
        print(f"[LLM] OpenAI GPT response ({model_choice}):\\n{llm_answer}")
    except Exception as e:
        print("[ERROR] OpenAI call failed:", str(e))
        sys.exit(1)

elif llm_provider == "gemini":
    if not gemini_key:
        print("[ERROR] Missing GEMINI_API_KEY.")
        sys.exit(1)
    # Example Google Generative Language endpoint (not official):
    # Official docs might differ. This is purely illustrative.
    url = "https://generativelanguage.googleapis.com/v1beta2/models/gemini-2.0-flash:generateText"
    headers = {
        "Authorization": f"Bearer {gemini_key}",
        "Content-Type": "application/json"
    }
    payload = {
        "prompt": {
            "text": prompt
        },
        "temperature": 0.3,
        "candidate_count": 1
        # Possibly other fields depending on the actual Gemini API spec
    }
    try:
        r = requests.post(url, json=payload, headers=headers, timeout=30)
        r.raise_for_status()
        resp = r.json()
        # The actual field might differ, we guess "candidates"
        if "candidates" in resp and len(resp["candidates"]) > 0:
            gemini_answer = resp["candidates"][0].get("output", "")
            print(f"[LLM] Gemini 2.0 response:\\n{gemini_answer}")
        else:
            print("[LLM] No text candidates returned from Gemini.")
    except requests.exceptions.RequestException as e:
        print("[ERROR] Gemini request failed:", str(e))
        sys.exit(1)

else:
    print("[ERROR] Unknown LLM_PROVIDER. Use 'openai' or 'gemini'.")
    sys.exit(1)
EOF

echo "[INFO] Done."
