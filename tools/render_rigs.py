#!/usr/bin/env python3
"""Render every humanoid enemy / boss / NPC outfit (World/Outfits) on a stand-in R15 body to a
contact sheet, without Studio. Runs the real Outfits code under `luau` with tests/engine_mock.luau.

Usage: python3 tools/render_rigs.py path/to/luau [out.png]
"""
import json
import math
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from run_tests import build_bundle  # noqa: E402
from render_weapons import corners, hull  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "build" / "rigs.png"

SPEC = """
local BODY = {
	Head = { 0, 2.0, 1.2, 1.2, 1.2, "skin" },
	UpperTorso = { 0, 0.8, 2, 1.6, 1, "body" },
	LowerTorso = { 0, -0.2, 2, 0.4, 1, "body" },
	LeftUpperArm = { -1.5, 0.9, 1, 1.2, 1, "skin" },
	RightUpperArm = { 1.5, 0.9, 1, 1.2, 1, "skin" },
	LeftLowerArm = { -1.5, -0.25, 1, 1.1, 1, "skin" },
	RightLowerArm = { 1.5, -0.25, 1, 1.1, 1, "skin" },
	LeftUpperLeg = { -0.5, -1.0, 1, 1.2, 1, "legs" },
	RightUpperLeg = { 0.5, -1.0, 1, 1.2, 1, "legs" },
	LeftLowerLeg = { -0.5, -2.2, 1, 1.2, 1, "legs" },
	RightLowerLeg = { 0.5, -2.2, 1, 1.2, 1, "legs" },
	LeftFoot = { -0.5, -2.95, 1, 0.3, 1, "legs" },
	RightFoot = { 0.5, -2.95, 1, 0.3, 1, "legs" },
	LeftHand = { -1.5, -0.95, 1, 0.3, 1, "skin" },
	RightHand = { 1.5, -0.95, 1, 0.3, 1, "skin" },
}
local function attach(model, base, name, size, offset, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	if shape then p.Shape = shape end
	p.CFrame = base.CFrame * offset
	p.Parent = model
	return p
end
return {
	dump = function()
		local RS = game:GetService("ReplicatedStorage")
		local Outfits = require(game:GetService("ServerScriptService").World.Outfits)
		local list = {}
		for id, d in require(RS.Config.EnemyConfig).Enemies do
			if d.look and d.look.outfit then table.insert(list, { id, d.name, d.look }) end
		end
		for id, d in require(RS.Config.BossConfig).Bosses do
			if d.look and d.look.outfit then table.insert(list, { id, d.name, d.look }) end
		end
		for _, n in require(RS.Config.SagaConfig).Npcs do
			if n.look.outfit then table.insert(list, { n.id, n.name, n.look }) end
		end
		table.sort(list, function(a, b) return a[1] < b[1] end)
		local CreatureBuilder = require(game:GetService("ServerScriptService").World.CreatureBuilder)
		local beasts = {}
		for id, d in require(RS.Config.EnemyConfig).Enemies do
			if d.creature and d.look then table.insert(beasts, { id, d.name, d.creature, d.look }) end
		end
		table.sort(beasts, function(a, b) return a[1] < b[1] end)
		for _, e in beasts do
			local model = CreatureBuilder.Build(e[3], e[4])
			if model then
				print("RIG " .. e[1] .. "|" .. e[2] .. "|" .. e[3] .. "|")
				__dumpParts(model)
			end
		end
		for _, e in list do
			local look = e[3]
			local model = Instance.new("Model")
			for name, b in BODY do
				local p = Instance.new("Part")
				p.Name = name
				p.Size = Vector3.new(b[3], b[4], b[5])
				p.CFrame = CFrame.new(b[1], b[2], 0)
				local c = look[b[6]]
				p.Color = Color3.fromRGB(c[1], c[2], c[3])
				p.Parent = model
			end
			Outfits.Apply(model, look, attach)
			print("RIG " .. e[1] .. "|" .. e[2] .. "|" .. (look.outfit or "") .. "|" .. (look.mask or ""))
			__dumpParts(model)
		end
	end,
}
"""


def load():
    bundle = build_bundle([("rigs", SPEC)], preludes=["tests/engine_mock.luau"])
    f = ROOT / "build" / "render_rigs.luau"
    f.parent.mkdir(exist_ok=True)
    f.write_text(bundle)
    res = subprocess.run([LUAU, str(f)], capture_output=True, text=True)
    out, cur = [], None
    for line in res.stdout.splitlines():
        if line.startswith("RIG "):
            rid, name, outfit, mask = line[4:].split("|")
            cur = {"id": rid, "name": name, "label": outfit + (" + " + mask if mask else "")}
        elif line.startswith("[{") and cur:
            cur["parts"] = json.loads(line)
            out.append(cur)
            cur = None
    if not out or "error" in res.stderr.lower():
        sys.stderr.write(res.stdout[-3000:] + res.stderr)
        if not out:
            sys.exit(1)
    return out


def render(s, size=256, yaw_deg=25):
    yaw, pitch = math.radians(yaw_deg), math.radians(8)
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)

    def view(pt):
        x, y, z = pt
        x, z = x * cy - z * sy, x * sy + z * cy
        y, z = y * cp - z * sp, y * sp + z * cp
        return x, y, z

    polys = []
    for part in s["parts"]:
        rp = {"cls": part["cls"], "shape": part["shape"] if part["shape"].startswith("PartType.") else None,
              "size": part["size"], "p": part["p"], "R": part["R"]}
        pts = [view(p) for p in corners(rp)]
        depth = sum(p[2] for p in pts) / len(pts)
        polys.append((depth, hull([(p[0], p[1]) for p in pts]), part))
    ss = 4
    span = max(max(abs(c) for part in s["parts"] for c in part["p"][:2]) * 2.2, 6.5)
    scale = size * 0.8 / span
    img = Image.new("RGBA", (size * ss, size * ss), (40, 36, 44, 255))
    d = ImageDraw.Draw(img)
    c0x, c0y = size * ss / 2, size * ss * 0.46
    for _, h, part in sorted(polys, key=lambda t: -t[0]):
        col = tuple(part["color"])
        pts = [(x * scale * ss + c0x, -y * scale * ss + c0y) for x, y in h]
        if len(pts) >= 3:
            d.polygon(pts, fill=col + (255,), outline=tuple(max(0, c - 60) for c in col) + (255,), width=ss)
    return img.resize((size, size), Image.LANCZOS)


def main():
    rigs = load()
    cols, cell = 6, 200
    rows = math.ceil(len(rigs) / cols)
    sheet = Image.new("RGBA", (cols * cell * 2, rows * (cell + 40)), (24, 22, 28, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    for i, s in enumerate(rigs):
        x, y = (i % cols) * cell * 2, (i // cols) * (cell + 40)
        sheet.alpha_composite(render(s, cell, 20), (x, y))
        sheet.alpha_composite(render(s, cell, 160), (x + cell, y))
        draw.text((x + 6, y + cell + 4), s["name"], fill=(235, 225, 210), font=font)
        draw.text((x + 6, y + cell + 20), s["label"], fill=(170, 160, 150), font=font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(f"rendered {len(rigs)} rigs -> {OUT}")


if __name__ == "__main__":
    main()
