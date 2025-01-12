import os
import logging
import threading
import warnings

import requests
import gradio as gr
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse
from dotenv import load_dotenv

load_dotenv()
logging.basicConfig(level=logging.INFO)
warnings.filterwarnings("ignore")

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "OK"}

@app.get("/telemetry")
def telemetry():
    # Fake or real data from microservices
    return {
        "rust_latency": 123,
        "go_latency": 50,
        "c_latency": 200,
        "mongo_conn": "Possible check for MONGO_DETAILS",
        "solana_rpc": os.getenv("SOLANA_RPC_URL", "N/A"),
        "openai_api_key_snippet": os.getenv("OPENAI_API_KEY","none")[:10],
        "gemini_api_key_snippet": os.getenv("GEMINI_API_KEY","none")[:10],
        "msg": "Python agent telemetry"
    }

def gemini_inference(prompt: str) -> str:
    return f"[Gemini placeholder] {prompt}"

def openai_inference(prompt: str) -> str:
    return f"[OpenAI placeholder] {prompt}"

def universal_inference(text: str) -> str:
    default_provider = os.getenv("DEFAULT_PROVIDER", "gemini").lower()
    if "gemini" in default_provider:
        return gemini_inference(text)
    else:
        return openai_inference(text)

def run_gradio():
    def greet(txt):
        return universal_inference(txt)

    with gr.Blocks() as demo:
        gr.Markdown("## Python Agent + Gradio UI")
        user_in = gr.Textbox(label="Your Input")
        resp_out = gr.Textbox(label="Response")
        send_btn = gr.Button("Send")
        send_btn.click(greet, user_in, resp_out)

    port = int(os.getenv("GRADIO_PORT", "8500"))
    demo.launch(server_name="0.0.0.0", server_port=port)

def run_fastapi():
    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("FASTAPI_PORT", "9000")))

if __name__ == "__main__":
    t = threading.Thread(target=run_gradio, daemon=True)
    t.start()
    run_fastapi()

# GEMINI_2_0_PLACEHOLDER:
# Hypothetical snippet for advanced Gemini integration
import os

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "fake-gemini-key")
def gemini_2_infer(prompt: str) -> str:
    """
    Pretend we call some advanced Gemini 2.0 API here...
    """
    print("[Gemini 2.0] Using key:", GEMINI_API_KEY)
    return "Gemini 2.0 hypothetical response to: " + prompt

