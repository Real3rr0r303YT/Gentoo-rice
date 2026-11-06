#!/usr/bin/env python3
"""Erzeugt die Pixel-Texturen für das SDDM-Theme gentoo-rice-blocks.
Alles prozedural erzeugt (eigene Grafiken, keine fremden Texturen).
Nutzung: python3 tools/gen-pixel-textures.py [Zielordner]
"""
import random, sys, os
from PIL import Image

out = sys.argv[1] if len(sys.argv) > 1 else "sddm/gentoo-rice-blocks/assets"
os.makedirs(out, exist_ok=True)
N = 16

def tile(seed, base, spread, specks=(), speck_rate=0.0):
    rnd = random.Random(seed)
    im = Image.new("RGB", (N, N))
    for y in range(N):
        for x in range(N):
            v = rnd.randint(-spread, spread)
            c = tuple(max(0, min(255, ch + v)) for ch in base)
            if specks and rnd.random() < speck_rate:
                c = rnd.choice(specks)
            im.putpixel((x, y), c)
    return im

# Fels: graue Körnung mit dunklen Flecken
stone = tile(7, (118, 118, 122), 14, specks=[(84, 84, 88), (96, 96, 100), (140, 140, 144)], speck_rate=0.12)
# Erde: braun mit dunkleren Krümeln
dirt = tile(11, (121, 85, 58), 12, specks=[(92, 64, 43), (104, 74, 50), (139, 100, 70)], speck_rate=0.16)
# Wiese seitlich: Erde mit Grasrand oben (unregelmäßig)
grass = dirt.copy()
rnd = random.Random(23)
for x in range(N):
    depth = rnd.choice([2, 3, 3, 4, 5])
    for y in range(depth):
        g = rnd.randint(-12, 12)
        grass.putpixel((x, y), (max(0, 88 + g), max(0, 150 + g), max(0, 58 + g)))
# dunkler Fels für Buttons/Rahmen
deep = tile(31, (62, 62, 68), 8, specks=[(48, 48, 54), (74, 74, 80)], speck_rate=0.1)

for name, im in {"stone": stone, "dirt": dirt, "grass": grass, "deepstone": deep}.items():
    im.save(os.path.join(out, f"{name}.png"))
print("Texturen erzeugt in", out)
