"""Golden-vector regression for QuantumEvolutionEngine (kernel extraction, packet B).

Runs tests/kernel_golden_dump.gd against the CURRENT build of the native DLL and
compares with the golden captured from the unmodified build
(tests/fixtures/kernel_golden/evolution_engine.json) at an absolute tolerance of
1e-10, so other platforms and compilers pass. On the same host and compiler the
rebuilt DLL should match bit for bit; check that with --exact:

    godot --headless --path . --script tests/kernel_golden_dump.gd -- --out=/tmp/cand.json
    python tests/kernel_golden_compare.py tests/fixtures/kernel_golden/evolution_engine.json /tmp/cand.json --exact

Skips (never fails) when godot is not on PATH.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
DUMP = ROOT / "tests" / "kernel_golden_dump.gd"
GOLDEN = ROOT / "tests" / "fixtures" / "kernel_golden" / "evolution_engine.json"
COMPARE = ROOT / "tests" / "kernel_golden_compare.py"

sys.path.insert(0, str(ROOT / "tests"))
import kernel_golden_compare as kgc  # noqa: E402


@pytest.fixture(scope="module")
def candidate(tmp_path_factory) -> Path:
    godot = shutil.which("godot")
    if godot is None:
        pytest.skip("godot not on PATH - cannot dump the native engine")
    out = tmp_path_factory.mktemp("kernel_golden") / "candidate.json"
    proc = subprocess.run(
        [godot, "--headless", "--path", str(ROOT), "--script", str(DUMP), "--", f"--out={out.as_posix()}"],
        cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=300,
    )
    assert proc.returncode == 0, (proc.stdout + proc.stderr)[-3000:]
    assert out.exists(), "dump exited 0 but wrote no file:\n" + (proc.stdout + proc.stderr)[-3000:]
    return out


def test_golden_file_is_committed():
    assert GOLDEN.exists(), "golden missing: regenerate from an unmodified build"
    assert len(json.loads(GOLDEN.read_text(encoding="utf-8"))) > 1000


def test_engine_matches_golden_within_tolerance(candidate):
    golden = json.loads(GOLDEN.read_text(encoding="utf-8"))
    cand = json.loads(candidate.read_text(encoding="utf-8"))
    n, problems, max_diff = kgc.compare(golden, cand, exact=False, tol=1e-10)
    report = "\n".join(f"{k}: {m}" for _, k, m in sorted(problems, key=lambda p: -p[0])[:20])
    assert not problems, f"{len(problems)} of {n} records differ (max abs diff {max_diff:.3e}):\n{report}"
