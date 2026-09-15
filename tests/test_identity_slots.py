"""Player faction identity is a biome (up to 6 qubits), not a leftover 3-clone.

Playtest: X-T-[1] showed three identical icons. The G picker was the real
word; [1][2][3] was leftover 3-slot chrome that cloned the starter pair.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FARM = ROOT / "Core" / "Farm.gd"
SELF = ROOT / "UI" / "Overlays" / "ControlsOverlay.gd"
SERIAL = ROOT / "Core" / "GameState" / "GameStateSerializer.gd"
STATE = ROOT / "Core" / "GameState" / "GameState.gd"


def src(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_identity_slots_cap_at_six_and_refuse_clones():
    farm = src(FARM)
    assert "IDENTITY_SLOT_MAX := 6" in farm
    assert "func identity_slot_count" in farm
    assert "func normalize_active_icon_slots" in farm
    norm = farm.split("func normalize_active_icon_slots")[1].split("\nfunc ")[0]
    assert "used.has(i)" in norm
    assert "out.append(-1)" in norm
    setter = farm.split("func set_active_icon_slot")[1].split("\nfunc ")[0]
    assert "IDENTITY_SLOT_MAX" in setter
    assert "slot_idx >= 3" not in setter


def test_self_tab_drops_the_three_clone_row():
    overlay = src(SELF)
    picker = overlay.split("func _build_icon_picker")[1].split("\nfunc ")[0]
    assert 'for i in range(3):' not in picker
    assert '"[%d] %s"' not in picker
    assert "1/2/3 slot" not in picker
    demos = overlay.split("func _build_our_faction_view")[1].split("\nfunc ")[0]
    assert "identity_slot_count" in demos
    assert "IdentityQubit_" in demos
    assert 'get_icons_for_faction("The Demos")' not in demos
    digits = overlay.split("func _identity_digit_slot")[1].split("\nfunc ")[0]
    assert "KEY_6" in digits
    assert "_story_icon_idx = 2" not in overlay.split("func _on_unhandled_key")[1].split("func _select_item_in_tab")[0]


def test_saves_do_not_force_exactly_three_slots():
    serial = src(SERIAL)
    assert "Restore active icon slots" in serial
    assert "slots.size() != 3" not in serial
    assert "normalize_active_icon_slots" in serial
    state = src(STATE)
    assert "active_icon_slots: Array = [0]" in state
    assert "Array = [0, 1, 2]" not in state.split("active_icon_slots")[1].split("\n")[0]
