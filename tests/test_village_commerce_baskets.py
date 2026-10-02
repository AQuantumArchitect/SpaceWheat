"""Village must grow 🧺 on a live plot. Gather costs a basket.

Capital 💰|⚙ (orphaned) used to steal coin+gear, so Commerce never seated
and WindMill ⚙|💨 filled by accident. Granary now owns Commerce 🧺|💰.
WindMill stays off the boot loadout — mill is a quest plant (🪵).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _norm(s: str) -> str:
    return str(s).replace("\ufe0f", "").replace("\ufe0e", "")


def _neighborhood_icons(biome: dict, factions: list) -> list:
    basis = {_norm(e) for e in biome.get("emojis", [])}
    by_name = {f["name"]: f for f in factions}
    claimed = set()
    seen = set()
    out = []
    for fname in biome.get("native_factions", []):
        fac = by_name.get(fname, {})
        for icon in fac.get("icons", []):
            p0, p1 = _norm(icon.get("pole_0", "")), _norm(icon.get("pole_1", ""))
            if p0 not in basis or p1 not in basis:
                continue
            if p0 in claimed or p1 in claimed:
                continue
            key = tuple(sorted([p0, p1]))
            if key in seen:
                continue
            seen.add(key)
            claimed.add(p0)
            claimed.add(p1)
            out.append((str(icon.get("name", "")), p0, p1, fname))
    return out


def test_village_commerce_heals_on_load() -> None:
    farm = (ROOT / "Core/Farm.gd").read_text(encoding="utf-8")
    assert "func ensure_village_commerce(" in farm
    prog = (ROOT / "UI/Core/UIProgression.gd").read_text(encoding="utf-8")
    walk = prog.split("func _basket_walk_line")[1].split("\nstatic func ")[0]
    assert "ensure_village_commerce" in walk
    assert walk.find("ensure_village_commerce") < walk.find("_glyph_plot_key")
    assert "_focused_is_glyph" in walk
    assert "func basket_well_grid_pos" in prog
    qii = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
    ex = qii.split("func _execute_action(")[1].split("\nfunc ")[0]
    assert "_basket_well_pos" in ex
    qii = (ROOT / "UI/Core/QuantumInstrumentInput.gd").read_text(encoding="utf-8")
    gp = qii.split("func _get_grid_position(")[1].split("\nfunc ")[0]
    assert "get_active_biome" in gp
    assert "last_selected_position" in gp
    gpf = qii.split("func _get_grid_position_for(")[1].split("\nfunc ")[0]
    assert "get_plot_biome_assignments" in gpf
    ace = (ROOT / "Core/UI/AceChipResolvers.gd").read_text(encoding="utf-8")
    assert "func resolve_r" in ace
    assert "_basket_walk_line" in ace
    cfg = (ROOT / "Core/GameState/ToolConfig.gd").read_text(encoding="utf-8")
    assert "ace.r_well" in cfg
    rm = (ROOT / "Core/QuantumSubstrate/RegisterMap.gd").read_text(encoding="utf-8")
    axis = rm.split("func axis(")[1].split("\nfunc ")[0]
    assert "as_str" in axis or "str(qubit_index)" in axis
    gsm = (ROOT / "Core/GameState/GameStateManager.gd").read_text(encoding="utf-8")
    assert "ensure_village_commerce" in gsm
    assert 'allocate_axis(idx, "🧺", "💰")' in farm
    heal = farm.split("func ensure_village_commerce(")[1].split("\nfunc ")[0]
    assert "seated_at" in heal
    assert "_assigned_cols_for_biome" in heal
    assert "Village" in heal
    abm = (ROOT / "Core/GameState/ActiveBiomeManager.gd").read_text(encoding="utf-8")
    assert "func ensure_slotted(" in abm
    prog = (ROOT / "UI/Core/UIProgression.gd").read_text(encoding="utf-8")
    assert "ensure_slotted" in prog.split("func _cross_to")[1].split("\nstatic func ")[0]
    glyph = prog.split("func _glyph_plot_key")[1].split("\nstatic func ")[0]
    assert "assigned.has" in glyph
    assert "_pole_has_glyph" in glyph
    assert "int(q) < nq" in glyph
    assert "found.sort" in glyph
    assert "rm_pair" in glyph
    assert "live" in heal
    assert "plot_layout" in heal
    assert "cap" in heal
    probe = (ROOT / "Core/Actions/ProbeActions.gd").read_text(encoding="utf-8")
    explore = probe.split("static func action_explore")[1].split("\nstatic func ")[0]
    assert "register_map.axis" in explore
    assert "eagle_well" in explore
    assert 'norm.contains("🦅")' in explore
    assert "bread_well" in explore
    assert 'norm.contains("🍞")' in explore
    pop = probe.split("static func action_pop")[1]
    well_yield = pop.split("if well:")[-1][:400]
    assert 'resource = "🧺"' in well_yield
    prog = (ROOT / "UI/Core/UIProgression.gd").read_text(encoding="utf-8")
    assert "func lantern_well_live" in prog
    obj = prog.split("static func objective_text")[1].split("\nstatic func ")[0]
    assert "lantern_well_live" in obj
    assert obj.find("lantern_well_live") < obj.find("_basket_walk_line")
    ace = (ROOT / "Core/UI/AceChipResolvers.gd").read_text(encoding="utf-8")
    assert "lantern_well_live" in ace.split("func resolve_r")[1].split("\nstatic func ")[0]
    base = (ROOT / "Core/Environment/BiomeBase.gd").read_text(encoding="utf-8")
    pair = base.split("func get_register_emoji_pair")[1].split("\nfunc ")[0]
    assert "register_map.axis" in pair
    qi = (ROOT / "Core/Instrumentation/QuantumInstrument.gd").read_text(encoding="utf-8")
    strike = qi.split("func action_measure(")[1].split("\nfunc ")[0]
    assert "🧺 well" in strike
    chips = (ROOT / "Core/UI/ChipResolverRegistry.gd").read_text(encoding="utf-8")
    assert 'action_name == "explore"' in chips
    assert 'north_e.contains("🍞")' in chips
    assert 'north_e.contains("🦅")' in chips
    ace = (ROOT / "Core/UI/AceChipResolvers.gd").read_text(encoding="utf-8")
    assert "no 🍞" in ace


def test_village_seats_commerce_not_windmill():
    biomes = json.loads((ROOT / "Core/Biomes/data/biomes.json").read_text(encoding="utf-8"))
    factions = json.loads((ROOT / "Core/Factions/data/factions.json").read_text(encoding="utf-8"))
    village = next(b for b in biomes if b.get("name") == "Village")
    assert "orphaned_icons" not in village.get("native_factions", [])
    granary = next(f for f in factions if f.get("name") == "Granary Guilds")
    commerce = [i for i in granary.get("icons", []) if i.get("name") == "Commerce"]
    assert commerce, "Granary Guilds must own Commerce"
    assert commerce[0]["pole_0"] == "🧺" and commerce[0]["pole_1"] == "💰"
    placed = _neighborhood_icons(village, factions)
    names = [p[0] for p in placed]
    poles = {(p[1], p[2]) for p in placed}
    assert "Commerce" in names
    assert ("🧺", "💰") in poles
    assert "WindMill" not in names
    assert ("⚙", "💨") not in poles
    assert "🧺" in {a for a, _b in poles} | {b for _a, b in poles}


def test_basket_walk_is_derived_not_gifted():
    prog = (ROOT / "UI/Core/UIProgression.gd").read_text(encoding="utf-8")
    assert "func _basket_walk_line" in prog
    assert "func _basket_short" in prog
    walk = prog.split("func _basket_walk_line")[1].split("\nstatic func ")[0]
    assert "Village" in walk
    assert "🧺" in walk
    assert "add_resource" not in walk
    assert "_glyph_plot_key" in walk
    assert '_glyph_plot_key("🧺", "Village")' in walk or "_glyph_plot_key(\"🧺\", \"Village\")" in walk
    glyph = prog.split("func _glyph_plot_key")[1].split("\nstatic func ")[0]
    assert "register_map" in glyph
    assert "rm.axis" in glyph
    eagle = prog.split("func _eagle_gather_line")[1].split("\nstatic func ")[0]
    assert eagle.find("lantern_well_live") < eagle.find("StarterForest")
    assert "pick a 🧺 plot" not in walk
    assert "no 🧺 plot seated" in walk
    assert 'want = "G"' not in walk
    decorate = prog.split("static func _decorate_objective")[1].split("static func _travel_line")[0]
    assert "lantern_well_live" in decorate
    assert "_basket_walk_line" in decorate
    obj = prog.split("static func objective_text(")[1].split("return _decorate_objective")[0]
    assert "lantern_well_live" in obj
    assert "_basket_walk_line" in obj
