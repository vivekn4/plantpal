#!/usr/bin/env python3
"""PlantPal app icon, code-drawn — no stock art, no copied art.

Design, from the color wheel (not from a random palette):
  - Base hue: leaf green, ~123 deg (PlantColors.leaf #2E7D32).
  - Analogous neighbours (wheel +/- 30-60 deg): chartreuse/yellow-
    green and teal/blue-green — used for leaf highlights.
  - Triadic partners (wheel +120 / +240 deg): water blue ~210 deg
    and pot terracotta/red-orange ~15 deg — the droplet and the pot.
  - Accent: sun yellow ~45 deg, analogous to green on the other
    side — used for the droplet sparkle and leaf shine, sparingly.

That is why the icon is a color wheel, not just a green circle:
the outer ring is 12 wheel segments (30 deg each, muted so the
pet still pops), the inner disc is the app's cream, and the pet
in the middle is drawn only from those wheel colours.

The pet itself is pixel art on a 24x24 grid, drawn in code and
upscaled with NEAREST so the pixels stay chunky at any size.
The wheel ring is drawn smooth, then the pixel pet is composited
on top — so the ring reads as a smooth wheel and the pet reads
as a pixel pet, which is exactly PlantPal's look.

Outputs (all from the same master, no hand-edited sizes):
  assets/icon-1024.png
  android mipmap-*: 48 / 72 / 96 / 144 / 192
  web/icons/Icon-192, Icon-512, Icon-maskable-192, Icon-maskable-512
  web/favicon.png (32)
Maskable versions use a smaller pet (80%) so the 20% maskable
safe-zone crop still leaves the whole pet visible.
"""
import colorsys
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

PALETTE = {
    ".": None,  # transparent -> cream disc shows through
    "G": (0x2E, 0x7D, 0x32),  # leaf
    "L": (0x43, 0xA0, 0x47),  # leaf bright
    "B": (0xA5, 0xD6, 0xA7),  # leaf light
    "T": (0x1B, 0x5E, 0x20),  # leaf dark outline
    "P": (0xC1, 0x66, 0x3E),  # pot terracotta (triadic red-orange)
    "D": (0x8E, 0x3B, 0x22),  # pot dark
    "S": (0x4A, 0x32, 0x26),  # soil brown
    "K": (0x2E, 0x1F, 0x16),  # dark (eyes, outlines)
    "W": (0x2E, 0x86, 0xDE),  # water blue (triadic blue)
    "Y": (0xFF, 0xC9, 0x3C),  # sun yellow accent
    "E": (0xFF, 0xFF, 0xFF),  # eye highlight
}

# 24x24 pixel pet. Face is on the pot (reads at 48px, where a
# face on the leaves would vanish). Droplet top-right, leaves
# top-centre, pot bottom-centre.
GRID = [
    "........................",
    "..................WW....",
    ".................WWWW...",
    ".........LLL.....WWW....",
    "........LLLLL............",
    ".......LLGLLLL...........",
    "......LLGGLLLLLL........",
    ".....LLGGLLLLLLLL.......",
    "....LLGGLLLLLLLLL.......",
    ".....LLLLLLLLLLLL.......",
    "......LLLLLLLLL.........",
    ".......LLLLLLL..........",
    "..........GG............",
    "..........GG............",
    ".......PPPPPPPP.........",
    "......PPPPPPPPPP........",
    "......PPPPPPPPPP........",
    "......PPKPPPPKPP........",
    "......PPKPPPPKPP........",
    "......PPPPPPPPPP........",
    "......PPPPKKPPPP........",
    ".......PPPPPPPP.........",
    "........DDDDDD..........",
    "........................",
]


def wheel_color(hue_deg: float) -> tuple[int, int, int]:
    """Muted wheel segment: saturation 0.62, value 0.88."""
    r, g, b = colorsys.hsv_to_rgb(hue_deg / 360.0, 0.62, 0.88)
    return (int(r * 255), int(g * 255), int(b * 255))


def render(size: int, pet_scale: float = 1.0) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = cy = size // 2
    # Outer wheel ring: 12 segments, full bleed to the edge.
    for i in range(12):
        draw.pieslice(
            [0, 0, size, size],
            start=i * 30 - 90,
            end=(i + 1) * 30 - 90,
            fill=wheel_color(i * 30) + (255,),
        )
    # Inner cream disc + dark outline ring.
    inner_r = int(size * 0.36)
    draw.ellipse(
        [cx - inner_r - 10, cy - inner_r - 10, cx + inner_r + 10, cy + inner_r + 10],
        fill=(0x2E, 0x1F, 0x16, 255),
    )
    draw.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
        fill=(0xFF, 0xF6, 0xE3, 255),
    )
    # Pixel pet, NEAREST upscale, centred slightly high so the
    # pot does not sit on the disc's bottom edge.
    grid_h = len(GRID)
    grid_w = len(GRID[0])
    pet_px = int(size * 0.58 * pet_scale)
    cell = pet_px // grid_h
    pet = Image.new("RGBA", (grid_w * cell, grid_h * cell), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pet)
    for y, row in enumerate(GRID):
        for x, ch in enumerate(row):
            color = PALETTE[ch]
            if color is None:
                continue
            pd.rectangle(
                [x * cell, y * cell, (x + 1) * cell - 1, (y + 1) * cell - 1],
                fill=color + (255,),
            )
    img.alpha_composite(
        pet,
        (cx - pet.width // 2, cy - pet.height // 2 - int(size * 0.02)),
    )
    return img


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    print(f"{path.relative_to(ROOT)}  {img.size[0]}x{img.size[1]}")


def main() -> None:
    master = render(1024)
    save(master, ROOT / "assets" / "icon-1024.png")
    for folder, px in [
        ("mipmap-mdpi", 48),
        ("mipmap-hdpi", 72),
        ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144),
        ("mipmap-xxxhdpi", 192),
    ]:
        save(
            master.resize((px, px), Image.LANCZOS),
            ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png",
        )
    for name, px, scale in [
        ("Icon-192.png", 192, 1.0),
        ("Icon-512.png", 512, 1.0),
        ("Icon-maskable-192.png", 192, 0.8),
        ("Icon-maskable-512.png", 512, 0.8),
    ]:
        save(
            render(px, pet_scale=scale),
            ROOT / "web" / "icons" / name,
        )
    save(master.resize((32, 32), Image.LANCZOS), ROOT / "web" / "favicon.png")
    # Also a preview copy in the workspace root of the repo tree
    # for the README / chat, same master file.
    save(master, ROOT / "assets" / "icon.png")


if __name__ == "__main__":
    sys.exit(main())
