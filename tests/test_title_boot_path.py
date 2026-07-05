import shutil
import sys
import tempfile
import time
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER_ROOT = PROJECT_ROOT / "🍄" / "🎛️"
if str(RUNNER_ROOT) not in sys.path:
    sys.path.insert(0, str(RUNNER_ROOT))

from rig_client import RigClient  # noqa: E402


def test_title_menu_restart_path_reaches_first_breath() -> None:
    # The player's real boot is title → F (menu/start) → welcome → any-key dismiss →
    # gameplay. The rig's default lane skips all of that (pending/auto boot), so bugs
    # that live only on the player path — the welcome modal trapping Q/E/R was one —
    # evade every other test. This walks the shipped path end-to-end and proves the
    # sole progression verb (Icon incorporate) still fires first_breath on it.
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")

    xdg_root = Path(tempfile.mkdtemp(prefix="sw_pytest_title_path_"))
    rig = RigClient(xdg=xdg_root, root_from_file=RUNNER_ROOT / "milk_hunt_runner.py")
    rig.clear_rig_files()

    proc = None
    try:
        proc = rig.start_listener(
            load_slot=None,
            scenario_id="demos_normal",  # the shipped default — what a real player boots
            allow_resource_injection=True,
            listener_stdout="null",
            rig_log_profile="quiet",
            extra_env={
                "RIG_QUEUE_POLL_MS": "80",
                "RIG_DRIVE_TITLE": "1",   # leave the title up; we drive the player path
                "RIG_SKIP_WELCOME": "0",  # the welcome modal must actually appear
            },
        )
        assert RigClient.wait_for_bridge_sentinel(timeout_s=60.0, xdg=rig.xdg_root), "rig listener not ready"

        turn = [1]

        def step(action, **kw):
            turn[0] += 1
            return rig.run_turn(turn[0], action, timeout_s=60.0, **kw)

        def press(key, frames=4):
            step("press_key", key=key, settle_frames=frames)

        # 1. Title → start. keys=["F"] is the player's first F on the title screen;
        #    start_from_title then guarantees the game booted (same entrypoint the menu
        #    uses) and resolves farm + shell — exactly the restart lane.
        started = step("start_from_title", keys=["F"], settle_frames=10)
        info = started.get("start_from_title", {})
        assert info.get("farm") and info.get("shell") and info.get("game_root"), started

        # 2. Welcome-modal regression (the input trap): ANY key must dismiss it, and the
        #    key row must act afterwards. "5" both dismisses and selects the Icon hat.
        press("5", frames=8)
        frame_row = step("confirm_state")
        assert frame_row.get("current_frame") in ("icon", "ace"), frame_row
        if frame_row.get("current_frame") != "icon":
            press("5", frames=8)  # first press was eaten by the welcome — dismiss counts, retry selects
            frame_row = step("confirm_state")
            assert frame_row.get("current_frame") == "icon", frame_row

        # 3. The progression loop on the player path: Druid-excite plot 0, Icon-track,
        #    ripen under H, incorporate. Signature growth is what first_breath gates on.
        press("0", frames=2)
        press("G", frames=3)
        press("E", frames=3)  # Hadamard — off the pole so the walk traces solid angle
        press("5", frames=2)
        press("G", frames=3)
        # Plot selection follows the cursor's biome — read it live rather than assuming.
        live_biome = str(step("instrument_state").get("current_biome", ""))
        assert live_biome, "no biome under the cursor after plot select"
        press("F", frames=3)  # Track
        tracked = [bool(q.get("tracked")) for q in step("berry_state", biome=live_biome).get("qubits", [])]
        assert tracked and tracked[0], (
            "Icon-F did not start Berry tracking on the title path (biome %s)" % live_biome
        )

        step("time_skip", phrames=900)
        press("G", frames=3)
        press("R", frames=4)  # Incorporate

        deadline = time.time() + 20.0
        fired = {}
        while time.time() < deadline:
            row = step("story_flags")
            fired = row.get("flags_fired", {}) if row.get("ok", False) else {}
            if "first_breath" in fired:
                break
            time.sleep(0.25)
        assert "first_breath" in fired, f"first_breath did not fire on the title path: {fired}"
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg_root, ignore_errors=True)
