"""Per-biome substep cap and parallel biome stepping in the native lookahead engine.

Every biome in a batched native call shares the call's dt (the shared clock,
PhysicsConfig.PHRAME_SIM_DT). Since 2026-11-14 each biome caps its integrator
substep at its own resolution (set_biome_max_dt), and the biomes of one call are
stepped on several threads with results bit-identical to one at a time.

Before: a call took one max_dt for every biome, the finest in the packet, so a
single finely resolved biome made every open biome in its packet take 16 RK4
substeps per frame (979 ms vs 84 ms for 8 dim-32 biomes x 21 frames, measured on
the Windows host); and biomes were stepped one after another.

tests/native_parallel_check.gd drives the engine directly. A native binary built
before this change (the committed Linux .so until it is rebuilt) has neither
method; the check then only benchmarks, and this test skips.
"""
import json
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

CHECK = "tests/native_parallel_check.gd"


@pytest.fixture(scope="module")
def check_output():
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    r = subprocess.run(["godot", "--headless", "--script", CHECK], cwd=ROOT,
                       capture_output=True, text=True, encoding="utf-8", errors="replace",
                       timeout=600)
    out = r.stdout + r.stderr
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    return r.returncode, out


def test_native_engine_caps_and_threads_per_biome(check_output):
    code, out = check_output
    bench = [json.loads(l[len("NATIVE_BENCH "):]) for l in out.splitlines() if l.startswith("NATIVE_BENCH ")]
    assert bench, out[-3000:]
    if bench[-1]["binary"] == "old":
        pytest.skip("this native binary predates set_biome_max_dt / set_max_threads (rebuild native/)")
    fails = [l.strip() for l in out.splitlines() if "FAIL" in l]
    assert code == 0 and not fails, "native_parallel_check failed:\n" + "\n".join(fails) + "\n" + out[-2000:]
    cases = bench[-1]["cases"]
    # One fine biome no longer drags the packet: own caps beat the packet minimum.
    assert cases["one_thread_own_caps"] < cases["one_thread_packet_min_cap"]


def test_batched_calls_hand_the_engine_each_biomes_cap():
    b = read_source("Core/Environment/BiomeEvolutionBatcher.gd")
    for fn in ("_prime_all_biomes_native(", "_process_next_packet_async(", "_compute_packet("):
        body = b.split("func " + fn)[1].split("\nfunc ")[0]
        sync_at = body.find("_sync_biome_max_dts()")
        call_at = min(i for i in (body.find("evolve_all_lookahead("), body.find("submit_lookahead_job(")) if i >= 0)
        assert 0 <= sync_at < call_at, f"{fn} must send each biome's cap before its native call"


def test_engine_flags_read_by_workers_are_atomic():
    h = read_source("native/src/multi_biome_lookahead_engine.h")
    for name in ("m_enable_mi", "m_enable_force", "m_pacing_delay_ms", "m_max_threads"):
        assert f"std::atomic" in h.split(name)[0].splitlines()[-1], \
            f"{name} is read by the stepping threads while its setter can run: make it atomic"
