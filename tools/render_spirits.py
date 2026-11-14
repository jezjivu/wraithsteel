#!/usr/bin/env python3
"""Render every Spirit companion model (Shared/SpiritModels) to PNG icons + a contact sheet,
without Studio. Runs the real builder under `luau` with tests/engine_mock.luau.

Usage: python3 tools/render_spirits.py path/to/luau [out_dir]
Output: assets/spirit_icons/<spiritId>.png and _sheet.png
"""
import json
import math
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from run_tests import build_bundle  # noqa: E402
from render_weapons import corners, hull, RARITY  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "assets" / "spirit_icons"

SPEC = """
return {
	dump = function()
		local RS = game:GetService("ReplicatedStorage")
		local SpiritModels = require(RS.Shared.SpiritModels)
		local SpiritConfig = require(RS.Config.SpiritConfig)
		local ids = {}
		for id in SpiritConfig.Spirits do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local ra = SpiritConfig.Rarities[SpiritConfig.Spirits[a].rarity].order
			local rb = SpiritConfig.Rarities[SpiritConfig.Spirits[b].rarity].order
			if ra == rb then return a < b end
			return ra < rb
		end)
		for _, id in ids do
			local def = SpiritConfig.Spirits[id]
			print("SPIRIT " .. id .. "|" .. def.name .. "|" .. def.rarity)
			__dumpParts(SpiritModels.Build(id, "None", def.rarity))
		end
	end,
}
"""


def load():
    bundle = build_bundle([("spirits", SPEC)], preludes=["tests/engine_mock.luau"])
    f = ROOT / "build" / "render_spirits.luau"
    f.parent.mkdir(exist_ok=True)
    f.write_text(bundle)
    res = subprocess.run([LUAU, str(f)], capture_output=True, text=True)
    out, cur = [], None
    for line in res.stdout.splitlines():
        if line.startswith("SPIRIT "):
            sid, name, rarity = line[7:].split("|")
            cur = {"id": sid, "name": name, "rarity": rarity}
        elif line.startswith("[{") and cur:
            cur["parts"] = json.loads(line)
            out.append(cur)
            cur = None
    if not out:
        sys.stderr.write(res.stdout + res.stderr)
        sys.exit(1)
    return out


def render(s, size=256):
    yaw, pitch = math.radians(35), math.radians(20)
    cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)

    def view(pt):
        x, y, z = pt
        x, z = x * cy - z * sy, x * sy + z * cy  # yaw
        y, z = y * cp - z * sp, y * sp + z * cp  # pitch
        return x, y, z

    polys = []
    for part in s["parts"]:
        rp = {"cls": part["cls"], "shape": part["shape"] if part["shape"].startswith("PartType.") else None,
              "size": part["size"], "p": part["p"], "R": part["R"]}
        pts = [view(p) for p in corners(rp)]
        depth = sum(p[2] for p in pts) / len(pts)
        polys.append((depth, hull([(p[0], p[1]) for p in pts]), part))
    xs = [x for _, h, _ in polys for x, _ in h]
    ys = [y for _, h, _ in polys for _, y in h]
    span = max(max(xs) - min(xs), max(ys) - min(ys)) or 1
    scale = size * 0.7 / span
    cx, cyy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
    ss = 4
    img = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rc = RARITY.get(s["rarity"], (200, 200, 200))
    c0, r0 = size * ss / 2, size * ss * 0.48
    d.ellipse([c0 - r0, c0 - r0, c0 + r0, c0 + r0], fill=rc + (60,), outline=rc + (200,), width=3 * ss)
    for _, h, part in sorted(polys, key=lambda t: -t[0]):  # far (larger z after view) first
        col = tuple(part["color"])
        alpha = int(255 * (1 - part["transparency"]))
        pts = [((x - cx) * scale * ss + c0, -(y - cyy) * scale * ss + c0) for x, y in h]
        if len(pts) >= 3:
            d.polygon(pts, fill=col + (alpha,), outline=tuple(max(0, c - 70) for c in col) + (alpha,), width=ss)
    return img.resize((size, size), Image.LANCZOS)


def main():
    spirits = load()
    OUT.mkdir(parents=True, exist_ok=True)
    cols, cell = 5, 256
    rows = math.ceil(len(spirits) / cols)
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 34)), (24, 22, 28, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 16)
    except OSError:
        font = ImageFont.load_default()
    for i, s in enumerate(spirits):
        img = render(s)
        img.save(OUT / f"{s['id']}.png")
        x, y = (i % cols) * cell, (i // cols) * (cell + 34)
        sheet.alpha_composite(img, (x, y))
        tw = draw.textlength(s["name"], font=font)
        draw.text((x + (cell - tw) / 2, y + cell + 6), s["name"], fill=RARITY.get(s["rarity"], (230, 230, 230)), font=font)
    sheet.save(OUT / "_sheet.png")
    print(f"rendered {len(spirits)} spirits -> {OUT}")


if __name__ == "__main__":
    main()
