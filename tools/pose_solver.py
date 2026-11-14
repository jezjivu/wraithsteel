#!/usr/bin/env python3
"""Solve R15 arm angles instead of guessing them (pairs with tools/render_poses.py).

Angles follow AnimationConfig: shoulder {X, Y, Z} in UpperTorso space (vector rotated by Z, then
Y, then X), elbow X. Everything is in the UpperTorso frame (waist/root turn both arms alike).

  python3 tools/pose_solver.py arm R  dx dy dz         # shoulder angles pointing the arm along d
  python3 tools/pose_solver.py hand R  x y z [dx dy dz] # right hand at a point (+ blade direction)
  python3 tools/pose_solver.py grip  sx sy sz e  along  # left hand onto the held weapon `along`
                                                        # studs up the blade from the right grip
"""
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
sys.argv = sys.argv[:1] + ["luau"] + sys.argv[1:]  # render_poses reads argv[1] as the luau path
import render_poses as R  # noqa: E402

ARGS = sys.argv[2:]
CF, A = R.CF, R.angles
GRIP = CF((0, -0.15, 0)) * A([-125, 0, 0])  # keep in sync with WeaponConfig.GripRotation


def chain(side, sh, el):
    sx = 1 if side == "R" else -1
    up = CF((sx, 0.56, 0)) * A(sh) * CF((-0.5 * sx, 0.42, 0)).inv()
    lo = up * CF((0, -0.33, 0)) * A([el, 0, 0]) * CF((0, 0.26, 0)).inv()
    return lo * CF((0, -0.5, 0)) * CF((0, 0.13, 0)).inv()


def norm(v):
    m = math.sqrt(sum(x * x for x in v)) or 1
    return [x / m for x in v]


def grid(xs, ys, zs, es):
    for X in xs:
        for Y in ys:
            for Z in zs:
                for E in es:
                    yield [X, Y, Z], E


def arm(side, d):
    d = norm(d)
    best = None
    for sh, _ in grid(range(-60, 185, 5), range(-120, 181, 10), range(-80, 121, 10), [0]):
        v = R.mat_vec(A(sh).R, [0, -1, 0])
        err = math.degrees(math.acos(max(-1, min(1, sum(a * b for a, b in zip(v, d))))))
        cost = err + 0.08 * (abs(sh[1]) + abs(sh[2]) * 0.5)
        if best is None or cost < best[0]:
            best = (cost, sh, err)
    return best


def hand(side, target, d=None, seed=None, pull=0.004):
    """Best (error, shoulder, elbow) for a hand at `target` (optionally blade along d).
    `seed` = (shoulder, elbow) keeps the answer near an existing pose (smooth blends)."""
    best = None
    for sh, e in grid(range(-20, 181, 10), range(-120, 121, 15), range(-60, 91, 10), range(0, 131, 15)):
        h = chain(side, sh, e)
        err = math.dist(h.p, target)
        if seed:
            err += pull * (sum(abs(sh[i] - seed[0][i]) for i in range(3)) + abs(e - seed[1]))
        if d:
            g = h * GRIP
            bd = norm([g.point((0, 1, 0))[i] - g.p[i] for i in range(3)])
            err += 2 * (1 - sum(a * b for a, b in zip(bd, norm(d))))
        if best is None or err < best[0]:
            best = (err, sh, e)
    return best


def main():
    if not ARGS:
        print(__doc__)
        return
    mode = ARGS[0]
    if mode == "arm":
        print(arm(ARGS[1], [float(x) for x in ARGS[2:5]]))
    elif mode == "hand":
        t = [float(x) for x in ARGS[2:5]]
        d = [float(x) for x in ARGS[5:8]] if len(ARGS) >= 8 else None
        print(hand(ARGS[1], t, d))
    elif mode == "grip":
        sh = [float(x) for x in ARGS[1:4]]
        g = chain("R", sh, float(ARGS[4])) * GRIP
        along = float(ARGS[5])
        print(hand("L", g.point((0, along, 0))))


if __name__ == "__main__":
    main()
