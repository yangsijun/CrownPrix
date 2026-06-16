#!/usr/bin/env python3
"""
find_shortcuts.py

Scans every preprocessed track JSON for shortcut-prone locations.

A shortcut is possible where two parts of the centerline that are far apart
along the track (different "arms") come close enough in Euclidean space that
the collision corridors (±collisionHalfWidth around the centerline) overlap.
There the car can slide continuously from one arm to the other (hairpins,
tight chicanes) without ever being more than collisionHalfWidth from the
nearest tracked segment.

Criteria for a candidate pair (i, j):
  - euclid(i, j) < 2 * COLLISION_HALF_WIDTH            (corridors overlap)
  - path separation along track > MIN_PATH_SEP units    (genuinely different arms)
  - path separation > PATH_RATIO * euclid               (not just a gentle curve)

Pairs within 40..MARGINAL units are reported separately as "marginal"
(tunneling risk at high frame speed) but not flagged as definite.

Candidates are clustered by index adjacency, then each cluster is CONFIRMED
or REJECTED by simulating the actual collision rule: walk a straight crossing
path between the arms at 1u resolution while greedily re-tracking the nearest
segment within ±SEGMENT_SEARCH_WINDOW indices (exactly what CollisionSystem
does). The crossing succeeds if the tracked index ends on the far arm and no
contiguous "pushed-back" stretch (distance > collisionHalfWidth) exceeds one
frame of travel at max speed (tunneling). Existing innerBarriers are honored:
a path that crosses a barrier is blocked.

Usage:
  python3 scripts/find_shortcuts.py [tracks_dir]

Dev tool only — not shipped.
"""

import json
import math
import os
import sys

COLLISION_HALF_WIDTH = 20.0    # GameConfig.collisionHalfWidth
SEGMENT_SEARCH_WINDOW = 40     # GameConfig.segmentSearchWindow
MAX_STEP_PER_FRAME = 6.0       # maxSpeed 180 u/s / 30 fps
DEFINITE = 2 * COLLISION_HALF_WIDTH        # 40: corridors overlap -> crossable
MARGINAL = 2 * COLLISION_HALF_WIDTH + 8    # 48: thin blocking strip, tunneling risk
MIN_PATH_SEP = 80.0
PATH_RATIO = 3.0


def load(path):
    with open(path) as f:
        return json.load(f)


def seg_dist(p, a, b):
    abx, aby = b[0] - a[0], b[1] - a[1]
    l2 = abx * abx + aby * aby
    if l2 < 1e-4:
        return math.hypot(p[0] - a[0], p[1] - a[1])
    t = max(0.0, min(1.0, ((p[0] - a[0]) * abx + (p[1] - a[1]) * aby) / l2))
    cx, cy = a[0] + t * abx, a[1] + t * aby
    return math.hypot(p[0] - cx, p[1] - cy)


def segments_intersect(p1, p2, p3, p4):
    d1x, d1y = p2[0] - p1[0], p2[1] - p1[1]
    d2x, d2y = p4[0] - p3[0], p4[1] - p3[1]
    cross = d1x * d2y - d1y * d2x
    if abs(cross) < 1e-9:
        return False
    t = ((p3[0] - p1[0]) * d2y - (p3[1] - p1[1]) * d2x) / cross
    u = ((p3[0] - p1[0]) * d1y - (p3[1] - p1[1]) * d1x) / cross
    return 0 <= t <= 1 and 1e-6 < u < 1 - 1e-6


def simulate_crossing(points, barriers, i, j):
    """Replicates CollisionSystem: straight path from centerline[i] to
    centerline[j], 1u samples, greedy windowed nearest-segment tracking.

    Returns (crossed, max_blocked_run):
      crossed         True if tracked index reaches arm B (within window of j)
                      and every blocked stretch is tunnel-able in one frame.
      max_blocked_run longest contiguous stretch (u) with distance >
                      COLLISION_HALF_WIDTH from the tracked window's best
                      segment, i.e. where push-back would fire.
    """
    n = len(points)
    start, goal = points[i], points[j]
    total = math.hypot(goal[0] - start[0], goal[1] - start[1])
    if total < 1e-6:
        return True, 0.0
    steps = max(2, int(total) + 1)
    cur_idx = i
    blocked_run = 0.0
    max_blocked_run = 0.0
    prev = start
    for s in range(steps + 1):
        f = s / steps
        p = (start[0] + (goal[0] - start[0]) * f, start[1] + (goal[1] - start[1]) * f)
        # a barrier on the path blocks the crossing outright
        if any(segments_intersect(prev, p, b[0], b[1]) for b in barriers) and s > 0:
            return False, float("inf")
        best_d, best_i = float("inf"), cur_idx
        for off in range(-SEGMENT_SEARCH_WINDOW, SEGMENT_SEARCH_WINDOW + 1):
            k = (cur_idx + off) % n
            d = seg_dist(p, points[k], points[(k + 1) % n])
            if d < best_d:
                best_d, best_i = d, k
        cur_idx = best_i
        step_len = total / steps
        if best_d > COLLISION_HALF_WIDTH:
            blocked_run += step_len
            max_blocked_run = max(max_blocked_run, blocked_run)
        else:
            blocked_run = 0.0
        prev = p
    idx_sep = min((cur_idx - j) % n, (j - cur_idx) % n)
    crossed = idx_sep <= SEGMENT_SEARCH_WINDOW and max_blocked_run <= MAX_STEP_PER_FRAME
    if crossed and path_grazes_vertex(start, goal, barriers):
        # The straight path threads within GRAZE_EPS of a barrier vertex —
        # a sub-millimeter needle created by coordinate rounding plus the
        # runtime's strict-interior epsilon. Any float-realistic neighbor
        # trajectory hits a segment interior, so treat as blocked.
        return False, max_blocked_run
    return crossed, max_blocked_run


GRAZE_EPS = 1e-3


def path_grazes_vertex(p1, p2, barriers):
    verts = {b[0] for b in barriers} | {b[1] for b in barriers}
    abx, aby = p2[0] - p1[0], p2[1] - p1[1]
    l2 = abx * abx + aby * aby
    if l2 < 1e-12:
        return False
    for v in verts:
        t = max(0.0, min(1.0, ((v[0] - p1[0]) * abx + (v[1] - p1[1]) * aby) / l2))
        if math.hypot(v[0] - (p1[0] + t * abx), v[1] - (p1[1] + t * aby)) < GRAZE_EPS:
            return True
    return False


def confirm_cluster(points, barriers, cluster):
    """Try crossings for the cluster's pairs (both directions). Returns
    (n_crossable, n_tested, tightest_blocked_margin)."""
    # sample up to ~60 pairs evenly to keep runtime sane
    pairs = sorted(cluster, key=lambda t: t[2])
    sampled = pairs[:: max(1, len(pairs) // 60)]
    crossable = 0
    min_run = float("inf")
    for (i, j, d, ps) in sampled:
        for (a, b) in ((i, j), (j, i)):
            ok, run = simulate_crossing(points, barriers, a, b)
            min_run = min(min_run, run)
            if ok:
                crossable += 1
    return crossable, 2 * len(sampled), min_run


def scan_track(data):
    points = [(p["x"], p["y"]) for p in data["points"]]
    n = len(points)

    # cumulative arc length
    cum = [0.0] * (n + 1)
    for i in range(n):
        j = (i + 1) % n
        cum[i + 1] = cum[i] + math.hypot(points[j][0] - points[i][0], points[j][1] - points[i][1])
    total = cum[n]

    def path_sep(i, j):
        s = abs(cum[j] - cum[i])
        return min(s, total - s)

    pairs = []
    for i in range(n):
        for j in range(i + 1, n):
            d = math.hypot(points[j][0] - points[i][0], points[j][1] - points[i][1])
            if d >= MARGINAL:
                continue
            ps = path_sep(i, j)
            if ps < MIN_PATH_SEP or ps < PATH_RATIO * d:
                continue
            pairs.append((i, j, d, ps))

    # cluster pairs: same corner if index ranges overlap/adjoin (within GAP)
    GAP = 12
    clusters = []
    for (i, j, d, ps) in sorted(pairs):
        placed = False
        for c in clusters:
            if any(abs(i - ci) <= GAP and abs(j - cj) <= GAP for (ci, cj, _, _) in c):
                c.append((i, j, d, ps))
                placed = True
                break
        if not placed:
            clusters.append([(i, j, d, ps)])
    return clusters, points, total


def main():
    tracks_dir = sys.argv[1] if len(sys.argv) > 1 else \
        "CrownPrix/CrownPrix Watch App/Resources/PreprocessedTracks"
    files = sorted(f for f in os.listdir(tracks_dir) if f.endswith(".json"))

    any_confirmed = False
    for fname in files:
        data = load(os.path.join(tracks_dir, fname))
        clusters, points, total = scan_track(data)
        barriers = [((b["start"]["x"], b["start"]["y"]), (b["end"]["x"], b["end"]["y"]))
                    for b in data.get("innerBarriers", [])]
        if not clusters:
            print(f"{fname:28s} OK (no close approaches; {len(points)} pts, len {total:.0f})")
            continue
        print(f"{fname:28s} {len(clusters)} candidate corner(s)"
              + (f" [{len(barriers)} barriers authored]" if barriers else ""))
        for c in clusters:
            best = min(c, key=lambda t: t[2])
            i, j, d, ps = best
            i_lo = min(t[0] for t in c); i_hi = max(t[0] for t in c)
            j_lo = min(t[1] for t in c); j_hi = max(t[1] for t in c)
            mid = ((points[i][0] + points[j][0]) / 2, (points[i][1] + points[j][1]) / 2)
            crossable, tested, min_run = confirm_cluster(points, barriers, c)
            if crossable:
                verdict = f"SHORTCUT CONFIRMED ({crossable}/{tested} crossings succeed)"
                any_confirmed = True
            else:
                verdict = f"not crossable (min blocked stretch {min_run:.1f}u)"
            print(f"    arms idx {i_lo}-{i_hi} <-> {j_lo}-{j_hi}, "
                  f"min gap {d:.1f}u (path sep {ps:.0f}u), near ({mid[0]:.0f}, {mid[1]:.0f})")
            print(f"      -> {verdict}")
    return 2 if any_confirmed else 0


if __name__ == "__main__":
    sys.exit(main())
