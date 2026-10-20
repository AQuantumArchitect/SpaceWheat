"""Pins the 2026-10-13 overnight testing stack.

Dump lies, grind follower, hive-wave abort/roster, advertised [Q] Refresh.
Does not boot Godot.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_dump_flags_mill_seated_plant_as_lie():
    dump = src(ROOT / "🍄" / "🧪" / "hive" / "dump_checkpoint.py")
    assert "banner_plant_while_mill_seated" in dump
    assert "banner_icon_plant_while_mill_seated" in dump
    assert "live_factory" in dump
    grind = src(ROOT / "🍄" / "🧪" / "hive" / "grind_follow.py")
    assert "banner_cull_woodlot" in grind
    assert "banner_empty_arc_while_mill_seated" in dump
    assert "arc_catalog_empty_while_mill_runs" in dump
    assert "banner_gather_unpaid_rabbit" in dump
    assert "banner_plant_the_mill_while_mill_seated" in dump
    assert "banner_strike_without_people" in dump
    assert 'well_axes and "🐇" in farm_blob' in dump
    assert "banner_gather_unmeasured_people" in dump
    assert "banner_lantern_while_rabbit_short" in dump
    assert "banner_lantern_while_mill_seated" in dump
    assert '"island_free" not in flag_names' in dump
    assert "banner_forest_while_rabbit_short" in dump
    assert 'first_keys[:1] == ["O"]' in dump
    assert '"CLAIM" in after_join.upper()' in dump
    assert "if not farm_for_keys and farm_after:" in dump
    assert '"THEN ARC" in first_join.upper()' in dump
    assert "LANTERNFALL" in dump.upper()
    assert "banner_empty_plot_occupied" in dump
    assert "banner_abandon" in dump
    assert 'mill_seated = any(("⚙" in str(ax) or "🏭" in str(ax))' in dump
    assert 'if not village_axes:' in dump
    assert '"schema": "game-mill-dump/0.1"' in dump
    assert '"mill_seated": mill_seated' in dump
    assert "gold_off_spine" in dump
    assert "compile_live_from_dump" in dump
    stack = src(ROOT / "🍄" / "🧪" / "hive" / "TESTING_STACK.md")
    assert "spine_recipe.py" in stack
    assert "gold_off_spine" in stack
    boot = dump.split("for key in presses or []:")[1].split("farm = _lines")[0]
    assert 't("ui_stack")' in boot
    assert 'int(stack.get("size") or 0) > 1' in boot
    assert '"ARC" in blob0.upper()' in boot
    assert 't("press_key", key="escape", settle_frames=20)' in boot


def test_grind_follow_is_player_parity_and_raises_cap():
    grind = src(ROOT / "🍄" / "🧪" / "hive" / "grind_follow.py")
    assert 'setdefault("SW_PRESS_CAP", "10")' in grind
    assert 'any(p in ("u", "U") for p in presses)' not in grind
    assert '"deliver" in str(g).lower()' in grind
    assert 'freeze_at = budget if (' in grind
    assert '"accept the teaching"' in grind
    assert "fast-fwd" in grind
    assert 'kw["settle_frames"] = 60' in grind
    assert "collapse the rose" in grind
    assert "pole then superpose" not in grind
    assert 'snip == "[5] icon"' in grind
    assert '"island_free" in flags' in grind
    assert "add_resource" not in grind
    assert "inject_icon" not in grind
    assert "time_skip" not in grind
    assert "godot_live" in grind
    assert "first_press" in grind
    assert "Do not ESC every turn" in grind
    assert "delivered" in grind
    assert "berry_moved" in grind
    assert "or berry_moved" in grind
    assert "incorporate" in grind
    assert "cmd_bank" in grind
    assert "OFF_WALL_FLAGS" in grind
    assert "banner_abandon" in grind
    assert 'presses[-1] == "x"' in grind
    assert 'key, shift = "i", False' in grind
    assert 'key, shift = "g", False' in grind
    assert '"claim" not in blob.lower()' in grind
    assert '"THEN ARC" in blob.upper()' in grind
    from importlib.machinery import SourceFileLoader
    import sys
    sys.path.insert(0, str(ROOT / "🍄" / "🧪"))
    # Importing grind_follow imports player_seat (needs WSL rig). Parse only.
    assert "No LLM" in grind


def test_grind_first_press_picks_advertised_key():
    import re
    key_re = re.compile(r"\[([A-Z0-9;,'\.\-\]]+)\]")

    def first_press(blob: str):
        shift = "SHIFT" in blob.upper()
        keys = key_re.findall(blob.upper())
        if not keys:
            if "ESC" in blob.upper():
                return "escape", False
            return None, False
        k = keys[0]
        if k in ("ESCAPE", "ESC"):
            return "escape", shift
        if len(k) == 1:
            return k.lower(), shift
        return k.lower(), shift

    key, shift = first_press("▸ [C]ontracts")
    assert key == "c" and shift is False
    key, _ = first_press("▸ [Q] Refresh 🐇")
    assert key == "q"
    key, _ = first_press("▸ [R] Accept the [G] Contract")
    assert key == "r"
    key, _ = first_press("▸ ESC closes")
    assert key == "escape"
    grind = src(ROOT / "🍄" / "🧪" / "hive" / "grind_follow.py")
    assert "def first_press" in grind


def test_hive_wave_drops_tap_lamb_on_overlay_and_mills_q_refresh():
    wave = src(ROOT / ".grok" / "workflows" / "hive-wave.rhai")
    assert "fn overlay_heavy" in wave
    assert "fn should_abort_rest" in wave
    assert "dropped tap-lamb" in wave
    assert "dropped earnest" in wave
    assert "grind_follow.py" in wave
    assert "mill [Q] Refresh" in wave
    assert "mill [Shift+E] Refresh" not in wave
    assert "last_gold" in wave


def test_sensor_laws_advertise_q_refresh_and_act0_tap_lamb():
    sensor = src(ROOT / "🍄" / "🧪" / "hive" / "prompts" / "SENSOR.md")
    assert "`[Q] Refresh`" in sensor
    assert "tap-lamb is Act-0 mouse chrome only" in sensor
    assert "grind_follow.py" in sensor
    assert "without `[Shift+E] Refresh`" not in sensor


def test_market_body_does_not_name_arc_while_mill_seated():
    board = src(ROOT / "UI" / "Overlays" / "QuestBoard.gd")
    body = board.split("func _build_market_body")[1].split("\nfunc ")[0]
    assert "_village_mill_seated()" in body
    assert "_millwright_rhythm_live()" in body
    assert "walk_open_offers(\"X\")" in body


def test_millwright_seated_outranks_empty_arc():
    """Plant the Mill leftover stays spent. Hold Commerce stays on Arc."""
    prog = src(ROOT / "UI" / "Core" / "UIProgression.gd")
    plant = prog.split("static func _plant_walk_line")[1].split("static func ")[0]
    head = plant.split("Wave 11")[0]
    assert "_village_mill_seated()" in head
    assert "_millwright_walk_line()" in head
    dump = src(ROOT / "🍄" / "🧪" / "hive" / "dump_checkpoint.py")
    assert "arc_plant_while_mill_seated" in dump
    assert "arc_catalog_empty_while_mill_runs" in dump
    intro = src(ROOT / "Core" / "Story" / "IntroVoice.gd")
    assert "static func _mill_wakes_spent" in intro
    spent = intro.split("static func _mill_wakes_spent(")[1].split("\nstatic func ")[0]
    assert "new_voices" in spent
    assert 'flag == "mill_wakes"' not in spent
    live = intro.split("static func live_quest(")[1].split("\nstatic func ")[0]
    assert "_mill_wakes_spent(q)" in live
    best = intro.split("static func _best_unsigned_offer(")[1].split("\nstatic func ")[0]
    assert "_mill_wakes_spent(q)" in best
    ahead = intro.split("static func doors_ahead(")[1].split("\nstatic func ")[0]
    assert "_mill_wakes_spent(q)" in ahead


def test_mill_wakes_is_not_plant_ask_once_mill_seated():
    prog = src(ROOT / "UI" / "Core" / "UIProgression.gd")
    plant = prog.split("static func _is_plant_ask")[1].split("static func ")[0]
    mill = plant.split('== "mill_wakes"')[1].split("if str(q.get")[0]
    assert "_village_mill_seated()" in mill
    assert "return false" in mill
    voices = plant.split('== "new_voices"')[1].split("for pred in")[0]
    # ⚙ seated is millwright. Captain unlocks on 🔨 / new_voices.
    assert '_atom_seated_in("Village", "🔨")' in voices
    assert '_flag_fired("new_voices")' in voices
    assert "_village_mill_seated()" not in voices
    assert "return false" in voices


def test_millwright_outranks_leftover_plant_ask_when_seated():
    prog = src(ROOT / "UI" / "Core" / "UIProgression.gd")
    obj = prog.split("static func objective_text")[1].split("static func objective_target_key")[0]
    assert obj.index("_millwright_walk_line()") < obj.index(
        "if _is_plant_ask(best) and not _act0_live():"
    )
    assert obj.index("union_early") < obj.index("_horn_walk_line")
    assert obj.index("union_early") < obj.index("_watched_walk_line")
    assert obj.index("union_rabbits") < obj.index("_is_berry_ask(best)")
    dump = src(ROOT / "🍄" / "🧪" / "hive" / "dump_checkpoint.py")
    assert '"🐇" in after_join and "ICON" in first_join.upper()' in dump
    millw = prog.split("static func _millwright_walk_line")[1].split("\nstatic func ")[0]
    assert "preflight_action" in millw
    assert "quest_reroll" in millw
    dump = src(ROOT / "🍄" / "🧪" / "hive" / "dump_checkpoint.py")
    assert "banner_contracts_while_rabbit_short" in dump
    assert 'wallet.get("🐇")' in dump


def test_refresh_shortfall_mills_rabbit_plot():
    board = src(ROOT / "UI" / "Overlays" / "QuestBoard.gd")
    cue = board.split("func _refresh_walk_cue")[1].split("\nfunc ")[0]
    assert "ESC closes for 🐇" in cue
    assert "[L]" not in cue
    millw = src(ROOT / "UI" / "Core" / "UIProgression.gd").split(
        "static func _millwright_walk_line"
    )[1].split("\nstatic func ")[0]
    assert millw.index('int(_wallet("🐇"))') < millw.index("_village_mill_seated")
    assert '_emoji_need_walk_line("🐇"' in millw
    assert '"Strike" in rabbit_line' in millw
    assert 'or "Superpose" in rabbit_line' not in millw
    assert "[Q] Gather for 🐇" in millw
    assert "[F] ▶ Play for 🐇" in millw
    assert '_glyph_plot_key("👥", "Village", true)' in millw
    assert '_glyph_plot_key("👥", "Village", false)' not in millw
    assert "[Q] Gather for 👥" in millw
    assert "[F] Explore for 👥" not in millw
    assert "[T] Demos for 👥" not in millw
    assert "crosses to TheDemos" not in millw
    assert "never fog G" in millw
    assert millw.index('int(_wallet("👥")) < 1') < millw.index(
        'if rabbit_line != "" and "Strike" in rabbit_line'
    )
    assert "[F] Fast-Fwd for 🐇" not in millw
    # w470: first 👥 stays Village. Never mill Forest/Woodlot for 👥.
    assert "Forest L is" in millw
    assert '_cross_to("StarterForest")' not in millw
    assert '_cross_to("Woodlot")' not in millw
    assert "[R] Strike for 👥" not in millw
    forest = millw.split('== "StarterForest"')[1].split("_glyph_plot_key")[0]
    assert "[Q] Gather for 👥" in forest
    assert "[E] Superpose for 👥" not in forest
    assert "[R] Strike" not in forest
    assert '_cross_to("Village")' in forest
    assert "[E] Superpose for 👥" in millw
    assert millw.index("[8] Ace for 🐇") < millw.rindex("[R] Strike for 🐇")
    assert "[R] Strike for 🐇" in millw
    assert "ESC — F is" not in millw
    strike = millw.split('"Strike" in rabbit_line')[1].split('if rabbit_line != "" and (("Druid"')[0]
    assert 'int(_wallet("👥")) < 1' in strike
    assert "_measure_well_free" in strike
    assert "_plot_bloch_p1" in strike
    assert "_already_superposed" in strike
    assert "_millwright_south_prep_line" in strike
    assert "_millwright_south_prep_line" in millw
    prep = src(ROOT / "UI" / "Core" / "UIProgression.gd").split(
        "static func _millwright_south_prep_line"
    )[1].split("\nstatic func ")[0]
    assert "[0] Druid for 🐇" in prep
    assert "[Q] Spin − for 🐇" in prep
    assert "[E] Superpose for 🐇" in prep
    assert "rotate_down" in prep
    assert "_hearth_sand()" in prep
    assert prep.index("[Q] Spin") < prep.index("[E] Superpose")
    assert '"Druid" in rabbit_line' in millw
    druid_f = millw.split('"Druid" in rabbit_line')[1].split("if rabbit_line != \"\":")[0]
    assert "_millwright_south_prep_line" in druid_f
    assert "_plot_bloch_p1" in druid_f
    assert "[C] Contracts" not in druid_f
    assert "ESC closes for 🐇" in druid_f
    assert millw.index("_glyph_plot_key") < millw.index("[R] Strike for 🐇")
    assert "Lanternfall" not in millw or 'not in harvest' in millw
    assert millw.rindex('return "▸ [C]ontracts"') > millw.index('_wallet("🔨")')
    assert "Ace never Superposes" in millw
    assert "biome [U]" in millw
    assert "Lanternfall" in millw
    assert "biome [O]" in millw
    assert "[F] Explore for 🐇" in millw
    rhythm = src(ROOT / "UI" / "Core" / "UIProgression.gd").split(
        "static func _millwright_rhythm_live"
    )[1].split("\nstatic func ")[0]
    assert '_atom_seated_in("Village", "⚙")' in rhythm
    horn = src(ROOT / "UI" / "Core" / "UIProgression.gd").split(
        "static func _horn_walk_line"
    )[1].split("\nstatic func ")[0]
    assert "_millwright_walk_line()" in horn
    assert horn.index("_millwright_walk_line()") < horn.index('_cross_to("Lanternfall")')
    need = src(ROOT / "UI" / "Core" / "UIProgression.gd").split(
        "static func _emoji_need_walk_line"
    )[1].split("\nstatic func ")[0]
    after_hit = need.split("if hit.is_empty():")[1]
    assert after_hit.index("_plot_has_harvest") < after_hit.index("_cross_to")
    assert millw.index('_emoji_need_walk_line("🐇"') < millw.index("_board_walk_line")
    plant = src(ROOT / "UI" / "Core" / "UIProgression.gd").split(
        "static func _plant_walk_line"
    )[1].split("\nstatic func ")[0]
    seated = plant.split("if _village_mill_seated():")[1].split("if wearing !=")[0]
    assert "_millwright_walk_line()" in seated
    board = src(ROOT / "UI" / "Core" / "UIProgression.gd").split(
        "static func _board_walk_line"
    )[1].split("\nstatic func ")[0]
    assert '_wrong_room_line("board")' in board
    farm = board.split("if not _menu_open():")[-1]
    assert 'int(_wallet("🐇")) < 1' in farm
    assert "_millwright_walk_line()" in farm


def test_gear_bench_does_not_accept_pack_lords():
    board = src(ROOT / "UI" / "Overlays" / "QuestBoard.gd")
    room = board.split("func room_walk_cue")[1].split("\nfunc ")[0]
    market = room.split("FRAME_MARKET:")[1].split("FRAME_COMMITMENTS:")[0]
    assert "_millwright_rhythm_live()" in market
    assert "_village_mill_seated()" in market
    assert market.index("_union_market_walk") < market.index("_millwright_rhythm_live()")


def test_refresh_after_deliver_beats_leftover_accept_in_room_cue():
    board = src(ROOT / "UI" / "Overlays" / "QuestBoard.gd")
    room = board.split("func room_walk_cue")[1].split("\nfunc ")[0]
    market = room.split("FRAME_MARKET:")[1].split("FRAME_COMMITMENTS:")[0]
    assert market.index("if _delivered_since_refresh > 0:") < market.index("_union_market_walk")


def test_testing_stack_doc_names_four_layers():
    doc = src(ROOT / "🍄" / "🧪" / "hive" / "TESTING_STACK.md")
    assert "Dump + pytest" in doc
    assert "grind_follow.py" in doc
    assert "literalist" in doc
    assert "Luke Windows" in doc
    assert "BoardTab_U" in doc
