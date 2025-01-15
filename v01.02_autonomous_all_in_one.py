#!/usr/bin/env python3
"""
v01.02_autonomous_all_in_one.py
==========================================================
Autonomous management of Docker microservices with AI-driven
refactoring and basic financial insight for ORGANIX.ETH.
Operates continuously with minimal daily human intervention.

Features:
  1) Docker Compose management (up/build)
  2) Continuous container health checks with AI synergy
  3) Gemini + GPT-4 synergy intelligence for proactive improvements
  4) Google Searching for context
  5) Automated LLM-based code refactoring with patch application
  6) Basic finance monitoring for organix.eth
  7) Optional triggers via Webhook & Socket.IO
  8) Enhanced ASCII art and color-coded logs

Operational Mode:
  Designed to run indefinitely, analyzing health and finances,
  then making code changes if allowed (AUTONOMOUS_REFACTOR).

Usage:
  1) pip install -r requirements.txt  (Ensure 'patch' is installed on OS)
  2) Create .env with keys (OPENAI_API_KEY, GOOGLE_API_KEY, ETH_RPC, etc.)
  3) python v01.02_autonomous_all_in_one.py

Disclaimer:
  - This script is for advanced demonstration and experimentation.
  - Automated actions can break systems if not tested thoroughly.
  - Secrets must be managed securely (avoid storing private keys in plaintext).
  - The finance piece only triggers AI analysis, no real transaction logic.
  - Monitor logs extensively, especially if AUTONOMOUS_REFACTOR is enabled.
==========================================================
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
import re
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
# LOAD ENVIRONMENT
###############################################################################
load_dotenv(dotenv_path='.env')

DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")
ORGANIXX_ETH_WALLET = os.getenv("ORGANIXX_ETH_WALLET", "organix.eth")
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
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    gemini_pro = genai.GenerativeModel('gemini-pro')
    gemini_vision = genai.GenerativeModel('gemini-pro-vision')
else:
    print("\033[33m[WARN]\033[0m => No GOOGLE_API_KEY found. Gemini calls disabled.")

###############################################################################
# ASCII ART HEADER
###############################################################################
ASCII_HEADER = r"""
\033[34m
 ██████  ██    ██  ██████   ███    ███  ██████  ███    ██ ██ \033[0m
\033[34m██       ██    ██ ██    ██ ████  ████ ██    ██ ████   ██ ██ \033[0m
\033[36m██   ███  ██  ██  ██    ██ ██ ████ ██ ██    ██ ██ ██  ██ ██ \033[0m
\033[36m██    ██   ████   ██    ██ ██  ██  ██ ██    ██ ██  ██ ██ ██ \033[0m
\033[35m ██████     ██     ██████  ██      ██  ██████  ██   ████ ██ \033[0m

  \033[35mORGANIX.ETH | AUTONOMOUS SWARM v01.02\033[0m

\033[32m[GEMINI FLASH 2.0 + GPT-4 | AUTO-REFACTOR | FINANCE INSIGHT | Socket.IO]\033[0m
"""

###############################################################################
# LOGGING HELPERS
###############################################################################
def log_info(msg):
    print(f"\033[34m[INFO] [ORGANIX.ETH]\033[0m => {msg}")

def log_warn(msg):
    print(f"\033[33m[WARN] [ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

def log_error(msg):
    print(f"\033[31m[ERROR] [ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

###############################################################################
# DOCKER MANAGEMENT
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
    """
    Checks container status and triggers Gemini Flash if unhealthy, restarting, or dead.
    """
    try:
        cmd = ["docker", "ps", "--format", "{{.Names}} {{.State}}"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = result.stdout.strip().split('\n')

        for line in lines:
            line = line.strip()
            if not line:
                continue
            parts = line.split(None, 1)
            if len(parts) < 2:
                continue
            container_name, state_str = parts
            if any(keyword in state_str.lower() for keyword in ["unhealthy", "restarting", "dead"]):
                log_warn(f"Container '{container_name}' => {state_str}, triggering AI synergy.")
                if GEMINI_FLASH_ENABLED:
                    gemini_flash_intelligence(f"Container '{container_name}' is {state_str} => fix or refactor?")
    except subprocess.CalledProcessError as e:
        log_error(f"Error checking Docker containers: {e.stderr}")

###############################################################################
# GEMINI FLASH 2.0 + GPT-4
###############################################################################
def gemini_flash_intelligence(context_str):
    """
    Synergy function that queries both GPT-4 and Gemini Pro, optionally referencing Google results.
    Possibly triggers code refactoring or additional analysis.
    """
    log_info(f"[GeminiFlash] AI synergy for context => {context_str}")

    # Google results
    google_results = get_google_results(context_str)

    # GPT-4
    openai_answer = get_openai_answer(context_str, google_results)

    # Gemini
    gemini_answer = get_gemini_answer(context_str, google_results)

    synergy = ""
    if openai_answer:
        synergy += f"\n[GPT-4 Suggests]:\n{openai_answer}\n"
    if gemini_answer:
        synergy += f"\n[Gemini Pro Suggests]:\n{gemini_answer}\n"

    if synergy.strip():
        log_info(f"[GeminiFlash] Combined AI synergy =>\n{synergy}")
        if AUTONOMOUS_REFACTOR and ("refactor" in synergy.lower() or "code change" in synergy.lower()):
            log_info("[GeminiFlash] AI synergy => Attempting autonomous refactoring.")
            trigger_code_refactoring(synergy)
    else:
        log_info("[GeminiFlash] No actionable synergy from AI models.")

def get_google_results(query):
    try:
        return list(search(query, tld="com", num=3, stop=3, pause=2))
    except Exception as e:
        log_warn(f"Google search error: {e}")
        return []

def get_openai_answer(context, google_results):
    if not OPENAI_API_KEY:
        return None
    prompt = f"Context: {context}\nGoogle results: {json.dumps(google_results, indent=2)}\nPropose next steps or improvements."
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"You are an advanced AI for ORGANIX.ETH."},
                      {"role":"user","content": prompt}],
            temperature=0.3
        )
        return resp["choices"][0]["message"]["content"]
    except Exception as e:
        log_warn(f"OpenAI error: {e}")
        return None

def get_gemini_answer(context, google_results):
    if not gemini_pro:
        return None
    prompt = f"Gemini, context: {context}\nGoogle results: {json.dumps(google_results, indent=2)}\nOffer improvements."
    try:
        response = gemini_pro.generate_content(prompt)
        return response.text
    except Exception as e:
        log_warn(f"Gemini Pro error: {e}")
        return None

###############################################################################
# AUTONOMOUS REFACTOR
###############################################################################
def trigger_code_refactoring(ai_message):
    """
    Parses AI synergy text for "refactor service 'xxx'" or similar, 
    and attempts an autonomous patch-based refactor if recognized.
    """
    log_info("[Refactor] Parsing synergy for service refactor instructions.")
    pattern = r"refactor service\s+'([^']+)'"
    match = re.search(pattern, ai_message, re.IGNORECASE)
    if match:
        svc_name = match.group(1)
        refactor_service_autonomously(svc_name, ai_message)
    else:
        log_warn("[Refactor] No 'refactor service' pattern found in synergy message.")

def refactor_service_autonomously(service_name, instructions):
    log_info(f"[Refactor] Autonomous refactor for service => {service_name}")
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"[Refactor] Service directory not found => {service_dir}")
        return

    code_str = gather_service_code(service_dir)
    if not code_str.strip():
        log_warn(f"[Refactor] No code found for service => {service_name}")
        return

    if not OPENAI_API_KEY:
        log_warn("[Refactor] No OPENAI_API_KEY => cannot call GPT-4.")
        return

    prompt = (
        f"You are a code refactoring AI for ORGANIX.ETH.\n"
        f"Below is the service code. Provide a unified diff patch for improvements.\n\n"
        f"--- Service: {service_name} ---\n"
        f"{code_str}\n\n"
        f"Instructions:\n{instructions}\n"
    )
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"Refactoring specialist for ORGANIX.ETH."},
                      {"role":"user","content": prompt}],
            temperature=0.4
        )
        diff_str = resp["choices"][0]["message"]["content"]
        apply_diff(service_dir, diff_str)
    except Exception as e:
        log_warn(f"[Refactor] GPT-4 error => {e}")

def gather_service_code(service_dir):
    code_str = ""
    for root, _, files in os.walk(service_dir):
        for fn in files:
            if fn.endswith((".py", ".rs", ".c", ".go", ".js")):
                path = os.path.join(root, fn)
                with open(path, "r", encoding="utf-8", errors="replace") as f:
                    content = f.read()
                code_str += f"--- FILE: {fn}\n{content}\n"
    return code_str

def apply_diff(base_dir, diff_content):
    """
    Creates a temporary .diff, runs patch --dry-run, then patch if success.
    """
    import tempfile
    import uuid

    patch_filename = f"auto_refactor_{uuid.uuid4().hex}.diff"
    try:
        with open(patch_filename, "w", encoding="utf-8", errors="replace") as tmpf:
            tmpf.write(diff_content)

        # Dry-run
        dry = subprocess.run(
            ["patch", "-p2", "--dry-run", "-i", patch_filename],
            cwd=base_dir,
            capture_output=True, text=True
        )
        if dry.returncode != 0:
            log_warn(f"[Refactor] Dry-run patch errors:\n{dry.stderr}")
            return

        # Actual patch
        apply = subprocess.run(
            ["patch", "-p2", "-i", patch_filename],
            cwd=base_dir,
            capture_output=True, text=True
        )
        if apply.returncode == 0:
            log_info(f"[Refactor] Successfully applied patch in {base_dir}.")
        else:
            log_warn(f"[Refactor] Patch application failed:\n{apply.stderr}")
    except Exception as e:
        log_warn(f"[Refactor] Error applying diff => {e}")
    finally:
        if os.path.exists(patch_filename):
            os.unlink(patch_filename)

###############################################################################
# MANUAL REFACTOR ENDPOINT
###############################################################################
def direct_refactor_service(service_name):
    """
    Manually triggered refactor -> generates .diff for manual application.
    Does not automatically apply the patch.
    """
    log_info(f"[Refactor-Manual] Trigger for service => {service_name}")
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"[Refactor-Manual] Service dir not found: {service_dir}")
        return

    code_str = gather_service_code(service_dir)
    if not code_str.strip():
        log_warn("[Refactor-Manual] No code found => Aborting.")
        return

    if not OPENAI_API_KEY:
        log_warn("[Refactor-Manual] No OPENAI_API_KEY => skipping GPT-4.")
        return

    prompt = (
        f"You are GPT-4, focusing on code refactoring for ORGANIX.ETH.\n"
        f"Service => {service_name}\n"
        f"Service code:\n{code_str}\n"
        f"Provide a unified diff patch for improvements (reliability/performance)."
    )
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
# FINANCE: ORGANIX.ETH
###############################################################################
def manage_finances():
    """
    Checks organix.eth ETH balance, triggers AI if below threshold 
    (only if AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER = true).
    """
    if not FINANCE_ENABLED:
        log_info("[Finance] Disabled for ORGANIX.ETH.")
        return

    log_info(f"[Finance] Checking ETH balance => {ORGANIXX_ETH_WALLET}")

    w3 = Web3(HTTPProvider(ETH_RPC))
    if not w3.isConnected():
        log_warn("Cannot connect to ETH RPC => skipping finance check.")
        return

    address = None
    try:
        if ".eth" in ORGANIXX_ETH_WALLET.lower():
            address = w3.ens.address(ORGANIXX_ETH_WALLET)
        else:
            address = Web3.toChecksumAddress(ORGANIXX_ETH_WALLET)
    except Exception as e:
        log_warn(f"ENS resolution/parse error => {e}")
        return

    if not address:
        log_warn("Resolved address is None => skipping finance check.")
        return

    try:
        bal_wei = w3.eth.get_balance(address)
        bal_eth = w3.fromWei(bal_wei, 'ether')
        log_info(f"[Finance] organix.eth balance => {bal_eth} ETH.")
        if AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER and bal_eth < ETH_BALANCE_THRESHOLD_FOR_AI:
            gemini_flash_intelligence(f"Low ETH balance: {bal_eth} for ORGANIX.ETH => suggestions?")
    except Exception as e:
        log_warn(f"Error checking ETH balance => {e}")

###############################################################################
# WEBSOCKET / SOCKET.IO
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
    context = data.get("context","No context")
    if ctype == "gemini":
        gemini_flash_intelligence(f"Socket Trigger => {context}")
    elif ctype == "refactor":
        direct_refactor_service(data.get("service","unknown"))

###############################################################################
# MAIN ORCHESTRATOR LOOP
###############################################################################
def main_loop():
    print(ASCII_HEADER)
    log_info("Starting ORGANIX.ETH Autonomous Orchestrator v01.02 ...")

    # Build/Up Docker
    docker_compose_build()
    docker_compose_up()

    # Optionally start a Socket.IO server in a separate thread if you wish
    # For now, we'll do a simple "continuous loop" approach
    # If you want full-time SocketIO, uncomment the below lines:

    """
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler

    def run_socketio():
        server = pywsgi.WSGIServer(("0.0.0.0", 5000), socketio_app, handler_class=WebSocketHandler)
        server.serve_forever()

    th_socket = threading.Thread(target=run_socketio, daemon=True)
    th_socket.start()
    """

    # Continuous loop for finances & container health
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
