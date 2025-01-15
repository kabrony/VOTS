#!/usr/bin/env python3
"""
v02.00_solana_autonomous_all_in_one.py

A comprehensive final script that:
 - Manages Docker microservices with build/up
 - Checks container health and triggers GPT-4 + Gemini synergy for improvements
 - Refactors code automatically if GPT-4 suggests it
 - Generates or uses an existing Solana private key for new wallet
 - Fallback Socket.IO on ports 5000 -> 5050
 - TAVILY_API_KEY placeholders
 - Self-handles errors or conflicts
 - Exits gracefully on ^C

WARNING:
  - Storing private keys in .env is insecure! This is for demonstration only.
  - If 'solders' isn't installed, no new Solana wallet is generated.
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
from dotenv import load_dotenv

# Try google search
try:
    from googlesearch import search as google_search
    HAVE_GOOGLESEARCH = True
except ImportError:
    HAVE_GOOGLESEARCH = False

# LLM
import openai
import google.generativeai as genai

# Solana (via solders)
try:
    from solders.keypair import Keypair as SolKeypair  # pip install solders
    from solders.pubkey import Pubkey
    from solders.system_program import transfer, TransferParams
    from solders.rpc.responses import SendTransactionResp
    from solders.rpc.config import Commitment
    from solders.rpc.api import Client as SolanaClient
    HAVE_SOLANA = True
except ImportError:
    HAVE_SOLANA = False


# ----------------- LOAD ENV ----------------
load_dotenv(".env")

DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")

OPENAI_API_KEY      = os.getenv("OPENAI_API_KEY","")
GOOGLE_API_KEY      = os.getenv("GOOGLE_API_KEY","")
TAVILY_API_KEY      = os.getenv("TAVILY_API_KEY","")  # optional synergy

SOLANA_RPC_URL      = os.getenv("SOLANA_RPC_URL","https://api.mainnet-beta.solana.com")
SOLANA_PRIVATE_KEY  = os.getenv("SOLANA_PRIVATE_KEY","")  # Possibly empty => we generate new if solders installed

AUTONOMOUS_REFACTOR = (os.getenv("AUTONOMOUS_REFACTOR","false").lower()=="true")
GEMINI_FLASH_ENABLED= (os.getenv("GEMINI_FLASH_ENABLED","true").lower()=="true")
MONITORING_INTERVAL = int(os.getenv("MONITORING_INTERVAL","60"))

ASCII_BANNER = r"""
\033[34m
 ██████  ██    ██  ██████   ███    ███   ██████  ███    ██ ██ 
\033[34m██       ██    ██ ██    ██ ████  ████  ██    ██ ████   ██ ██ 
\033[36m██   ███  ██  ██  ██    ██ ██ ████ ██  ██    ██ ██ ██  ██ ██ 
\033[36m██    ██   ████   ██    ██ ██  ██  ██  ██    ██ ██  ██ ██ ██ 
\033[35m ██████     ██     ██████  ██      ██   ██████  ██   ████ ██ 
\033[35m
 ORGANIX.ETH & SOLANA AUTO-SWARM v02.00
\033[32m
 [GPT-4 + GEMINI synergy | Docker + Code Refactor + New Solana Wallet]
 [TAVILY_API_KEY placeholders for expansions]
\033[0m
"""

# ----------------- LOGGING ----------------
def log_info(msg):
    print(f"\033[34m[INFO][SOLANA-SWARM]\033[0m => {msg}")

def log_warn(msg):
    print(f"\033[33m[WARN][SOLANA-SWARM]\033[0m => {msg}", file=sys.stderr)

def log_error(msg):
    print(f"\033[31m[ERROR][SOLANA-SWARM]\033[0m => {msg}", file=sys.stderr)

# ============== AI Setup ==============
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
    log_info("TAVILY_API_KEY present => expansions possible.")


# ============== Solana Key Generation ==============
def ensure_solana_key():
    """
    If SOLANA_PRIVATE_KEY is empty, generate a new Solana wallet (via 'solders').
    Returns (Keypair, Pubkey) or (None,None).
    """
    if not HAVE_SOLANA:
        log_warn("solders not installed => cannot generate Solana wallet.")
        return None, None

    global SOLANA_PRIVATE_KEY
    if SOLANA_PRIVATE_KEY.strip():
        log_info("Using existing SOLANA_PRIVATE_KEY from .env (insecure).")
        return load_solana_key(SOLANA_PRIVATE_KEY)
    else:
        # generate brand new
        kp = SolKeypair()
        secret_hex = kp.as_bytes().hex() 
        pub  = kp.pubkey()
        # update .env (dangerous in real usage)
        try:
            update_dotenv("SOLANA_PRIVATE_KEY", secret_hex)
            log_info(f"Generated new Solana PK => wrote to .env (INSECURE DEMO). pubkey={pub}")
        except Exception as e:
            log_warn(f"Couldn't auto-update .env => {e}")
        return kp, pub

def load_solana_key(secret_hex: str):
    """Parses a hex string => Keypair."""
    try:
        raw = bytes.fromhex(secret_hex)
        kp = SolKeypair.from_bytes(raw)
        return kp, kp.pubkey()
    except Exception as e:
        log_warn(f"Solana load error => {e}")
        return None, None

def update_dotenv(key, val):
    """Append or update .env.  (INSECURE!!)"""
    env_path = ".env"
    lines = []
    replaced = False
    if os.path.exists(env_path):
        with open(env_path,"r") as f:
            lines = f.readlines()
    new_lines = []
    for line in lines:
        if line.strip().startswith(f"{key}="):
            new_lines.append(f"{key}={val}\n")
            replaced=True
        else:
            new_lines.append(line)
    if not replaced:
        new_lines.append(f"{key}={val}\n")
    with open(env_path,"w") as f:
        f.writelines(new_lines)

# ============== Docker Compose ==============
def docker_compose_build():
    try:
        subprocess.run(
            ["docker","compose","-f",DOCKER_COMPOSE_FILE,"build"],
            check=True
        )
        log_info("Docker Compose => build done.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker build => {e}")

def docker_compose_up():
    try:
        subprocess.run(
            ["docker","compose","-f",DOCKER_COMPOSE_FILE,"up","-d"],
            check=True
        )
        log_info("Docker Compose => containers up.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker up => {e}")

# ============== Container Health + AI synergy ==============
def check_container_health():
    """
    Check if containers are unhealthy, dead, or restarting,
    then call gemini_flash_intelligence for GPT-4 + Gemini synergy.
    """
    cmd = ["docker","ps","--format","{{.Names}} {{.Status}}"]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = proc.stdout.strip().split("\n")
        for line in lines:
            if not line.strip():
                continue
            name_status = line.split(None,1)
            if len(name_status)<2:
                continue
            cname, cstatus = name_status[0], name_status[1].lower()
            if any(s in cstatus for s in ["unhealthy","dead","restarting"]):
                log_warn(f"Container {cname} => {cstatus}. synergy triggered.")
                if GEMINI_FLASH_ENABLED:
                    gemini_flash_intelligence(f"Container {cname} => {cstatus}")
    except subprocess.CalledProcessError as e:
        log_error(f"[HealthCheck] => {e}")

# ============== GPT-4 + Gemini synergy ==============
def gemini_flash_intelligence(context_str):
    log_info(f"[GeminiFlash] analyzing => {context_str}")
    google_results = []
    if HAVE_GOOGLESEARCH:
        try:
            for result in google_search(context_str, num=2, stop=2, pause=1):
                google_results.append(result)
        except Exception as e:
            log_warn(f"[GoogleSearch] => {e}")

    openai_txt = ""
    if OPENAI_API_KEY:
        prompt = f"""You are synergy AI for Solana + Docker:

Context => {context_str}
Google => {google_results}

If code refactor or system improvement is needed => propose details.
"""
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[
                    {"role":"system","content":"SynergyRefactorAI for organix & solana"},
                    {"role":"user","content":prompt}
                ],
                temperature=0.3
            )
            openai_txt = resp["choices"][0]["message"]["content"]
            log_info(f"[GPT-4] => {openai_txt[:180]} ...")
        except Exception as e:
            log_warn(f"OpenAI => {e}")

    gem_txt = ""
    if gemini_pro:
        try:
            gem_prompt = f"Context => {context_str}\nGoogle => {google_results}"
            out = gemini_pro.generate_content(gem_prompt)
            gem_txt = out.text
            log_info(f"[Gemini] => {gem_txt[:180]} ...")
        except Exception as e:
            log_warn(f"Gemini => {e}")

    combined = openai_txt + "\n" + gem_txt
    if combined and AUTONOMOUS_REFACTOR and "refactor" in combined.lower():
        trigger_code_refactoring(combined)

# ============== Code Refactor ==============
def trigger_code_refactoring(ai_text):
    import re
    pat = re.compile(r"refactor service\s+(\w+)", re.IGNORECASE)
    match = pat.search(ai_text)
    if match:
        svc = match.group(1)
        direct_refactor_service(svc)
    else:
        log_warn("AI suggests refactor but no service name found in text.")


def direct_refactor_service(service_name):
    service_dir = f"services/{service_name}"
    if not os.path.isdir(service_dir):
        log_warn(f"No directory => {service_dir}, skipping refactor.")
        return
    if not OPENAI_API_KEY:
        log_warn("No OPENAI_API_KEY => skip GPT-4 patch generation.")
        return

    # gather code
    code_agg = ""
    for root,_,files in os.walk(service_dir):
        for fn in files:
            if fn.endswith((".py",".rs",".c",".go",".js")):
                with open(os.path.join(root,fn),"r") as f:
                    code_agg += f"--- FILE {fn}\n{f.read()}\n"
    if not code_agg.strip():
        log_warn("No recognized code in service => skip refactor.")
        return

    prompt = f"""You are GPT-4 code refactorer for a Solana-based Docker microservice '{service_name}'.
Provide a patch in unified diff format for improvements:

CODE:
{code_agg}
"""

    try:
        r = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role":"system","content":"RefactorAI"},
                {"role":"user","content":prompt}
            ],
            temperature=0.3
        )
        patch_text = r["choices"][0]["message"]["content"]
        apply_patch(service_dir, patch_text)
    except Exception as e:
        log_warn(f"Refactor => GPT-4 => {e}")

def apply_patch(base_dir, patch_text):
    import tempfile, os
    tmp_patch = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".diff", delete=False) as tf:
            tf.write(patch_text)
            tmp_patch = tf.name

        # Attempt patch with -p1 or -p2
        for pnum in ["1","2"]:
            cmd_dry = ["patch", f"-p{pnum}", "--dry-run","-i", tmp_patch]
            ret = subprocess.run(cmd_dry, capture_output=True, cwd=base_dir)
            if ret.returncode == 0:
                cmd_apply = ["patch", f"-p{pnum}", "-i", tmp_patch]
                ret2 = subprocess.run(cmd_apply, cwd=base_dir)
                if ret2.returncode==0:
                    log_info(f"[Refactor] Patch success => -p{pnum} => {base_dir}")
                    break
        else:
            log_warn("Patch failed => manual inspection needed.")
    finally:
        if tmp_patch and os.path.exists(tmp_patch):
            os.unlink(tmp_patch)

# ============== Socket.IO + Flask ==============
sio = socketio.Server(async_mode="threading")
app = Flask(__name__)
sock_app = socketio.WSGIApp(sio, app)

@app.route("/webhook", methods=["POST"])
def handle_webhook():
    data = request.json or {}
    log_info(f"[Webhook] => {data}")
    if data.get("action")=="refactor_service":
        svc = data.get("service_name","unknown")
        direct_refactor_service(svc)
    elif data.get("action")=="trigger_ai":
        ctx = data.get("context","(none)")
        gemini_flash_intelligence(ctx)
    return {"status":"ok"}

@sio.event
def connect(sid, environ):
    log_info(f"[SocketIO] connect => {sid}")
    sio.emit("msg", {"info":"Hello from SOLANA-SWARM!"}, room=sid)

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO] disconnect => {sid}")

@sio.on("trigger_ai")
def handle_trigger_ai(sid, data):
    cctx = data.get("context","(none)")
    gemini_flash_intelligence(cctx)


# ============== ORCHESTRATOR MAIN LOOP ==============
def orchestrator_loop():
    # Docker up
    docker_compose_build()
    docker_compose_up()

    # Possibly generate or load Solana key
    kp, pub = ensure_solana_key()
    if kp and pub:
        log_info(f"[Solana] => loaded or generated key => pubkey: {pub}")

    while True:
        try:
            check_container_health()
            time.sleep(MONITORING_INTERVAL)
        except KeyboardInterrupt:
            log_warn("[Orchestrator] => ^C => stop.")
            break
        except Exception as ex:
            log_error(f"[Orchestrator] => {ex}")
            time.sleep(5)

def find_open_port(primary=5000, fallback=5050):
    s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    try:
        s.bind(("0.0.0.0",primary))
        s.close()
        return primary
    except:
        log_warn(f"Port {primary} in use => fallback => {fallback}")
        return fallback

def run_socketio_server(port):
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler
    try:
        server = pywsgi.WSGIServer(("0.0.0.0", port), sock_app, handler_class=WebSocketHandler)
        log_info(f"[SocketIO] => listening on port: {port}")
        server.serve_forever()
    except KeyboardInterrupt:
        log_warn("SocketIO => ^C => stopping")

def main():
    print(ASCII_BANNER)
    log_info("Starting v02.00_solana_autonomous_all_in_one...")

    # orchestrator in background
    th=threading.Thread(target=orchestrator_loop, daemon=True)
    th.start()

    # pick port
    port = find_open_port(5000,5050)
    run_socketio_server(port)

if __name__=="__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_warn("Main => ^C => exit.")
    except Exception as e:
        log_error(f"Fatal => {e}\n{traceback.format_exc()}")
        sys.exit(1)
