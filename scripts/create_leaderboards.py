#!/usr/bin/env python3
"""
CrownPrix — Game Center Leaderboard Creator
Creates 96 leaderboards (24 lap times + 72 sectors) via App Store Connect API.

Prerequisites:
  1. App Store Connect → Users & Access → Integrations → App Store Connect API → Generate Key
     - Access: Admin or App Manager
     - Download the .p8 file (only downloadable ONCE)
  2. Note your Key ID and Issuer ID from the same page
  3. Your app must already exist in App Store Connect with Game Center enabled
  4. pip install pyjwt cryptography requests

Usage:
  1. Copy .env.example to .env and fill in your values
  2. python3 scripts/create_leaderboards.py
"""

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
    token = jwt.encode(payload, private_key, algorithm="ES256", headers={"kid": key_id})
    return token


BASE_URL = "https://api.appstoreconnect.apple.com/v1"

TRACKS = [
    ("albertpark", "Albert Park"),
    ("shanghai", "Shanghai"),
    ("suzuka", "Suzuka"),
    ("bahrain", "Bahrain"),
    ("jeddah", "Jeddah"),
    ("miami", "Miami"),
    ("gillesvilleneuve", "Gilles Villeneuve"),
    ("monaco", "Monaco"),
    ("catalunya", "Catalunya"),
    ("redbull", "Red Bull Ring"),
    ("silverstone", "Silverstone"),
    ("spa", "Spa-Francorchamps"),
    ("hungaroring", "Hungaroring"),
    ("zandvoort", "Zandvoort"),
    ("monza", "Monza"),
    ("madring", "Circuito de Madring"),
    ("baku", "Baku"),
    ("marinabay", "Marina Bay"),
    ("americas", "Circuit of the Americas"),
    ("hermanosrodriguez", "Hermanos Rodriguez"),
    ("interlagos", "Interlagos"),
    ("lasvegas", "Las Vegas"),
    ("losail", "Losail"),
    ("abudhabi", "Abu Dhabi"),
]


def get_game_center_detail_id(headers, app_id):
    url = f"{BASE_URL}/apps/{app_id}/gameCenterDetail"
    resp = requests.get(url, headers=headers)
    body = resp.json()
    if resp.status_code == 200 and body.get("data"):
        return body["data"]["id"]
    if resp.status_code == 200 and body.get("data") is None:
        print("Game Center is not enabled for this app.")
        print("Enabling Game Center...")
        return enable_game_center(headers, app_id)
    print(f"Failed to get Game Center detail: {resp.status_code}")
    print(json.dumps(body, indent=2))
    sys.exit(1)


def enable_game_center(headers, app_id):
    url = f"{BASE_URL}/gameCenterDetails"
    payload = {
        "data": {
            "type": "gameCenterDetails",
            "relationships": {
                "app": {
                    "data": {
                        "type": "apps",
                        "id": app_id,
                    }
                }
            },
        }
    }
    resp = requests.post(url, headers=headers, json=payload)
    if resp.status_code == 201:
        gc_id = resp.json()["data"]["id"]
        print(f"  Game Center enabled: {gc_id}")
        return gc_id
    print(f"Failed to enable Game Center: {resp.status_code}")
    print(resp.text)
    sys.exit(1)


def create_leaderboard(headers, gc_detail_id, vendor_id, reference_name):
    url = f"{BASE_URL}/gameCenterLeaderboards"
    payload = {
        "data": {
            "type": "gameCenterLeaderboards",
            "attributes": {
                "defaultFormatter": "ELAPSED_TIME_CENTISECOND",
                "referenceName": reference_name,
                "vendorIdentifier": vendor_id,
                "submissionType": "BEST_SCORE",
                "scoreSortType": "ASC",
            },
            "relationships": {
                "gameCenterDetail": {
                    "data": {
                        "type": "gameCenterDetails",
                        "id": gc_detail_id,
                    }
                }
            },
        }
    }
    resp = requests.post(url, headers=headers, json=payload)
    if resp.status_code == 201:
        return resp.json()["data"]["id"]
    if resp.status_code == 409:
        body = resp.json()
        errors = body.get("errors", [])
        detail = errors[0].get("detail", "") if errors else ""
        print(f"  ⏭  Conflict: {vendor_id} — {detail}")
        return "conflict"
    print(f"  ❌ Failed ({resp.status_code}): {vendor_id}")
    print(f"     {resp.text[:200]}")
    return None


def add_localization(headers, leaderboard_api_id, locale, name):
    url = f"{BASE_URL}/gameCenterLeaderboardLocalizations"
    payload = {
        "data": {
            "type": "gameCenterLeaderboardLocalizations",
            "attributes": {
                "locale": locale,
                "name": name,
            },
            "relationships": {
                "gameCenterLeaderboard": {
                    "data": {
                        "type": "gameCenterLeaderboards",
                        "id": leaderboard_api_id,
                    }
                }
            },
        }
    }
    resp = requests.post(url, headers=headers, json=payload)
    if resp.status_code not in (201, 409):
        print(f"  ⚠️  Localization failed ({resp.status_code}): {name}")


def main():
    load_env()

    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    key_path = os.environ.get("ASC_KEY_PATH")
    app_id = os.environ.get("ASC_APP_ID")

    missing = []
    if not key_id:
        missing.append("ASC_KEY_ID")
    if not issuer_id:
        missing.append("ASC_ISSUER_ID")
    if not key_path:
        missing.append("ASC_KEY_PATH")
    if not app_id:
        missing.append("ASC_APP_ID")
    if missing:
        print(f"ERROR: Missing env vars: {', '.join(missing)}")
        print("Fill in .env file. See .env.example.")
        sys.exit(1)

    if not Path(key_path).exists():
        print(f"ERROR: .p8 key file not found: {key_path}")
        sys.exit(1)

    token = generate_token(key_id, issuer_id, key_path)
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

    print("Fetching Game Center Detail ID...")
    gc_detail_id = get_game_center_detail_id(headers, app_id)
    print(f"  Game Center Detail ID: {gc_detail_id}\n")

    created = 0
    skipped = 0
    failed = 0

    # Lap time leaderboards (24)
    print("=== Lap Time Leaderboards (24) ===\n")
    for track_id, track_name in TRACKS:
        vendor_id = f"cp.laptime.{track_id}"
        ref_name = f"Lap Time - {track_name}"
        print(f"  Creating: {vendor_id}")
        lb_id = create_leaderboard(headers, gc_detail_id, vendor_id, ref_name)
        if lb_id:
            add_localization(headers, lb_id, "en-US", track_name)
            created += 1
        elif lb_id is None:
            skipped += 1
        else:
            failed += 1
        time.sleep(0.3)

    # Sector leaderboards (72)
    print("\n=== Sector Leaderboards (72) ===\n")
    for track_id, track_name in TRACKS:
        for sector in range(3):
            vendor_id = f"cp.sector.{track_id}.{sector}"
            ref_name = f"Sector {sector + 1} - {track_name}"
            display_name = f"{track_name} S{sector + 1}"
            print(f"  Creating: {vendor_id}")
            lb_id = create_leaderboard(headers, gc_detail_id, vendor_id, ref_name)
            if lb_id:
                add_localization(headers, lb_id, "en-US", display_name)
                created += 1
            elif lb_id is None:
                skipped += 1
            else:
                failed += 1
            time.sleep(0.3)

    print(f"\n=== Done ===")
    print(f"  Created: {created}")
    print(f"  Skipped (already exist): {skipped}")
    print(f"  Failed: {failed}")
    print(f"  Total expected: 96")


if __name__ == "__main__":
    main()
