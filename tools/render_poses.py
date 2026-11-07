#!/usr/bin/env python3
"""Preview the procedural combat poses (AnimationConfig) as stick figures, without Studio.

Dumps AnimationConfig (stances, style stances, move styles, flavors) through the Luau CLI, then
runs a small forward-kinematics model of an R15 body (same joint conventions as
AnimationController: degrees {x, y, z} = CFrame.Angles, +X swings a limb forward, -X on a knee
bends it, root entries 4-6 are studs) and draws front + side views.

It approximates Roblox (stand-in limb lengths, weapon drawn along the forearm), good enough to
see whether a stance reads, whether arms/legs bend the right way and how styles differ.

Usage: python3 tools/render_poses.py path/to/luau [out.png]
"""
import json
import math
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from run_tests import build_bundle  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "build" / "poses.png"

SPEC = """
local function enc(v)
	if type(v) == "table" then
		local n = #v
		if n > 0 then
			local parts = {}
			for i = 1, n do parts[i] = enc(v[i]) end
			return "[" .. table.concat(parts, ",") .. "]"
		end
		local parts = {}
		for k, x in v do
			if type(x) ~= "function" then
				table.insert(parts, string.format("%q:%s", tostring(k), enc(x)))
			end
		end
		return "{" .. table.concat(parts, ",") .. "}"
	elseif type(v) == "number" then
		return string.format("%.4f", v)
	elseif type(v) == "boolean" then
		return tostring(v)
	elseif type(v) == "string" then
		return string.format("%q", v)
	end
	return "null"
end
local cases = {}
cases["dump"] = function()
	local A = require(game:GetService("ReplicatedStorage").Config.AnimationConfig)
	print("POSES" .. enc({ stances = A.Stances, styleStances = A.StyleStances, styles = A.Styles, flavor = A.StyleFlavor, default = A.DefaultFlavor }))
end
return cases
"""

# Limb lengths (studs) of the stand-in body.
UPPER_ARM, LOWER_ARM, UPPER_LEG, LOWER_LEG, BLADE = 1.15, 1.1, 1.3, 1.35, 3.2
HIP_HEIGHT = 3.0

AUTO_WINDUP = {"waist": [-8, 32, 0], "root": [8, 14, 0, 0, -0.5, 0.5], "leftHip": [10, 0, -6], "rightHip": [-22, 0, 8], "leftKnee": [-30, 0, 0], "rightKnee": [-26, 0, 0]}
AUTO_STRIKE = {"waist": [12, -34, 0], "root": [-14, -16, 0, 0, -0.9, -1.4], "leftHip": [-48, 0, -4], "rightHip": [34, 0, 6], "leftKnee": [-42, 0, 0], "rightKnee": [-14, 0, 0]}


def rot(a):
    """CFrame.Angles(x, y, z) as a 3x3 matrix (Rx * Ry * Rz)."""
    x, y, z = (math.radians(a[i]) if i < len(a) else 0 for i in range(3))
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    Rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Rz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return mul(mul(Rx, Ry), Rz)


def mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def app(m, v):
    return [sum(m[i][k] * v[k] for k in range(3)) for i in range(3)]


def add(a, b):
    return [a[i] + b[i] for i in range(3)]


def fk(pose):
    """Returns named 3D points of the body for a pose dict."""
    g = lambda k: pose.get(k, [0, 0, 0])
    r = g("root")
    R0 = rot(r)
    origin = [r[3] if len(r) > 3 else 0, HIP_HEIGHT + (r[4] if len(r) > 4 else 0), r[5] if len(r) > 5 else 0]
    pts = {"pelvis": origin}
    # waist -> upper torso
    Rw = mul(R0, rot(g("waist")))
    chest = add(origin, app(R0, [0, 0.5, 0]))
    neck = add(chest, app(Rw, [0, 1.5, 0]))
    pts.update(chest=chest, neck=neck, head=add(neck, app(Rw, [0, 0.7, 0])))
    for side, sh, el, x in (("R", "shoulder", "elbow", 1.0), ("L", "leftShoulder", "leftElbow", -1.0)):
        s = add(chest, app(Rw, [x, 1.3, 0]))
        Rs = mul(Rw, rot(g(sh)))
        e = add(s, app(Rs, [0, -UPPER_ARM, 0]))
        Re = mul(Rs, rot(g(el)))
        h = add(e, app(Re, [0, -LOWER_ARM, 0]))
        pts[side + "s"], pts[side + "e"], pts[side + "h"] = s, e, h
        if side == "R":
            pts["tip"] = add(h, app(Re, [0, 0, -BLADE]))  # blade forward out of the fist
    for side, hp, kn, x in (("R", "rightHip", "rightKnee", 0.5), ("L", "leftHip", "leftKnee", -0.5)):
        hip = add(origin, app(R0, [x, -0.2, 0]))
        Rh = mul(R0, rot(g(hp)))
        knee = add(hip, app(Rh, [0, -UPPER_LEG, 0]))
        Rk = mul(Rh, rot(g(kn)))
        foot = add(knee, app(Rk, [0, -LOWER_LEG, 0]))
        pts[side + "hip"], pts[side + "k"], pts[side + "f"] = hip, knee, foot
    return pts


BONES = [("pelvis", "chest", "torso"), ("chest", "neck", "torso"), ("Rs", "Ls", "torso"), ("Rhip", "Lhip", "torso"),
         ("Rs", "Re", "arm"), ("Re", "Rh", "arm"), ("Ls", "Le", "arm"), ("Le", "Lh", "arm"),
         ("Rhip", "Rk", "leg"), ("Rk", "Rf", "leg"), ("Lhip", "Lk", "leg"), ("Lk", "Lf", "leg"), ("Rh", "tip", "blade")]
COLORS = {"torso": (230, 220, 200), "arm": (240, 190, 140), "leg": (170, 180, 210), "blade": (255, 120, 80)}


def additive(base, extra):
    out = {k: list(v) for k, v in base.items()}
    for k, v in (extra or {}).items():
        b = out.get(k, [])
        out[k] = [(b[i] if i < len(b) else 0) + (v[i] if i < len(v) else 0) for i in range(max(len(b), len(v)))]
    return out


def move_pose(rest, part, auto, lean=0):
    pose = dict(rest)
    pose.update(auto)
    pose.update(part)
    if lean:
        r = list(pose.get("root", [0, 0, 0]))
        r[0] += lean
        pose["root"] = r
    return pose


def mix(a, b, k):
    keys = set(a) | set(b)
    out = {}
    for name in keys:
        x, y = a.get(name, [0, 0, 0]), b.get(name, a.get(name, [0, 0, 0]))
        out[name] = [(x[i] if i < len(x) else 0) + ((y[i] if i < len(y) else 0) - (x[i] if i < len(x) else 0)) * k for i in range(max(len(x), len(y)))]
    return out


def draw_figure(d, pose, ox, oy, scale, view, label, font):
    pts = fk(pose)
    def proj(p):
        if view == "front":
            return ox - p[0] * scale, oy - p[1] * scale  # facing the viewer: character's right is on our left
        return ox + p[2] * scale, oy - p[1] * scale  # side: forward (-Z) to the left
    d.line([(ox - 2.6 * scale, oy), (ox + 2.6 * scale, oy)], fill=(70, 70, 70), width=1)
    for a, b, kind in BONES:
        d.line([proj(pts[a]), proj(pts[b])], fill=COLORS[kind], width=4 if kind != "blade" else 3)
    hx, hy = proj(pts["head"])
    d.ellipse((hx - 0.45 * scale, hy - 0.45 * scale, hx + 0.45 * scale, hy + 0.45 * scale), outline=COLORS["torso"], width=3)
    d.text((ox - 2.5 * scale, oy + 6), label, fill=(220, 220, 220), font=font)


def main():
    bundle = build_bundle([("poses", SPEC)], preludes=["tests/engine_mock.luau"])
    out = ROOT / "build" / "poses.bundle.luau"
    out.parent.mkdir(exist_ok=True)
    out.write_text(bundle)
    res = subprocess.run([LUAU, str(out)], capture_output=True, text=True)
    line = next((l for l in res.stdout.splitlines() if l.startswith("POSES")), None)
    if line is None:
        sys.stderr.write(res.stdout + res.stderr)
        raise SystemExit(1)
    A = json.loads(line[5:])
    styles = ["", "river", "mountain", "wind", "ember"]
    rows = []
    for cls in ("OneHanded", "TwoHanded"):
        rows.append([(f"{cls} {s or 'base'}", additive(A["stances"][cls], A["styleStances"].get(s)) if s else A["stances"][cls]) for s in styles])
    slash = A["styles"]["SlashRight"]
    for phase, auto, flav_key in (("windup", AUTO_WINDUP, "coil"), ("strike", AUTO_STRIKE, "overshoot")):
        row = []
        for s in styles:
            rest = additive(A["stances"]["OneHanded"], A["styleStances"].get(s)) if s else A["stances"]["OneHanded"]
            flav = A["flavor"].get(s, A["default"]) if s else A["default"]
            target = move_pose(rest, slash[phase], auto, flav["lean"] if phase == "strike" else 0)
            base = move_pose(rest, slash["windup"], AUTO_WINDUP) if phase == "strike" else rest
            row.append((f"slash {phase} {s or 'base'}", mix(base, target, flav[flav_key])))
        rows.append(row)
    cell, scale = 230, 30
    W, H = cell * 2 * len(styles), cell * len(rows)
    img = Image.new("RGB", (W, H), (28, 26, 30))
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("/usr/share/fonts/opentype/inter/Inter-Medium.otf", 14)
    except OSError:
        font = ImageFont.load_default()
    for r, row in enumerate(rows):
        for c, (label, pose) in enumerate(row):
            x0 = c * cell * 2
            draw_figure(d, pose, x0 + cell * 0.5, r * cell + cell - 40, scale, "front", label + " (front)", font)
            draw_figure(d, pose, x0 + cell * 1.5, r * cell + cell - 40, scale, "side", "(side)", font)
    img.save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
