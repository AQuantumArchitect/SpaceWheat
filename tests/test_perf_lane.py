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
    assert "RuntimeEnv.load_path()" in hooks, (
        "the checkpoint load must go through RuntimeEnv so a web query string can "
        "reach it — OS.get_environment is empty in a browser"
    )
    shot = src.split("func _dev_screenshot()")[1].split("\nfunc ")[0]
    assert "SW_LOAD_PATH" not in shot, (
        "the screenshot path must not own the checkpoint load again"
    )


BATCHER = ROOT / "Core/Environment/BiomeEvolutionBatcher.gd"


def test_packet_size_is_bounded_by_measured_time_not_just_buffer_depth():
    """Two-layer size law. Sync compute still runs ON the frame, so the 25 ms
    stall budget stays. Async compute sizes by buffer cover (Fibonacci) and
    must not silently fall back to "grow fib to max" on the sync path.

    The clamp is applied where the packet is sized. Progress is never zero.
    """
    src = _read(BATCHER)
    assert "PACKET_TIME_BUDGET_MS" in src, (
        "sync packets must stay bounded by a stall budget"
    )
    assert "_has_async_lookahead" in src, (
        "cover law is gated on the compute layer actually being async"
    )
    assert "ASYNC_PACKET_LATENCY_BUDGET_MS" in src, (
        "async packets are bounded by job/take latency, not uncapped Fibonacci"
    )
    assert "_avg_ms_per_step" in src, (
        "the stall budget has to divide by a MEASURED per-step cost"
    )
    queue_fn = src.split("func _queue_hybrid_packet()")[1].split("\nfunc ")[0]
    assert "_affordable_batch_size" in queue_fn, (
        "the budget is applied where the packet is sized, or it is decoration"
    )
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


def test_batcher_splits_the_gdscript_side_of_the_physics_callback():
    """Headed endgame on the 960M (2026-08-13) spent ~13% of wall inside Eigen
    and never left RECOVERY. native+merge cannot say where the other 87% went.
    consume/refill/poll are the next three seams in the same callback."""
    src = _read(BATCHER)
    for key in ("consume_ms_total", "refill_ms_total", "poll_ms_total"):
        assert key in src, f"{key} is how the remaining physics-callback cost gets a name"
    sampler = _read(SAMPLER)
    for key in ("consume_ms_total", "refill_ms_total", "poll_ms_total", "attribution"):
        assert key in sampler, f"{key} must reach the shipped report"


LEDGER = ROOT / "Core/Debug/FrameCostLedger.gd"
FIELD3D = ROOT / "Core/Visualization/QuantumField3D.gd"


def test_viz_cost_has_a_named_ledger_that_ships():
    """The 86% of headed endgame wall that is not the batcher needs a name.

    UIPerformanceTracker only keeps a 100-sample rolling average and never
    reaches the shipped report. A second silent average would repeat the
    avg_batch_time_ms mistake. The ledger is cumulative milliseconds, lives
    in Core/Debug (not tests/, not 🍄/), and PerfSampler copies it.
    """
    assert LEDGER.exists(), "FrameCostLedger.gd is the viz channel; it is missing"
    rel = str(LEDGER.relative_to(ROOT))
    assert not rel.startswith(("🍄/", "tests/", "Core/Tests/", "tools/")), (
        f"{rel} sits inside an export-excluded tree — it would not ship"
    )
    src = _read(LEDGER)
    assert "add_us" in src and "totals" in src
    assert "RuntimeEnv.perf_log_path()" in src, (
        "the ledger must be inert unless the sampler is on — a player's build "
        "pays one env read, not a running average"
    )
    sampler = _read(SAMPLER)
    assert "snap[\"viz\"]" in sampler
    assert "\"viz_field3d\"" in sampler, (
        "the default renderer is QuantumField3D, not the 2D force graph — "
        "that key must be in the non-overlapping accounted set"
    )


def test_the_default_3d_field_records_its_tick():
    """GameRoot._field3d_enabled defaults ON. Timing only QuantumForceGraph
    would name a renderer the player is not looking at."""
    src = _read(FIELD3D)
    assert "FrameCostLedger.add_us(\"viz_field3d\"" in src
    for key in ("viz_field3d_force", "viz_field3d_bubbles", "viz_field3d_edges"):
        assert key in src, f"{key} splits the 3D tick so a hitch has a seam"
    farm = _read(ROOT / "Core/Farm.gd")
    assert "FrameCostLedger.add_us(\"viz_farm\"" in farm
    assert "FrameCostLedger.add_us(\"viz_farm_physics_rest\"" in farm
    pgd = _read(ROOT / "UI/PlotGridDisplay.gd")
    assert "FrameCostLedger.add_us(\"viz_pgd\"" in pgd
    force = _read(ROOT / "Core/Visualization/QuantumForceGraph.gd")
    assert "FrameCostLedger.add_us(\"viz_force_process\"" in force
    assert "FrameCostLedger.add_us(\"viz_force_draw\"" in force


def test_web_builds_read_the_same_switches_from_the_query_string():
    """SW_AUTOSTART is an env var. A browser has none. Without a query hook
    every headed web sample is the title card, which is how 59.8 fps got
    quoted as the playable number when it was not."""
    env_src = _read(RUNTIME_ENV)
    assert "parse_query" in env_src
    assert "JavaScriptBridge" in env_src
    assert "static func autostart()" in env_src
    assert "static func load_path()" in env_src
    assert "return \"web://post\"" in env_src, (
        "sw_perf=1 must give the sampler a path or it disables itself"
    )
    app = _read(ROOT / "scenes/AppRoot.gd")
    start = app.split("func _maybe_auto_start()")[1].split("\nfunc ")[0]
    assert "RuntimeEnv.autostart()" in start
    assert "OS.has_environment(\"SW_AUTOSTART\")" not in start, (
        "OS.has_environment is empty on web — autostart must go through RuntimeEnv"
    )
    sampler = _read(SAMPLER)
    assert "_post_web_report" in sampler
    assert "/__engine_perf" in sampler
    web = _read(ROOT / "tools/profiling_kit/run_web.py")
    assert "/__engine_perf" in web
    assert "sw_autostart" in web
    assert "sw_load_path" in web


def test_perf_hitch_logs_go_through_the_tagged_logger():
    """The owner asked for telemetry on the existing verbosity/tag logger,
    not a second silent channel. Hitch lines are WARN on `perf` so a player
    build stays quiet; the sampler raises that category when SW_PERF_LOG is on.
    """
    vc = _read(ROOT / "Core/Config/VerboseConfig.gd")
    assert "func hitch(" in vc
    assert 'warn("perf"' in vc
    assert "VERBOSE_CATEGORIES" in vc
    sampler = _read(SAMPLER)
    assert "_record_hitch" in sampler
    assert "engine_process_ms_total" in sampler
    assert "present_wait_share" in sampler
    assert "engine_minus_script_share" in sampler
    field = _read(FIELD3D)
    assert 'vc.hitch("viz_field3d"' in field
    root = _read(ROOT / "scenes/GameRoot.gd")
    assert "RuntimeEnv.classic_2d()" in root
    desktop = _read(ROOT / "tools/profiling_kit/run_desktop.py")
    assert "--classic-2d" in desktop
    assert "--headless" in desktop
    assert "find_exe" in desktop


def test_vsync_hitch_train_is_pinned():
    """Capped and uncapped endgame share the same ~150 hitches / 30 s.

    FIFO vsync only promotes them into p95. Mailbox on the 960M made present
    worse (26 fps). Keep the packet flat, hitch rows name ledger_ms, and the
    5 Hz live-tile refresh must not dirty hidden / unchanged tiles — that
    loop was the ~90 ms unnamed spike (hitch times sit on a 0.2 s grid).
    """
    optimizer = _read(ROOT / "Core/Settings/PerformanceOptimizer.gd")
    assert "VSYNC_ENABLED" in optimizer
    assert "VSYNC_MAILBOX" not in optimizer.split("window_set_vsync_mode")[-1]
    batcher = _read(ROOT / "Core/Environment/BiomeEvolutionBatcher.gd")
    assert "func adopt_flat_from_result" in batcher
    assert "layout == \"flat\"" in batcher
    sampler = _read(SAMPLER)
    assert "ledger_ms" in sampler
    assert "_ledger_prev = FrameCostLedger.totals()" in sampler
    pgd = _read(ROOT / "UI/PlotGridDisplay.gd")
    live = pgd.split("func _refresh_live_tiles()")[1].split("\nfunc ")[0]
    assert "not tile.visible" in live, "5 Hz refresh must skip hidden tiles"
    assert "viz_pgd_live" in live
    tile = _read(ROOT / "UI/PlotTile.gd")
    setter = tile.split("func set_plot_data(")[1].split("\nfunc ")[0]
    assert "_structural_same" in setter
    assert "queue_redraw()" in setter
    assert "set_physics_process(false)" in tile
    assert "set_physics_process(true)" not in tile
    witness = _read(ROOT / "Core/Witness/WitnessOrgan.gd")
    proc = witness.split("func _process(")[1].split("\nfunc ")[0]
    assert "_watchers <= 0" in proc, "advisory 5 Hz stride must not run unwatched"
    assert "viz_witness" in proc
    assert "\"viz_witness\"" in sampler
