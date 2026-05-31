from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def test_serializer_reconciles_known_icons_on_load_and_capture() -> None:
    save_store = _read("Core/GameState/SaveStore.gd")
    src = _read("Core/GameState/GameStateSerializer.gd")
    assert "func _extract_known_icons_from_resource_text(path: String) -> Array:" in save_store
    assert "state.known_icons.size() <= 1" in save_store
    assert "state.known_icons = recovered_known_icons" in save_store
    assert "func _resolve_known_icons_from_state(state: GameState) -> Array:" in src
    assert "func _resolve_known_icons_for_capture(farm: Node) -> Array:" in src
    assert "restored_known_icons = _resolve_known_icons_from_state(state)" in src
    assert "farm.set_known_icons(restored_known_icons)" in src
    assert "state.known_icons = _resolve_known_icons_for_capture(farm)" in src
