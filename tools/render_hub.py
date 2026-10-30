#!/usr/bin/env python3
"""Render the generated hub town (HubService) to PNGs WITHOUT Studio: a top-down map and a
side elevation, plus a report of every solid surface higher than a normal step.

Runs the real HubService code under the `luau` CLI with tests/engine_mock.luau.
Usage: python3 tools/render_hub.py path/to/luau [out_dir]
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
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "build"

SPEC = """
return {
	dump = function()
		local HubService = require(game:GetService("ServerScriptService").Services.HubService)
		HubService.Start()
		__dumpParts(workspace)
	end,
}
"""


def load_parts():
    bundle = build_bundle([("hub", SPEC)], preludes=["tests/engine_mock.luau"])
    OUT.mkdir(parents=True, exist_ok=True)
    f = ROOT / "build" / "render_hub.luau"
    f.parent.mkdir(exist_ok=True)
    f.write_text(bundle)
    res = subprocess.run([LUAU, str(f)], capture_output=True, text=True)
    for line in res.stdout.splitlines():
        if line.startswith("[{"):
            return json.loads(line)
    sys.stderr.write(res.stdout + res.stderr)
    sys.exit(1)


def as_render_part(p):
    shape = p["shape"]
    return {
        "cls": p["cls"],
        "shape": shape if shape.startswith("PartType.") else None,
        "size": p["size"],
        "p": p["p"],
        "R": p["R"],
    }


def draw_view(parts, axes, depth_key, size, title):
    polys = []
    for part in parts:
        if part["transparency"] >= 1:
            continue
        pts3 = corners(as_render_part(part))
        pts2 = [(pt[axes[0]], pt[axes[1]]) for pt in pts3]
        depth = depth_key(pts3)
        polys.append((depth, hull(pts2), part))
    xs = [x for _, h, _ in polys for x, _ in h]
    ys = [y for _, h, _ in polys for _, y in h]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    span = max(maxx - minx, maxy - miny) or 1
    scale = (size - 40) / span
    img = Image.new("RGB", (size, size), (34, 32, 30))
    d = ImageDraw.Draw(img)
    for _, h, part in sorted(polys, key=lambda t: t[0]):
        col = tuple(part["color"])
        pts = [(20 + (x - minx) * scale, size - 20 - (y - miny) * scale) for x, y in h]
        if len(pts) >= 3:
            d.polygon(pts, fill=col, outline=tuple(max(0, c - 60) for c in col))
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 18)
    except OSError:
        font = ImageFont.load_default()
    d.text((12, 8), title, fill=(240, 220, 170), font=font)
    return img


def main():
    parts = load_parts()
    # Top view: X right, -Z up (north = toward the Wilds). Depth = highest point (draw top last).
    top = draw_view(parts, (0, 2), lambda pts: max(p[1] for p in pts), 1100, "Hub - top view (north/Wilds is down)")
    top.save(OUT / "hub_top.png")
    side = draw_view(parts, (0, 1), lambda pts: max(p[2] for p in pts), 1100, "Hub - side view from the south")
    side.save(OUT / "hub_side.png")

    # Walkability report: solid parts whose top surface is above a normal step.
    print("Solid surfaces higher than 1.0 stud above the ground (name: top height):")
    seen = {}
    for p in parts:
        if not p["collide"] or p["transparency"] >= 1:
            continue
        top_y = max(pt[1] for pt in corners(as_render_part(p)))
        if top_y > 1.0:
            key = p["name"]
            seen[key] = max(seen.get(key, 0), top_y)
    for name, h in sorted(seen.items(), key=lambda kv: -kv[1]):
        print(f"  {name}: {h:.2f}")
    print(f"{len(parts)} parts rendered -> {OUT}")


if __name__ == "__main__":
    main()
