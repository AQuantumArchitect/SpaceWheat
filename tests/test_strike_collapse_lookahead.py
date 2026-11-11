"""A write to ρ outside the batcher survives the lookahead (2026-11-10).

The batcher precomputes ~13 phrames of evolution and loads them into ρ one per
phrame. Anything that writes ρ directly (a strike's collapse, a gate, a Spark
jolt) must drop those stale frames, or the next buffered step restores the state
from before the write. QuantumInstrumentInput did that for player actions, but
the write sites themselves did not: GateInjector only scheduled a refill, and
ProbeActions/LindbladHandler did nothing. So a strike made by a rig driver, the
gallery ReelRunner or any direct caller lasted about two frames, and a gate
vanished. The rig defaults to lookahead OFF, which hid it from rig tests.

tests/strike_collapse_probe.gd boots the real game headless with lookahead ON
and writes ρ three ways: the player's key path (8 G F R), a direct
QuantumInstrument.action_measure, and an X gate through GateInjector. Each written
register must stay closer to what was written than to what it replaced.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/strike_collapse_probe.gd"
CHECK_FRAMES = (3, 5, 10)


@pytest.fixture(scope="module")
def traces(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("strike_probe")
    env = dict(os.environ)
    for k in ("RIG_DISABLE_LOOKAHEAD", "SW_DISABLE_LOOKAHEAD"):
        env.pop(k, None)                    # the player default: lookahead on
    env["APPDATA"] = str(tmp)               # Windows: user:// lives under %APPDATA%
    env["XDG_DATA_HOME"] = str(tmp)         # Linux / macOS
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    result = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8", timeout=300, env=env)
    tail = (result.stdout + result.stderr)[-3000:]
    assert result.returncode == 0, f"probe failed:\n{tail}"
    assert "SCRIPT ERROR" not in result.stdout + result.stderr, tail
    rows = [json.loads(l[len("STRIKE_TRACE "):]) for l in result.stdout.splitlines()
            if l.startswith("STRIKE_TRACE ")]
    return {r["path"]: r for r in rows}


@pytest.mark.parametrize("path", ["keys", "direct", "gate"])
def test_write_survives_the_lookahead(traces, path):
    assert path in traces, f"no {path} trace"
    t = traces[path]
    assert t["lookahead"] is True, "the probe must run with lookahead on"
    expect, before = float(t["expect"]), float(t["before"])
    if abs(expect - before) < 0.02:
        pytest.skip(f"{path}: the write barely moved the register ({before:.3f} → {expect:.3f})")
    frames = dict((int(f), float(p)) for f, p in t["trace"])
    assert abs(frames[0] - expect) < 1e-6, f"{path}: the write itself did not land: {frames[0]} vs {expect}"
    for f in CHECK_FRAMES:
        p = frames[f]
        assert abs(p - expect) < abs(p - before), (
            f"{path}: at frame {f} the register reads {p:.3f}, back toward the overwritten "
            f"{before:.3f} instead of the written {expect:.3f} (stale lookahead frame)")


def test_write_sites_invalidate_the_lookahead():
    injector = read_source("Core/QuantumSubstrate/GateInjector.gd")
    body = injector.split("static func invalidate_after_write(")[1].split("\nstatic func ")[0]
    assert "invalidate_biome_buffer(" in body, "must drop the stale frames, not just schedule a refill"
    assert "for touched_biome in touched:" in injector, "a batch invalidates every biome it wrote"
    probe = read_source("Core/Actions/ProbeActions.gd")
    measure = probe.split("static func action_measure(")[1].split("\nstatic func ")[0]
    assert "GateInjector.invalidate_after_write(biome, farm)" in measure
    lindblad = read_source("Core/Instrumentation/Handlers/LindbladHandler.gd")
    for fn in ("lindblad_drive", "lindblad_decay"):
        body = lindblad.split(f"static func {fn}(")[1].split("\nstatic func ")[0]
        assert "GateInjector.invalidate_after_write(" in body, fn
