#!/usr/bin/env python3
"""Headless preview of the code-built UI (no Studio).

Runs client UI code (Kit, panels, HUD) inside the Luau CLI with tests/engine_mock.luau +
tools/ui_mock.luau, dumps the PlayerGui tree as JSON, then lays it out (UDim2, list/grid
layouts, padding, automatic size, scrolling frames) and draws it with Pillow.

This is an approximation of Roblox's renderer: fonts are stand-ins (Inter for Gotham/Builder
Sans, Caladea/Liberation Serif for the serif fonts), images and 3D viewports are placeholders.
It is good enough to judge layout, hierarchy, spacing and color - not pixel-exact.

Usage:
  python3 tools/render_ui.py path/to/luau [scene ...] [--size 1280x720] [--out build/ui]
Scenes live in tools/ui_scenes/*.luau (each returns a function that builds the GUI).
"""
import json
import math
import pathlib
import re
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from run_tests import build_bundle  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOPBAR = 58  # Roblox top bar inset when IgnoreGuiInset = false

# ------------------------------------------------------------------------------------------
# Fonts
FONT_FILES = {
    "sans": "/usr/share/fonts/opentype/inter/Inter-Regular.otf",
    "sans-medium": "/usr/share/fonts/opentype/inter/Inter-Medium.otf",
    "sans-semibold": "/usr/share/fonts/opentype/inter/Inter-SemiBold.otf",
    "sans-bold": "/usr/share/fonts/opentype/inter/Inter-Bold.otf",
    "sans-black": "/usr/share/fonts/opentype/inter/Inter-Black.otf",
    "serif": "/usr/share/fonts/truetype/crosextra/Caladea-Regular.ttf",
    "serif-bold": "/usr/share/fonts/truetype/crosextra/Caladea-Bold.ttf",
    "mono": "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
}
FONT_MAP = {
    "Gotham": "sans", "GothamMedium": "sans-medium", "GothamSemibold": "sans-semibold", "GothamBold": "sans-bold",
    "GothamBlack": "sans-black", "BuilderSans": "sans", "BuilderSansMedium": "sans-medium",
    "BuilderSansBold": "sans-bold", "BuilderSansExtraBold": "sans-black", "SourceSans": "sans",
    "SourceSansBold": "sans-bold", "SourceSansSemibold": "sans-semibold", "Arial": "sans", "ArialBold": "sans-bold",
    "Roboto": "sans", "Nunito": "sans-semibold", "Ubuntu": "sans", "Antique": "serif", "Garamond": "serif",
    "Merriweather": "serif-bold", "Fondamento": "serif", "Bodoni": "serif", "Fantasy": "serif-bold",
    "GrenzeGotisch": "serif-bold", "Code": "mono", "RobotoMono": "mono", "Sarpanch": "sans-bold",
}
_font_cache = {}


def font_for(name, size):
    key = FONT_MAP.get((name or "Font.Gotham").split(".")[-1], "sans")
    k = (key, int(size))
    if k not in _font_cache:
        path = FONT_FILES[key]
        if not pathlib.Path(path).exists():
            path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
        _font_cache[k] = ImageFont.truetype(path, max(1, int(size)))
    return _font_cache[k]


# ------------------------------------------------------------------------------------------
# Value helpers
def color(v, default=(163, 162, 165)):
    if isinstance(v, dict) and "c" in v:
        return tuple(v["c"])
    return default


def udim(v, scale_base, default=0.0):
    if isinstance(v, dict) and "s" in v:
        return v["s"] * scale_base + v["o"]
    return default


def u2(v):
    if isinstance(v, list) and len(v) == 4:
        return v
    return [0, 0, 0, 0]


def enum(v, default=""):
    return v.split(".")[-1] if isinstance(v, str) else default


def seq_at(seq, t):
    kp = seq["seq"] if isinstance(seq, dict) and "seq" in seq else None
    if not kp:
        return None
    if t <= kp[0][0]:
        return kp[0][1]
    for (t0, v0), (t1, v1) in zip(kp, kp[1:]):
        if t <= t1:
            f = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            if isinstance(v0, dict):
                a, b = color(v0), color(v1)
                return {"c": [a[i] + (b[i] - a[i]) * f for i in range(3)]}
            return v0 + (v1 - v0) * f
    return kp[-1][1]


RICH = re.compile(r"<[^>]+>")


def plain(text, rich):
    t = text or ""
    if rich:
        t = RICH.sub("", t)
        t = t.replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&").replace("&quot;", '"')
    return t


GUI = {"Frame", "TextLabel", "TextButton", "TextBox", "ImageLabel", "ImageButton", "ScrollingFrame",
       "ViewportFrame", "CanvasGroup", "VideoFrame"}
TEXT = {"TextLabel", "TextButton", "TextBox"}


def kids_of(node, cls):
    return [c for c in node["children"] if c["cls"] == cls]


def first(node, cls):
    k = kids_of(node, cls)
    return k[0] if k else None


# ------------------------------------------------------------------------------------------
# Text measuring
def wrap_lines(text, fnt, width):
    out = []
    for para in text.split("\n"):
        words = para.split(" ")
        line = ""
        for w in words:
            cand = w if not line else line + " " + w
            if width is None or fnt.getlength(cand) <= width or not line:
                line = cand
            else:
                out.append(line)
                line = w
        out.append(line)
    return out


def text_size(node, width):
    size = node.get("TextSize", 14)
    fnt = font_for(node.get("Font") or node.get("FontFace"), size)
    text = plain(node.get("Text", ""), node.get("RichText"))
    lines = wrap_lines(text, fnt, width if node.get("TextWrapped") else None)
    w = max((fnt.getlength(l) for l in lines), default=0)
    lh = size * (node.get("LineHeight") or 1.0) * 1.2
    return w, lh * len(lines)


# ------------------------------------------------------------------------------------------
# Layout
class Box:
    __slots__ = ("node", "x", "y", "w", "h", "kids", "clip", "z", "ts")

    def __init__(self, node, x, y, w, h):
        self.node, self.x, self.y, self.w, self.h = node, x, y, w, h
        self.kids = []
        self.clip = None
        self.z = node.get("ZIndex", 1)
        self.ts = 1.0


def padding_of(node, w, h):
    p = first(node, "UIPadding")
    if not p:
        return 0, 0, 0, 0
    return (udim(p.get("PaddingLeft"), w), udim(p.get("PaddingTop"), h),
            udim(p.get("PaddingRight"), w), udim(p.get("PaddingBottom"), h))


def own_size(node, pw, ph):
    s = u2(node.get("Size"))
    w = s[0] * pw + s[1]
    h = s[2] * ph + s[3]
    ar = first(node, "UIAspectRatioConstraint")
    if ar:
        ratio = ar.get("AspectRatio", 1) or 1
        dom = enum(ar.get("DominantAxis"), "Width")
        if dom == "Height":
            w = h * ratio
        else:
            h = w / ratio
    sc = first(node, "UISizeConstraint")
    if sc:
        mx = sc.get("MaxSize") or {"x": 1e9, "y": 1e9}
        mn = sc.get("MinSize") or {"x": 0, "y": 0}
        w = max(mn["x"], min(mx["x"], w))
        h = max(mn["y"], min(mx["y"], h))
    return w, h


def visible(n):
    return n["cls"] in GUI and n.get("Visible", True) is not False


def layout(node, x, y, pw, ph, placed=None):
    """Returns a Box for node. `placed` = (x, y) if a layout already decided the position."""
    w, h = own_size(node, pw, ph)
    auto = enum(node.get("AutomaticSize"), "None")
    if node["cls"] in TEXT and auto != "None":
        tw, th = text_size(node, w if auto == "Y" else None)
        pl, pt, pr, pb = padding_of(node, w, h)
        if auto in ("X", "XY"):
            w = max(w, tw + pl + pr)
        if auto in ("Y", "XY"):
            h = max(h, th + pt + pb)
    if placed is None:
        p = u2(node.get("Position"))
        a = node.get("AnchorPoint") or {"x": 0, "y": 0}
        bx = x + p[0] * pw + p[1] - a["x"] * w
        by = y + p[2] * ph + p[3] - a["y"] * h
    else:
        bx, by = placed
    box = Box(node, bx, by, w, h)
    layout_children(box)
    if auto != "None" and node["cls"] not in TEXT and box.kids:
        pl, pt, pr, pb = padding_of(node, w, h)
        right = max(k.x + k.w for k in box.kids) - bx + pr
        bottom = max(k.y + k.h for k in box.kids) - by + pb
        if auto in ("X", "XY") and right > w:
            box.w = right
        if auto in ("Y", "XY") and bottom > h:
            box.h = bottom
    if placed is None and (box.w != w or box.h != h):
        a = node.get("AnchorPoint") or {"x": 0, "y": 0}
        shift(box, -(box.w - w) * a["x"], -(box.h - h) * a["y"])
    us = first(node, "UIScale")
    sc = us.get("Scale", 1) if us else 1
    if sc and abs(sc - 1) > 1e-6:
        a = node.get("AnchorPoint") or {"x": 0, "y": 0}
        scale_box(box, box.x + a["x"] * box.w, box.y + a["y"] * box.h, sc)
    return box


def scale_box(b, ox, oy, sc):
    b.x = ox + (b.x - ox) * sc
    b.y = oy + (b.y - oy) * sc
    b.w *= sc
    b.h *= sc
    b.ts *= sc
    if b.clip:
        x, y, w, h = b.clip
        b.clip = (ox + (x - ox) * sc, oy + (y - oy) * sc, w * sc, h * sc)
    for k in b.kids:
        scale_box(k, ox, oy, sc)


def sorted_kids(node, kids):
    lay = first(node, "UIListLayout") or first(node, "UIGridLayout")
    if lay and enum(lay.get("SortOrder"), "LayoutOrder") == "Name":
        return sorted(kids, key=lambda c: c.get("Name", ""))
    return sorted(kids, key=lambda c: c.get("LayoutOrder", 0))


def layout_children(box):
    node = box.node
    pl, pt, pr, pb = padding_of(node, box.w, box.h)
    cx, cy = box.x + pl, box.y + pt
    cw, ch = max(0, box.w - pl - pr), max(0, box.h - pt - pb)
    scrolling = node["cls"] == "ScrollingFrame"
    if scrolling:
        cs = u2(node.get("CanvasSize"))
        cw = max(cw, cs[0] * box.w + cs[1] - pl - pr) - (node.get("ScrollBarThickness", 12) or 0)
        ch = max(ch, cs[2] * box.h + cs[3] - pt - pb)
    kids = [c for c in node["children"] if visible(c)]
    lst = first(node, "UIListLayout")
    grid = first(node, "UIGridLayout")
    if lst:
        horiz = enum(lst.get("FillDirection"), "Vertical") == "Horizontal"
        gap = udim(lst.get("Padding"), cw if horiz else ch)
        placed = []
        cur = 0.0
        for c in sorted_kids(node, kids):
            b = layout(c, cx, cy, cw, ch, placed=(0, 0))
            placed.append(b)
        total = sum((b.w if horiz else b.h) for b in placed) + gap * max(0, len(placed) - 1)
        ha = enum(lst.get("HorizontalAlignment"), "Left")
        va = enum(lst.get("VerticalAlignment"), "Top")
        if horiz:
            start = cx + {"Left": 0, "Center": (cw - total) / 2, "Right": cw - total}.get(ha, 0)
        else:
            start = cy + {"Top": 0, "Center": (ch - total) / 2, "Bottom": ch - total}.get(va, 0)
        cur = start
        for b in placed:
            if horiz:
                ny = cy + {"Top": 0, "Center": (ch - b.h) / 2, "Bottom": ch - b.h}.get(va, 0)
                shift(b, cur - b.x, ny - b.y)
                cur += b.w + gap
            else:
                nx = cx + {"Left": 0, "Center": (cw - b.w) / 2, "Right": cw - b.w}.get(ha, 0)
                shift(b, nx - b.x, cur - b.y)
                cur += b.h + gap
            box.kids.append(b)
        others = [c for c in kids if False]
    elif grid:
        cs = u2(grid.get("CellSize"))
        cp = u2(grid.get("CellPadding"))
        cwid, chei = cs[0] * cw + cs[1], cs[2] * ch + cs[3]
        gx, gy = cp[0] * cw + cp[1], cp[2] * ch + cp[3]
        cols = max(1, int((cw + gx) // (cwid + gx))) if cwid + gx > 0 else 1
        for i, c in enumerate(sorted_kids(node, kids)):
            c2 = dict(c)
            c2["Size"] = [0, cwid, 0, chei]
            r, col = divmod(i, cols)
            b = layout(c2, cx, cy, cw, ch, placed=(cx + col * (cwid + gx), cy + r * (chei + gy)))
            box.kids.append(b)
    else:
        for c in kids:
            box.kids.append(layout(c, cx, cy, cw, ch))
    if scrolling or node.get("ClipsDescendants"):
        box.clip = (box.x, box.y, box.w, box.h)


def shift(b, dx, dy):
    b.x += dx
    b.y += dy
    if b.clip:
        x, y, w, h = b.clip
        b.clip = (x + dx, y + dy, w, h)
    for k in b.kids:
        shift(k, dx, dy)


def extent(b):
    bottom = b.y + b.h
    for k in b.kids:
        bottom = max(bottom, extent(k))
    return bottom


# ------------------------------------------------------------------------------------------
# Drawing
def gradient_mask(w, h, grad, base_rgb, base_alpha):
    """RGBA image of a gradient-tinted fill."""
    rot = math.radians(grad.get("Rotation", 0) or 0)
    dx, dy = math.cos(rot), math.sin(rot)
    img = Image.new("RGBA", (w, h))
    px = img.load()
    cseq = grad.get("Color")
    tseq = grad.get("Transparency")
    steps = 64
    lut = []
    for i in range(steps + 1):
        t = i / steps
        c = seq_at(cseq, t) if cseq else {"c": [255, 255, 255]}
        tr = seq_at(tseq, t) if tseq else 0
        cc = color(c, (255, 255, 255))
        lut.append((tuple(int(base_rgb[j] * cc[j] / 255) for j in range(3)), int(base_alpha * (1 - (tr or 0)))))
    for yy in range(h):
        for xx in range(w):
            u = ((xx / max(1, w - 1)) - 0.5) * dx + ((yy / max(1, h - 1)) - 0.5) * dy + 0.5
            rgb, a = lut[int(max(0, min(1, u)) * steps)]
            px[xx, yy] = (*rgb, a)
    return img


def radius_of(node, w, h):
    c = first(node, "UICorner")
    if not c:
        return 0
    return max(0, min(udim(c.get("CornerRadius"), min(w, h), 8), min(w, h) / 2))


def paste(canvas, layer, x, y, clip):
    if clip:
        cx, cy, cw, ch = clip
        lx0, ly0 = max(x, cx), max(y, cy)
        lx1, ly1 = min(x + layer.width, cx + cw), min(y + layer.height, cy + ch)
        if lx1 <= lx0 or ly1 <= ly0:
            return
        layer = layer.crop((int(lx0 - x), int(ly0 - y), int(lx1 - x), int(ly1 - y)))
        x, y = lx0, ly0
    canvas.alpha_composite(layer, (int(round(x)), int(round(y))))


def draw_box(canvas, b, clip):
    n = b.node
    if n["cls"] not in GUI:
        return
    rot = n.get("Rotation", 0) or 0
    if rot:
        pad = int(max(b.w, b.h)) + 4
        tmp = Image.new("RGBA", (int(b.w) + 2 * pad, int(b.h) + 2 * pad))
        local = Box(n, pad, pad, b.w, b.h)
        local.ts = b.ts
        draw_core(tmp, local, None)
        tmp = tmp.rotate(-rot, resample=Image.BICUBIC, center=(pad + b.w / 2, pad + b.h / 2))
        paste(canvas, tmp, b.x - pad, b.y - pad, clip)
        return
    draw_core(canvas, b, clip)


def draw_core(canvas, b, clip):
    n = b.node
    w, h = int(round(b.w)), int(round(b.h))
    if w <= 0 or h <= 0:
        return
    grad = first(n, "UIGradient")
    grad = grad if grad and grad.get("Enabled", True) is not False else None
    r = radius_of(n, w, h)
    c0 = first(n, "UICorner")
    if c0 and isinstance(c0.get("CornerRadius"), dict) and c0["CornerRadius"]["s"] == 0:
        r = min(r * b.ts, min(w, h) / 2)
    bt = n.get("BackgroundTransparency", 0)
    if n["cls"] == "ViewportFrame":
        bt = min(bt, 0.0) if n.get("BackgroundTransparency") is None else bt
    if bt < 1:
        alpha = int(255 * (1 - bt))
        rgb = color(n.get("BackgroundColor3"))
        if grad:
            fill = gradient_mask(w, h, grad, rgb, alpha)
        else:
            fill = Image.new("RGBA", (w, h), (*rgb, alpha))
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=r, fill=255)
        layer = Image.new("RGBA", (w, h))
        layer.paste(fill, (0, 0), mask)
        paste(canvas, layer, b.x, b.y, clip)
    if n["cls"] in ("ImageLabel", "ImageButton") and n.get("Image") and n.get("ImageTransparency", 0) < 1:
        rgb = color(n.get("ImageColor3"), (255, 255, 255))
        a = int(70 * (1 - n.get("ImageTransparency", 0)))
        layer = Image.new("RGBA", (w, h))
        ImageDraw.Draw(layer).rounded_rectangle((1, 1, w - 2, h - 2), radius=r, outline=(*rgb, a), width=1)
        paste(canvas, layer, b.x, b.y, clip)
    if n["cls"] == "ViewportFrame":
        layer = Image.new("RGBA", (w, h))
        d = ImageDraw.Draw(layer)
        cx, cy, s = w / 2, h / 2, min(w, h) * 0.22
        d.polygon([(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], outline=(200, 190, 170, 120))
        paste(canvas, layer, b.x, b.y, clip)
    for st in kids_of(n, "UIStroke"):
        if st.get("Enabled", True) is False:
            continue
        mode = enum(st.get("ApplyStrokeMode"), "Contextual")
        if n["cls"] in TEXT and mode != "Border":
            continue  # handled with the text
        t = st.get("Thickness", 1) or 1
        a = int(255 * (1 - (st.get("Transparency", 0) or 0)))
        rgb = color(st.get("Color"), (0, 0, 0))
        pad = int(math.ceil(t))
        layer = Image.new("RGBA", (w + 2 * pad, h + 2 * pad))
        ImageDraw.Draw(layer).rounded_rectangle(
            (pad - t / 2, pad - t / 2, pad + w - 1 + t / 2, pad + h - 1 + t / 2),
            radius=r + t / 2 if r else 0, outline=(*rgb, a), width=max(1, int(round(t))))
        paste(canvas, layer, b.x - pad, b.y - pad, clip)
    if n["cls"] in TEXT:
        draw_text(canvas, b, clip, grad)


def draw_text(canvas, b, clip, grad):
    n = b.node
    text = plain(n.get("Text", ""), n.get("RichText"))
    if not text and n["cls"] == "TextBox" and n.get("PlaceholderText"):
        text = n["PlaceholderText"]
        rgb = color(n.get("PlaceholderColor3"), (178, 178, 178))
    else:
        rgb = color(n.get("TextColor3"), (27, 42, 53))
    tt = n.get("TextTransparency", 0) or 0
    if not text or tt >= 1:
        return
    pl, pt, pr, pb = (v * b.ts for v in padding_of(n, b.w, b.h))
    aw, ah = b.w - pl - pr, b.h - pt - pb
    size = n.get("TextSize", 14) * b.ts
    if n.get("TextScaled"):
        size = max(6, min(n.get("MaxTextSize") or 100, ah * 0.8))
        while size > 6:
            f = font_for(n.get("Font") or n.get("FontFace"), size)
            lines = wrap_lines(text, f, aw if n.get("TextWrapped") else None)
            if max(f.getlength(l) for l in lines) <= aw and len(lines) * size * 1.2 <= ah:
                break
            size -= 1
    fnt = font_for(n.get("Font") or n.get("FontFace"), size)
    lines = wrap_lines(text, fnt, aw if n.get("TextWrapped") else None)
    lh = size * (n.get("LineHeight") or 1.0) * 1.2
    total = lh * len(lines)
    ya = enum(n.get("TextYAlignment"), "Center")
    xa = enum(n.get("TextXAlignment"), "Center")
    y0 = pt + {"Top": 0, "Center": (ah - total) / 2, "Bottom": ah - total}.get(ya, 0)
    W, H = int(b.w) + 40, int(b.h) + 40
    layer = Image.new("RGBA", (max(1, W), max(1, H)))
    d = ImageDraw.Draw(layer)
    alpha = int(255 * (1 - tt))
    stroke = None
    for st in kids_of(n, "UIStroke"):
        if enum(st.get("ApplyStrokeMode"), "Contextual") != "Border" and st.get("Enabled", True) is not False:
            stroke = (color(st.get("Color"), (0, 0, 0)), st.get("Thickness", 1), st.get("Transparency", 0))
    if stroke is None and (n.get("TextStrokeTransparency", 1) or 1) < 1:
        stroke = (color(n.get("TextStrokeColor3"), (0, 0, 0)), 1, n.get("TextStrokeTransparency", 1))
    for i, line in enumerate(lines):
        lw = fnt.getlength(line)
        x0 = pl + {"Left": 0, "Center": (aw - lw) / 2, "Right": aw - lw}.get(xa, 0)
        yy = y0 + i * lh + (lh - size) / 2 - size * 0.08
        kw = {}
        if stroke:
            kw = {"stroke_width": max(1, int(round(stroke[1]))),
                  "stroke_fill": (*stroke[0], int(255 * (1 - (stroke[2] or 0)) * (1 - tt)))}
        fillc = (*rgb, alpha)
        if grad and grad.get("Color"):
            c = color(seq_at(grad.get("Color"), 0.5), (255, 255, 255))
            fillc = (*(int(rgb[j] * c[j] / 255) for j in range(3)), alpha)
        d.text((x0 + 20, yy + 20), line, font=fnt, fill=fillc, **kw)
    paste(canvas, layer, b.x - 20, b.y - 20, clip)


def intersect(a, b):
    if a is None:
        return b
    if b is None:
        return a
    x0, y0 = max(a[0], b[0]), max(a[1], b[1])
    x1, y1 = min(a[0] + a[2], b[0] + b[2]), min(a[1] + a[3], b[1] + b[3])
    return (x0, y0, max(0, x1 - x0), max(0, y1 - y0))


def draw_tree(canvas, b, clip=None):
    draw_box(canvas, b, clip)
    inner = intersect(clip, b.clip) if b.clip else clip
    for k in sorted(b.kids, key=lambda k: k.z):
        draw_tree(canvas, k, inner)


def render(tree, W, H, full=False):
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    guis = [g for g in tree["children"] if g["cls"] == "ScreenGui" and g.get("Enabled", True) is not False]
    guis.sort(key=lambda g: g.get("DisplayOrder", 0))
    for g in guis:
        top = 0 if g.get("IgnoreGuiInset") else TOPBAR
        root = Box(g, 0, top, W, H - top)
        for c in g["children"]:
            if visible(c):
                root.kids.append(layout(c, 0, top, W, H - top))
        draw_tree(canvas, root)
    return canvas


def backdrop(W, H):
    """A dusky stand-in for the 3D world behind the UI."""
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(70 + 40 * t), int(78 + 30 * t), int(92 + 10 * t), 255))
    d.polygon([(0, H * 0.62), (W * 0.3, H * 0.45), (W * 0.55, H * 0.58), (W * 0.8, H * 0.42), (W, H * 0.55), (W, H), (0, H)], fill=(52, 64, 58, 255))
    d.rectangle((0, H * 0.78, W, H), fill=(60, 72, 52, 255))
    return img


def run_scene(luau, scene_path, W, H):
    scene = scene_path.read_text()
    spec = """
local cases = {}
cases["render"] = function()
	__require = require
	workspace.CurrentCamera.ViewportSize = Vector2.new(%d, %d)
	local build = (function()
%s
	end)()
	build()
	__flushDelays(3)
	__dumpGui()
end
return cases
""" % (W, H, scene)
    bundle = build_bundle([("scene", spec)], preludes=("tests/engine_mock.luau", "tools/ui_mock.luau", "tools/ui_fixture.luau"))
    out = ROOT / "build" / "ui_scene.bundle.luau"
    out.parent.mkdir(exist_ok=True)
    out.write_text(bundle)
    res = subprocess.run([luau, str(out)], capture_output=True, text=True)
    for line in res.stdout.splitlines():
        if line.startswith("GUI{"):
            return json.loads(line[3:])
    sys.stderr.write(res.stdout[-4000:] + res.stderr[-4000:])
    raise SystemExit("scene failed: " + scene_path.name)


def main():
    args = sys.argv[1:]
    luau = "luau"
    if args and pathlib.Path(args[0]).is_file() and not args[0].endswith(".luau"):
        luau = args.pop(0)
    size = "1280x720"
    out_dir = ROOT / "build" / "ui"
    scenes = []
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--size":
            size = args[i + 1]
            i += 2
            continue
        if a == "--out":
            out_dir = pathlib.Path(args[i + 1])
            i += 2
            continue
        scenes.append(a)
        i += 1
    W, H = (int(v) for v in size.split("x"))
    scene_dir = ROOT / "tools" / "ui_scenes"
    paths = [scene_dir / (s if s.endswith(".luau") else s + ".luau") for s in scenes] or sorted(p for p in scene_dir.glob("*.luau") if not p.name.startswith("_"))
    out_dir.mkdir(parents=True, exist_ok=True)
    for p in paths:
        tree = run_scene(luau, p, W, H)
        img = backdrop(W, H)
        img.alpha_composite(render(tree, W, H))
        dest = out_dir / (p.stem + f"_{W}x{H}.png")
        img.convert("RGB").save(dest)
        print("wrote", dest)


if __name__ == "__main__":
    main()
