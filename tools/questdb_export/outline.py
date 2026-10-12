"""
Outline of the ground one cluster of spawn points takes up.

Spawns with nothing between them are joined by a strip reaching MARGIN_YARDS
to either side, when the cluster links them or a disc DISC_YARDS across
could not pass between them. Then every gap and pocket too small for that
disc is filled in. A compact camp comes out as its rounded hull, a line of
spawns along a coast as a band, a ring of spawns round a lake as a ring with
the lake left out. (An endlessly large disc would give the convex hull.)

Worked out on a grid, exact where the outline crosses a grid line: grow the
strips by the disc's radius; grow the edge of that by the same radius; what
the second leaves of the first is the area. Where it came out long and
narrow, a strip of the plain margin and no more, the links there get a wider
strip laid over it (_widened): a share of the map's width, so the area reads
as one on the map of a large zone too. A last pair of passes takes a thin
rim off and puts it back, which rounds the sharp tips.

Two steps on the outline itself then take its details off. The dents the
disc only dipped into, with a mouth it cannot get through, and the ones
that are shallow or small beside the body of the area behind them are
levelled: the outline runs straight across them (_level). And the corners
this leaves are rounded: a curve reaching well along the side on either end
replaces each, as far as the spawn in the corner allows (_round).

build() returns the outline's rings (holes among them), the triangles that
fill it and a point inside it.
"""
from __future__ import annotations

import math
import sys

import numpy as np

# The disc that has to fit into a gap for the gap to stay open, across.
DISC_YARDS = 200.0
# How far the area reaches past its spawns.
MARGIN_YARDS = 25.0
# Spacing of the grid the outline is traced on.
GRID_YARDS = 5.0
# An outline vertex goes while the outline stays this close to it.
SIMPLIFY_YARDS = 0.5

# Nothing of the area is left narrower than twice this, or with a corner
# sharper than a circle of this radius.
TIP_YARDS = 10.0
# A dent of the outline shallower than this is levelled, whatever its width
# (one with a mouth the disc cannot get through is levelled anyway). So is
# a deeper one, up to the width strips are widened to, that is a detail of
# the area: no deeper than LEVEL_SHARE of its own width, nor than LEVEL_BODY
# of how far the area goes on behind it. (The inside of a bent strip is no
# detail: it is as deep as the strip is thick.)
LEVEL_YARDS = 40.0
LEVEL_SHARE = 0.25
LEVEL_BODY = 1 / 3

# A long stretch of the area is at least this share of its map's width
# across (a strip of the plain margin is a hairline on a large zone's map),
# though never wider than STRIP_MAX_YARDS, nor than STRIP_ASPECT of its own
# length: a short strip and a compact camp keep the plain margin.
STRIP_MAP_SHARE = 0.02
STRIP_MAX_YARDS = 90.0
STRIP_ASPECT = 0.5

# A corner of the outline is rounded off with a curve that reaches this
# share of the map's width along either side of it, though no more than
# ROUND_MAX_YARDS and never past the middle of a side. Rounding a corner
# brings the outline nearer to the spawn in it: never to less than
# KEEP_YARDS.
ROUND_MAP_SHARE = 0.02
ROUND_MAX_YARDS = 100.0
KEEP_YARDS = 15.0

# The same two for the edge of the grown strips, which only the second pass
# reads: it bends far more gently than the outline does.
_EDGE_GRID_YARDS = 10.0
_EDGE_SIMPLIFY_YARDS = 0.15
# A widened strip joins the rest of the area with no notch a circle of this
# radius cannot get into.
_JOIN_YARDS = 25.0
# The rounding keeps the spawns and points this far apart along their links
# inside. To it an edge of the outline this long is a side, and a run of
# shorter ones between two sides a corner unless it turns further than
# _TURN (radians): that is the end of a strip, or a patch's whole outline.
_KEEP_STEP_YARDS = 12.0
_SIDE_YARDS = 40.0
_TURN = 2.4
# Neighbours the quick pass of _links tries, and the size its batches stay under.
_NEAREST = 8
_BATCH = 4_000_000

# Marching squares: which grid edges of a cell the outline runs between, the
# masked side on its left. Corner bits: 1 lower left, 2 lower right, 4 upper
# right, 8 upper left; edges Bottom / Right / Top / Left. Two masked corners
# across a diagonal are kept apart.
_CELL_MOVES = {
    1: "BL", 2: "RB", 4: "TR", 8: "LT",
    3: "RL", 6: "TB", 12: "LR", 9: "BT",
    14: "LB", 13: "BR", 11: "RT", 7: "TL",
    5: "BLTR", 10: "RBLT",
}

sys.setrecursionlimit(max(sys.getrecursionlimit(), 20000))


def _links(pts, limit):
    """Index pairs of the points closer than `limit` that have no third point
    between them (inside the circle drawn on the pair as its diameter)."""
    n = len(pts)
    d2 = ((pts[:, None, :] - pts[None, :, :]) ** 2).sum(-1)
    a, b = np.nonzero(np.triu(d2 < limit * limit, 1))
    if not len(a):
        return a, b
    mid = (pts[a] + pts[b]) * 0.5
    rad2 = d2[a, b] * (0.25 * (1.0 - 1e-9))
    free = np.ones(len(a), bool)
    # Quick pass: one end's nearest neighbours rule most pairs out.
    if n > 4 * _NEAREST:
        near = np.argpartition(d2, _NEAREST, axis=1)[:, :_NEAREST + 1]
        step = _BATCH // (4 * _NEAREST)
        for s in range(0, len(a), step):
            c = slice(s, s + step)
            cand = pts[near[a[c]]]
            free[c] = ~(((cand - mid[c, None, :]) ** 2).sum(-1) < rad2[c, None]).any(1)
    left = np.nonzero(free)[0]
    step = max(1, _BATCH // (2 * n))
    for s in range(0, len(left), step):
        c = left[s:s + step]
        inside = ((mid[c, None, :] - pts[None, :, :]) ** 2).sum(-1) < rad2[c, None]
        free[c] = ~inside.any(1)
    return a[free], b[free]


def _spans(ax, ay, bx, by, r, c0, h, n, apart):
    """The stretches of the grid lines y = c0 + k*h (k < n) within r of the
    segments a-b, as arrays (line, lo, hi): merged and in order. `r` is one
    distance or one for each segment. `apart` is more than any stretch is
    long, to keep the lines apart while merging."""
    k0 = np.maximum(np.ceil((np.minimum(ay, by) - r - c0) / h), 0).astype(np.int64)
    k1 = np.minimum(np.floor((np.maximum(ay, by) + r - c0) / h), n - 1).astype(np.int64)
    cnt = np.maximum(k1 - k0 + 1, 0)
    seg = np.repeat(np.arange(len(ax)), cnt)
    line = np.arange(len(seg)) - np.repeat(np.cumsum(cnt) - cnt, cnt) + k0[seg]
    ax, ay, bx, by = ax[seg], ay[seg], bx[seg], by[seg]
    if np.ndim(r):
        r = r[seg]
    y = c0 + line * h

    # The two end discs.
    lo = np.full(len(seg), np.inf)
    hi = np.full(len(seg), -np.inf)
    for cx, cy in ((ax, ay), (bx, by)):
        w2 = r * r - (y - cy) ** 2
        ok = w2 >= 0
        w = np.sqrt(np.where(ok, w2, 0.0))
        lo = np.where(ok, np.minimum(lo, cx - w), lo)
        hi = np.where(ok, np.maximum(hi, cx + w), hi)

    # The rectangle between them: within the segment's length along it and
    # within r across it.
    dx, dy = bx - ax, by - ay
    len2 = dx * dx + dy * dy
    length = np.sqrt(len2)
    e = y - ay
    with np.errstate(divide="ignore", invalid="ignore"):
        p1, p2 = (-e * dy) / dx, (len2 - e * dy) / dx
        q1, q2 = (e * dx - r * length) / dy, (e * dx + r * length) / dy
    along = dx != 0
    across = dy != 0
    lo1 = np.where(along, np.minimum(p1, p2), -np.inf)
    hi1 = np.where(along, np.maximum(p1, p2), np.inf)
    lo2 = np.where(across, np.minimum(q1, q2), -np.inf)
    hi2 = np.where(across, np.maximum(q1, q2), np.inf)
    ok = (len2 > 0) & (along | ((e * dy >= 0) & (e * dy <= len2))) \
        & (across | (np.abs(e * dx) <= r * length))
    rlo, rhi = np.maximum(lo1, lo2), np.minimum(hi1, hi2)
    ok &= rlo <= rhi
    lo = np.where(ok, np.minimum(lo, ax + rlo), lo)
    hi = np.where(ok, np.maximum(hi, ax + rhi), hi)

    ok = lo <= hi
    line, lo, hi = line[ok], lo[ok], hi[ok]
    if not len(line):
        return line, lo, hi
    order = np.lexsort((lo, line))
    line, lo, hi = line[order], lo[order], hi[order]
    shift = line * apart
    reach = np.maximum.accumulate(hi + shift)
    first = np.ones(len(line), bool)
    first[1:] = lo[1:] + shift[1:] > reach[:-1]
    at = np.nonzero(first)[0]
    last = np.append(at[1:] - 1, len(line) - 1)
    return line[at], lo[at], reach[last] - shift[at]


def _crossings(base, step, lo, hi, c0, h, n):
    """Along grid lines of n nodes from c0: which stretches (lo, hi) cover a
    node, the first and last node each of those covers, and the places the
    covered state changes between two nodes as edge id -> coordinate. Edge k
    of a line has id base + step * k."""
    first = np.ceil((lo - c0) / h).astype(np.int64)
    last = np.floor((hi - c0) / h).astype(np.int64)
    ok = (first <= last) & (last >= 0) & (first <= n - 1)
    base, lo, hi, first, last = base[ok], lo[ok], hi[ok], first[ok], last[ok]
    up, down = first >= 1, last <= n - 2
    ids = np.concatenate((base[up] + step * (first[up] - 1), base[down] + step * last[down]))
    pos = np.concatenate((lo[up], hi[down]))
    # Two stretches that end between the same two nodes change nothing there.
    ids, where, times = np.unique(ids, return_index=True, return_counts=True)
    once = times == 1
    return ok, np.maximum(first, 0), np.minimum(last, n - 1), \
        dict(zip(ids[once].tolist(), pos[where[once]].tolist()))


def _cover(ax, ay, bx, by, r, grid):
    """The grid nodes within r of the segments a-b (one r, or one for each
    segment), and where the edge of that region crosses the grid's rows and
    its columns (edge id -> coordinate)."""
    x0, y0, nx, ny, h = grid
    apart = (max(nx, ny) + 4) * h + 4 * float(np.max(r))

    line, lo, hi = _spans(ax, ay, bx, by, r, y0, h, ny, apart)
    ok, first, last, hpos = _crossings(line * nx, 1, lo, hi, x0, h, nx)
    line = line[ok]
    diff = np.zeros(ny * (nx + 1), np.int32)
    np.add.at(diff, line * (nx + 1) + first, 1)
    np.add.at(diff, line * (nx + 1) + last + 1, -1)
    mask = diff.reshape(ny, nx + 1).cumsum(1)[:, :nx] > 0

    line, lo, hi = _spans(ay, ax, by, bx, r, x0, h, nx, apart)
    vpos = _crossings(line, nx, lo, hi, y0, h, ny)[3]
    return mask, hpos, vpos


def _trace(mask, hpos, vpos, grid):
    """The edge of the masked nodes: closed loops of points, the mask on the
    left of each (so counter-clockwise round it, clockwise round its holes)."""
    x0, y0, nx, ny, h = grid
    m = mask.astype(np.uint8)
    code = m[:-1, :-1] + 2 * m[:-1, 1:] + 4 * m[1:, 1:] + 8 * m[1:, :-1]
    ci, cj = np.nonzero((code > 0) & (code < 15))
    if not len(ci):
        return []
    code = code[ci, cj]
    base = ci * nx + cj
    rows = ny * nx      # ids below this are edges along a row, the rest up a column
    edge = {"B": base, "T": base + nx, "L": rows + base, "R": rows + base + 1}
    src, dst = [], []
    for c, moves in _CELL_MOVES.items():
        sel = code == c
        if sel.any():
            for k in range(0, len(moves), 2):
                src.append(edge[moves[k]][sel])
                dst.append(edge[moves[k + 1]][sel])
    step = dict(zip(np.concatenate(src).tolist(), np.concatenate(dst).tolist()))

    def point(e):
        if e < rows:
            x = hpos.get(e)
            return (x0 + (e % nx + 0.5) * h if x is None else x, y0 + (e // nx) * h)
        e -= rows
        y = vpos.get(e)
        return (x0 + (e % nx) * h, y0 + (e // nx + 0.5) * h if y is None else y)

    loops = []
    while step:
        start, e = step.popitem()
        loop = [point(start)]
        while e != start:
            loop.append(point(e))
            e = step.pop(e)
        loops.append(loop)
    return loops


def _simplify(ring, tolerance):
    """`ring` without the points it stays within `tolerance` of when they go.
    From each kept point the next one is the furthest the ring can jump to
    with every point skipped still that close to the jump's line."""
    n = len(ring)
    if n < 5:
        return ring
    out = [ring[0]]
    anchor = 0
    while anchor < n:
        ax, ay = ring[anchor]
        # The directions a jump from the anchor may still take, as a range of
        # turns from the first of them: each point passed narrows it.
        low, high, base = -math.inf, math.inf, None
        end = anchor + 1
        for k in range(anchor + 1, n + 1):
            px, py = ring[k % n]
            dx, dy = px - ax, py - ay
            d = math.hypot(dx, dy)
            if d <= tolerance:
                continue
            angle = math.atan2(dy, dx)
            if base is None:
                base = angle
            turn = (angle - base + math.pi) % (2 * math.pi) - math.pi
            if turn < low or turn > high or abs(turn) > 1.5:
                break
            end = k
            spread = math.asin(tolerance / d)
            low, high = max(low, turn - spread), min(high, turn + spread)
        if end < n:
            out.append(ring[end])
        anchor = end
    return out


def _area(ring):
    """Signed area: positive for a counter-clockwise ring."""
    total = 0.0
    px, py = ring[-1]
    for x, y in ring:
        total += px * y - x * py
        px, py = x, y
    return total / 2


def _inside(rings, x, y):
    """Whether (x, y) is inside the rings, a hole's ring taking it out again."""
    odd = False
    for ring in rings:
        px, py = ring[-1]
        for qx, qy in ring:
            if (py > y) != (qy > y) and x < px + (y - py) * (qx - px) / (qy - py):
                odd = not odd
            px, py = qx, qy
    return odd


def _level(ring, others, mouth, depth, shallow, wide):
    """`ring` (counter-clockwise, the area on its left) with its dents
    levelled. Where the outline bends into the area and comes back out, the
    straight line across the dent, resting on the outline at both ends,
    replaces it when the dent is no deeper than `shallow` behind that line,
    or no deeper than `depth` with the line no longer than `mouth`, or no
    deeper than `wide`, than LEVEL_SHARE of the line's length and than
    LEVEL_BODY of the area's reach behind the dent's bottom. `others` are
    the area's other rings: the line must stay clear of them, and they end
    the area's reach as this ring does."""
    n = len(ring)
    if n < 5:
        return ring
    nxt = list(range(1, n)) + [0]
    prv = [n - 1] + list(range(n - 1))
    alive = [True] * n
    left = n
    boxes = [(min(x for x, _ in r), min(y for _, y in r),
              max(x for x, _ in r), max(y for _, y in r)) for r in others]

    def bend(a, b, c):
        """Positive where the way a -> b -> c turns left (a corner of the
        area), negative where it turns into the area, 0 within half a degree
        of straight."""
        (ax, ay), (bx, by), (cx, cy) = ring[a], ring[b], ring[c]
        ux, uy, vx, vy = bx - ax, by - ay, cx - bx, cy - by
        cross = ux * vy - uy * vx
        if abs(cross) <= 0.0087 * math.hypot(ux, uy) * math.hypot(vx, vy):
            return 0.0
        return cross

    def crossed(px, py, qx, qy, a, b):
        """Whether the segment a-b cuts through the line p-q."""
        (ax, ay), (bx, by) = a, b
        d1 = (qx - px) * (ay - py) - (qy - py) * (ax - px)
        d2 = (qx - px) * (by - py) - (qy - py) * (bx - px)
        d3 = (bx - ax) * (py - ay) - (by - ay) * (px - ax)
        d4 = (bx - ax) * (qy - ay) - (by - ay) * (qx - ax)
        return d1 * d2 < 0 and d3 * d4 < 0

    def plain(width):
        """How deep a dent `width` across is levelled for that alone."""
        return depth if width <= mouth else shallow

    def body(ox, oy, ux, uy, p, q):
        """How far the area goes on from (ox, oy) along the unit vector u,
        the outline between p and q left out."""
        far = math.inf
        edges = []
        k = q
        while k != p:
            edges.append((ring[k], ring[nxt[k]]))
            k = nxt[k]
        for other in others:
            edges.extend(zip(other, other[1:] + other[:1]))
        for (ax, ay), (bx, by) in edges:
            ex, ey = bx - ax, by - ay
            den = ux * ey - uy * ex
            if den:
                t = ((ax - ox) * ey - (ay - oy) * ex) / den
                if 1e-6 < t < far and 0 <= ((ax - ox) * uy - (ay - oy) * ux) / den <= 1:
                    far = t
        return far

    def pocket(p, q):
        """The outline between p and q when the line p-q may replace it."""
        (px, py), (qx, qy) = ring[p], ring[q]
        dx, dy = qx - px, qy - py
        width = math.hypot(dx, dy)
        if not width:
            return None
        limit = max(plain(width), min(LEVEL_SHARE * width, wide))
        chain = []
        deep, bottom = 0.0, None
        k = nxt[p]
        while k != q:
            x, y = ring[k]
            behind = (dx * (y - py) - dy * (x - px)) / width
            if behind < -1e-6 or behind > limit:
                return None
            if behind > deep:
                deep, bottom = behind, (x, y)
            chain.append(k)
            k = nxt[k]
        if not chain:
            return None
        if deep > plain(width) and deep > LEVEL_BODY * body(*bottom, -dy / width, dx / width, p, q):
            return None
        # Nothing else of the outline, and no other part, may reach into the
        # dent or across its mouth.
        shape = [ring[p]] + [ring[k] for k in chain] + [ring[q]]
        x0, x1 = min(x for x, _ in shape), max(x for x, _ in shape)
        y0, y1 = min(y for _, y in shape), max(y for _, y in shape)
        k = q
        while k != p:
            a, b = ring[k], ring[nxt[k]]
            if k != q and x0 <= a[0] <= x1 and y0 <= a[1] <= y1 and _inside([shape], *a):
                return None
            if k != q and nxt[k] != p and crossed(px, py, qx, qy, a, b):
                return None
            k = nxt[k]
        for other, (ox0, oy0, ox1, oy1) in zip(others, boxes):
            if ox1 < x0 or ox0 > x1 or oy1 < y0 or oy0 > y1:
                continue
            last = other[-1]
            for point in other:
                if _inside([shape], *point) or crossed(px, py, qx, qy, last, point):
                    return None
                last = point
        return chain

    changed = True
    while changed and left >= 5:
        changed = False
        for i in range(n):
            if not alive[i] or left < 5 or bend(prv[i], i, nxt[i]) >= 0:
                continue
            # From the dent's bottom, widen the line across it until it rests
            # on the outline at both ends; give up once the bottom is further
            # behind it than any longer line may have it (each widening only
            # moves the line further out).
            p, q = prv[i], nxt[i]
            bx, by = ring[i]
            for _ in range(left - 3):
                if p == q or nxt[q] == p:
                    break
                (px, py), (qx, qy) = ring[p], ring[q]
                width = math.hypot(qx - px, qy - py)
                if not width or ((qx - px) * (by - py) - (qy - py) * (bx - px)) / width \
                        > max(plain(width), wide):
                    break
                if bend(prv[p], p, q) < 0:
                    p = prv[p]
                elif bend(p, q, nxt[q]) < 0:
                    q = nxt[q]
                else:
                    chain = pocket(p, q)
                    if chain:
                        for k in chain:
                            alive[k] = False
                        left -= len(chain)
                        nxt[p], prv[q] = q, p
                        changed = True
                    break
    return [ring[i] for i in range(n) if alive[i]]


def _earcut(pts, starts):
    """Triangles filling one polygon: `pts` holds its outer ring and then its
    holes, `starts` where each ring begins. Returns indices into pts, three a
    triangle. Mapbox's earcut (ISC licence) without its z-order index; `area`
    keeps earcut's sign, negative at a convex corner."""
    X, Y, I, PV, NX = [], [], [], [], []
    tris = []

    def insert(i, last):
        p = len(X)
        X.append(pts[i][0])
        Y.append(pts[i][1])
        I.append(i)
        if last is None:
            PV.append(p)
            NX.append(p)
        else:
            NX.append(NX[last])
            PV.append(last)
            PV[NX[last]] = p
            NX[last] = p
        return p

    def remove(p):
        NX[PV[p]] = NX[p]
        PV[NX[p]] = PV[p]

    def area(p, q, r):
        return (Y[q] - Y[p]) * (X[r] - X[q]) - (X[q] - X[p]) * (Y[r] - Y[q])

    def equals(p, q):
        return X[p] == X[q] and Y[p] == Y[q]

    def linked(start, end, clockwise):
        total = 0.0
        j = end - 1
        for i in range(start, end):
            total += (pts[j][0] - pts[i][0]) * (pts[i][1] + pts[j][1])
            j = i
        last = None
        order = range(start, end) if clockwise == (total > 0) else range(end - 1, start - 1, -1)
        for i in order:
            last = insert(i, last)
        if last is not None and equals(last, NX[last]):
            remove(last)
            last = NX[last]
        return last

    def filter_points(start, end=None):
        if start is None:
            return start
        if end is None:
            end = start
        p = start
        while True:
            again = False
            if equals(p, NX[p]) or area(PV[p], p, NX[p]) == 0:
                remove(p)
                p = end = PV[p]
                if p == NX[p]:
                    break
                again = True
            else:
                p = NX[p]
            if not again and p == end:
                break
        return end

    def in_triangle(ax, ay, bx, by, cx, cy, px, py):
        return (cx - px) * (ay - py) >= (ax - px) * (cy - py) \
            and (ax - px) * (by - py) >= (bx - px) * (ay - py) \
            and (bx - px) * (cy - py) >= (cx - px) * (by - py)

    def is_ear(ear):
        a, c = PV[ear], NX[ear]
        if area(a, ear, c) >= 0:
            return False
        ax, ay, bx, by, cx, cy = X[a], Y[a], X[ear], Y[ear], X[c], Y[c]
        x0, x1 = min(ax, bx, cx), max(ax, bx, cx)
        y0, y1 = min(ay, by, cy), max(ay, by, cy)
        p = NX[c]
        while p != a:
            px, py = X[p], Y[p]
            if x0 <= px <= x1 and y0 <= py <= y1 \
                    and in_triangle(ax, ay, bx, by, cx, cy, px, py) \
                    and area(PV[p], p, NX[p]) >= 0:
                return False
            p = NX[p]
        return True

    def sign(v):
        return (v > 0) - (v < 0)

    def on_segment(p, q, r):
        return min(X[p], X[r]) <= X[q] <= max(X[p], X[r]) \
            and min(Y[p], Y[r]) <= Y[q] <= max(Y[p], Y[r])

    def intersects(p1, q1, p2, q2):
        o1, o2 = sign(area(p1, q1, p2)), sign(area(p1, q1, q2))
        o3, o4 = sign(area(p2, q2, p1)), sign(area(p2, q2, q1))
        if o1 != o2 and o3 != o4:
            return True
        return (o1 == 0 and on_segment(p1, p2, q1)) or (o2 == 0 and on_segment(p1, q2, q1)) \
            or (o3 == 0 and on_segment(p2, p1, q2)) or (o4 == 0 and on_segment(p2, q1, q2))

    def intersects_polygon(a, b):
        p = a
        while True:
            n = NX[p]
            if I[p] != I[a] and I[n] != I[a] and I[p] != I[b] and I[n] != I[b] \
                    and intersects(p, n, a, b):
                return True
            p = n
            if p == a:
                return False

    def locally_inside(a, b):
        if area(PV[a], a, NX[a]) < 0:
            return area(a, b, NX[a]) >= 0 and area(a, PV[a], b) >= 0
        return area(a, b, PV[a]) < 0 or area(a, NX[a], b) < 0

    def middle_inside(a, b):
        px, py = (X[a] + X[b]) / 2, (Y[a] + Y[b]) / 2
        p, inside = a, False
        while True:
            n = NX[p]
            if (Y[p] > py) != (Y[n] > py) and Y[n] != Y[p] \
                    and px < (X[n] - X[p]) * (py - Y[p]) / (Y[n] - Y[p]) + X[p]:
                inside = not inside
            p = n
            if p == a:
                return inside

    def valid_diagonal(a, b):
        if I[NX[a]] == I[b] or I[PV[a]] == I[b] or intersects_polygon(a, b):
            return False
        if locally_inside(a, b) and locally_inside(b, a) and middle_inside(a, b) \
                and (area(PV[a], a, PV[b]) != 0 or area(a, PV[b], b) != 0):
            return True
        return equals(a, b) and area(PV[a], a, NX[a]) > 0 and area(PV[b], b, NX[b]) > 0

    def split_polygon(a, b):
        a2 = len(X)
        b2 = a2 + 1
        X.extend((X[a], X[b]))
        Y.extend((Y[a], Y[b]))
        I.extend((I[a], I[b]))
        after, before = NX[a], PV[b]
        NX[a] = b
        PV[b] = a
        NX.extend((after, a2))
        PV.extend((b2, before))
        PV[after] = a2
        NX[before] = b2
        return b2

    def cure(start):
        p = start
        while True:
            a, b = PV[p], NX[NX[p]]
            if not equals(a, b) and intersects(a, p, NX[p], b) \
                    and locally_inside(a, b) and locally_inside(b, a):
                tris.extend((I[a], I[p], I[b]))
                remove(p)
                remove(NX[p])
                p = start = b
            p = NX[p]
            if p == start:
                break
        return filter_points(p)

    def split(start):
        a = start
        while True:
            b = NX[NX[a]]
            while b != PV[a]:
                if I[a] != I[b] and valid_diagonal(a, b):
                    c = split_polygon(a, b)
                    a = filter_points(a, NX[a])
                    c = filter_points(c, NX[c])
                    clip(a, 0)
                    clip(c, 0)
                    return
                b = NX[b]
            a = NX[a]
            if a == start:
                return

    def clip(ear, attempt):
        if ear is None:
            return
        stop = ear
        while PV[ear] != NX[ear]:
            before, after = PV[ear], NX[ear]
            if is_ear(ear):
                tris.extend((I[before], I[ear], I[after]))
                remove(ear)
                ear = stop = NX[after]
                continue
            ear = after
            if ear == stop:
                if attempt == 0:
                    clip(filter_points(ear), 1)
                elif attempt == 1:
                    clip(cure(filter_points(ear)), 2)
                else:
                    split(ear)
                return

    def leftmost(start):
        p = left = start
        while True:
            if X[p] < X[left] or (X[p] == X[left] and Y[p] < Y[left]):
                left = p
            p = NX[p]
            if p == start:
                return left

    def hole_bridge(hole, outer):
        hx, hy = X[hole], Y[hole]
        qx, m = -math.inf, None
        p = outer
        while True:
            n = NX[p]
            if Y[p] >= hy >= Y[n] and Y[n] != Y[p]:
                x = X[p] + (hy - Y[p]) * (X[n] - X[p]) / (Y[n] - Y[p])
                if qx < x <= hx:
                    qx = x
                    m = p if X[p] < X[n] else n
                    if x == hx:
                        return m
            p = n
            if p == outer:
                break
        if m is None:
            return None
        stop, mx, my = m, X[m], Y[m]
        best = math.inf
        p = m
        while True:
            if hx >= X[p] >= mx and hx != X[p] and in_triangle(
                    hx if hy < my else qx, hy, mx, my, qx if hy < my else hx, hy, X[p], Y[p]):
                tan = abs(hy - Y[p]) / (hx - X[p])
                if locally_inside(p, hole) and (tan < best or (tan == best and (
                        X[p] > X[m] or (X[p] == X[m]
                                        and area(PV[m], m, PV[p]) < 0
                                        and area(NX[p], m, NX[m]) < 0)))):
                    m, best = p, tan
            p = NX[p]
            if p == stop:
                return m

    ends = starts[1:] + [len(pts)]
    outer = linked(starts[0], ends[0], True)
    if outer is None or NX[outer] == PV[outer]:
        return tris
    holes = [leftmost(linked(s, e, False)) for s, e in zip(starts[1:], ends[1:])]
    for hole in sorted(holes, key=lambda p: X[p]):
        bridge = hole_bridge(hole, outer)
        if bridge is not None:
            back = split_polygon(bridge, hole)
            filter_points(back, NX[back])
            outer = filter_points(bridge, NX[bridge])
    clip(outer, 0)
    return tris


def _grid(pts, reach, h):
    """A grid of spacing h over the points and `reach` round them:
    (x0, y0, columns, rows, h). The odd offsets keep an outline from running
    exactly through a node."""
    x0 = float(pts[:, 0].min()) - reach - 2.37 * h
    y0 = float(pts[:, 1].min()) - reach - 2.61 * h
    nx = int(math.ceil((float(pts[:, 0].max()) + reach + 2 * h - x0) / h)) + 1
    ny = int(math.ceil((float(pts[:, 1].max()) + reach + 2 * h - y0) / h)) + 1
    return x0, y0, nx, ny, h


def _resample(mask, grid, onto):
    """`mask` of `grid` read at the nodes of the grid `onto` (nearest node)."""
    x0, y0, nx, ny, h = grid
    fx, fy, fnx, fny, fh = onto
    col = np.clip(np.rint((fx + np.arange(fnx) * fh - x0) / h).astype(np.int64), 0, nx - 1)
    row = np.clip(np.rint((fy + np.arange(fny) * fh - y0) / h).astype(np.int64), 0, ny - 1)
    return mask[np.ix_(row, col)]


def _segments(loops):
    """The closed loops as one set of segments: arrays ax, ay, bx, by."""
    a = np.array([p for loop in loops for p in loop])
    b = np.array([p for loop in loops for p in loop[1:] + loop[:1]])
    return a[:, 0], a[:, 1], b[:, 0], b[:, 1]


def _within(edge, px, py):
    """Which of the points p are inside the outline `edge` (its segments)."""
    ax, ay, bx, by = edge
    out = np.empty(len(px), bool)
    step = max(1, _BATCH // (4 * len(ax)))
    for s in range(0, len(px), step):
        c = slice(s, s + step)
        y = py[c, None]
        with np.errstate(divide="ignore", invalid="ignore"):
            cross = ((ay > y) != (by > y)) & (px[c, None] < ax + (y - ay) * (bx - ax) / (by - ay))
        out[c] = cross.sum(1) % 2 == 1
    return out


def _fill(pts, a, b, room):
    """Passes 1 and 2: the strips round the links a-b (a lone spawn is a link
    of no length), with every gap too small for the disc filled in. Returns
    the masked nodes of a grid reaching `room` past the spawns, where the
    area's edge crosses the grid's rows and its columns, and the grid."""
    radius = DISC_YARDS / 2

    # Pass 1: the links grown by the margin and the disc's radius.
    coarse = _grid(pts, MARGIN_YARDS + radius, _EDGE_GRID_YARDS)
    grown, hpos, vpos = _cover(pts[a, 0], pts[a, 1], pts[b, 0], pts[b, 1],
                               MARGIN_YARDS + radius, coarse)
    edge = [_simplify(loop, _EDGE_SIMPLIFY_YARDS) for loop in _trace(grown, hpos, vpos, coarse)]

    # Pass 2: whatever is within the disc's radius of that edge goes again.
    # The area keeps well clear of the edge, so the coarse grid is enough to
    # tell its inside from the open ground beyond.
    grid = _grid(pts, room, GRID_YARDS)
    band, hpos, vpos = _cover(*_segments(edge), radius, grid)
    return _resample(grown, coarse, grid) & ~band, hpos, vpos, grid


def _chords(loops, px, py, dx, dy):
    """How far the outline `loops` is from each point p, going the way of the
    unit vector d and going against it."""
    ax, ay, bx, by = _segments(loops)
    ex, ey = bx - ax, by - ay
    ahead = np.full(len(px), np.inf)
    behind = np.full(len(px), np.inf)
    step = max(1, _BATCH // (4 * len(ax)))
    for s in range(0, len(px), step):
        c = slice(s, s + step)
        # p + t * d = a + u * e, for every point against every segment.
        wx, wy = ax[None, :] - px[c, None], ay[None, :] - py[c, None]
        den = dx[c, None] * ey[None, :] - dy[c, None] * ex[None, :]
        with np.errstate(divide="ignore", invalid="ignore"):
            t = (wx * ey[None, :] - wy * ex[None, :]) / den
            u = (wx * dy[c, None] - wy * dx[c, None]) / den
        hit = (den != 0) & (u >= 0) & (u < 1)
        ahead[c] = np.where(hit & (t > 0), t, np.inf).min(1)
        behind[c] = np.where(hit & (t < 0), -t, np.inf).min(1)
    return ahead, behind


def _widened(pts, a, b, loops, least):
    """The margin each link a-b needs for the area to be `least` across it.
    `loops` is the area with every link at MARGIN_YARDS: how wide that is
    across the link, at three places along it, is what the link's strip has
    to make up for. The width asked for is no more than STRIP_ASPECT of the
    length of the run of linked spawns the link belongs to."""
    # The runs of linked spawns, and how long each is from corner to corner.
    run = list(range(len(pts)))

    def find(i):
        while run[i] != i:
            run[i] = run[run[i]]
            i = run[i]
        return i

    for i, j in zip(a.tolist(), b.tolist()):
        run[find(i)] = find(j)
    run = np.array([find(i) for i in range(len(pts))])
    low = np.full(pts.shape, np.inf)
    high = np.full(pts.shape, -np.inf)
    np.minimum.at(low, run, pts)
    np.maximum.at(high, run, pts)
    span = np.hypot(*(high - low)[run[a]].T) + 2 * MARGIN_YARDS

    px, py = pts[a, 0], pts[a, 1]
    dx, dy = pts[b, 0] - px, pts[b, 1] - py
    length = np.hypot(dx, dy)
    at = np.array((0.25, 0.5, 0.75))[:, None]
    ahead, behind = _chords(loops, (px + at * dx).ravel(), (py + at * dy).ravel(),
                            np.tile(-dy / length, 3), np.tile(dx / length, 3))
    across = (ahead + behind).reshape(3, -1).min(0)
    wanted = np.minimum(least, STRIP_ASPECT * span)
    return np.clip(MARGIN_YARDS + (wanted - across) / 2, MARGIN_YARDS, least / 2)


def _away(edge, px, py):
    """How far each point p is from the nearest of the segments `edge`."""
    ax, ay, bx, by = (v[None, :] for v in edge)
    ex, ey = bx - ax, by - ay
    wx, wy = px[:, None] - ax, py[:, None] - ay
    t = np.clip((wx * ex + wy * ey) / np.maximum(ex * ex + ey * ey, 1e-12), 0.0, 1.0)
    return np.hypot(wx - t * ex, wy - t * ey).min(1)


def _crosses(edge, other):
    """Whether any of the segments `edge` cuts through one of `other`."""
    ax, ay, bx, by = (v[:, None] for v in edge)
    cx, cy, dx, dy = (v[None, :] for v in other)
    d1 = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
    d2 = (bx - ax) * (dy - ay) - (by - ay) * (dx - ax)
    d3 = (dx - cx) * (ay - cy) - (dy - cy) * (ax - cx)
    d4 = (dx - cx) * (by - cy) - (dy - cy) * (bx - cx)
    return bool(((d1 * d2 < 0) & (d3 * d4 < 0)).any())


def _blend(a, d1, t1, b, d2, t2):
    """A curve (its points) from the point t1 back from `a` against the
    direction d1 to the point t2 on from `b` along d2, leaving along d1 and
    arriving along d2: close to an arc where the two sides carried on meet
    between its ends, an S-bend where they do not."""
    x0, y0 = a[0] - t1 * d1[0], a[1] - t1 * d1[1]
    x3, y3 = b[0] + t2 * d2[0], b[1] + t2 * d2[1]
    wx, wy = x3 - x0, y3 - y0
    span = math.hypot(wx, wy)
    h1 = h2 = span / 3
    den = d1[0] * d2[1] - d1[1] * d2[0]
    if abs(den) > 1e-6:
        # How far on from the curve's ends the sides meet.
        s1 = (wx * d2[1] - wy * d2[0]) / den
        s2 = (d1[0] * wy - d1[1] * wx) / den
        if 0 < s1 < 1.5 * span and 0 < s2 < 1.5 * span:
            angle = math.atan2(abs(den), d1[0] * d2[0] + d1[1] * d2[1])
            k = 4 / 3 * math.tan(angle / 4) / math.tan(angle / 2)
            h1, h2 = k * s1, k * s2
    x1, y1 = x0 + h1 * d1[0], y0 + h1 * d1[1]
    x2, y2 = x3 - h2 * d2[0], y3 - h2 * d2[1]
    # As many pieces as keep each within SIMPLIFY_YARDS of the curve: it
    # bows three quarters as far from its ends' line as its handles do.
    off = max(abs((x1 - x0) * wy - (y1 - y0) * wx), abs((x2 - x0) * wy - (y2 - y0) * wx)) \
        / max(span, 1e-9)
    count = max(1, math.ceil(math.sqrt(0.75 * off / SIMPLIFY_YARDS)))
    curve = []
    for k in range(count + 1):
        u = k / count
        v = 1 - u
        c0, c1, c2, c3 = v * v * v, 3 * v * v * u, 3 * v * u * u, u * u * u
        curve.append((c0 * x0 + c1 * x1 + c2 * x2 + c3 * x3, c0 * y0 + c1 * y1 + c2 * y2 + c3 * y3))
    return curve


def _round(rings, pts, a, b, reach):
    """The rings (in yards, the area on the left of each) with their corners
    rounded. A ring is taken as its sides, the edges _SIDE_YARDS long or
    longer, and the runs of shorter edges between them. A run that turns no
    further than _TURN goes, and with it up to `reach` of the side on either
    end of it (never more than half the side): a curve leaving the one side
    and joining the other takes their place (_blend). The curve is shortened
    until it leaves the spawns `pts` and their links a-b KEEP_YARDS inside,
    strays no further than LEVEL_YARDS from the run it replaces and keeps
    clear of the rest of the outline; a run no curve can replace stays as it
    is."""
    # The points to keep: the spawns and points along their links.
    dx, dy = pts[b, 0] - pts[a, 0], pts[b, 1] - pts[a, 1]
    n = np.maximum(np.ceil(np.hypot(dx, dy) / _KEEP_STEP_YARDS).astype(np.int64), 1) - 1
    link = np.repeat(np.arange(len(a)), n)
    part = (np.arange(len(link)) - np.repeat(np.cumsum(n) - n, n) + 1) / (n[link] + 1)
    kx = np.concatenate((pts[:, 0], pts[a[link], 0] + part * dx[link]))
    ky = np.concatenate((pts[:, 1], pts[a[link], 1] + part * dy[link]))

    edges = _segments(rings)
    owner = np.concatenate([np.full(len(ring), r) for r, ring in enumerate(rings)])
    place = np.concatenate([np.arange(len(ring)) for ring in rings])

    def clear(r, i, j, curve, run):
        """Whether `curve` may take the place of `run` and the ends of the
        sides i and j of ring r it leaves from and arrives on."""
        zone = _segments([curve + run[::-1]])
        line = tuple(np.array(v) for v in zip(*((p[0], p[1], q[0], q[1])
                                               for p, q in zip(curve, curve[1:]))))
        if _away(line, np.array([p[0] for p in run]), np.array([p[1] for p in run])).max() \
                > LEVEL_YARDS:
            return False
        x0, x1 = zone[0].min() - KEEP_YARDS, zone[0].max() + KEEP_YARDS
        y0, y1 = zone[1].min() - KEEP_YARDS, zone[1].max() + KEEP_YARDS
        near = (kx > x0) & (kx < x1) & (ky > y0) & (ky < y1)
        if near.any() and (_within(zone, kx[near], ky[near]).any()
                           or (_away(line, kx[near], ky[near]) < KEEP_YARDS).any()):
            return False
        # The rest of the outline: every edge but the sides and the run.
        size = len(rings[r])
        ax, ay, bx, by = edges
        rest = ((owner != r) | ((place - i) % size > (j - i) % size)) \
            & (np.maximum(ax, bx) > x0) & (np.minimum(ax, bx) < x1) \
            & (np.maximum(ay, by) > y0) & (np.minimum(ay, by) < y1)
        if rest.any():
            rest = tuple(v[rest] for v in edges)
            if _within(zone, rest[0], rest[1]).any() or _crosses(line, rest):
                return False
        return True

    out = []
    for r, ring in enumerate(rings):
        size = len(ring)
        side = [math.hypot(ring[(i + 1) % size][0] - ring[i][0],
                           ring[(i + 1) % size][1] - ring[i][1]) for i in range(size)]
        sides = [i for i in range(size) if side[i] >= _SIDE_YARDS]
        if len(sides) < 2:
            out.append(ring)
            continue
        new = []
        for k, i in enumerate(sides):
            j = sides[(k + 1) % len(sides)]
            run = [ring[(i + 1 + v) % size] for v in range((j - i - 1) % size + 1)]
            way = [ring[i]] + run + [ring[(j + 1) % size]]
            turn = 0.0
            for (px, py), (qx, qy), (sx, sy) in zip(way, way[1:], way[2:]):
                turn += math.atan2((qx - px) * (sy - qy) - (qy - py) * (sx - qx),
                                   (qx - px) * (sx - qx) + (qy - py) * (sy - qy))
            curve = None
            if abs(turn) <= _TURN:
                d1 = ((run[0][0] - ring[i][0]) / side[i], (run[0][1] - ring[i][1]) / side[i])
                d2 = ((way[-1][0] - run[-1][0]) / side[j], (way[-1][1] - run[-1][1]) / side[j])
                for share in (1.0, 0.75, 0.56, 0.42, 0.32, 0.24, 0.18, 0.13):
                    curve = _blend(run[0], d1, share * min(side[i] / 2, reach),
                                   run[-1], d2, share * min(side[j] / 2, reach))
                    if clear(r, i, j, curve, run):
                        break
                    curve = None
            for p in curve or run:
                if not new or math.hypot(p[0] - new[-1][0], p[1] - new[-1][1]) > 1e-6:
                    new.append(p)
        if len(new) > 1 and math.hypot(new[0][0] - new[-1][0], new[0][1] - new[-1][1]) <= 1e-6:
            new.pop()
        out.append(new)
    return out


def _rings(loops, size, snap, tolerance):
    """The loops (in yards) as rings to store: simplified to `tolerance`
    (0 leaves them as they are) and on the stored coordinates, each as
    [normalized, yards], the parts' rings apart from the holes'. A lone
    spawn's patch is the smallest part there can be, and a hole has room for
    a disc: anything well under that is a sliver of the grid and left out."""
    width, height = size
    sliver = math.pi * MARGIN_YARDS ** 2 / 2
    outers, holes = [], []
    for loop in loops:
        ring = []
        for x, y in (_simplify(loop, tolerance) if tolerance else loop):
            p = (snap(x / width), snap(y / height))
            if not ring or p != ring[-1]:
                ring.append(p)
        if len(ring) > 1 and ring[0] == ring[-1]:
            ring.pop()
        if len(ring) < 3:
            continue
        yards = [(x * width, y * height) for x, y in ring]
        extent = _area(yards)
        if extent >= sliver:
            outers.append([ring, yards])
        elif extent <= -sliver:
            holes.append([ring, yards])
    return outers, holes


def _triangles(outers, holes):
    """The rings (as _rings gives them) in the order they are stored, every
    part's ring followed by the rings of its holes; the same in yards; and
    the triangles that fill them, as indices into the rings' points taken
    together. Raises ValueError where the triangles do not cover the outline
    exactly, which is what a ring crossing itself or another comes to."""
    parts = sorted(((_area(yards), ring, yards, []) for ring, yards in outers),
                   key=lambda o: o[0])
    for ring, yards in holes:
        for part in parts:          # smallest first: the one it sits in directly
            if _inside([part[2]], *yards[0]):
                part[3].append((ring, yards))
                break

    rings, yard_rings, triangles = [], [], []
    for extent, ring, yards, inner in reversed(parts):
        base = sum(len(r) for r in rings)
        flat, starts = [], []
        for r, y in [(ring, yards)] + inner:
            starts.append(len(flat))
            flat.extend(y)
            rings.append(r)
            yard_rings.append(y)
        extent += sum(_area(y) for _, y in inner)
        tris = _earcut(flat, starts)
        filled = sum(abs(_area([flat[tris[k]], flat[tris[k + 1]], flat[tris[k + 2]]]))
                     for k in range(0, len(tris), 3))
        if abs(filled - extent) > 1e-6 * extent + 1e-6:
            raise ValueError("triangles cover %.3f of an outline of %.3f sq yards"
                             % (filled, extent))
        triangles.extend(base + t for t in tris)
    return rings, yard_rings, triangles


def build(points, size, link_yards, snap):
    """The area of one cluster: `points` are its spawns in normalized map
    coordinates, `size` the map's (width, height) in yards and `link_yards`
    the distance its spawns are linked at. `snap` rounds a normalized
    coordinate to what gets stored.

    Returns (rings, triangles, centre), all normalized. A ring is a list of
    (x, y); every outer ring is followed by the rings of its holes. Triangles
    are indices into the rings' points taken together, three a triangle, made
    from the snapped points. Centre is the mean of the spawns, or the spawn
    nearest to it when the mean itself falls outside the area."""
    width, height = size
    scale = np.array((width, height), float)
    pts = np.unique(np.array(points, float) * scale, axis=0)

    # The links, a lone spawn going in as a link of no length. Spawns the
    # disc cannot pass between are linked too, further apart than the
    # cluster's own links though they be.
    a, b = _links(pts, max(link_yards, DISC_YARDS + 2 * MARGIN_YARDS))
    lone = np.ones(len(pts), bool)
    lone[a] = lone[b] = False
    lone = np.nonzero(lone)[0]

    # Passes 1 and 2. Where strips may be widened the grid has room for them
    # and for pass 3: a whole number of cells more, which keeps its lines
    # where they are, clear of the coarse grid's.
    least = min(max(STRIP_MAP_SHARE * width, 2 * MARGIN_YARDS), STRIP_MAX_YARDS)
    widen = len(a) > 0 and least > 2 * MARGIN_YARDS
    room = MARGIN_YARDS
    if widen:
        room = math.ceil((least / 2 + _JOIN_YARDS) / GRID_YARDS) * GRID_YARDS
    area, hpos, vpos, grid = _fill(pts, np.concatenate((a, lone)), np.concatenate((b, lone)), room)
    loops = _trace(area, hpos, vpos, grid)

    # Pass 3: the links the area came out long and narrow across get their
    # wider strip. Area and strips are grown together by _JOIN_YARDS, which
    # the next pass takes off again: the two become one with no notch where
    # a strip leaves the area or bends, and no gap the disc had room in is
    # closed.
    # (Every pass from here on takes its loops as traced: simplified, two
    # points on one grid line can become a segment along it, and the edge
    # would come back to rest on that line, where a node is neither in nor
    # out.)
    shave = TIP_YARDS
    if widen:
        margin = _widened(pts, a, b, [_simplify(loop, SIMPLIFY_YARDS) for loop in loops], least)
        wide = np.nonzero(margin > MARGIN_YARDS + 1.0)[0]
        if len(wide):
            ax, ay, bx, by = _segments(loops)
            more, hpos, vpos = _cover(
                np.concatenate((ax, pts[a[wide], 0])), np.concatenate((ay, pts[a[wide], 1])),
                np.concatenate((bx, pts[b[wide], 0])), np.concatenate((by, pts[b[wide], 1])),
                np.concatenate((np.full(len(ax), _JOIN_YARDS), margin[wide] + _JOIN_YARDS)), grid)
            area |= more
            loops = _trace(area, hpos, vpos, grid)
            shave += _JOIN_YARDS

    # Passes 4 and 5: a rim of TIP_YARDS comes off and goes back on. What
    # was narrower than the rim is gone for good, and with it the spikes left
    # where the disc came at one stretch of the area from two sides.
    rim, hpos, vpos = _cover(*_segments(loops), shave, grid)
    core = area & ~rim
    edge = _trace(core, hpos, vpos, grid)
    if edge:
        rim, hpos, vpos = _cover(*_segments(edge), TIP_YARDS, grid)
        loops = _trace(core | rim, hpos, vpos, grid)

    # Level the dents of each part's outline that the disc only dipped into
    # (a mouth it cannot get through where the strips are their widened
    # width, no deeper than it reaches) and the shallow ones. Round a hole
    # only the plainly shallow ones go: the disc is in there, and what it
    # dips into is the hole itself.
    outers, holes = _rings(loops, size, snap, SIMPLIFY_YARDS)
    mouth = DISC_YARDS + least
    for part in outers:
        part[1] = _level(part[1], [o[1] for o in outers + holes if o is not part],
                         mouth, mouth / 2, LEVEL_YARDS, least)
    for part in holes:
        part[1] = _level(part[1], [o[1] for o in outers], 0.0, 0.0, LEVEL_YARDS, 0.0)
    for part in outers + holes:
        part[0] = [(snap(x / width), snap(y / height)) for x, y in part[1]]

    # Round the corners that leaves. Should a rounded outline ever cross
    # itself, the levelled one is stored.
    try:
        rings, yard_rings, triangles = _triangles(*_rings(
            _round([yards for _, yards in outers + holes], pts, a, b,
                   min(ROUND_MAP_SHARE * width, ROUND_MAX_YARDS)), size, snap, 0))
    except ValueError:
        rings, yard_rings, triangles = _triangles(outers, holes)

    mean = np.array(points, float).mean(0) * scale
    if not _inside(yard_rings, mean[0], mean[1]):
        mean = pts[((pts - mean) ** 2).sum(1).argmin()]
    return rings, triangles, (float(mean[0]) / width, float(mean[1]) / height)
