from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
MILK_HUNT_RUNNER = PROJECT_ROOT / "🍄" / "🎛️" / "milk_hunt_runner.py"


def test_runner_uses_policy_snapshot_helper_for_state_reads() -> None:
    src = MILK_HUNT_RUNNER.read_text(encoding="utf-8")
    assert "def _run_policy_snapshot(" in src
    assert '_run_turn(turn, "resource_snapshot"' not in src
    assert '_run_turn(turn, "grid_snapshot"' not in src
    assert '_run_turn(turn, "known_vocab_pairs"' not in src
    assert '_run_turn(turn, "active_quests"' not in src


def test_runner_extractors_support_policy_snapshot_payloads() -> None:
    src = MILK_HUNT_RUNNER.read_text(encoding="utf-8")
    assert 'elif row.get("action") == "policy_snapshot":' in src
    assert 'elif action == "policy_snapshot":' in src
    assert "def _extract_policy_pairs(" in src
    assert "def _extract_policy_biomes(" in src
    assert "def _extract_policy_active_quests(" in src
