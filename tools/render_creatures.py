#!/usr/bin/env python3
"""Preview creature attack poses (AnimationConfig.CreaturePoses) on the real CreatureBuilder
models, without Studio. Each row: a creature + pose; columns: rest, windup, strike (side view).

Usage: python3 tools/render_creatures.py path/to/luau [out.png] [Kind:Pose,Kind:Pose,...]
"""
import json
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from run_tests import build_bundle  # noqa: E402
import render_rigs as RR  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"
OUT = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "build" / "creatures.png"
PAIRS = sys.argv[3] if len(sys.argv) > 3 else "Hound:Bite,Hound:Pounce,Hound:Howl,Tiger:Swipe,Tiger:Rear"

SPEC = """
local PAIRS = "%s"
return {
	dump = function()
		local RS = game:GetService("ReplicatedStorage")
		local A = require(RS.Config.AnimationConfig)
		local CreatureBuilder = require(game:GetService("ServerScriptService").World.CreatureBuilder)
		local look = { skin = { 200, 170, 140 }, body = { 150, 80, 50 }, legs = { 90, 60, 40 }, accent = { 60, 35, 25 }, glow = { 255, 140, 60 }, scale = 1 }
		for pair in string.gmatch(PAIRS, "[^,]+") do
			local kind, poseName = string.match(pair, "(%%w+):(%%w+)")
			for _, phase in { "rest", "windup", "strike" } do
				local model = CreatureBuilder.Build(kind, look)
				local motors = {}
				for _, d in model:GetDescendants() do
					if d.ClassName == "Motor6D" then motors[d.Name] = d end
				end
				local set = if phase == "rest" then {} else A.CreaturePoses[poseName][phase]
				for name, a in set do
					local m = motors[name]
					if m then m.C0 = m.C0 * CFrame.Angles(math.rad(a[1]), math.rad(a[2]), math.rad(a[3])) end
				end
				local root = model.PrimaryPart
				root.CFrame = CFrame.new()
				for _, d in model:GetDescendants() do
					if d:IsA("JointInstance") and d.Part0 and d.Part1 then
						d.Part1.CFrame = d.Part0.CFrame * d.C0 * d.C1:Inverse()
					end
				end
				print("RIG " .. kind .. "|" .. poseName .. "|" .. phase .. "|")
				__dumpParts(model)
			end
		end
	end,
}
"""


def main():
    bundle = build_bundle([("creatures", SPEC % PAIRS)], preludes=["tests/engine_mock.luau"])
    f = ROOT / "build" / "render_creatures.luau"
    f.parent.mkdir(exist_ok=True)
    f.write_text(bundle)
    res = subprocess.run([LUAU, str(f)], capture_output=True, text=True)
    items, cur = [], None
    for line in res.stdout.splitlines():
        if line.startswith("RIG "):
            k, p, ph, _ = line[4:].split("|")
            cur = {"label": f"{k} {p} {ph}", "parts": None}
        elif line.startswith("[{") and cur:
            cur["parts"] = [x for x in json.loads(line) if x["transparency"] < 0.9]
            items.append(cur)
            cur = None
    if not items:
        sys.stderr.write(res.stdout[-2000:] + res.stderr)
        sys.exit(1)
    cell = 280
    rows = (len(items) + 2) // 3
    sheet = Image.new("RGBA", (3 * cell, rows * (cell + 20)), (24, 22, 28, 255))
    dr = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("DejaVuSans-Bold.ttf", 13)
    except OSError:
        font = ImageFont.load_default()
    for i, it in enumerate(items):
        x, y = (i % 3) * cell, (i // 3) * (cell + 20)
        sheet.alpha_composite(RR.render(it, cell, 100), (x, y))
        dr.text((x + 6, y + cell + 2), it["label"], fill=(230, 220, 205), font=font)
    sheet.save(OUT)
    print(f"rendered {len(items)} frames -> {OUT}")


if __name__ == "__main__":
    main()
