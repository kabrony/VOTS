#!/usr/bin/env bash
################################################################################
# fix_rag_conflicts.sh
#
# Replaces python_agent/requirements.txt with a set of pinned versions that can
# coexist (FastAPI+Pydantic2+Gradio+LangChain+Chroma+OpenAI). Overwrites agent.py
# with a minimal RAG example using Chroma (REST).
#
# Usage:
#   chmod +x fix_rag_conflicts.sh
#   ./fix_rag_conflicts.sh
#
# Then:
#   docker compose build --no-cache python_agent
#   docker compose up -d python_agent chroma_service
################################################################################

echo "[STEP 1] Overwriting 'python_agent/requirements.txt' with pinned versions..."

cat << 'REQS' > python_agent/requirements.txt
# Pinned versions that should be Pydantic 2.x compatible across the board:
# - FastAPI ~0.108.* now supports pydantic v2
# - Gradio 4.44.x requires pydantic >=2.0
# - Chroma >=0.4.6 uses pydantic 1.9+ but is okay with 2
# - LangChain 0.0.319 is known to work with pydantic 2 as well
# - We'll forcibly pin pydantic to 2.3.0
# - If conflict remains, tweak further or remove some libs.

fastapi==0.108.0
uvicorn==0.23.2
requests==2.31.0
python-dotenv==1.0.0
openai==0.27.8

langchain==0.0.319
chromadb==0.4.6
gradio==4.44.1

# Force specific pydantic 2.3.* to avoid mismatch
pydantic==2.3.0

# Some other typical dependencies
# e.g. if you want 'pip install --upgrade pip' in Docker:
# RUN python -m pip install --upgrade pip
REQS

echo "[STEP 2] Overwriting 'python_agent/agent.py' with minimal RAG + Chroma example..."

cat << 'AGENTPY' > python_agent/agent.py
import os
import logging
import threading
import warnings
from typing import List

import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

import openai

# LangChain + Chroma
from langchain.vectorstores import Chroma
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.chains import RetrievalQA
from langchain.llms import OpenAI

################################################################################
# If you want a fallback "gemini_inference", keep it or remove it
################################################################################
def gemini_inference(prompt: str) -> str:
    """Hypothetical call to Gemini 2.0 Flash Exp."""
    return f"[Gemini 2.0 placeholder => {prompt}]"

################################################################################
# We'll do a minimal approach with a global RAG chain
################################################################################
RAG_CHAIN = None
CHROMA_DB = None

load_dotenv()
logging.basicConfig(level=logging.INFO)
warnings.filterwarnings("ignore")

app = FastAPI()

@app.on_event("startup")
def startup_event():
    """
    Initialize Chroma connection & create a global RAG chain with OpenAI embeddings & LLM
    if DEFAULT_PROVIDER != gemini. If gemini, we skip.
    """
    global CHROMA_DB, RAG_CHAIN

    openai.api_key = os.getenv("OPENAI_API_KEY", "")
    default_provider = os.getenv("DEFAULT_PROVIDER", "openai").lower()

    if default_provider != "gemini" and openai.api_key:
        logging.info("Using OpenAI for embeddings & LLM. Setting up Chroma REST client...")

        # Create embeddings
        embeddings = OpenAIEmbeddings(openai_api_key=openai.api_key)

        # Connect to containerized Chroma via REST. 
        # (Chroma 0.4+ has a new config approach.)
        CHROMA_DB = Chroma(
            collection_name="my_collection",
            embedding_function=embeddings,
            client_settings={
                "chroma_api_impl": "rest",
                "chroma_server_host": "chroma_service",
                "chroma_server_port": 8000,
            },
        )

        retriever = CHROMA_DB.as_retriever(search_kwargs={"k": 3})
        llm = OpenAI(
            model_name="gpt-3.5-turbo",
            openai_api_key=openai.api_key,
            temperature=0.0,
        )
        RAG_CHAIN = RetrievalQA.from_chain_type(
            llm=llm,
            chain_type="stuff",
            retriever=retriever,
        )
    else:
        logging.info("Using gemini_inference or fallback placeholders. No Chroma integration.")
        CHROMA_DB = None
        RAG_CHAIN = None


@app.get("/health")
def health():
    return {"status": "OK"}

@app.get("/telemetry")
def telemetry():
    return {
        "msg": "Python agent telemetry with pinned versions for RAG",
        "openai_api_snippet": openai.api_key[:8] + "..." if openai.api_key else "(none)",
        "provider": os.getenv("DEFAULT_PROVIDER","openai"),
    }

@app.post("/ingest")
async def ingest_docs(request: Request):
    """
    Accept JSON like:
      { "texts": ["Hello world", "Doc #2 ..."] }
    We'll embed & store them in Chroma if RAG_CHAIN is configured.
    """
    if not CHROMA_DB:
        return {"status": "SKIP", "reason": "No CHROMA_DB (maybe gemini or no OPENAI_API_KEY?)"}

    body = await request.json()
    texts = body.get("texts", [])
    if not texts:
        return JSONResponse({"error": "No texts provided"}, status_code=400)

    CHROMA_DB.add_texts(texts, metadatas=[{"source": "ingest_api"}]*len(texts))
    return {"status": "OK", "ingested_count": len(texts)}

@app.post("/chat")
async def chat_rag(request: Request):
    """
    Basic RAG chat endpoint:
      { "query": "Hello?" }
    If RAG_CHAIN is set, do retrieval + LLM. Otherwise gemini placeholder.
    """
    data = await request.json()
    query = data.get("query","").strip()
    if not query:
        return JSONResponse({"error": "No query provided"}, status_code=400)

    default_provider = os.getenv("DEFAULT_PROVIDER", "openai").lower()
    if default_provider == "gemini":
        answer = gemini_inference(query)
    else:
        if RAG_CHAIN:
            answer = RAG_CHAIN.run(query)
        else:
            answer = f"[OpenAI fallback but no chain configured => {query}]"

    return {"answer": answer}


################################################################################
# Optional: Gradio UI
################################################################################
def run_gradio_ui():
    import gradio as gr
    import requests

    def chat_bot(user_input):
        try:
            resp = requests.post("http://localhost:9000/chat", json={"query": user_input})
            return resp.json().get("answer","(Error in response)")
        except Exception as e:
            return f"Error => {str(e)}"

    with gr.Blocks() as demo:
        gr.Markdown("## Python Agent + Chroma-based RAG (Gradio UI) [pydantic 2 pinned!]")
        user_in = gr.Textbox(label="Your query")
        resp_out = gr.Textbox(label="RAG Answer")
        send_btn = gr.Button("Send")
        send_btn.click(chat_bot, user_in, resp_out)

    port = int(os.getenv("GRADIO_PORT", "8500"))
    demo.launch(server_name="0.0.0.0", server_port=port)

if __name__ == "__main__":
    # Start Gradio in background
    t = threading.Thread(target=run_gradio_ui, daemon=True)
    t.start()
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("FASTAPI_PORT","9000")))
AGENTPY

echo ""
echo "[STEP 3] Done rewriting. Next steps:"
echo "  1) 'docker compose build --no-cache python_agent'"
echo "  2) 'docker compose up -d python_agent chroma_service'"
echo "  3) Then test with e.g.:"
echo "     curl -X POST http://localhost:9000/ingest -H 'Content-Type: application/json' -d '{\"texts\":[\"Doc #1 about cats\",\"Doc #2 about dogs\"]}'"
echo "     curl -X POST http://localhost:9000/chat -H 'Content-Type: application/json' -d '{\"query\":\"Tell me about cats\"}'"
echo ""
echo "[INFO] If conflicts remain, try 'pip install --upgrade pip' in the Dockerfile or reduce version constraints."
echo "[DONE] fix_rag_conflicts.sh completed successfully."
