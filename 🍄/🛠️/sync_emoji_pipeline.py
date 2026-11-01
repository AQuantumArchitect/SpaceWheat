#!/usr/bin/env python3
"""
sync_emoji_pipeline.py — Keep emoji SVG coverage in sync with game data.

Phases:
  1 (SCAN)  — Extract all emojis from game data files + .gd sources
  2 (FETCH) — Download any missing twemoji SVGs from CDN
  3 (BUILD) — Write Assets/emoji_registry.json: {custom: {...}, twemoji: {...}}

The registry is the single source of truth for emoji → SVG path.
EmojiRegistry.gd loads it at boot. JSON stays in the build but serves
no functional purpose at runtime.

Run from project root:
    python3 🍄/🛠️/sync_emoji_pipeline.py [--dry-run | --check]
"""

import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
ROOT = Path(__file__).resolve().parent.parent.parent
GAME_DATA = [
    ROOT / "Core/Biomes/data/biomes.json",
    ROOT / "Core/Factions/data/factions.json",
    ROOT / "Core/Factions/data/icons.json",        # canonical icon poles (H physics)
    ROOT / "Core/Factions/data/axes.json",          # axis label emojis (qubit poles)
    ROOT / "Core/Quests/data/story_flags.json",     # story flag emojis
    # semantica world configs (spec→biome compiler output) also carry pole emojis the
    # renderer must draw — 🍺/🛖 shipped glyphless because this list didn't scan them
    # (found in the 2026-08-04 broken-fractal-emoji audit).
    *sorted((ROOT / "Core/Config/semantica").glob("*.json")),
]
SVG_DIR       = ROOT / "Assets/emoji_svg"
REGISTRY_FILE = ROOT / "Assets/emoji_registry.json"
CDN           = "https://cdn.jsdelivr.net/gh/jdecked/twemoji@latest/assets/svg/{cp}.svg"

# The yurt worlds tree — same repo-crossing convention 🍄/🧪/hearth_client.py's YURT_ENV_DEFAULT
# and umwelt's tests/test_world_vocabulary_coverage.py already use to reach it from a sibling
# repo. A `register_role_emoji(...)`/`register_node_icon(...)` call anywhere under here designs a
# glyph the hive now needs an SVG for; this pipeline used to only know about SpaceWheat's own
# GAME_DATA/.gd sources, so getting a newly-registered glyph to actually render required 3 manual
# round-trips (run Godot headed, read "no SVG for X" warnings out of the log, hand-collect them,
# re-run this pipeline) — found the hard way across the hive-ops/yurt-mood/project_membrane fixes,
# 2026-08-02. Scanning it here closes that loop.
YURT_WORLDS_DIR_DEFAULT = "/mnt/c/Users/Luke Spooner/ws-win/yurt/worlds"

# ── Custom SVG entries (Tier 1) ────────────────────────────────────────────────
# Single authoritative source for hand-crafted emoji → SVG mappings.
# Keys: fe0f-normalized. Values: full Godot res:// paths.
# Edit here (and add the SVG to Assets/UI/) when adding a new custom emoji.
CUSTOM_ENTRIES: dict[str, str] = {
    "💨": "res://Assets/UI/Resources/Flour.svg",
    "🌾": "res://Assets/UI/Resources/Wheat.svg",
    "🪵": "res://Assets/UI/Resources/Lumber.svg",
    "⚡": "res://Assets/UI/Resources/Power.svg",
    "🔥": "res://Assets/UI/Elements/Fire.svg",
    "💧": "res://Assets/UI/Elements/Water.svg",
    "🌬": "res://Assets/UI/Elements/Wind.svg",
    "☀": "res://Assets/UI/Celestial/Sun.svg",
    "🌙": "res://Assets/UI/Celestial/Moon.svg",
    "🌿": "res://Assets/UI/Nature/Vegetation.svg",
    "🌱": "res://Assets/UI/Nature/Seedling.svg",
    "🍂": "res://Assets/UI/Nature/Decay.svg",
    "🌲": "res://Assets/UI/Nature/Forest.svg",
    "🔬": "res://Assets/UI/Tools/Spec.svg",
    "🔗": "res://Assets/UI/Tools/Fabric.svg",
    "⚙": "res://Assets/UI/Tools/Efficiency.svg",
    "🏭": "res://Assets/UI/Tools/Station.svg",
    "🛠": "res://Assets/UI/Tools/Tools.svg",
    "💻": "res://Assets/UI/Tools/Code.svg",
    "💰": "res://Assets/UI/Economic/Wealth.svg",
    "📡": "res://Assets/UI/Economic/Signal.svg",
    "⚖": "res://Assets/UI/Economic/Justice.svg",
    "🗝": "res://Assets/UI/Economic/Lock.svg",
    "🔒": "res://Assets/UI/Economic/Lock.svg",
    # 👥 had no matching Assets/UI/Economic/Collective.svg (art never actually made) — every
    # get_texture() call logged a Godot resource-load ERROR and silently fell to the twemoji
    # tier anyway. Found via P4's cognifold node-badge verification, 2026-08-02. Dropped rather
    # than pointed at art that doesn't exist; twemoji already covers 👥 honestly.
    "≈": "res://Assets/UI/Math/AlmostEqual.svg",
    "≠": "res://Assets/UI/Math/NotEqual.svg",
}

# ── Renderable-emoji filter for GDScript scans ────────────────────────────────
# .gd files contain box-drawing (U+2500-25FF), geometric shapes, and math/tech
# symbols in log strings that are never passed to EmojiRegistry for rendering.
_GD_RENDERABLE_RANGES = [(0x1F000, 0x1FAFF), (0x2600, 0x27BF), (0x2B00, 0x2BFF)]
_GD_RENDERABLE_SPECIFIC = frozenset([
    0x231A, 0x231B,
    0x23E9, 0x23EA, 0x23EB, 0x23EC, 0x23ED, 0x23EE, 0x23EF,
    0x23F0, 0x23F1, 0x23F2, 0x23F3, 0x23F8, 0x23F9, 0x23FA,
    0x25AA, 0x25AB, 0x25B6, 0x25C0, 0x25FB, 0x25FC, 0x25FD, 0x25FE,
])
_GD_SCAN_EXCLUSIONS: frozenset[str] = frozenset([
    "★", "☐", "✓", "✕", "✗",  # log/UI strings, never rendered via EmojiRegistry
])


def _gd_emoji_filter(s: str) -> bool:
    if not s or s in _GD_SCAN_EXCLUSIONS:
        return False
    cp = ord(s[0])
    for lo, hi in _GD_RENDERABLE_RANGES:
        if lo <= cp <= hi:
            return True
    return cp in _GD_RENDERABLE_SPECIFIC


# ── Emoji regex + helpers ──────────────────────────────────────────────────────
_EMOJI_RE = re.compile(
    r"(?:"
    r"[\U0001F1E0-\U0001F1FF]{2}"
    r"|[0-9#*]️?⃣"
    r"|[\U0001F000-\U0001FAFF](?:️|‍[\U0001F000-\U0001FAFF]️?)*"
    r"|[⌀-➿]️?"
    r"|[⬀-⯿]️?"
    r"|[©®]️?"
    r")",
    re.UNICODE,
)


def normalize(emoji: str) -> str:
    return emoji.replace("️", "").replace("︎", "")


def to_codepoint(emoji: str) -> str:
    return "-".join(f"{ord(c):04x}" for c in emoji)


def from_codepoint(cp_str: str) -> str:
    try:
        return "".join(chr(int(p, 16)) for p in cp_str.split("-"))
    except ValueError:
        return ""


def emojis_on_disk() -> set[str]:
    return {normalize(from_codepoint(svg.stem)) for svg in SVG_DIR.glob("*.svg")
            if from_codepoint(svg.stem)}


# ── yurt worlds vocabulary scan (register_role_emoji / register_node_icon glyphs) ─────────────

def _yurt_worlds_dir() -> Path | None:
    raw = os.environ.get("YURT_WORLDS_DIR", YURT_WORLDS_DIR_DEFAULT)
    p = Path(raw)
    return p if p.is_dir() else None


def _scan_yurt_vocab() -> set[str]:
    """Every emoji literal in any worlds/*/vocabulary.py — register_role_emoji's {pos,zero,neg,
    coherent} dict values and register_node_icon's icon args, whatever their exact call shape.
    A plain emoji-glyph regex scan over the file text (same _EMOJI_RE the GAME_DATA/.gd scans use)
    rather than parsing the calls — a `vocabulary.py` has no other reason to carry these glyphs."""
    worlds_dir = _yurt_worlds_dir()
    if worlds_dir is None:
        return set()
    found: set[str] = set()
    for vocab_file in worlds_dir.glob("*/vocabulary.py"):
        text = vocab_file.read_text(encoding="utf-8", errors="replace")
        for m in _EMOJI_RE.finditer(text):
            n = normalize(m.group())
            if n:
                found.add(n)
    return found


# ── Phase 1: SCAN ──────────────────────────────────────────────────────────────

def phase1_scan() -> tuple[set[str], set[str]]:
    """Returns (all_emojis, needing_twemoji_svgs)."""
    print("\n── Phase 1: SCAN ──────────────────────────────────────────────────")
    all_emojis: set[str] = set()

    for src in GAME_DATA:
        if not src.exists():
            print(f"  ⚠️  {src.relative_to(ROOT)} not found — skipping")
            continue
        raw = src.read_text(encoding="utf-8")
        # JSON may use \uXXXX escapes; decode first so regex finds literal chars.
        if src.suffix == ".json":
            try:
                text = json.dumps(json.loads(raw), ensure_ascii=False)
            except json.JSONDecodeError:
                text = raw
        else:
            text = raw
        found = {normalize(m.group()) for m in _EMOJI_RE.finditer(text)}
        found.discard("")
        print(f"  {src.name}: {len(found)} emojis")
        all_emojis |= found

    gd_emojis: set[str] = set()
    for gd_dir in [ROOT / "Core", ROOT / "UI"]:
        if gd_dir.exists():
            for gd_file in gd_dir.rglob("*.gd"):
                text = gd_file.read_text(encoding="utf-8", errors="replace")
                for m in _EMOJI_RE.finditer(text):
                    n = normalize(m.group())
                    if n and _gd_emoji_filter(n):
                        gd_emojis.add(n)
    new_from_gd = gd_emojis - all_emojis
    print(f"  .gd files: {'+' + str(len(new_from_gd)) + ' additional' if new_from_gd else 'no new'} emojis")
    all_emojis |= gd_emojis

    yurt_emojis = _scan_yurt_vocab()
    if _yurt_worlds_dir() is None:
        print(f"  yurt worlds/*/vocabulary.py: not mounted here — skipping")
    else:
        new_from_yurt = yurt_emojis - all_emojis
        print(f"  yurt worlds/*/vocabulary.py: "
              f"{'+' + str(len(new_from_yurt)) + ' additional' if new_from_yurt else 'no new'} emojis")
        all_emojis |= yurt_emojis

    custom_hit   = all_emojis & set(CUSTOM_ENTRIES)
    needing_svgs = all_emojis - set(CUSTOM_ENTRIES)

    print(f"  ──")
    print(f"  Total unique (normalized): {len(all_emojis)}")
    print(f"  Covered by custom SVGs: {len(custom_hit)}")
    print(f"  Need twemoji SVG: {len(needing_svgs)}")
    return all_emojis, needing_svgs


# ── Phase 2: FETCH ─────────────────────────────────────────────────────────────

def _try_download(url: str, out_file: Path) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=10) as r:
            out_file.write_bytes(r.read())
        return True
    except urllib.error.HTTPError as e:
        if e.code != 404:
            print(f"    HTTP {e.code}: {url}")
        return False
    except Exception as e:
        print(f"    Error: {e}")
        return False


def phase2_fetch(needing_svgs: set[str], dry_run: bool) -> set[str]:
    """Download any missing SVGs. Returns emojis that couldn't be fetched."""
    print("\n── Phase 2: FETCH ─────────────────────────────────────────────────")

    on_disk = emojis_on_disk()
    missing = sorted(needing_svgs - on_disk)

    if not missing:
        print(f"  All {len(needing_svgs)} SVGs already on disk. Nothing to download.")
        return set()

    print(f"  {len(needing_svgs) - len(missing)} already on disk, {len(missing)} to fetch...")
    failed: set[str] = set()

    for emoji in missing:
        cp_base = to_codepoint(emoji)
        cp_vs16 = cp_base + "-fe0f"

        if dry_run:
            print(f"  [DRY] {emoji}  →  {cp_base}.svg")
            continue

        out_base = SVG_DIR / f"{cp_base}.svg"
        out_vs16 = SVG_DIR / f"{cp_vs16}.svg"

        if _try_download(CDN.format(cp=cp_base), out_base):
            print(f"  ✓ {emoji}  ({cp_base}.svg)")
        elif _try_download(CDN.format(cp=cp_vs16), out_vs16):
            print(f"  ✓ {emoji}  ({cp_vs16}.svg)")
        else:
            print(f"  ✗ {emoji}  (U+{cp_base.upper()}) — not in twemoji, needs custom SVG")
            failed.add(emoji)

    return failed


# ── Phase 3: BUILD REGISTRY ────────────────────────────────────────────────────

def phase3_build_registry(dry_run: bool) -> dict:
    """Write Assets/emoji_registry.json — unified {custom, twemoji} registry."""
    print("\n── Phase 3: BUILD REGISTRY ────────────────────────────────────────")

    twemoji: dict[str, str] = {}
    skipped = 0
    for svg in sorted(SVG_DIR.glob("*.svg")):
        emoji = from_codepoint(svg.stem)
        if not emoji:
            skipped += 1
            continue
        norm = normalize(emoji)
        if norm and norm not in CUSTOM_ENTRIES:
            twemoji[norm] = f"res://Assets/emoji_svg/{svg.name}"

    registry = {
        "custom": CUSTOM_ENTRIES,
        "twemoji": dict(sorted(twemoji.items())),
    }

    print(f"  Custom entries: {len(CUSTOM_ENTRIES)}")
    print(f"  Twemoji entries: {len(twemoji)} (skipped {skipped} undecodable)")

    if not dry_run:
        REGISTRY_FILE.write_text(
            json.dumps(registry, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"  Wrote {REGISTRY_FILE.relative_to(ROOT)}")
    else:
        print(f"  [DRY] would write {REGISTRY_FILE.relative_to(ROOT)}")

    return registry


# ── Main ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Sync emoji SVG coverage with SpaceWheat game data.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--dry-run", action="store_true",
                        help="Report gaps without downloading or writing any files")
    parser.add_argument("--check", action="store_true",
                        help="Verify coverage; exit 1 if any emoji is missing. No downloads, no writes.")
    args = parser.parse_args()

    if args.check:
        all_emojis, _ = phase1_scan()
        registry: dict = {}
        if REGISTRY_FILE.exists():
            r = json.loads(REGISTRY_FILE.read_text(encoding="utf-8"))
            registry = {**r.get("custom", {}), **r.get("twemoji", {})}
        uncovered = all_emojis - set(registry)
        print("\n── Coverage Check ─────────────────────────────────────────────────")
        if uncovered:
            print(f"  FAIL — {len(uncovered)} emoji(s) not covered:")
            for e in sorted(uncovered, key=to_codepoint):
                print(f"    {e}  (U+{to_codepoint(e).upper()})")
            sys.exit(1)
        else:
            print(f"  PASS — all {len(all_emojis)} emojis covered ✓")
        return

    if args.dry_run:
        print("DRY RUN — no files will be modified")

    all_emojis, needing_svgs = phase1_scan()
    failed = phase2_fetch(needing_svgs, args.dry_run)
    registry = phase3_build_registry(args.dry_run)

    all_keys = set(registry.get("custom", {})) | set(registry.get("twemoji", {}))
    covered  = all_emojis & (set(CUSTOM_ENTRIES) | all_keys)
    uncovered = all_emojis - covered

    print("\n── Summary ────────────────────────────────────────────────────────")
    print(f"  Game emojis: {len(all_emojis)}")
    print(f"  Custom SVGs: {len(all_emojis & set(CUSTOM_ENTRIES))}")
    print(f"  Twemoji SVGs: {len(registry.get('twemoji', {}))}")
    if uncovered:
        print(f"  ⚠️  Still uncovered ({len(uncovered)}) — need custom SVGs:")
        for e in sorted(uncovered):
            print(f"     {e}  (U+{to_codepoint(e).upper()})")
    else:
        print(f"  Coverage: 100% ✓")


if __name__ == "__main__":
    main()
