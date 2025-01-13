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
