#!/usr/bin/env python3
"""Tile several UI preview PNGs into one contact sheet: ui_sheet.py out.png a.png b.png ..."""
import sys

from PIL import Image, ImageDraw

out, files = sys.argv[1], sys.argv[2:]
imgs = [Image.open(f).convert("RGB") for f in files]
scale = 0.5
w, h = int(imgs[0].width * scale), int(imgs[0].height * scale)
cols = 2
rows = (len(imgs) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, (h + 18) * rows), (20, 20, 20))
d = ImageDraw.Draw(sheet)
for i, (f, im) in enumerate(zip(files, imgs)):
    x, y = (i % cols) * w, (i // cols) * (h + 18)
    sheet.paste(im.resize((w, h)), (x, y + 18))
    d.text((x + 6, y + 3), f.split("/")[-1], fill=(220, 220, 220))
sheet.save(out)
