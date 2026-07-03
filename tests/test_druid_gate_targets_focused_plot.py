import shutil
import tempfile
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


def _live_z(rig, turn: int, biome: str) -> list:
    row = rig.run_turn(turn, "viz_bloch", timeout_s=30.0, biome=biome)
    return [float(q.get("live_z", 999.0)) for q in row.get("qubits", [])]


def test_druid_hadamard_targets_focused_plot_after_hat_switch() -> None:
    # Bug #9: the natural flow — highlight a plot, THEN switch to the Druid hat,
    # THEN press E (Hadamard) — used to silently no-op. Jumping to the frame layer
    # to pick the hat runs leave_plot_ring(), which clears current_plot_idx, and the
    # gate's _get_selected_positions() returned empty → nothing applied. The fix is a
    # sticky-focus fallback to last_selected_position, so the gate still lands on the
    # register you were looking at. This test drives the real key path and asserts the
    # qubit's live Bloch-z actually moves.
    RigClient = _load_rig_client()
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")

    xdg_root = Path(tempfile.mkdtemp(prefix="sw_pytest_druid_"))
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
            extra_env={"RIG_QUEUE_POLL_MS": "80", "RIG_SKIP_WELCOME": "1"},
        )
        assert RigClient.wait_for_bridge_sentinel(timeout_s=60.0, xdg=rig.xdg_root), "rig listener not ready"

        biome = "StarterForest"
        # Settle, then highlight plot 0 (key 'g') — cursor enters the plot ring.
        rig.run_turn(1, "press_key", timeout_s=30.0, key="f", settle_frames=8)
        rig.run_turn(2, "press_key", timeout_s=30.0, key="g", settle_frames=4)

        z_before = _live_z(rig, 3, biome)
        assert z_before, "no qubits reported for StarterForest"

        # Switch to the Druid hat (key '0'). This clears current_plot_idx via
        # leave_plot_ring — the exact state that used to break the gate.
        rig.run_turn(4, "press_key", timeout_s=30.0, key="0", settle_frames=4)
        inst = rig.run_turn(5, "instrument_state", timeout_s=30.0)
        assert int(inst.get("current_plot_idx", 0)) < 0, \
            "expected hat-select to clear the plot cursor (precondition for the bug)"

        # Hadamard (key 'e'). Minimal settle so we isolate the gate from evolution.
        rig.run_turn(6, "press_key", timeout_s=30.0, key="e", settle_frames=1)
        z_after = _live_z(rig, 7, biome)

        max_delta = max(
            (abs(z_after[i] - z_before[i]) for i in range(min(len(z_before), len(z_after)))),
            default=0.0,
        )
        assert max_delta > 0.1, (
            "Druid Hadamard was a no-op after hat switch: "
            f"z_before={z_before} z_after={z_after} (max|Δz|={max_delta:.4f})"
        )
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg_root, ignore_errors=True)
