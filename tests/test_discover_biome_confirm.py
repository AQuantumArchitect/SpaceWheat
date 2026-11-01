"""Playtest note 8: Captain Add Biome must name the land and confirm it.

Player finished Captain "get a new biome". R fired immediately, seated a
decomposing land (FungalNetworks on the easy four-pack / GildedRot in the
demos pool when pressure missed), and exploring plots never completed
Find the Woodlot. That door completes when Woodlot's QC is live — Ace F
on the wrong land does not count. Hive bots start on demos_normal, whose
curated pool already contains Woodlot; they were not gifted a skip.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
FARM = ROOT / "Core" / "Farm.gd"
FORECAST = ROOT / "Core" / "Gameplay" / "BiomeDiscoveryForecastService.gd"
QII = ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd"
TOOLS = ROOT / "Core" / "GameState" / "ToolConfig.gd"
PROG = ROOT / "UI" / "Core" / "UIProgression.gd"
CHIPS = ROOT / "UI" / "Managers" / "UIContextController.gd"
ROW = ROOT / "UI" / "Widgets" / "ActionPreviewRow.gd"
FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"
EASY = ROOT / "Scenarios" / "new_game_easy.tres"
DEMOS = ROOT / "Scenarios" / "demos_normal.tres"
BIOMES = ROOT / "Core" / "Biomes" / "data" / "biomes.json"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def body(path: Path, name: str) -> str:
    parts = src(path).split("func %s(" % name)
    assert len(parts) > 1, "%s() is gone from %s" % (name, path.name)
    return parts[1].split("\nfunc ")[0]


def test_add_biome_opens_a_pick_submenu() -> None:
    tools = src(TOOLS)
    r_chip = tools.split('"R": {"action": "discover_biome"')[1].split("FRAME_")[0]
    assert '"submenu": "biome_discovery"' in r_chip
    assert '"confirm": true' not in r_chip.split("}")[0]
    qii = src(QII)
    assert "biome_discovery" in qii
    assert "func _execute_discover_biome_pick(" in qii
    inst = src(ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd")
    enter = body(ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd", "enter_submenu")
    assert "biome_discovery" in enter
    picker = src(ROOT / "UI" / "Core" / "Submenus" / "BiomeDiscoverySubmenu.gd")
    assert "claim_south" in picker
    assert "discover_biome" in picker
    collect = picker.split("static func _collect_options")[1].split("static func ")[0]
    assert 'get_action_cost(farm, "discover_biome")' in collect
    assert 'get_action_cost(farm, "claim_biome"' not in collect
    disc = body(FARM, "discover_biome")
    assert 'new_biome != "BloodLedger"' not in disc
    assert "claim_biome" not in disc
    prog = src(ROOT / "UI" / "Core" / "UIProgression.gd")
    pick_line = prog.split("static func _biome_picker_line(")[1].split("\nstatic func ")[0]
    assert "discover_target_name" in pick_line
    assert "[%s] %s" in pick_line
    forecast = src(FORECAST)
    assert "func claim_south(" in forecast
    disc = body(FARM, "discover_biome")
    assert "claim_biome" not in disc
    assert "commit_action" in disc


def test_peek_freezes_the_named_land_until_confirm() -> None:
    farm = src(FARM)
    assert "func peek_discover_candidate(" in farm
    assert "func arm_discover_pick(" in farm
    assert "func clear_discover_pick(" in farm
    peek = body(FARM, "peek_discover_candidate")
    assert "first_pressured" in peek
    assert "arm_discover_pick" in peek
    disc = body(FARM, "discover_biome")
    assert "_armed_discover_biome" in disc
    assert "first_pressured" in disc
    assert "commit_action" in disc
    # Spend happens on the real add, not the arm.
    assert "commit_action" not in peek


def test_pressured_story_land_enters_a_pool_that_omitted_it() -> None:
    forecast = src(FORECAST)
    assert "func expand_unexplored(" in forecast
    expand = body(FORECAST, "expand_unexplored")
    assert "_biomes_under_pressure" in expand
    assert "last_removed_biome" in expand
    assert "BloodLedger" in expand
    first = body(FORECAST, "first_pressured")
    assert "expand_unexplored" in first
    can = body(FARM, "can_discover_biome")
    assert "expand_unexplored" in can
    easy = src(EASY)
    demos = src(DEMOS)
    assert "FungalNetworks" in easy
    assert '"Woodlot"' not in easy and "Woodlot" not in easy.split("unexplored_biome_pool")[1].split("\n")[0]
    assert "Woodlot" in demos.split("unexplored_biome_pool")[1].split("\n")[0]


def test_woodlot_off_rail_mills_captain_add_biome() -> None:
    """Playtest: gold named 'Woodlot not in TYUIOP' and skipped Captain.
    Add Biome is how Woodlot lands on the rail. Plant the Mill unlocks [7]."""
    prog = src(PROG)
    cross = prog.split("static func _cross_to(")[1].split("\nstatic func ")[0]
    assert 'return "▸ %s not in TYUIOP"' not in cross
    assert 'return "▸ Woodlot not in TYUIOP"' not in cross
    assert "_land_off_rail_line" in cross
    assert "Forest not in TYUIOP" in cross
    land = prog.split("static func _land_off_rail_line(")[1].split("\nstatic func ")[0]
    assert "[7] Captain" in land
    assert "Add Biome — %s" in land
    assert '[R] Plant the Mill' in land
    assert '[5] Icon' in land
    plant = prog.split("static func _plant_walk_line")[1].split("\nstatic func ")[0]
    assert "_land_off_rail_line(want_biome)" in plant
    hats = prog.split("const HAT_UNLOCK_FLAGS")[1].split("\n}")[0]
    cap = hats.split("FRAME_CAPTAIN")[1].split("FRAME_SPARK")[0]
    assert "new_voices" in cap
    disc = prog.split("static func _discover_walk_line")[1].split("\nstatic func ")[0]
    assert '[5] Icon' in disc
    intro = src(ROOT / "Core" / "Story" / "IntroVoice.gd")
    spent = intro.split("static func _mill_wakes_spent(")[1].split("\nstatic func ")[0]
    assert '_atom_seated_in("Village", "🔨")' in spent
    assert 'flag == "mill_wakes"' not in spent
    assert "new_voices" in spent


def test_woodlot_door_names_timber_country_and_completes_on_load() -> None:
    flags = json.loads(src(FLAGS))
    if isinstance(flags, dict):
        flags = flags.get("flags", [])
    door = next(f for f in flags if f.get("id") == "woodlot_door")
    aq = door["arc_quest"]
    assert "Woodlot" in aq["hint"]
    assert "Add Biome" in aq["hint"]
    preds = aq["state_predicates"]
    assert any(p.get("type") == "biome_evolving" and p.get("biome") == "Woodlot" for p in preds)
    # Plot-explore is not the door. Completing is Woodlot loaded with a live QC.
    assert "explore" not in json.dumps(preds)
    biomes = json.loads(src(BIOMES))
    fungal = next(b for b in biomes if b.get("name") == "FungalNetworks")
    assert "health and death" in fungal.get("description", "")


def test_banner_and_chip_name_the_fish() -> None:
    walk = body(PROG, "_discover_walk_line")
    assert "discover_target_name" in walk
    assert "Add Biome — %s" in walk
    target = body(PROG, "discover_target_name")
    assert "_pressured_discover_name" in target
    assert "biome_evolving" in target
    chips = body(CHIPS, "_build_frame_actions")
    assert "discover_target_name" in chips
    assert "Add %s" in chips
    row = body(ROW, "_resolve_button_color")
    assert 'btn_data.get("confirm", false)' in row

def test_n_network_shows_fog_links_to_unexplored() -> None:
    """N Network lists live↔unexplored atom links so Captain pick is visible."""
    ins = ROOT / "UI" / "Overlays" / "InspectorOverlay.gd"
    edges = body(ins, "_compute_network_edges")
    assert "expand_unexplored" in edges
    assert '"fog": true' in edges
    row = body(ins, "_make_network_row")
    assert "fog " in row
    scope = body(ins, "_update_pending_pair_scope")
    assert 'edge.get("fog"' in scope
    r_fn = body(ins, "_on_action_r")
    assert 'fog_edge.get("fog"' in r_fn or 'get("fog"' in r_fn
    assert "Add Biome" in r_fn


def test_claim_biome_is_the_plant_price() -> None:
    """21 eagles seats; the plant formula (south + sprout) takes control."""
    econ = src(ROOT / "Core" / "GameMechanics" / "EconomyConstants.gd")
    claim = econ.split('normalized_action == "claim_biome"')[1].split("if normalized_action")[0]
    assert "get_icon_injection_cost" in claim
    walk = body(PROG, "_discover_walk_line")
    assert "_in_biome_submenu" in walk
    assert "_claim_cost_walk_line" in walk
    assert "_biome_unlocked(want)" in walk
    obj = src(PROG).split("static func objective_text(")[1].split("\nstatic func ")[0]
    island = obj.split('if _flag_fired("island_free")')[1].split("if not _unsigned_plant_offer")[0]
    assert '_biome_unlocked("BloodLedger")' in island
    emoji = body(PROG, "_emoji_need_walk_line")
    assert "discover_target_name" in emoji
    assert "Add Biome" in emoji
    picker = src(ROOT / "UI" / "Core" / "Submenus" / "BiomeDiscoverySubmenu.gd")
    assert "claim_south" in picker
    collect = picker.split("static func _collect_options")[1].split("static func ")[0]
    assert 'get_action_cost(farm, "claim_biome"' not in collect
    disc = body(FARM, "discover_biome")
    assert "commit_cost" not in disc
    assert "preflight_cost" not in disc
