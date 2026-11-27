#!/usr/bin/env python3
"""Generate PromptIndo favicons, PWA icons and the Open Graph image.

Run from the repository root:
    python3 scripts/generate_brand_assets.py

No external services are used; the mark and OG card are drawn with Pillow.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "app" / "assets" / "fonts"
APP_DIR = ROOT / "backend" / "src" / "app"
PUBLIC_ICONS = ROOT / "backend" / "public" / "icons"

INK = (8, 8, 10, 255)
PURPLE = (167, 139, 250)
CYAN = (34, 211, 238)
WHITE = (245, 245, 247, 255)
MUTED = (161, 161, 170, 255)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_DIR / name), size)


def lerp(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def diagonal_gradient(size: int, start: tuple[int, int, int], end: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (size, size), start)
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = lerp(start, end, t)
    return img


def rounded(img: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, img.size[0] - 1, img.size[1] - 1), radius=radius, fill=255
    )
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.convert("RGBA"), (0, 0), mask)
    return out


def mark(size: int, radius_ratio: float = 0.22, inset_ratio: float = 0.0) -> Image.Image:
    """Gradient rounded square with a dark 'P' and a small spark."""
    base = diagonal_gradient(size, PURPLE, CYAN).convert("RGBA")
    if radius_ratio:
        base = rounded(base, int(size * radius_ratio))
    draw = ImageDraw.Draw(base)
    inset = int(size * inset_ratio)
    box = (inset, inset, size - inset, size - inset)
    # Letter P
    f = font("Inter-Bold.ttf", int(size * 0.58))
    text = "P"
    bbox = draw.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (size - tw) / 2 - bbox[0]
    ty = (size - th) / 2 - bbox[1] - int(size * 0.015)
    draw.text((tx, ty), text, font=f, fill=INK)
    # Spark dot
    r = max(3, int(size * 0.045))
    cx, cy = int(size * 0.76), int(size * 0.25)
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 255, 235))
    return base


def icon_png(size: int, path: Path, maskable: bool = False) -> None:
    if maskable:
        img = mark(size, radius_ratio=0.0, inset_ratio=0.10)
    else:
        img = mark(size, radius_ratio=0.22)
    img.save(path, optimize=True)


def og_image(path: Path) -> None:
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), (8, 8, 10))
    draw = ImageDraw.Draw(img)

    # Soft brand glows.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((-180, -220, 520, 360), fill=(167, 139, 250, 80))
    gd.ellipse((820, 300, 1380, 820), fill=(34, 211, 238, 60))
    glow = glow.filter(ImageFilter.GaussianBlur(90))
    img = Image.alpha_composite(img.convert("RGBA"), glow)
    draw = ImageDraw.Draw(img)

    # Subtle grid.
    for x in range(0, W, 60):
        draw.line((x, 0, x, H), fill=(255, 255, 255, 6), width=1)
    for y in range(0, H, 60):
        draw.line((0, y, W, y), fill=(255, 255, 255, 6), width=1)

    # Logo + wordmark.
    logo = mark(88, radius_ratio=0.24)
    img.paste(logo, (84, 70), logo)
    draw.text((188, 80), "PromptIndo", font=font("Inter-Bold.ttf", 44), fill=WHITE)

    # Headline (left column stays clear of the card).
    draw.text((84, 206), "Prompts that work.", font=font("Inter-Bold.ttf", 60), fill=WHITE)
    draw.text(
        (84, 276),
        "Shared by people who use them.",
        font=font("Inter-Bold.ttf", 36),
        fill=(167, 139, 250, 255),
    )
    draw.text(
        (86, 380),
        "Discover real prompts for writing, coding,\ndesign and business. Copy, remix, publish.",
        font=font("Inter-Regular.ttf", 21),
        fill=(209, 209, 214),
        spacing=10,
    )

    # Right-hand prompt card.
    CW, CH = 350, 420
    card = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle((0, 0, CW - 1, CH - 1), radius=26, fill=(20, 20, 24, 255), outline=(48, 48, 56, 255), width=2)
    thumb = diagonal_gradient(310, (109, 40, 217), (219, 39, 119)).convert("RGBA")
    thumb = rounded(thumb, 16)
    card.paste(thumb, (20, 20), thumb)
    cd.text((22, 230), "Cinematic product photography", font=font("Inter-Bold.ttf", 19), fill=WHITE)
    cd.text((22, 260), "@maya  ·  GPT-4o  ·  2.4k copies", font=font("Inter-Regular.ttf", 13), fill=MUTED)
    for i, label in enumerate(["photography", "midjourney"]):
        x = 22 + i * 104
        cd.rounded_rectangle((x, 294, x + 92, 322), radius=14, fill=(31, 31, 36, 255), outline=(48, 48, 56, 255))
        cd.text((x + 11, 300), label, font=font("Inter-Medium.ttf", 12), fill=(209, 209, 214, 255))
    cd.rounded_rectangle((22, 344, CW - 22, 388), radius=14, fill=(167, 139, 250, 255))
    bbox = cd.textbbox((0, 0), "Copy prompt", font=font("Inter-Bold.ttf", 17))
    tw = bbox[2] - bbox[0]
    cd.text(((CW - tw) / 2, 356), "Copy prompt", font=font("Inter-Bold.ttf", 17), fill=INK)
    img.paste(card, (790, 105), card)

    # Footer.
    draw.line((84, 552, 1116, 552), fill=(38, 38, 42, 255), width=1)
    draw.text((84, 570), "www.promptindo.app", font=font("Inter-SemiBold.ttf", 18), fill=WHITE)
    draw.text((922, 571), "Android  ·  Free", font=font("Inter-Regular.ttf", 17), fill=MUTED)

    img.convert("RGB").save(path, optimize=True)


def main() -> None:
    PUBLIC_ICONS.mkdir(parents=True, exist_ok=True)
    icon_png(512, APP_DIR / "icon.png")
    icon_png(180, APP_DIR / "apple-icon.png")
    icon_png(192, PUBLIC_ICONS / "icon-192.png")
    icon_png(512, PUBLIC_ICONS / "icon-512.png")
    icon_png(512, PUBLIC_ICONS / "icon-maskable-512.png", maskable=True)

    # Multi-resolution favicon.
    ico = mark(256, radius_ratio=0.22)
    ico.save(
        APP_DIR / "favicon.ico",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64)],
    )

    og_image(APP_DIR / "opengraph-image.png")
    og_image(APP_DIR / "twitter-image.png")
    print("Generated PromptIndo brand assets.")


if __name__ == "__main__":
    main()
