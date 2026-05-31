import shutil
import tempfile
import time
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER_ROOT = PROJECT_ROOT / "🍄" / "🎛️"


def _load_rig_client():
    import sys

    if str(RUNNER_ROOT) not in sys.path:
        sys.path.insert(0, str(RUNNER_ROOT))
    from rig_client import RigClient  # noqa: E402

    return RigClient


def _wait_for_story_flag(rig, flag_id: str, *, timeout_s: float = 12.0):
    deadline = time.time() + timeout_s
    turn = 1
    last_row = None
    while time.time() < deadline:
        last_row = rig.run_turn(turn, "story_flags", timeout_s=30.0)
        if last_row.get("ok", False):
            fired = last_row.get("flags_fired", {})
            if isinstance(fired, dict) and flag_id in fired:
                return last_row
        turn += 1
        time.sleep(0.25)
    raise AssertionError(f"timed out waiting for story flag {flag_id}: {last_row}")


def test_first_breath_fires_on_fresh_boot() -> None:
    RigClient = _load_rig_client()
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")

    xdg_root = Path(tempfile.mkdtemp(prefix="sw_pytest_story_boot_"))
    rig = RigClient(xdg=xdg_root, root_from_file=RUNNER_ROOT / "milk_hunt_runner.py")
    rig.clear_rig_files()

    proc = None
    try:
        proc = rig.start_listener(
            load_slot=None,
            scenario_id="new_game_easy",
            allow_resource_injection=True,
            listener_stdout="null",
            rig_log_profile="quiet",
            extra_env={"RIG_QUEUE_POLL_MS": "80"},
        )
        assert RigClient.wait_for_bridge_sentinel(timeout_s=60.0, xdg=rig.xdg_root), "rig listener not ready"

        story_row = _wait_for_story_flag(rig, "first_breath", timeout_s=20.0)
        flags_fired = story_row.get("flags_fired", {})
        assert "first_breath" in flags_fired, story_row
        story_log = story_row.get("story_log", [])
        assert any(str(entry.get("id", "")) == "first_breath" for entry in story_log), story_row

        turn = 99
        berry_row = rig.run_turn(
            turn,
            "consume_berry",
            timeout_s=30.0,
            biome="StarterForest",
            count=1,
            phase_each=3.14159,
        )
        assert berry_row.get("ok", False), berry_row
        story_row = _wait_for_story_flag(rig, "forest_evolving", timeout_s=20.0)
        flags_fired = story_row.get("flags_fired", {})
        assert "forest_evolving" in flags_fired, story_row
        story_log = story_row.get("story_log", [])
        assert any(str(entry.get("id", "")) == "forest_evolving" for entry in story_log), story_row

        for _ in range(4):
            turn += 1
            berry_row = rig.run_turn(
                turn,
                "consume_berry",
                timeout_s=30.0,
                biome="StarterForest",
                count=1,
                phase_each=3.14159,
            )
            assert berry_row.get("ok", False), berry_row

        turn += 1
        story_row = _wait_for_story_flag(rig, "forest_communion", timeout_s=20.0)
        flags_fired = story_row.get("flags_fired", {})
        assert "forest_communion" in flags_fired, story_row

        turn += 1
        offers_row = rig.run_turn(turn, "offer_quests", timeout_s=30.0)
        assert offers_row.get("ok", False), offers_row
        offers = offers_row.get("offers", [])
        assert isinstance(offers, list), offers_row
        assert not any(str(offer.get("source_flag", "")) == "forest_communion" for offer in offers), offers_row

        turn += 1
        village_row = rig.run_turn(
            turn,
            "consume_berry",
            timeout_s=30.0,
            biome="Village",
            count=1,
            phase_each=3.14159,
        )
        assert village_row.get("ok", False), village_row
        story_row = _wait_for_story_flag(rig, "village_stirs", timeout_s=20.0)
        flags_fired = story_row.get("flags_fired", {})
        assert "village_stirs" in flags_fired, story_row
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg_root, ignore_errors=True)
