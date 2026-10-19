#!/usr/bin/env python3
# Radiojoy terminal splash: heads.png (Alastor + Emily, cropped from the official
# hazbinhotel.fandom.com renders) -> half-block ANSI frames NN.txt.
# 00.txt is the clear picture; 01.. "tune in" from radio static to the picture.
# Usage: build.py [cols] [heads image] [output dir]   (defaults: 46 heads.png .)
import random, sys
from pathlib import Path
from PIL import Image

here = Path(__file__).resolve().parent
cols = int(sys.argv[1]) if len(sys.argv) > 1 else 46
steps = 14
static = [(220, 34, 73), (236, 233, 247), (125, 130, 188), (43, 26, 29), (157, 153, 188)]

src = Image.open(here / (sys.argv[2] if len(sys.argv) > 2 else "heads.png")).convert("RGBA")
dest = here / (sys.argv[3] if len(sys.argv) > 3 else ".")
dest.mkdir(exist_ok=True)
rows = round(src.height * cols / src.width / 2)
base = src.resize((cols, rows * 2), Image.LANCZOS).load()

def render(noise, seed):
    rnd = random.Random(seed)
    shift = {y: rnd.choice((-2, -1, 1, 2)) for y in range(rows * 2) if rnd.random() < noise * 0.5}
    def px(x, y):
        if rnd.random() < noise:
            return static[rnd.randrange(len(static))] + (255,)
        x = min(cols - 1, max(0, x + shift.get(y, 0)))
        return base[x, y]
    lines = []
    for r in range(rows):
        s = ""
        for x in range(cols):
            t, b = px(x, 2 * r), px(x, 2 * r + 1)
            ton, bon = t[3] > 110, b[3] > 110
            if ton and bon:
                s += f"\x1b[38;2;{t[0]};{t[1]};{t[2]};48;2;{b[0]};{b[1]};{b[2]}m▀\x1b[0m"
            elif ton:
                s += f"\x1b[38;2;{t[0]};{t[1]};{t[2]}m▀\x1b[0m"
            elif bon:
                s += f"\x1b[38;2;{b[0]};{b[1]};{b[2]}m▄\x1b[0m"
            else:
                s += " "
        lines.append(s)
    return "\n".join(lines) + "\n"

for old in dest.glob("[0-9][0-9].txt"):
    old.unlink()
(dest / "00.txt").write_text(render(0, 0))
for i in range(1, steps + 1):
    (dest / f"{i:02d}.txt").write_text(render((1 - (i - 1) / steps) ** 1.6 * 0.9, i))
print(f"{steps + 1} frames, {cols}x{rows}")
