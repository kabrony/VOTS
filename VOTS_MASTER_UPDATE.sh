#!/usr/bin/env bash
################################################################################
# VOTS_MASTER_UPDATE.sh
# ------------------------------------------------------------------------------
# Single script to fix or update your VOTS stack:
#   - Overwrites python_agent/requirements.txt with pinned versions
#   - Overwrites python_agent/agent.py with advanced LLM logic (OpenAI + Gemini)
#   - Creates/overwrites docker-compose.yml to unify c_service, go_service,
#     nextjs_dashboard, python_agent, chroma_service, vots_mongo
#   - Creates Dockerfiles for each sub-folder if missing
# USAGE:
#   chmod +x VOTS_MASTER_UPDATE.sh
#   ./VOTS_MASTER_UPDATE.sh
# Then:
#   docker compose build --no-cache
#   docker compose up -d
################################################################################

set -e

echo "=== [STEP 1] Checking for python_agent folder..."
if [ ! -d "./python_agent" ]; then
  echo "[ERROR] No python_agent folder found. Exiting."
  exit 1
fi

################################################################################
# 2) Overwrite python_agent/requirements.txt with pinned versions to avoid conflicts
################################################################################
echo "=== [STEP 2] Overwriting python_agent/requirements.txt with pinned versions..."

mkdir -p python_agent

cat << 'EOF' > python_agent/requirements.txt
###############################################################################
# python_agent/requirements.txt
#
# This set of pinned versions aims to avoid conflict among:
#   - fastapi + gradio + chromadb
#   - pydantic 2.x constraints
#   - openai, google-genai, etc.
#
# Adjust if still conflicting. In that case, remove some pinned versions
# or update them carefully. 
###############################################################################

# FastAPI version that supports Pydantic 2 but not too new
fastapi==0.103.0

# This uvicorn is typically good with fastapi 0.103
uvicorn==0.23.2

# Basic
requests==2.31.0
python-dotenv==1.0.0

# OpenAI
openai==0.28.0

# Google GenAI (Gemini)
google-genai==0.2.1

# Chroma for local vector DB
chromadb==0.4.8

# Gradio UI
gradio==4.44.1

# LangChain can be pinned or unpinned. We'll pick 0.0.320
langchain==0.0.320

# Pydantic pinned to 2.1+ but <3. 
pydantic==2.3.0

# Additional 
tiktoken==0.6.0
EOF

echo "[INFO] python_agent/requirements.txt updated."

################################################################################
# 3) Overwrite python_agent/agent.py with advanced code
################################################################################
echo "=== [STEP 3] Overwriting python_agent/agent.py..."

cat << 'EOF' > python_agent/agent.py
import os
import logging
import threading
import warnings

import requests
import gradio as gr
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

# For OpenAI calls:
import openai

# For Gemini calls via google-genai
try:
    from google import genai
    from google.genai import types
except ImportError:
    genai = None

# For optional local Chroma usage
try:
    import chromadb
    from chromadb.config import Settings
except ImportError:
    chromadb = None

load_dotenv()
logging.basicConfig(level=logging.INFO)
warnings.filterwarnings("ignore")

app = FastAPI()

# Setup environment keys
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY","")
openai.api_key = OPENAI_API_KEY

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY","")
GEMINI_MODEL = os.getenv("GEMINI_MODEL","gemini-2.0-flash-exp")

DEFAULT_OPENAI_MODEL = os.getenv("DEFAULT_OPENAI_MODEL","gpt-4o")

# Attempt to create gemini client
gemini_client = None
if genai and GEMINI_API_KEY:
    gemini_client = genai.Client(api_key=GEMINI_API_KEY, http_options={'api_version':'v1alpha'})

@app.get("/health")
def health():
    return {"status":"OK","msg":"Python Agent advanced stack online."}

@app.get("/telemetry")
def telemetry():
    return {
        "OPENAI_API_KEY_snip": OPENAI_API_KEY[:8],
        "GEMINI_API_KEY_snip": GEMINI_API_KEY[:8],
        "CHROMA_AVAILABLE": True if chromadb else False,
        "mongo_uri_snip": os.getenv("MONGO_URI","")[:12],
        "info": "Telemetry from python_agent"
    }

def call_openai(prompt: str) -> str:
    if not OPENAI_API_KEY:
        return "[OpenAI key not found]"
    try:
        resp = openai.ChatCompletion.create(
            model=DEFAULT_OPENAI_MODEL,
            messages=[
                {"role":"system","content":"You are a helpful assistant."},
                {"role":"user","content":prompt}
            ],
            temperature=0.3
        )
        return resp.choices[0].message.content
    except Exception as e:
        logging.error(f"[OpenAI error] {e}")
        return f"[OpenAI error: {e}]"

def call_gemini(prompt: str) -> str:
    """Call the 'regular' gemini model (Flash Exp)."""
    if not gemini_client:
        return "[No gemini client configured]"
    try:
        resp = gemini_client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt
        )
        return resp.text
    except Exception as e:
        logging.error(f"[Gemini error] {e}")
        return f"[Gemini error: {e}]"

def call_gemini_thinking(prompt: str) -> str:
    """Hypothetical advanced 'thinking' model: gemini-2.0-flash-thinking-exp."""
    if not gemini_client:
        return "[No gemini client configured]"
    try:
        # We might override the model name here:
        thinking_model = "gemini-2.0-flash-thinking-exp"
        resp = gemini_client.models.generate_content(
            model=thinking_model,
            contents=prompt
        )
        # We can parse out the thoughts:
        out_str = ""
        for part in resp.candidates[0].content.parts:
            if part.thought:
                out_str += f"[THOUGHT] {part.text}\n"
            else:
                out_str += part.text + "\n"
        return out_str.strip()
    except Exception as e:
        logging.error(f"[Gemini thinking error] {e}")
        return f"[Gemini thinking error: {e}]"

@app.post("/chat")
def chat_api(payload: dict):
    """
    JSON:
    {
      "provider":"openai"|"gemini"|"gemini_thinking",
      "prompt":"Hello"
    }
    """
    provider = payload.get("provider","openai")
    prompt = payload.get("prompt","").strip()
    if not prompt:
        raise HTTPException(status_code=400, detail="Missing prompt.")
    if provider=="gemini":
        ans = call_gemini(prompt)
    elif provider=="gemini_thinking":
        ans = call_gemini_thinking(prompt)
    else:
        ans = call_openai(prompt)
    return {"response": ans}

def run_gradio():
    def do_infer(provider, txt):
        if provider=="openai":
            return call_openai(txt)
        elif provider=="gemini_thinking":
            return call_gemini_thinking(txt)
        else:
            return call_gemini(txt)

    with gr.Blocks() as demo:
        gr.Markdown("### Python Agent - Multi LLM Inference")
        dd = gr.Dropdown(choices=["openai","gemini","gemini_thinking"], label="Provider", value="openai")
        user_box = gr.Textbox(label="Your Prompt")
        resp_box = gr.Textbox(label="Response")
        go_btn = gr.Button("Send")
        go_btn.click(do_infer, [dd, user_box], [resp_box])

    port = int(os.getenv("GRADIO_PORT","8500"))
    demo.launch(server_name="0.0.0.0", server_port=port)

def run_fastapi():
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("FASTAPI_PORT","9000")))

if __name__=="__main__":
    t = threading.Thread(target=run_gradio, daemon=True)
    t.start()
    run_fastapi()
EOF

echo "[INFO] python_agent/agent.py updated."

################################################################################
# 4) Dockerfiles if missing
################################################################################
echo "=== [STEP 4] Checking Dockerfiles for c_service, go_service, nextjs_dashboard..."

# c_service
if [ ! -d "c_service" ]; then
  mkdir -p c_service
fi
if [ ! -f "c_service/Dockerfile" ]; then
cat << 'EOF' > c_service/Dockerfile
# syntax=docker/dockerfile:1
FROM ubuntu:22.04 as builder
RUN apt-get update && apt-get install -y build-essential libmicrohttpd-dev
WORKDIR /app
COPY main.c ./
RUN gcc main.c -o c_service -lmicrohttpd

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y libmicrohttpd-dev
WORKDIR /app
COPY --from=builder /app/c_service /app/c_service
EXPOSE 5000
CMD ["/app/c_service"]
EOF
echo "[INFO] Created c_service/Dockerfile."
fi

# go_service
if [ ! -d "go_service" ]; then
  mkdir -p go_service
fi
if [ ! -f "go_service/Dockerfile" ]; then
cat << 'EOF' > go_service/Dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.21 as builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY main.go .
RUN go build -o /go_service main.go

FROM gcr.io/distroless/base-debian11
WORKDIR /app
COPY --from=builder /go_service /app/go_service
EXPOSE 4000
CMD ["/app/go_service"]
EOF
echo "[INFO] Created go_service/Dockerfile."
fi

# nextjs_dashboard
if [ ! -d "nextjs_dashboard" ]; then
  mkdir -p nextjs_dashboard
fi
if [ ! -f "nextjs_dashboard/Dockerfile" ]; then
cat << 'EOF' > nextjs_dashboard/Dockerfile
# syntax=docker/dockerfile:1
FROM node:18-alpine as builder
WORKDIR /app
COPY package.json ./
# If you have package-lock.json:
# COPY package-lock.json ./
RUN npm install
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package.json ./package.json
# If you have a public folder
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["npm","run","start"]
EOF
echo "[INFO] Created nextjs_dashboard/Dockerfile."
fi

# python_agent
if [ ! -f "python_agent/Dockerfile" ]; then
cat << 'EOF' > python_agent/Dockerfile
# syntax=docker/dockerfile:1
FROM python:3.11-slim-buster
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt
COPY . /app
EXPOSE 9000 8500
CMD ["python","agent.py"]
EOF
echo "[INFO] Created python_agent/Dockerfile."
fi

################################################################################
# 5) Overwrite docker-compose.yml
################################################################################
echo "=== [STEP 5] Overwriting docker-compose.yml..."

cat << 'EOF' > docker-compose.yml
###############################################################################
# docker-compose.yml (Compose v2+)
# Full microservices for VOTS:
#   - python_agent (OpenAI + Gemini + optional Chroma)
#   - c_service
#   - go_service
#   - nextjs_dashboard
#   - chroma_service
#   - vots_mongo (local)
###############################################################################
services:

  python_agent:
    build:
      context: ./python_agent
      dockerfile: Dockerfile
    container_name: python_agent
    env_file: .env
    networks:
      - vots_network
    ports:
      - "9000:9000"
      - "8500:8500"
    depends_on:
      - c_service
      - go_service
      - chroma_service
      - vots_mongo

  c_service:
    build:
      context: ./c_service
      dockerfile: Dockerfile
    container_name: c_service
    env_file: .env
    networks:
      - vots_network
    ports:
      - "${C_PORT:-5000}:5000"

  go_service:
    build:
      context: ./go_service
      dockerfile: Dockerfile
    container_name: go_service
    env_file: .env
    networks:
      - vots_network
    ports:
      - "${GO_PORT:-4000}:4000"

  nextjs_dashboard:
    build:
      context: ./nextjs_dashboard
      dockerfile: Dockerfile
    container_name: nextjs_dashboard
    env_file: .env
    networks:
      - vots_network
    ports:
      - "${NEXTJS_PORT:-3001}:3000"
    depends_on:
      - python_agent

  chroma_service:
    image: chromadb/chroma:latest
    container_name: chroma_service
    environment:
      CHROMA_DB_IMPL: "duckdb+parquet"
      CHROMA_PERSIST_DIRECTORY: "/data"
    volumes:
      - chroma_data:/data
    ports:
      - "8000:8000"
    networks:
      - vots_network

  vots_mongo:
    image: mongo:6
    container_name: vots_mongo
    networks:
      - vots_network
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: mysecret
    ports:
      - "27017:27017"

networks:
  vots_network:
    name: vots_network
    driver: bridge

volumes:
  chroma_data:
    driver: local
EOF

echo "[INFO] docker-compose.yml overwritten."

################################################################################
# Done. Show final instructions
################################################################################
echo "=== [DONE] Full upgrade script completed."
echo "------------------------------------------------------"
echo "Next steps:"
echo "  1) docker compose build --no-cache"
echo "  2) docker compose up -d"
echo "  3) Check logs: 'docker compose logs -f python_agent'"
echo "If you still see 'failed to solve' pip conflicts, consider removing pinned versions"
echo "or removing certain dependencies from python_agent/requirements.txt as needed."
echo "Good luck!"
