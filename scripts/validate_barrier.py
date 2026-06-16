#!/usr/bin/env python3
"""
validate_barrier.py

Computes (and/or validates) innerBarriers for a hairpin-bearing preprocessed
track JSON file. Usage:

  python3 scripts/validate_barrier.py <track.json>

Behavior:
- Detects the tightest-radius hairpin via circumscribed-circle curvature.
- Computes a 3-segment inner-kerb fan covering the hairpin interior.
- Validates:
  (a) No barrier segment crosses the centerline polyline.
  (b) 100% shortcut coverage over the entry-exit trajectory matrix.
  (c) Inner-kerb racing line is NOT blocked (no false positives).
- If the JSON already contains innerBarriers, those are validated instead
  of proposing new ones.
- Prints a recommended innerBarriers JSON block on success.
- Exit 0 on PASS, 1 on FAIL.

Dev tool only — not shipped.
"""

import json
import math
import sys


def load_track(path):
    with open(path) as f:
        return json.load(f)


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def segments_intersect(p1, p2, p3, p4):
    d1x, d1y = p2[0] - p1[0], p2[1] - p1[1]
    d2x, d2y = p4[0] - p3[0], p4[1] - p3[1]
    cross = d1x * d2y - d1y * d2x
    if abs(cross) < 1e-9:
        return False
    t = ((p3[0] - p1[0]) * d2y - (p3[1] - p1[1]) * d2x) / cross
    u = ((p3[0] - p1[0]) * d1y - (p3[1] - p1[1]) * d1x) / cross
    return 0 <= t <= 1 and 0 <= u <= 1


def circumscribed_center(p1, p2, p3):
    ax, ay = p1
    bx, by = p2
    cx, cy = p3
    d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
    if abs(d) < 1e-9:
        return None
    ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay) + (cx * cx + cy * cy) * (ay - by)) / d
    uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx) + (cx * cx + cy * cy) * (bx - ax)) / d
    return (ux, uy)


def pt(points, i):
    return (points[i]["x"], points[i]["y"])


def nearest_centerline_dist(p, points):
    """Distance from point p to the nearest centerline segment (any segment).

    Used to tell whether a candidate barrier vertex lands on the drivable road
    (<= roadHalfWidth from a centerline) or out in the black infield between
    the two hairpin arms. Barriers must live in the infield so they never sit
    on the racing surface.
    """
    n = len(points)
    best = float("inf")
    for i in range(n):
        a = pt(points, i)
        b = pt(points, (i + 1) % n)
        abx, aby = b[0] - a[0], b[1] - a[1]
        l2 = abx * abx + aby * aby
        if l2 < 1e-9:
            d = dist(p, a)
        else:
            t = max(0.0, min(1.0, ((p[0] - a[0]) * abx + (p[1] - a[1]) * aby) / l2))
            d = math.hypot(p[0] - (a[0] + t * abx), p[1] - (a[1] + t * aby))
        if d < best:
            best = d
    return best


def find_hairpin_apex(points, window=5):
    n = len(points)
    min_r = float("inf")
    apex = -1
    for i in range(window, n - window):
        c = circumscribed_center(pt(points, i - window), pt(points, i), pt(points, i + window))
        if c is None:
            continue
        r = dist(c, pt(points, i))
        if r < min_r:
            min_r = r
            apex = i
    return apex, min_r


def heading_at(points, i):
    n = len(points)
    p = pt(points, i)
    q = pt(points, (i + 1) % n)
    return math.atan2(q[1] - p[1], q[0] - p[0])


def normalize_angle(a):
    while a > math.pi:
        a -= 2 * math.pi
    while a < -math.pi:
        a += 2 * math.pi
    return a


def hairpin_range(points, apex_idx, half_window=25):
    """Simple fixed-window range covering ~half_window indices on each side."""
    n = len(points)
    start = max(0, apex_idx - half_window)
    end = min(n - 1, apex_idx + half_window)
    return start, end


def detect_turn_direction(points, apex_idx, window=3):
    h_before = heading_at(points, apex_idx - window)
    h_after = heading_at(points, apex_idx + window)
    return "ccw" if normalize_angle(h_after - h_before) > 0 else "cw"


def inner_kerb_point(points, idx, road_half_width, turn_direction="ccw"):
    """Offset centerline[idx] perpendicular to local heading, toward inside of turn."""
    p = pt(points, idx)
    h = heading_at(points, idx)
    sign = 1.0 if turn_direction == "ccw" else -1.0
    perp = h + sign * math.pi / 2
    return (p[0] + road_half_width * math.cos(perp), p[1] + road_half_width * math.sin(perp))


def validate_centerline_crossing(barriers, points):
    """Check centerline polyline doesn't cross any barrier, ignoring exact
    shared-endpoint cases (barrier endpoint AT a centerline point is a
    deliberate design, not a crossing)."""
    n = len(points)
    hits = []
    for i in range(n):
        j = (i + 1) % n
        seg = (pt(points, i), pt(points, j))
        for bi, b in enumerate(barriers):
            if segments_share_endpoint(seg, b):
                continue
            if segments_intersect(seg[0], seg[1], b[0], b[1]):
                hits.append((i, bi))
    return hits


def point_on_segment(p, a, b, eps=1e-6):
    d = dist(a, b)
    if d < eps:
        return dist(p, a) < eps
    cross = (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0])
    if abs(cross) / d > eps:
        return False
    dot = (p[0] - a[0]) * (b[0] - a[0]) + (p[1] - a[1]) * (b[1] - a[1])
    return -eps <= dot <= d * d + eps


def validate_shortcut_coverage(barriers, points, entry_range, exit_range, apex_idx, sep_limit=None, apex_gap=0):
    """A pair is blocked if its straight trajectory crosses a barrier segment,
    OR passes exactly through a barrier vertex (graze). Grazes count as
    blocked: barrier vertices are centerline midpoints, so the exact
    entry->exit line through a vertex is a measure-zero trajectory — any
    float-realistic neighbor of it crosses a segment interior.

    When sep_limit is given, only pairs whose endpoints are within sep_limit of
    each other are tested. A straight line between two FAR points crosses the
    open end of the throat where the lanes have separated — it is not a
    drivable shortcut (a car would leave the track), so requiring the barrier
    to block it would force the barrier to over-extend into the median. The
    drivable shortcuts are exactly the short crossings within sep_limit.

    Pairs that fall entirely inside the apex gap (both endpoints within
    apex_gap indices of the apex) are skipped: that region is the merged apex
    road the racing line legitimately drives, and a crossing there hugs the
    apex and saves no meaningful distance. find_shortcuts.py is the
    authoritative check that no drivable shortcut survives the gap."""
    verts = {b[0] for b in barriers} | {b[1] for b in barriers}
    total, blocked, grazed, unblocked = 0, 0, 0, []
    for e in entry_range:
        for x in exit_range:
            if x <= e:
                continue
            if (apex_idx - e) <= apex_gap or (x - apex_idx) <= apex_gap:
                continue
            p_e, p_x = pt(points, e), pt(points, x)
            if sep_limit is not None and dist(p_e, p_x) > sep_limit:
                continue
            total += 1
            if any(segments_intersect(p_e, p_x, b[0], b[1]) for b in barriers):
                blocked += 1
            elif any(point_on_segment(v, p_e, p_x) for v in verts):
                blocked += 1
                grazed += 1
            else:
                unblocked.append((e, x))
    return blocked, total, unblocked, grazed


def segments_share_endpoint(s1, s2, eps=0.01):
    return any(dist(a, b) < eps for a in s1 for b in s2)


def validate_racing_line(barriers, points, idx_range, road_half_width, turn_direction, apex_idx=None, apex_exclusion=3):
    """Check that local-heading inner kerb path isn't blocked by barriers.

    Near the apex, local heading changes rapidly and the derived kerb positions
    wobble — not a real driving path. Skip indices within ±apex_exclusion of
    apex_idx where this discretization artifact would produce false positives.
    """
    kerb = [inner_kerb_point(points, i, road_half_width, turn_direction) for i in idx_range]
    fps = []
    for i in range(len(kerb) - 1):
        if apex_idx is not None:
            if abs(idx_range[i] - apex_idx) <= apex_exclusion or abs(idx_range[i + 1] - apex_idx) <= apex_exclusion:
                continue
        seg = (kerb[i], kerb[i + 1])
        for b in barriers:
            if segments_share_endpoint(seg, b):
                continue
            if segments_intersect(seg[0], seg[1], b[0], b[1]):
                fps.append((idx_range[i], idx_range[i + 1]))
                break
    return fps


def barriers_from_json(data):
    if "innerBarriers" not in data or not data["innerBarriers"]:
        return None
    result = []
    for b in data["innerBarriers"]:
        result.append((
            (b["start"]["x"], b["start"]["y"]),
            (b["end"]["x"], b["end"]["y"]),
        ))
    return result


COLLISION_HALF_WIDTH = 20.0   # GameConfig.collisionHalfWidth
MAX_STEP_PER_FRAME = 6.0       # maxSpeed 180 u/s / 30 fps
# A throat is shortcut-prone (tunnel-crossable) while the NEAREST-opposite-arm
# centerline separation <= 2*collisionHW + one max-speed frame. Past that, a
# single frame cannot jump the >collisionHW-from-both band and normal
# centerline collision already blocks the crossing — so no barrier is needed,
# and any barrier placed there would sit out in the off-track median between
# the separated lanes and poke out visually. This is the termination boundary.
SEP_LIMIT = 2 * COLLISION_HALF_WIDTH + MAX_STEP_PER_FRAME  # 46.0


def nearest_opposite(points, entry_idx, apex_idx, search_span=60):
    """Nearest exit-arm point (apex+1..apex+span) to entry_idx.
    Returns (exit_idx, separation)."""
    n = len(points)
    pe = pt(points, entry_idx)
    best_idx, best_sep = apex_idx, float("inf")
    for xo in range(1, search_span + 1):
        xi = (apex_idx + xo) % n
        d = dist(pe, pt(points, xi))
        if d < best_sep:
            best_idx, best_sep = xi, d
    return best_idx, best_sep


def crossable_extent(points, apex_idx, search_span=60, sep_limit=SEP_LIMIT):
    """Largest entry offset whose nearest-opposite separation <= sep_limit.

    This is the true extent of the shortcut-prone throat — where the two arms'
    collision corridors are close enough that a car (including one max-speed
    frame of tunneling) can slide between lanes. Beyond it the lanes have
    safely separated. Robust to asymmetric hairpins because it pairs each entry
    point with its actual nearest exit point, not the symmetric-index one.
    """
    last = 0
    for eo in range(1, search_span + 1):
        ei = (apex_idx - eo) % len(points)
        _, sep = nearest_opposite(points, ei, apex_idx, search_span)
        if sep <= sep_limit:
            last = eo
    return last


def infield_medial_barrier(points, apex_idx, gray_margin, sep_limit=SEP_LIMIT, search_span=60, spacing=3):
    """Barrier polyline down the throat's infield, with an apex gap.

    Vertices are midpoints between symmetric opposite-arm points (apex-eo,
    apex+eo). Symmetric pairing keeps the line on the throat's axis of symmetry
    (no drift toward either inner kerb). A vertex is KEPT only when:

      * it lies in the black infield, i.e. its distance to the nearest
        centerline is >= gray_margin (so it never sits on the drivable gray
        road, which extends roadHalfWidth from the centerline), and
      * it is within the crossable extent (nearest-opposite sep <= sep_limit),
        beyond which the lanes have separated and no barrier is needed.

    Near the apex the two arms' roads merge into one gray surface (no infield),
    so those offsets fail the gray_margin test and are skipped — leaving an
    apex gap. The racing line rounds the apex through that gap; crossings that
    sneak through it are right at the apex and save no meaningful distance
    (confirmed by scripts/find_shortcuts.py). The kept offsets form one
    contiguous run; it is resampled at `spacing` to keep the polyline light.
    """
    # +2 past the crossable extent seals asymmetric open-end crossings
    # (entry@extent -> exit@extent+1) a vertex exactly at the extent would miss.
    extent = crossable_extent(points, apex_idx, search_span, sep_limit)
    n = len(points)
    kept = []
    for eo in range(1, extent + 3):
        pe = pt(points, (apex_idx - eo) % n)
        px = pt(points, (apex_idx + eo) % n)
        mid = ((pe[0] + px[0]) / 2, (pe[1] + px[1]) / 2)
        if nearest_centerline_dist(mid, points) >= gray_margin:
            kept.append(eo)
    if len(kept) < 2:
        return [], []
    lo, hi = min(kept), max(kept)
    offsets = list(range(lo, hi + 1, spacing))
    if offsets[-1] != hi:
        offsets.append(hi)
    verts, labels = [], []
    for eo in offsets:
        ei = (apex_idx - eo) % n
        xi = (apex_idx + eo) % n
        pe, px = pt(points, ei), pt(points, xi)
        verts.append(((pe[0] + px[0]) / 2, (pe[1] + px[1]) / 2))
        labels.append((ei, xi))
    barriers = [(verts[i], verts[i + 1]) for i in range(len(verts) - 1)]
    return barriers, labels, lo


def measure_apex_gap(barriers, points, apex_idx, extent):
    """Largest offset g such that the symmetric apex crossing
    pt(apex-g)->pt(apex+g) is NOT blocked by any barrier — i.e. the open apex
    gap the barrier deliberately leaves for the racing line. Works for both
    freshly generated and already-stored barriers."""
    verts = {b[0] for b in barriers} | {b[1] for b in barriers}
    n = len(points)
    gap = 0
    for g in range(1, extent + 1):
        pe = pt(points, (apex_idx - g) % n)
        px = pt(points, (apex_idx + g) % n)
        blocked = any(segments_intersect(pe, px, b[0], b[1]) for b in barriers) \
            or any(point_on_segment(v, pe, px) for v in verts)
        if blocked:
            break
        gap = g
    return gap


def main():
    positional = [a for a in sys.argv[1:] if not a.startswith("--")]
    path = positional[0] if positional else "CrownPrix/CrownPrix Watch App/Resources/PreprocessedTracks/monaco.json"
    data = load_track(path)
    points = data["points"]
    road_half_width = data.get("roadHalfWidth", 16.0)

    print(f"Track: {path}")
    print(f"Points: {len(points)}, roadHalfWidth: {road_half_width}")

    apex_idx, apex_radius = find_hairpin_apex(points)
    print(f"Tightest curvature: idx={apex_idx}, radius={apex_radius:.2f}u")

    c = circumscribed_center(pt(points, apex_idx - 5), pt(points, apex_idx), pt(points, apex_idx + 5))
    print(f"Approximate center of curvature: ({c[0]:.2f}, {c[1]:.2f})")

    turn_direction = detect_turn_direction(points, apex_idx)
    print(f"Turn direction: {turn_direction}")

    extent = crossable_extent(points, apex_idx)
    print(f"Crossable throat extent: apex +/- {extent} (nearest-opposite sep <= {SEP_LIMIT:.0f}u)")
    # Barriers must stay off the gray road (drivable surface is roadHalfWidth
    # from the centerline); +2u keeps the 2u-wide debug line clear of the edge.
    gray_margin = road_half_width + 2
    # Validate/score over a window slightly wider than the crossable extent so a
    # too-short barrier would surface as unblocked pairs at the boundary.
    half_window = extent + 4
    start_idx, end_idx = hairpin_range(points, apex_idx, half_window=half_window)
    print(f"Hairpin index range: [{start_idx}..{end_idx}] (length {end_idx - start_idx + 1})")

    regen = "--regen" in sys.argv
    existing = None if regen else barriers_from_json(data)
    if existing:
        print(f"Found {len(existing)} existing innerBarriers — validating.")
        barriers = existing
    else:
        barriers, used_indices, _ = infield_medial_barrier(points, apex_idx, gray_margin=gray_margin)
        print(f"Computed {len(barriers)}-segment infield barrier; vertex pairs: {used_indices}.")

    apex_gap = measure_apex_gap(barriers, points, apex_idx, extent)
    print(f"Apex gap (open for racing line): apex +/- {apex_gap}")

    # Validations
    cross = validate_centerline_crossing(barriers, points)
    print(f"[1] Centerline crossings: {len(cross)}{' FAIL' if cross else ' PASS'}")
    if cross:
        print(f"    examples: {cross[:5]}")

    # Shortcut coverage grid — every drivable crossing (within sep_limit, outside
    # the apex gap) must be blocked. find_shortcuts.py is the authoritative gate
    # that no drivable shortcut survives the apex gap.
    entry_range = range(start_idx, apex_idx)
    exit_range = range(apex_idx + 1, end_idx + 1)
    blocked, total, unblocked, grazed = validate_shortcut_coverage(
        barriers, points, entry_range, exit_range, apex_idx, sep_limit=SEP_LIMIT, apex_gap=apex_gap)
    coverage = 100.0 * blocked / total if total else 0
    graze_note = f" ({grazed} via vertex-graze)" if grazed else ""
    print(f"[2] Shortcut coverage (outside apex gap): {blocked}/{total} = {coverage:.2f}%{graze_note}{' PASS' if coverage >= 100 else ' FAIL'}")
    if unblocked:
        print(f"    unblocked samples: {unblocked[:5]}")

    # Racing line false positives — strict: no apex exclusion. The barrier's
    # apex gap means even the wobble-prone apex kerb must be clear.
    line_range = list(range(start_idx, end_idx + 1))
    fps = validate_racing_line(barriers, points, line_range, road_half_width, turn_direction,
                               apex_idx=apex_idx, apex_exclusion=0)
    print(f"[3] Inner-kerb false positives: {len(fps)}{' FAIL' if fps else ' PASS'}")
    if fps:
        print(f"    examples: {fps[:5]}")

    # Output recommended JSON block
    print()
    print("Recommended innerBarriers JSON block:")
    print('  "innerBarriers" : [')
    for i, (s, e) in enumerate(barriers):
        comma = "," if i < len(barriers) - 1 else ""
        print(f'    {{ "start" : {{ "x" : {s[0]:.4f}, "y" : {s[1]:.4f} }}, "end" : {{ "x" : {e[0]:.4f}, "y" : {e[1]:.4f} }} }}{comma}')
    print("  ],")

    ok = (not cross) and coverage >= 100 and not fps
    print()
    print("OVERALL:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
