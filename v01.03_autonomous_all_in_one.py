#!/usr/bin/env python3
"""
v01.03_autonomous_all_in_one.py
==============================================================================
An advanced, continuous script that:

- Loads environment variables for port assignments (RUST_PORT, GO_PORT, etc.)
- Manages Docker Compose services and checks container health
- Integrates GPT-4 (OpenAI) + Gemini for synergy-based AI improvements
- Optionally performs autonomous code refactoring (via patch)
- Performs basic finance checks for organix.eth
- Offers a minimal Flask + Socket.IO interface for external triggers
- Includes colored logs and enhanced ASCII art

Requires:
  - Python 3.8+
  - pip install -r requirements.txt
  - 'patch' utility installed on the OS
  - .env file with environment variables

Usage:
  python v01.03_autonomous_all_in_one.py

Disclaimer:
  - Automated refactoring can break code if the AI suggestions are invalid.
  - No actual financial transactions are performed, only AI-based analysis.
  - Thoroughly test in a safe environment; do not run on prod blindly.
==============================================================================
"""

import os
import sys
import time
import json
import subprocess
import requests
import socketio
import traceback
import threading
from flask import Flask, request
from dotenv import load_dotenv

# AI & LLM
import openai
import google.generativeai as genai

# Google searching
from googlesearch import search as google_search

# Crypto / Finance
from web3 import Web3, HTTPProvider

###############################################################################
# 1) Load Environment
###############################################################################
load_dotenv(dotenv_path='.env')

# Basic Ports (from your snippet; often Docker Compose uses them, but we can read them)
RUST_PORT = os.getenv("RUST_PORT", "3500")
GO_PORT = os.getenv("GO_PORT", "4000")
C_PORT = os.getenv("C_PORT", "5000")
GRADIO_PORT = os.getenv("GRADIO_PORT", "8500")
FASTAPI_PORT = os.getenv("FASTAPI_PORT", "9000")
NEXTJS_PORT = os.getenv("NEXTJS_PORT", "3001")

# Docker Compose / AI / Finance
DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
ORGANIX_ETH_WALLET = os.getenv("ORGANIX_ETH_WALLET", "organix.eth")
ETH_RPC = os.getenv("ETH_RPC", "https://eth-mainnet.alchemyapi.io/v2/YOURKEY")

FINANCE_ENABLED = (os.getenv("FINANCE_ENABLED", "true").lower() == "true")
GEMINI_FLASH_ENABLED = (os.getenv("GEMINI_FLASH_ENABLED", "true").lower() == "true")
AUTONOMOUS_REFACTOR = (os.getenv("AUTONOMOUS_REFACTOR", "false").lower() == "true")
AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER = (os.getenv("AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER", "true").lower() == "true")
ETH_BALANCE_THRESHOLD_FOR_AI = float(os.getenv("ETH_BALANCE_THRESHOLD_FOR_AI", "1.0"))
MONITORING_INTERVAL = int(os.getenv("MONITORING_INTERVAL", "60"))

# Initialize OpenAI
if OPENAI_API_KEY:
    openai.api_key = OPENAI_API_KEY
else:
    print("\033[33m[WARN]\033[0m => No OPENAI_API_KEY found. GPT-4 calls disabled.")

# Initialize Gemini
gemini_pro = None
gemini_vision = None
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)
    gemini_pro = genai.GenerativeModel('gemini-pro')
    gemini_vision = genai.GenerativeModel('gemini-pro-vision')
else:
    print("\033[33m[WARN]\033[0m => No GEMINI_API_KEY found. Gemini calls disabled.")

###############################################################################
# 2) ASCII Art
###############################################################################
ASCII_HEADER = r"""
\033[34m
 ██████  ██    ██  ██████   ███    ███  ██████  ███    ██ ██ \033[0m
\033[34m██       ██    ██ ██    ██ ████  ████ ██    ██ ████   ██ ██ \033[0m
\033[36m██   ███  ██  ██  ██    ██ ██ ████ ██ ██    ██ ██ ██  ██ ██ \033[0m
\033[36m██    ██   ████   ██    ██ ██  ██  ██ ██    ██ ██  ██ ██ ██ \033[0m
\033[35m ██████     ██     ██████  ██      ██  ██████  ██   ████ ██ \033[0m

   \033[35mORGANIX.ETH | AUTONOMOUS SWARM v01.03\033[0m

\033[32m[GPT-4 + Gemini | Ports => Rust:%s, Go:%s, C:%s | Docker + AI + Finance]\033[0m
""" % (RUST_PORT, GO_PORT, C_PORT)

###############################################################################
# 3) Logging Helpers
###############################################################################
def log_info(msg):
    print(f"\033[34m[INFO] [ORGANIX.ETH]\033[0m => {msg}")

def log_warn(msg):
    print(f"\033[33m[WARN] [ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

def log_error(msg):
    print(f"\033[31m[ERROR] [ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

###############################################################################
# 4) Docker Compose Management
###############################################################################
def docker_compose_up():
    try:
        result = subprocess.run(
            ["docker", "compose", "-f", DOCKER_COMPOSE_FILE, "up", "-d"],
            check=True, capture_output=True, text=True
        )
        log_info("Docker Compose => services up.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker compose up error:\n{e.stderr}")

def docker_compose_build():
    try:
        result = subprocess.run(
            ["docker", "compose", "-f", DOCKER_COMPOSE_FILE, "build"],
            check=True, capture_output=True, text=True
        )
        log_info("Docker Compose => build complete.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker compose build error:\n{e.stderr}")

def check_container_health():
    """Periodically check Docker container states; if unhealthy => AI synergy."""
    try:
        cmd = ["docker", "ps", "--format", "{{.Names}} {{.State}}"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = result.stdout.strip().split('\n')

        for line in lines:
            if not line.strip():
                continue
            parts = line.split(None, 1)
            if len(parts) < 2:
                continue
            container_name, state_str = parts
            # If container is unhealthy, dead, or restarting => trigger AI
            if any(x in state_str.lower() for x in ["unhealthy", "dead", "restarting"]):
                log_warn(f"Container '{container_name}' => {state_str}, calling AI synergy.")
                if GEMINI_FLASH_ENABLED:
                    gemini_flash_intelligence(f"Container '{container_name}' => {state_str}")
    except subprocess.CalledProcessError as e:
        log_error(f"Error checking Docker containers => {e.stderr}")

###############################################################################
# 5) Gemini + GPT-4 Synergy
###############################################################################
def gemini_flash_intelligence(context_str):
    """Calls Google, GPT-4, and Gemini to propose improvements; may refactor code."""
    log_info(f"[GeminiFlash] AI synergy => {context_str}")

    google_results = get_google_results(context_str)
    openai_msg = get_openai_response(context_str, google_results)
    gemini_msg = get_gemini_response(context_str, google_results)

    synergy_response = ""
    if openai_msg:
        synergy_response += f"\n[GPT-4 SAYS]\n{openai_msg}\n"
    if gemini_msg:
        synergy_response += f"\n[GEMINI PRO SAYS]\n{gemini_msg}\n"

    if synergy_response.strip():
        log_info(f"[GeminiFlash] Combined synergy =>\n{synergy_response}")
        # If refactoring is allowed and AI suggests code changes
        if AUTONOMOUS_REFACTOR and ("refactor" in synergy_response.lower() or "code change" in synergy_response.lower()):
            log_info("[GeminiFlash] Attempting autonomous refactoring from synergy.")
            trigger_code_refactoring(synergy_response)
    else:
        log_info("[GeminiFlash] No actionable synergy from AI models.")

def get_google_results(query):
    try:
        return list(search(query, tld="com", num=3, stop=3, pause=2))
    except Exception as e:
        log_warn(f"Googlesearch error => {e}")
        return []

def get_openai_response(context, google_results):
    if not OPENAI_API_KEY:
        return None
    prompt = f"""
Context: {context}
Google results: {json.dumps(google_results, indent=2)}
Propose actions or improvements for ORGANIX.ETH system.
"""
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"You are an advanced AI for ORGANIX.ETH."},
                      {"role":"user","content": prompt}],
            temperature=0.3
        )
        return resp["choices"][0]["message"]["content"]
    except Exception as e:
        log_warn(f"OpenAI GPT-4 error => {e}")
    return None

def get_gemini_response(context, google_results):
    if not gemini_pro:
        return None
    prompt = f"GeminiPro: context {context}, google results: {json.dumps(google_results, indent=2)}. Suggest improvements."
    try:
        result = gemini_pro.generate_content(prompt)
        return result.text
    except Exception as e:
        log_warn(f"Gemini Pro error => {e}")
    return None

###############################################################################
# 6) Autonomous Refactor Logic
###############################################################################
def trigger_code_refactoring(ai_text):
    """
    Looks for pattern like "refactor service 'XYZ'"
    Then performs an autonomous patch-based refactoring if found.
    """
    log_info("[Refactor] Searching synergy text for 'refactor service ...' pattern.")
    import re
    pattern = r"refactor service\s*'([^']+)'"
    match = re.search(pattern, ai_text, re.IGNORECASE)
    if match:
        service_name = match.group(1).strip()
        refactor_service_autonomously(service_name, ai_text)
    else:
        log_warn("[Refactor] No recognized 'refactor service' directive in synergy text.")

def refactor_service_autonomously(service_name, instructions):
    log_info(f"[Refactor] Autonomous refactor => {service_name}")
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"[Refactor] Service directory not found => {service_dir}")
        return

    code_str = gather_service_code(service_dir)
    if not code_str.strip():
        log_warn("[Refactor] No code found in service => Aborting.")
        return

    if not OPENAI_API_KEY:
        log_warn("[Refactor] No OPENAI_API_KEY => can't do GPT-4 refactoring.")
        return

    prompt = f"""You are GPT-4, focusing on code refactoring for ORGANIX.ETH. 
Service: {service_name}
Service code:
{code_str}
AI synergy instructions:
{instructions}
Return a unified diff patch to improve reliability/performance.
"""
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"Refactoring specialist for ORGANIX.ETH."},
                      {"role":"user","content":prompt}],
            temperature=0.4
        )
        diff_str = resp["choices"][0]["message"]["content"]
        apply_diff(service_dir, diff_str)
    except Exception as e:
        log_warn(f"[Refactor] GPT-4 refactoring error => {e}")

def gather_service_code(service_dir):
    code_accum = ""
    for root, dirs, files in os.walk(service_dir):
        for fn in files:
            # You can add more file extensions if needed
            if fn.endswith((".py", ".rs", ".c", ".go", ".js")):
                path = os.path.join(root, fn)
                try:
                    with open(path, "r", encoding="utf-8", errors="replace") as f:
                        contents = f.read()
                    code_accum += f"--- FILE: {fn}\n{contents}\n"
                except Exception as e:
                    log_warn(f"Error reading {path}: {e}")
    return code_accum

def apply_diff(base_dir, diff_content):
    """Writes diff to a temp file, performs a dry-run patch, then applies if no errors."""
    import tempfile
    import uuid

    patch_file = f"auto_refactor_{uuid.uuid4().hex}.diff"
    try:
        with open(patch_file, "w", encoding="utf-8") as pf:
            pf.write(diff_content)

        # Dry-run
        dry_run = subprocess.run(
            ["patch", "-p2", "--dry-run", "-i", patch_file],
            cwd=base_dir,
            capture_output=True, text=True
        )
        if dry_run.returncode != 0:
            log_warn(f"[Refactor] Dry-run errors:\n{dry_run.stderr}")
            return

        # Actual patch
        patch_run = subprocess.run(
            ["patch", "-p2", "-i", patch_file],
            cwd=base_dir,
            capture_output=True, text=True
        )
        if patch_run.returncode == 0:
            log_info(f"[Refactor] Patch applied successfully in {base_dir}.")
        else:
            log_warn(f"[Refactor] Patch application failed:\n{patch_run.stderr}")
    except Exception as e:
        log_warn(f"[Refactor] apply_diff error => {e}")
    finally:
        if os.path.exists(patch_file):
            os.unlink(patch_file)

###############################################################################
# 7) Manual Refactor Endpoint
###############################################################################
def direct_refactor_service(service_name):
    """
    Called by webhook or socket.io => writes a .diff file for user application.
    Doesn't apply automatically.
    """
    log_info(f"[Refactor-Manual] => {service_name}")
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"[Refactor-Manual] Service dir not found => {service_dir}")
        return

    code_str = gather_service_code(service_dir)
    if not code_str.strip():
        log_warn("[Refactor-Manual] No code found => aborting.")
        return

    if not OPENAI_API_KEY:
        log_warn("[Refactor-Manual] No OPENAI_API_KEY => skipping GPT-4 calls.")
        return

    prompt = f"""You are GPT-4, focusing on ORGANIX.ETH code refactoring.
Service => {service_name}
Service code:
{code_str}

Generate a unified diff patch to improve reliability/performance. 
The user will manually apply the patch.
"""
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"Refactoring expert for ORGANIX.ETH."},
                      {"role":"user","content":prompt}],
            temperature=0.2
        )
        diff_suggestions = resp["choices"][0]["message"]["content"]
        patch_file = f"{service_name}_patch_organix.diff"
        with open(patch_file,"w", encoding="utf-8") as pf:
            pf.write(diff_suggestions)
        log_info(f"[Refactor-Manual] Patch saved => {patch_file}")
    except Exception as e:
        log_warn(f"[Refactor-Manual] GPT-4 error => {e}")

###############################################################################
# 8) Finance for ORGANIX.ETH
###############################################################################
def manage_finances():
    """Checks ETH balance for organix.eth and triggers AI if below threshold."""
    if not FINANCE_ENABLED:
        log_info("[Finance] Disabled.")
        return

    log_info(f"[Finance] Checking ETH => {ORGANIX_ETH_WALLET}")
    w3 = Web3(HTTPProvider(ETH_RPC))
    if not w3.isConnected():
        log_warn("[Finance] Cannot connect to ETH RPC => skipping.")
        return

    try:
        if ".eth" in ORGANIX_ETH_WALLET.lower():
            address = w3.ens.address(ORGANIX_ETH_WALLET)
        else:
            address = Web3.toChecksumAddress(ORGANIX_ETH_WALLET)
        if not address:
            log_warn("[Finance] ENS resolution or parsing => returned None.")
            return

        bal_wei = w3.eth.get_balance(address)
        bal_eth = w3.fromWei(bal_wei, 'ether')
        log_info(f"[Finance] Current ETH bal => {bal_eth}")

        if AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER and bal_eth < ETH_BALANCE_THRESHOLD_FOR_AI:
            gemini_flash_intelligence(f"Low ETH balance => {bal_eth}, propose suggestions for ORGANIX.ETH.")
    except Exception as e:
        log_warn(f"[Finance] Error => {e}")

###############################################################################
# 9) Socket.IO + Flask Setup
###############################################################################
sio = socketio.Server(async_mode='threading')
app = Flask(__name__)
socketio_app = socketio.WSGIApp(sio, app)

@app.route('/webhook', methods=['POST'])
def webhook_entry():
    data = request.json
    log_info(f"[Webhook] Received => {data}")
    action = data.get("action","")
    if action == "refactor_service":
        svc = data.get("service_name","unknown")
        direct_refactor_service(svc)
    elif action == "trigger_ai":
        context = data.get("context","No context")
        gemini_flash_intelligence(f"Webhook => {context}")
    return {"status":"ok"}

@sio.event
def connect(sid, environ):
    log_info(f"[SocketIO] Client connected => {sid}")
    sio.emit("message", {"info":"Welcome to ORGANIX.ETH auto-swarm!"}, room=sid)

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO] Client disconnected => {sid}")

@sio.on("trigger_ai")
def handle_trigger_ai(sid, data):
    log_info(f"[SocketIO trigger_ai] => {data}")
    ctype = data.get("type","gemini")
    context = data.get("context","(no context)")
    if ctype == "gemini":
        gemini_flash_intelligence(f"Socket => {context}")
    elif ctype == "refactor":
        svc = data.get("service","unknown")
        direct_refactor_service(svc)

###############################################################################
# 10) Main Orchestrator Loop
###############################################################################
def main_loop():
    print(ASCII_HEADER)

    log_info("Starting ORGANIX.ETH Autonomous Orchestrator v01.03 ...")

    # 1) Build/Up Docker
    docker_compose_build()
    docker_compose_up()

    # 2) Optional: start a gevent-based SocketIO server in background
    #    For demonstration, we will skip or comment out
    """
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler

    def run_socketio():
        server = pywsgi.WSGIServer(("0.0.0.0", 5000), socketio_app, handler_class=WebSocketHandler)
        server.serve_forever()

    th_socket = threading.Thread(target=run_socketio, daemon=True)
    th_socket.start()
    """

    # 3) Continuous check for finances & container health
    while True:
        manage_finances()
        check_container_health()
        time.sleep(MONITORING_INTERVAL)

if __name__ == "__main__":
    try:
        main_loop()
    except KeyboardInterrupt:
        log_info("KeyboardInterrupt => shutting down gracefully.")
    except Exception as ex:
        log_error(f"Fatal error => {ex}\n{traceback.format_exc()}")
        sys.exit(1)
