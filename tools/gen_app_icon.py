#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Simple Live TV 应用图标生成器
设计：深蓝渐变圆角底 + 白色播放三角 + 青色直播信号弧
输出：legacy ic_launcher / adaptive ic_launcher_foreground / TV banner

用法（在仓库根目录）：
    python tools/gen_app_icon.py

依赖：Pillow（pip install pillow）
渲染：Chrome 无头模式（自动在常见安装路径里找），只用来把 SVG 栅格化成 PNG。
"""
import math
import os
import subprocess
import sys

from PIL import Image

# 仓库根目录 = 本文件所在目录的上一级
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(REPO, "simple_live_tv_app", "android", "app", "src", "main", "res")
WORK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_icon_out")

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]


def find_chrome():
    for c in CHROME_CANDIDATES:
        if os.path.exists(c):
            return c
    raise RuntimeError("找不到 Chrome/Edge，无法渲染 SVG")


CHROME = find_chrome()

# ---------------------------------------------------------------- 几何
TRI = [(0.0, 0.0), (212.0, 110.0), (0.0, 220.0)]   # 播放三角
TRI_R = 34.0                                        # 圆角
ARC_C = (212.0, 110.0)                              # 信号弧圆心
ARC_R = [66.0, 104.0]                               # 信号弧半径
ARC_A = 46.0                                        # 信号弧张角(半角)
ARC_W = 24.0                                        # 信号弧线宽
STROKE = 13.0                                       # 三角描边(圆角用)


def _unit(ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    d = math.hypot(dx, dy)
    return dx / d, dy / d


def rounded_triangle_path():
    """把三角形变成带圆角的三次贝塞尔路径"""
    n = len(TRI)
    segs = []
    for i in range(n):
        p_prev = TRI[(i - 1) % n]
        p = TRI[i]
        p_next = TRI[(i + 1) % n]
        l1 = math.dist(p, p_prev) / 2
        l2 = math.dist(p, p_next) / 2
        r = min(TRI_R, l1, l2)
        ux, uy = _unit(p[0], p[1], p_prev[0], p_prev[1])
        vx, vy = _unit(p[0], p[1], p_next[0], p_next[1])
        a = (p[0] + ux * r, p[1] + uy * r)
        b = (p[0] + vx * r, p[1] + vy * r)
        segs.append((a, p, b))
    d = "M %.2f %.2f" % (segs[0][2][0], segs[0][2][1])
    for i in range(1, n):
        a, p, b = segs[i]
        d += " L %.2f %.2f Q %.2f %.2f %.2f %.2f" % (a[0], a[1], p[0], p[1], b[0], b[1])
    a, p, b = segs[0]
    d += " L %.2f %.2f Q %.2f %.2f %.2f %.2f" % (a[0], a[1], p[0], p[1], b[0], b[1])
    return d + " Z"


def arc_path(r):
    cx, cy = ARC_C
    a = math.radians(ARC_A)
    x1 = cx + r * math.cos(-a)
    y1 = cy + r * math.sin(-a)
    x2 = cx + r * math.cos(a)
    y2 = cy + r * math.sin(a)
    return "M %.2f %.2f A %.2f %.2f 0 0 1 %.2f %.2f" % (x1, y1, r, r, x2, y2)


# 图形实际占位（含描边/圆角外扩）
GLYPH_W = ARC_C[0] + max(ARC_R) + ARC_W / 2
GLYPH_H = 220.0


def glyph_svg(scale, tx, ty, color_tri="#FFFFFF", color_arc="#A6ECFF"):
    """输出 glyph 组（已应用缩放/平移）"""
    tri = rounded_triangle_path()
    parts = ['<g transform="translate(%.3f %.3f) scale(%.4f)">' % (tx, ty, scale)]
    parts.append('<path d="%s" fill="%s"/>' % (tri, color_tri))
    for i, r in enumerate(ARC_R):
        op = "1" if i == 0 else "0.55"
        parts.append(
            '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" '
            'stroke-linecap="round" opacity="%s"/>' % (arc_path(r), color_arc, ARC_W, op)
        )
    parts.append("</g>")
    return "\n".join(parts)


def svg_full(size=512, radius_ratio=0.22):
    """完整图标（legacy 用）：渐变圆角底 + glyph"""
    scale = size * 0.60 / GLYPH_W
    g = glyph_svg(scale, (size - GLYPH_W * scale) / 2.0, (size - GLYPH_H * scale) / 2.0)
    r = size * radius_ratio
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#14213D"/>
      <stop offset="0.55" stop-color="#1D4E8C"/>
      <stop offset="1" stop-color="#2F80ED"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.28" cy="0.22" r="0.75">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.20"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
    <clipPath id="clip"><rect x="0" y="0" width="{size}" height="{size}" rx="{r}" ry="{r}"/></clipPath>
  </defs>
  <g clip-path="url(#clip)">
    <rect width="{size}" height="{size}" fill="url(#bg)"/>
    <rect width="{size}" height="{size}" fill="url(#glow)"/>
    {g}
  </g>
</svg>
"""


def svg_foreground(size=512):
    """自适应图标前景层：只有 glyph，居中在安全区内"""
    scale = size * 0.46 / GLYPH_W
    tx = (size - GLYPH_W * scale) / 2.0
    ty = (size - GLYPH_H * scale) / 2.0
    g = glyph_svg(scale, tx, ty)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">
  {g}
</svg>
"""


def svg_banner(w=1024, h=576):
    """TV 启动横幅"""
    scale = h * 0.42 / GLYPH_H
    g = glyph_svg(scale, w * 0.06, (h - GLYPH_H * scale) / 2.0)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#14213D"/>
      <stop offset="0.55" stop-color="#1D4E8C"/>
      <stop offset="1" stop-color="#2F80ED"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.22" cy="0.25" r="0.8">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.18"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0"/>
    </radialGradient>
  </defs>
  <rect width="{w}" height="{h}" fill="url(#bg)"/>
  <rect width="{w}" height="{h}" fill="url(#glow)"/>
  {g}
  <text x="{w * 0.44}" y="{h * 0.50}" font-family="Segoe UI, Roboto, Arial, sans-serif"
        font-size="{h * 0.115}" font-weight="600" fill="#FFFFFF" letter-spacing="0.5">Simple Live TV</text>
  <text x="{w * 0.445}" y="{h * 0.64}" font-family="Segoe UI, Roboto, Arial, sans-serif"
        font-size="{h * 0.058}" fill="#A6ECFF" letter-spacing="2">直播电视</text>
</svg>
"""


def svg_banner_fg(w=1024, h=576):
    """TV 横幅前景层：透明底 + 左侧 glyph"""
    scale = h * 0.42 / GLYPH_H
    g = glyph_svg(scale, w * 0.06, (h - GLYPH_H * scale) / 2.0)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  {g}
</svg>
"""


def render(svg_path, png_path, w, h):
    cmd = [
        CHROME, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
        "--default-background-color=00000000",
        f"--screenshot={png_path}", f"--window-size={w},{h}",
        "file:///" + svg_path.replace("\\", "/"),
    ]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if not os.path.exists(png_path):
        raise RuntimeError("render failed: %s\n%s" % (svg_path, r.stderr[-800:]))


def save(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    img = img.resize((size, size), Image.LANCZOS)
    img.save(path, "PNG", optimize=True)
    print("  %-58s %4dx%-4d %6.1f KB" % (path.replace(RES + "\\", ""), size, size,
                                          os.path.getsize(path) / 1024))


def main():
    os.makedirs(WORK, exist_ok=True)
    print("渲染 SVG ...")
    svg_full_p = os.path.join(WORK, "full.svg")
    svg_fg_p = os.path.join(WORK, "fg.svg")
    svg_ban_p = os.path.join(WORK, "banner.svg")
    with open(svg_full_p, "w", encoding="utf-8") as f:
        f.write(svg_full(1024))
    with open(svg_fg_p, "w", encoding="utf-8") as f:
        f.write(svg_foreground(1024))
    with open(svg_ban_p, "w", encoding="utf-8") as f:
        f.write(svg_banner(1024, 576))

    render(svg_full_p, os.path.join(WORK, "full.png"), 1024, 1024)
    render(svg_fg_p, os.path.join(WORK, "fg.png"), 1024, 1024)
    render(svg_ban_p, os.path.join(WORK, "banner.png"), 1024, 576)
    full = Image.open(os.path.join(WORK, "full.png")).convert("RGBA")
    fg = Image.open(os.path.join(WORK, "fg.png")).convert("RGBA")
    ban = Image.open(os.path.join(WORK, "banner.png")).convert("RGBA")

    print("输出 legacy ic_launcher.png ...")
    for folder, px in [("mipmap-ldpi", 36), ("mipmap-mdpi", 48), ("mipmap-hdpi", 72),
                        ("mipmap-xhdpi", 96), ("mipmap-xxhdpi", 144), ("mipmap-xxxhdpi", 192)]:
        save(full, os.path.join(RES, folder, "ic_launcher.png"), px)

    print("输出 adaptive ic_launcher_foreground.png ...")
    for folder, px in [("mipmap-mdpi", 108), ("mipmap-hdpi", 162), ("mipmap-xhdpi", 216),
                       ("mipmap-xxhdpi", 324), ("mipmap-xxxhdpi", 432)]:
        save(fg, os.path.join(RES, folder, "ic_launcher_foreground.png"), px)

    print("输出 TV banner ...")
    os.makedirs(os.path.join(RES, "mipmap-xhdpi"), exist_ok=True)
    ban320 = ban.resize((320, 180), Image.LANCZOS)
    ban320.save(os.path.join(RES, "mipmap-xhdpi", "ic_banner.png"), "PNG", optimize=True)
    print("  mipmap-xhdpi/ic_banner.png 320x180")
    # 横幅自适应前景层（透明底）
    svg_ban_fg_p = os.path.join(WORK, "banner_fg.svg")
    with open(svg_ban_fg_p, "w", encoding="utf-8") as f:
        f.write(svg_banner_fg())
    render(svg_ban_fg_p, os.path.join(WORK, "banner_fg.png"), 1024, 576)
    banfg = Image.open(os.path.join(WORK, "banner_fg.png")).convert("RGBA")
    banfg.resize((320, 180), Image.LANCZOS).save(
        os.path.join(RES, "mipmap-xhdpi", "ic_banner_foreground.png"), "PNG", optimize=True)
    print("  mipmap-xhdpi/ic_banner_foreground.png 320x180")
    ban320.save(os.path.join(WORK, "banner_preview.png"), "PNG")
    full.resize((512, 512), Image.LANCZOS).save(os.path.join(WORK, "preview_full.png"))
    fg.resize((512, 512), Image.LANCZOS).save(os.path.join(WORK, "preview_fg.png"))
    print("\n预览: %s" % WORK)


if __name__ == "__main__":
    main()
