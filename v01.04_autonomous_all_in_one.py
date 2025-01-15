#!/usr/bin/env python3
"""
v01.04_autonomous_all_in_one.py
==========================================================
Autonomous management of Docker microservices with AI-driven
refactoring and financial oversight for ORGANIX.ETH, using
OpenAI + Google Generative AI synergy and flexible dependencies.

Features:
  • Docker Compose up/build, container health checks
  • AI synergy using GPT-4 + Gemini
  • Automated code refactoring (optional)
  • Simple finance checks for organix.eth
  • Webhook + Socket.IO for external triggers
  • Minimal pinned dependencies to avoid resolution conflicts

Usage:
  1) pip install -r requirements.txt (with flexible specs)
  2) Create .env with environment variables (OPENAI_API_KEY, GOOGLE_API_KEY, etc.)
  3) python v01.04_autonomous_all_in_one.py
"""

import os
import sys
import time
import json
import subprocess
import threading
import traceback

# Flask + SocketIO
import socketio
from flask import Flask, request

# AI & LLM
import openai
import google.generativeai as genai

# Google searching
try:
    from googlesearch import search as google_search
except ImportError:
    print("[WARN] googlesearch not installed or conflicting. Some features may be limited.")

# Web3 for finance checks
from web3 import Web3, HTTPProvider

# Load env
from dotenv import load_dotenv
load_dotenv(dotenv_path='.env')

################################################################
# 1) Environment Variables + Config
################################################################
DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")

# AI Keys
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")

# organix.eth Info
ORGANIXX_ETH_WALLET = os.getenv("ORGANIXX_ETH_WALLET", "organix.eth")
ETH_RPC = os.getenv("ETH_RPC", "https://eth-mainnet.alchemyapi.io/v2/YOURKEY")
FINANCE_ENABLED = (os.getenv("FINANCE_ENABLED", "true").lower() == "true")

# Additional AI synergy toggles
GEMINI_FLASH_ENABLED = (os.getenv("GEMINI_FLASH_ENABLED", "true").lower() == "true")

# Monitoring
MONITORING_INTERVAL = int(os.getenv("MONITORING_INTERVAL", "60"))

# Autonomous Code Refactoring
AUTONOMOUS_REFACTOR = (os.getenv("AUTONOMOUS_REFACTOR", "false").lower() == "true")

# Finance Analysis
AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER = (os.getenv("AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER", "true").lower() == "true")
ETH_BALANCE_THRESHOLD_FOR_AI = float(os.getenv("ETH_BALANCE_THRESHOLD_FOR_AI", "1.0"))

################################################################
# 2) Setup ASCII Banner
################################################################
ASCII_BANNER = r"""
\033[34m
 ██████  ██    ██  ██████   ███    ███  ██████  ███    ██ ██ 
\033[34m██       ██    ██ ██    ██ ████  ████ ██    ██ ████   ██ ██ 
\033[36m██   ███  ██  ██  ██    ██ ██ ████ ██ ██    ██ ██ ██  ██ ██ 
\033[36m██    ██   ████   ██    ██ ██  ██  ██ ██    ██ ██  ██ ██ ██ 
\033[35m ██████     ██     ██████  ██      ██  ██████  ██   ████ ██ 
\033[35m
 ORGANIX.ETH :: AUTONOMOUS SWARM v01.04
\033[32m
 [GPT-4 + GEMINI 2.0 synergy | Docker Health + Code Refactor | organix.eth Finance]
\033[0m
"""

################################################################
# 3) Logging Helpers
################################################################
def log_info(msg):
    print(f"\033[34m[INFO] [ORGANIX.ETH]\033[0m => {msg}")

def log_warn(msg):
    print(f"\033[33m[WARN] [ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

def log_error(msg):
    print(f"\033[31m[ERROR] [ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

################################################################
# 4) Initialize AI
################################################################
# OpenAI init
if OPENAI_API_KEY:
    openai.api_key = OPENAI_API_KEY
else:
    log_warn("No OPENAI_API_KEY set => GPT-4 calls disabled.")

# Gemini init
gemini_pro = None
gemini_vision = None
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    gemini_pro = genai.GenerativeModel('gemini-pro')
    gemini_vision = genai.GenerativeModel('gemini-pro-vision')
else:
    log_warn("No GOOGLE_API_KEY set => Gemini calls disabled.")

################################################################
# 5) Docker Management
################################################################
def docker_compose_build():
    try:
        subprocess.run(["docker", "compose", "-f", DOCKER_COMPOSE_FILE, "build"],
                       check=True)
        log_info("Docker Compose => build complete.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker compose build error: {e}")

def docker_compose_up():
    try:
        subprocess.run(["docker", "compose", "-f", DOCKER_COMPOSE_FILE, "up", "-d"],
                       check=True)
        log_info("Docker Compose => services up.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker compose up error: {e}")

def check_container_health():
    """
    Checks container statuses; triggers gemini_flash_intelligence if unhealthy.
    """
    cmd = ["docker", "ps", "--format", "{{.Names}} {{.Status}}"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = result.stdout.strip().split('\n')
        for line in lines:
            if not line.strip():
                continue
            cont_name, rest = line.split(None, 1)
            if "unhealthy" in rest.lower() or "restarting" in rest.lower() or "dead" in rest.lower():
                log_warn(f"Container {cont_name} => {rest}. Triggering AI synergy.")
                if GEMINI_FLASH_ENABLED:
                    gemini_flash_intelligence(f"Container {cont_name} is {rest} => possible fix.")
    except subprocess.CalledProcessError as e:
        log_error(f"Error checking container health: {e}")

################################################################
# 6) AI Synergy (GPT-4 + Gemini)
################################################################
def gemini_flash_intelligence(context_str):
    """
    1) Possibly do a google_search
    2) Consult GPT-4
    3) Consult Gemini Pro
    4) Combine suggestions => Possibly trigger code refactor
    """
    log_info(f"[GeminiFlash] AI synergy for context: {context_str}")

    # Google results
    google_results = []
    if 'google_search' in globals():
        try:
            for r in google_search(context_str, num=2, stop=2, pause=1):
                google_results.append(r)
        except Exception as e:
            log_warn(f"Google search error => {e}")
    else:
        log_warn("googlesearch not available => skipping search.")

    # GPT-4
    gpt_answer = None
    if OPENAI_API_KEY:
        prompt = f"""Context: {context_str}
Google results: {json.dumps(google_results)}

Provide analysis and potential solution steps, focusing on reliability or refactoring if needed.
"""
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[{"role":"system","content":"You are an advanced AI for organix.eth."},
                          {"role":"user","content":prompt}],
                temperature=0.3
            )
            gpt_answer = resp["choices"][0]["message"]["content"]
            log_info("[GeminiFlash] GPT-4 => " + gpt_answer[:200] + "...")
        except Exception as e:
            log_warn(f"GPT-4 error => {e}")
    else:
        log_warn("No OPENAI_API_KEY => skipping GPT-4 synergy.")

    # Gemini
    gemini_answer = None
    if gemini_pro:
        gemini_prompt = f"""Context: {context_str}
Google results: {json.dumps(google_results)}

Provide suggestions or improvements (Gemini Pro).
"""
        try:
            gemresp = gemini_pro.generate_content(gemini_prompt)
            gemini_answer = gemresp.text
            log_info("[GeminiFlash] Gemini => " + gemini_answer[:200] + "...")
        except Exception as e:
            log_warn(f"Gemini error => {e}")
    else:
        log_warn("No Gemini => skipping gemini_pro synergy.")

    # Combine
    combined = ""
    if gpt_answer:  combined += f"GPT-4 SAYS:\n{gpt_answer}\n"
    if gemini_answer: combined += f"GEMINI PRO SAYS:\n{gemini_answer}\n"

    if combined.strip():
        # If the synergy suggests refactoring or code fixes
        if AUTONOMOUS_REFACTOR and "refactor" in combined.lower():
            log_info("[GeminiFlash] synergy suggests refactor => trigger_code_refactoring.")
            trigger_code_refactoring(combined)
    else:
        log_info("AI synergy => no actionable insights at this time.")

################################################################
# 7) Code Refactoring
################################################################
def trigger_code_refactoring(ai_message):
    """
    Parse AI message for 'refactor service foo' etc. Then do direct_refactor_service.
    """
    import re
    pat = re.compile(r"refactor service\s+(\w+)", re.IGNORECASE)
    match = pat.search(ai_message)
    if match:
        service_name = match.group(1)
        log_info(f"[Refactor] Found mention of service => {service_name}")
        direct_refactor_service(service_name)
    else:
        log_warn("[Refactor] AI mentioned 'refactor' but no explicit service found.")

def direct_refactor_service(service_name):
    """
    Gather code, get patch from GPT-4, apply if feasible.
    """
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"[Refactor] Service dir not found => {service_dir}")
        return
    if not OPENAI_API_KEY:
        log_warn("[Refactor] No OPENAI_API_KEY => skipping GPT-4 patch generation.")
        return

    # 1) Gather code
    code_str = ""
    for root, dirs, files in os.walk(service_dir):
        for fn in files:
            if fn.endswith((".py", ".go", ".rs", ".c", ".js")):
                full_path = os.path.join(root, fn)
                with open(full_path, "r") as f:
                    code_str += f"--- FILE: {fn}\n{f.read()}\n"

    if not code_str.strip():
        log_warn("[Refactor] No code found in service => skipping.")
        return

    # 2) GPT-4 prompt => get patch
    prompt = f"""You are GPT-4. The user wants to refactor code for the {service_name} microservice:
Here is the code (in multiple files):
{code_str}

Output a unified diff patch to improve reliability/performance, minimal changes:
"""
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"Refactoring specialist for organix.eth"},
                      {"role":"user","content":prompt}],
            temperature=0.2
        )
        patch_text = resp["choices"][0]["message"]["content"]
        apply_patch(service_dir, patch_text)
    except Exception as e:
        log_warn(f"[Refactor] GPT-4 error => {e}")

def apply_patch(service_dir, patch_text):
    """Applies patch to the service_dir if valid."""
    import tempfile
    import subprocess
    with tempfile.NamedTemporaryFile(mode='w', suffix='.diff', delete=False) as tf:
        tf.write(patch_text)
        patch_path = tf.name
    # Attempt to patch with -p1 or -p2 as needed. Let's do -p1 first
    for pnum in ["1", "2"]:
        try:
            subprocess.run(["patch", f"-p{pnum}", "--dry-run", "-i", patch_path],
                           cwd=service_dir, check=True, capture_output=True)
            # If no error => apply for real
            subprocess.run(["patch", f"-p{pnum}", "-i", patch_path],
                           cwd=service_dir, check=True, capture_output=True)
            log_info(f"[Refactor] Successfully applied patch with -p{pnum}.")
            os.unlink(patch_path)
            return
        except subprocess.CalledProcessError as e:
            # Try next p number
            pass
    log_warn("[Refactor] Patch application failed with both -p1 and -p2. Manual review recommended.")
    os.unlink(patch_path)

################################################################
# 8) Finance
################################################################
def manage_finances():
    """If FINANCE_ENABLED, checks organix.eth's ETH balance. Possibly triggers gemini_flash."""
    if not FINANCE_ENABLED:
        return
    w3 = Web3(HTTPProvider(ETH_RPC))
    if not w3.isConnected():
        log_warn("[Finance] Cannot connect to ETH RPC. Skipping.")
        return

    # Resolve address
    addr = None
    if ".eth" in ORGANIXX_ETH_WALLET.lower():
        try:
            addr = w3.ens.address(ORGANIXX_ETH_WALLET)
        except:
            pass
    else:
        try:
            addr = Web3.toChecksumAddress(ORGANIXX_ETH_WALLET)
        except:
            pass

    if not addr:
        log_warn(f"[Finance] Could not parse {ORGANIXX_ETH_WALLET} as address/ENS.")
        return

    try:
        bal_wei = w3.eth.get_balance(addr)
        bal_eth = w3.fromWei(bal_wei,'ether')
        log_info(f"[Finance] organix.eth => {bal_eth} ETH.")
        # Check threshold
        if AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER and bal_eth < ETH_BALANCE_THRESHOLD_FOR_AI:
            # Trigger synergy
            gemini_flash_intelligence(f"Low ETH balance = {bal_eth}. Potential actions?")
    except Exception as e:
        log_warn(f"[Finance] Error checking balance => {e}")

################################################################
# 9) Socket.IO + Flask Setup
################################################################
sio = socketio.Server(async_mode='threading')
app = Flask(__name__)
socketio_app = socketio.WSGIApp(sio, app)

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.json or {}
    log_info(f"[Webhook] => {data}")
    action = data.get("action","")
    if action == "refactor_service":
        svc = data.get("service_name","unknown_svc")
        direct_refactor_service(svc)
    elif action == "trigger_ai":
        ctx = data.get("context","No context")
        gemini_flash_intelligence(ctx)
    return {"status":"ok"}

@sio.event
def connect(sid, environ):
    log_info(f"[SocketIO] Client connected => {sid}")
    sio.emit("welcome", {"msg":"Welcome to organix.eth system."}, room=sid)

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO] Client disconnected => {sid}")

@sio.on("trigger_ai")
def handle_trigger_ai(sid, data):
    ctx = data.get("context","No context")
    gemini_flash_intelligence(ctx)

################################################################
# 10) Main Orchestrator Loop
################################################################
def orchestrator_loop():
    log_info("Launching orchestrator => building + up Docker Compose.")
    docker_compose_build()
    docker_compose_up()

    # Basic loop
    while True:
        try:
            manage_finances()
            check_container_health()
            time.sleep(MONITORING_INTERVAL)
        except KeyboardInterrupt:
            log_warn("Ctrl+C => shutting down orchestrator.")
            break
        except Exception as e:
            log_error(f"Main loop error => {e}\n{traceback.format_exc()}")
            time.sleep(10)

def run_socketio_server():
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler
    server = pywsgi.WSGIServer(("0.0.0.0", 5000), socketio_app, handler_class=WebSocketHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log_warn("SocketIO => stopping on KeyboardInterrupt.")
    except Exception as e:
        log_error(f"SocketIO server error => {e}")

def main():
    print(ASCII_BANNER)

    # 1) Launch orchestrator in background
    th = threading.Thread(target=orchestrator_loop, daemon=True)
    th.start()

    # 2) Run Socket.IO server (blocking)
    run_socketio_server()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_warn("KeyboardInterrupt => main exit.")
    except Exception as ex:
        log_error(f"Fatal error => {ex}\n{traceback.format_exc()}")
        sys.exit(1)
