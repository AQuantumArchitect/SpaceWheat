"""A new icon re-deals the contract market for free.

Playtest 2026-10-29: the Demos market kept the old offers after incorporating
new icons. QuestBoard cached its pool until the biome changed or the pool
emptied; the lattice's neighborhood/issuer choice depends on the player's
signature, so a stale pool hid exactly the offers the new icon unlocked.
"""
from pathlib import Path

QB = Path(__file__).resolve().parent.parent / "UI" / "Overlays" / "QuestBoard.gd"


def _src() -> str:
    return QB.read_text(encoding="utf-8")


def test_board_open_redeals_when_signature_changed():
    src = _src()
    act = src.split("func _on_activated(")[1].split("\nfunc ")[0]
    assert "_signature_stamp() != _pool_signature" in act
    assert "_refresh_pool()" in act


def test_every_deal_records_the_signature():
    body = _src().split("func _refresh_pool(")[1].split("\nfunc ")[0]
    assert "_pool_signature = _signature_stamp()" in body


def test_stamp_counts_known_and_incorporated_icons():
    body = _src().split("func _signature_stamp(")[1].split("\nfunc ")[0]
    assert "known_icons" in body and "incorporated_icons" in body
