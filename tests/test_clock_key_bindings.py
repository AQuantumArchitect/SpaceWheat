"""The -/= clock keys are live; the binding registry (source of in-game help)
must not call them reserved. See issue #144."""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REGISTRY = ROOT / "UI/Core/InputBindingRegistry.gd"
GRAN = ROOT / "Core/Utilities/GranularityController.gd"
BAD = ("reserved", "pending", "stub")


def _desc(key: str) -> str:
    text = REGISTRY.read_text(encoding="utf-8")
    m = re.search(r'\{"key": "%s",[^}]*"description": "([^"]*)"' % re.escape(key), text)
    assert m, f"GLOBAL_BINDINGS has no entry for {key!r}"
    return m.group(1)


def test_clock_keys_not_described_as_reserved():
    for key in ("-", "="):
        d = _desc(key).lower()
        assert not any(w in d for w in BAD), f"{key!r}: {d}"
        assert "clock" in d


def test_resolution_keys_stay_dt():
    assert "dt" in _desc("Shift+-") and "dt" in _desc("Shift+=")


def test_documented_cap_matches_controller():
    cap = re.search(r"MAX_STRIDE: int = (\d+)", GRAN.read_text(encoding="utf-8")).group(1)
    assert f"×{cap}" in _desc("=")
