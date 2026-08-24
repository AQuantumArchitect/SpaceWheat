"""The 3D field draws the biome the player is standing in, framed where it fits.

Two defects, both found while verifying the fog-sphere change (2026-08-11), both
fixed 2026-08-12.

#519 — after a PATH load the field went on rendering the pre-load world. Measured
at the act1_complete checkpoint: `bubble_state` showed one TheDemos orb (axis
👥🌾) while ActiveBiomeManager, the tab row and the story header all said Village,
and clicking a biome tab changed nothing. Root cause: `load_and_apply_path` builds
a NEW Farm without rebuilding the view (the slot-load lane restarts GameRoot, so it
never needed to), leaving every UI holder pointing at the farm the player just
left. Two things then hid it: `_get_active_biome()` silently substituted the first
renderable biome it could find, and `_process` froze the last render forever
instead of noticing its farm was gone.

#520 — the cloud sat ~180px too high, orbs crossing the biome tab row with the
bottom third of the screen empty. `UILayoutManager.play_area_rect` models the 2D
rack's layout (top_bar_height = 6% of the window) while the real top chrome is the
resource bar plus three stacked selection rows (~37% at 720p).
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIELD = ROOT / "Core/Visualization/QuantumField3D.gd"
BARS = ROOT / "UI/Managers/ActionBarManager.gd"
VIEW = ROOT / "UI/FarmView.gd"
SAVES = ROOT / "Core/GameState/SaveLoadCoordinator.gd"
GAMEROOT = ROOT / "scenes/GameRoot.gd"
GLOSS = ROOT / "Core/Quests/PredicateGloss.gd"


def body(path: Path, name: str) -> str:
    parts = path.read_text(encoding="utf-8").split("func %s(" % name)
    assert len(parts) > 1, "%s() is gone from %s — this test reads it, not a guess" % (name, path.name)
    return parts[1].split("\nfunc ")[0]


# ------------------------------------------------------------------ #519: authority

def test_the_field_never_substitutes_a_biome_the_player_is_not_in() -> None:
    """The rule, stated precisely: substitute only when the authority has no opinion
    about this grid. If ActiveBiomeManager names a biome and the grid HOLDS it, that
    biome is the only honest thing to draw — a neighbour instead is a silent bridge
    channel (cf. #141) that renders the wrong country and speaks nothing."""
    src = body(FIELD, "_get_active_biome")
    got = src.split("if b != null:")
    assert len(got) > 1, (
        "the 'grid has the wanted biome' branch must be explicit — it is what "
        "separates 'ABM governs this grid' from the standalone cognifold "
        "instrument, whose belief-field name ABM never knows"
    )
    owned = got[1].split("if grid.has_method(\"get_all_biomes\")")[0]
    assert "return null" in owned, (
        "when the player's own biome is not renderable the field must draw NOTHING "
        "and say why — never fall through to the first biome that happens to work"
    )
    assert "_field_blocked" in owned, "and it must record the reason (#519)"


def test_the_cognifold_fall_through_survives() -> None:
    """CognifoldTraceView hands the field a grid holding one 'belief-field: <world>'
    biome — a name ActiveBiomeManager will never contain. That IS the 'no opinion'
    case, so the fall-through must stay reachable."""
    src = body(FIELD, "_get_active_biome")
    assert "get_all_biomes" in src, (
        "deleting the fall-through outright blanks the standalone cognifold "
        "instrument, which has no ActiveBiomeManager to ask"
    )


def test_a_dead_farm_stops_the_render_instead_of_freezing_it() -> None:
    """`_process` used to return early on a missing farm, which left the pre-load
    orbs on screen and clickable — the visible half of #519.

    `_process` is now a thin frame-cost-timing wrapper around `_tick_field`
    (added when FrameCostLedger instrumentation landed) — the real guard
    lives in `_tick_field`, so that's what this test has to read."""
    src = body(FIELD, "_tick_field")
    guard = src.split("var biome = _get_active_biome()")[0]
    assert "is_instance_valid(farm_ref)" in guard, (
        "a freed Farm is not `== null` in Godot — the guard must ask "
        "is_instance_valid or it sails straight past a dangling reference"
    )
    assert "_clear_bubbles()" in guard, (
        "when the farm goes, the world it described must go with it"
    )


def test_the_rig_can_tell_wrong_biome_from_empty_field() -> None:
    """bubble_count alone cannot distinguish 'nothing rendered' from 'rendering the
    wrong country' — which is how #519 survived a whole mouse-only campaign."""
    src = body(FIELD, "rig_field_status")
    for key in ('"rendering"', '"wants"', '"agrees"', '"blocked"', '"farm_is_live"'):
        assert key in src, "rig_field_status must report %s" % key
    listener = (ROOT / "🍄/🎛️/rig_listener.gd").read_text(encoding="utf-8")
    assert "rig_field_status()" in listener, (
        "and the rig surface must actually carry it, or no leg can see the lie"
    )


# --------------------------------------------------------------- #519: the re-point

def test_the_lane_that_swaps_the_farm_is_the_lane_that_re_points_the_view() -> None:
    src = body(SAVES, "_attach_state_to_fresh_farm")
    assert "rebind_view_to_farm" in src, (
        "this lane builds a new Farm with the scene still alive; if it does not "
        "hand the view the new farm, every holder keeps the dead one (#519)"
    )
    assert "func rebind_farm" in VIEW.read_text(encoding="utf-8"), (
        "FarmView owns the renderer, so FarmView is where the re-point lands"
    )
    assert "_connect_quantum_viz_to_farm()" in body(VIEW, "rebind_farm"), (
        "re-pointing must go through the same wiring boot uses — not a second path"
    )


def test_the_dev_screenshot_lane_no_longer_hand_rolls_its_own_re_point() -> None:
    """SW_LOAD_PATH used to re-point the field itself. That private copy was proof
    the load lane needed it, and cover for the fact that nobody else got it."""
    src = GAMEROOT.read_text(encoding="utf-8")
    assert "f3d.connect_to_farm(post_farm)" not in src, (
        "one authority for the post-load re-point, and it is not the screenshot code"
    )


# ------------------------------------------------------------------ #520: framing

def test_the_hud_owner_reports_the_band_it_leaves_free() -> None:
    src = body(BARS, "get_free_band")
    for row in ("menu_selection_row", "tool_selection_row", "mode_selection_row",
                "clock_speed_row"):
        assert row in src, (
            "%s boxes the play space — a band that ignores it puts orbs behind the "
            "chrome (#520)" % row
        )
    assert "action_preview_row" in src, "the QERF chips close the band from below"


def test_the_camera_frames_on_the_real_band_not_the_2d_rack_model() -> None:
    src = body(FIELD, "_update_camera_framing")
    assert "get_free_band" in src, (
        "play_area_rect describes the 2D rack (top_bar_height = 6% of the window); "
        "the field must ask the HUD's own owner where the chrome really ends"
    )
    assert "pc.y" in src, "the correction is vertical — the HUD spans the full width"


# --------------------------------------------------------------- #515: a moving dial

def test_the_meta_state_gate_shows_a_number_and_names_a_verb() -> None:
    """`island_stops_asking` is the one beat that asks the player to BE a certain
    way rather than do X in biome Y. With no live value and no named verb it read
    as the first ask in six acts with no next step."""
    src = GLOSS.read_text(encoding="utf-8")
    # "soul_purity_gte" now ALSO appears in TARGETS (2026-08-13: it gained a
    # real hat-spotlight target like every other predicate) — split on the
    # LAST occurrence so this lands in summary()'s match arm, not the dict.
    seg = src.rsplit('"soul_purity_gte":', 1)[1].split('"biome_evolving"')[0]
    assert "soul_purity_now" in seg, "it must show where the player stands right now"
    # 2026-08-13: reworded to "Icon (5)" (dropped "hat") to fit the banner's
    # OBJECTIVE_MAX_CHARS budget while still naming the hat digit in (N) form
    # (predicate_target_smoke pins the spotlight off that digit) — the verb
    # is still named, just not with the word "hat".
    assert "Icon (5)" in seg, (
        "and name the verb that moves it — incorporation pumps the owning faction "
        "(Farm._pump_for_icon), which is what sharpens ρ out of the fog"
    )


# ------------------------------------------------- #514: a load that says it loaded

def test_loading_an_empty_slot_says_no() -> None:
    """`load_and_apply` used to `return true` unconditionally on the AppRoot lane.
    restart_into() on an empty slot cheerfully boots a FRESH scenario, so a load
    that never happened reported success — and EscapeMenu only keeps its menu open
    `if not ok`, so it closed on a brand-new game. Found 2026-08-12 by the endgame
    re-mint drive: load_game(slot=3), one past NUM_SAVE_SLOTS, answered
    {"loaded": true} while landing in a fresh demos_normal boot with 1 flag."""
    src = body(SAVES, "load_and_apply")
    lane = src.split("if not app_roots.is_empty():")[1].split("# Headless")[0]
    assert "return false" in lane, (
        "the AppRoot lane must refuse a slot with nothing in it — the headless "
        "lane below already does, and the two must agree"
    )
    assert lane.index("return false") < lane.index("session_lifecycle.restart_into"), (
        "and it must refuse BEFORE restarting, or the refusal arrives after the "
        "player's session has already been replaced by a fresh game"
    )


def test_the_endgame_checkpoints_are_not_all_the_same_state() -> None:
    """The whole point of #514: endrun_act7/act8/ending were one 49-flag state
    wearing three names, so no leg could walk act7 -> act8 -> ending."""
    import json
    d = ROOT / "🍄/🧪/checkpoints"
    counts = {}
    for name in ("endrun_act7", "endrun_act8"):
        p = d / (name + ".json")
        assert p.exists(), "%s is a shipped fixture — do not remove it silently" % name
        fired = json.loads(p.read_text(encoding="utf-8"))["flags_fired"]
        counts[name] = set(fired if isinstance(fired, list) else fired)
    assert counts["endrun_act7"] < counts["endrun_act8"], (
        "act8 must strictly extend act7. If these ever collapse to the same set "
        "again, the endgame is untestable and the fixtures are lying about which "
        "act they represent."
    )
    for beat in ("braid_alphabet", "the_fusion", "the_number_lied"):
        assert beat in counts["endrun_act7"], (
            "endrun_act7 must carry real act-7 play, not a post-ending state "
            "mislabelled — %s is missing" % beat
        )
    for beat in ("the_rite", "the_door_stays_open"):
        assert beat in counts["endrun_act8"], "endrun_act8 is missing %s" % beat


def test_the_lever_named_in_the_gloss_is_the_lever_in_the_code() -> None:
    """A hint that names a verb the physics does not have is worse than no hint."""
    farm = (ROOT / "Core/Farm.gd").read_text(encoding="utf-8")
    assert "faction_density.pump(" in farm, (
        "the gloss promises that taking an icon pumps its owner faction; if that "
        "call goes, the promise becomes a lie and this test should fail loudly"
    )
    assert re.search(r"func _pump_for_icon", farm), "…from the icon-learn path"
