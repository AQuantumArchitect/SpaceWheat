"""Every biome runs on one clock, in both lanes (owner ruling 2026-11-13).

"It should be a shared clock, because we want to find particular states." A
biome's place in its evolution must depend only on how long it has run (and its
stride), never on which biomes its refill packet carried, or which lane ran it.

Before 2026-11-13 (docs/history/2026-11-12-lookahead-time-map.md):
- a lookahead packet ran every biome in it at the smallest max_evolution_dt among
  them, so one write to Village (dt 1.0) split its refills off and it ran 54x its
  neighbours;
- the rig lane ran 0.1 sim-s per tick, the player lane 0.02 (5x apart);
- every refill was seeded from the live rho but appended after the frames still
  waiting, so the player lane replayed ~2 frames per refill (~10% slow);
- standing contracts ticked on wall time x max_evolution_dt / 0.02.

Now one PHRAME_SIM_DT per phrame (x stride) for everything; max_evolution_dt
only caps the integrator substep. tests/lookahead_clock_probe.gd boots the real
game in each lane and samples every biome every tick.
"""
import json
import math
import os
import re
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/lookahead_clock_probe.gd"


def _clock():
    m = re.search(r"const PHRAME_SIM_DT: float = ([0-9.]+)", read_source("Core/Config/PhysicsConfig.gd"))
    assert m, "PhysicsConfig must define PHRAME_SIM_DT"
    return float(m.group(1))


def _env(tmp, lane):
    env = dict(os.environ)
    for k in ("RIG_DISABLE_LOOKAHEAD", "SW_DISABLE_LOOKAHEAD", "CLOCK_DISTURB", "CLOCK_DISTURB_ONCE"):
        env.pop(k, None)
    if lane == "rig":
        env["RIG_DISABLE_LOOKAHEAD"] = "1"
    else:
        env["CLOCK_DISTURB"] = "Village"       # one write: its refills go out alone
        env["CLOCK_DISTURB_ONCE"] = "1"
    env["APPDATA"] = str(tmp)
    env["XDG_DATA_HOME"] = str(tmp)
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    return env


def _parse(out):
    rows = {"biome": {}, "series": {}, "packets": [], "summary": None}
    for line in out.splitlines():
        if line.startswith("CLOCK_BIOME "):
            r = json.loads(line[len("CLOCK_BIOME "):]); rows["biome"][r["biome"]] = r
        elif line.startswith("CLOCK_SERIES "):
            r = json.loads(line[len("CLOCK_SERIES "):]); rows["series"][r["biome"]] = r["p_north"]
        elif line.startswith("CLOCK_PACKET "):
            rows["packets"].append(json.loads(line[len("CLOCK_PACKET "):]))
        elif line.startswith("CLOCK_SUMMARY "):
            rows["summary"] = json.loads(line[len("CLOCK_SUMMARY "):])
    return rows


@pytest.fixture(scope="module")
def lanes(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    procs = {}
    for lane in ("lookahead", "rig"):
        tmp = tmp_path_factory.mktemp(f"clock_{lane}")
        procs[lane] = subprocess.Popen(["godot", "--headless", "--script", PROBE], cwd=ROOT,
                                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, encoding="utf-8", errors="replace",
                                       env=_env(tmp, lane))
    out = {}
    for lane, p in procs.items():
        text, _ = p.communicate(timeout=400)
        assert p.returncode == 0, f"{lane} probe failed:\n{text[-3000:]}"
        assert "SCRIPT ERROR" not in text and "Parse Error" not in text, text[-3000:]
        out[lane] = _parse(text)
        assert out[lane]["summary"] is not None, text[-3000:]
    assert out["lookahead"]["summary"]["lane"] == "lookahead"
    assert out["rig"]["summary"]["lane"] == "direct"
    return out


def _period(xs, lo=20.0, hi=2000.0):
    """Least-squares single-sinusoid period, in ticks."""
    n = len(xs)
    mean = sum(xs) / n
    ys = [x - mean for x in xs]
    best, best_p, p = float("inf"), None, lo
    while p <= hi:
        w = 2 * math.pi / p
        c = [math.cos(w * t) for t in range(n)]
        s = [math.sin(w * t) for t in range(n)]
        cc = sum(v * v for v in c); ss = sum(v * v for v in s); cs = sum(a * b for a, b in zip(c, s))
        yc = sum(a * b for a, b in zip(ys, c)); ysn = sum(a * b for a, b in zip(ys, s))
        det = cc * ss - cs * cs
        if det > 1e-9:
            a = (yc * ss - ysn * cs) / det
            b = (ysn * cc - yc * cs) / det
            res = sum((y - a * cv - b * sv) ** 2 for y, cv, sv in zip(ys, c, s))
            if res < best:
                best, best_p = res, p
        p *= 1.005
    return best_p


def test_every_packet_runs_on_the_shared_clock(lanes):
    clock = _clock()
    packets = lanes["lookahead"]["packets"]
    assert packets, "the player lane forecast nothing"
    off = [p for p in packets if abs(float(p["dt"]) - clock) > 1e-9]
    assert not off, f"packets not on the shared clock ({clock}): {off}"


def test_a_biome_refilling_alone_keeps_the_clock(lanes):
    """Village's resolution is 1.0. Written once, its refills go out on their own;
    they used to run at its own dt, 50x its neighbours."""
    clock = _clock()
    village = lanes["lookahead"]["biome"]["Village"]
    assert float(village["max_evolution_dt"]) > clock, "Village no longer has a coarse resolution"
    alone = [p for p in lanes["lookahead"]["packets"] if p["biomes"] == ["Village"]]
    assert alone, "the write did not split Village's refills off; the test proves nothing"
    assert all(abs(float(p["dt"]) - clock) < 1e-9 for p in alone)


def test_both_lanes_run_one_clock(lanes):
    """TheDemos is one closed qubit: its populations are an exact sinusoid in sim
    time, so its period in ticks is the clock. Before: 5x apart (rig fast), then
    10% apart once the clock was shared but refill seams still replayed frames."""
    pl = _period(lanes["lookahead"]["series"]["TheDemos"])
    rg = _period(lanes["rig"]["series"]["TheDemos"])
    assert pl and rg
    assert abs(pl - rg) / rg < 0.04, (
        f"TheDemos period: player lane {pl:.1f} ticks, rig {rg:.1f} ticks — the lanes run different clocks")


def test_refills_never_replay_frames(lanes):
    """A refill continues the buffer from its last frame. Seeded from the live rho
    instead, it replayed the frames still waiting: a one-tick step backwards every
    refill (~every 21 ticks)."""
    for biome, xs in lanes["lookahead"]["series"].items():
        d = [xs[i + 1] - xs[i] for i in range(len(xs) - 1)]
        back = [i for i in range(1, len(d) - 1)
                if d[i] * d[i - 1] < 0 and d[i] * d[i + 1] < 0 and abs(d[i]) > 1e-6]
        assert not back, f"{biome} stepped backwards at ticks {back} (a refill replayed frames)"


# ---------------------------------------------------------------------------
# Source pins
# ---------------------------------------------------------------------------

def test_native_calls_take_the_clock_not_the_resolution():
    b = read_source("Core/Environment/BiomeEvolutionBatcher.gd")
    calls = re.findall(r"(?:evolve_single_biome|evolve_all_lookahead|submit_lookahead_job)\((.*?)\)\s*(?:\n|:)", b, re.S)
    real = [c for c in calls if "rho" in c or "biome_rhos" in c]
    # prime-all, prime-one, live phrame, async submit, sync compute
    assert len(real) >= 5, f"expected the batcher's five native calls, found {len(real)}"
    for c in real:
        assert "PHRAME_SIM_DT" in c, f"a native evolve call isn't on the shared clock: ({c.strip()})"
    assert "_live_phrame_dt" not in b and "_get_packet_dt_for" not in b


def test_refills_seed_from_the_buffer_tail():
    b = read_source("Core/Environment/BiomeEvolutionBatcher.gd")
    assert b.count("_refill_seed(biome_name, status.rho)") == 2, \
        "both the adaptive and the emergency refill must start from the buffer's last frame"


def test_rig_lane_and_contracts_use_the_clock():
    stepper = read_source("Core/Environment/BiomeDeterministicStepper.gd")
    collect = stepper.split("func collect_stride_evolution_packets(")[1].split("\nfunc ")[0]
    assert "PhysicsConfig.sim_dt(" in collect and "PhysicsConfig.PHRAME_SIM_DT" in collect
    farm = read_source("Core/Farm.gd")
    eff = farm.split("func _get_lindblad_effective_delta_for_biome(")[1].split("\nfunc ")[0]
    code = "\n".join(l for l in eff.splitlines() if not l.lstrip().startswith("#"))
    assert "PhysicsConfig.sim_dt(" in code
    assert "max_evolution_dt" not in code, "resolution must not speed up a contract"
