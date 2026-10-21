#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Simple Live TV 应用图标生成器

输入: assets/images/app_logo_source.png (用户提供的原图, 白底)
输出:
  - assets/images/app_logo.png            图形本体(外圈白底已去掉, 内圈白色播放三角保留)
  - android/.../mipmap-*/ic_launcher.png  桌面图标(深色渐变底 + 图形)
  - android/.../mipmap-*/ic_launcher_foreground.png  自适应图标前景层(透明底)
  - android/.../mipmap-xhdpi/ic_banner.png            TV 横幅

用法(在仓库根目录):
    python tools/gen_app_icon.py
"""
import math
import os
import subprocess

import numpy as np
from PIL import Image
from scipy import ndimage

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(REPO, "simple_live_tv_app")
RES = os.path.join(APP, "android", "app", "src", "main", "res")
SOURCE = os.path.join(APP, "assets", "images", "app_logo_source.png")
MARK_OUT = os.path.join(APP, "assets", "images", "app_logo.png")
WORK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_icon_out")

CHROME_CANDIDATES = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
]

# 图标底色: 跟 APP 里的深色渐变同一套
BG_TOP = (0x14, 0x21, 0x3D)
BG_MID = (0x1D, 0x4E, 0x8C)
BG_BOTTOM = (0x2F, 0x80, 0xED)


def find_chrome():
    for c in CHROME_CANDIDATES:
        if os.path.exists(c):
            return c
    raise RuntimeError("找不到 Chrome/Edge, 无法渲染 SVG")


def extract_mark(path):
    """把原图里的图形抠出来: 外圈跟边界连着的白色变透明, 图形内部的白色保留"""
    im = Image.open(path).convert("RGB")
    a = np.asarray(im).astype(np.int16)
    # 跟背景白的距离, 用来算软边
    bg = a[0, 0].astype(np.float64)
    dist = np.sqrt(((a - bg) ** 2).sum(axis=2))
    alpha = np.clip(dist / 40.0, 0.0, 1.0)

    near_white = dist < 12
    labels, n = ndimage.label(near_white)
    if n == 0:
        raise RuntimeError("没找到白色区域")
    # 跟画面边界相连的都是外圈背景
    border_labels = set(labels[0, :]) | set(labels[-1, :]) | set(labels[:, 0]) | set(labels[:, -1])
    border_labels.discard(0)
    outer = np.isin(labels, list(border_labels))
    # 外圈挖空, 图形里被包住的白色(播放三角)保留
    alpha[outer] = 0.0

    rgba = np.dstack([np.asarray(im), (alpha * 255).astype(np.uint8)])
    out = Image.fromarray(rgba, "RGBA")

    # 裁到图形的外接框
    bbox = out.getbbox()
    if bbox is None:
        raise RuntimeError("抠完没有内容了")
    return out.crop(bbox)


def gradient_bg(size):
    """深色渐变底, 和 APP 启动页一致"""
    bg = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    px = bg.load()
    for y in range(size):
        t = y / max(1, size - 1)
        if t < 0.5:
            k = t / 0.5
            c = tuple(int(BG_TOP[i] + (BG_MID[i] - BG_TOP[i]) * k) for i in range(3))
        else:
            k = (t - 0.5) / 0.5
            c = tuple(int(BG_MID[i] + (BG_BOTTOM[i] - BG_MID[i]) * k) for i in range(3))
        for x in range(size):
            px[x, y] = (c[0], c[1], c[2], 255)
    return bg


def place_tight(mark, target):
    """按最长边缩放到 target, 不加透明画布"""
    w, h = mark.size
    scale = target / max(w, h)
    return mark.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)


def place(mark, canvas_size, ratio):
    """把图形按比例放到画布中间"""
    w, h = mark.size
    target = int(canvas_size * ratio)
    scale = target / max(w, h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    resized = mark.resize((nw, nh), Image.LANCZOS)
    out = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    out.paste(resized, ((canvas_size - nw) // 2, (canvas_size - nh) // 2), resized)
    return out


def rounded(img, radius_ratio=0.22):
    mask = Image.new("L", img.size, 0)
    from PIL import ImageDraw

    d = ImageDraw.Draw(mask)
    d.rounded_rectangle(
        [0, 0, img.size[0] - 1, img.size[1] - 1],
        radius=int(img.size[0] * radius_ratio),
        fill=255,
    )
    out = img.copy()
    out.putalpha(mask)
    return out


def save_png(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = img.resize((size, size), Image.LANCZOS)
    img.save(path, "PNG", optimize=True)
    print("  %-62s %4d  %6.1f KB" % (path.replace(REPO + os.sep, ""), size,
                                     os.path.getsize(path) / 1024))


def build_banner(mark, chrome):
    """TV 横幅: 图形 + 文字"""
    w, h = 1024, 576
    bg = gradient_bg(h).resize((w, h), Image.LANCZOS)
    logo = place_tight(mark, int(h * 0.58))
    bg.alpha_composite(logo, (int(w * 0.05), (h - logo.size[1]) // 2))
    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <text x="{w * 0.40}" y="{h * 0.50}" font-family="Segoe UI, Roboto, Arial, sans-serif"
        font-size="{h * 0.115}" font-weight="600" fill="#FFFFFF" letter-spacing="0.5">Simple Live TV</text>
  <text x="{w * 0.405}" y="{h * 0.64}" font-family="Segoe UI, Roboto, Arial, sans-serif"
        font-size="{h * 0.058}" fill="#A6ECFF" letter-spacing="2">直播电视</text>
</svg>"""
    svg_path = os.path.join(WORK, "banner_text.svg")
    with open(svg_path, "w", encoding="utf-8") as f:
        f.write(svg)
    png = os.path.join(WORK, "banner_text.png")
    subprocess.run(
        [chrome, "--headless", "--disable-gpu", "--no-sandbox", "--hide-scrollbars",
         "--default-background-color=00000000", f"--screenshot={png}",
         f"--window-size={w},{h}", "file:///" + svg_path.replace("\\", "/")],
        capture_output=True, timeout=120,
    )
    text_layer = Image.open(png).convert("RGBA")
    bg.alpha_composite(text_layer)
    return bg


def main():
    os.makedirs(WORK, exist_ok=True)
    chrome = find_chrome()

    print("抠图 ...")
    mark = extract_mark(SOURCE)
    mark.save(MARK_OUT, "PNG", optimize=True)
    print("  图形 %dx%d -> %s" % (mark.size[0], mark.size[1], MARK_OUT.replace(REPO + os.sep, "")))

    big = place(mark, 1024, 0.78)

    print("输出桌面图标 ...")
    bg = gradient_bg(1024)
    legacy = bg.copy()
    legacy.alpha_composite(big)
    legacy = rounded(legacy, 0.22)
    for folder, px in [("mipmap-mdpi", 48), ("mipmap-hdpi", 72), ("mipmap-xhdpi", 96),
                       ("mipmap-xxhdpi", 144), ("mipmap-xxxhdpi", 192),
                       ("mipmap-ldpi", 36)]:
        save_png(legacy, os.path.join(RES, folder, "ic_launcher.png"), px)

    print("输出自适应图标前景层 ...")
    fg = place(mark, 1024, 0.60)
    for folder, px in [("mipmap-mdpi", 108), ("mipmap-hdpi", 162), ("mipmap-xhdpi", 216),
                       ("mipmap-xxhdpi", 324), ("mipmap-xxxhdpi", 432)]:
        save_png(fg, os.path.join(RES, folder, "ic_launcher_foreground.png"), px)

    print("输出 TV 横幅 ...")
    banner = build_banner(mark, chrome)
    banner.save(os.path.join(RES, "mipmap-xhdpi", "ic_banner.png"), "PNG", optimize=True)
    print("  mipmap-xhdpi/ic_banner.png 320x180")
    banner.resize((320, 180), Image.LANCZOS).save(os.path.join(WORK, "banner_preview.png"))

    preview = legacy.resize((512, 512), Image.LANCZOS)
    preview.save(os.path.join(WORK, "preview.png"))
    print("\n预览: %s" % WORK)


if __name__ == "__main__":
    main()
