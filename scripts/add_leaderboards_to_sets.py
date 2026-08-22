#!/usr/bin/env python3
"""
CrownPrix — Attach a leaderboard generation to the per-track leaderboard sets.

Each track has one leaderboard set (e.g. "Albert Park") holding its lap-time and
sector boards. create_leaderboards.py does not attach new boards to sets, so run
this after creating a new generation.

The track for each set is derived from the set's existing members (any board
whose vendor ID matches "*.laptime.{trackId}"), so set vendor IDs don't matter.

The PATCH replaces the set's full member list with: existing members + the new
generation's boards for that track (laptime first, then sectors 0-2).

Usage:
  # Dry run — show which boards would be added to which set
  python3 scripts/add_leaderboards_to_sets.py --generation 2

  # Apply
  python3 scripts/add_leaderboards_to_sets.py --generation 2 --apply
"""

import argparse
import re
import sys
import time

import requests

from archive_leaderboards import (
    BASE_URL,
    fetch_all_leaderboards,
    get_credentials,
    get_game_center_detail_id,
)


def fetch_sets(headers, gc_detail_id):
    resp = requests.get(
        f"{BASE_URL}/gameCenterDetails/{gc_detail_id}/gameCenterLeaderboardSets",
        headers=headers, params={"limit": 200},
    )
    if resp.status_code != 200:
        print(f"Failed to fetch leaderboard sets: {resp.status_code}")
        print(resp.text[:500])
        sys.exit(1)
    return resp.json().get("data", [])


def fetch_set_members(headers, set_id):
    members = []
    url = f"{BASE_URL}/gameCenterLeaderboardSets/{set_id}/gameCenterLeaderboards"
    params = {"limit": 200}
    while url:
        resp = requests.get(url, headers=headers, params=params)
        if resp.status_code != 200:
            print(f"Failed to fetch set members: {resp.status_code}")
            print(resp.text[:500])
            sys.exit(1)
        body = resp.json()
        members.extend(body.get("data", []))
        url = body.get("links", {}).get("next")
        params = None
    return members


def add_set_members(headers, set_id, leaderboard_ids):
    # POST adds members; PATCH on this relationship only reorders existing ones.
    url = f"{BASE_URL}/gameCenterLeaderboardSets/{set_id}/relationships/gameCenterLeaderboards"
    payload = {
        "data": [
            {"type": "gameCenterLeaderboards", "id": lb_id}
            for lb_id in leaderboard_ids
        ]
    }
    return requests.post(url, headers=headers, json=payload)


def remove_set_members(headers, set_id, leaderboard_ids):
    url = f"{BASE_URL}/gameCenterLeaderboardSets/{set_id}/relationships/gameCenterLeaderboards"
    payload = {
        "data": [
            {"type": "gameCenterLeaderboards", "id": lb_id}
            for lb_id in leaderboard_ids
        ]
    }
    return requests.delete(url, headers=headers, json=payload)


def main():
    parser = argparse.ArgumentParser(description="Attach a leaderboard generation to per-track sets")
    parser.add_argument(
        "--generation", type=int, default=2,
        help="Generation whose boards get added (must match LeaderboardIDs.generation). Default: 2",
    )
    parser.add_argument(
        "--apply", action="store_true",
        help="Actually modify the sets. Without this flag the script only prints the plan (dry run).",
    )
    parser.add_argument(
        "--remove-generation", type=int, default=None, metavar="N",
        help="Also remove generation N's boards from each set (replace instead of coexist).",
    )
    args = parser.parse_args()
    prefix = "cp" if args.generation == 1 else f"cp{args.generation}"
    remove_prefix = None
    if args.remove_generation is not None:
        remove_prefix = "cp" if args.remove_generation == 1 else f"cp{args.remove_generation}"

    headers, app_id = get_credentials()

    print("Fetching Game Center Detail ID...")
    gc_detail_id = get_game_center_detail_id(headers, app_id)

    print("Fetching all leaderboards...")
    boards = fetch_all_leaderboards(headers, gc_detail_id)

    # trackId -> [ASC resource ids] in laptime, sector0, sector1, sector2 order
    new_by_track = {}
    lap_re = re.compile(rf"^{re.escape(prefix)}\.laptime\.([a-z]+)$")
    sec_re = re.compile(rf"^{re.escape(prefix)}\.sector\.([a-z]+)\.([0-2])$")
    for lb in boards:
        vendor_id = lb["attributes"]["vendorIdentifier"]
        if m := lap_re.match(vendor_id):
            new_by_track.setdefault(m.group(1), {})["lap"] = (lb["id"], vendor_id)
        elif m := sec_re.match(vendor_id):
            new_by_track.setdefault(m.group(1), {})[f"s{m.group(2)}"] = (lb["id"], vendor_id)

    if not new_by_track:
        print(f"No generation-{args.generation} leaderboards found ({prefix}.*). Run create_leaderboards.py first.")
        sys.exit(1)

    print("Fetching leaderboard sets...")
    sets = fetch_sets(headers, gc_detail_id)
    print(f"  Sets: {len(sets)}\n")

    updated = 0
    skipped = 0
    failed = 0
    any_lap_re = re.compile(r"^cp\d*\.laptime\.([a-z]+)$")

    for s in sets:
        set_name = s["attributes"].get("referenceName", s["id"])
        members = fetch_set_members(headers, s["id"])
        member_ids = [m["id"] for m in members]
        member_vendors = [m["attributes"]["vendorIdentifier"] for m in members]

        # Derive the set's track from any existing laptime member.
        track_id = next(
            (m.group(1) for v in member_vendors if (m := any_lap_re.match(v))),
            None,
        )
        if track_id is None or track_id not in new_by_track:
            print(f"  ⚠️  {set_name}: cannot map to a {prefix}.* track (members: {member_vendors[:2]}...) — skipped")
            skipped += 1
            continue

        entry = new_by_track[track_id]
        ordered_new = [entry[k] for k in ("lap", "s0", "s1", "s2") if k in entry]
        to_add = [(rid, vid) for rid, vid in ordered_new if rid not in member_ids]

        to_remove = []
        if remove_prefix:
            remove_re = re.compile(rf"^{re.escape(remove_prefix)}\.(laptime|sector)\.")
            to_remove = [
                (m["id"], m["attributes"]["vendorIdentifier"])
                for m in members
                if remove_re.match(m["attributes"]["vendorIdentifier"])
            ]

        if not to_add and not to_remove:
            print(f"  ⏭  {set_name}: nothing to change")
            skipped += 1
            continue

        if to_add:
            print(f"  {set_name} ({track_id}): adding {[vid for _, vid in to_add]}")
        if to_remove:
            print(f"  {set_name} ({track_id}): removing {[vid for _, vid in to_remove]}")
        if not args.apply:
            continue

        ok = True
        if to_add:
            resp = add_set_members(headers, s["id"], [rid for rid, _ in to_add])
            if resp.status_code not in (200, 204):
                print(f"  ❌ Add failed ({resp.status_code}): {set_name}")
                print(f"     {resp.text[:200]}")
                ok = False
        if ok and to_remove:
            resp = remove_set_members(headers, s["id"], [rid for rid, _ in to_remove])
            if resp.status_code not in (200, 204):
                print(f"  ❌ Remove failed ({resp.status_code}): {set_name}")
                print(f"     {resp.text[:200]}")
                ok = False
        if ok:
            updated += 1
        else:
            failed += 1
        time.sleep(0.3)

    if not args.apply:
        print("\nDry run — no changes made. Re-run with --apply to update the sets.")
        return

    print(f"\n=== Done ===")
    print(f"  Updated sets: {updated}")
    print(f"  Skipped: {skipped}")
    print(f"  Failed: {failed}")


if __name__ == "__main__":
    main()
