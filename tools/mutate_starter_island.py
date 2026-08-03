#!/usr/bin/env python3
"""mutate_starter_island.py — Surgical patches to 5 starter-island biomes.

Biomes patched:
  StarterForest  — ☀ gets a real void-pump source + 🌿 outgoing channel
  Woodlot        — 🌲 gets a void-pump so the already-wired cycle actually runs
  Village        — 🍞/🧺 pumps boosted; 🔥/❄ kickstart pumps added → genuine bistability
  PastoralCommons — 🐑 gets wolf-predation drain; 🥣 gets meadow-gated harvest
  WeaversLoft    — 🧶/🪡 get void-pump sources; 👘 fray cycle; 🧵 needle-gated tailoring
"""

from __future__ import annotations
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import biome_io  # noqa: E402
from biome_io import BIOMES_PATH  # noqa: E402


def load() -> list[dict]:
    return biome_io.load_biomes()  # raw read — mutate scripts never normalize


def save(data: list[dict]) -> None:
    biome_io.save_biomes(data)
    print(f"Saved → {BIOMES_PATH}")


def find(data: list[dict], name: str) -> dict:
    for b in data:
        if b.get("name") == name:
            return b
    raise KeyError(f"Biome not found: {name}")


def ac(biome: dict, emoji: str) -> dict:
    """Return (creating if needed) the atom_components entry for emoji."""
    comps = biome.setdefault("atom_components", {})
    return comps.setdefault(emoji, {})


# ── patch functions ──────────────────────────────────────────────────────────

def patch_starter_forest(biome: dict) -> None:
    sun = ac(biome, "☀")
    # Add incoming pump from void
    sun.setdefault("lindblad_incoming", {})["🗑"] = 0.20
    # Add 🌿 to existing outgoing (keep 🌙: 0.05)
    sun.setdefault("lindblad_outgoing", {})["🌿"] = 0.05
    print("  StarterForest ☀: lindblad_incoming 🗑→0.20, lindblad_outgoing 🌿→0.05  ✓")


def patch_woodlot(biome: dict) -> None:
    tree = ac(biome, "🌲")
    tree.setdefault("lindblad_incoming", {})["🗑"] = 0.20
    print("  Woodlot 🌲: lindblad_incoming 🗑→0.20  ✓")


def patch_village(biome: dict) -> None:
    # 🔥 — add void kickstart pump
    fire = ac(biome, "🔥")
    fire.setdefault("lindblad_incoming", {})["🗑"] = 0.05

    # ❄ — add void kickstart pump
    ice = ac(biome, "❄")
    ice.setdefault("lindblad_incoming", {})["🗑"] = 0.05

    # 🍞 — boost incoming pump rate + fix gated_lindblad_source rate
    bread = ac(biome, "🍞")
    bread.setdefault("lindblad_incoming", {})["🗑"] = 0.3
    for entry in bread.get("gated_lindblad_source", []):
        if entry.get("target") == "🔥" and entry.get("gate") == "🔥":
            entry["rate"] = 25.0
            break

    # 🧺 — boost incoming pump rate + fix gated_lindblad_source rate
    basket = ac(biome, "🧺")
    basket.setdefault("lindblad_incoming", {})["🗑"] = 0.3
    for entry in basket.get("gated_lindblad_source", []):
        if entry.get("target") == "❄" and entry.get("gate") == "❄":
            entry["rate"] = 25.0
            break

    print("  Village 🔥/❄: lindblad_incoming 🗑→0.05 each  ✓")
    print("  Village 🍞: lindblad_incoming 🗑→0.3; gated rate→25.0  ✓")
    print("  Village 🧺: lindblad_incoming 🗑→0.3; gated rate→25.0  ✓")


def patch_pastoral_commons(biome: dict) -> None:
    # 🐑 — add wolf-predation drain
    sheep = ac(biome, "🐑")
    sheep.setdefault("gated_lindblad_source", []).append({
        "target": "🗑",
        "gate": "🐺",
        "rate": 1.5,
        "power": 1,
    })

    # 🥣 — add meadow-gated harvest
    bowl = ac(biome, "🥣")
    bowl.setdefault("gated_lindblad_source", []).append({
        "target": "🌿",
        "gate": "🌿",
        "rate": 0.8,
        "power": 1,
    })

    print("  PastoralCommons 🐑: gated_lindblad_source drain via 🐺→🗑 rate=1.5  ✓")
    print("  PastoralCommons 🥣: gated_lindblad_source harvest gate=🌿 rate=0.8  ✓")


def patch_weavers_loft(biome: dict) -> None:
    # 🧶 — add void pump (yarn spun from raw fiber)
    yarn = ac(biome, "🧶")
    yarn.setdefault("lindblad_incoming", {})["🗑"] = 0.12

    # 🪡 — add void pump (bobbins wound from stock)
    bobbin = ac(biome, "🪡")
    bobbin.setdefault("lindblad_incoming", {})["🗑"] = 0.10

    # 👘 — add fray-back cycle outgoing to 🧵
    garment = ac(biome, "👘")
    garment.setdefault("lindblad_outgoing", {})["🧵"] = 0.008

    # 🧵 — add needle-gated tailoring (thread→garment when needle present)
    thread = ac(biome, "🧵")
    thread.setdefault("gated_lindblad_source", []).append({
        "target": "👘",
        "gate": "🧷",
        "rate": 3.0,
        "power": 1,
    })

    print("  WeaversLoft 🧶: lindblad_incoming 🗑→0.12  ✓")
    print("  WeaversLoft 🪡: lindblad_incoming 🗑→0.10  ✓")
    print("  WeaversLoft 👘: lindblad_outgoing 🧵→0.008 (fray cycle)  ✓")
    print("  WeaversLoft 🧵: gated_lindblad_source 👘 gate=🧷 rate=3.0  ✓")


# ── main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    data = load()
    print("Patching biomes…")

    patch_starter_forest(find(data, "StarterForest"))
    patch_woodlot(find(data, "Woodlot"))
    patch_village(find(data, "Village"))
    patch_pastoral_commons(find(data, "PastoralCommons"))
    patch_weavers_loft(find(data, "WeaversLoft"))

    save(data)
    print("\nAll patches applied.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
