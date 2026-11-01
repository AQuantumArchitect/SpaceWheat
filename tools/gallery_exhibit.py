#!/usr/bin/env python3
"""gallery_exhibit.py — build the curated atlas exhibition page.

The Gallery, shop-window lane (docs/ENGINE_FRONTIER.md Part II). Takes the
plates rendered by tools/atlas_plates.py and binds sixteen of them — the ones
that carry the campaigns' physics — into a single self-contained HTML page:
every plate embedded as a data: URI, no external requests, hostable anywhere
(GitHub Pages, itch.io HTML upload, a USB stick, an email attachment).

Usage:
    python3 tools/atlas_plates.py                 # render plates first
    python3 tools/gallery_exhibit.py              # -> docs/gallery/index.html
    python3 tools/gallery_exhibit.py --plates DIR --out FILE
"""

import argparse
import base64
import sys
from pathlib import Path

PROJECT = Path(__file__).resolve().parent.parent

# The curation: (biome, caption). Captions are the physics, one breath each.
SECTIONS = [
    ("Home", "The island the player grows up on stays closed forever — pure unitary evolution, nothing decays, and measurement is the only irreversible act. The open world is built to teach you to miss it.", [
        ("StarterForest", "Home. A day/night Hamiltonian swings ☀/🌙 forever; the first Berry loop is walked here. Sealed shore — the Bath never enters."),
    ]),
    ("The Wound", "The first wet landmark the player crosses into. Dephasing is taught by loss: populations intact, color draining. Nothing moved, and something is gone.", [
        ("GildedRot", "The Fallow. Its authored webway runs live (orange, solid) — the first place a qubit the player prepared goes gray. T₂ has a home address."),
    ]),
    ("The Chain", "Topological protection as authored data: alternating strong/weak couplings put the strong bonds inside, and the ends host protected modes.", [
        ("Lanternfall", "Five lanterns on the coast. The bridge lantern 🌉 cannot go dark while the pattern holds — SSH edge protection, playable. The mid-chain disperses everything it is given."),
    ]),
    ("The Basins", "Closed systems never settle — these five biomes author dissipative structure that genuinely does: steady states, bistability with hysteresis, a limit cycle, critical slowdown.", [
        ("Village", "Tristable: hot, cold, and quiet basins. The town remembers which life it fell into."),
        ("ShrineOfAshes", "A bistable latched at 0.95. Flip it, and it refuses to flip back — hysteresis is the world's own memory."),
        ("TwofacedTide", "The other bistable. Two faces, one tide, and a threshold between them."),
        ("MothGarden", "A limit cycle — the garden orbits instead of settling. Motion as the steady state."),
        ("BrittleDawn", "Critical slowdown: near the transition, everything takes forever. The dawn is brittle because the gap is closing."),
    ]),
    ("Watching Keeps", "The quantum Zeno effect as gameplay: a state dying toward the sink is pinned by measuring it, again and again. The player's oldest verb becomes the shield.", [
        ("ZenoLatch", "The latch itself — a memory that persists only while observed."),
        ("Clinic", "Zeno as care: the patient is kept alive by attention, literally."),
    ]),
    ("Hiding in the Light", "The Bath cannot eat what does not couple to it. Interference, engineered on purpose, becomes shelter — and once, the Bath feeds instead of eating.", [
        ("NullingChamber", "An EIT dark state: a superposition destructive interference hides from the drive. Shelter built out of phase itself."),
        ("WheelOfHours", "A chiral clock — persistent current keeps the time, dissipation keeps the direction."),
        ("LaserGlint", "Gain: the one place the Bath pumps a mode instead of draining it. Dissipation as cultivation."),
    ]),
    ("Curiosities", "The far shelf — authored dissipative circuits waiting in the data for the player to find them.", [
        ("FreshwaterSpring", "A vacuum attractor: everything relaxes to the still, cold ground state. The quietest place in the world."),
        ("MnemonicHive", "A two-bit dissipative memory — the hive stores what the bees agree on."),
        ("OrbitalStrike", "A self-erasing one-shot: fires once, then dissipates its own arming state. The circuit that forgets itself on purpose."),
    ]),
]

CSS = """
:root { color-scheme: dark; }
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #0a0c11; color: #d8dce4; font-family: Georgia, 'Times New Roman', serif;
       line-height: 1.55; padding: 3rem 1.25rem 4rem; }
main { max-width: 1180px; margin: 0 auto; }
h1 { font-size: 2.1rem; font-weight: normal; letter-spacing: 0.12em; text-align: center; }
.deck { text-align: center; color: #8a93a5; max-width: 46rem; margin: 0.9rem auto 0;
        font-size: 1.02rem; }
.legend { display: flex; flex-wrap: wrap; gap: 0.4rem 1.4rem; justify-content: center;
          margin: 1.6rem auto 0; font-size: 0.85rem; color: #8a93a5;
          font-family: system-ui, sans-serif; }
.legend span { white-space: nowrap; }
.swatch { display: inline-block; width: 1.6em; height: 0; border-bottom-width: 3px;
          vertical-align: middle; margin-right: 0.35em; }
h2 { font-size: 1.35rem; font-weight: normal; letter-spacing: 0.08em; color: #e0c98f;
     margin: 3.2rem 0 0.4rem; border-bottom: 1px solid #232838; padding-bottom: 0.35rem; }
.section-note { color: #8a93a5; max-width: 52rem; margin-bottom: 1.4rem; font-size: 0.95rem; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
        gap: 1.4rem; }
figure { background: #10131c; border: 1px solid #1d2230; border-radius: 10px;
         padding: 0.8rem; }
figure img { width: 100%; height: auto; display: block; border-radius: 6px; }
figcaption { padding: 0.7rem 0.3rem 0.2rem; font-size: 0.88rem; color: #a8b0c0; }
figcaption b { color: #d8dce4; font-weight: normal; letter-spacing: 0.05em; }
footer { margin-top: 3.5rem; text-align: center; color: #626b7d; font-size: 0.85rem; }
footer code { font-family: ui-monospace, monospace; color: #8a93a5;
              background: #10131c; padding: 0.1em 0.4em; border-radius: 4px; }
footer a { color: #8a93a5; }
"""

HEADER_DECK = (
    "Sixteen of 162 plates from the SpaceWheat atlas. Nothing here is a "
    "screenshot: every plate is rendered directly from the game's data truth "
    "(<code>Core/Biomes/data/biomes.json</code>) — the same file the engine "
    "boots its density matrices from. The atoms are the biome's emoji palette; "
    "the edges are its authored Lindblad flow-graph, the <i>webway</i>. "
    "64 biomes author real dissipative structure (the wet country); "
    "98 author none and stay coherent forever (natural enclaves)."
)

LEGEND = [
    ("#e08830", "solid", "webway, running open"),
    ("#7a5023", "dashed", "webway, sealed"),
    ("#a05548", "dashed", "decay to sink"),
    ("#4f9a95", "dotted", "external feed"),
    ("#8f6fd0", "solid", "gated channel"),
]


def build(plates_dir: Path, out_path: Path) -> int:
    missing = []
    parts = []
    parts.append("<meta charset='utf-8'>")
    parts.append("<meta name='viewport' content='width=device-width, initial-scale=1'>")
    parts.append("<title>SpaceWheat — The Atlas</title>")
    parts.append(f"<style>{CSS}</style>")
    parts.append("<main>")
    parts.append("<h1>SPACEWHEAT · THE ATLAS</h1>")
    parts.append(f"<p class='deck'>{HEADER_DECK}</p>")
    legend_bits = []
    for color, style, label in LEGEND:
        legend_bits.append(
            f"<span><i class='swatch' style='border-bottom-style:{style};"
            f"border-bottom-color:{color}'></i>{label}</span>")
    parts.append(f"<div class='legend'>{''.join(legend_bits)}</div>")

    total = 0
    for title, note, entries in SECTIONS:
        parts.append(f"<h2>{title}</h2>")
        parts.append(f"<p class='section-note'>{note}</p>")
        parts.append("<div class='grid'>")
        for biome, caption in entries:
            svg = plates_dir / f"{biome}.svg"
            if not svg.exists():
                missing.append(biome)
                continue
            b64 = base64.b64encode(svg.read_bytes()).decode("ascii")
            parts.append(
                "<figure>"
                f"<img alt='{biome} atlas plate' loading='lazy' "
                f"src='data:image/svg+xml;base64,{b64}'>"
                f"<figcaption><b>{biome}</b> — {caption}</figcaption>"
                "</figure>")
            total += 1
        parts.append("</div>")

    parts.append(
        "<footer><p>The full atlas — all 162 biomes plus a contact sheet — "
        "regenerates in about a second: <code>python3 tools/atlas_plates.py"
        "</code>. This page: <code>python3 tools/gallery_exhibit.py</code>.</p>"
        "<p>The physics behind every plate, with honesty grades per claim: "
        "<a href='../FOR_PHYSICISTS.md'>docs/FOR_PHYSICISTS.md</a>.</p></footer>")
    parts.append("</main>")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("<!doctype html>\n" + "\n".join(parts), encoding="utf-8")
    print(f"wrote {out_path} — {total} plates, {out_path.stat().st_size // 1024} KiB")
    if missing:
        print(f"MISSING plates (run tools/atlas_plates.py first): {missing}")
        return 1
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--plates", default=str(PROJECT / "build" / "atlas" / "plates"))
    ap.add_argument("--out", default=str(PROJECT / "docs" / "gallery" / "index.html"))
    args = ap.parse_args()
    return build(Path(args.plates), Path(args.out))


if __name__ == "__main__":
    sys.exit(main())
