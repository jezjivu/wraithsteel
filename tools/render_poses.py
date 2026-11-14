#!/usr/bin/env python3
"""Render AnimationConfig poses on an R15 skeleton (blocky body + held weapon) without Studio.

Reproduces the engine maths: child = parent * C0 * Transform * C1^-1, with Transform built from
a pose {rx, ry, rz [, tx, ty, tz]} as CFrame.new(t) * CFrame.Angles(rx, ry, rz) (Roblox order:
the vector is rotated by Z, then Y, then X). Joint offsets are the default R15 blocky rig's.
Moves get the same automatic footwork AnimationController adds (AUTO_WINDUP / AUTO_STRIKE).

Usage: python3 tools/render_poses.py path/to/luau [out.png] [Style,Style,...]
Output: a contact sheet - each row is a style: stance, windup, strike, from the front-right
and from above (top view shows horizontal sweeps).
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
ONLY = sys.argv[3].split(",") if len(sys.argv) > 3 else None

SPEC = """
local function enc(v)
	local t = type(v)
	if t == "number" then return string.format("%.4f", v) end
	if t == "string" then return string.format("%q", v) end
	if t == "boolean" then return tostring(v) end
	if t == "table" then
		if #v > 0 then
			local out = {}
			for _, x in ipairs(v) do table.insert(out, enc(x)) end
			return "[" .. table.concat(out, ",") .. "]"
		end
		local out = {}
		for k, x in pairs(v) do table.insert(out, string.format("%q", tostring(k)) .. ":" .. enc(x)) end
		return "{" .. table.concat(out, ",") .. "}"
	end
	return "null"
end
return {
	dump = function()
		local A = require(game:GetService("ReplicatedStorage").Config.AnimationConfig)
		local W = require(game:GetService("ReplicatedStorage").Config.WeaponConfig)
		print("ANIM" .. enc({ Styles = A.Styles, Stances = A.Stances, Death = A.Death, Grip = W.GripRotation, GripDepth = W.GripDepth }))
	end,
}
"""

# ---- tiny rigid-transform maths (3x3 rotation + translation) ----------------------------------
def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mat_vec(a, v):
    return [sum(a[i][k] * v[k] for k in range(3)) for i in range(3)]


def rx(t):
    c, s = math.cos(t), math.sin(t)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def ry(t):
    c, s = math.cos(t), math.sin(t)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rz(t):
    c, s = math.cos(t), math.sin(t)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


class CF:
    def __init__(self, p=(0, 0, 0), R=None):
        self.p = list(p)
        self.R = R or I3

    def __mul__(self, o):
        return CF([self.p[i] + mat_vec(self.R, o.p)[i] for i in range(3)], mat_mul(self.R, o.R))

    def inv(self):
        Rt = [[self.R[j][i] for j in range(3)] for i in range(3)]
        p = mat_vec(Rt, self.p)
        return CF([-x for x in p], Rt)

    def point(self, v):
        return [self.p[i] + mat_vec(self.R, v)[i] for i in range(3)]


def angles(a):
    a = (a or []) + [0] * 6
    rot = mat_mul(mat_mul(rx(math.radians(a[0])), ry(math.radians(a[1]))), rz(math.radians(a[2])))
    return CF((a[3], a[4], a[5]), rot)


# ---- R15 blocky rig (default proportions) -------------------------------------------------------
# part: (size, parent, C0 in parent, C1 in part, pose key)
RIG = {
    "HumanoidRootPart": ((2, 2, 1), None, None, None, None),
    "LowerTorso": ((2, 0.4, 1), "HumanoidRootPart", (0, -1, 0), (0, -0.2, 0), "root"),
    "UpperTorso": ((2, 1.6, 1), "LowerTorso", (0, 0.2, 0), (0, -0.8, 0), "waist"),
    "Head": ((1.2, 1.2, 1.2), "UpperTorso", (0, 0.8, 0), (0, -0.5, 0), None),
    "RightUpperArm": ((1, 1.17, 1), "UpperTorso", (1, 0.56, 0), (-0.5, 0.42, 0), "shoulder"),
    "RightLowerArm": ((1, 1.05, 1), "RightUpperArm", (0, -0.33, 0), (0, 0.26, 0), "elbow"),
    "RightHand": ((1, 0.3, 1), "RightLowerArm", (0, -0.5, 0), (0, 0.13, 0), None),
    "LeftUpperArm": ((1, 1.17, 1), "UpperTorso", (-1, 0.56, 0), (0.5, 0.42, 0), "leftShoulder"),
    "LeftLowerArm": ((1, 1.05, 1), "LeftUpperArm", (0, -0.33, 0), (0, 0.26, 0), "leftElbow"),
    "LeftHand": ((1, 0.3, 1), "LeftLowerArm", (0, -0.5, 0), (0, 0.13, 0), None),
    "RightUpperLeg": ((1, 1.22, 1), "LowerTorso", (0.5, -0.2, 0), (0, 0.42, 0), "rightHip"),
    "RightLowerLeg": ((1, 1.19, 1), "RightUpperLeg", (0, -0.42, 0), (0, 0.36, 0), "rightKnee"),
    "RightFoot": ((1, 0.3, 1), "RightLowerLeg", (0, -0.55, 0), (0, 0.1, 0), None),
    "LeftUpperLeg": ((1, 1.22, 1), "LowerTorso", (-0.5, -0.2, 0), (0, 0.42, 0), "leftHip"),
    "LeftLowerLeg": ((1, 1.19, 1), "LeftUpperLeg", (0, -0.42, 0), (0, 0.36, 0), "leftKnee"),
    "LeftFoot": ((1, 0.3, 1), "LeftLowerLeg", (0, -0.55, 0), (0, 0.1, 0), None),
}
ORDER = ["HumanoidRootPart", "LowerTorso", "UpperTorso", "Head", "RightUpperArm", "RightLowerArm", "RightHand",
         "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperLeg", "RightLowerLeg", "RightFoot",
         "LeftUpperLeg", "LeftLowerLeg", "LeftFoot"]
COLORS = {
    "Head": (230, 200, 170), "UpperTorso": (150, 60, 50), "LowerTorso": (90, 40, 35),
    "RightUpperArm": (200, 90, 70), "RightLowerArm": (220, 120, 90), "RightHand": (230, 200, 170),
    "LeftUpperArm": (70, 110, 170), "LeftLowerArm": (90, 140, 200), "LeftHand": (230, 200, 170),
    "RightUpperLeg": (60, 60, 70), "RightLowerLeg": (80, 80, 92), "RightFoot": (40, 40, 45),
    "LeftUpperLeg": (60, 70, 60), "LeftLowerLeg": (80, 95, 80), "LeftFoot": (40, 45, 40),
}

AUTO_WINDUP = {"waist": [8, 32, 0], "root": [8, 14, 0, 0, -0.5, 0.5], "leftHip": [10, 0, -6], "rightHip": [-22, 0, 8], "leftKnee": [-30, 0, 0], "rightKnee": [-26, 0, 0]}
AUTO_STRIKE = {"waist": [-12, -34, 0], "root": [-14, -16, 0, 0, -0.9, -1.4], "leftHip": [-48, 0, -4], "rightHip": [34, 0, 6], "leftKnee": [-42, 0, 0], "rightKnee": [-14, 0, 0]}
NO_FOOTWORK = {"LookAround", "ShoulderRoll", "CheckBlade", "HitReact", "HitHeavy", "BlockRecoil", "DeflectStrike", "Kneel", "DashForward", "SideStep", "Sweep", "Guard", "Dodge", "Drink", "Flip", "Stagger", "Flinch", "Grasp", "CastGuard", "AirSlam"}
GRIP = CF((0, -0.15, 0), rx(math.radians(-90)))  # replaced from WeaponConfig in main()


def solve(pose):
    world = {"HumanoidRootPart": CF((0, 0, 0))}
    for name in ORDER[1:]:
        size, parent, c0, c1, key = RIG[name]
        t = angles(pose.get(key)) if key else CF()
        world[name] = world[parent] * CF(c0) * t * CF(c1).inv()
    return world


def corners(cf, size):
    sx, sy, sz = (s / 2 for s in size)
    return [cf.point((x, y, z)) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]


def hull(points):
    pts = sorted(set((round(x, 4), round(y, 4)) for x, y in points))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def blade_tip(pose, weapon_swing):
    w = solve(pose)
    sw = (weapon_swing or []) + [0, 0, 0, 0]
    wcf = w["RightHand"] * GRIP * CF((0, sw[3], 0)) * angles([sw[0], sw[1], sw[2]])
    return wcf.point((0, 4.1, 0))


def lerp_pose(a, b, k):
    keys = set(a) | set(b)
    out = {}
    for key in keys:
        x, y = a.get(key, [0, 0, 0]), b.get(key, [0, 0, 0])
        n = max(len(x), len(y))
        out[key] = [(x[i] if i < len(x) else 0) + ((y[i] if i < len(y) else 0) - (x[i] if i < len(x) else 0)) * k for i in range(n)]
    return out


def boxes(pose, weapon_swing):
    w = solve(pose)
    out = []
    for name in ORDER[1:]:
        out.append((corners(w[name], RIG[name][0]), COLORS[name]))
    # Weapon: grip in the right hand, blade along the weapon's +Y.
    sw = weapon_swing or [0, 0, 0, 0]
    wcf = w["RightHand"] * GRIP * CF((0, sw[3] if len(sw) > 3 else 0, 0)) * angles([sw[0], sw[1], sw[2]])
    out.append((corners(wcf * CF((0, 2.3, 0)), (0.12, 3.8, 0.35)), (215, 220, 235)))  # blade
    out.append((corners(wcf * CF((0, -0.1, 0)), (0.6, 0.15, 0.6)), (200, 170, 60)))  # guard
    out.append((corners(wcf * CF((0, -0.6, 0)), (0.2, 0.9, 0.2)), (60, 40, 30)))  # hilt
    return out


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def norm(v):
    m = math.sqrt(sum(x * x for x in v)) or 1
    return [x / m for x in v]


def draw(polys, yaw_deg, pitch_deg, size=230, trace=None):
    # Camera on a sphere around the body: yaw 0 = in front (-Z), +yaw toward the body's right,
    # pitch up from the horizon. Proper (unmirrored) basis: right = forward x up.
    yaw, pitch = math.radians(yaw_deg), math.radians(pitch_deg)
    cam = [math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)]
    fwd = [-x for x in cam]
    up_hint = [0, 1, 0] if abs(pitch_deg) < 80 else [math.sin(yaw), 0, -math.cos(yaw)]
    right = norm(cross(fwd, up_hint))
    up = cross(right, fwd)

    def view(pt):
        dot = lambda a, b: sum(a[i] * b[i] for i in range(3))
        return dot(pt, right), dot(pt, up), dot(pt, fwd)

    ss = 3
    img = Image.new("RGBA", (size * ss, size * ss), (34, 31, 38, 255))
    d = ImageDraw.Draw(img)
    scale = size * ss / 11.0
    c0x, c0y = size * ss / 2, size * ss * 0.5
    # ground line / shadow
    items = []
    for cs, col in polys:
        pts = [view(p) for p in cs]
        depth = sum(p[2] for p in pts) / len(pts)
        items.append((depth, hull([(p[0], p[1]) for p in pts]), col))
    def scr(p):
        x, y, _ = view(p)
        return (x * scale + c0x, -y * scale + c0y)
    # Ground: a ring under the feet and an arrow toward the body's front (-Z).
    ring = [scr((math.cos(a) * 2.2, -3.0, math.sin(a) * 2.2)) for a in [i / 24 * math.pi * 2 for i in range(25)]]
    d.line(ring, fill=(70, 66, 74, 255), width=ss)
    d.line([scr((0, -3.0, 0)), scr((0, -3.0, -3.2))], fill=(200, 60, 60, 255), width=2 * ss)
    for _, h, col in sorted(items, key=lambda t: -t[0]):
        pts = [(x * scale + c0x, -y * scale + c0y) for x, y in h]
        if len(pts) >= 3:
            d.polygon(pts, fill=col + (255,), outline=tuple(max(0, c - 60) for c in col) + (255,), width=ss)
    if trace:
        pts = [scr(p) for p in trace]
        d.line(pts, fill=(255, 220, 90, 255), width=2 * ss)
        r = 4 * ss
        d.ellipse([pts[-1][0] - r, pts[-1][1] - r, pts[-1][0] + r, pts[-1][1] + r], fill=(255, 220, 90, 255))
    return img.resize((size, size), Image.LANCZOS)


def load():
    bundle = build_bundle([("anim", SPEC)])
    f = ROOT / "build" / "render_poses.luau"
    f.parent.mkdir(exist_ok=True)
    f.write_text(bundle)
    res = subprocess.run([LUAU, str(f)], capture_output=True, text=True)
    for line in res.stdout.splitlines():
        if line.startswith("ANIM"):
            return json.loads(line[4:])
    sys.stderr.write(res.stdout[-3000:] + res.stderr)
    sys.exit(1)


def merged(rest, pose, auto):
    out = dict(rest)
    if auto:
        out.update(auto)
    out.update(pose)
    return out


def main():
    global GRIP
    data = load()
    g = data["Grip"]
    GRIP = CF((0, -0.3 * data["GripDepth"], 0)) * angles(g)
    styles, stances = data["Styles"], data["Stances"]
    rest = stances.get("OneHanded", {})
    names = ONLY or list(styles.keys())
    cell = 300
    cols = 6  # front: stance / windup / strike, top: windup / strike / both
    sheet = Image.new("RGBA", (cols * cell + 150, len(names) * cell), (24, 22, 28, 255))
    dr = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 14)
    except OSError:
        font = ImageFont.load_default()
    for r, name in enumerate(names):
        if name == "Death":
            # Keyframe sequence: stance, each key (front), the last key from the side.
            keys = [rest] + [merged(rest, k["pose"], None) for k in data["Death"]]
            views = [(keys[i], 30, 10) for i in range(len(keys))] + [(keys[-1], -100, 5)]
            for c, (pose, yaw, pitch) in enumerate(views[:6]):
                sheet.alpha_composite(draw(boxes(pose, [30, 0, 0]), yaw, pitch, cell), (150 + c * cell, r * cell))
            dr.text((8, r * cell + 8), "Death", fill=(240, 225, 200), font=font)
            continue
        st = styles[name]
        move = name not in NO_FOOTWORK and not st.get("spin")
        W = merged(rest, st.get("windup", {}), AUTO_WINDUP if move else None)
        S = merged(rest, st.get("strike", {}), AUTO_STRIKE if move else None)
        y = r * cell
        ww, ws = st.get("weaponWindup") or [0, 0, 0, 0], st.get("weaponStrike") or [0, 0, 0, 0]
        trace = [blade_tip(lerp_pose(W, S, k / 12), [ww[i] + (ws[i] - ww[i]) * k / 12 if i < min(len(ww), len(ws)) else 0 for i in range(4)]) for k in range(13)]
        frames = [
            (rest, None, 30, 10, None), (W, ww, 30, 10, None), (S, ws, 30, 10, trace),
            (W, ww, 0, 89, None), (S, ws, 0, 89, trace), (S, ws, -100, 5, trace),
        ]
        for c, (pose, sw, yaw, pitch, tr) in enumerate(frames):
            sheet.alpha_composite(draw(boxes(pose, sw), yaw, pitch, cell, tr), (150 + c * cell, y))
        dr.text((8, y + 8), name, fill=(240, 225, 200), font=font)
        dr.text((8, y + 28), "stance | windup | strike", fill=(150, 140, 135), font=font)
        dr.text((8, y + 46), "top: windup | strike", fill=(150, 140, 135), font=font)
        dr.text((8, y + 64), "side: strike", fill=(150, 140, 135), font=font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"rendered {len(names)} styles -> {OUT}")


if __name__ == "__main__":
    main()
