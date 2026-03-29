from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_serializer_reconciles_known_pairs_on_load_and_capture() -> None:
    src = _read("Core/GameState/GameStateSerializer.gd")
    assert "func _resolve_known_pairs_from_state(state: GameState) -> Array:" in src
    assert "func _resolve_known_pairs_for_capture(farm: Node) -> Array:" in src
    assert "restored_known_pairs = _resolve_known_pairs_from_state(state)" in src
    assert 'farm.set_known_pairs(restored_known_pairs, not has_player_vocab_data, false)' in src
    assert 'farm.set_known_pairs(vocab_pairs, false, false)' in src
    assert "state.known_pairs = _resolve_known_pairs_for_capture(farm)" in src

