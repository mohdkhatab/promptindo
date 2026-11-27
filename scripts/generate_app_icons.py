#!/usr/bin/env python3
"""Generate Android, iOS and web icons from the PromptIndo app artwork.

Source: scripts/assets/app-icon.webp (1600x1600, rounded dark-purple mark).
The white surround is flood-filled with the icon's own background colour so
launcher icons are full-bleed and have no white corners.

Run from the repository root:
    python3 scripts/generate_app_icons.py
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts" / "assets" / "app-icon.webp"
ANDROID_RES = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
IOS_ICONS = ROOT / "app" / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WEB_APP = ROOT / "backend" / "src" / "app"
WEB_ICONS = ROOT / "backend" / "public" / "icons"

ANDROID_SIZES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def master() -> Image.Image:
    img = Image.open(SOURCE).convert("RGB")
    bg = img.getpixel((120, 120))
    w, h = img.size
    for corner in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        ImageDraw.floodfill(img, corner, bg, thresh=70)
    return img


def resized(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.LANCZOS)


def round_icon(img: Image.Image, size: int) -> Image.Image:
    square = resized(img, size).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    square.putalpha(mask)
    return square


def android_icons(img: Image.Image) -> None:
    for density, size in ANDROID_SIZES.items():
        folder = ANDROID_RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        resized(img, size).save(folder / "ic_launcher.png", optimize=True)
        round_icon(img, size).save(folder / "ic_launcher_round.png", optimize=True)


def ios_icons(img: Image.Image) -> None:
    contents = json.loads((IOS_ICONS / "Contents.json").read_text())
    for entry in contents.get("images", []):
        filename = entry.get("filename")
        size = entry.get("size")
        scale = entry.get("scale")
        if not filename or not size or not scale:
            continue
        base = float(size.split("x")[0])
        pixels = int(round(base * int(scale.rstrip("x"))))
        resized(img, pixels).save(IOS_ICONS / filename, optimize=True)
        # iOS rejects alpha in App Store icons; save as opaque RGB.
    for png in IOS_ICONS.glob("*.png"):
        rgb = Image.open(png).convert("RGB")
        rgb.save(png, optimize=True)


def web_icons(img: Image.Image) -> None:
    WEB_ICONS.mkdir(parents=True, exist_ok=True)
    resized(img, 512).save(WEB_APP / "icon.png", optimize=True)
    resized(img, 180).save(WEB_APP / "apple-icon.png", optimize=True)
    resized(img, 192).save(WEB_ICONS / "icon-192.png", optimize=True)
    resized(img, 512).save(WEB_ICONS / "icon-512.png", optimize=True)
    resized(img, 512).save(WEB_ICONS / "icon-maskable-512.png", optimize=True)
    resized(img, 256).convert("RGBA").save(
        WEB_APP / "favicon.ico",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64)],
    )


def main() -> None:
    img = master()
    android_icons(img)
    ios_icons(img)
    web_icons(img)
    print("Generated Android, iOS and web icons from the PromptIndo artwork.")


if __name__ == "__main__":
    main()
