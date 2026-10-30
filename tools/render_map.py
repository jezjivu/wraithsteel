#!/usr/bin/env python3
"""Render the generated world (MapService + HubService) as a top-down map PNG without Studio.
Terrain fills are drawn as colored shapes, parts on top (highest last).
Usage: python3 tools/render_map.py path/to/luau [out.png]
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
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "build" / "map_top.png"

SPEC = """
return {
	dump = function()
		local SSS = game:GetService("ServerScriptService")
		require(SSS.Services.MapService).Start()
		require(SSS.Services.HubService).Start()
		__dumpTerrain()
		__dumpParts(workspace)
	end,
}
"""

MAT = {
    "Material.Grass": (88, 128, 62), "Material.Cobblestone": (140, 135, 125), "Material.Ground": (125, 100, 70),
    "Material.Rock": (110, 105, 100), "Material.Snow": (240, 245, 250), "Material.Sand": (215, 195, 150),
    "Material.Water": (60, 110, 150), "Material.Mud": (80, 65, 50), "Material.Air": None,
    "Material.Pavement": (165, 160, 150), "Material.LeafyGrass": (120, 110, 55),
}


def main():
    bundle = build_bundle([("map", SPEC)], preludes=["tests/engine_mock.luau"])
    f = ROOT / "build" / "render_map.luau"
    f.parent.mkdir(exist_ok=True)
    f.write_text(bundle)
    res = subprocess.run([LUAU, str(f)], capture_output=True, text=True)
    terrain, parts = None, None
    for line in res.stdout.splitlines():
        if line.startswith("TERRAIN["):
            terrain = json.loads(line[len("TERRAIN"):])
        elif line.startswith("[{"):
            parts = json.loads(line)
    if parts is None:
        sys.stderr.write(res.stdout[-3000:] + res.stderr[-3000:])
        sys.exit(1)
    terrain = terrain or []

    minx, maxx, minz, maxz = -330, 330, -400, 320
    size = 1400
    scale = size / max(maxx - minx, maxz - minz)

    def P(x, z):
        return ((x - minx) * scale, (z - minz) * scale)  # north (-z) at the top

    img = Image.new("RGB", (size, size), (40, 38, 36))
    d = ImageDraw.Draw(img)
    for t in terrain:
        col = MAT.get(t["material"])
        if col is None:
            continue
        x, y, z = t["p"]
        if t["kind"] == "Ball":
            r = t["size"][0]
            # Footprint radius where the ball crosses ground level (y = 0).
            if abs(y) < r:
                fr = math.sqrt(r * r - y * y)
                a, b = P(x - fr, z - fr), P(x + fr, z + fr)
                d.ellipse([a, b], fill=col)
        elif t["kind"] == "Cylinder":
            r = t["size"][1]
            a, b = P(x - r, z - r), P(x + r, z + r)
            d.ellipse([a, b], fill=col)
        else:
            sx, sy, sz = t["size"]
            R = t["R"]
            pts = []
            for cx, cz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                lx, lz = cx * sx / 2, cz * sz / 2
                wx = x + R[0][0] * lx + R[0][2] * lz
                wz = z + R[2][0] * lx + R[2][2] * lz
                pts.append(P(wx, wz))
            d.polygon(pts, fill=col)
    polys = []
    for p in parts:
        if p["transparency"] >= 1:
            continue
        rp = {"cls": p["cls"], "shape": p["shape"] if p["shape"].startswith("PartType.") else None,
              "size": p["size"], "p": p["p"], "R": p["R"]}
        pts = corners(rp)
        polys.append((max(q[1] for q in pts), hull([P(q[0], q[2]) for q in pts]), p))
    for _, h, p in sorted(polys, key=lambda t: t[0]):
        if len(h) >= 3:
            col = tuple(p["color"])
            d.polygon(h, fill=col, outline=tuple(max(0, c - 50) for c in col))
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    d.text((14, 10), "Wilds of the Nine Gates - top view (north is up, hub town at the bottom)", fill=(250, 230, 190), font=font)
    img.save(OUT)
    print(f"{len(parts)} parts, {len(terrain)} terrain fills -> {OUT}")


if __name__ == "__main__":
    main()
