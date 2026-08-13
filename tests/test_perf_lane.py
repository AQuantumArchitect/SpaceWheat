"""A performance lane must address a parser that actually ships.

For at least one release cycle this repository carried fourteen files of
profiling tooling — four scripts, seven test-runners, two summarisers and a
GDScript harness — all of which drove the game with `--runtime-profile-mode=…`
and friends. Nothing has ever parsed those flags. The one file that could
(`tests/test_headed_runtime_profile.gd`) read `PROFILE_*` environment variables
instead, was invoked by nothing, and lived under `tests/`, which every export
preset excludes. So the lane launched a game, waited, found no JSON, and
reported the missing output as a build failure. `docs/EXPORT_HEALTH.md` and
`scripts/validate-desktop-release.sh --profile` both trusted it.

The failure was not "a script broke". It was that an instrument addressed
something that did not exist, and nothing could tell. These tests make that
specific silence impossible: the perf channel must be reachable from a SHIPPED
build, and no script may talk to the phantom again.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SAMPLER = ROOT / "Core/Debug/PerfSampler.gd"
RUNTIME_ENV = ROOT / "Core/Config/RuntimeEnv.gd"
PROJECT = ROOT / "project.godot"
EXPORT_LANE = ROOT / "scripts/profile-export-runtime.sh"
PRESETS = ROOT / "export_presets.cfg"


def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_no_script_addresses_the_phantom_profile_parser():
    """The flags that fourteen files spoke to, and nothing listened for.

    Executable lines only. Prose is allowed to name the dead flags — this file
    does, and so does the architecture note that records the deletion — because
    the danger was never the string, it was a script passing it to a binary.
    """
    speakers = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts or ".claude" in path.parts:
            continue
        # This file is the checker; it necessarily writes the dead flag down,
        # in a docstring and in its own failure message.
        if path.suffix not in {".sh", ".py", ".gd"} or path == Path(__file__):
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for n, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue
            if "--runtime-profile-" in line:
                speakers.append(f"{path.relative_to(ROOT)}:{n}")
    assert not speakers, (
        "these pass `--runtime-profile-*` to something, and no code in this repo parses "
        "it: " + ", ".join(speakers)
    )


def test_the_perf_channel_is_reachable_from_a_shipped_build():
    """`🍄/**` and `tests/**` are excluded from every export, so the sampler
    cannot live in either — that exclusion is what made the old harness
    unreachable from the pack a player runs."""
    assert SAMPLER.exists(), "Core/Debug/PerfSampler.gd is the perf channel; it is missing"
    rel = str(SAMPLER.relative_to(ROOT))
    presets = _read(PRESETS)
    for exclusion in ("🍄/**", "tests/**", "Core/Tests/**"):
        assert exclusion in presets, f"expected {exclusion} in the export exclude filter"
    assert not rel.startswith(("🍄/", "tests/", "Core/Tests/")), (
        f"{rel} sits inside an export-excluded tree — it would not ship"
    )
    assert f'PerfSampler="*res://{rel}"' in _read(PROJECT), (
        "PerfSampler must be an autoload, or nothing starts it in an exported game"
    )


def test_the_sampler_is_inert_without_its_env_var():
    """A player's build must pay one env read at boot and nothing after."""
    src = _read(SAMPLER)
    ready = src.split("func _ready()")[1].split("\nfunc ")[0]
    assert "set_process(false)" in ready and "return" in ready, (
        "_ready must disable processing when SW_PERF_LOG is unset"
    )
    assert 'env_str("SW_PERF_LOG", "")' in _read(RUNTIME_ENV), (
        "SW_PERF_LOG belongs to RuntimeEnv — the single authority for runtime switches"
    )


def test_a_report_says_when_it_cannot_be_trusted():
    """An fps number without its renderer is an adjective.

    Two numbers have already been published off invalid renderers: 10.4 fps on
    SwiftShader (docs/release/WEB_DOOR.md) and the llvmpipe desktop runs. The
    report has to carry its own disqualification rather than leave the reader to
    remember which box produced it.
    """
    src = _read(SAMPLER)
    assert "software_rendering_suspected" in src
    assert '"trustworthy"' in src, "the report must state a verdict, not just raw fields"
    assert "detect_software_renderer" in src, (
        "software-rasteriser detection has one owner (PerformanceOptimizer); a second "
        "list here could drift, and the game would cap for software while the report "
        "called the run trustworthy"
    )
    # Vsync and an fps cap each silently flatten a result to the refresh rate.
    assert "vsync is on" in src and "max_fps" in src


def test_the_uncap_switch_is_recorded_in_every_report():
    """SW_UNCAP_FPS produces a number no player can see. It must be impossible
    to mistake an uncapped run for a capped one after the fact."""
    optimizer = _read(ROOT / "Core/Settings/PerformanceOptimizer.gd")
    assert "RuntimeEnv.uncap_frame_rate()" in optimizer, (
        "the frame cap has one owner; the profiling override must go through it"
    )
    env_src = _read(RUNTIME_ENV)
    assert 'flag("SW_UNCAP_FPS", false)' in env_src, "must default OFF for players"
    describe = env_src.split("static func describe()")[1]
    assert '"uncap_frame_rate": uncap_frame_rate()' in describe, (
        "describe() is embedded verbatim in every perf report — if the flag is not in "
        "it, an uncapped run reads exactly like a capped one"
    )
    assert '"runtime_env": RuntimeEnv.describe()' in _read(SAMPLER)


def test_the_export_lane_drives_the_shipping_parser():
    src = _read(EXPORT_LANE)
    assert "SW_PERF_LOG" in src, "the export profiler must drive the channel that ships"
    for scenario in ("SW_AUTOSTART", "SW_LOAD_PATH"):
        assert scenario in src, (
            f"{scenario} is how the lane reaches real game state; without it every "
            "scenario measures the title card"
        )
    # A missing report is a fact about the build, not a mystery.
    assert re.search(r"no report at .*PerfSampler", src), (
        "when no report appears the lane must name the likely cause (a pack built "
        "before the sampler existed), not just warn"
    )


def test_loading_a_save_does_not_require_asking_for_a_screenshot():
    """SW_LOAD_PATH used to live inside GameRoot._dev_screenshot(), which quits
    the moment the capture lands — so the richest state in the game could be
    photographed but never run, and never profiled."""
    src = _read(ROOT / "scenes/GameRoot.gd")
    hooks = src.split("func _run_boot_env_hooks()")[1].split("\nfunc ")[0]
    assert "SW_LOAD_PATH" in hooks, "the checkpoint load must be its own step"
    shot = src.split("func _dev_screenshot()")[1].split("\nfunc ")[0]
    assert "SW_LOAD_PATH" not in shot, (
        "the screenshot path must not own the checkpoint load again"
    )


BATCHER = ROOT / "Core/Environment/BiomeEvolutionBatcher.gd"


def test_packet_size_is_bounded_by_measured_time_not_just_buffer_depth():
    """Task #528. A native packet is computed synchronously on the main thread, so
    its whole cost lands in ONE frame.

    The Fibonacci ladder sized packets by buffer depth alone, on a stated assumption
    that "C++ batches are cheap". At six live biomes they are not: one 21-step packet
    measured ~310ms on the endgame save. Crucially, total native work is INVARIANT
    under packet size (21.7% / 25.3% / 23.3% of wall at 1, 5 and 21 steps per packet),
    so the ladder was buying no throughput with that stall — only lumpiness.

    This pins the time budget so a future tuning pass cannot quietly restore
    "grow fib to max and stay there" without also restoring the 681ms frame.
    """
    src = _read(BATCHER)
    assert "PACKET_TIME_BUDGET_MS" in src, (
        "packet size must be bounded by a time budget, not only by the fib ladder"
    )
    assert "_avg_ms_per_step" in src, (
        "the budget has to divide by a MEASURED per-step cost; a hardcoded step "
        "count would drift the moment biome count or dimension changes"
    )
    # The clamp must actually be applied on the queueing path, not merely defined.
    queue_fn = src.split("func _queue_hybrid_packet()")[1].split("\nfunc ")[0]
    assert "_affordable_batch_size" in queue_fn, (
        "the budget is applied where the packet is sized, or it is decoration"
    )
    # Progress must never be traded away entirely.
    afford = src.split("func _affordable_batch_size(")[1].split("\nfunc ")[0]
    assert "1" in afford and "clampi" in afford, (
        "a starved biome must still get at least one step per packet"
    )


def test_batcher_reports_cumulative_native_cost_not_only_an_average():
    """avg_batch_time_ms says what ONE packet cost. It cannot say what fraction of
    the session went into the native call — for that you need packets-per-second too.

    Reading the average as though it were the frame is exactly how the first pass at
    #528 concluded "the quantum batch is the whole cost" when the measured share was
    23%. The cumulative counters make that mistake impossible to repeat."""
    src = _read(BATCHER)
    for key in ("native_ms_total", "merge_ms_total", "packets_total"):
        assert key in src, f"{key} is needed to turn a per-packet average into a share of wall time"
    sampler = _read(ROOT / "Core/Debug/PerfSampler.gd")
    for key in ("native_ms_total", "packets_total"):
        assert key in sampler, f"{key} must reach the report, not just the batcher"


def test_integrator_substeps_are_bounded():
    """The old step-size rule solved the purity quadratic for "time until Tr(ρ²)=1"
    and floored the step at 1e-6s — which permitted 100k substeps inside a single
    0.1s phrame. Measured at dim 32: 167 substeps, 318ms, and NO better accuracy
    than its own single-substep case (both ≈1e-3 against a 20k-step reference).

    A hard substep ceiling is the guarantee that one phrame costs bounded work no
    matter what state a player builds."""
    src = _read(ROOT / "native/src/quantum_evolution_engine.h")
    assert "MAX_SUBSTEPS" in src, "the integrator needs a hard ceiling on work per call"
    cpp = _read(ROOT / "native/src/quantum_evolution_engine.cpp")
    assert "MAX_SUBSTEPS" in cpp, "the ceiling must be used, not just declared"
    assert "1e-6f" not in cpp.split("QuantumEvolutionEngine::evolve(")[1].split("\n}")[0], (
        "the absolute 1e-6s step floor is what allowed 100k substeps; it must not return"
    )


def test_sampler_measures_wall_clock_not_engine_delta():
    """`_process(delta)` delta is multiplied by Engine.time_scale, and Godot clamps
    it to stop the spiral of death. A sampler that accumulates it is measuring
    dilated, clamped seconds and calling them seconds.

    Measured 2026-08-13 on the endgame save, headless: the run took 280.7s of real
    time and the report said 32.4s. The same clamp hid the tail — a worst frame of
    10,384ms was reported as 884ms, twelve times smaller. Every "share of the
    window" number computed from that clock was inflated by the same factor, and
    one of them came out above 100%, which is how it was caught.

    So the window and every frame time must come from Time.get_ticks_usec()."""
    src = _read(SAMPLER)
    assert "Time.get_ticks_usec()" in src, "the sampler's clock must be the wall clock"
    assert "_wall_start_us" in src and "_last_frame_us" in src
    body = src.split("func _process(")[1].split("\nfunc ")[0]
    assert "_elapsed += delta" not in body, (
        "accumulating _process delta re-introduces the dilated/clamped clock"
    )
    assert "delta * 1000.0" not in body, (
        "frame times must be wall-clock deltas, not the engine's clamped delta"
    )
    # A dilated run must be legible as dilated rather than silently reported.
    assert "engine_time_scale_min" in src


def test_batcher_reports_cost_per_step_not_only_per_packet():
    """Packet size is adaptive, so ms-per-packet moves when the packet does and two
    builds cannot be compared with it. Measured 2026-08-13 at the 6-qubit ceiling:
    per-packet cost said one thing and per-step cost said the opposite.

    native_ms_per_step is also the exact quantity PACKET_TIME_BUDGET_MS divides,
    so the report and the sizing rule read the same number."""
    src = _read(ROOT / "Core/Environment/BiomeEvolutionBatcher.gd")
    assert '"native_ms_per_step"' in src
    assert '"steps_total"' in src
    assert "_steps_total += " in src, "steps must be counted where packets are"
    sampler = _read(SAMPLER)
    assert "native_ms_per_step" in sampler, (
        "the sampler copies a fixed key list — a metric the batcher exports but the "
        "sampler does not copy never reaches the report"
    )
