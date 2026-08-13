#!/usr/bin/env python3
"""Measure the Windows desktop build's frame cost on real hardware. Windows-native.

    py -3 run_desktop.py                    # all scenarios, capped and uncapped
    py -3 run_desktop.py --scenarios endgame
    py -3 run_desktop.py --seconds 60

Standard library only. Launches `build\\SpaceWheat.exe` with `SW_PERF_LOG` set,
waits for it to write its own JSON report and exit, then prints the numbers.
There is no window-scraping and no test harness in the loop: the sampler
(`Core/Debug/PerfSampler.gd`) is compiled into the game, so this measures the
same binary a player downloads.

THREE SCENARIOS, because SpaceWheat's cost tracks how much world is alive, not
which menu is open:

    title     the title card — the renderer's floor, almost no physics
    fresh     a new campaign — Act-0 load, three biomes
    endgame   a late-act save — six biomes, the full coupling graph

`endgame` is the one that matters. If it holds up, the game holds up.

TWO PASSES, because they answer different questions and neither substitutes for
the other:

    capped     what a player actually gets. The game turns vsync ON when it
               detects a real GPU, so this reports the refresh rate if there is
               any headroom at all — which is the point. "Does it hold 60?"
    uncapped   SW_UNCAP_FPS=1 lifts vsync and the fps ceiling. Nobody plays this
               way; it is the only way to see how much room is left. 62 fps
               uncapped and 400 fps uncapped both read "60" when capped.

The uncapped flag is recorded inside every report (`runtime_env.uncap_frame_rate`),
so the two can never be confused after the fact.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_BUILD = HERE / "build"
DEFAULT_RESULTS = HERE / "results"
DEFAULT_SAVE = HERE / "build" / "endrun_ending.tres"

SCENARIOS = {
    "title": {},
    "fresh": {"SW_AUTOSTART": "1"},
    "endgame": {"SW_AUTOSTART": "1", "SW_LOAD_PATH": None},  # filled in from --save
}


def run_one(exe: Path, out: Path, scenario: str, uncapped: bool,
            warmup: float, seconds: float, save: Path, timeout: float) -> dict | None:
    env = dict(os.environ)
    env.update({
        "SW_PERF_LOG": str(out),
        "SW_PERF_WARMUP_SECONDS": str(warmup),
        "SW_PERF_SECONDS": str(seconds),
        "SW_UNCAP_FPS": "1" if uncapped else "0",
        # The FPS/PhHz strip is a debug-build readout. Off, so the run renders
        # exactly what a player's build renders.
        "SW_DEBUG_READOUT": "0",
    })
    for k, v in SCENARIOS[scenario].items():
        env[k] = str(save) if v is None else v

    if out.exists():
        out.unlink()

    label = f"{scenario}/{'uncapped' if uncapped else 'capped'}"
    print(f"  running {label} … ", end="", flush=True)
    started = time.time()
    try:
        proc = subprocess.run([str(exe)], env=env, timeout=timeout,
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    except subprocess.TimeoutExpired:
        print(f"TIMEOUT after {timeout:.0f}s — the game did not quit on its own")
        return None
    elapsed = time.time() - started

    if not out.exists():
        print(f"no report (exit {proc.returncode}, {elapsed:.0f}s)")
        tail = (proc.stdout or b"").decode("utf-8", "replace").strip().splitlines()[-12:]
        for line in tail:
            print(f"      | {line}")
        print("      This build has no PerfSampler in it. The kit's build\\ folder must")
        print("      hold the profiling export, not the v1.0-rc3 pack.")
        return None

    report = json.loads(out.read_text(encoding="utf-8"))
    s = report.get("steady_state") or {}
    if not s:
        print("no steady-state frames")
        return report
    print(f"{s['fps_mean']:6.1f} fps mean  |  p50 {s['frame_ms_p50']:6.2f}ms  "
          f"p95 {s['frame_ms_p95']:6.2f}ms  |  {s['frames']} frames")
    return report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--build", default=str(DEFAULT_BUILD))
    ap.add_argument("--results", default=str(DEFAULT_RESULTS))
    ap.add_argument("--save", default=str(DEFAULT_SAVE))
    ap.add_argument("--scenarios", nargs="*", default=list(SCENARIOS),
                    choices=list(SCENARIOS))
    ap.add_argument("--seconds", type=float, default=30.0, help="measurement window")
    ap.add_argument("--warmup", type=float, default=25.0,
                    help="boot grace kept out of the percentiles (sampled separately)")
    ap.add_argument("--only", choices=["capped", "uncapped"], default=None)
    args = ap.parse_args()

    exe = Path(args.build).resolve() / "SpaceWheat.exe"
    if not exe.exists():
        sys.exit(f"no SpaceWheat.exe in {args.build}")
    save = Path(args.save).resolve()
    results = Path(args.results).resolve()
    results.mkdir(parents=True, exist_ok=True)

    passes = [False, True] if args.only is None else [args.only == "uncapped"]
    timeout = args.warmup + args.seconds + 180

    print(f"exe        {exe}")
    print(f"save       {save}{'' if save.exists() else '   [MISSING — endgame will be skipped]'}")
    print(f"window     {args.warmup:.0f}s warmup + {args.seconds:.0f}s sample per run")
    print(f"scenarios  {', '.join(args.scenarios)}")
    print()
    print("Each run opens a game window and closes itself. Leave the window in front.")
    print()

    reports: dict[str, dict] = {}
    for scenario in args.scenarios:
        if scenario == "endgame" and not save.exists():
            print(f"  skipping endgame — no save at {save}")
            continue
        for uncapped in passes:
            key = f"{scenario}-{'uncapped' if uncapped else 'capped'}"
            report = run_one(exe, results / f"desktop-{key}.json", scenario, uncapped,
                             args.warmup, args.seconds, save, timeout)
            if report:
                reports[key] = report

    if not reports:
        print("\nNo reports produced. Nothing to conclude — do not guess a number.")
        return 2

    first = next(iter(reports.values()))
    env = first.get("environment", {})
    print()
    print("=" * 78)
    print(f"  build      {first.get('build', {}).get('display')}")
    print(f"  adapter    {env.get('video_adapter')}  ({env.get('video_adapter_vendor')})")
    print(f"  api        {env.get('video_adapter_api_version')}")
    print(f"  cpu        {env.get('processor')} x{env.get('processor_count')}")
    print(f"  refresh    {env.get('screen_refresh_rate')} Hz")
    print("-" * 78)
    print(f"  {'scenario':<22} {'fps mean':>9} {'p50 ms':>8} {'p95 ms':>8} {'worst ms':>9}  trust")
    for key, report in reports.items():
        s = report.get("steady_state") or {}
        if not s:
            continue
        print(f"  {key:<22} {s['fps_mean']:>9.1f} {s['frame_ms_p50']:>8.2f} "
              f"{s['frame_ms_p95']:>8.2f} {s['frame_ms_max']:>9.0f}  {report.get('trustworthy')}")
    print("=" * 78)

    untrusted = [k for k, r in reports.items() if not r.get("trustworthy")]
    if untrusted:
        print("\nRuns that cannot support a verdict:")
        for key in untrusted:
            for c in reports[key].get("caveats", []):
                print(f"  {key}: {c}")
    print(f"\nreports in {results}")
    return 0 if not untrusted else 1


if __name__ == "__main__":
    sys.exit(main())
