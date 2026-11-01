#!/usr/bin/env python3
"""The Gallery, G3 (docs/ENGINE_FRONTIER.md, Part II): atlas plates.

Renders every biome in Core/Biomes/data/biomes.json as an SVG *plate* — the
atom cloud on a ring, the authored webway drawn from data truth — plus an
index.html contact sheet. Pure data, no engine, no GPU: the assay pattern
(tools/ssh_assay.py). The output is simultaneously the exhibition catalog,
itch page art, and a data-QA sweep — a malformed biome is visible as a
malformed plate.

Edge language (matches the in-game graph views):
  orange solid arrow   lindblad_outgoing  (wet where regime=open, else the
                       sealed webway — drawn dark and dashed)
  red-brown dashed     decay (atom -> its decay target)
  teal dotted          lindblad_incoming (source -> atom)
  violet arrow + gate  gated_lindblad_source (gate emoji labels the edge)

Usage:
  python3 tools/atlas_plates.py                # all plates -> build/atlas/
  python3 tools/atlas_plates.py --only StarterForest GildedRot
  python3 tools/atlas_plates.py --out docs/atlas/samples --only StarterForest GildedRot
"""

import argparse
import html
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIOMES_JSON = os.path.join(ROOT, "Core", "Biomes", "data", "biomes.json")

W, H = 760, 820
CX, CY, R = W / 2, 420, 270

# Palette shared with the in-game grammar: purple H (unused here — H is a
# neighborhood product, not biome data), orange webway, gray-blue chrome.
C_BG = "#0d0f14"
C_CARD = "#151823"
C_TEXT = "#d8dce4"
C_MUTED = "#8a93a5"
C_WET = "#e08830"
C_SEALED = "#7a5023"
C_DECAY = "#a05548"
C_IN = "#4f9a95"
C_GATE = "#8f6fd0"
C_NODE = "#232838"
C_RING = "#2c3244"


def esc(s):
    return html.escape(str(s), quote=True)


def polar(i, n, radius=R, cx=CX, cy=CY):
    ang = -math.pi / 2 + (2 * math.pi * i) / max(1, n)
    return cx + radius * math.cos(ang), cy + radius * math.sin(ang)


def shrink(x1, y1, x2, y2, margin):
    """Pull both endpoints toward each other so arrows stop at node rims."""
    dx, dy = x2 - x1, y2 - y1
    d = math.hypot(dx, dy)
    if d < 1e-6:
        return x1, y1, x2, y2
    ux, uy = dx / d, dy / d
    m = min(margin, d * 0.45)
    return x1 + ux * m, y1 + uy * m, x2 - ux * m, y2 - uy * m


def edge(x1, y1, x2, y2, color, width, dash=None, marker="arrow"):
    x1, y1, x2, y2 = shrink(x1, y1, x2, y2, 26)
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{color}" stroke-width="{width}"{dash_attr} '
            f'marker-end="url(#{marker})" opacity="0.85"/>')


def self_loop(x, y, color, dash=None):
    dash_attr = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<circle cx="{x:.1f}" cy="{y - 30:.1f}" r="12" fill="none" '
            f'stroke="{color}" stroke-width="1.5"{dash_attr} opacity="0.7"/>')


def render_plate(biome):
    name = biome.get("name", "?")
    regime = biome.get("regime", "")
    ac = biome.get("atom_components", {}) or {}
    emojis = list(biome.get("emojis", []) or [])
    # The plate shows every atom that either lives in the palette or appears
    # anywhere in the webway (sources/targets outside the palette included —
    # data QA depends on seeing them).
    atoms = list(dict.fromkeys(emojis))
    for atom, spec in ac.items():
        if atom not in atoms:
            atoms.append(atom)
        if not isinstance(spec, dict):
            continue
        for t in (spec.get("lindblad_outgoing") or {}):
            if t not in atoms:
                atoms.append(t)
        for s in (spec.get("lindblad_incoming") or {}):
            if s not in atoms:
                atoms.append(s)
        decay = spec.get("decay") or {}
        t = decay.get("target")
        if t and t not in atoms:
            atoms.append(t)
        for row in (spec.get("gated_lindblad_source") or []):
            for k in ("target", "gate"):
                v = row.get(k)
                if v and v not in atoms:
                    atoms.append(v)

    n = len(atoms)
    pos = {a: polar(i, n) for i, a in enumerate(atoms)}
    node_r = 22 if n <= 14 else (16 if n <= 30 else 11)
    fs = 20 if n <= 14 else (15 if n <= 30 else 10)

    wet = (regime == "open")
    web_color = C_WET if wet else C_SEALED
    web_dash = None if wet else "6,5"

    lines = []
    counts = {"webway": 0, "decay": 0, "incoming": 0, "gated": 0}
    for atom, spec in ac.items():
        if not isinstance(spec, dict):
            continue
        ax, ay = pos[atom]
        for target, rate in (spec.get("lindblad_outgoing") or {}).items():
            counts["webway"] += 1
            tx, ty = pos[target]
            wdt = 1.2 + min(3.0, abs(float(rate)) * 40)
            if target == atom:
                lines.append(self_loop(ax, ay, web_color, web_dash))
            else:
                lines.append(edge(ax, ay, tx, ty, web_color, wdt, web_dash))
        decay = spec.get("decay") or {}
        if decay.get("target"):
            counts["decay"] += 1
            tx, ty = pos[decay["target"]]
            lines.append(edge(ax, ay, tx, ty, C_DECAY, 1.2, "3,4", "arrow_decay"))
        for source, rate in (spec.get("lindblad_incoming") or {}).items():
            counts["incoming"] += 1
            sx, sy = pos[source]
            if source != atom:
                lines.append(edge(sx, sy, ax, ay, C_IN, 1.0, "1,4", "arrow_in"))
        for row in (spec.get("gated_lindblad_source") or []):
            target = row.get("target")
            if not target:
                continue
            counts["gated"] += 1
            tx, ty = pos[target]
            lines.append(edge(ax, ay, tx, ty, C_GATE, 1.4, None, "arrow_gate"))
            mx, my = (ax + tx) / 2, (ay + ty) / 2
            lines.append(f'<text x="{mx:.1f}" y="{my:.1f}" font-size="12" '
                         f'text-anchor="middle" fill="{C_GATE}">{esc(row.get("gate", ""))}</text>')

    nodes = []
    for atom in atoms:
        x, y = pos[atom]
        in_palette = atom in emojis
        ring = C_RING if in_palette else C_DECAY
        nodes.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{node_r}" '
                     f'fill="{C_NODE}" stroke="{ring}" stroke-width="1.5"/>')
        nodes.append(f'<text x="{x:.1f}" y="{y + fs * 0.35:.1f}" font-size="{fs}" '
                     f'text-anchor="middle">{esc(atom)}</text>')

    stamp = ("🌊 wet — runs open" if regime == "open"
             else ("🔒 sealed shore — closed forever" if regime == "closed"
                   else "— inherits the world"))
    factions = ", ".join(biome.get("native_factions", []) or []) or "no native faction"
    tags = " · ".join(biome.get("tags", []) or [])
    palette_row = " ".join(emojis[:24]) + (" …" if len(emojis) > 24 else "")
    legend_y = H - 46
    counts_row = (f'webway {counts["webway"]} · decay {counts["decay"]} · '
                  f'feeds {counts["incoming"]} · gated {counts["gated"]} · atoms {n}')

    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
    <path d="M0,0 L8,4 L0,8 z" fill="{C_WET if wet else C_SEALED}"/></marker>
  <marker id="arrow_decay" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
    <path d="M0,0 L8,4 L0,8 z" fill="{C_DECAY}"/></marker>
  <marker id="arrow_in" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
    <path d="M0,0 L8,4 L0,8 z" fill="{C_IN}"/></marker>
  <marker id="arrow_gate" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
    <path d="M0,0 L8,4 L0,8 z" fill="{C_GATE}"/></marker>
</defs>
<rect width="{W}" height="{H}" fill="{C_BG}"/>
<rect x="14" y="14" width="{W - 28}" height="{H - 28}" rx="10" fill="{C_CARD}"/>
<text x="{CX}" y="58" font-size="26" text-anchor="middle" fill="{C_TEXT}" font-family="serif">{esc(name)}</text>
<text x="{CX}" y="84" font-size="13" text-anchor="middle" fill="{C_MUTED}">{esc(stamp)}</text>
<text x="{CX}" y="104" font-size="12" text-anchor="middle" fill="{C_MUTED}">{esc(factions)}{(" · " + esc(tags)) if tags else ""}</text>
<g>{"".join(lines)}</g>
<g>{"".join(nodes)}</g>
<text x="{CX}" y="{legend_y}" font-size="12" text-anchor="middle" fill="{C_MUTED}">{esc(counts_row)}</text>
<text x="{CX}" y="{legend_y + 22}" font-size="15" text-anchor="middle">{esc(palette_row)}</text>
</svg>
'''


def render_index(rows, out_dir):
    cells = []
    for name, fname, regime, n_edges in rows:
        badge = {"open": "🌊", "closed": "🔒"}.get(regime, "·")
        cells.append(
            f'<figure><a href="plates/{esc(fname)}"><img loading="lazy" '
            f'src="plates/{esc(fname)}" alt="{esc(name)}"/></a>'
            f'<figcaption>{esc(badge)} {esc(name)} <span>({n_edges} channels)</span></figcaption></figure>')
    n_open = sum(1 for r in rows if r[2] == "open")
    n_closed = sum(1 for r in rows if r[2] == "closed")
    return f'''<!doctype html><html><head><meta charset="utf-8">
<title>SpaceWheat — the Atlas ({len(rows)} plates)</title>
<style>
 body {{ background:{C_BG}; color:{C_TEXT}; font-family: Georgia, serif; margin: 2rem; }}
 h1 {{ font-weight: normal; }} p {{ color:{C_MUTED}; max-width: 60rem; }}
 .grid {{ display:grid; grid-template-columns:repeat(auto-fill,minmax(240px,1fr)); gap:14px; }}
 figure {{ margin:0; background:{C_CARD}; border-radius:8px; padding:8px; }}
 img {{ width:100%; height:auto; display:block; border-radius:4px; }}
 figcaption {{ font-size:13px; padding:6px 2px 2px; }} figcaption span {{ color:{C_MUTED}; }}
</style></head><body>
<h1>SpaceWheat — the Atlas</h1>
<p>{len(rows)} biomes rendered from data truth (Core/Biomes/data/biomes.json):
the atom cloud on a ring, the authored webway as it is written — orange where
the country runs wet ({n_open} biomes), dark and dashed where the shore stays
sealed ({n_closed} inviolable), inherit-the-world everywhere else. A malformed
biome is visible as a malformed plate; this page is a QA sweep that hangs on a
wall. Generated by tools/atlas_plates.py.</p>
<div class="grid">{"".join(cells)}</div>
</body></html>
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--out", default=os.path.join(ROOT, "build", "atlas"))
    ap.add_argument("--only", nargs="*", default=None,
                    help="biome names to render (default: all)")
    args = ap.parse_args()

    with open(BIOMES_JSON, encoding="utf-8") as fh:
        biomes = json.load(fh)
    if args.only:
        wanted = set(args.only)
        biomes = [b for b in biomes if b.get("name") in wanted]
        missing = wanted - {b.get("name") for b in biomes}
        if missing:
            sys.exit(f"unknown biomes: {sorted(missing)}")

    plates_dir = os.path.join(args.out, "plates")
    os.makedirs(plates_dir, exist_ok=True)
    rows = []
    for b in sorted(biomes, key=lambda x: x.get("name", "")):
        name = b.get("name", "unnamed")
        fname = "".join(c if (c.isalnum() or c in "-_") else "_" for c in name) + ".svg"
        svg = render_plate(b)
        with open(os.path.join(plates_dir, fname), "w", encoding="utf-8") as fh:
            fh.write(svg)
        n_edges = sum(
            len(spec.get("lindblad_outgoing") or {}) + len(spec.get("lindblad_incoming") or {})
            + (1 if (spec.get("decay") or {}).get("target") else 0)
            + len(spec.get("gated_lindblad_source") or [])
            for spec in (b.get("atom_components") or {}).values() if isinstance(spec, dict))
        rows.append((name, fname, b.get("regime", ""), n_edges))

    index_path = os.path.join(args.out, "index.html")
    with open(index_path, "w", encoding="utf-8") as fh:
        fh.write(render_index(rows, args.out))
    dry = sum(1 for r in rows if r[3] == 0)
    print(f"atlas: {len(rows)} plates -> {plates_dir}")
    print(f"index: {index_path}")
    print(f"regimes: open={sum(1 for r in rows if r[2] == 'open')} "
          f"closed={sum(1 for r in rows if r[2] == 'closed')} inherit={sum(1 for r in rows if r[2] == '')}")
    print(f"natural enclaves (no authored channels): {dry}")


if __name__ == "__main__":
    main()
