"""The portal rail is a first-class biome door (mouse parity, wave 2026-08-24).

Before this wave the rail — the emoji orbs on the 3D field's left edge — could
switch biomes but not SPEAK: it called ActiveBiomeManager.set_active_biome()
directly and its biome_selected signal had zero listeners, so a rail click gave
no "-> Village" toast, no Focus repoint, and left a pending destructive confirm
armed. That is byte-for-byte the wave-5 defect the biome bar's biome_confirmed
grammar was built to fix (docs/MOUSE_PARITY_AUDIT.md, "silent switch"). These
ratchets pin the rail's grammar so the bar can be removed without regressing
the mouse-first pass:

  1. a rail dive captures old BEFORE the set and emits biome_confirmed only when
     the switch actually landed (set_active_biome silently no-ops mid-transition);
  2. FarmView routes biome_confirmed to the shared QII.confirm_biome_switch tail;
  3. every orb says its name and bracketed key (say-the-click needs screen words);
  4. every ASSIGNED slot gets an orb — placeholders included — because keyboard
     T/Y switches to an unrenderable biome and the mouse must be able to follow;
  5. a blind mouse seat can enumerate the rail (rig_portals -> biome_slots
     orb_center), since 3D meshes are invisible to the Control-walking
     `clickables` verb by design.
"""

from conftest import read_source


def _field() -> str:
    return read_source("Core/Visualization/QuantumField3D.gd")


def test_rail_click_gets_the_same_confirm_as_keyboard() -> None:
    field = _field()
    # The dive helper: old captured before the set, emit only on a real switch,
    # refusal spoken when the crossing is refused (anti-gating).
    assert "signal biome_confirmed(old_biome: String, new_biome: String, key: String)" in field
    assert "func _dive_to_biome(nm: String) -> void:" in field
    assert 'var old := str(abm.get_active_biome())' in field
    assert "abm.set_active_biome(nm)" in field
    assert "biome_confirmed.emit(old, nm, key)" in field
    assert '_toast("mid-crossing' in field
    # The pick branch routes through the helper -- no bare silent set left.
    assert "_dive_to_biome(str(bestp.name))" in field

    fv = read_source("UI/FarmView.gd")
    assert "renderer.biome_confirmed.connect(_on_biome_confirmed)" in fv
    assert "func _on_biome_confirmed(old_biome: String, new_biome: String, key: String) -> void:" in fv
    assert "instrument_input.confirm_biome_switch(old_biome, new_biome, key)" in fv

    # The tail itself stays whole (duplicated from the headed-surface test on
    # purpose: this file must fail alone if the tail is hollowed).
    qii = read_source("UI/Core/QuantumInstrumentInput.gd")
    assert "func confirm_biome_switch(old_biome: String, new_biome: String, key: String) -> void:" in qii
    assert "_apply_biome_switch(old_biome, new_biome, key)" in qii


def test_rail_orbs_say_their_name_and_key() -> None:
    field = _field()
    assert "func _spawn_portal_label(nm: String, key: String, pos: Vector3) -> Label3D:" in field
    assert 'lbl.text = ("%s [%s]" % [nm, key]) if key != "" else nm' in field
    # Both spawn paths label; the clear path frees the label with the orb.
    assert field.count("_spawn_portal_label(nm, key, pos)") == 2
    assert '"label"' in field.split("func _clear_portals", 1)[1].split("func ", 1)[0]


def test_rail_covers_every_assigned_slot() -> None:
    field = _field()
    # Slot-ordered iteration (rail order = TYUIOP order) ...
    assert "for si in range(int(abm.get_slot_count())):" in field
    assert "abm.get_biome_for_slot(si)" in field
    # ... with a placeholder orb when the assigned biome isn't renderable yet.
    assert "func _spawn_placeholder_portal(nm: String, pos: Vector3, key: String) -> void:" in field
    assert "_spawn_placeholder_portal(str(e.name), pos, str(e.key))" in field
    # Slot reshuffles reflow the rail even when the active biome stays put.
    assert "biome_order_changed.connect" in field
    assert "slot_assignment_changed.connect" in field


def test_rail_is_enumerable_by_a_blind_mouse_seat() -> None:
    field = _field()
    assert "func rig_portals() -> Array:" in field
    assert '"placeholder": bool(p.get("placeholder", false))' in field

    rig = read_source("🍄/🎛️/rig_listener.gd")
    slots_block = rig.split('"biome_slots":', 1)[1].split('"board_visible":', 1)[0]
    assert 'has_method("rig_portals")' in slots_block
    assert '"orb_center"' in slots_block

    seat = read_source("🍄/🧪/mouse_seat.py")
    assert '"orb_center": s.get("orb_center")' in seat
