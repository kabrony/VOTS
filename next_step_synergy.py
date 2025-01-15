#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
next_step_synergy.py

Purpose:
  - "Cat" (print) the .env for quick environment check (like a safe audit).
  - Attempt to load environment variables for AI synergy (OpenAI API key, Gemini key, etc.).
  - Optionally scan your project directories (including Rust or C) to demonstrate
    "analysis" or synergy queries (like a high-level overview).
  - Log which models (GPT-4, Gemini) are available.
  - Provide a "flash synergy" test to confirm that both GPT-4 and Gemini can respond.

(c) 2025. Provided under MIT or Apache 2.0, your choice.
"""

import os
import sys
from pathlib import Path

try:
    from dotenv import load_dotenv
    load_dotenv(".env")
except:
    pass

try:
    import openai
    HAVE_OPENAI=True
except ImportError:
    HAVE_OPENAI=False

try:
    import google.generativeai as genai
    HAVE_GEMINI=True
except ImportError:
    HAVE_GEMINI=False


######################################
# 1) Cat .env
######################################
def cat_env():
    env_path = Path(".env")
    if not env_path.exists():
        print("[ERROR] .env file not found, cannot cat.")
        return

    print("==========================================================")
    print("[INFO] Here is the .env content (like a cat command):")
    print("==========================================================")
    with env_path.open("r", encoding="utf-8") as f:
        for line in f:
            print(line, end="")
    print("\n==========================================================\n")


######################################
# 2) Check environment variables, AI keys
######################################
def check_ai_keys():
    openai_key = os.getenv("OPENAI_API_KEY","")
    gemini_key = os.getenv("GEMINI_API_KEY","")

    if not openai_key.strip():
        print("[WARN] OPENAI_API_KEY missing or blank => GPT-4 synergy won't work.")
    else:
        if not HAVE_OPENAI:
            print("[WARN] openai library not installed => can't use GPT-4 synergy.")
        else:
            openai.api_key = openai_key

    if not gemini_key.strip():
        print("[WARN] GEMINI_API_KEY missing or blank => Gemini synergy won't work.")
    else:
        if not HAVE_GEMINI:
            print("[WARN] google.generativeai library not installed => can't use Gemini synergy.")
        else:
            try:
                genai.configure(api_key=gemini_key)
            except Exception as e:
                print(f"[WARN] Could not configure Gemini => {e}")


######################################
# 3) Quick synergy test (GPT-4 + Gemini)
######################################
def synergy_test():
    print("[INFO] Starting synergy test with GPT-4 + Gemini (if available).")

    # 3.1) GPT-4 test
    if HAVE_OPENAI and openai.api_key:
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[
                    {"role":"system","content":"You are a synergy tester."},
                    {"role":"user","content":"Hello GPT-4! Just do a quick check. How are you?"}
                ],
                temperature=0.3
            )
            gpt_answer = resp["choices"][0]["message"]["content"]
            print(f"[GPT-4 response partial] => {gpt_answer[:100]} ...")
        except Exception as e:
            print(f"[ERROR] GPT-4 synergy test failed => {e}")
    else:
        print("[INFO] GPT-4 synergy test skipped (no key or library).")

    # 3.2) Gemini test
    if HAVE_GEMINI and os.getenv("GEMINI_API_KEY","").strip():
        try:
            model = genai.get_model("gemini-pro")  # or "gemini"
            result = model.generate_content("Hello Gemini! Quick synergy test.")
            print(f"[Gemini response partial] => {result.text[:100]} ...")
        except Exception as e:
            print(f"[ERROR] Gemini synergy test failed => {e}")
    else:
        print("[INFO] Gemini synergy test skipped (no key or library).")


######################################
# 4) Optional Project "analysis" (Rust/C scanning)
######################################
def analyze_project():
    """
    Example function to show how you might gather file paths from Rust or C directories
    and do a quick synergy prompt about them. This is purely a stub demonstration.
    """
    # Suppose you have directories:
    rust_dir = Path("./services/rust-service")
    c_dir = Path("./services/c-service")

    # Collect file info
    info_summary = ""
    for d in [rust_dir, c_dir]:
        if d.exists():
            files = list(d.rglob("*.*"))
            info_summary += f"Found {len(files)} files in {d}:\n"
            for f in files:
                info_summary += f" - {f}\n"
        else:
            info_summary += f"{d} not found.\n"

    print("[INFO] Simple project analysis summary:\n", info_summary)

    # If we have GPT-4 or Gemini, we can do a synergy call:
    if HAVE_OPENAI and openai.api_key:
        prompt = f"Project summary:\n{info_summary}\nWhat potential issues or improvements might we have?"
        try:
            resp = openai.ChatCompletion.create(
                model="gpt-4",
                messages=[
                    {"role":"system","content":"Project code analysis."},
                    {"role":"user","content":prompt}
                ],
                temperature=0.4
            )
            print("[GPT-4 analysis partial] =>", resp["choices"][0]["message"]["content"][:300], "...")
        except Exception as e:
            print(f"[ERROR] GPT-4 analysis call failed => {e}")
    else:
        print("[INFO] GPT-4 analysis skipped (no key or library).")

    if HAVE_GEMINI and os.getenv("GEMINI_API_KEY","").strip():
        model = genai.get_model("gemini-pro")
        try:
            result = model.generate_content(f"Project summary:\n{info_summary}\nPotential improvements?")
            print("[Gemini analysis partial] =>", result.text[:300], "...")
        except Exception as e:
            print(f"[ERROR] Gemini analysis call failed => {e}")
    else:
        print("[INFO] Gemini analysis skipped (no key or library).")


######################################
# main
######################################
def main():
    cat_env()         # Step 1: cat .env
    check_ai_keys()   # Step 2: check for AI keys
    synergy_test()    # Step 3: synergy quick test
    analyze_project() # Step 4: optional project analysis (Rust/C)

if __name__=="__main__":
    main()
