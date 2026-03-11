from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SAVE_STORE = PROJECT_ROOT / "Core" / "GameState" / "SaveStore.gd"


def test_atomic_save_temp_path_keeps_resource_extension() -> None:
    src = SAVE_STORE.read_text(encoding="utf-8")
    assert 'tmp_path = "%s.tmp.%s" % [stem, ext]' in src
    assert 'var tmp_path = path + ".tmp"' in src
