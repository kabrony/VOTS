#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
setup_vots.py

Purpose:
  - Read the existing .env (the one you have, with all your environment variables).
  - Print (cat) the file contents (like a "safe cat" to confirm).
  - (Optional) Copy or sync environment variables into other places (e.g. Next.js .env.local).
  - Keep .env intact—do not delete or overwrite it.
  - Provide a base script to be extended later for updating Docker Compose, Next.js, or other files.

(c) 2025. Provided under MIT or Apache 2.0. 
"""

import os
import sys
from pathlib import Path

# Optional: use dotenv to parse .env if you want
try:
    from dotenv import dotenv_values
    HAVE_DOTENV = True
except ImportError:
    HAVE_DOTENV = False

# Path to your .env
ENV_PATH = Path(".env")  # or specify absolute path if needed

def main():
    """
    Main entry: cat the .env, confirm environment variables,
    optionally copy them to nextjs_dashboard or docker-compose, etc.
    """
    if not ENV_PATH.exists():
        print("[ERROR] .env file not found. Please ensure .env is present.")
        sys.exit(1)

    print("======================================================")
    print("[INFO] Found .env file. Below is its content (safe cat):")
    print("======================================================\n")

    # "Safe cat" approach: read lines & print them out
    # If you have super-secret values you want masked, you'd do it here.
    with ENV_PATH.open("r", encoding="utf-8") as f:
        lines = f.readlines()

    # Just printing them raw. Adjust as needed to mask keys.
    for line in lines:
        print(line, end="")
    print("\n======================================================\n")

    # If you want to parse .env into a dictionary:
    env_dict = {}
    if HAVE_DOTENV:
        env_dict = dotenv_values(ENV_PATH)
    else:
        env_dict = parse_env_fallback(lines)

    # Optional: show which keys you have
    print("[INFO] Environment variables loaded:")
    for k, v in env_dict.items():
        print(f" - {k}={v}")

    # Example: create or update a Next.js .env.local file
    # (If you want Next.js to access these environment variables at build time)
    create_nextjs_env_local(env_dict)

    # Add any further logic to update docker-compose.yml or others as needed.
    # For now, we just show how you'd do it.

    print("[INFO] Setup script completed. .env remains intact.")

def parse_env_fallback(lines):
    """
    Fallback parser if python-dotenv is not installed.
    This is naive: only handles lines with KEY=VALUE.
    """
    d = {}
    for line in lines:
        line=line.strip()
        if not line or line.startswith("#"):
            continue
        # split on first '='
        parts=line.split("=",1)
        if len(parts)==2:
            k,v=parts[0].strip(), parts[1].strip()
            d[k]=v
    return d

def create_nextjs_env_local(env_dict):
    """
    Optional function to create or update a `.env.local` in your Next.js folder.
    If you want Next.js to see certain environment variables at build time,
    you can selectively copy them here.
    """
    nextjs_folder = Path("./nextjs_dashboard")
    env_local_path = nextjs_folder / ".env.local"

    if not nextjs_folder.exists():
        print("[WARN] nextjs_dashboard folder not found. Skipping .env.local creation.")
        return

    # Decide which keys to copy over. For example:
    # We'll copy MONGO_URI, or other keys relevant to Next.js
    relevant_keys = [
        "MONGO_URI",
        # add more if Next.js needs them
    ]
    lines_to_write = []
    for rk in relevant_keys:
        if rk in env_dict:
            lines_to_write.append(f"{rk}={env_dict[rk]}\n")

    if not lines_to_write:
        print("[INFO] No Next.js env keys found to copy. (MONGO_URI missing?)")
        return

    # Write or append to .env.local
    # We'll do a simple "overwrite" for demonstration.
    with env_local_path.open("w", encoding="utf-8") as f:
        f.writelines(lines_to_write)
    print(f"[INFO] Created/updated Next.js .env.local with: {', '.join(relevant_keys)}")


if __name__ == "__main__":
    main()
