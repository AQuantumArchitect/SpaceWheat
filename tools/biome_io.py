#!/usr/bin/env python3
"""biome_io.py — the ONE shared biome/faction data-IO module.

Every tools/ and scripts/ consumer of Core/Factions/data/factions.json,
Core/Biomes/data/biomes.json, and Core/Factions/data/axes.json routes its
JSON reads (and mutate-script writes) through here, instead of carrying its
own path constants and read-mutate-write boilerplate.

FE0F normalization is an EXPLICIT opt-in (`normalize=True`), never a default:
the analysis stack (biome_audit + the *_assay tools) strips U+FE0F variation
selectors to match EmojiUtil.normalize in GDScript, but the mutate scripts
must see and write the raw canonical bytes. A shared helper must not silently
import FE0F-normalization behavior into scripts that never opted into it.

Writes always use ensure_ascii=False (biomes.json MUST stay ensure_ascii=False)
with indent=2, matching the pre-existing per-script write idioms.
"""

from __future__ import annotations

import json
from pathlib import Path

# ── Canonical paths (relative to repo root) ──────────────────────────────────

ROOT = Path(__file__).resolve().parent.parent
FACTIONS_PATH = ROOT / "Core" / "Factions" / "data" / "factions.json"
BIOMES_PATH = ROOT / "Core" / "Biomes" / "data" / "biomes.json"
AXES_PATH = ROOT / "Core" / "Factions" / "data" / "axes.json"


# ── Emoji normalization ──────────────────────────────────────────────────────

def strip_fe0f(s: str) -> str:
    """Strip U+FE0F variation selectors (matches EmojiUtil.normalize in GDScript)."""
    return s.replace("\ufe0f", "")


# ── Reads ────────────────────────────────────────────────────────────────────

def load_json(path: Path):
    """The single JSON-read implementation. Raw parse, no normalization."""
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def load_factions(*, normalize: bool = False) -> list[dict]:
    """Load factions.json.

    normalize=True strips FE0F from every emoji key surface the analysis
    stack touches: sig, self_energies keys, hamiltonian src/tgt keys, and
    drivers keys. Default is the RAW read.
    """
    factions = load_json(FACTIONS_PATH)
    if normalize:
        for fac in factions:
            fac["sig"] = [strip_fe0f(e) for e in fac.get("sig", [])]
            fac["self_energies"] = {strip_fe0f(k): v for k, v in fac.get("self_energies", {}).items()}
            fac["hamiltonian"] = {
                strip_fe0f(src): {strip_fe0f(tgt): v for tgt, v in targets.items()}
                for src, targets in fac.get("hamiltonian", {}).items()
            }
            fac["drivers"] = {
                strip_fe0f(k): v for k, v in fac.get("drivers", {}).items()
            }
    return factions


def load_biomes(*, normalize: bool = False) -> list[dict]:
    """Load biomes.json. normalize=True strips FE0F from each biome's emojis."""
    biomes = load_json(BIOMES_PATH)
    if normalize:
        for b in biomes:
            b["emojis"] = [strip_fe0f(e) for e in b.get("emojis", [])]
    return biomes


def load_axes() -> list[dict]:
    """Load axes.json (12-axis encoding). Always raw."""
    return load_json(AXES_PATH)


# ── Writes (mutate scripts only) ─────────────────────────────────────────────

def save_json(path: Path, data, *, trailing_newline: bool = False) -> None:
    """The single JSON-write implementation: indent=2, ensure_ascii=False.

    trailing_newline=True appends "\\n" (the scripts/mutate_factions_biomes.py
    idiom); the default matches the bare json.dump idiom of the tools/ mutate
    scripts, which emit no trailing newline.
    """
    text = json.dumps(data, indent=2, ensure_ascii=False)
    if trailing_newline:
        text += "\n"
    path.write_text(text, encoding="utf-8")


def save_biomes(biomes: list[dict], *, trailing_newline: bool = False) -> None:
    save_json(BIOMES_PATH, biomes, trailing_newline=trailing_newline)


def save_factions(factions: list[dict], *, trailing_newline: bool = False) -> None:
    save_json(FACTIONS_PATH, factions, trailing_newline=trailing_newline)
