"""Auto-promote ladder: earned banks only, mill alias, no fork doors."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HIVE = ROOT / "🍄" / "🧪" / "hive"
sys.path.insert(0, str(HIVE))
import promote  # noqa: E402


def test_ladder_has_act0_mill_plant_and_open_band():
    ladder = promote.load_ladder()
    ids = [r["id"] for r in ladder]
    assert ids[0] == "act0_fresh"
    assert "village_stirs" in ids
    assert "new_voices" in ids
    assert "woodlot_door" in ids
    assert "village_identity" in ids
    assert "edge_of_the_enclave" in ids
    assert not any(i.startswith("village_path_") for i in ids)
    mill = next(r for r in ladder if r["id"] == "village_stirs")
    assert "mill_apprentice" in mill["aliases"]
    ident = next(r for r in ladder if r["id"] == "village_identity")
    assert ident["band"] == "open"


def test_mill_alias_and_plant_next():
    ladder = promote.load_ladder()
    assert promote.canonical("mill_apprentice", ladder) == "village_stirs"
    nxt = promote.next_of("mill_apprentice", ladder)
    assert nxt is not None
    assert nxt["id"] == "new_voices"


def test_wave17_seed_banks_exist():
    for spec in promote.SEED.values():
        assert promote.checkpoint_exists(spec["checkpoint"]), spec["checkpoint"]
