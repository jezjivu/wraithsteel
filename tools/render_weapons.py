#!/usr/bin/env python3
"""Render every weapon in WeaponConfig to a PNG icon (and a contact sheet) WITHOUT Studio.

It runs the real Shared/WeaponModels.luau under the `luau` CLI with tiny fake Roblox types
(Instance, CFrame, Vector3, Color3, Enum), dumps every part as JSON, then draws the parts with
Pillow (flat-shaded orthographic view, tilted diagonally like an inventory icon).

Usage: python3 tools/render_weapons.py path/to/luau [out_dir]
Output: assets/weapon_icons/<weaponId>.png and assets/weapon_icons/_sheet.png
These PNGs can be uploaded as Decals/Images for UI icons (record ids in AssetLog.md).
"""
import json
import math
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "assets" / "weapon_icons"

PRELUDE = r'''
local function mat(a, b)
	local r = {}
	for i = 1, 3 do
		r[i] = {}
		for j = 1, 3 do
			r[i][j] = a[i][1] * b[1][j] + a[i][2] * b[2][j] + a[i][3] * b[3][j]
		end
	end
	return r
end
local CF = {}
CF.__index = CF
local function cf(p, R) return setmetatable({ p = p, R = R }, CF) end
local I = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }
CF.__mul = function(a, b)
	local R = mat(a.R, b.R)
	local p = {}
	for i = 1, 3 do
		p[i] = a.p[i] + a.R[i][1] * b.p[1] + a.R[i][2] * b.p[2] + a.R[i][3] * b.p[3]
	end
	return cf(p, R)
end
CFrame = {
	new = function(x, y, z) return cf({ x or 0, y or 0, z or 0 }, I) end,
	Angles = function(rx, ry, rz)
		local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
		local Rx = { { 1, 0, 0 }, { 0, cx, -sx }, { 0, sx, cx } }
		local Ry = { { cy, 0, sy }, { 0, 1, 0 }, { -sy, 0, cy } }
		local Rz = { { cz, -sz, 0 }, { sz, cz, 0 }, { 0, 0, 1 } }
		return cf({ 0, 0, 0 }, mat(mat(Rx, Ry), Rz))
	end,
}
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
Color3 = { fromRGB = function(r, g, b) return { r, g, b } end }
Enum = setmetatable({}, { __index = function(_, cat)
	return setmetatable({}, { __index = function(_, item) return cat .. "." .. item end })
end })
local all = {}
local Inst = {}
Inst.__index = function(self, k)
	if k == "GetDescendants" then
		return function(s)
			local out = {}
			local function walk(n) for _, c in n.__children do table.insert(out, c); walk(c) end end
			walk(s)
			return out
		end
	elseif k == "IsA" then
		return function(s, cls)
			if cls == "BasePart" then return s.ClassName == "Part" or s.ClassName == "WedgePart" end
			return s.ClassName == cls
		end
	elseif k == "SetAttribute" then
		return function() end
	end
	return rawget(self, "__props")[k]
end
Inst.__newindex = function(self, k, v)
	if k == "Parent" and v then
		table.insert(rawget(v, "__children"), self)
	end
	rawget(self, "__props")[k] = v
end
Instance = { new = function(cls)
	local o = setmetatable({ __props = { ClassName = cls }, __children = {} }, Inst)
	table.insert(all, o)
	return o
end }
'''

DUMP = r'''
local out = {}
for _, id in WeaponConfig.ShopOrder do
	local model = WeaponModels.Build(id, true)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Handle" then
			table.insert(parts, {
				cls = d.ClassName, shape = d.Shape, name = d.Name,
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				p = d.CFrame.p, R = d.CFrame.R,
				color = d.Color, material = d.Material,
			})
		end
	end
	local def = WeaponConfig.Weapons[id]
	table.insert(out, { id = id, name = def.name, rarity = def.rarity, cls = def.class, parts = parts })
end
print(JSON(out))
'''

JSON_FN = r'''
function JSON(v)
	local t = type(v)
	if t == "table" then
		if #v > 0 or next(v) == nil then
			local items = {}
			for _, x in ipairs(v) do table.insert(items, JSON(x)) end
			return "[" .. table.concat(items, ",") .. "]"
		end
		local items = {}
		for k, x in pairs(v) do table.insert(items, string.format("%q", tostring(k)) .. ":" .. JSON(x)) end
		return "{" .. table.concat(items, ",") .. "}"
	elseif t == "string" then
		return string.format("%q", v)
	elseif t == "nil" then
		return "null"
	end
	return tostring(v)
end
'''


def module(path, name):
    src = (ROOT / path).read_text()
    src = "\n".join(l[len("export "):] if l.startswith("export type ") else l for l in src.split("\n"))
    return f"local {name} = (function()\n{src}\nend)()\n"


def run_luau():
    cfg = module("src/config/WeaponConfig.luau", "WeaponConfig")
    models = module("src/shared/WeaponModels.luau", "WeaponModels")
    # WeaponModels requires WeaponConfig through ReplicatedStorage; provide a fake `game`.
    fake_game = (
        "game = { GetService = function() return { WaitForChild = function() return "
        "{ WaitForChild = function() return '__WeaponConfig' end } end } end }\n"
        "local __realRequire = require\n"
        "require = function(x) if x == '__WeaponConfig' then return WeaponConfig end return __realRequire(x) end\n"
    )
    bundle = PRELUDE + JSON_FN + cfg + fake_game + models + DUMP
    build = ROOT / "build"
    build.mkdir(exist_ok=True)
    f = build / "render_weapons.luau"
    f.write_text(bundle)
    res = subprocess.run([LUAU, str(f)], capture_output=True, text=True)
    if res.returncode != 0:
        sys.stderr.write(res.stdout + res.stderr)
        sys.exit(1)
    return json.loads(res.stdout.strip().splitlines()[-1])


RARITY = {
    "Common": (190, 190, 190), "Uncommon": (110, 200, 120), "Rare": (80, 150, 240),
    "Epic": (170, 90, 230), "Legendary": (245, 180, 60), "Mythic": (235, 70, 90),
}


def corners(part):
    sx, sy, sz = (s / 2 for s in part["size"])
    if part["cls"] == "WedgePart":
        # Roblox wedge: full bottom face, top edge at the back (+Z), slope faces front (-Z).
        local = [(x, -sy, z) for x in (-sx, sx) for z in (-sz, sz)] + [(x, sy, sz) for x in (-sx, sx)]
    elif part.get("shape") == "PartType.Cylinder":
        # Cylinder along local X: sample circles at both ends.
        local = []
        for x in (-sx, sx):
            for k in range(16):
                a = 2 * math.pi * k / 16
                local.append((x, sy * math.cos(a), sz * math.sin(a)))
    elif part.get("shape") == "PartType.Ball":
        local = []
        for k in range(20):
            a = 2 * math.pi * k / 20
            for b in (-0.6, 0, 0.6):
                r = math.cos(b)
                local.append((sx * r * math.cos(a), sy * r * math.sin(a), sz * math.sin(b)))
    else:
        local = [(x, y, z) for x in (-sx, sx) for y in (-sy, sy) for z in (-sz, sz)]
    p, R = part["p"], part["R"]
    return [
        tuple(p[i] + R[i][0] * v[0] + R[i][1] * v[1] + R[i][2] * v[2] for i in range(3))
        for v in local
    ]


def hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2:
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


def render(w, size=256):
    # View: looking down -Z at the weapon's X/Y plane, rotated 45 degrees (icon tilt).
    tilt = math.radians(-45)
    ct, st = math.cos(tilt), math.sin(tilt)
    polys = []
    for part in w["parts"]:
        pts3 = corners(part)
        depth = sum(p[2] for p in pts3) / len(pts3)
        pts2 = [(x * ct - y * st, x * st + y * ct) for x, y, _ in pts3]
        polys.append((depth, hull(pts2), part))
    xs = [x for _, h, _ in polys for x, _ in h]
    ys = [y for _, h, _ in polys for _, y in h]
    span = max(max(xs) - min(xs), max(ys) - min(ys)) or 1
    scale = size * 0.84 / span
    cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    ss = 4  # supersample for smooth edges
    img = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    rc = RARITY.get(w["rarity"], (200, 200, 200))
    r0 = size * ss * 0.48
    c0 = size * ss / 2
    draw.ellipse([c0 - r0, c0 - r0, c0 + r0, c0 + r0], fill=rc + (60,), outline=rc + (200,), width=3 * ss)
    for _, h, part in sorted(polys, key=lambda t: t[0]):
        col = tuple(int(c) for c in part["color"])
        if part["material"] != "Material.Neon":
            col = tuple(int(c * 0.92) for c in col)
        pts = [((x - cx) * scale * ss + c0, -(y - cy) * scale * ss + c0) for x, y in h]
        if len(pts) >= 3:
            outline = tuple(max(0, int(c * 0.45)) for c in col)
            draw.polygon(pts, fill=col + (255,), outline=outline + (255,), width=max(1, ss))
    return img.resize((size, size), Image.LANCZOS)


def main():
    weapons = run_luau()
    OUT.mkdir(parents=True, exist_ok=True)
    icons = []
    for w in weapons:
        img = render(w)
        img.save(OUT / f"{w['id']}.png")
        icons.append((w, img))
    cols = 4
    rows = math.ceil(len(icons) / cols)
    cell = 256
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 34)), (24, 22, 28, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    for i, (w, img) in enumerate(icons):
        x, y = (i % cols) * cell, (i // cols) * (cell + 34)
        sheet.alpha_composite(img, (x, y))
        label = f"{w['name']}"
        tw = draw.textlength(label, font=font)
        draw.text((x + (cell - tw) / 2, y + cell + 6), label, fill=RARITY.get(w["rarity"], (230, 230, 230)), font=font)
    sheet.save(OUT / "_sheet.png")
    print(f"rendered {len(icons)} weapons -> {OUT}")


if __name__ == "__main__":
    main()
