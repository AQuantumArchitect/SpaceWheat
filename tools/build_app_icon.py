#!/usr/bin/env python3
"""Build SpaceWheat's application icon from the game's own visual language.

The icon is one STATION — the unit the player actually stares at all game:
a Bloch ball tinted the player-faction hue, its teal equator (the x-y phase
plane), the honest white state dot sitting off-centre inside (superposition,
not collapse), and the gold ripeness ring around its waist. The wheat glyph
rides the north pole exactly the way QuantumField3D billboards a |0> basis
emoji above the ball.

The renderer also draws a faint pole-to-pole measurement axis inside its
translucent ball. That is deliberately NOT reproduced here: the icon's ball
is opaque, so an interior line reads as a crack in the sphere rather than an
axis. The equator plus the off-centre dot carry the same "this is a state,
not a planet" reading without the artifact.

Nothing here is invented colour. Every value is lifted from the running game:

  ground   Core/Visualization/QuantumField3D.gd:154  env.background_color
  ball hue Core/Biomes/data/visual_themes.json       rules[player_faction].hue
  ring     Core/Biomes/data/visual_themes.json       defaults.accent
  equator  Core/Biomes/data/visual_themes.json       defaults.line_palette[3]
  wheat    Assets/emoji_svg/1f33e.svg                the shipping glyph, verbatim

Flat colour throughout, no gradients or glow — QuantumField3D.gd's own note
is "Mini-Metro clarity: flat vibrant colour, no bloom/glow", and flat also
survives being resampled down to a 16px favicon.

Two variants come out of this:
  icon.svg        full detail — editor, runtime window, PWA, anything >= 64px
  icon_small.svg  ball + ring + dot only — the glyph, equator and axis are
                  noise below ~48px, so the .ico's small frames use this

Two steps, in order — see scripts/build-app-icon.sh, which runs all of them:

  python3 tools/build_app_icon.py            author Assets/icon{,_small}.svg
  godot --headless -s tools/rasterize_app_icon.gd   -> Assets/icon_raster/*.png
  python3 tools/build_app_icon.py --pack-ico  pack those PNGs into Assets/icon.ico

Rasterisation lives in Godot on purpose: using the engine's own ThorVG means
the shipped .ico frames and the window icon can't disagree with each other.
"""

from __future__ import annotations

import colorsys
import json
import re
import struct
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
THEMES = REPO / "Core/Biomes/data/visual_themes.json"
FIELD3D = REPO / "Core/Visualization/QuantumField3D.gd"
WHEAT_SVG = REPO / "Assets/emoji_svg/1f33e.svg"
OUT_FULL = REPO / "Assets/icon.svg"
OUT_SMALL = REPO / "Assets/icon_small.svg"

CANVAS = 512


def _hex(rgb: tuple[float, float, float]) -> str:
    return "#" + "".join(f"{max(0, min(255, round(c * 255))):02X}" for c in rgb)


def read_ground() -> str:
    """env.background_color from the live 3D field renderer."""
    src = FIELD3D.read_text(encoding="utf-8")
    m = re.search(r"env\.background_color\s*=\s*Color\(([^)]+)\)", src)
    if not m:
        raise SystemExit(f"no env.background_color in {FIELD3D} — renderer changed, fix this script")
    parts = [float(x.strip()) for x in m.group(1).split(",")]
    return _hex(tuple(parts[:3]))


def read_theme() -> tuple[str, str, str]:
    """Accent gold, player-faction ball hue, and the teal metro line."""
    data = json.loads(THEMES.read_text(encoding="utf-8"))
    accent = _hex(tuple(data["defaults"]["accent"][:3]))

    hue = None
    for rule in data["rules"]:
        if "player_faction" in rule.get("match_tags", []):
            hue = rule["hue"]
            break
    if hue is None:
        raise SystemExit("no player_faction rule in visual_themes.json — the player lost their hue")
    # The renderer tints the ball at partial saturation/value against a dark
    # ground; these are the flat-icon equivalents of that tint.
    ball = _hex(colorsys.hsv_to_rgb(hue, 0.80, 0.78))

    teal = _hex(tuple(data["defaults"]["line_palette"][3][:3]))
    return accent, ball, teal


# Ink bounds of Assets/emoji_svg/1f33e.svg inside its own 36x36 tile, measured
# by rasterising the glyph alone at 1024px and taking the alpha bbox. Twemoji
# does not centre its art in the tile — the wheat sits 2.0 units left — so
# centring on the tile instead of on the ink visibly cants the crown.
WHEAT_INK_CX = 15.996  # vs a tile centre of 18.0
WHEAT_INK_TOP = 0.598
WHEAT_INK_BOTTOM = 35.016


def read_wheat() -> list[tuple[str, str]]:
    """The shipping wheat glyph's paths, verbatim: [(fill, d), ...]."""
    src = WHEAT_SVG.read_text(encoding="utf-8")
    box = re.search(r'viewBox="([^"]+)"', src)
    if not box or box.group(1).split() != ["0", "0", "36", "36"]:
        raise SystemExit(f"{WHEAT_SVG} is not a 36x36 twemoji tile — retune the transform")
    paths = []
    for tag in re.findall(r"<path\b[^>]*/>", src):
        fill = re.search(r'fill="([^"]+)"', tag)
        d = re.search(r'\bd="([^"]+)"', tag)
        if fill and d:
            paths.append((fill.group(1), d.group(1)))
    if not paths:
        raise SystemExit(f"no paths in {WHEAT_SVG}")
    return paths


def front_arc(cx: float, cy: float, rx: float, ry: float) -> str:
    """The near half of a horizontal ellipse — the part that passes in FRONT
    of the ball. sweep=0 runs 180deg -> 90deg -> 0deg, and in SVG's y-down
    space 90deg is (cx, cy+ry): below centre, i.e. toward the viewer."""
    return f"M {cx - rx:g},{cy:g} A {rx:g},{ry:g} 0 0 0 {cx + rx:g},{cy:g}"


def build(full: bool) -> str:
    ground = read_ground()
    accent, ball_col, teal = read_theme()

    cx = CANVAS / 2

    if full:
        ball_r, ball_cy = 112.0, 296.0
        ring_rx, ring_ry, ring_w = 166.0, 55.0, 14.0
        dot_r = 16.0
    else:
        # Small frames lose the glyph, so the ball and ring carry the whole
        # identity alone — give them more of the tile and centre them in it.
        ball_r, ball_cy = 132.0, 256.0
        ring_rx, ring_ry, ring_w = 178.0, 58.0, 21.0
        dot_r = 21.0

    o: list[str] = []
    o.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {CANVAS} {CANVAS}" width="{CANVAS}" height="{CANVAS}">')
    o.append("  <title>SpaceWheat</title>")

    # Ground: the field's own background, rounded so it reads as an app tile.
    o.append(f'  <rect x="0" y="0" width="{CANVAS}" height="{CANVAS}" rx="96" ry="96" fill="{ground}"/>')

    # Ripeness ring. Drawn whole at full strength — the ball then covers the far
    # arc, which is the only occlusion there should be. (Dimming the whole
    # ellipse to fake depth also dims the side lobes, the one part of the ring
    # that is genuinely beside the ball and should be at full gold.)
    o.append(
        f'  <ellipse cx="{cx:g}" cy="{ball_cy:g}" rx="{ring_rx:g}" ry="{ring_ry:g}" '
        f'fill="none" stroke="{accent}" stroke-width="{ring_w:g}"/>'
    )

    # The ball.
    o.append(f'  <circle cx="{cx:g}" cy="{ball_cy:g}" r="{ball_r:g}" fill="{ball_col}"/>')

    if full:
        # Equator = the x-y phase plane. Far half dim, near half bright.
        eq_rx, eq_ry = ball_r, ball_r * 0.30
        o.append(
            f'  <ellipse cx="{cx:g}" cy="{ball_cy:g}" rx="{eq_rx:g}" ry="{eq_ry:g}" '
            f'fill="none" stroke="{teal}" stroke-width="5" opacity="0.32"/>'
        )
        o.append(
            f'  <path d="{front_arc(cx, ball_cy, eq_rx, eq_ry)}" fill="none" '
            f'stroke="{teal}" stroke-width="6.5" stroke-linecap="round" opacity="0.95"/>'
        )

    # Ripeness ring, near half — over the ball, so the ring reads as a ring.
    o.append(
        f'  <path d="{front_arc(cx, ball_cy, ring_rx, ring_ry)}" fill="none" '
        f'stroke="{accent}" stroke-width="{ring_w:g}" stroke-linecap="round"/>'
    )

    # The honest state dot: off-centre, i.e. in superposition rather than collapsed.
    o.append(
        f'  <circle cx="{cx + ball_r * 0.42:g}" cy="{ball_cy - ball_r * 0.36:g}" r="{dot_r:g}" fill="#FFFFFF"/>'
    )

    if full:
        # Wheat rides the north pole the way a |0> basis emoji billboards above
        # the ball, its stalk running down behind the sphere.
        ink_h = 118.0
        scale = ink_h / (WHEAT_INK_BOTTOM - WHEAT_INK_TOP)
        # Centre on the ink, not the tile; sit the stalk's base inside the ball.
        tx = cx - WHEAT_INK_CX * scale
        ty = (ball_cy - ball_r + 38.0) - WHEAT_INK_BOTTOM * scale
        o.append(f'  <g transform="translate({tx:g},{ty:g}) scale({scale:g})">')
        for fill, d in read_wheat():
            o.append(f'    <path fill="{fill}" d="{d}"/>')
        o.append("  </g>")

    o.append("</svg>")
    return "\n".join(o) + "\n"


## ---------------------------------------------------------------------------
## Windows .ico packing
## ---------------------------------------------------------------------------
## Hand-rolled rather than Pillow's ICO writer for one reason: Pillow resamples
## every frame from a single source image, and our small frames come from a
## DIFFERENT source (icon_small.svg). Packing the already-rasterised per-size
## PNGs is the only way each frame keeps the art that was drawn for it.
##
## Frames <= 48px are written as 32-bit BMP (BITMAPINFOHEADER + BGRA + AND
## mask). PNG-in-ICO is legal on Vista and later and everything modern reads
## it, but a handful of installer/packaging tools still choke on small PNG
## frames, and BMP costs a few KB to be safe. 64px and up go out as PNG.

RASTER_DIR = REPO / "Assets/icon_raster"
OUT_ICO = REPO / "Assets/icon.ico"
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
BMP_AT_OR_BELOW = 48


def _bmp_frame(img) -> bytes:
    """32-bit BGRA DIB with the legacy AND mask, bottom-up, as ICO wants."""
    w, h = img.size
    px = img.load()

    xor = bytearray()
    for y in range(h - 1, -1, -1):
        for x in range(w):
            r, g, b, a = px[x, y]
            xor += bytes((b, g, r, a))

    # AND mask: 1bpp, rows padded to a 4-byte boundary. Fully redundant beside
    # a real alpha channel, but the format requires it to be present.
    row_bytes = ((w + 31) // 32) * 4
    mask = bytearray()
    for y in range(h - 1, -1, -1):
        row = bytearray(row_bytes)
        for x in range(w):
            if px[x, y][3] == 0:
                row[x // 8] |= 0x80 >> (x % 8)
        mask += row

    header = struct.pack(
        "<IiiHHIIiiII",
        40,        # biSize
        w,         # biWidth
        h * 2,     # biHeight — XOR and AND stacked
        1,         # biPlanes
        32,        # biBitCount
        0,         # biCompression = BI_RGB
        len(xor) + len(mask),
        0, 0, 0, 0,
    )
    return header + bytes(xor) + bytes(mask)


def pack_ico() -> None:
    try:
        from PIL import Image
    except ImportError:
        raise SystemExit("--pack-ico needs Pillow (python3 -m pip install --user Pillow)")

    frames: list[tuple[int, bytes]] = []
    for size in ICO_SIZES:
        src = RASTER_DIR / f"icon_{size}.png"
        if not src.exists():
            raise SystemExit(f"missing {src} — run tools/rasterize_app_icon.gd first")
        img = Image.open(src).convert("RGBA")
        if img.size != (size, size):
            raise SystemExit(f"{src} is {img.size}, expected {size}x{size}")
        if size <= BMP_AT_OR_BELOW:
            frames.append((size, _bmp_frame(img)))
        else:
            frames.append((size, src.read_bytes()))

    out = bytearray(struct.pack("<HHH", 0, 1, len(frames)))
    offset = 6 + 16 * len(frames)
    entries = bytearray()
    blob = bytearray()
    for size, data in frames:
        entries += struct.pack(
            "<BBBBHHII",
            size if size < 256 else 0,   # 0 encodes 256
            size if size < 256 else 0,
            0,   # colour count (0 = truecolour)
            0,   # reserved
            1,   # planes
            32,  # bit depth
            len(data),
            offset,
        )
        blob += data
        offset += len(data)

    OUT_ICO.write_bytes(bytes(out + entries + blob))
    kinds = ", ".join(f"{s}{'bmp' if s <= BMP_AT_OR_BELOW else 'png'}" for s in ICO_SIZES)
    print(f"wrote {OUT_ICO.relative_to(REPO)} ({OUT_ICO.stat().st_size} B) — {kinds}")


def main() -> None:
    if "--pack-ico" in sys.argv[1:]:
        pack_ico()
        return
    OUT_FULL.write_text(build(full=True), encoding="utf-8")
    OUT_SMALL.write_text(build(full=False), encoding="utf-8")
    ground = read_ground()
    accent, ball_col, teal = read_theme()
    print(f"ground {ground}  ball {ball_col}  ring {accent}  equator {teal}")
    print(f"wrote {OUT_FULL.relative_to(REPO)}  ({OUT_FULL.stat().st_size} B)")
    print(f"wrote {OUT_SMALL.relative_to(REPO)} ({OUT_SMALL.stat().st_size} B)")


if __name__ == "__main__":
    main()
