"""The UI is a graph (Core/Campaign/SurfaceGraph.gd), and every instruction
that names keys is a path on it from the surface that is open NOW.

Pins the structure that keeps the toast, the banner and the open menu from
disagreeing (docs/design/GUIDANCE_FROM_THE_SPEC.md, "The surface graph"):

  * the keymap's X/C tabs, SurfaceRooms' constants and the overlays' own key
    bindings are one table
  * Guide.gd builds no menu path by hand: it asks SurfaceGraph
  * toasts carry no key paths at their source, and a toast that names keys
    collapses when the player moves to another surface
  * signed story beats live on X → Charge, market contracts on C → Commitments
  * the Druid, Operator and Icon steps explore their qubit first
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _func(text: str, name: str) -> str:
    return text.split("func %s(" % name)[1].split("\nfunc ")[0].split("\nstatic func ")[0]


def _keymap() -> dict:
    spec = json.loads(src("Core/Campaign/campaign.json"))
    return spec["guide"]["keymap"]["surfaces"]


def test_keymap_surfaces_rooms_and_overlay_bindings_are_one_table():
    surf = _keymap()
    x = {t["id"]: t["key"] for t in surf["X"]["tabs"]}
    c = {t["id"]: t["key"] for t in surf["C"]["tabs"]}
    rooms = src("UI/Core/SurfaceRooms.gd")
    const = dict(re.findall(r'const (KEY_[A-Z]+) := "([A-Z])"', rooms))
    assert x == {"self": const["KEY_IDENTITY"], "arc": const["KEY_OFFERS"], "charge": const["KEY_HELD"],
                 "guide": const["KEY_INFO"], "story": const["KEY_STORY"]}
    assert c == {"manifold": const["KEY_IDENTITY"], "market": const["KEY_OFFERS"],
                 "commitments": const["KEY_HELD"]}
    overlay = src("UI/Overlays/ControlsOverlay.gd")
    bound = dict(re.findall(r"KEY_([A-Z]): Tab\.([A-Z]+),", overlay.split("const TAB_BY_KEYCODE")[1].split("}")[0]))
    assert bound == {x["self"]: "SELF", x["arc"]: "ARC", x["charge"]: "CHARGE",
                     x["guide"]: "GUIDE", x["story"]: "STORY"}, bound
    assert surf["C"]["reopens"] == "commitments"


def test_no_source_spells_arc_on_the_old_key():
    hits = []
    for p in list((ROOT / "UI").rglob("*.gd")) + list((ROOT / "Core").rglob("*.gd")):
        t = p.read_text(encoding="utf-8")
        for needle in ("Arc [I]", "X→I", "Charge [I]"):
            if needle in t:
                hits.append("%s: %s" % (p.relative_to(ROOT), needle))
    assert not hits, hits


def test_guide_builds_no_menu_path_by_hand():
    guide = src("Core/Campaign/Guide.gd")
    assert "SurfaceGraph.path(" in guide
    for needle in ("_board_open()", 'get("frame_id")', "is_event_home_open"):
        assert needle not in guide, needle
    claim = guide.split("static func _door_claim(")[1].split("\nstatic func ")[0]
    assert '_go("X/charge")' in claim
    accept = guide.split("static func _door_accept(")[1].split("\nstatic func ")[0]
    assert '_go("X/arc")' in accept


def test_surface_graph_reads_the_live_ui_and_walks_the_keymap():
    g = src("Core/Campaign/SurfaceGraph.gd")
    current = g.split("static func current()")[1].split("\nstatic func ")[0]
    for needle in ("_board_open()", "get_active_overlay", "_in_icon_submenu", "_in_gate_submenu"):
        assert needle in current, needle
    edges = g.split("static func edges(")[1].split("\nstatic func ")[0]
    assert "close_key()" in edges and '"reopens"' in edges and "tabs(m)" in edges


def test_toasts_carry_no_key_paths_and_collapse_when_you_move():
    intro = src("Core/Story/IntroVoice.gd")
    offer = intro.split("static func toast_for_offer(")[1].split("\nstatic func ")[0]
    message = offer.split('"message":')[1].split("\n")[0]
    assert not re.search(r"\[[A-Z]\]", message), message
    bridge = src("Core/Story/PlayerEventBridge.gd")
    announce = bridge.split("func _announce_live_beat")[1].split("\nfunc ")[0]
    assert "next_step" not in announce, "the beat toast must not bake the resolver's key path"
    toast = src("UI/Widgets/HintToast.gd")
    proc = toast.split("func _process(")[1].split("\nfunc ")[0]
    assert "_surface_now()" in proc and "flatten()" in proc and "_names_keys(" in proc


def test_commitments_hold_contracts_and_charge_holds_signed_beats():
    qm = src("Core/Quests/QuestManager.gd")
    assert "is_market_hold(q)" in qm.split("func commitment_quests")[1].split("\nfunc ")[0]
    assert "is_charge_hold(q)" in qm.split("func charge_quests")[1].split("\nfunc ")[0]
    overlay = src("UI/Overlays/ControlsOverlay.gd")
    assert "func _build_charge_body" in overlay
    assert "complete_or_claim" in _func(overlay, "_claim_selected_charge")
    intro = src("Core/Story/IntroVoice.gd")
    assert "_is_signed_story(" in intro.split("static func doors_ahead(")[1].split("\nstatic func ")[0]


def test_druid_operator_and_icon_steps_explore_their_qubit_first():
    guide = src("Core/Campaign/Guide.gd")
    for fn in ("_superpose", "_plot_verb", "_pair_gate", "_berry"):
        body = guide.split("static func %s(" % fn)[1].split("\nstatic func ")[0]
        assert "_reveal(" in body, fn
