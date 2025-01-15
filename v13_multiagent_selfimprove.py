#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
v13_multiagent_selfimprove.py

PURPOSE:
  - Demonstrates a multiagent synergy approach with GPT-4 + Gemini 2.0 Flash,
    referencing the "diverse reasoning chains" approach from the multiagent
    finetuning (generation + critic agents).
  - Uses Docker container health checks (optional).
  - Provides stubs for how you might integrate finetuning data
    (like "finetune_generation_agent()" or "finetune_critic_agent()").
  - Encourages multiple synergy rounds, preserving agent diversity.

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

#######################
# 1) Load environment
#######################
try:
    from dotenv import load_dotenv
    load_dotenv(".env")
except ImportError:
    pass

def log_info(msg):
    print(f"[INFO] {msg}")

def log_warn(msg):
    print(f"[WARN] {msg}", file=sys.stderr)

def log_error(msg):
    print(f"[ERROR] {msg}", file=sys.stderr)

# Read env
OPENAI_API_KEY   = os.getenv("OPENAI_API_KEY","").strip()
GEMINI_API_KEY   = os.getenv("GEMINI_API_KEY","").strip()
DOCKER_FILE      = os.getenv("DOCKER_COMPOSE_FILE","docker-compose.yml")
MONITOR_INTERVAL = int(os.getenv("MONITORING_INTERVAL","60"))  # container checks
THINKING_MODE    = False  # Set True if you want to use gemini-2.0-flash-thinking-exp

#######################
# 2) Setup GPT-4
#######################
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

#######################
# 3) Setup Gemini
#######################
GEMINI_ENABLED = False
try:
    import google.generativeai as genai
    if GEMINI_API_KEY:
        genai.configure(api_key=GEMINI_API_KEY)
        GEMINI_ENABLED = True
    else:
        log_warn("No GEMINI_API_KEY => Gemini synergy disabled.")
except ImportError:
    log_warn("`google.generativeai` not installed => Gemini synergy disabled.")


#######################
# 4) Multiagent Models
#######################
# We'll store a conceptual "Agents" dictionary, each with a "role" (generation or critic)
# and a "model_name" (like gemini-2.0-flash-exp or gemini-2.0-flash-thinking-exp).
# For GPT-4, we store "use_gpt4=True" if it’s a GPT agent; else we store "gemini_model" if it’s a gemini agent.

AGENTS = [
    {"id": "GenAgent1", "role": "generation", "use_gpt4": True, "gemini_model": None},
    {"id": "GenAgent2", "role": "generation", "use_gpt4": False, "gemini_model": "gemini-2.0-flash-exp"},
    {"id": "CritAgent1", "role": "critic",     "use_gpt4": False, "gemini_model": "gemini-2.0-flash-thinking-exp" if THINKING_MODE else "gemini-2.0-flash-exp"},
    # Add more if you want more agents
]

def agent_resolve(agent_conf, prompt):
    """
    If use_gpt4 => call GPT-4 synergy
    else => call gemini synergy with the appropriate model.
    If agent_conf["role"]=="critic", you might want to incorporate the "previous responses"
    for synergy "debate."
    """
    if agent_conf["use_gpt4"] and GPT4_ENABLED:
        return gpt4_chat(prompt)
    elif GEMINI_ENABLED and agent_conf["gemini_model"]:
        if (agent_conf["gemini_model"] == "gemini-2.0-flash-thinking-exp") and THINKING_MODE:
            final_text, thoughts = gemini_thinking_mode(prompt, agent_conf["gemini_model"])
            # you might decide to store the "thoughts" or just return final_text
            return final_text
        else:
            return gemini_generate_text(prompt, agent_conf["gemini_model"])
    else:
        log_warn(f"Agent {agent_conf['id']} => no synergy enabled => returning empty.")
        return ""

#######################
# 5) GPT-4 synergy
#######################
def gpt4_chat(prompt):
    if not GPT4_ENABLED:
        return ""
    try:
        resp = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[
                {"role":"system","content":"Multiagent synergy (GPT-4)."},
                {"role":"user","content": prompt}
            ],
            temperature=0.3
        )
        return resp["choices"][0]["message"]["content"]
    except Exception as e:
        log_warn(f"[gpt4_chat error] => {e}")
        return ""

#######################
# 6) Gemini synergy
#######################
def gemini_generate_text(prompt, model_name="gemini-2.0-flash-exp"):
    if not GEMINI_ENABLED:
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
    If the model_name is gemini-2.0-flash-thinking-exp, we can get final + thinking process.
    """
    if not GEMINI_ENABLED:
        return ("","")
    if model_name != "gemini-2.0-flash-thinking-exp":
        # fallback
        return gemini_generate_text(prompt, model_name), ""
    try:
        model = genai.get_model(model_name)
        response = model.generate_content(prompt)
        final_text = response.text
        thoughts = ""
        if hasattr(response, "thinking_process") and getattr(response.thinking_process, "text", None):
            thoughts = response.thinking_process.text
        return final_text, thoughts
    except Exception as e:
        log_warn(f"[Gemini thinking error] => {e}")
        return ("","")

#######################
# 7) Multiagent Debate
#######################
def multiagent_debate(context):
    """
    Simple 2-round debate:
    Round 1: "generation" agents produce an answer
    Round 2: "critic" agents produce updated answers
    Then majority vote => final
    In a real system, we’d do more complex logic or summarization.
    """
    # Round 1 => generation
    gen_responses = {}
    for agent in AGENTS:
        if agent["role"]=="generation":
            # The prompt can be "context"
            r = agent_resolve(agent, context)
            gen_responses[agent["id"]] = r

    # Summarize generation results in a single string
    generation_summary = "\n".join(f"{k}: {v}" for (k,v) in gen_responses.items())

    # Round 2 => critics
    critic_responses = {}
    for agent in AGENTS:
        if agent["role"]=="critic":
            # The prompt can be something like "context + generation_summary"
            # Possibly: "Here are the generation agent responses. Critique and propose final answer."
            prompt = f"Context => {context}\nGeneration Round =>\n{generation_summary}\nPlease critique & refine the final answer."
            r = agent_resolve(agent, prompt)
            critic_responses[agent["id"]] = r

    # Combine final round => majority vote
    # For simplicity, combine generation + critic responses in a single list for voting
    all_responses = list(gen_responses.values()) + list(critic_responses.values())
    final_ans = majority_vote(all_responses)
    return final_ans

def majority_vote(responses):
    """
    A naive approach: we do a frequency count of the exact string match.
    Real usage might parse or canonicalize numeric answers, etc.
    """
    if not responses:
        return ""
    from collections import Counter
    c = Counter(responses)
    most_common, freq = c.most_common(1)[0]
    # If there's a tie, you might pick randomly or apply more logic
    return most_common

#######################
# 8) Docker Compose
#######################
def docker_compose_build():
    cmd=["docker","compose","-f",DOCKER_FILE,"build"]
    try:
        subprocess.run(cmd, check=True)
        log_info("Docker Compose => build success.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker Compose build => {e}")

def docker_compose_up():
    cmd=["docker","compose","-f",DOCKER_FILE,"up","-d"]
    try:
        subprocess.run(cmd, check=True)
        log_info("Docker Compose => containers up.")
    except subprocess.CalledProcessError as e:
        log_error(f"Docker Compose up => {e}")

def check_container_health():
    cmd=["docker","ps","--format","{{.Names}} {{.Status}}"]
    try:
        res=subprocess.run(cmd, capture_output=True, text=True, check=True)
        lines=res.stdout.strip().split("\n")
        for line in lines:
            if not line.strip():
                continue
            parts=line.split(None,1)
            if len(parts)<2:
                continue
            cname, cstat = parts[0], parts[1].lower()
            if any(x in cstat for x in ["unhealthy","dead","restarting"]):
                log_warn(f"[ContainerHealth] {cname} => {cstat}, triggering synergy.")
                out = multiagent_debate(f"Container {cname} is {cstat} => propose fix or refactor.")
                if "refactor service" in out.lower():
                    # parse out service name
                    import re
                    pat = re.compile(r"refactor\s+service\s+(\w+)", re.IGNORECASE)
                    m=pat.search(out)
                    if m:
                        svc=m.group(1)
                        direct_refactor_service(svc)
    except subprocess.CalledProcessError as e:
        log_error(f"Check container => {e}")

#######################
# 9) Refactor Pipeline
#######################
def direct_refactor_service(svc_name):
    """
    Gathers code from services/<svc_name>, calls GPT-4 for patch, applies it.
    """
    if not GPT4_ENABLED:
        log_warn("No GPT-4 => skipping refactor.")
        return
    svc_dir = f"services/{svc_name}"
    if not os.path.isdir(svc_dir):
        log_warn(f"No directory => {svc_dir}. skip refactor.")
        return

    code_str = ""
    for root,_,files in os.walk(svc_dir):
        for fn in files:
            if fn.endswith((".py",".rs",".go",".c",".cpp",".js",".ts",".tsx")):
                path = os.path.join(root,fn)
                try:
                    with open(path,"r",encoding="utf-8") as f:
                        content=f.read()
                    code_str += f"--- FILE: {fn}\n{content}\n"
                except Exception as e:
                    log_warn(f"Cannot read {path} => {e}")

    if not code_str.strip():
        log_warn(f"No recognized code in {svc_name}. skip refactor.")
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
        patch_text = resp["choices"][0]["message"]["content"]
        apply_patch(svc_dir, patch_text)
    except Exception as e:
        log_warn(f"[Refactor request error] => {e}")

def apply_patch(base_dir, patch_content):
    import tempfile
    tmpf=None
    try:
        with tempfile.NamedTemporaryFile(mode="w",suffix=".diff",delete=False) as tf:
            tf.write(patch_content)
            tmpf=tf.name
        for pnum in [1,2]:
            cmd=["patch",f"-p{pnum}","--dry-run","-i",tmpf]
            pr=subprocess.run(cmd,cwd=base_dir,capture_output=True)
            if pr.returncode==0:
                # apply
                cmd2=["patch",f"-p{pnum}","-i",tmpf]
                pr2=subprocess.run(cmd2,cwd=base_dir)
                if pr2.returncode==0:
                    log_info(f"Patch success => -p{pnum} => {base_dir}")
                    break
        else:
            log_warn("No patch apply success => check manually.")
    finally:
        if tmpf and os.path.exists(tmpf):
            os.unlink(tmpf)

#######################
# 10) Finetuning stubs
#######################
def finetune_generation_agent(agent_id, data):
    """
    Stub function. You’d write the actual code for multiagent finetuning here.
    For instance:
      - save data to disk
      - run a PyTorch script or a huggingface code that loads your base model
        and does a few epochs of finetuning with the data
      - return a path to the finetuned model weights
    """
    log_info(f"Finetuning generation agent {agent_id} on {len(data)} samples (STUB).")
    # Example: 
    # new_ckpt_path = do_your_pytorch_finetune(base_model="mistral-7b", data=data, epochs=2, lr=2e-6)
    new_ckpt_path = f"/path/to/checkpoints/gen_{agent_id}.pt"
    return new_ckpt_path

def finetune_critic_agent(agent_id, data):
    """
    Same stub idea as above, but for the critic agent.
    """
    log_info(f"Finetuning critic agent {agent_id} on {len(data)} samples (STUB).")
    new_ckpt_path = f"/path/to/checkpoints/critic_{agent_id}.pt"
    return new_ckpt_path

#######################
# 11) Socket.IO + Flask
#######################
sio = socketio.Server(async_mode="threading")
app = Flask(__name__)
socketio_app = socketio.WSGIApp(sio, app)

@app.route("/webhook", methods=["POST"])
def webhook():
    d=request.json or {}
    act=d.get("action","")
    if act=="trigger_ai":
        context=d.get("context","(no context)")
        ans = multiagent_debate(context)
        return {"answer": ans}, 200
    elif act=="refactor_service":
        svc_name=d.get("service_name","unknown")
        direct_refactor_service(svc_name)
        return {"status":"ok"},200
    return {"status":"no action"}, 200

@sio.event
def connect(sid,environ):
    log_info(f"[SocketIO connect] => {sid}")

@sio.event
def disconnect(sid):
    log_info(f"[SocketIO disconnect] => {sid}")

@sio.on("trigger_ai")
def handle_trigger_ai(sid, data):
    context = data.get("context","(no context)")
    ans = multiagent_debate(context)
    sio.emit("ai_response", {"answer": ans}, room=sid)

#######################
# 12) Orchestrator Loop
#######################
def main_loop():
    docker_compose_build()
    docker_compose_up()

    while True:
        try:
            check_container_health()
            time.sleep(MONITOR_INTERVAL)
        except KeyboardInterrupt:
            log_warn("MainLoop => ^C => break.")
            break
        except Exception as ex:
            log_error(f"MainLoop => {ex}\n{traceback.format_exc()}")
            time.sleep(5)

def pick_port(primary=5000, fallback=5050):
    s=socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        s.bind(("0.0.0.0",primary))
        s.close()
        return primary
    except:
        log_warn(f"Port {primary} in use => fallback {fallback}")
        return fallback

def run_server(port):
    from gevent import pywsgi
    from geventwebsocket.handler import WebSocketHandler
    log_info(f"Listening on port => {port}")
    srv=pywsgi.WSGIServer(("0.0.0.0",port), socketio_app, handler_class=WebSocketHandler)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        log_warn("SocketIO => ^C => stop.")

def main():
    log_info("=== Starting v13_multiagent_selfimprove ===")
    # Start orchestrator in background
    t=threading.Thread(target=main_loop, daemon=True)
    t.start()

    # pick port
    use_port = pick_port(5000,5050)
    run_server(use_port)

if __name__=="__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_warn("[Main] => ^C => exit.")
        sys.exit(0)
    except Exception as e:
        log_error(f"[Fatal] => {e}\n{traceback.format_exc()}")
        sys.exit(1)
