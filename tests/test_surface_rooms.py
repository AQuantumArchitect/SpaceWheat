"""SurfaceRooms is the one grammar table for C and X.

C and X share TYU: identity / offers / held. X adds I for Guide.
Commitments hold market contracts. Charge holds signed story/arc work.
Toasts, tabs, OverlayManager aliases, and walk cues read this file.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_surface_rooms_is_the_tyu_table() -> None:
    rooms = src("UI/Core/SurfaceRooms.gd")
    assert 'KEY_IDENTITY := "T"' in rooms
    assert 'KEY_OFFERS := "Y"' in rooms
    assert 'KEY_HELD := "U"' in rooms
    assert 'KEY_INFO := "I"' in rooms
    assert "NAME_MARKET" in rooms
    assert "NAME_COMMITMENTS" in rooms
    assert "NAME_ARC" in rooms
    assert "NAME_CHARGE" in rooms
    assert "NAME_GUIDE" in rooms
    assert "func c_tabs" in rooms
    assert "func x_tabs" in rooms
    assert 'return "▸ [X] then Arc [%s]" % KEY_OFFERS' in rooms
    assert 'NOUN_C := "Contract"' in rooms
    assert 'NOUN_X := "Teaching"' in rooms
    assert "func item_noun" in rooms
    assert "func row_item_cue" in rooms
    assert "the [%s] %s" in rooms


def test_c_and_x_tabs_read_surface_rooms() -> None:
    board = src("UI/Overlays/QuestBoard.gd")
    arc = src("UI/Overlays/ControlsOverlay.gd")
    for token in (
        "SurfaceRooms.KEY_IDENTITY",
        "SurfaceRooms.KEY_OFFERS",
        "SurfaceRooms.KEY_HELD",
        "SurfaceRooms.NAME_MARKET",
        "SurfaceRooms.NAME_COMMITMENTS",
    ):
        assert token in board, token
    for token in (
        "SurfaceRooms.KEY_IDENTITY",
        "SurfaceRooms.KEY_OFFERS",
        "SurfaceRooms.KEY_HELD",
        "SurfaceRooms.KEY_INFO",
        "Tab.CHARGE",
        "FRAME_CHARGE",
    ):
        assert token in arc, token
    assert "Tab.STORY" not in arc
    assert "FRAME_STORY" not in arc


def test_commitments_are_market_holds_charge_is_story() -> None:
    qm = src("Core/Quests/QuestManager.gd")
    assert "func is_market_hold" in qm
    assert "func is_charge_hold" in qm
    commit = qm.split("func commitment_quests")[1].split("func ")[0]
    assert "is_market_hold" in commit
    charge = qm.split("func charge_quests")[1].split("func ")[0]
    assert "is_charge_hold" in charge
    assert "_furthest_fired_story_act" in charge
    arc = src("UI/Overlays/ControlsOverlay.gd")
    claim = arc.split("func _claim_selected_charge")[1].split("func ")[0]
    assert "claim_quest" in claim


def test_walk_cues_and_dock_share_one_table() -> None:
    prog = src("UI/Core/UIProgression.gd")
    intro = src("Core/Story/IntroVoice.gd")
    overlay = src("UI/Core/OverlayBase.gd")
    board = src("UI/Overlays/QuestBoard.gd")
    assert "SurfaceRooms.walk_open_offers" in prog
    assert "SurfaceRooms.walk_open_offers" in intro
    assert "_top_overlay_walk_cue" in prog
    assert "func room_walk_cue" in overlay
    assert "func room_walk_cue" in board
    arc = src("UI/Overlays/ControlsOverlay.gd")
    cue = arc.split("func room_walk_cue")[1].split("\nfunc ")[0]
    assert "live_tutorial" in cue
    assert "the work is on the field" in cue
    assert 'row_item_cue("X"' in cue
    assert "_charge_selected_item_key" in cue
    assert "the [%s] Contract" not in cue
    assert "no charge yet" not in cue or "ESC closes" in cue
    charge_body = arc.split("func _build_charge_body")[1].split("\nfunc ")[0]
    assert "_arc_rows()" in charge_body
    assert "ESC closes, the work is on the field" in charge_body
    assert "SurfaceRooms.walk_open_offers" in board
    assert "[X→I]" not in board
    assert "push_action_infos" in board
    assert "_apply_playfield_rect" in overlay
    assert "get_dock_reserve" in overlay
    obj = prog.split("static func objective_text()")[1].split("static func ")[0]
    overlay_branch = obj.split("if hold_lamp_live")[0]
    assert "_top_overlay_walk_cue" in overlay_branch
    assert "SurfaceRooms.offers_cue" in overlay_branch


def test_overlay_manager_xy_is_arc_xu_is_charge_xi_is_guide() -> None:
    om = src("UI/Managers/OverlayManager.gd")
    home = om.split("func open_event_home")[1].split("func is_event_home_open")[0]
    assert 'ku == "ARC" or ku == "XY"' in home
    assert 'ku == "CHARGE" or ku == "XU"' in home
    assert 'ku == "GUIDE" or ku == "XI"' in home
    assert 'show_tab_named("self")' in home
    assert 'show_tab_named("charge")' in home
