"""The quest observer's per-tick reads stay O(dim), not O(dim²) Complex loops.

2026-11-12 (hive, to_earnest_7): QuestStateProjectionService.observe_biome runs
on every 10 Hz physics tick. It took the partial trace of every qubit through a
dim² loop that allocated a Complex per entry, and summed coherence the same
way: ~190 ms a tick at dim 64, so physics fell behind and the late game ran at
1 FPS (a bot read it as a hang). Both now read the packed store: 23 FPS on the
same save, same numbers (the probe checks them against the old loops).
"""
import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PROBE = ROOT / "tests" / "marginal_packed_probe.gd"


def test_marginal_and_coherence_read_the_packed_store():
    qc = (ROOT / "Core/QuantumSubstrate/QuantumComputer.gd").read_text(encoding="utf-8")
    marg = qc.split("func get_marginal_density_matrix(", 1)[1].split("\nfunc ", 1)[0]
    assert "density_matrix._to_packed()" in marg
    fsm = (ROOT / "Core/QuantumSubstrate/FactionStateMatcher.gd").read_text(encoding="utf-8")
    coh = fsm.split("static func _calculate_coherence(", 1)[1].split("\nstatic func ", 1)[0]
    assert "mat._to_packed()" in coh


def test_packed_paths_match_the_old_loops():
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH")
    proc = subprocess.run(["godot", "--headless", "--path", ".", "--script", str(PROBE)],
                          cwd=ROOT, capture_output=True, text=True, timeout=240)
    line = next((l for l in proc.stdout.splitlines()
                 if l.strip().startswith("{") and '"marginal-packed"' in l), None)
    assert line, proc.stdout[-2000:] + proc.stderr[-2000:]
    out = json.loads(line)
    assert out["checked"] == 10
    assert out["fails"] == []
