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


def _pick_teaching_offer(offers: list[dict]) -> tuple[int, dict]:
    for idx, offer in enumerate(offers):
        if not isinstance(offer, dict):
            continue
        if str(offer.get("reward_north", "")) or str(offer.get("reward_south", "")):
            return idx, offer
    raise AssertionError("no quest offer with a learnable icon reward was found")


def test_quest_reward_survives_path_save_load_roundtrip() -> None:
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")

    xdg_root = Path(tempfile.mkdtemp(prefix="sw_pytest_quest_roundtrip_"))
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

        turn = 1
        offer_row = rig.run_turn(
            turn,
            "offer_quests",
            timeout_s=60.0,
            full=True,
        )
        assert offer_row.get("ok", False), offer_row
        offers = offer_row.get("offers", [])
        assert isinstance(offers, list) and offers, offer_row

        offer_index, offer = _pick_teaching_offer(offers)
        quest_id = int(offer.get("id", -1))
        required_emoji = str(offer.get("resource", ""))
        required_qty = int(offer.get("quantity", 0))

        turn += 1
        accept_row = rig.run_turn(
            turn,
            "accept_offer",
            timeout_s=60.0,
            offer_index=offer_index,
        )
        assert accept_row.get("ok", False), accept_row
        assert int(accept_row.get("quest_id", -1)) == quest_id, accept_row

        if required_emoji and required_qty > 0:
            turn += 1
            add_row = rig.run_turn(
                turn,
                "add_resource",
                timeout_s=60.0,
                emoji=required_emoji,
                amount=required_qty,
            )
            assert add_row.get("ok", False), add_row

        turn += 1
        complete_row = rig.run_turn(
            turn,
            "complete_quest",
            timeout_s=60.0,
            quest_id=quest_id,
        )
        assert complete_row.get("ok", False), complete_row
        rewards = complete_row.get("rewards", {})
        learned_pairs = rewards.get("learned_pairs", [])
        assert isinstance(learned_pairs, list) and learned_pairs, complete_row

        learned_pair = learned_pairs[0]
        north = str(learned_pair.get("north", ""))
        south = str(learned_pair.get("south", ""))
        assert north and south, complete_row

        turn += 1
        icons_row = rig.run_turn(turn, "known_icons", timeout_s=30.0)
        assert icons_row.get("ok", False), icons_row
        icons = icons_row.get("icons", [])
        assert isinstance(icons, list), icons_row
        assert {"north": north, "south": south} in icons, icons_row

        save_path = xdg_root / "quest_roundtrip.tres"
        turn += 1
        save_row = rig.run_turn(
            turn,
            "save_game_path",
            timeout_s=60.0,
            path=str(save_path),
        )
        assert save_row.get("ok", False), save_row
        assert bool(save_row.get("saved", False)), save_row

        turn += 1
        load_row = rig.run_turn(
            turn,
            "load_game_path",
            timeout_s=60.0,
            path=str(save_path),
        )
        assert load_row.get("ok", False), load_row
        assert bool(load_row.get("loaded", False)), load_row

        turn += 1
        icons_after_load = rig.run_turn(turn, "known_icons", timeout_s=30.0)
        assert icons_after_load.get("ok", False), icons_after_load
        assert {"north": north, "south": south} in icons_after_load.get("icons", []), icons_after_load
    finally:
        RigClient.terminate_listener(proc, timeout_s=5.0)
        shutil.rmtree(xdg_root, ignore_errors=True)
