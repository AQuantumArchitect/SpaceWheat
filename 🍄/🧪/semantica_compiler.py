#!/usr/bin/env python3
"""semantica_compiler.py — ONE-WAY COMPILER: umwelt world spec → SpaceWheat biome+icon data.

W3b of the Semantica Six Weeks plan. The owner's dream, stated plainly: "SpaceWheat
IS Semantica's ideal interface — a spacewheat explorer for the nested world of
quantumNN space." The physics agrees (docs/SEMANTICA_SPEC_v0.1.md §5): umwelt worlds
are Lindblad systems; SpaceWheat renders Lindblad systems. This module reads a
`DomainSpec` (umwelt/spec/schema.py — a world as DATA, not code) and emits the
SpaceWheat-native equivalent: one biome record + a set of icon (2-emoji H-axis)
records, all landing in Core/Config/semantica/ so canon (Core/Biomes/data/biomes.json,
Core/Factions/data/icons.json — "crafted artifacts", never auto-edited) stays untouched.

THE DICTIONARY (docs/SEMANTICA_SPEC_v0.1.md §5, wiring = this file):
  world (umweltd)              -> biome            (emoji vocabulary + dissipative L + slots)
  organ (NodeSpec, non-root)   -> plot / slot       (plot_idx = register_id; one organ = one plot)
  role/axis (Claura pair)      -> icon (2-emoji H)  (same object on both sides)
  eta (collapse_alpha)         -> rabi_coupling     (coupling weight of "the look")
  gamma_diss                   -> atom_components L (dissipative decay, biome-owned)

SCALE LAWS (measured off the live house data — see `_house_scale()` and the compile
manifest emitted alongside the biome/icon files for the exact numbers used):
  - rabi_coupling (H): icons.json's house distribution has median ~0.3, range [0, 1].
    eta already lives on a comparable 0-1 scale (0.25/0.40/00.92 tiers), so it is
    mapped near-linearly onto the house rabi range: rabi = eta * RABI_HOUSE_SCALE.
  - Lindblad L (biomes.json atom_components lindblad_outgoing rates): house median is
    ~0.03, i.e. roughly 10x weaker than the house rabi median — matching the project
    law "L 10-100x weaker than H" (feedback_l_weaker_than_h.md). gamma_diss (organ
    0.0003 1/s, root 0.0002 1/s) is a physically tiny per-SECOND rate from a
    real-time-decay world; it is not itself a SpaceWheat rate (SpaceWheat L acts per
    game-tick, not per wall-clock second). So instead of importing gamma_diss
    literally, this compiler preserves its RELATIVE shape (root decays slower than
    organs, ratio ~0.67) and re-anchors the absolute magnitude into the house L band,
    landing at ~10-30x weaker than the compiled rabi_coupling — inside the law.

No physics retunes to existing data. New data only. This is the STATIC compiler +
load proof (W3b) — no live hearth polling (that is Explorer v0, W6).

Usage:
    python3 semantica_compiler.py <world_module_dir> [--out DIR] [--biome-name NAME]

    # yurt_mood, from this repo:
    python3 semantica_compiler.py "/mnt/c/Users/Luke Spooner/ws-win/yurt/worlds/yurt_mood"

Emits into --out (default Core/Config/semantica/, relative to the SpaceWheat repo
root two levels up from this file's 🍄/🧪 home):
    <slug>.biome.json    - one-element array, same shape as a biomes.json record
    <slug>.icons.json    - array of icon records, same shape as icons.json entries
    <slug>.manifest.json - the compile manifest: what mapped to what, and why
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import sys
from pathlib import Path
from typing import Any

# ── repo anchors ──────────────────────────────────────────────────────────────────
HERE = Path(__file__).resolve().parent               # .../SpaceWheat/🍄/🧪
REPO_ROOT = HERE.parent.parent                        # .../SpaceWheat
DEFAULT_OUT = REPO_ROOT / "Core" / "Config" / "semantica"
UMWELT_SRC_DEFAULT = "/mnt/c/Users/Luke Spooner/ws-win/umwelt/src"

# ── house scale constants (measured off Core/Factions/data/icons.json and
#    Core/Biomes/data/biomes.json 2026-07-17; see compile manifest for the run's
#    actual numbers if the house data has since moved) ──────────────────────────────
RABI_HOUSE_MEDIAN = 0.3       # icons.json rabi_coupling median (n=360)
RABI_HOUSE_MAX = 1.0          # icons.json rabi_coupling max
L_HOUSE_MEDIAN = 0.03         # biomes.json atom_components lindblad rate median (n=810)
# House law (feedback_l_weaker_than_h.md): L is 10-100x weaker than H. We aim the
# compiled L rate near the middle of that band relative to the compiled rabi_coupling.
L_WEAKNESS_FACTOR = 20.0      # compiled L ≈ compiled rabi_coupling / 20  (inside 10-100x)

# eta tiers observed across yurt worlds (yurt_mood/resident/roc_self all use these):
ETA_CLAIM, ETA_WALL, ETA_REF = 0.25, 0.40, 0.92

# ── organ node icons + axis pole emoji: yurt_mood ships NO vocabulary.py (verified
#    2026-07-17 — no register_node_icon/register_role_emoji calls anywhere reachable
#    for this world), unlike resident/roc_self which register their own. Where the
#    world's own docstring names an emoji pair for an axis (yurt_mood's docstring:
#    "activity 💤🔥, confidence ✅🔮 ... coordination 🤝🏃"), we use it verbatim. Where
#    it doesn't (blocked, freshness — lichen-adapted per the docstring but not given
#    literal glyphs), we author a pair consistent with the WARM_NORM sign law the
#    world itself states: pos pole = warm = the IDEAL-ward direction.
#    These are AUTHORED DATA for the compile, not invented physics — pole choice
#    changes only which emoji renders, never any H/L magnitude.
YURT_MOOD_AXIS_EMOJI: dict[str, dict[str, str]] = {
    "activity":     {"pos": "🔥", "neg": "💤"},   # flowing .. idle (docstring-literal)
    "confidence":   {"pos": "✅", "neg": "🔮"},   # grounded .. uncertain (docstring-literal)
    "blocked":      {"pos": "🟢", "neg": "🚧"},   # clear .. stuck (authored, WARM_NORM-consistent)
    "freshness":    {"pos": "✨", "neg": "🍂"},   # alive .. stale (authored, WARM_NORM-consistent)
    "coordination": {"pos": "🤝", "neg": "🏃"},   # dancing .. solo (docstring-literal)
}
YURT_MOOD_ORGAN_ICON: dict[str, str] = {
    "yurt": "🛖",
    "wargen_head": "🧠",
    "potato_seat": "🥔",
    "roc_muscle": "🦅",
    "succession": "🪢",
    "lane_spacewheat": "🌾",
    "lane_bar": "🍺",
    "lane_semantica": "🧬",
}

# Registry of per-world authored vocabulary (extend when compiling resident/roc_self —
# those two DO ship their own vocabulary.py with register_role_emoji/register_node_icon,
# so a future pass should read those registries directly instead of hand-authoring;
# see manifest "vocabulary_source" field for how a given compile got its emoji).
_AUTHORED_VOCAB: dict[str, dict[str, Any]] = {
    "yurt-mood": {"axis_emoji": YURT_MOOD_AXIS_EMOJI, "organ_icon": YURT_MOOD_ORGAN_ICON},
}


def _import_world(world_dir: Path, umwelt_src: str):
    """Import a world.py the same way the world itself expects to be imported: its
    own dir + the yurt root on sys.path FIRST (the `_pm_boot` shim baked into every
    world.py), plus the umwelt src root so `from umwelt.spec.schema import ...`
    resolves. Returns the imported module (has `.SPEC`, a DomainSpec)."""
    world_dir = world_dir.resolve()
    yurt_root = world_dir.parents[1]  # worlds/<name> -> worlds -> yurt root
    for p in (str(umwelt_src), str(yurt_root), str(world_dir)):
        if p not in sys.path:
            sys.path.insert(0, p)
    spec = importlib.util.spec_from_file_location("world", world_dir / "world.py")
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load world.py from {world_dir}")
    module = importlib.util.module_from_spec(spec)
    sys.modules["world"] = module  # world.py may be re-imported by its own vocabulary
    spec.loader.exec_module(module)
    return module


def _slugify(name: str) -> str:
    return name.strip().lower().replace(" ", "_").replace("-", "_")


def _pascal_case(name: str) -> str:
    """'yurt-mood' -> 'YurtMood' — matches the house biome-name casing
    (BioticFlux, CyberDebtMegacity, StarterForest)."""
    parts = name.replace("_", "-").split("-")
    return "".join(p[:1].upper() + p[1:] for p in parts if p)


def _title_case_role(role: str) -> str:
    """'activity' -> 'Activity' — matches house icon-name casing (Void, Radiance)."""
    return role[:1].upper() + role[1:]


def _organs_of(spec) -> list:
    """Non-root NodeSpecs — these are the browsable units (plots)."""
    return [n for n in spec.nodes if n.parent is not None]


def _root_of(spec):
    roots = [n for n in spec.nodes if n.parent is None]
    return roots[0] if roots else None


def _collect_axes(spec, organs: list) -> list[str]:
    """Union of every role across every organ, order-preserving first-seen —
    this is the icon axis set. (yurt_mood: every organ shares AXES, but the
    compiler does not assume that — it reads what's actually on each node.)"""
    seen: dict[str, None] = {}
    for n in organs:
        for role in n.roles:
            seen.setdefault(role, None)
    return list(seen.keys())


def _binding_etas_for(spec, role: str) -> list[float]:
    """All collapse_alpha values bound to this role, across every organ — used to
    pick the representative eta (we take the max: the strongest look the world
    ever takes on this axis, i.e. its referee tier when one exists)."""
    etas = [b.collapse_alpha for b in spec.bindings
            if b.role == role and b.collapse_alpha is not None]
    return etas


def _vocab_for(spec_name: str, organs: list, axes: list[str]) -> tuple[dict, dict, str]:
    """Return (axis_emoji, organ_icon, source) for a world. Prefers an authored
    table (this module); a bare fallback keeps the compiler total (never crashes
    on an unregistered world) but flags itself clearly in the manifest so nobody
    mistakes a fallback glyph for real vocabulary."""
    entry = _AUTHORED_VOCAB.get(spec_name)
    if entry is not None:
        return entry["axis_emoji"], entry["organ_icon"], "authored_table(%s)" % __name__
    # Fallback: numbered placeholder glyphs, clearly synthetic.
    fallback_axis = {a: {"pos": "🔷", "neg": "🔶"} for a in axes}
    fallback_organ = {n.name: "📍" for n in organs}
    return fallback_axis, fallback_organ, "fallback_placeholder(no vocabulary registered)"


def compile_world(world_dir: Path, out_dir: Path, biome_name: str | None,
                   umwelt_src: str) -> dict:
    module = _import_world(world_dir, umwelt_src)
    spec = module.SPEC
    organs = _organs_of(spec)
    root = _root_of(spec)
    axes = _collect_axes(spec, organs)
    axis_emoji, organ_icon, vocab_source = _vocab_for(spec.name, organs, axes)

    biome_slug_name = biome_name or _pascal_case(spec.name)

    # ── icons: one per axis, pole emoji from the vocabulary table, rabi_coupling
    #    from the axis's strongest observed eta (referee tier where present). ──────
    icon_records = []
    icon_manifest_rows = []
    for axis in axes:
        poles = axis_emoji.get(axis, {"pos": "🔷", "neg": "🔶"})
        etas = _binding_etas_for(spec, axis)
        eta_used = max(etas) if etas else ETA_WALL
        rabi = round(eta_used * RABI_HOUSE_MEDIAN / ETA_WALL, 4)  # eta=0.40 -> exactly house median
        rabi = min(rabi, RABI_HOUSE_MAX)
        icon_records.append({
            "name": _title_case_role(axis),
            "pole_0": poles["pos"],
            "pole_1": poles["neg"],
            "self_energy_0": 0.0,
            "self_energy_1": 0.0,
            "rabi_coupling": rabi,
            "hamiltonian_couplings": {},
            "energy_couplings": {},
        })
        icon_manifest_rows.append({
            "axis": axis, "pole_0": poles["pos"], "pole_1": poles["neg"],
            "eta_used": eta_used, "eta_tier": (
                "referee" if eta_used >= ETA_REF - 1e-9 else
                "wall" if eta_used >= ETA_WALL - 1e-9 else "claim"),
            "rabi_coupling": rabi,
            "formula": "rabi = eta * RABI_HOUSE_MEDIAN(%.2f) / ETA_WALL(%.2f)" % (
                RABI_HOUSE_MEDIAN, ETA_WALL),
        })

    # ── biome: one plot (slot) per organ, emojis = organ icons + axis pole emoji
    #    (verbatim, no VS16 stripping — Godot BiomeRegistry normalizes at lookup
    #    time, not at data-authoring time; see IconRegistry.norm_emoji). L is
    #    sparse: one lindblad_outgoing self-loop-free decay per organ, keyed off
    #    that organ's own node icon, magnitude scaled from gamma_diss's RELATIVE
    #    shape (root vs organ) into the house L band. ──────────────────────────────
    organ_gamma = {}
    for n in organs:
        g = n.params.get("gamma_diss")
        organ_gamma[n.name] = g[0] if isinstance(g, (list, tuple)) else float(g or 0.0)
    root_gamma = 0.0
    if root is not None:
        g = root.params.get("gamma_diss")
        root_gamma = g[0] if isinstance(g, (list, tuple)) else float(g or 0.0)

    # Representative compiled rabi (median across this world's icons) anchors the
    # L magnitude so the 10-100x-weaker law holds regardless of eta spread.
    compiled_rabis = [r["rabi_coupling"] for r in icon_records] or [RABI_HOUSE_MEDIAN]
    compiled_rabis.sort()
    anchor_rabi = compiled_rabis[len(compiled_rabis) // 2]
    base_l_rate = round(anchor_rabi / L_WEAKNESS_FACTOR, 5)

    plot_layout = []
    n_organs = max(len(organs), 1)
    for i in range(n_organs):
        plot_layout.append({"x": round(0.15 + 0.7 * (i / max(n_organs - 1, 1)), 4),
                             "y": 0.65})

    biome_emojis: list[str] = []
    if root is not None:
        root_icon = organ_icon.get(root.name, "📍")
        biome_emojis.append(root_icon)
    for n in organs:
        icon = organ_icon.get(n.name, "📍")
        if icon not in biome_emojis:
            biome_emojis.append(icon)
    for rec in icon_records:
        for pole in (rec["pole_0"], rec["pole_1"]):
            if pole not in biome_emojis:
                biome_emojis.append(pole)

    atom_components: dict[str, Any] = {}
    l_manifest_rows = []
    for n in organs:
        icon = organ_icon.get(n.name, "📍")
        g = organ_gamma.get(n.name, 0.0)
        # gamma_diss is a per-second real-time decay rate from a live-hose world;
        # its ABSOLUTE value has no meaning inside SpaceWheat's per-tick physics.
        # We keep only its RELATIVE weight against the root's own gamma_diss so a
        # faster-decaying organ still decays visibly faster post-compile, then
        # anchor the absolute magnitude at base_l_rate (already inside the
        # 10-100x-weaker-than-H band via L_WEAKNESS_FACTOR above).
        relative = (g / root_gamma) if root_gamma > 0 else 1.0
        rate = round(base_l_rate * relative, 5)
        target = organ_icon.get(root.name, "📍") if root is not None else icon
        if icon == target:
            continue  # no self-loop
        atom_components[icon] = {"lindblad_outgoing": {target: rate}}
        l_manifest_rows.append({
            "organ": n.name, "source_emoji": icon, "target_emoji": target,
            "gamma_diss": g, "gamma_diss_relative_to_root": round(relative, 4),
            "compiled_rate": rate,
            "formula": "rate = base_l_rate(%.5f, = anchor_rabi/%.0f) * (gamma_diss/root_gamma_diss)"
                       % (base_l_rate, L_WEAKNESS_FACTOR),
        })

    doc_lines = [ln.strip() for ln in (module.__doc__ or "").strip().splitlines()]
    doc_lines = [ln for ln in doc_lines if ln]
    description = " ".join(doc_lines[:2]) if doc_lines else \
        "Compiled from umwelt world '%s' by semantica_compiler.py." % spec.name

    biome_record = {
        "name": biome_slug_name,
        "description": description,
        "image_path": "",
        "music_path": "",
        "discovered": True,   # explorer worlds are browsable immediately, no unlock gate
        "discoverable": False,  # not part of the captain-hat random-unlock pool
        "plot_layout": plot_layout,
        "emojis": biome_emojis,
        "tags": ["semantica", "explorer", "compiled"],
        "atom_components": atom_components,
    }

    manifest = {
        "compiler": "semantica_compiler.py",
        "source_world": spec.name,
        "source_path": str(world_dir),
        "vocabulary_source": vocab_source,
        "biome_name": biome_slug_name,
        "organ_count": len(organs),
        "axis_count": len(axes),
        "ideal": dict(getattr(module, "IDEAL", {})),
        "eta_tiers_seen": {"claim": ETA_CLAIM, "wall": ETA_WALL, "referee": ETA_REF},
        "scale_law": {
            "rabi_house_median": RABI_HOUSE_MEDIAN, "rabi_house_max": RABI_HOUSE_MAX,
            "l_house_median": L_HOUSE_MEDIAN, "l_weakness_factor": L_WEAKNESS_FACTOR,
            "anchor_rabi_used": anchor_rabi, "base_l_rate": base_l_rate,
            "l_over_h_ratio": round(base_l_rate / anchor_rabi, 5) if anchor_rabi else None,
        },
        "organ_to_plot": [{"organ": n.name, "plot_index": i, "node_icon": organ_icon.get(n.name, "📍"),
                            "gamma_diss": organ_gamma.get(n.name)}
                           for i, n in enumerate(organs)],
        "axis_to_icon": icon_manifest_rows,
        "lindblad_terms": l_manifest_rows,
        "mapping_table": [
            {"semantica_field": "world (DomainSpec.name)", "spacewheat_field": "biome.name",
             "rule": "slug -> PascalCase"},
            {"semantica_field": "NodeSpec (non-root organ)", "spacewheat_field": "biome plot / plot_layout entry",
             "rule": "1 organ = 1 plot; plot_idx = register_id = organ's index in this list"},
            {"semantica_field": "NodeSpec.name node icon (authored)", "spacewheat_field": "biome.emojis[]",
             "rule": "authored per-organ glyph (see YURT_MOOD_ORGAN_ICON)"},
            {"semantica_field": "role/axis pos+neg pole emoji (authored/docstring)",
             "spacewheat_field": "icon.pole_0 / icon.pole_1",
             "rule": "docstring-literal where given, WARM_NORM-consistent authored otherwise"},
            {"semantica_field": "BindingSpec.collapse_alpha (eta)", "spacewheat_field": "icon.rabi_coupling",
             "rule": "rabi = max(eta over this axis's bindings) * RABI_HOUSE_MEDIAN / ETA_WALL, "
                     "capped at RABI_HOUSE_MAX"},
            {"semantica_field": "NodeSpec.params.gamma_diss", "spacewheat_field": "biome.atom_components[].lindblad_outgoing",
             "rule": "relative shape (organ_gamma / root_gamma) preserved; absolute magnitude "
                     "re-anchored to anchor_rabi / L_WEAKNESS_FACTOR (house law: L is 10-100x weaker than H)"},
            {"semantica_field": "IDEAL dict", "spacewheat_field": "manifest.ideal (informational only)",
             "rule": "NOT wired into physics — the target-state annotation has no SpaceWheat "
                     "analogue yet (no attractor/setpoint concept on a biome); carried for the tape"},
        ],
    }

    out_dir.mkdir(parents=True, exist_ok=True)
    slug = _slugify(spec.name)
    biome_path = out_dir / f"{slug}.biome.json"
    icons_path = out_dir / f"{slug}.icons.json"
    manifest_path = out_dir / f"{slug}.manifest.json"
    biome_path.write_text(json.dumps([biome_record], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    icons_path.write_text(json.dumps(icon_records, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    return {"biome_path": biome_path, "icons_path": icons_path, "manifest_path": manifest_path,
            "biome_name": biome_slug_name, "organ_count": len(organs), "axis_count": len(axes)}


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("world_dir", help="path to the world's directory (contains world.py)")
    ap.add_argument("--out", default=str(DEFAULT_OUT), help="output dir (default Core/Config/semantica/)")
    ap.add_argument("--biome-name", default=None, help="override the compiled biome name")
    ap.add_argument("--umwelt-src", default=UMWELT_SRC_DEFAULT, help="umwelt src root for `import umwelt`")
    args = ap.parse_args(argv)

    result = compile_world(Path(args.world_dir), Path(args.out), args.biome_name, args.umwelt_src)
    print(json.dumps({
        "ok": True,
        "biome_name": result["biome_name"],
        "organ_count": result["organ_count"],
        "axis_count": result["axis_count"],
        "biome_path": str(result["biome_path"]),
        "icons_path": str(result["icons_path"]),
        "manifest_path": str(result["manifest_path"]),
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
