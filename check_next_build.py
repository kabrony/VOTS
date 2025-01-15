#!/usr/bin/env python3

"""
check_next_build.py

A quick script to verify whether a Next.js production build folder (.next)
exists. If it does, the script will list the contents. If not, it suggests
running `next build`.
"""

import os

def check_next_build():
    project_root = os.path.dirname(os.path.abspath(__file__))
    next_folder = os.path.join(project_root, ".next")

    if os.path.exists(next_folder):
        print(f"\n[INFO] Found '.next' directory at:\n    {next_folder}\n")
        print("[INFO] Listing its contents:\n")
        for root, dirs, files in os.walk(next_folder):
            for name in files:
                relative_path = os.path.relpath(os.path.join(root, name), project_root)
                print(f"  - {relative_path}")
        print("\n[INFO] Build artifacts detected successfully.")
    else:
        print("[ERROR] No '.next' directory found!")
        print("[HINT] Make sure to run `npm run build` or `next build` before starting.")
        print("[HINT] If you're using Docker, confirm your Dockerfile executes `npm run build`.\n")

if __name__ == "__main__":
    check_next_build()
