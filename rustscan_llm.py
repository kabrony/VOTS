#!/usr/bin/env python3
"""
rustscan_llm.py
A Python snippet that:
  1) Reads the rustscan output from a file (rustscan_output.json or similar).
  2) Parses it as JSON or raw text.
  3) Feeds it to an LLM (OpenAI or Gemini) for summarization.
  4) Prints the result.

Usage:
  python rustscan_llm.py --file rustscan_output.json [--use-gemini]
"""

import json
import os
import sys
import argparse

import openai
# import requests  # For Gemini or other usage if needed

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

def analyze_openai(parsed_data):
    # Convert parsed_data to a short string
    message_content = f"Here is the RustScan result:\n{parsed_data}\n\n" \
                      f"Please provide a brief summary of open ports and any potential security concerns."

    # ChatCompletion
    response = openai.ChatCompletion.create(
        model="gpt-3.5-turbo",
        messages=[{"role": "user", "content": message_content}],
        temperature=0.3
    )

    return response["choices"][0]["message"]["content"]


def analyze_gemini(parsed_data):
    # Pseudo-code for Gemini usage:
    # url = "https://gemini.googleapis.com/v1/models/gemini-2.0-flash:generateText"
    # headers = {"Authorization": f"Bearer {GEMINI_API_KEY}", "Content-Type": "application/json"}
    # payload = {...}
    # resp = requests.post(url, json=payload, headers=headers)
    # return resp.json()["content"]
    return f"[Gemini mock] Summarizing: {parsed_data}"


def main():
    parser = argparse.ArgumentParser(description="Analyze RustScan JSON output with LLM")
    parser.add_argument("--file", required=True, help="Path to the RustScan output file")
    parser.add_argument("--use-gemini", action="store_true", help="Use Gemini LLM instead of OpenAI")
    args = parser.parse_args()

    if not os.path.isfile(args.file):
        print(f"[ERROR] File not found: {args.file}")
        sys.exit(1)

    # Load the RustScan output
    with open(args.file, "r", encoding="utf-8") as f:
        raw_data = f.read().strip()

    # Attempt to parse JSON
    try:
        parsed_data = json.loads(raw_data)
    except json.JSONDecodeError:
        print("[WARN] Could not parse JSON, using raw text.")
        parsed_data = raw_data

    # Check which LLM
    if args.use_gemini:
        if not GEMINI_API_KEY:
            print("[ERROR] Missing environment variable GEMINI_API_KEY.")
            sys.exit(1)
        analysis = analyze_gemini(parsed_data)
    else:
        if not OPENAI_API_KEY:
            print("[ERROR] Missing environment variable OPENAI_API_KEY.")
            sys.exit(1)
        analysis = analyze_openai(parsed_data)

    print("=== LLM ANALYSIS RESULT ===")
    print(analysis)

if __name__ == "__main__":
    main()
