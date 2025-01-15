#!/usr/bin/env python3
"""
v01.05_autonomous_all_in_one.py
==========================================================
Autonomous microservice manager for ORGANIX.ETH. 
Features:
  • Docker Compose build/up, continuous health checks
  • GPT-4 + Google Gemini synergy for AI improvement
  • Automated code refactoring (optional)
  • Finance checks for organix.eth (no actual tx in script)
  • Webhook + Socket.IO endpoints for external triggers
  • Flexible dependencies to avoid ResolutionImpossible

Requires:
  - A .env with env vars (OPENAI_API_KEY, GOOGLE_API_KEY, etc.)
  - "requirements.txt" with flexible versions
  - A 'docker-compose.yml' describing your microservices
  - Patch utility installed (for code diffs)

Usage:
  1) pip install -r requirements.txt
  2) python v01.05_autonomous_all_in_one.py
"""

import os
import sys
import time
import json
import traceback
import subprocess
import threading

from flask import Flask, request
import socketio

# Attempt to import googlesearch. If missing, partial functionality only.
try:
    from googlesearch import search as google_search
    HAVE_GOOGLESEARCH = True
except ImportError:
    HAVE_GOOGLESEARCH = False

# AI / LLM
import openai
import google.generativeai as genai

# Web3 for finance checks
from web3 import Web3, HTTPProvider

# .env loader
from dotenv import load_dotenv
load_dotenv('.env')

################################################################
# 1) Environment Vars
################################################################
DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")

ORGANIXX_ETH_WALLET = os.getenv("ORGANIXX_ETH_WALLET", "organix.eth")
ETH_RPC = os.getenv("ETH_RPC", "https://eth-mainnet.alchemyapi.io/v2/YOURKEY")
FINANCE_ENABLED = (os.getenv("FINANCE_ENABLED", "true").lower() == "true")

GEMINI_FLASH_ENABLED = (os.getenv("GEMINI_FLASH_ENABLED", "true").lower() == "true")

MONITORING_INTERVAL = int(os.getenv("MONITORING_INTERVAL", "60"))

AUTONOMOUS_REFACTOR = (os.getenv("AUTONOMOUS_REFACTOR", "false").lower() == "true")
AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER = (os.getenv("AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER", "true").lower() == "true")
ETH_BALANCE_THRESHOLD_FOR_AI = float(os.getenv("ETH_BALANCE_THRESHOLD_FOR_AI", "1.0"))

################################################################
# 2) ASCII Banner
################################################################
ASCII_BANNER = r"""
\033[34m
 ██████  ██    ██  ██████   ███    ███  ██████  ███    ██ ██ 
\033[34m██       ██    ██ ██    ██ ████  ████ ██    ██ ████   ██ ██ 
\033[36m██   ███  ██  ██  ██    ██ ██ ████ ██ ██    ██ ██ ██  ██ ██ 
\033[36m██    ██   ████   ██    ██ ██  ██  ██ ██    ██ ██  ██ ██ ██ 
\033[35m ██████     ██     ██████  ██      ██  ██████  ██   ████ ██ 
\033[35m
 ORGANIX.ETH :: AUTONOMOUS SWARM v01.05
\033[32m
 [GPT-4 + GEMINI synergy | Docker Health + Code Refactor | organix.eth Finance]
\033[0m
"""

################################################################
# 3) Logging Helpers
################################################################
def log_info(msg):
    print(f"\033[34m[INFO][ORGANIX.ETH]\033[0m => {msg}")

def log_warn(msg):
    print(f"\033[33m[WARN][ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

def log_error(msg):
    print(f"\033[31m[ERROR][ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

################################################################
# 4) AI Setup
################################################################
if OPENAI_API_KEY:
    openai.api_key = OPENAI_API_KEY
else:
    log_warn("No OPENAI_API_KEY => GPT-4 synergy disabled.")

gemini_pro = None
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    gemini_pro = genai.GenerativeModel("gemini-pro")
else:
    log_warn("No GOOGLE_API_KEY => Gemini synergy disabled.")

################################################################
# 5) Docker Management
################################################################
def docker_compose_build():
    try:
        subprocess.run(["docker","compose","-f",DOCKER_COMPOSE_FILE,"build"], check=True)
        log_info("Docker Compose => build complete.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker compose build error => {e}")

def docker_compose_up():
    try:
        subprocess.run(["docker","compose","-f",DOCKER_COMPOSE_FILE,"up","-d"], check=True)
        log_info("Docker Compose => containers up.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker compose up error => {e}")

def check_container_health():
    """
    Check container statuses; if unhealthy => AI synergy
    """
    cmd = ["docker","ps","--format","{{.Names}} {{.Status}}"]
    try:
        proc = subprocess.run(cmd, check=True, capture_output=True, text=True)
        lines = proc.stdout.strip().split("\n")
        for line in lines:
            if not line.strip():
                continue
            parts = line.split(None,1)
            if len(parts) < 2: 
                continue
            cont_name, cstatus = parts[0], parts[1]
            cstat_lower = cstatus.lower()
            if any(x in cstat_lower for x in ["unhealthy","restarting","dead"]):
                log_warn(f"Container {cont_name} => {cstatus}, triggering synergy.")
                if GEMINI_FLASH_ENABLED:
                    gemini_flash_intelligence(f"Container {cont_name} is {cstatus}, possible fix needed.")
    except subprocess.CalledProcessError as e:
        log_error(f"Check container health error => {e}")

################################################################
# 6) Gemini + GPT-4 Synergy
################################################################
def gemini_flash_intelligence(context_str):
    """
    1) Google search (if available)
    2) GPT-4
    3) Gemini Pro
    4) Possibly triggers code refactor
    """
    log_info(f"[GeminiFlash] synergy for => {context_str}")

    # Google
    google_results = []
    if HAVE_GOOGLESEARCH:
        try:
            for r in google_search(context_str, num=2, stop=2, pause=0.5):
                google_results.append(r)
        except Exception as e:
            log_warn(f"googlesearch error => {e}")
    else:
        log_warn("No googlesearch => skipping Google step.")

    # GPT-4
    gpt_answer = None
    if OPENAI_API_KEY:
        prompt = f"""Context: {context_str}
Google: {json.dumps(google_results)}

Suggest improvements or code refactor if needed.
"""
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[{"role":"system","content":"Act as advanced AI for organix.eth."},
                          {"role":"user","content":prompt}],
                temperature=0.4
            )
            gpt_answer = resp["choices"][0]["message"]["content"]
            log_info("[GPT-4] => " + gpt_answer[:200] + "...")
        except Exception as e:
            log_warn(f"GPT-4 error => {e}")
    else:
        log_warn("No OPENAI_API_KEY => skipping GPT-4 synergy.")

    # Gemini
    gemini_answer = None
    if gemini_pro:
        gem_prompt = f"""Context: {context_str}
Google: {json.dumps(google_results)}

Offer any recommended steps or code changes.
"""
        try:
            gresp = gemini_pro.generate_content(gem_prompt)
            gemini_answer = gresp.text
            log_info("[Gemini] => " + gemini_answer[:200] + "...")
        except Exception as e:
            log_warn(f"Gemini error => {e}")

    combined = ""
    if gpt_answer:  combined += f"[GPT-4 SAYS]\n{gpt_answer}\n"
    if gemini_answer: combined += f"[GEMINI SAYS]\n{gemini_answer}\n"

    if combined.strip():
        # If "refactor" found => attempt
        if AUTONOMOUS_REFACTOR and "refactor" in combined.lower():
            trigger_code_refactoring(combined)
    else:
        log_info("[GeminiFlash] synergy => no actionable content.")

################################################################
# 7) Code Refactoring
################################################################
def trigger_code_refactoring(ai_text):
    """Looks for 'refactor service X' in the AI text and calls direct_refactor_service."""
    import re
    pat = re.compile(r"refactor service\s+(\w+)", re.IGNORECASE)
    match = pat.search(ai_text)
    if match:
        svc = match.group(1)
        direct_refactor_service(svc)
    else:
        log_warn("[Refactor] AI mentioned 'refactor' but no explicit service name found.")

def direct_refactor_service(service_name):
    """
    Gathers code from services/{service_name}, prompts GPT-4 for a patch,
    and attempts to apply it.
    """
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"[Refactor] No service dir => {service_dir}")
        return
    if not OPENAI_API_KEY:
        log_warn("[Refactor] No OPENAI_API_KEY => no GPT-4 patch.")
        return

    # Gather code
    code_str = ""
    for root, dirs, files in os.walk(service_dir):
        for fn in files:
            if fn.endswith((".py",".go",".rs",".c",".js")):
                fpath = os.path.join(root, fn)
                with open(fpath,"r") as rf:
                    contents = rf.read()
                code_str += f"--- FILE: {fn}\n{contents}\n"
    if not code_str.strip():
        log_warn("[Refactor] No recognized code in service => abort.")
        return

    prompt = f"""You are GPT-4. The user wants to refactor code for microservice '{service_name}':

Code:
{code_str}

Output a unified diff patch that improves reliability/performance with minimal changes.
"""
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"Refactoring specialist for organix.eth."},
                      {"role":"user","content":prompt}],
            temperature=0.3
        )
        patch_text = resp["choices"][0]["message"]["content"]
        apply_patch(service_dir, patch_text)
    except Exception as e:
        log_warn(f"[Refactor] GPT-4 error => {e}")

def apply_patch(base_dir, patch_text):
    import tempfile
    pfile = None
    try:
        import subprocess
        with tempfile.NamedTemporaryFile(mode='w', suffix='.diff', delete=False) as tf:
            tf.write(patch_text)
            pfile = tf.name
        # Try -p1 then -p2
        for pnum in ["1","2"]:
            try:
                # dry-run
                subprocess.run(["patch",f"-p{pnum}","--dry-run","-i",pfile],
                               cwd=base_dir, check=True, capture_output=True)
                # apply for real
                subprocess.run(["patch",f"-p{pnum}","-i",pfile],
                               cwd=base_dir, check=True)
                log_info(f"[Refactor] Patch applied successfully with -p{pnum} in {base_dir}")
                break
            except subprocess.CalledProcessError as e:
                # Try the next pnum
                pass
        else:
            log_warn("[Refactor] Patch failed with both -p1 and -p2. Manual review recommended.")
    finally:
        if pfile and os.path.exists(pfile):
            os.unlink(pfile)

################################################################
# 8) Finance (organix.eth)
################################################################
def manage_finances():
    """If FINANCE_ENABLED => check balance of organix.eth and possibly trigger synergy."""
    if not FINANCE_ENABLED:
        return
    from web3 import Web3, HTTPProvider
    w3 = Web3(HTTPProvider(ETH_RPC))
    if not w3.isConnected():
        log_warn("[Finance] Unable to connect to ETH RPC => skipping.")
        return

    # Resolve address
    address = None
    if ".eth" in ORGANIXX_ETH_WALLET.lower():
        try:
            address = w3.ens.address(ORGANIXX_ETH_WALLET)
        except:
            pass
    else:
        try:
            address = Web3.toChecksumAddress(ORGANIXX_ETH_WALLET)
        except:
            pass
    if not address:
        log_warn(f"[Finance] Could not parse {ORGANIXX_ETH_WALLET} as address or ENS.")
        return

    try:
        bal_wei = w3.eth.get_balance(address)
        bal_eth = w3.fromWei(bal_wei,"ether")
        log_info(f"[Finance] organix.eth => {bal_eth} ETH.")
        # If below threshold => synergy
        if AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER and bal_eth < ETH_BALANCE_THRESHOLD_FOR_AI:
            gemini_flash_intelligence(f"Low ETH balance: {bal_eth} => possible steps?")
    except Exception as e:
        log_warn(f"[Finance] Error checking balance => {e}")

################################################################
# 9) Socket.IO + Flask
################################################################
sio = socketio.Server(async_mode='threading')
app = Flask(__name__)
sock_app = socketio.WSGIApp(sio, app)

@app.route("/webhook", methods=["POST"])
def handle_webhook():
    data = request.json or {}
    log_info(f"[Webhook] => {data}")
    action = data.get("action","")
    if action == "refactor_service":
        svc = data.get("service_name","unknown")
        direct_refactor_service(svc)
    elif action == "trigger_ai":
        ctx = data.get("context","")
        gemini_flash_intelligence(ctx)
    return {"status":"ok"}

@sio.event
def connect(sid, environ):
    log_info(f"[SocketIO] Client connected => {sid}")
    sio.emit("welcome", {"msg":"Welcome to ORGANIX.ETH system."}, room=sid)

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO] Client disconnected => {sid}")

@sio.on("trigger_ai")
def on_trigger_ai(sid, data):
    ctx = data.get("context","No context")
    gemini_flash_intelligence(ctx)

################################################################
# 10) Main
################################################################
def orchestrator_loop():
    # Up + build Docker
    docker_compose_build()
    docker_compose_up()
    # Continuous
    while True:
        try:
            manage_finances()
            check_container_health()
            time.sleep(MONITORING_INTERVAL)
        except KeyboardInterrupt:
            log_warn("Ctrl-C => orchestrator stop.")
            break
        except Exception as e:
            log_error(f"Main loop error => {e}")
            time.sleep(10)

def run_socketio_server():
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler
    server = pywsgi.WSGIServer(("0.0.0.0",5000), sock_app, handler_class=WebSocketHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log_warn("SocketIO => stopping server.")
    except Exception as ex:
        log_error(f"SocketIO server crash => {ex}")

def main():
    print(ASCII_BANNER)
    log_info("Starting v01.05_autonomous_all_in_one for organix.eth ...")

    # Launch orchestrator in background
    t = threading.Thread(target=orchestrator_loop, daemon=True)
    t.start()

    # Run Socket.IO server (blocking)
    run_socketio_server()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_warn("KeyboardInterrupt => exit main.")
    except Exception as ex:
        log_error(f"Fatal => {ex}\n{traceback.format_exc()}")
        sys.exit(1)
