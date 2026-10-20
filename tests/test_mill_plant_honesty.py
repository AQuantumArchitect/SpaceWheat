"""Icon tutorial honesty: Q plants Mill, mill-union needs 🔨 in Village.

Luke pressed Q because the picker/walk advertised plant, and Q was
Subsistence (Village affinity) while Mill sat on E. The mill-union quest
completed from that subsistence plant. Walk then kept saying plant because
Q-Subsistence was affordable while Mill needed 🔨.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FLAGS = ROOT / "Core" / "Quests" / "data" / "story_flags.json"
PROG = ROOT / "UI" / "Core" / "UIProgression.gd"
PICKER = ROOT / "UI" / "Core" / "Submenus" / "IconInjectionSubmenu.gd"
QII = ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd"
INTRO = ROOT / "Core" / "Story" / "IntroVoice.gd"
BIOMES = ROOT / "Core" / "Biomes" / "data" / "biomes.json"
COST = ROOT / "Core" / "GameMechanics" / "EconomyConstants.gd"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def body(path: Path, name: str) -> str:
    parts = src(path).split("func %s(" % name)
    assert len(parts) > 1, "%s() is gone from %s" % (name, path.name)
    return parts[1].split("\nfunc ")[0]


def test_new_voices_requires_mill_hammer_in_village() -> None:
    flags = json.loads(src(FLAGS))
    voices = next(f for f in flags if f.get("id") == "new_voices")
    aq = voices.get("arc_quest") or {}
    preds = aq.get("state_predicates") or []
    assert preds, "new_voices lost its plant ask"
    assert all(p.get("gate") != "inject_icon" for p in preds), (
        "any inject_icon completed mill-union from Subsistence"
    )
    mill = next(p for p in preds if p.get("type") == "atom_in_biome")
    assert mill.get("biome") == "Village"
    assert mill.get("atom") == "🔨"
    hint = str(aq.get("hint", ""))
    assert "Mill" in hint
    assert "🔨" in hint
    assert "[R] Plant" in hint
    assert "[5]" in hint
    assert len(hint) <= 70
    body_txt = str(aq.get("body", ""))
    assert "🔨" in body_txt
    assert "Subsistence" not in body_txt


def test_village_natives_wind_not_hammer() -> None:
    """💨 is already in Village, so mill-union cannot gate on 💨."""
    biomes = json.loads(src(BIOMES))
    items = biomes.get("biomes", biomes) if isinstance(biomes, dict) else biomes
    village = next(b for b in items if b.get("name") == "Village")
    emojis = set(village.get("emojis") or [])
    assert "💨" in emojis
    assert "🔨" not in emojis
    assert "👥" in emojis


def test_picker_pins_quest_atom_to_q() -> None:
    picker = src(PICKER)
    assert "prefer_atom" in picker
    assert "func _pin_preferred_atom" in picker
    pin = body(PICKER, "_pin_preferred_atom")
    assert "return pinned + rest" in pin
    gen = body(PICKER, "generate_submenu")
    assert "_pin_preferred_atom" in gen
    qii = src(QII)
    assert "plant_target_atom()" in qii
    assert "prefer_atom" in qii


def test_icon_r_incorporate_when_tracked_ripe_unbound() -> None:
    """w317: toast ripe Incorporate, chip Plant because unbound."""
    icon = src(ROOT / "Core" / "UI" / "IconChipResolvers.gd")
    assert "register_early" in icon
    assert "incorporate_icon" in icon


def test_icon_q_trim_disabled_when_wolf_short() -> None:
    """w304: chip Trim while banner named Forest for 🐺 10/13."""
    icon = src(ROOT / "Core" / "UI" / "IconChipResolvers.gd")
    assert "func resolve_q" in icon
    assert "needs 13🐺" in icon
    reg = src(ROOT / "Core" / "UI" / "ChipResolverRegistry.gd")
    assert "icon.q_trim" in reg
    tools = src(ROOT / "Core" / "GameState" / "ToolConfig.gd")
    assert "icon.q_trim" in tools


def test_walk_names_hammer_cost_before_q_plant() -> None:
    plant = body(PROG, "_plant_walk_line")
    assert plant.find("_plant_south_short") < plant.find("_in_icon_submenu")
    assert "_plant_cost_walk_line" in plant
    assert "_sprout_short" in plant
    cost = body(PROG, "_plant_cost_walk_line")
    assert "ESC closes" in cost
    need = body(PROG, "_emoji_need_walk_line")
    assert "walk_open_offers" in need
    assert "[Q] gather" in need
    assert "func plant_target_atom(" in src(PROG)
    assert "func plant_cost_short(" in src(PROG)
    south = body(PROG, "_plant_south_short")
    assert '"🌱"' in south
    econ = src(COST)
    assert "ICON_INJECTION_SOUTH_COST" in econ


def test_hammer_need_mills_icon_not_captain() -> None:
    """Playtest: gold said [7] Captain Add Biome for 🔨 4/13; mill is [5] Icon."""
    need = body(PROG, "_emoji_need_walk_line")
    assert "_claim_south_of" in need
    assert "mill_plant_hunt" in need
    assert "hunt_reward_emoji" in need
    empty = need.split("if hit.is_empty():")[1].split("var bname")[0]
    captain = 'return "▸ [7] Captain — Add Biome for %s"'
    icon = 'return "▸ [5] Icon for %s"'
    assert captain in empty
    assert icon in empty
    assert empty.find("not mill_plant_hunt") < empty.find(captain)
    assert empty.find(icon) > empty.find(captain)
    helper = body(PROG, "_claim_south_of")
    assert "claim_south" in helper
    obj = body(PROG, "objective_target")
    plant_south = obj.split("if _plant_south_short():")[1].split("var icon_hat")[0]
    assert "ROOM_MARKET" in plant_south


def test_unsigned_new_voices_beats_cull_walk() -> None:
    """Plant a New Voice must not send Captain cull→Add Biome."""
    prog = src(PROG)
    obj = body(PROG, "objective_text")
    steal_at = obj.find("not _unsigned_plant_offer().is_empty()")
    sixteen_walk = obj.find("if sixteen_live():")
    assert steal_at != -1 and sixteen_walk != -1
    assert steal_at < sixteen_walk
    assert "not _act0_live()" in obj.split("not _unsigned_plant_offer().is_empty()")[0][-80:]
    disc = body(PROG, "_discover_walk_line")
    assert "_unsigned_plant_offer" in disc
    ask = body(PROG, "_is_plant_ask")
    assert "new_voices" in ask


def test_inject_reuses_blank_register_at_cap() -> None:
    # w288 sitting: Village G empty at nq=6, Plant picker mute.
    qi = src(ROOT / "Core" / "Instrumentation" / "QuantumInstrument.gd")
    pair = qi.split("func action_inject_icon_pair(")[1].split("\nfunc ")[0]
    assert "_blank_register_id" in pair
    assert "relabel_axis" in pair
    blank = qi.split("func _blank_register_id(")[1].split("\nfunc ")[0]
    assert "_register_is_bound" in blank
    builder = src(ROOT / "Core" / "Environment" / "Components" / "BiomeQuantumSystemBuilder.gd")
    assert "func relabel_axis(" in builder


def test_icon_r_blank_axis_falls_through_to_plant() -> None:
    # w282 dump: Village G gathered-empty, banner Plant 🪵 vs chip Track first.
    resolvers = src(ROOT / "Core" / "UI" / "IconChipResolvers.gd")
    r = resolvers.split("static func resolve_r(")[1].split("\nstatic func ")[0]
    assert "register_bound" in r
    assert "focused_axis" in r
    assert 'str(ax.get("north", "")) == ""' in r
    assert "return {}" in r


def test_intro_voice_treats_mill_union_as_plant() -> None:
    offer = body(INTRO, "_offer_is_plant")
    assert "atom_in_biome" in offer
    assert "new_voices" in offer
    toast = body(INTRO, "toast_for_offer")
    assert "_plant_cost_is_short" in toast


def test_first_learn_seats_the_word_in_demos() -> None:
    """Playtest 2026-10-12: 🔨 was a random Millwright coupling; market
    could not be steered. First-learn plants the word in The Demos for
    free so the south×13 can be harvested at home, then paid to plant
    Village. new_voices still requires Village 🔨.
    """
    farm = src(ROOT / "Core" / "Farm.gd")
    assert "func seat_learned_word_at_home(" in farm
    seat = body(ROOT / "Core" / "Farm.gd", "seat_learned_word_at_home")
    assert 'home := "TheDemos"' in seat
    assert "expand_quantum_system" in seat
    assert "preflight_action_cost" not in seat
    assert "commit_action_cost" not in seat
    assert "add_resource" not in seat
    grant = body(ROOT / "Core" / "Quests" / "QuestManager.gd", "_grant_icon_rewards")
    assert "seat_learned_word_at_home" in grant
    find = body(PROG, "_find_glyph_plot")
    assert "TheDemos" in find
    assert "identity_biome_name" in find


def test_market_delivery_does_not_pay_unadvertised_born_pole() -> None:
    """Delivering Forest 🌱 on 💀🌱 minted wallet 💀 the stall never named."""
    lat = src(ROOT / "Core" / "Markets" / "MarketLattice.gd")
    syn = body(ROOT / "Core" / "Markets" / "MarketLattice.gd", "synthesize_and_exercise")
    assert "exercise_immediate(c, false)" in syn
    assert "func exercise(contract_id: int, pay_wallet: bool = true)" in lat
    complete = body(ROOT / "Core" / "Quests" / "QuestManager.gd", "complete_quest")
    assert "classical_reward" not in complete
    assert "_grant_resource_rewards" in complete
