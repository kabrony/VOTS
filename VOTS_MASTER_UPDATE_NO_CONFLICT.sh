#!/usr/bin/env bash
################################################################################
# VOTS_MASTER_UPDATE_NO_CONFLICT.sh
# ------------------------------------------------------------------------------
# This script tries to fix the pip dependency conflicts among:
#   - fastapi + pydantic 2
#   - gradio (which requires pydantic >=2.0)
#   - chromadb (which recently started supporting pydantic>=2 in ~0.4.13+)
#   - google-genai, openai, langchain, etc.
#
# 1) Overwrites python_agent/requirements.txt with pinned versions that should
#    coexist without conflict.
# 2) Overwrites python_agent/agent.py with advanced LLM logic (OpenAI + Gemini).
# 3) Overwrites or creates Dockerfiles for python_agent, c_service, go_service,
#    and nextjs_dashboard if they’re missing.
# 4) Overwrites docker-compose.yml to unify all microservices, plus optional
#    Chroma & local Mongo.
# ------------------------------------------------------------------------------
# Usage:
#   chmod +x VOTS_MASTER_UPDATE_NO_CONFLICT.sh
#   ./VOTS_MASTER_UPDATE_NO_CONFLICT.sh
# Then run:
#   docker compose build --no-cache
#   docker compose up -d
# And check logs:
#   docker compose logs -f python_agent
################################################################################

set -e

echo "=== [STEP 1] Checking essential folders..."

# Must have python_agent, c_service, go_service, nextjs_dashboard folders:
for svc in python_agent c_service go_service nextjs_dashboard; do
  if [ ! -d "$svc" ]; then
    echo "[INFO] Creating missing folder: $svc"
    mkdir -p "$svc"
  fi
done

################################################################################
# 2) Overwrite python_agent/requirements.txt with pinned versions
################################################################################
echo "=== [STEP 2] Overwriting python_agent/requirements.txt to avoid conflicts..."

cat << 'EOF' > python_agent/requirements.txt
###############################################################################
# python_agent/requirements.txt
#
# Pinned versions carefully chosen to avoid or reduce pip conflicts:
#   - FastAPI ~ 0.103 => supports Pydantic 2
#   - Gradio 4.44.x => requires pydantic>=2.0
#   - Chroma 0.4.13 => supports Pydantic 2
#   - LangChain 0.0.320 => tested w/ Pydantic 2
#   - google-genai 0.2.x => OK
#   - openai ~0.28 => new enough
#   - We'll pin pydantic==2.3.0
#   - If STILL conflict, consider removing pinned versions or adjusting further.
###############################################################################

fastapi==0.103.0
uvicorn==0.23.2
requests==2.31.0
python-dotenv==1.0.0
openai==0.28.0
google-genai==0.2.1
chromadb==0.4.13
gradio==4.44.1
langchain==0.0.320
pydantic==2.3.0
tiktoken==0.6.0
EOF

echo "[INFO] Done overwriting python_agent/requirements.txt."

################################################################################
# 3) Overwrite python_agent/agent.py with advanced logic (OpenAI + Gemini)
################################################################################
echo "=== [STEP 3] Overwriting python_agent/agent.py with advanced code..."

cat << 'EOF' > python_agent/agent.py
import os
import logging
import threading
import warnings

import gradio as gr
import requests
import uvicorn
from fastapi import FastAPI, HTTPException
from dotenv import load_dotenv

# For OpenAI calls
import openai

# For Gemini calls
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

# Grab environment keys
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
openai.api_key = OPENAI_API_KEY
DEFAULT_OPENAI_MODEL = os.getenv("DEFAULT_OPENAI_MODEL", "gpt-4o")

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.0-flash-exp")

# Attempt to create gemini client
gemini_client = None
if genai and GEMINI_API_KEY:
    gemini_client = genai.Client(api_key=GEMINI_API_KEY, http_options={"api_version": "v1alpha"})

@app.get("/health")
def health():
    return {"status": "OK", "msg": "Python Agent advanced LLM logic online."}

@app.get("/telemetry")
def telemetry():
    return {
        "OPENAI_API_KEY_snip": OPENAI_API_KEY[:6] + "...",
        "GEMINI_API_KEY_snip": GEMINI_API_KEY[:6] + "...",
        "CHROMA_AVAILABLE": bool(chromadb),
        "mongo_uri_snip": os.getenv("MONGO_URI","")[:10],
        "info": "Python agent telemetry"
    }

def call_openai(prompt: str) -> str:
    if not OPENAI_API_KEY:
        return "[ERROR: No OPENAI_API_KEY]"
    try:
        resp = openai.ChatCompletion.create(
            model=DEFAULT_OPENAI_MODEL,
            messages=[
                {"role": "system", "content": "You are a helpful assistant."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.2
        )
        return resp.choices[0].message.content
    except Exception as e:
        logging.error(f"[OpenAI error] {e}")
        return f"[OpenAI error: {e}]"

def call_gemini(prompt: str) -> str:
    if not gemini_client:
        return "[ERROR: No gemini client configured or no GEMINI_API_KEY]"
    try:
        result = gemini_client.models.generate_content(
            model=GEMINI_MODEL,
            contents=prompt
        )
        return result.text
    except Exception as e:
        logging.error(f"[Gemini error] {e}")
        return f"[Gemini error: {e}]"

@app.post("/chat")
def chat_api(payload: dict):
    """
    JSON:
    {
      "provider":"openai"|"gemini",
      "prompt": "Hello..."
    }
    """
    provider = payload.get("provider","openai").lower()
    prompt = payload.get("prompt","").strip()
    if not prompt:
        raise HTTPException(status_code=400, detail="No 'prompt' found in request.")

    if provider == "gemini":
        return {"response": call_gemini(prompt)}
    else:
        return {"response": call_openai(prompt)}

# Optional Gradio UI
def run_gradio():
    def do_infer(provider, txt):
        if provider=="gemini":
            return call_gemini(txt)
        else:
            return call_openai(txt)

    with gr.Blocks() as demo:
        gr.Markdown("## Python Agent (OpenAI + Gemini) Demo")
        with gr.Row():
            provider_in = gr.Dropdown(choices=["openai","gemini"], value="openai", label="Provider")
            user_prompt = gr.Textbox(label="Your Prompt")
        output_box = gr.Textbox(label="Response")
        run_btn = gr.Button("Send")
        run_btn.click(do_infer, [provider_in, user_prompt], [output_box])
    port = int(os.getenv("GRADIO_PORT","8500"))
    demo.launch(server_name="0.0.0.0", server_port=port)

def run_fastapi():
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("FASTAPI_PORT","9000")))

if __name__=="__main__":
    # spin up gradio in background
    t = threading.Thread(target=run_gradio, daemon=True)
    t.start()
    run_fastapi()
EOF

echo "[INFO] Done overwriting python_agent/agent.py."

################################################################################
# 4) Create Dockerfiles for python_agent, c_service, go_service, nextjs_dashboard
################################################################################
echo "=== [STEP 4] Creating or overwriting Dockerfiles for each microservice..."

# python_agent
if [ ! -f "python_agent/Dockerfile" ]; then
  echo "[INFO] Creating python_agent/Dockerfile..."
fi
cat << 'EOF' > python_agent/Dockerfile
# syntax=docker/dockerfile:1
FROM python:3.11-slim-buster
WORKDIR /app
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt ./
# Upgrade pip to minimize conflict issues
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt
COPY . /app
EXPOSE 9000 8500
CMD ["python","agent.py"]
EOF

# c_service
if [ ! -f "c_service/Dockerfile" ]; then
  echo "[INFO] Creating c_service/Dockerfile..."
fi
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

# go_service
if [ ! -f "go_service/Dockerfile" ]; then
  echo "[INFO] Creating go_service/Dockerfile..."
fi
cat << 'EOF' > go_service/Dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.21 as builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o /go_service main.go

FROM gcr.io/distroless/base-debian11
WORKDIR /app
COPY --from=builder /go_service /app/go_service
EXPOSE 4000
CMD ["/app/go_service"]
EOF

# nextjs_dashboard
if [ ! -f "nextjs_dashboard/Dockerfile" ]; then
  echo "[INFO] Creating nextjs_dashboard/Dockerfile..."
fi
cat << 'EOF' > nextjs_dashboard/Dockerfile
# syntax=docker/dockerfile:1
FROM node:18-alpine as builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/package*.json ./
# If you have public/ folder
COPY --from=builder /app/public ./public
EXPOSE 3000
CMD ["npm","run","start"]
EOF

################################################################################
# 5) Overwrite docker-compose.yml
################################################################################
echo "=== [STEP 5] Overwriting docker-compose.yml..."

cat << 'EOF' > docker-compose.yml
###############################################################################
# docker-compose.yml (Compose v2+)
# 
# Multi-service for VOTS:
#   - python_agent (OpenAI + Gemini + optional Chroma usage)
#   - c_service
#   - go_service
#   - nextjs_dashboard
#   - chroma_service (image: chromadb/chroma:latest)
#   - local Mongo vots_mongo (image: mongo:6)
#
# Make sure .env has your keys: 
#   OPENAI_API_KEY, GEMINI_API_KEY, MONGO_URI, etc.
#
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
      python_agent:
        condition: service_started

  chroma_service:
    image: chromadb/chroma:latest
    container_name: chroma_service
    environment:
      CHROMA_DB_IMPL: "duckdb+parquet"
      CHROMA_PERSIST_DIRECTORY: "/data"
    volumes:
      - chroma_data:/data
    networks:
      - vots_network
    ports:
      - "8000:8000"

  vots_mongo:
    image: mongo:6
    container_name: vots_mongo
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: mysecret
    ports:
      - "27017:27017"
    networks:
      - vots_network

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
# Done
################################################################################
echo "=== [DONE] VOTS MASTER UPDATE COMPLETED (NO_CONFLICT version) ==="
echo "------------------------------------------------------------------"
echo "Next steps:"
echo " 1) docker compose build --no-cache"
echo " 2) docker compose up -d"
echo " 3) If pip conflicts still occur, remove/adjust pinned versions in"
echo "    python_agent/requirements.txt and try again."
echo "------------------------------------------------------------------"
