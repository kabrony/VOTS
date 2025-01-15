#!/usr/bin/env python3
"""
v01.11.02_autonomous_all_in_one.py
===============================================================================
Comprehensive autonomous script for:
  - Docker microservices (compose build/up)
  - GPT-4 + Gemini synergy (health checks, code refactoring)
  - organix.eth finance checks
  - Fallback Socket.IO from port 5000 to 5050
  - TAVILY_API_KEY placeholders for future expansions

Features:
  - If Docker containers become 'unhealthy', synergy triggers GPT-4/Gemini analysis
  - Automatic code refactoring via GPT-4 "patch" application
  - Check organix.eth using w3.is_connected() (fixing isConnected() issues)
  - TAVILY_API_KEY usage is stubbed
  - Graceful shutdown on ^C

Usage:
  1) pip install -r requirements.txt  (should fix typical websockets + google/genai)
  2) python v01.11.02_autonomous_all_in_one.py
  3) Provide .env with:
       OPENAI_API_KEY, GOOGLE_API_KEY (if you want Gemini synergy),
       TAVILY_API_KEY (if you want expansions), ...
  4) Patch installed system-wide for code diffs.

Careful with autonomous code refactoring in real environments!
===============================================================================
"""

import os
import sys
import time
import json
import socket
import subprocess
import threading
import traceback

from flask import Flask, request
import socketio

# Dotenv (env)
from dotenv import load_dotenv
load_dotenv(".env")

# Attempt google search
try:
    from googlesearch import search as google_search
    HAVE_GOOGLESEARCH = True
except ImportError:
    HAVE_GOOGLESEARCH = False

# AI libs
import openai
import google.generativeai as genai

# Web3 for finance
from web3 import Web3, HTTPProvider


# =============================================================================
# 1) Environment / Config
# =============================================================================
DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY", "")
TAVILY_API_KEY = os.getenv("TAVILY_API_KEY", "")  # placeholder if future synergy

ORGANIXX_ETH_WALLET = os.getenv("ORGANIXX_ETH_WALLET", "organix.eth")
ETH_RPC = os.getenv("ETH_RPC", "https://eth-mainnet.alchemyapi.io/v2/YOURKEY")

FINANCE_ENABLED = (os.getenv("FINANCE_ENABLED", "true").lower() == "true")
GEMINI_FLASH_ENABLED = (os.getenv("GEMINI_FLASH_ENABLED", "true").lower() == "true")
AUTONOMOUS_REFACTOR = (os.getenv("AUTONOMOUS_REFACTOR", "false").lower() == "true")
AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER = (os.getenv("AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER", "true").lower() == "true")
ETH_BALANCE_THRESHOLD_FOR_AI = float(os.getenv("ETH_BALANCE_THRESHOLD_FOR_AI", "1.0"))

MONITORING_INTERVAL = int(os.getenv("MONITORING_INTERVAL", "60"))

# =============================================================================
# 2) ASCII Banner
# =============================================================================
ASCII_BANNER = r"""
\033[34m
 ██████  ██    ██  ██████   ███    ███  ██████  ███    ██ ██ 
\033[34m██       ██    ██ ██    ██ ████  ████ ██    ██ ████   ██ ██ 
\033[36m██   ███  ██  ██  ██    ██ ██ ████ ██ ██    ██ ██ ██  ██ ██ 
\033[36m██    ██   ████   ██    ██ ██  ██  ██ ██    ██ ██  ██ ██ ██ 
\033[35m ██████     ██     ██████  ██      ██  ██████  ██   ████ ██ 
\033[35m
 ORGANIX.ETH :: AUTONOMOUS SWARM v01.11.02
\033[32m
 [GPT-4 + GEMINI synergy | Docker + Code Refactor | organix.eth Finance]
 [TAVILY_API_KEY placeholders for expansions]
\033[0m
"""


# =============================================================================
# 3) Logging
# =============================================================================
def log_info(msg):
    print(f"\033[34m[INFO][ORGANIX.ETH]\033[0m => {msg}")

def log_warn(msg):
    print(f"\033[33m[WARN][ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)

def log_error(msg):
    print(f"\033[31m[ERROR][ORGANIX.ETH]\033[0m => {msg}", file=sys.stderr)


# =============================================================================
# 4) AI Initialization
# =============================================================================
if OPENAI_API_KEY:
    openai.api_key = OPENAI_API_KEY
else:
    log_warn("No OPENAI_API_KEY => GPT-4 synergy disabled.")

if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    gemini_pro = genai.GenerativeModel("gemini-pro")
else:
    gemini_pro = None
    log_warn("No GOOGLE_API_KEY => Gemini synergy disabled.")

if TAVILY_API_KEY:
    log_info("TAVILY_API_KEY present => you can integrate TAVILY synergy if needed.")


# =============================================================================
# 5) Docker Compose Management
# =============================================================================
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


# =============================================================================
# 6) Container Health => GPT-4/Gemini synergy
# =============================================================================
def check_container_health():
    try:
        cmd = ["docker","ps","--format","{{.Names}} {{.Status}}"]
        proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = proc.stdout.strip().split("\n")
        for line in lines:
            if not line.strip():
                continue
            parts = line.split(None,1)
            if len(parts)<2:
                continue
            cname, cstatus = parts[0], parts[1].lower()
            # if unhealthy, dead, or restarting => synergy
            if any(word in cstatus for word in ["unhealthy","dead","restarting"]):
                log_warn(f"Container {cname} => {cstatus}, synergy triggered.")
                if GEMINI_FLASH_ENABLED:
                    gemini_flash_intelligence(f"Container {cname} => {cstatus}")
    except subprocess.CalledProcessError as e:
        log_error(f"[HealthCheck] => {e}")


# =============================================================================
# 7) GPT-4 + Gemini Flash
# =============================================================================
def gemini_flash_intelligence(context_str):
    log_info(f"[GeminiFlash] => analyzing {context_str}")
    # google
    google_results = []
    if HAVE_GOOGLESEARCH:
        try:
            for res in google_search(context_str, num=2, stop=2, pause=1.0):
                google_results.append(res)
        except Exception as e:
            log_warn(f"googlesearch => {e}")

    # GPT-4
    openai_ans = None
    if OPENAI_API_KEY:
        prompt = f"Context: {context_str}\nGoogleResults: {google_results}\nSuggest improvements or refactor."
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[{"role":"system","content":"Be advanced synergy AI for organix.eth."},
                          {"role":"user","content":prompt}],
                temperature=0.4
            )
            openai_ans = resp["choices"][0]["message"]["content"]
            log_info(f"[GPT-4] => {openai_ans[:200]} ...")
        except Exception as e:
            log_warn(f"GPT-4 error => {e}")
    else:
        log_warn("[GeminiFlash] => No OPENAI_API_KEY => skip GPT-4 calls")

    # Gemini
    gemini_ans = None
    if gemini_pro:
        try:
            gem_prompt = f"Context: {context_str}\nGoogle: {google_results}"
            out = gemini_pro.generate_content(gem_prompt)
            gemini_ans = out.text
            log_info(f"[Gemini] => {gemini_ans[:200]} ...")
        except Exception as e:
            log_warn(f"Gemini error => {e}")
    else:
        log_warn("Gemini synergy not available => skip.")

    combined = ""
    if openai_ans:
        combined += f"[GPT-4 SAYS]\n{openai_ans}\n"
    if gemini_ans:
        combined += f"[GEMINI SAYS]\n{gemini_ans}\n"

    if combined and AUTONOMOUS_REFACTOR and ("refactor" in combined.lower()):
        trigger_code_refactoring(combined)


# =============================================================================
# 8) Code Refactoring
# =============================================================================
def trigger_code_refactoring(ai_text):
    import re
    pat = re.compile(r"refactor service\s+(\w+)",re.IGNORECASE)
    m = pat.search(ai_text)
    if m:
        svc_name = m.group(1)
        direct_refactor_service(svc_name)
    else:
        log_warn("[Refactor] => AI suggested refactor, but no service found in text.")


def direct_refactor_service(service_name):
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"[Refactor] => No dir => {service_dir}")
        return
    if not OPENAI_API_KEY:
        log_warn("[Refactor] => No OPENAI_API_KEY => skip GPT-4 diff generation.")
        return

    # gather code
    code_agg = ""
    for root, dirs, files in os.walk(service_dir):
        for fn in files:
            if fn.endswith((".py",".rs",".c",".go",".js")):
                fpath = os.path.join(root,fn)
                with open(fpath,"r") as f:
                    fcont = f.read()
                code_agg += f"--- FILE: {fn}\n{fcont}\n"
    if not code_agg.strip():
        log_warn("[Refactor] => No code found.")
        return

    prompt = f"""You are GPT-4 code refactoring expert for organix.eth. Provide a diff in unified format:

Service: {service_name}

CODE:
{code_agg}
"""

    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role":"system","content":"Refactoring assistant."},
                      {"role":"user","content":prompt}],
            temperature=0.3
        )
        patch_text = resp["choices"][0]["message"]["content"]
        apply_patch(service_dir, patch_text)
    except Exception as e:
        log_warn(f"Refactor => GPT-4 error => {e}")


def apply_patch(base_dir, patch_text):
    """Try -p1 or -p2, if both fail => warn."""
    import tempfile
    tmp = None
    try:
        with tempfile.NamedTemporaryFile(mode='w',suffix='.diff',delete=False) as tf:
            tf.write(patch_text)
            tmp = tf.name
        for pnum in ["1","2"]:
            # dry run
            cmd_dry = ["patch",f"-p{pnum}","--dry-run","-i",tmp]
            ret = subprocess.run(cmd_dry, cwd=base_dir, capture_output=True)
            if ret.returncode==0:
                # apply
                cmd_apply = ["patch",f"-p{pnum}","-i",tmp]
                ret2 = subprocess.run(cmd_apply, cwd=base_dir)
                if ret2.returncode==0:
                    log_info(f"[Refactor] Patch success (-p{pnum}) => {base_dir}")
                    break
        else:
            log_warn("[Refactor] Patch failed with -p1/-p2 => manual fix needed.")
    finally:
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)


# =============================================================================
# 9) Finance: organix.eth
# =============================================================================
def manage_finances():
    if not FINANCE_ENABLED:
        return
    w3 = Web3(HTTPProvider(ETH_RPC))
    # robust check
    if w3.provider is None or not w3.is_connected():
        log_warn("[Finance] w3 provider not connected => skip finance.")
        return

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
        log_warn(f"[Finance] Could not parse => {ORGANIXX_ETH_WALLET}")
        return

    try:
        bal_wei = w3.eth.get_balance(address)
        bal_eth = w3.fromWei(bal_wei,"ether")
        log_info(f"[Finance] organix.eth => {bal_eth} ETH.")
        if AUTONOMOUS_FINANCE_ANALYSIS_TRIGGER and bal_eth < ETH_BALANCE_THRESHOLD_FOR_AI:
            gemini_flash_intelligence(f"Low ETH => {bal_eth}, synergy needed.")
    except Exception as e:
        log_warn(f"[Finance] => {e}")


# =============================================================================
# 10) Socket.IO + Flask
# =============================================================================
sio = socketio.Server(async_mode='threading')
app = Flask(__name__)
sock_app = socketio.WSGIApp(sio, app)

@app.route("/webhook", methods=["POST"])
def handle_webhook():
    data = request.json or {}
    log_info(f"[Webhook] => {data}")
    act = data.get("action","")
    if act=="refactor_service":
        svc = data.get("service_name","unknown")
        direct_refactor_service(svc)
    elif act=="trigger_ai":
        ctx = data.get("context","(none)")
        gemini_flash_intelligence(ctx)
    return {"status":"ok"}

@sio.event
def connect(sid, environ):
    log_info(f"[SocketIO] client => {sid}")
    sio.emit("welcome",{"msg":"Welcome to organix.eth swarm!"},room=sid)

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO] disconnected => {sid}")

@sio.on("trigger_ai")
def handle_trigger_ai(sid,data):
    cctx = data.get("context","No context")
    gemini_flash_intelligence(cctx)


# =============================================================================
# 11) Orchestrator Loop + SocketIO
# =============================================================================
def orchestrator_loop():
    docker_compose_build()
    docker_compose_up()
    while True:
        try:
            manage_finances()
            check_container_health()
            time.sleep(MONITORING_INTERVAL)
        except KeyboardInterrupt:
            log_warn("Orchestrator => ^C => stop.")
            break
        except Exception as ex:
            log_error(f"Main loop error => {ex}")
            time.sleep(5)

def find_open_port(preferred=5000, fallback=5050):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind(("0.0.0.0", preferred))
        s.close()
        return preferred
    except:
        log_warn(f"Port {preferred} in use => fallback to {fallback}")
        return fallback

def run_socketio_server(port):
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler
    try:
        server = pywsgi.WSGIServer(("0.0.0.0", port), sock_app, handler_class=WebSocketHandler)
        log_info(f"Socket.IO => listening on :{port}")
        server.serve_forever()
    except KeyboardInterrupt:
        log_warn("SocketIO => ^C => stop.")
    except Exception as ex:
        log_error(f"SocketIO => crashed => {ex}")

def main():
    print(ASCII_BANNER)
    log_info("Starting v01.11.02_autonomous_all_in_one for organix.eth ...")

    # Orchestrator in background
    th = threading.Thread(target=orchestrator_loop, daemon=True)
    th.start()

    # socket.io
    chosen_port = find_open_port(5000,5050)
    run_socketio_server(chosen_port)


if __name__=="__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_warn("Main => ^C => exit.")
    except Exception as e:
        log_error(f"Fatal => {e}\n{traceback.format_exc()}")
        sys.exit(1)
