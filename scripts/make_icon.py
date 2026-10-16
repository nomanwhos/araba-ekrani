"""Draws Torpido's app icon: a lit drive-in screen under a marquee bulb row on a night sky.

Usage: uv run --with pillow python -I scripts/make_icon.py <output.png>
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
NIGHT = (10, 19, 36)
NIGHT_HORIZON = (24, 38, 66)
AMBER = (255, 177, 59)


def vertical_gradient(top, bottom):
    img = Image.new("RGB", (SIZE, SIZE))
    draw = ImageDraw.Draw(img)
    for y in range(SIZE):
        t = y / (SIZE - 1)
        draw.line([(0, y), (SIZE, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return img


def lit_screen(width, height):
    """Projector light: brightest at the center, falling off toward the edges."""
    screen = Image.new("RGB", (width, height))
    px = screen.load()
    cx, cy = width / 2, height / 2
    for y in range(height):
        for x in range(width):
            d = min(1.0, (((x - cx) / cx) ** 2 + ((y - cy) / cy) ** 2) ** 0.5)
            px[x, y] = tuple(round(c - (c - e) * d ** 1.6) for c, e in zip((248, 245, 236), (196, 194, 188)))
    return screen


def main(out):
    icon = vertical_gradient(NIGHT, NIGHT_HORIZON)

    sw, sh = 700, 394  # 16:9
    sx, sy = (SIZE - sw) // 2, 400
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle([sx - 10, sy + 10, sx + sw + 10, sy + sh + 40], 40, fill=AMBER + (110,))
    icon.paste(glow.filter(ImageFilter.GaussianBlur(60)), (0, 0), glow.filter(ImageFilter.GaussianBlur(60)))

    mask = Image.new("L", (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, sw - 1, sh - 1], 28, fill=255)
    icon.paste(lit_screen(sw, sh), (sx, sy), mask)

    bulbs = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    halo = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    count, r, y = 7, 22, 300
    step = sw / (count - 1)
    for i in range(count):
        x = sx + i * step
        ImageDraw.Draw(halo).ellipse([x - r * 2.4, y - r * 2.4, x + r * 2.4, y + r * 2.4], fill=AMBER + (140,))
        ImageDraw.Draw(bulbs).ellipse([x - r, y - r, x + r, y + r], fill=AMBER + (255,))
        ImageDraw.Draw(bulbs).ellipse([x - r * 0.45, y - r * 0.55, x + r * 0.15, y - r * 0.05], fill=(255, 236, 200, 255))
    halo = halo.filter(ImageFilter.GaussianBlur(18))
    icon.paste(halo, (0, 0), halo)
    icon.paste(bulbs, (0, 0), bulbs)

    icon.save(out, "PNG")


if __name__ == "__main__":
    main(sys.argv[1])
