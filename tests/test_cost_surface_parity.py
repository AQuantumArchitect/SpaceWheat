import shutil
import sys
import tempfile
from pathlib import Path

import pytest


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RUNNER_ROOT = PROJECT_ROOT / "🍄" / "🎛️"
if str(RUNNER_ROOT) not in sys.path:
    sys.path.insert(0, str(RUNNER_ROOT))

from rig_client import RigClient  # noqa: E402


def test_action_cost_surface_parity() -> None:
    """Validate rig-exposed action costs match live balance snapshot costs."""
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")

    xdg_root = Path(tempfile.mkdtemp(prefix="sw_pytest_rig_"))
    rig = RigClient(xdg=xdg_root, root_from_file=RUNNER_ROOT / "milk_hunt_runner.py")
    rig.clear_rig_files()

    proc = None
    try:
        proc = rig.start_listener(
            load_slot=None,
            scenario_id="default",
            allow_resource_injection=False,
            listener_stdout="null",
            rig_log_profile="quiet",
            extra_env={"RIG_QUEUE_POLL_MS": "80"},
        )
        assert RigClient.wait_for_bridge_sentinel(timeout_s=60.0, xdg=rig.xdg_root), "rig listener not ready"

        turn = 1
        balance = rig.run_turn(turn, "balance_snapshot", timeout_s=120.0)
        assert balance.get("ok", False), balance
        action_costs = (
            balance.get("balance", {}).get("action_costs", {})
            if isinstance(balance.get("balance", {}), dict)
            else {}
        )

        checks = [
            ("quest_reroll", {}, True),
            ("quest_lock", {}, True),
            ("inject_vocabulary", {"south_emoji": "👥"}, False),  # dynamic cost depends on context
        ]
        for action_name, context, compare_balance_snapshot in checks:
            turn += 1
            cost_row = rig.run_turn(
                turn,
                "action_cost",
                timeout_s=30.0,
                name=action_name,
                context=context,
            )
            assert cost_row.get("ok", False), cost_row
            cost = cost_row.get("cost", {})
            assert isinstance(cost, dict), cost_row

            if compare_balance_snapshot:
                assert cost == action_costs.get(action_name, {}), {
                    "action": action_name,
                    "cost_row": cost,
                    "balance_snapshot": action_costs.get(action_name, {}),
                }

            turn += 1
            preflight_row = rig.run_turn(
                turn,
                "action_preflight",
                timeout_s=30.0,
                name=action_name,
                context=context,
            )
            assert preflight_row.get("ok", False), preflight_row
            preflight = preflight_row.get("preflight", {})
            assert isinstance(preflight, dict), preflight_row
            assert preflight.get("cost", {}) == cost
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg_root, ignore_errors=True)
