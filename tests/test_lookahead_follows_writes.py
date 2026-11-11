"""The lookahead follows every write to ρ, and nobody invalidates by hand.

The batcher precomputes ~13 phrames of evolution and loads them into ρ one per
phrame. Until 2026-11-11 anything else that wrote ρ had to remember to drop those
frames, and most didn't: the player's key path did (QuantumInstrumentInput
invalidated after each verb), a strike or gate from a rig driver, ReelRunner or
bot lasted ~2 frames, and a standing Merchant contract never accumulated — Farm
wrote one tick of pump, the next buffered frame wrote it back.

Now every write stamps QuantumComputer.state_epoch, and the batcher evolves the
live ρ (instead of replaying a stale frame) whenever the epoch has moved past the
one its frames were forecast from. The game layer holds no invalidation at all.

- tests/rho_write_epoch_check.gd: every QuantumComputer writer stamps the epoch.
- tests/strike_collapse_probe.gd: the real game, lookahead ON, written five ways
  (key strike, key Druid spin, direct strike, GateInjector gate, a raw gate on
  the QC, a standing pump). Each write must hold; the pump must compound across ticks.
- Source pins: the input layer, GateInjector and the verb handlers don't touch the
  batcher; any in-place ρ write outside QuantumComputer stamps the epoch.
"""
import json
import os
import re
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/strike_collapse_probe.gd"
EPOCH_CHECK = "tests/rho_write_epoch_check.gd"
CHECK_FRAMES = (3, 5, 10)


def _godot_env(tmp):
    env = dict(os.environ)
    for k in ("RIG_DISABLE_LOOKAHEAD", "SW_DISABLE_LOOKAHEAD"):
        env.pop(k, None)                    # the player default: lookahead on
    env["APPDATA"] = str(tmp)               # Windows: user:// lives under %APPDATA%
    env["XDG_DATA_HOME"] = str(tmp)         # Linux / macOS
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    env["RIG_UNLOCK_ALL"] = "1"             # Druid Spin + is locked for Act 0
    return env


def _run(script, tmp, timeout):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    result = subprocess.run(["godot", "--headless", "--script", script], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8",
                            timeout=timeout, env=_godot_env(tmp))
    out = result.stdout + result.stderr
    assert result.returncode == 0, f"{script} failed:\n{out[-3000:]}"
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    return result.stdout


@pytest.fixture(scope="module")
def traces(tmp_path_factory):
    out = _run(PROBE, tmp_path_factory.mktemp("strike_probe"), 300)
    rows = [json.loads(l[len("STRIKE_TRACE "):]) for l in out.splitlines()
            if l.startswith("STRIKE_TRACE ")]
    return {r["path"]: r for r in rows}


def test_every_qc_writer_stamps_the_epoch(tmp_path):
    out = _run(EPOCH_CHECK, tmp_path, 120)
    rows = [l.split(" ", 1)[1] for l in out.splitlines() if l.startswith("EPOCH ")]
    assert len(rows) >= 15, f"epoch check printed {len(rows)} writers:\n{out[-2000:]}"
    missing = [r for r in rows if r.endswith(" MISSING")]
    assert not missing, "these writes leave state_epoch where it was, so the " \
        "next buffered frame would overwrite them:\n" + "\n".join(missing)


@pytest.mark.parametrize("path", ["keys", "druid", "direct", "gate", "raw"])
def test_write_survives_the_lookahead(traces, path):
    assert path in traces, f"no {path} trace"
    t = traces[path]
    assert t["lookahead"] is True, "the probe must run with lookahead on"
    expect, before = float(t["expect"]), float(t["before"])
    if abs(expect - before) < 0.02:
        pytest.skip(f"{path}: the write barely moved the register ({before:.3f} → {expect:.3f})")
    frames = dict((int(f), float(p)) for f, p in t["trace"])
    assert abs(frames[0] - expect) < 1e-3, f"{path}: the write itself did not land: {frames[0]} vs {expect}"
    for f in CHECK_FRAMES:
        p = frames[f]
        assert abs(p - expect) < abs(p - before), (
            f"{path}: at frame {f} the register reads {p:.3f}, back toward the overwritten "
            f"{before:.3f} instead of the written {expect:.3f} (stale lookahead frame)")


def test_standing_pump_compounds_with_lookahead_on(traces):
    """Rate 20 moves 86% of the south population per tick. One tick that sticks
    leaves ~14% of it; before 2026-11-11 that was all that ever stuck (the pump
    plateaued at ~0.96 from 0.72). Compounding over 40 ticks leaves ~nothing."""
    t = traces["pump"]
    assert t["lookahead"] is True
    frames = dict((int(f), float(p)) for f, p in t["trace"])
    south0, south40 = 1.0 - frames[0], 1.0 - frames[40]
    assert south0 > 0.05, f"pump register started at p_north {frames[0]:.3f}; nothing to pump"
    assert south40 < 0.02 * south0, (
        f"standing pump did not compound: p_north {frames[0]:.3f} → {frames[40]:.3f} over 40 "
        f"ticks; the buffered frames are overwriting the contract's writes")


# ---------------------------------------------------------------------------
# Source pins: the simulation owns invalidation, the game layer doesn't.
# ---------------------------------------------------------------------------

BATCHER_CALLS = re.compile(r"invalidate_biome_buffer|decimate_biome_buffer|reset_stride_carry"
                           r"|signal_user_action|invalidate_after_write|BUFFER_INVALIDATING")


@pytest.mark.parametrize("rel", [
    "UI/Core/QuantumInstrumentInput.gd",
    "Core/QuantumSubstrate/GateInjector.gd",
    "Core/Actions/ProbeActions.gd",
    "Core/Instrumentation/Handlers/LindbladHandler.gd",
    "Core/Instrumentation/QuantumInstrument.gd",
])
def test_game_layer_does_not_invalidate_the_lookahead(rel):
    hits = [f"{rel}:{n}: {l.strip()}" for n, l in enumerate(read_source(rel).splitlines(), 1)
            if BATCHER_CALLS.search(l) and not l.lstrip().startswith("#")]
    assert not hits, "the batcher notices writes to ρ itself; this code must not " \
        "manage its buffers:\n" + "\n".join(hits)


def test_batcher_checks_the_epoch_before_every_frame():
    b = read_source("Core/Environment/BiomeEvolutionBatcher.gd")
    advance = b.split("func _advance_all_buffers(")[1].split("\nfunc ")[0]
    assert "_forecast_is_stale(" in advance and "_evolve_live_phrame(" in advance
    apply = b.split("func _apply_buffered_step(")[1].split("\nfunc ")[0]
    assert apply.index("_forecast_is_stale(") < apply.index("load_packed_state(")
    assert "_note_forecast_from_live(" in apply.split("load_packed_state(")[1]
    queue = b.split("func _queue_adaptive_packet(")[1].split("\nfunc ")[0]
    assert '"generations": _snapshot_buffer_generations()' in queue, \
        "packets must carry the generation from when their ρs were captured"


def test_timing_setters_tell_the_batcher():
    base = read_source("Core/Environment/BiomeBase.gd")
    dt = base.split("var max_evolution_dt")[1].split("\nvar ")[0]
    assert "note_resolution_changed(" in dt
    stride = base.split("var observation_stride")[1].split("\nvar ")[0]
    assert "note_stride_changed(" in stride


IN_PLACE_RHO_WRITE = re.compile(r"density_matrix\.(set_element|_from_packed|renormalize_trace)\(|"
                                r"density_matrix\._packed_cache\s*(\[.*\])?\s*=[^=]")


def test_in_place_rho_writes_outside_the_qc_stamp_the_epoch():
    offenders = []
    for d in ("Core", "UI", "🍄"):
        for f in (ROOT / d).rglob("*.gd"):
            rel = f.relative_to(ROOT).as_posix()
            if rel == "Core/QuantumSubstrate/QuantumComputer.gd":
                continue
            lines = f.read_text(encoding="utf-8").splitlines()
            for n, line in enumerate(lines):
                if IN_PLACE_RHO_WRITE.search(line) and not line.lstrip().startswith("#"):
                    window = "\n".join(lines[n:n + 4])
                    if "mark_state_written()" not in window:
                        offenders.append(f"{rel}:{n + 1}: {line.strip()}")
    assert not offenders, "in-place writes to ρ must call qc.mark_state_written() " \
        "(or go through a QuantumComputer method):\n" + "\n".join(offenders)
