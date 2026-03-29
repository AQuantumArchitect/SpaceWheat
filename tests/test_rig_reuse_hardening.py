from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RIG_LISTENER = PROJECT_ROOT / "Tests" / "rig_listener.gd"
RIG_CLIENT = PROJECT_ROOT / "🍄" / "🎛️" / "rig_client.py"


def test_rig_listener_primes_queue_cursor_on_ready() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert "func _prime_queue_cursor_to_end()" in src
    assert "_prime_queue_cursor_to_end()" in src


def test_rig_listener_echoes_request_id_in_results() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert 'var request_id = str(cmd.get("request_id", ""))' in src
    assert 'result["request_id"] = request_id' in src


def test_rig_client_turn_roundtrip_uses_request_id() -> None:
    src = RIG_CLIENT.read_text(encoding="utf-8")
    assert 'payload["request_id"] = request_id' in src
    assert "request_id=request_id" in src
    assert "self._results_by_request" in src


def test_rig_listener_routes_read_actions_through_policy_snapshot() -> None:
    src = RIG_LISTENER.read_text(encoding="utf-8")
    assert '_snapshot_service.get_resource_snapshot()' in src
    assert '_snapshot_service.get_grid_snapshot()' in src
    assert '_snapshot_service.get_active_quests()' in src
    assert '_snapshot_service.get_known_vocab_pairs()' in src
    assert 'result["resources"] = _instrument.get_resource_snapshot()' not in src
    assert 'result["grid"] = _instrument.get_grid_snapshot()' not in src
