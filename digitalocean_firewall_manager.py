#!/usr/bin/env python3
"""
digitalocean_firewall_manager.py

A CLI for managing DigitalOcean Firewalls (v2/firewalls),
loading DO_API_TOKEN from .env via python-dotenv.

Error-handling:
- 401 => token / perms issue
- 429 => rate-limited
- 5xx => DO side error
"""

import os
import sys
import json
import argparse
import requests

try:
    from dotenv import load_dotenv
except ImportError:
    print("[ERROR] Please install python-dotenv: pip install python-dotenv")
    sys.exit(1)

# Load environment variables from .env
load_dotenv()

# Read from environment
DO_API_TOKEN = os.getenv("DO_API_TOKEN")  # e.g. "dop_v1_..."
DO_API_BASE = os.getenv("DO_API_BASE", "https://api.digitalocean.com/v2")
FIREWALLS_ENDPOINT = f"{DO_API_BASE}/firewalls"

def get_auth_header():
    if not DO_API_TOKEN:
        print("[ERROR] DO_API_TOKEN not found. Check .env or environment variables.")
        sys.exit(1)
    return {
        "Authorization": f"Bearer {DO_API_TOKEN}",
        "Content-Type": "application/json"
    }

def handle_response(resp):
    if 200 <= resp.status_code <= 299:
        try:
            return resp.json()
        except ValueError:
            return {}
    else:
        if resp.status_code == 401:
            print("[ERROR 401] Unauthorized. Check token or perms.")
        elif resp.status_code == 404:
            print("[ERROR 404] Not found. Check the resource ID.")
        elif resp.status_code == 429:
            print("[ERROR 429] Rate limit exceeded.")
            retry = resp.headers.get("Retry-After")
            if retry:
                print(f"       Retry after ~{retry} seconds.")
        elif 400 <= resp.status_code < 500:
            print(f"[ERROR {resp.status_code}] Client error. Invalid input?")
        elif 500 <= resp.status_code < 600:
            print(f"[ERROR {resp.status_code}] Server error. Try again later.")
        else:
            print(f"[ERROR {resp.status_code}] Unexpected error.")

        try:
            err_data = resp.json()
            print("Error body:\n", json.dumps(err_data, indent=2))
        except:
            print("No JSON body or parse error.")
        sys.exit(1)

def list_firewalls(_args):
    headers = get_auth_header()
    r = requests.get(FIREWALLS_ENDPOINT, headers=headers)
    data = handle_response(r)
    fw_list = data.get("firewalls", [])
    if fw_list:
        print(json.dumps(fw_list, indent=2))
    else:
        print("[INFO] No firewalls or empty response.")

def create_firewall(args):
    headers = get_auth_header()
    req_body = {"name": args.name}

    if args.inbound_rules:
        try:
            req_body["inbound_rules"] = json.loads(args.inbound_rules)
        except:
            print("[ERROR] inbound_rules invalid JSON.")
            sys.exit(1)
    if args.outbound_rules:
        try:
            req_body["outbound_rules"] = json.loads(args.outbound_rules)
        except:
            print("[ERROR] outbound_rules invalid JSON.")
            sys.exit(1)
    if args.droplet_ids:
        req_body["droplet_ids"] = args.droplet_ids
    if args.tags:
        req_body["tags"] = args.tags

    r = requests.post(FIREWALLS_ENDPOINT, headers=headers, json=req_body)
    data = handle_response(r)
    print("[SUCCESS] Firewall created:")
    print(json.dumps(data, indent=2))

def get_firewall(args):
    if not args.id:
        print("[ERROR] Missing --id for firewall retrieval.")
        sys.exit(1)
    headers = get_auth_header()
    url = f"{FIREWALLS_ENDPOINT}/{args.id}"
    r = requests.get(url, headers=headers)
    data = handle_response(r)
    firewall = data.get("firewall", {})
    print(json.dumps(firewall, indent=2))

def update_firewall(args):
    if not args.id:
        print("[ERROR] Missing --id for firewall update.")
        sys.exit(1)
    headers = get_auth_header()
    url = f"{FIREWALLS_ENDPOINT}/{args.id}"

    req_body = {"name": args.name}
    if args.inbound_rules:
        try:
            req_body["inbound_rules"] = json.loads(args.inbound_rules)
        except:
            print("[ERROR] inbound_rules invalid JSON.")
            sys.exit(1)
    else:
        req_body["inbound_rules"] = []
    if args.outbound_rules:
        try:
            req_body["outbound_rules"] = json.loads(args.outbound_rules)
        except:
            print("[ERROR] outbound_rules invalid JSON.")
            sys.exit(1)
    else:
        req_body["outbound_rules"] = []
    if args.droplet_ids:
        req_body["droplet_ids"] = args.droplet_ids
    else:
        req_body["droplet_ids"] = []
    if args.tags:
        req_body["tags"] = args.tags
    else:
        req_body["tags"] = []

    r = requests.put(url, headers=headers, json=req_body)
    data = handle_response(r)
    print("[SUCCESS] Firewall updated:")
    print(json.dumps(data, indent=2))

def delete_firewall(args):
    if not args.id:
        print("[ERROR] Missing --id for firewall deletion.")
        sys.exit(1)
    headers = get_auth_header()
    url = f"{FIREWALLS_ENDPOINT}/{args.id}"
    r = requests.delete(url, headers=headers)
    handle_response(r)
    print("[SUCCESS] Firewall deleted (no content).")

def main():
    parser = argparse.ArgumentParser(description="Manage DigitalOcean Firewalls via CLI")
    subparsers = parser.add_subparsers(help="Commands")

    # list
    list_p = subparsers.add_parser("list", help="List all firewalls")
    list_p.set_defaults(func=list_firewalls)

    # create
    create_p = subparsers.add_parser("create", help="Create a firewall")
    create_p.add_argument("--name", required=True)
    create_p.add_argument("--inbound-rules", help="JSON array of inbound rules")
    create_p.add_argument("--outbound-rules", help="JSON array of outbound rules")
    create_p.add_argument("--droplet-ids", nargs="*", type=int)
    create_p.add_argument("--tags", nargs="*")
    create_p.set_defaults(func=create_firewall)

    # get
    get_p = subparsers.add_parser("get", help="Retrieve firewall by ID")
    get_p.add_argument("--id", required=True, help="Firewall UUID")
    get_p.set_defaults(func=get_firewall)

    # update
    update_p = subparsers.add_parser("update", help="Update firewall by ID")
    update_p.add_argument("--id", required=True)
    update_p.add_argument("--name", required=True)
    update_p.add_argument("--inbound-rules")
    update_p.add_argument("--outbound-rules")
    update_p.add_argument("--droplet-ids", nargs="*", type=int)
    update_p.add_argument("--tags", nargs="*")
    update_p.set_defaults(func=update_firewall)

    # delete
    delete_p = subparsers.add_parser("delete", help="Delete firewall by ID")
    delete_p.add_argument("--id", required=True)
    delete_p.set_defaults(func=delete_firewall)

    if len(sys.argv) < 2:
        parser.print_help()
        sys.exit(1)
    args = parser.parse_args()
    args.func(args)

if __name__ == "__main__":
    main()
