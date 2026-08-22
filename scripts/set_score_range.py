#!/usr/bin/env python3
"""
CrownPrix — Game Center Leaderboard Score Range Updater
Sets scoreRangeMin/Max on all (or filtered) leaderboards via App Store Connect API.

WARNING: Setting a score range RETROACTIVELY DELETES scores outside the range.
         This is permanent and cannot be undone.

Prerequisites:
  Same as create_leaderboards.py — see .env.example

Usage:
  # Dry run — list leaderboards and show what would change (no modifications)
  python3 scripts/set_score_range.py

  # Apply score range to ALL leaderboards
  python3 scripts/set_score_range.py --apply

  # Apply only to sector leaderboards (cp.sector.*)
  python3 scripts/set_score_range.py --apply --filter "cp.sector."

  # Custom range
  python3 scripts/set_score_range.py --apply --min 1 --max 600000
"""

import argparse
import json
import os
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


def update_score_range(headers, lb_resource_id, score_min, score_max):
    url = f"{BASE_URL}/gameCenterLeaderboards/{lb_resource_id}"
    payload = {
        "data": {
            "type": "gameCenterLeaderboards",
            "id": lb_resource_id,
            "attributes": {
                "scoreRangeStart": str(score_min),
                "scoreRangeEnd": str(score_max),
            },
        }
    }
    resp = requests.patch(url, headers=headers, json=payload)
    return resp.status_code, resp.json() if resp.text else {}


def main():
    parser = argparse.ArgumentParser(
        description="Set score range on Game Center leaderboards"
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually apply changes (without this flag, dry-run only)",
    )
    parser.add_argument(
        "--filter",
        type=str,
        default=None,
        help="Only update leaderboards whose vendorIdentifier contains this string",
    )
    parser.add_argument("--min", type=int, default=1, help="Minimum score (default: 1)")
    parser.add_argument(
        "--max", type=int, default=600000, help="Maximum score (default: 600000)"
    )
    args = parser.parse_args()

    headers, app_id = get_credentials()

    print("Fetching Game Center Detail...")
    gc_detail_id = get_game_center_detail_id(headers, app_id)
    print(f"  Game Center Detail ID: {gc_detail_id}\n")

    print("Fetching all leaderboards...")
    all_lbs = fetch_all_leaderboards(headers, gc_detail_id)
    print(f"  Found {len(all_lbs)} leaderboards total\n")

    targets = []
    for lb in all_lbs:
        vendor_id = lb["attributes"].get("vendorIdentifier", "")
        if args.filter and args.filter not in vendor_id:
            continue
        targets.append(lb)

    if args.filter:
        print(f"  Filter '{args.filter}' matched {len(targets)} leaderboards\n")

    if not targets:
        print("No leaderboards matched. Nothing to do.")
        return

    print(
        f"{'Vendor Identifier':<40} {'Current Min':>12} {'Current Max':>12} {'Action'}"
    )
    print("-" * 80)

    needs_update = []
    for lb in sorted(
        targets, key=lambda x: x["attributes"].get("vendorIdentifier", "")
    ):
        attrs = lb["attributes"]
        vendor_id = attrs.get("vendorIdentifier", "?")
        cur_min = attrs.get("scoreRangeStart")
        cur_max = attrs.get("scoreRangeEnd")

        cur_min_str = str(cur_min) if cur_min is not None else "—"
        cur_max_str = str(cur_max) if cur_max is not None else "—"

        if cur_min == str(args.min) and cur_max == str(args.max):
            action = "OK (already set)"
        else:
            action = f"SET [{args.min}, {args.max}]"
            needs_update.append(lb)

        print(f"  {vendor_id:<38} {cur_min_str:>12} {cur_max_str:>12}   {action}")

    print(
        f"\n  Total: {len(targets)} | Need update: {len(needs_update)} | Already set: {len(targets) - len(needs_update)}"
    )

    if not needs_update:
        print("\nAll leaderboards already have the correct score range. Done.")
        return

    if not args.apply:
        print(f"\n  DRY RUN — no changes made.")
        print(
            f"  To apply: python3 scripts/set_score_range.py --apply"
            + (f' --filter "{args.filter}"' if args.filter else "")
        )
        return

    print(
        f"\n  ⚠️  WARNING: This will PERMANENTLY DELETE scores outside [{args.min}, {args.max}]"
    )
    print(f"  Updating {len(needs_update)} leaderboards...")
    confirm = input("  Type 'yes' to proceed: ").strip().lower()
    if confirm != "yes":
        print("  Aborted.")
        return

    print()
    updated = 0
    failed = 0
    for lb in needs_update:
        vendor_id = lb["attributes"].get("vendorIdentifier", "?")
        resource_id = lb["id"]
        status, body = update_score_range(headers, resource_id, args.min, args.max)
        if status == 200:
            print(f"  ✓ {vendor_id}")
            updated += 1
        else:
            detail = ""
            if body.get("errors"):
                detail = body["errors"][0].get("detail", "")
            print(f"  ✗ {vendor_id} — {status} {detail}")
            failed += 1
        time.sleep(0.3)

    print(f"\n=== Done ===")
    print(f"  Updated: {updated}")
    print(f"  Failed: {failed}")


if __name__ == "__main__":
    main()
