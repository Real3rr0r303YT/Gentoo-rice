#!/usr/bin/env python3
"""Erzeugt die Bilder für das GRUB-Theme im Klötzchen-Look (grub/gentoo-rice-blocks).

Nutzung: python3 tools/grub-blocks-assets.py [pfad/zu/unifont.otf]
Texturen: sddm/gentoo-rice-blocks/assets (eigene 16x16-Pixeltexturen, keine Original-Assets).
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "sddm", "gentoo-rice-blocks", "assets")
OUT = os.path.join(ROOT, "grub", "gentoo-rice-blocks")
FONT = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/opentype/unifont/unifont.otf"

W, H = 1920, 1080
MENU_W, ITEM_H = 640, 60      # muss zu theme.txt passen
PX = 3                         # Pixelgröße der Knöpfe
B = 2 * PX                     # Rand (2 Texel)


def tex(name):
    return Image.open(os.path.join(TEX, name + ".png")).convert("RGBA")


def tile(img, w, h, scale):
    t = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    out = Image.new("RGBA", (w, h))
    for y in range(0, h, t.height):
        for x in range(0, w, t.width):
            out.paste(t, (x, y))
    return out


def darken(img, f):
    black = Image.new("RGBA", img.size, (0, 0, 0, 255))
    return Image.blend(img, black, f)


# ── Hintergrund: Erde, abgedunkelt; oben eine Reihe Gras ──
bg = darken(tile(tex("dirt"), W, H, 4), 0.55)
grass = tile(tex("grass"), W, 64, 4)
bg.paste(darken(grass, 0.25), (0, 0))
bg.convert("RGB").save(os.path.join(OUT, "background.png"))


# ── Pixeltext (Unifont 16 px, hochskaliert) ───────────────
def pixel_text(text, zoom, fill, shadow, fill_tex=None):
    font = ImageFont.truetype(FONT, 16)
    l, t, r, b = font.getbbox(text)
    w, h = r - l + 2, b - t + 2
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.fontmode = "1"
    d.text((-l, -t), text, font=font, fill=255)
    small = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = mask.crop((0, 0, w - 1, h - 1))
    small.paste(Image.new("RGBA", sh.size, shadow), (1, 1), sh)
    if fill_tex is not None:
        face = tile(fill_tex, w, h, 1)
    else:
        face = Image.new("RGBA", (w, h), fill)
    small.paste(face, (0, 0), mask)
    return small.resize((w * zoom, h * zoom), Image.NEAREST)


title = pixel_text("GENTOO", 8, None, (40, 40, 44, 255), fill_tex=tex("stone"))
title.save(os.path.join(OUT, "title.png"))

splash = pixel_text("Now with Hyprland!", 2, (255, 255, 0, 255), (63, 63, 0, 255))
splash = splash.rotate(18, resample=Image.NEAREST, expand=True)
splash.save(os.path.join(OUT, "splash.png"))


# ── Knöpfe als 9 Teile (Stein, Bevel, Rahmen) ─────────────
def button(prefix, hot):
    w, h = MENU_W, ITEM_H
    img = tile(tex("stone"), w, h, PX)
    if hot:
        img = Image.blend(img, Image.new("RGBA", img.size, (120, 140, 255, 255)), 0.22)
    d = ImageDraw.Draw(img)
    light, dark = (200, 200, 204, 255), (42, 42, 46, 255)
    frame = (255, 255, 255, 255) if hot else (17, 17, 20, 255)
    d.rectangle([PX, PX, w - PX - 1, 2 * PX - 1], fill=light)          # oben hell
    d.rectangle([PX, PX, 2 * PX - 1, h - PX - 1], fill=light)          # links hell
    d.rectangle([PX, h - 2 * PX, w - PX - 1, h - PX - 1], fill=dark)   # unten dunkel
    d.rectangle([w - 2 * PX, PX, w - PX - 1, h - PX - 1], fill=dark)   # rechts dunkel
    d.rectangle([0, 0, w - 1, h - 1], outline=frame, width=PX)          # Rahmen
    parts = {
        "nw": (0, 0, B, B), "n": (B, 0, w - B, B), "ne": (w - B, 0, w, B),
        "w": (0, B, B, h - B), "c": (B, B, w - B, h - B), "e": (w - B, B, w, h - B),
        "sw": (0, h - B, B, h), "s": (B, h - B, w - B, h), "se": (w - B, h - B, w, h),
    }
    for n, box in parts.items():
        img.crop(box).save(os.path.join(OUT, f"{prefix}_{n}.png"))


button("item", False)
button("select", True)
print("Bilder erzeugt in", OUT)
