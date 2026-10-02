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


def test_furthest_live_skips_holes():
    ladder = promote.load_ladder()
    fired = {
        "village_stirs", "new_voices", "woodlot_door", "woodlot_contact",
        "lumber_flows", "spring_door", "spring_contact", "spring_connects",
        "spring_wakes", "pond_depths", "pond_breathes", "first_breath",
        "spiral_breaks", "forest_evolving", "forest_listener",
    }
    cleared, live = promote.furthest_live(fired, ladder)
    assert "forest_listener" in cleared
    assert "woodlot_wakes" not in cleared
    assert live["id"] == "forest_listener"


def test_furthest_live_open_door_is_furthest_fired():
    """w50: mill_wakes minted after Druid's Loop. Act 5 loop flags can
    fire in parallel; Hold Commerce is still the spine-order live door."""
    ladder = promote.load_ladder()
    fired = {
        "village_stirs", "new_voices", "woodlot_door", "woodlot_contact",
        "lumber_flows", "spring_door", "spring_contact", "spring_connects",
        "spring_wakes", "pond_depths", "pond_breathes", "first_breath",
        "spiral_breaks", "forest_evolving", "forest_listener",
        "forest_communion", "loop_remembers", "mill_wakes",
        "second_loop", "the_knot", "loop_came_home",
    }
    _cleared, live = promote.furthest_live(fired, ladder)
    assert live["id"] == "mill_wakes"


def test_newest_bank_prefers_more_flags(tmp_path, monkeypatch):
    """w160-r2: later wall with more flags must beat an older clear checkpoint."""
    monkeypatch.setattr(promote, "CKPT", tmp_path)
    (tmp_path / "runner_the_teaching_clear.json").write_text(
        '{"flags_fired":["new_voices","spring_door"]}\n', encoding="utf-8")
    (tmp_path / "runner_the_teaching_clear.tres").write_text(
        "story_flags_fired = {}\n", encoding="utf-8")
    (tmp_path / "runner_spring_wakes_wall.json").write_text(
        '{"flags_fired":["new_voices","spring_door","spring_wakes","woodlot_door"]}\n',
        encoding="utf-8")
    (tmp_path / "runner_spring_wakes_wall.tres").write_text(
        "story_flags_fired = {}\n", encoding="utf-8")
    assert promote.newest_bank("runner", "runner_the_teaching_clear") == (
        "runner_spring_wakes_wall"
    )


def test_comma_concatenated_banks_pick_last_existing(tmp_path, monkeypatch):
    """w161-r1 recap banked three runner clears as one comma list."""
    monkeypatch.setattr(promote, "CKPT", tmp_path)
    (tmp_path / "runner_pond_breathes_clear.json").write_text(
        '{"flags_fired":["pond_breathes"]}\n', encoding="utf-8")
    (tmp_path / "runner_pond_breathes_clear.tres").write_text(
        "story_flags_fired = {}\n", encoding="utf-8")
    blob = "runner_spring_wakes_clear, runner_pond_depths_clear, runner_pond_breathes_clear"
    assert promote._first_existing_bank(blob) == "runner_pond_breathes_clear"


def test_empty_json_sidecar_falls_through_to_tres(tmp_path, monkeypatch):
    """Campaign-124 banks wrote flags_fired: [] while the .tres still had the dict."""
    monkeypatch.setattr(promote, "CKPT", tmp_path)
    (tmp_path / "x.json").write_text(
        '{"name":"x","flags_fired":[]}\n', encoding="utf-8")
    (tmp_path / "x.tres").write_text(
        'story_flags_fired = {\n"lantern_door": 1\n}\n', encoding="utf-8")
    assert promote.checkpoint_flags("x") == ["lantern_door"]


def test_latest_banks_have_forest_listener():
    for stem in (
        "literalist_first_breath_wall",
        "earnest_spring_wakes_wall",
        "literalist_pond_breathes_clear",
    ):
        flags = set(promote.checkpoint_flags(stem))
        assert "forest_listener" in flags, stem
        assert "forest_communion" not in flags, stem
