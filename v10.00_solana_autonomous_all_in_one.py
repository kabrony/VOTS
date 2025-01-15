#!/usr/bin/env python3
"""
v10.00_solana_autonomous_all_in_one.py

Final "beyond perfect" script:
 - Docker Compose build+up
 - Container health checks => GPT-4 + Gemini synergy => possible code refactor
 - Optional TAVILY usage
 - Generates a new Solana wallet if .env has empty SOLANA_PRIVATE_KEY (INSECURE DEMO)
 - Socket.IO port fallback (5000 -> 5050)
 - Graceful keyboard interrupt
"""

import os
import sys
import time
import json
import socket
import subprocess
import threading
import traceback

# Flask + Socket.IO
from flask import Flask, request
import socketio
# .env
from dotenv import load_dotenv

# Attempt Google Search
try:
    from googlesearch import search as google_search
    HAVE_GOOGLESEARCH = True
except ImportError:
    HAVE_GOOGLESEARCH = False

# OpenAI & Gemini
import openai
import google.generativeai as genai

# Attempt Solana (solders)
try:
    from solders.keypair import Keypair as SolKeypair
    from solders.pubkey import Pubkey
    from solders.rpc.api import Client as SolanaClient
    HAVE_SOLANA = True
except ImportError:
    HAVE_SOLANA = False

# ----------- Load .env -----------
load_dotenv(".env")

DOCKER_COMPOSE_FILE  = os.getenv("DOCKER_COMPOSE_FILE","docker-compose.yml")
OPENAI_API_KEY       = os.getenv("OPENAI_API_KEY","")
GOOGLE_API_KEY       = os.getenv("GOOGLE_API_KEY","")
TAVILY_API_KEY       = os.getenv("TAVILY_API_KEY","")  # optional expansions

# Solana
SOLANA_RPC_URL       = os.getenv("SOLANA_RPC_URL","https://api.mainnet-beta.solana.com")
SOLANA_PRIVATE_KEY   = os.getenv("SOLANA_PRIVATE_KEY","")  # if empty => generate new

# AI config
AUTONOMOUS_REFACTOR  = (os.getenv("AUTONOMOUS_REFACTOR","false").lower()=="true")
GEMINI_FLASH_ENABLED = (os.getenv("GEMINI_FLASH_ENABLED","true").lower()=="true")
MONITORING_INTERVAL  = int(os.getenv("MONITORING_INTERVAL","60"))

ASCII_BANNER = r"""
\033[34m
 ██████  ██    ██  ██████   ███    ███   ██████  ███    ██ ██ 
\033[34m██       ██    ██ ██    ██ ████  ████  ██    ██ ████   ██ ██ 
\033[36m██   ███  ██  ██  ██    ██ ██ ████ ██  ██    ██ ██ ██  ██ ██ 
\033[36m██    ██   ████   ██    ██ ██  ██  ██  ██    ██ ██  ██ ██ ██ 
\033[35m ██████     ██     ██████  ██      ██   ██████  ██   ████ ██ 
\033[35m
 ORGANIX.ETH & SOLANA AUTO-SWARM v10.00
\033[32m
 [GPT-4 + GEMINI synergy | Docker + Code Refactor + New Solana Wallet]
 [TAVILY_API_KEY recognized for expansions]
\033[0m
"""

# ------------- Logging helpers -------------
def log_info(msg):
    print(f"\033[34m[INFO][SOLANA-SWARM]\033[0m => {msg}")

def log_warn(msg):
    print(f"\033[33m[WARN][SOLANA-SWARM]\033[0m => {msg}", file=sys.stderr)

def log_error(msg):
    print(f"\033[31m[ERROR][SOLANA-SWARM]\033[0m => {msg}", file=sys.stderr)

# ------------- AI setup -------------
if not OPENAI_API_KEY:
    log_warn("No OPENAI_API_KEY => GPT-4 synergy disabled.")
else:
    openai.api_key = OPENAI_API_KEY

gemini_pro = None
if GOOGLE_API_KEY:
    genai.configure(api_key=GOOGLE_API_KEY)
    gemini_pro = genai.GenerativeModel("gemini-pro")
else:
    log_warn("No GOOGLE_API_KEY => Gemini synergy disabled.")

if TAVILY_API_KEY:
    log_info("TAVILY_API_KEY => expansions possible in code if needed.")

# ------------- Possibly generate new Solana key -------------
def ensure_solana_key():
    """
    If SOLANA_PRIVATE_KEY is empty, generate new. Then store in .env (INSECURE).
    If user doesn't have solders => no generation, logs warn.
    Returns (keypair, pubkey) or (None,None).
    """
    if not HAVE_SOLANA:
        log_warn("solders not installed => cannot generate Solana wallet.")
        return None, None
    if SOLANA_PRIVATE_KEY.strip():
        # load existing
        log_info("Using existing SOLANA_PRIVATE_KEY from .env (unsecure).")
        return load_solana_key(SOLANA_PRIVATE_KEY)
    else:
        # generate new
        kp = SolKeypair()
        raw_hex = kp.as_bytes().hex()
        update_dotenv("SOLANA_PRIVATE_KEY", raw_hex)  # append
        pub = kp.pubkey()
        log_info(f"Generated new Solana key => pubkey={pub} (INSECURE .env write!)")
        return kp, pub

def load_solana_key(hexed:str):
    try:
        raw = bytes.fromhex(hexed)
        kp = SolKeypair.from_bytes(raw)
        return kp, kp.pubkey()
    except Exception as e:
        log_warn(f"Solana key load => {e}")
        return None, None

def update_dotenv(k,v):
    path = ".env"
    lines = []
    replaced = False
    if os.path.exists(path):
        with open(path,"r") as f:
            lines = f.readlines()
    new_lines = []
    for line in lines:
        if line.strip().startswith(f"{k}="):
            new_lines.append(f"{k}={v}\n")
            replaced=True
        else:
            new_lines.append(line)
    if not replaced:
        new_lines.append(f"{k}={v}\n")
    with open(path,"w") as f:
        f.writelines(new_lines)

# ------------- Docker -------------
def docker_compose_build():
    try:
        subprocess.run(["docker","compose","-f",DOCKER_COMPOSE_FILE,"build"],check=True)
        log_info("Docker Compose => build done.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker build => {e}")

def docker_compose_up():
    try:
        subprocess.run(["docker","compose","-f",DOCKER_COMPOSE_FILE,"up","-d"],check=True)
        log_info("Docker Compose => containers up.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker up => {e}")

# ------------- Health + AI synergy -------------
def check_container_health():
    cmd = ["docker","ps","--format","{{.Names}} {{.Status}}"]
    try:
        r = subprocess.run(cmd,capture_output=True,text=True,check=True)
        lines = r.stdout.strip().split("\n")
        for line in lines:
            if not line.strip():
                continue
            name_status = line.split(None,1)
            if len(name_status)<2:
                continue
            cname, cstat = name_status[0], name_status[1].lower()
            # check for "unhealthy", "dead", "restarting"
            if any(x in cstat for x in ["unhealthy","dead","restarting"]):
                log_warn(f"Container {cname} => {cstat}; synergy triggered.")
                if GEMINI_FLASH_ENABLED:
                    gemini_flash_intelligence(f"{cname} => {cstat}")
    except subprocess.CalledProcessError as e:
        log_error(f"HealthCheck => {e}")

def gemini_flash_intelligence(context):
    log_info(f"[GemFlash] analyzing => {context}")

    google_results = []
    if HAVE_GOOGLESEARCH:
        try:
            for res in google_search(context, num=2, stop=2):
                google_results.append(res)
        except Exception as e:
            log_warn(f"Google => {e}")

    # GPT-4
    gpt_txt = ""
    if OPENAI_API_KEY:
        user_prompt = f"""Context => {context}
Google => {google_results}

If code refactor or improvements needed => propose specifics.
"""
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[
                    {"role":"system","content":"Refactor synergy AI for solana-swarm."},
                    {"role":"user","content":user_prompt}
                ],
                temperature=0.3
            )
            gpt_txt = resp["choices"][0]["message"]["content"]
            log_info(f"[GPT-4] => {gpt_txt[:160]} ...")
        except Exception as e:
            log_warn(f"GPT-4 => {e}")

    # Gemini
    gem_txt = ""
    if gemini_pro:
        try:
            gem_prompt = f"Context => {context}\nGoogle => {google_results}"
            out = gemini_pro.generate_content(gem_prompt)
            gem_txt = out.text
            log_info(f"[Gemini] => {gem_txt[:160]} ...")
        except Exception as e:
            log_warn(f"Gemini => {e}")

    combined = f"{gpt_txt}\n{gem_txt}"
    if combined and AUTONOMOUS_REFACTOR and "refactor" in combined.lower():
        trigger_code_refactor(combined)

# ------------- Code Refactor -------------
def trigger_code_refactor(ai_text):
    import re
    pat = re.compile(r"refactor\s+service\s+(\w+)", re.IGNORECASE)
    m = pat.search(ai_text)
    if m:
        svc = m.group(1)
        direct_refactor_service(svc)
    else:
        log_warn("AI suggests refactor but no 'service X' found in text.")

def direct_refactor_service(service_name):
    # gather code from services/<service_name>
    svc_dir = f"services/{service_name}"
    if not os.path.isdir(svc_dir):
        log_warn(f"No service dir => {svc_dir}. skip refactor.")
        return
    if not OPENAI_API_KEY:
        log_warn("No OPENAI_API_KEY => skip refactor.")
        return

    code_agg = ""
    for root,_,files in os.walk(svc_dir):
        for fn in files:
            if fn.endswith((".py",".rs",".c",".go",".js")):
                with open(os.path.join(root,fn),"r") as f:
                    code_agg += f"--- FILE: {fn}\n{f.read()}\n"
    if not code_agg.strip():
        log_warn("No recognized code => skip refactor.")
        return

    prompt = f"""You are a GPT-4 code refactoring agent for the microservice '{service_name}'.
Give a patch in unified diff for improvements:

CODE:
{code_agg}
"""
    try:
        r = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role":"system","content":"Refactor agent"},
                {"role":"user","content":prompt}
            ],
            temperature=0.3
        )
        patch_text = r["choices"][0]["message"]["content"]
        apply_patch(svc_dir, patch_text)
    except Exception as e:
        log_warn(f"Refactor => GPT-4 => {e}")

def apply_patch(base_dir, patch_text):
    import tempfile, os
    import subprocess
    tmp_patch = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".diff", delete=False) as tf:
            tf.write(patch_text)
            tmp_patch = tf.name

        # Try patch -p1 or -p2
        for pnum in [1,2]:
            cmd_dry = ["patch", f"-p{pnum}", "--dry-run", "-i", tmp_patch]
            ret = subprocess.run(cmd_dry, capture_output=True, cwd=base_dir)
            if ret.returncode == 0:
                # apply
                cmd_apply= ["patch", f"-p{pnum}", "-i", tmp_patch]
                ret2 = subprocess.run(cmd_apply, cwd=base_dir)
                if ret2.returncode==0:
                    log_info(f"Patch applied => -p{pnum} => {base_dir}")
                    break
        else:
            log_warn("No patch variant succeeded => manual check needed.")
    finally:
        if tmp_patch and os.path.exists(tmp_patch):
            os.unlink(tmp_patch)

# ------------- Socket.IO -------------
sio = socketio.Server(async_mode="threading")
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
    log_info(f"[SocketIO] connect => sid={sid}")
    sio.emit("message", {"info":"Welcome to SOLANA-SWARM"}, room=sid)

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO] disconnect => sid={sid}")

@sio.on("trigger_ai")
def handle_trigger_ai(sid, data):
    cctx = data.get("context","(none)")
    gemini_flash_intelligence(cctx)

# ------------- Main Orchestrator -------------
def orchestrator_loop():
    # Docker stuff
    docker_compose_build()
    docker_compose_up()

    # Possibly create solana key
    kp, pub = ensure_solana_key()
    if kp and pub:
        log_info(f"Solana pubkey => {pub}")

    # Start monitoring
    while True:
        try:
            check_container_health()
            time.sleep(MONITORING_INTERVAL)
        except KeyboardInterrupt:
            log_warn("Orchestrator => ^C => stop loop.")
            break
        except Exception as e:
            log_error(f"Orchestrator => {e}")
            time.sleep(5)

def pick_socket_port(primary=5000, fallback=5050):
    s=socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind(("0.0.0.0", primary))
        s.close()
        return primary
    except:
        log_warn(f"Port {primary} in use => fallback {fallback}")
        return fallback

def run_socketio_server(port):
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler
    try:
        server = pywsgi.WSGIServer(("0.0.0.0",port), sock_app, handler_class=WebSocketHandler)
        log_info(f"[SocketIO] listening on port => {port}")
        server.serve_forever()
    except KeyboardInterrupt:
        log_warn("SocketIO => ^C => stop")

def main():
    print(ASCII_BANNER)
    log_info("Starting v10.00_solana_autonomous_all_in_one.py ...")

    # run orchestrator in background
    th = threading.Thread(target=orchestrator_loop, daemon=True)
    th.start()

    # pick port
    port = pick_socket_port(5000,5050)
    run_socketio_server(port)

if __name__=="__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_warn("Main => ^C => exit.")
    except Exception as e:
        log_error(f"Fatal => {e}\n{traceback.format_exc()}")
        sys.exit(1)
