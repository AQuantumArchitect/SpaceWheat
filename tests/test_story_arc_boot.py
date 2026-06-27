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


def test_story_flags_fire_from_action_not_boot() -> None:
    # Principle: story flags fire as a RESULT of human action, never at a fresh boot.
    # Run on the SHIPPED DEFAULT scenario (demos_normal), which boots with a single starter
    # icon (🌾/👥, signature size 1). first_breath gates on signature_size_gte 1.5 width 0.4,
    # which under soft geometry crosses the 0.85 fire threshold at signature size 2 — so it
    # must NOT fire at boot (sig 1) and only fires once the player incorporates their first
    # icon (sig 1→2). (new_game_easy hands you 2 icons up front, so it legitimately fires at
    # its boot — that scenario can't test the invariant.) The forest beats below then fire
    # from a real action (consuming berries).
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
            scenario_id="demos_normal",
            allow_resource_injection=True,
            listener_stdout="null",
            rig_log_profile="quiet",
            extra_env={"RIG_QUEUE_POLL_MS": "80"},
        )
        assert RigClient.wait_for_bridge_sentinel(timeout_s=60.0, xdg=rig.xdg_root), "rig listener not ready"

        # No action taken yet → first_breath must NOT have fired at boot.
        boot_row = rig.run_turn(1, "story_flags", timeout_s=30.0)
        assert boot_row.get("ok", False), boot_row
        assert "first_breath" not in boot_row.get("flags_fired", {}), boot_row

        # Positive half: the flag fires FROM the action. forest_evolving gates on
        # biome_evolving(StarterForest) + berry_consumed_count_gte 1, which under soft
        # geometry needs ~2.3 berries to cross the 0.85 fire threshold — so consume a few.
        # (The full forest→village→empire chain is covered end-to-end by act3_5_drive.py.)
        berry_row = rig.run_turn(
            99,
            "consume_berry",
            timeout_s=30.0,
            biome="StarterForest",
            count=4,
            phase_each=3.14159,
        )
        assert berry_row.get("ok", False), berry_row
        story_row = _wait_for_story_flag(rig, "forest_evolving", timeout_s=20.0)
        flags_fired = story_row.get("flags_fired", {})
        assert "forest_evolving" in flags_fired, story_row
        story_log = story_row.get("story_log", [])
        assert any(str(entry.get("id", "")) == "forest_evolving" for entry in story_log), story_row
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg_root, ignore_errors=True)
