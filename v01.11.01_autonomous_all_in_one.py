#!/usr/bin/env python3
"""
v01.11.01_autonomous_all_in_one.py
===============================================================================
Fully autonomous script for managing Docker microservices with AI synergy,
finances for organix.eth, code refactoring, Next.js dashboard synergy, and an
improved solution for the Web3 'isConnected()' issue. Also includes fallback
Socket.IO port logic if 5000 is in use. TAVILY_API_KEY usage is shown as a
placeholder for synergy (if you want to integrate Tavily or additional LLM logic).

Features:
  • GPT-4 + Gemini synergy for container health & code improvements
  • Docker Compose build + up
  • Autonomous refactoring if AI suggests it
  • organix.eth finance check + synergy
  • Socket.IO server fallback from 5000 -> 5050
  • TAVILY_API_KEY placeholders for future expansions
  • Self-fix approach to patches
  • Summarily: "No mistakes," we handle each step robustly

Usage:
  1) python v01.11.01_autonomous_all_in_one.py
  2) Provide .env with:
       OPENAI_API_KEY, GOOGLE_API_KEY, TAVILY_API_KEY, etc.
     Example for TAVILY:
       TAVILY_API_KEY=tvly-...
  3) You must have installed the pinned or flexible `requirements.txt`
  4) Docker Compose and Docker installed
  5) patch installed for code diffs
===============================================================================
"""

import os
import sys
import time
import json
import traceback
import subprocess
import threading
import socket

from flask import Flask, request
import socketio

# Optional google search
try:
    from googlesearch import search as google_search
    HAVE_GOOGLESEARCH = True
except ImportError:
    HAVE_GOOGLESEARCH = False

# AI
import openai
import google.generativeai as genai

# Web3
from web3 import Web3, HTTPProvider

# Dotenv for environment
from dotenv import load_dotenv

load_dotenv(".env")

###############################################################################
# 1) Environment Config
###############################################################################
DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "")  # placeholder if you want synergy

ORGANIXX_ETH_WALLET = os.getenv("ORGANIXX_ETH_WALLET", "organix.eth")
ETH_RPC = os.getenv("ETH_RPC", "https://eth-mainnet.alchemyapi.io/v2/YOURKEY")
FINANCE_ENABLED = (os.getenv("FINANCE_ENABLED", "true").lower() == "true")

GEMINI_FLASH_ENABLED = (os.getenv("GEMINI_FLASH_ENABLED", "true").lower() == "true")

MONITORING_INTERVAL = int(os.getenv("MONITORING_INTERVAL", "60"))

AUTONOMOUS_REFACTOR = (os.getenv("AUTONOMOUS_REFACTOR", "false").lower() == "true")
AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER = (os.getenv("AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER", "true").lower() == "true")
ETH_BALANCE_THRESHOLD_FOR_AI = float(os.getenv("ETH_BALANCE_THRESHOLD_FOR_AI", "1.0"))

###############################################################################
# 2) ASCII Banner
###############################################################################
ASCII_BANNER = r"""
\033[34m
 ██████  ██    ██  ██████   ███    ███  ██████  ███    ██ ██ 
\033[34m██       ██    ██ ██    ██ ████  ████ ██    ██ ████   ██ ██ 
\033[36m██   ███  ██  ██  ██    ██ ██ ████ ██ ██    ██ ██ ██  ██ ██ 
\033[36m██    ██   ████   ██    ██ ██  ██  ██ ██    ██ ██  ██ ██ ██ 
\033[35m ██████     ██     ██████  ██      ██  ██████  ██   ████ ██ 
\033[35m
 ORGANIX.ETH :: AUTONOMOUS SWARM v01.11.01
\033[32m
 [GPT-4 + GEMINI synergy | Docker Health + Code Refactor | organix.eth Finance]
 [TAVILY_API_KEY placeholders for future synergy]
\033[0m
"""

###############################################################################
# 3) Logging
###############################################################################
def log_info(msg):
    print(f"\033[34m[INFO][ORGANIX.ETH]\033[0m => {msg}")

def log_warn(msg):
    print(f"\033[33m[WARN][ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

def log_error(msg):
    print(f"\033[31m[ERROR][ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

###############################################################################
# 4) AI Setup
###############################################################################
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

if TAVILY_API_KEY:
    # placeholder if you want to do TAvily calls
    log_info(f"TAVILY_API_KEY present => you can integrate TAVILY synergy if needed.")

###############################################################################
# 5) Docker
###############################################################################
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
    cmd = ["docker","ps","--format","{{.Names}} {{.Status}}"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = proc.stdout.strip().split("\n")
        for line in lines:
            if not line.strip():
                continue
            parts = line.split(None,1)
            if len(parts)<2:
                continue
            cname, cstatus = parts[0], parts[1]
            cstat_lower = cstatus.lower()
            # If unhealthy => synergy
            if any(x in cstat_lower for x in ["unhealthy","restarting","dead"]):
                log_warn(f"Container {cname} => {cstatus}, synergy triggered.")
                if GEMINI_FLASH_ENABLED:
                    gemini_flash_intelligence(f"Container {cname} => {cstatus}")
    except subprocess.CalledProcessError as e:
        log_error(f"Check container health => {e}")

###############################################################################
# 6) Synergy: GPT-4 + Gemini
###############################################################################
def gemini_flash_intelligence(context_str):
    log_info(f"[GeminiFlash] => {context_str}")

    # Google
    google_results = []
    if HAVE_GOOGLESEARCH:
        try:
            for r in google_search(context_str, num=2, stop=2, pause=0.5):
                google_results.append(r)
        except Exception as e:
            log_warn(f"google_search error => {e}")
    else:
        log_warn("No googlesearch => skipping Google step.")

    # GPT-4
    gpt_ans = None
    if OPENAI_API_KEY:
        prompt = f"Context: {context_str}\nGoogle: {json.dumps(google_results)}\nRefactor if needed."
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[{"role":"system","content":"Be advanced AI for organix.eth."},
                          {"role":"user","content":prompt}],
                temperature=0.4
            )
            gpt_ans = resp["choices"][0]["message"]["content"]
            log_info("[GPT-4] => " + gpt_ans[:200] + "...")
        except Exception as e:
            log_warn(f"GPT-4 error => {e}")
    else:
        log_warn("[GeminiFlash] No OPENAI_API_KEY => skip GPT-4")

    # Gemini
    gemini_ans = None
    if gemini_pro:
        try:
            gem_prompt = f"Context: {context_str}\nGoogle: {json.dumps(google_results)}"
            gresp = gemini_pro.generate_content(gem_prompt)
            gemini_ans = gresp.text
            log_info("[Gemini] => " + gemini_ans[:200] + "...")
        except Exception as e:
            log_warn(f"Gemini error => {e}")
    else:
        log_warn("[GeminiFlash] No gemini_pro => skip Gemini synergy")

    combined = ""
    if gpt_ans:
        combined += f"[GPT-4 SAYS]\n{gpt_ans}\n"
    if gemini_ans:
        combined += f"[GEMINI SAYS]\n{gemini_ans}\n"

    if combined and AUTONOMOUS_REFACTOR and "refactor" in combined.lower():
        trigger_code_refactoring(combined)

###############################################################################
# 7) Code Refactor
###############################################################################
def trigger_code_refactoring(ai_text):
    import re
    pat = re.compile(r"refactor service\s+(\w+)", re.IGNORECASE)
    m = pat.search(ai_text)
    if m:
        svc = m.group(1)
        direct_refactor_service(svc)
    else:
        log_warn("[Refactor] AI said 'refactor' but no 'service' found.")

def direct_refactor_service(service_name):
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"[Refactor] No directory => {service_dir}")
        return
    if not OPENAI_API_KEY:
        log_warn("[Refactor] No OPENAI_API_KEY => skipping GPT-4 patch.")
        return

    # gather code
    code_str = ""
    for root, dirs, files in os.walk(service_dir):
        for fn in files:
            if fn.endswith((".py",".rs",".c",".go",".js")):
                with open(os.path.join(root, fn),"r") as f:
                    contents = f.read()
                code_str += f"--- FILE: {fn}\n{contents}\n"
    if not code_str.strip():
        log_warn("[Refactor] No recognized code => abort.")
        return

    prompt = f"""You are GPT-4, code refactor for organix.eth's microservice '{service_name}':

CODE:
{code_str}

Output a unified diff patch for improvements:
"""

    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"Refactoring specialist."},
                      {"role":"user","content":prompt}],
            temperature=0.3
        )
        patch_text = resp["choices"][0]["message"]["content"]
        apply_patch(service_dir, patch_text)
    except Exception as e:
        log_warn(f"[Refactor] error => {e}")

def apply_patch(base_dir, patch_text):
    import tempfile
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(mode='w',suffix='.diff',delete=False) as tf:
            tf.write(patch_text)
            tmp = tf.name
        # Try -p1 then -p2
        for pnum in ["1","2"]:
            try:
                # dry-run
                subprocess.run(["patch",f"-p{pnum}","--dry-run","-i",tmp],
                               cwd=base_dir, check=True, capture_output=True)
                # apply
                subprocess.run(["patch",f"-p{pnum}","-i",tmp],
                               cwd=base_dir, check=True)
                log_info(f"[Refactor] Patch success with -p{pnum} in {base_dir}")
                break
            except subprocess.CalledProcessError:
                pass
        else:
            log_warn("[Refactor] Patch failed with -p1/-p2 => manual review needed.")
    finally:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)

###############################################################################
# 8) Finance (organix.eth) - Fix for web3 is_connected
###############################################################################
def manage_finances():
    """Check organix.eth balance. If low => synergy."""
    if not FINANCE_ENABLED:
        return
    w3 = Web3(HTTPProvider(ETH_RPC))

    # In new Web3 versions, 'isConnected()' is 'is_connected()' or you check provider
    # We'll do a robust check
    if w3.provider is None or not w3.is_connected():
        log_warn("[Finance] w3 provider not connected => skip finance.")
        return

    # parse address
    address = None
    if ".eth" in ORGANIXX_ETH_WALLET.lower():
        try:
            # for ens, you might do: w3.ens.setResolver('resolver address') if needed
            address = w3.ens.address(ORGANIXX_ETH_WALLET)
        except:
            pass
    else:
        try:
            address = Web3.toChecksumAddress(ORGANIXX_ETH_WALLET)
        except:
            pass
    if not address:
        log_warn(f"[Finance] Could not parse => {ORGANIXX_ETH_WALLET}")
        return

    try:
        bal_wei = w3.eth.get_balance(address)
        bal_eth = w3.fromWei(bal_wei, 'ether')
        log_info(f"[Finance] organix.eth => {bal_eth} ETH.")
        if AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER and bal_eth < ETH_BALANCE_THRESHOLD_FOR_AI:
            gemini_flash_intelligence(f"Low ETH => {bal_eth}. Need synergy?")
    except Exception as e:
        log_warn(f"[Finance] Error => {e}")

###############################################################################
# 9) Socket.IO + Flask
###############################################################################
sio = socketio.Server(async_mode='threading')
app = Flask(__name__)
sock_app = socketio.WSGIApp(sio, app)

@app.route("/webhook", methods=["POST"])
def handle_webhook():
    data = request.json or {}
    log_info(f"[Webhook] => {data}")
    act = data.get("action","")
    if act=="refactor_service":
        sname = data.get("service_name","unknown")
        direct_refactor_service(sname)
    elif act=="trigger_ai":
        cctx = data.get("context","none")
        gemini_flash_intelligence(cctx)
    return {"status":"ok"}

@sio.event
def connect(sid, environ):
    log_info(f"[SocketIO] client => {sid}")
    sio.emit("welcome",{"msg":"Welcome to organix.eth system!"},room=sid)

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO] disconnected => {sid}")

@sio.on("trigger_ai")
def handle_trigger_ai(sid, data):
    cctx = data.get("context","No context")
    gemini_flash_intelligence(cctx)

###############################################################################
# 10) Main Orchestrator
###############################################################################
def orchestrator_loop():
    docker_compose_build()
    docker_compose_up()
    while True:
        try:
            manage_finances()
            check_container_health()
            time.sleep(MONITORING_INTERVAL)
        except KeyboardInterrupt:
            log_warn("Orchestrator => Ctrl-C => stop.")
            break
        except Exception as e:
            log_error(f"Main loop error => {e}")
            time.sleep(10)

def find_free_port(prefer=5000, fallback=5050):
    sk = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        sk.bind(("0.0.0.0", prefer))
        sk.close()
        return prefer
    except OSError:
        log_warn(f"Port {prefer} in use => fallback to {fallback}")
        return fallback

def run_socketio_server(port):
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler
    try:
        server = pywsgi.WSGIServer(("0.0.0.0", port), sock_app, handler_class=WebSocketHandler)
        log_info(f"Socket.IO => listening on :{port}")
        server.serve_forever()
    except KeyboardInterrupt:
        log_warn("SocketIO => Ctrl-C => stop.")
    except Exception as ex:
        log_error(f"SocketIO => crash => {ex}")

def main():
    print(ASCII_BANNER)
    log_info("Starting v01.11.01_autonomous_all_in_one for organix.eth ...")

    t = threading.Thread(target=orchestrator_loop, daemon=True)
    t.start()

    s_port = find_free_port(5000,5050)
    run_socketio_server(s_port)

if __name__=="__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_warn("Main => KeyboardInterrupt => exit.")
    except Exception as ex:
        log_error(f"Fatal => {ex}\n{traceback.format_exc()}")
        sys.exit(1)
