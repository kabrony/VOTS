#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v12_synergy.py

An all-in-one synergy script that:
  1) Uses openai>=1.0.0 with ChatCompletion.create() => GPT-4 synergy.
  2) Uses google.generativeai for Gemini 2.0 Flash (all models).
     - Allows dynamic model selection, e.g. gemini-2.0-flash-exp, gemini-2.0-flash-thinking-exp, etc.
     - If "thinking mode" is relevant, tries to print the thinking_process.
  3) Optionally monitors Docker containers for health => if "unhealthy," synergy can propose "refactor service X."
  4) If synergy says "refactor service X," gather code + request a GPT-4 patch => apply with `patch`.
  5) Provides Socket.IO + Flask server for external synergy triggers.

(c) 2025. Provided under MIT or Apache 2.0, your choice.
"""

import os
import sys
import time
import socket
import subprocess
import threading
import traceback

from flask import Flask, request
import socketio

##########################
# (1) Load environment
##########################
try:
    from dotenv import load_dotenv
    load_dotenv(".env")
except ImportError:
    pass

# Logging
def log_info(msg):
    print(f"[INFO] {msg}")

def log_warn(msg):
    print(f"[WARN] {msg}", file=sys.stderr)

def log_error(msg):
    print(f"[ERROR] {msg}", file=sys.stderr)

##########################
# (2) Setup OpenAI >= 1.0.0
##########################
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "").strip()
GPT4_ENABLED = False
try:
    import openai
    if OPENAI_API_KEY:
        openai.api_key = OPENAI_API_KEY
        GPT4_ENABLED = True
    else:
        log_warn("No OPENAI_API_KEY => GPT-4 synergy disabled.")
except ImportError:
    log_warn("`openai` library not installed => GPT-4 synergy disabled.")

##########################
# (3) Setup Gemini (google.generativeai)
##########################
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_ENABLED = False
try:
    import google.generativeai as genai
    if GEMINI_API_KEY:
        genai.configure(api_key=GEMINI_API_KEY)
        GEMINI_ENABLED = True
    else:
        log_warn("No GEMINI_API_KEY => Gemini synergy disabled.")
except ImportError:
    log_warn("`google.generativeai` library not installed => Gemini synergy disabled.")


##########################
# Docker settings
##########################
DOCKER_COMPOSE_FILE = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")
MONITORING_INTERVAL = int(os.getenv("MONITORING_INTERVAL", "60"))

##########################
# Gemino 2.0 Flash synergy
##########################
def gemini_generate_text(prompt, model_name="gemini-2.0-flash-exp"):
    """
    Minimal text generation with dynamic model.
    If thinking mode is not relevant or we don't want to see it, use this function.
    """
    if not GEMINI_ENABLED:
        log_warn("Gemini synergy not enabled or no key => skipping.")
        return ""
    try:
        model = genai.get_model(model_name)
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        log_warn(f"[Gemini generate_text error] => {e}")
        return ""

def gemini_thinking_mode(prompt, model_name="gemini-2.0-flash-thinking-exp"):
    """
    Demonstrates how to handle "thinking mode" on gemini-2.0-flash-thinking-exp.
    If model_name != gemini-2.0-flash-thinking-exp, we skip the thinking_process.
    """
    if not GEMINI_ENABLED:
        log_warn("Gemini synergy not enabled => skipping.")
        return "", ""

    # If user passes the correct model for thinking mode
    if model_name != "gemini-2.0-flash-thinking-exp":
        log_info("Thinking mode is only for gemini-2.0-flash-thinking-exp. Using normal generation.")
        return gemini_generate_text(prompt, model_name), ""

    # Attempt to fetch thinking_process
    final_text = ""
    thoughts = ""
    try:
        model = genai.get_model(model_name)
        response = model.generate_content(prompt)
        final_text = response.text
        # Check if the response has a thinking_process field
        if hasattr(response, "thinking_process") and getattr(response.thinking_process, "text", None):
            thoughts = response.thinking_process.text
    except Exception as e:
        log_warn(f"[Gemini thinking_mode error] => {e}")
    return final_text, thoughts


##########################
# GPT-4 synergy calls
##########################
def gpt4_chat(prompt):
    """
    Minimal GPT-4 call using openai>=1.0.0
    messages = [ {role: system, content: ...}, {role: user, content: prompt}, ...]
    """
    if not GPT4_ENABLED:
        log_warn("GPT-4 synergy not enabled => skipping.")
        return ""

    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "System synergy for container issues."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3
        )
        gpt_answer = resp["choices"][0]["message"]["content"]
        return gpt_answer
    except Exception as e:
        log_warn(f"[GPT-4 synergy error] => {e}")
        return ""

##########################
# Combined synergy
##########################
def synergy_for_issue(context_text, gemini_model="gemini-2.0-flash-exp", use_thinking=False):
    """
    Attempt synergy from GPT-4 + Gemini 2.0 Flash.
    If use_thinking=True and gemini_model="gemini-2.0-flash-thinking-exp", fetch thoughts.
    Return combined text that might mention "refactor service X".
    """
    combined_str = ""
    # GPT-4
    gpt_answer = gpt4_chat(context_text)
    if gpt_answer:
        log_info(f"[GPT-4 partial] => {gpt_answer[:200]}...")
        combined_str += gpt_answer + "\n"

    # Gemini
    if GEMINI_ENABLED:
        if use_thinking and gemini_model == "gemini-2.0-flash-thinking-exp":
            final_txt, thoughts = gemini_thinking_mode(context_text, gemini_model)
            log_info(f"[Gemini-2.0 thinking partial] => {final_txt[:200]}...")
            if thoughts:
                log_info(f"[Gemini thinking process partial] => {thoughts[:200]}...")
            combined_str += final_txt
        else:
            gem_txt = gemini_generate_text(context_text, gemini_model)
            if gem_txt:
                log_info(f"[Gemini partial] => {gem_txt[:200]}...")
                combined_str += gem_txt
    else:
        log_info("[Gemini disabled or missing key]")

    return combined_str

##########################
# Docker Health
##########################
def docker_compose_build():
    cmd = ["docker","compose","-f", DOCKER_COMPOSE_FILE, "build"]
    try:
        subprocess.run(cmd, check=True)
        log_info("Docker Compose => build success.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker Compose build => {e}")

def docker_compose_up():
    cmd = ["docker","compose","-f", DOCKER_COMPOSE_FILE, "up","-d"]
    try:
        subprocess.run(cmd, check=True)
        log_info("Docker Compose => containers up.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker Compose up => {e}")

def check_container_health():
    """
    Minimal health check => if container is "unhealthy", synergy
    If synergy says "refactor service X", we do refactor
    """
    cmd = ["docker","ps","--format","{{.Names}} {{.Status}}"]
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines = res.stdout.strip().split("\n")
        for line in lines:
            if not line.strip():
                continue
            parts = line.split(None, 1)
            if len(parts)<2:
                continue
            cname, cstat = parts[0], parts[1].lower()
            if any(x in cstat for x in ["unhealthy","dead","restarting"]):
                log_warn(f"Container {cname} => {cstat} => synergy triggered.")
                text = synergy_for_issue(f"{cname} => {cstat}",
                                         gemini_model="gemini-2.0-flash-exp",
                                         use_thinking=False)
                if "refactor service" in text.lower():
                    # parse out service name
                    import re
                    pat = re.compile(r"refactor\s+service\s+(\w+)", re.IGNORECASE)
                    m = pat.search(text)
                    if m:
                        svc = m.group(1)
                        direct_refactor_service(svc)
    except subprocess.CalledProcessError as e:
        log_error(f"check_container_health => {e}")

##########################
# Refactor Pipeline (via GPT-4)
##########################
def direct_refactor_service(svc_name):
    if not GPT4_ENABLED:
        log_warn("No GPT-4 => skip refactor request.")
        return
    svc_dir = f"services/{svc_name}"
    if not os.path.isdir(svc_dir):
        log_warn(f"Service dir not found: {svc_dir}.")
        return
    # gather code
    code_str = ""
    for root,_,files in os.walk(svc_dir):
        for fn in files:
            if fn.endswith((".py",".go",".rs",".c",".cpp",".js",".ts",".tsx")):
                path = os.path.join(root,fn)
                try:
                    with open(path,"r",encoding="utf-8") as f:
                        content=f.read()
                    code_str += f"--- FILE: {fn}\n{content}\n"
                except Exception as e:
                    log_warn(f"Cannot read {path} => {e}")
    if not code_str.strip():
        log_warn(f"No recognized code in {svc_dir}. Skipping.")
        return

    prompt = f"""You are a GPT-4 refactor bot. Provide a unified diff patch to improve the code.
SERVICE: {svc_name}
CODE:
{code_str}
"""
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role":"system","content":"Refactor bot."},
                {"role":"user","content":prompt}
            ],
            temperature=0.3
        )
        diff_text = resp["choices"][0]["message"]["content"]
        apply_patch(svc_dir, diff_text)
    except Exception as e:
        log_warn(f"[Refactor request error] => {e}")

def apply_patch(base_dir, patch_content):
    import tempfile
    tmpf = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", suffix=".diff", delete=False) as tf:
            tf.write(patch_content)
            tmpf=tf.name
        for pnum in [1,2]:
            # dry-run
            cmd = ["patch", f"-p{pnum}", "--dry-run", "-i", tmpf]
            pr = subprocess.run(cmd, cwd=base_dir, capture_output=True)
            if pr.returncode == 0:
                # apply
                cmd2 = ["patch", f"-p{pnum}", "-i", tmpf]
                pr2 = subprocess.run(cmd2, cwd=base_dir)
                if pr2.returncode == 0:
                    log_info(f"Patch applied successfully with -p{pnum} in {base_dir}")
                    break
        else:
            log_warn("No patch apply success => manual check needed.")
    finally:
        if tmpf and os.path.exists(tmpf):
            os.unlink(tmpf)

##########################
# Socket.IO + Flask
##########################
sio = socketio.Server(async_mode="threading")
app = Flask(__name__)
socketio_app = socketio.WSGIApp(sio, app)

@app.route("/webhook", methods=["POST"])
def webhook():
    data = request.json or {}
    action = data.get("action", "")
    if action == "refactor_service":
        svc = data.get("service_name", "unknown")
        direct_refactor_service(svc)
    elif action == "trigger_ai":
        cxt = data.get("context", "(no context)")
        # We'll do synergy with gemini-2.0-flash-exp (no thinking)
        text = synergy_for_issue(cxt, "gemini-2.0-flash-exp", use_thinking=False)
        # If synergy says "refactor service X," parse it:
        if "refactor service" in text.lower():
            import re
            pat = re.compile(r"refactor\s+service\s+(\w+)", re.IGNORECASE)
            m = pat.search(text)
            if m:
                direct_refactor_service(m.group(1))
    return {"status":"ok"}

@sio.event
def connect(sid,environ):
    log_info(f"[SocketIO] connect => {sid}")

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO] disconnect => {sid}")

@sio.on("trigger_ai")
def handle_trigger_ai(sid, data):
    cxt = data.get("context", "(no context)")
    # synergy
    text = synergy_for_issue(cxt, "gemini-2.0-flash-exp", use_thinking=False)
    if "refactor service" in text.lower():
        import re
        pat = re.compile(r"refactor\s+service\s+(\w+)", re.IGNORECASE)
        m = pat.search(text)
        if m:
            direct_refactor_service(m.group(1))

##########################
# Main orchestration
##########################
def main_loop():
    # Build & run containers
    docker_compose_build()
    docker_compose_up()

    # Periodic health checks
    while True:
        try:
            check_container_health()
            time.sleep(MONITORING_INTERVAL)
        except KeyboardInterrupt:
            log_warn("[MainLoop] ^C => break.")
            break
        except Exception as ex:
            log_error(f"[MainLoop] => {ex}\n{traceback.format_exc()}")
            time.sleep(5)

def pick_port(primary=5000, fallback=5050):
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
    log_info(f"[SocketIO] => Listening on port {port}")
    srv = pywsgi.WSGIServer(("0.0.0.0", port), socketio_app, handler_class=WebSocketHandler)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        log_warn("[SocketIO] => ^C => stop server.")

def main():
    log_info("=== Starting v12_synergy with GPT-4 + Gemini 2.0 Flash ===")
    # Start orchestrator in background
    t = threading.Thread(target=main_loop, daemon=True)
    t.start()

    # Pick port
    use_port = pick_port(5000, 5050)
    run_socketio_server(use_port)

if __name__=="__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_warn("[Main] => ^C => exit.")
        sys.exit(0)
    except Exception as ex:
        log_error(f"[Fatal] => {ex}\n{traceback.format_exc()}")
        sys.exit(1)
