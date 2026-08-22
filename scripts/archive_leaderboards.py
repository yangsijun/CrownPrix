#!/usr/bin/env python3
"""
CrownPrix — Game Center Leaderboard Archiver
Archives an old leaderboard generation via the App Store Connect API, so
outdated app versions can no longer submit (or read) scores on those boards.

Run this ONLY after the app release that switches to the new generation is
live on the App Store — archiving while an old version is still current
breaks its leaderboard views.

Prerequisites:
  Same as create_leaderboards.py — see .env.example

Usage:
  # Dry run — list generation-1 boards that would be archived (no changes)
  python3 scripts/archive_leaderboards.py

  # Archive all generation-1 boards (cp.laptime.*, cp.sector.*)
  python3 scripts/archive_leaderboards.py --apply

  # Archive a different generation (e.g. gen 2 after a future gen-3 reset)
  python3 scripts/archive_leaderboards.py --apply --generation 2
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

try:
    import jwt
    import requests
except ImportError:
    print("Missing dependencies. Run: pip install pyjwt cryptography requests")
    sys.exit(1)


BASE_URL = "https://api.appstoreconnect.apple.com/v1"


def load_env():
    env_path = Path(__file__).parent.parent / ".env"
    if not env_path.exists():
        print(f"ERROR: {env_path} not found.")
        print("Copy .env.example to .env and fill in your credentials.")
        sys.exit(1)
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))


def generate_token(key_id, issuer_id, key_path):
    with open(key_path, "r") as f:
        private_key = f.read()
    payload = {
        "iss": issuer_id,
        "exp": int(time.time()) + 600,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})


def get_credentials():
    load_env()
    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_path = os.environ.get("ASC_KEY_PATH")
    app_id = os.environ.get("ASC_APP_ID")

    missing = [
        name
        for name, val in [
            ("ASC_KEY_ID", key_id),
            ("ASC_ISSUER_ID", issuer_id),
            ("ASC_KEY_PATH", key_path),
            ("ASC_APP_ID", app_id),
        ]
        if not val
    ]
    if missing:
        print(f"ERROR: Missing env vars: {', '.join(missing)}")
        sys.exit(1)

    if not Path(key_path).exists():
        print(f"ERROR: .p8 key file not found: {key_path}")
        sys.exit(1)

    token = generate_token(key_id, issuer_id, key_path)
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    return headers, app_id


def get_game_center_detail_id(headers, app_id):
    resp = requests.get(f"{BASE_URL}/apps/{app_id}/gameCenterDetail", headers=headers)
    body = resp.json()
    if resp.status_code == 200 and body.get("data"):
        return body["data"]["id"]
    print(f"Failed to get Game Center detail: {resp.status_code}")
    print(json.dumps(body, indent=2))
    sys.exit(1)


def fetch_all_leaderboards(headers, gc_detail_id):
    leaderboards = []
    url = f"{BASE_URL}/gameCenterDetails/{gc_detail_id}/gameCenterLeaderboards"
    params = {"limit": 200}

    while url:
        resp = requests.get(url, headers=headers, params=params)
        if resp.status_code != 200:
            print(f"Failed to fetch leaderboards: {resp.status_code}")
            print(resp.text[:500])
            sys.exit(1)

        body = resp.json()
        leaderboards.extend(body.get("data", []))
        url = body.get("links", {}).get("next")
        params = None

    return leaderboards


def generation_pattern(generation):
    prefix = "cp" if generation == 1 else f"cp{generation}"
    return re.compile(rf"^{re.escape(prefix)}\.(laptime|sector)\.")


def archive_leaderboard(headers, lb_resource_id):
    url = f"{BASE_URL}/gameCenterLeaderboards/{lb_resource_id}"
    payload = {
        "data": {
            "type": "gameCenterLeaderboards",
            "id": lb_resource_id,
            "attributes": {"archived": True},
        }
    }
    resp = requests.patch(url, headers=headers, json=payload)
    return resp


def main():
    parser = argparse.ArgumentParser(description="Archive an old CrownPrix leaderboard generation")
    parser.add_argument(
        "--generation", type=int, default=1,
        help="Generation to archive (1 = legacy cp.* boards). Default: 1",
    )
    parser.add_argument(
        "--apply", action="store_true",
        help="Actually archive. Without this flag the script only lists targets (dry run).",
    )
    args = parser.parse_args()
    pattern = generation_pattern(args.generation)

    headers, app_id = get_credentials()

    print("Fetching Game Center Detail ID...")
    gc_detail_id = get_game_center_detail_id(headers, app_id)
    print(f"  Game Center Detail ID: {gc_detail_id}\n")

    print("Fetching all leaderboards...")
    boards = fetch_all_leaderboards(headers, gc_detail_id)
    print(f"  Total leaderboards: {len(boards)}\n")

    targets = []
    for lb in boards:
        attrs = lb.get("attributes", {})
        vendor_id = attrs.get("vendorIdentifier", "")
        if not pattern.match(vendor_id):
            continue
        if attrs.get("archived"):
            print(f"  ⏭  Already archived: {vendor_id}")
            continue
        targets.append((lb["id"], vendor_id))

    if not targets:
        print("Nothing to archive.")
        return

    print(f"\n=== Generation {args.generation} boards to archive ({len(targets)}) ===\n")
    for _, vendor_id in targets:
        print(f"  {vendor_id}")

    if not args.apply:
        print(f"\nDry run — no changes made. Re-run with --apply to archive {len(targets)} leaderboards.")
        return

    print(f"\nArchiving {len(targets)} leaderboards...\n")
    archived = 0
    failed = 0
    for lb_resource_id, vendor_id in targets:
        resp = archive_leaderboard(headers, lb_resource_id)
        if resp.status_code == 200:
            print(f"  ✅ Archived: {vendor_id}")
            archived += 1
        else:
            print(f"  ❌ Failed ({resp.status_code}): {vendor_id}")
            print(f"     {resp.text[:200]}")
            failed += 1
        time.sleep(0.3)

    print(f"\n=== Done ===")
    print(f"  Archived: {archived}")
    print(f"  Failed: {failed}")


if __name__ == "__main__":
    main()
