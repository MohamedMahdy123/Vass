"""Render clean, transparent-background garment product shots for the demo
wardrobe. These are bundled as assets (assets/garments/) and used as the demo
seed's `processed_image_url` cut-outs — the real-item look without stock photos.

Illustrated placeholders: a designer or product photography can drop real
transparent PNGs over these at the same paths. Run:  python tool/render_garments.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter

SS = 4          # supersample factor for smooth anti-aliasing
OUT = 512       # final asset size (px, square)
W = OUT * SS
OUTDIR = os.path.join(os.path.dirname(__file__), "..", "assets", "garments")


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(c, other, t):
    return tuple(round(c[i] + (other[i] - c[i]) * t) for i in range(3))


def lighten(c, t):
    return mix(c, (255, 255, 255), t)


def darken(c, t):
    return mix(c, (0, 0, 0), t)


def s(v):
    """Scale a 0..100 coordinate into the supersampled canvas."""
    return v / 100.0 * W


def pts(seq):
    return [(s(x), s(y)) for x, y in seq]


# ---- garment outlines in a 0..100 space -----------------------------------

TOP = [(34, 22), (16, 35), (25, 50), (34, 45), (34, 84), (66, 84), (66, 45),
       (75, 50), (84, 35), (66, 22), (58, 30), (50, 31), (42, 30)]

OUTER = [(34, 18), (13, 32), (23, 53), (33, 47), (33, 88), (46, 88), (46, 40),
         (50, 46), (54, 40), (54, 88), (67, 88), (67, 47), (77, 53), (87, 32),
         (66, 18), (54, 30), (50, 42), (46, 30)]

BOTTOMS = [(33, 14), (67, 14), (65, 52), (61, 88), (52, 88), (50, 52),
           (48, 88), (39, 88), (35, 52)]

DRESS = [(38, 18), (23, 30), (31, 43), (38, 38), (30, 88), (70, 88), (62, 38),
         (69, 43), (77, 30), (62, 18), (54, 28), (50, 29), (46, 28)]


def draw_poly(d, poly, fill):
    d.polygon(pts(poly), fill=fill)


def shape_mask(kind):
    """Return an L-mode mask of the garment silhouette (white on black)."""
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    if kind == "tops":
        draw_poly(d, TOP, 255)
    elif kind == "outerwear":
        draw_poly(d, OUTER, 255)
    elif kind == "bottoms":
        draw_poly(d, BOTTOMS, 255)
    elif kind == "dresses":
        draw_poly(d, DRESS, 255)
    elif kind == "accessories":
        d.rounded_rectangle([s(27), s(30), s(73), s(70)], radius=s(9), fill=255)
    elif kind == "footwear":
        # a low shoe: rounded body + toe
        d.rounded_rectangle([s(16), s(46), s(86), s(72)], radius=s(13), fill=255)
        d.pieslice([s(56), s(30), s(92), s(74)], 180, 360, fill=255)
    else:  # folded / other
        d.rounded_rectangle([s(24), s(26), s(76), s(74)], radius=s(11), fill=255)
    return m


def vertical_gradient(top, bottom):
    grad = Image.new("RGB", (1, W))
    for y in range(W):
        t = y / (W - 1)
        grad.putpixel((0, y), mix(top, bottom, t))
    return grad.resize((W, W))


def render(kind, color_hex):
    color = hx(color_hex)
    mask = shape_mask(kind)

    canvas = Image.new("RGBA", (W, W), (0, 0, 0, 0))

    # Soft contact shadow beneath the piece.
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    shadow.putalpha(mask.point(lambda a: int(a * 0.30)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(W * 0.018))
    canvas.alpha_composite(shadow, (0, int(W * 0.012)))

    # Shaded fabric fill (lighter top, deeper bottom).
    fill = vertical_gradient(lighten(color, 0.14), darken(color, 0.16)).convert("RGBA")
    canvas.paste(fill, (0, 0), mask)

    # Gentle top sheen.
    sheen = Image.new("RGBA", (W, W), (255, 255, 255, 0))
    sheen.putalpha(vertical_gradient((90, 90, 90), (0, 0, 0)).convert("L").point(
        lambda a: int(a * 0.22)))
    canvas.paste(sheen, (0, 0), Image.composite(sheen.getchannel("A"),
                 Image.new("L", (W, W), 0), mask))

    # Crisp seam outline.
    edge = mask.filter(ImageFilter.FIND_EDGES).filter(
        ImageFilter.GaussianBlur(W * 0.001))
    outline = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    outline.putalpha(edge.point(lambda a: min(90, int(a * 0.7))))
    canvas.alpha_composite(outline)

    return canvas.resize((OUT, OUT), Image.LANCZOS)


# id -> (category, color hex)  — matches lib/state/wardrobe_state.dart demo seed
ITEMS = {
    "demo-1": ("tops", "#8A857B"),        # Ribbed Wool Sweater / Ash
    "demo-2": ("tops", "#F2EDE3"),        # Oxford Shirt / White
    "demo-3": ("tops", "#D3C3AE"),        # Cotton Tee / Sand
    "demo-4": ("tops", "#EAE2D3"),        # Chunky Knit / Cream
    "demo-5": ("bottoms", "#41506B"),     # Straight Jeans / Indigo
    "demo-6": ("bottoms", "#4A6079"),     # Washed Denim / Blue
    "demo-7": ("outerwear", "#CDB999"),   # Camel Trench / Camel
    "demo-8": ("outerwear", "#33343A"),   # Wool Overcoat / Charcoal
    "demo-9": ("footwear", "#5A4636"),    # Leather Loafers / Cognac
    "demo-10": ("footwear", "#6B4A33"),   # Derby Shoes / Brown
    "demo-11": ("accessories", "#BCC6BA"),# Cashmere Scarf / Sage
    "demo-12": ("dresses", "#EAE2D3"),    # Linen Dress / Bone
}


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    for name, (kind, color) in ITEMS.items():
        img = render(kind, color)
        path = os.path.join(OUTDIR, name + ".png")
        img.save(path)
        print("wrote", os.path.relpath(path))


if __name__ == "__main__":
    main()
