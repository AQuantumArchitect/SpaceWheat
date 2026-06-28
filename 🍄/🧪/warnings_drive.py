#!/usr/bin/env python3
"""Warnings audit driver — exercise the REAL play path and capture every warning.

Two blind spots motivated this:
  1. The boot smoke-grep only matched SCRIPT ERROR / Parse Error / ERROR: Failed to
     and ran at boot only — blind to WARNING: lines and to anything during gameplay.
  2. The headless rig SKIPS the entire visualization stack ("QuantumViz unavailable",
     "skipping visuals"). When a human runs `godot` headed, the viz layer (shaders,
     textures, bubbles, QuantumViz) mounts and renders — the one path neither the rig
     nor pytest ever exercised.

This driver boots the rig (headless OR headed) through the shared PlayerShell, drives a
compact sequence that touches every visual surface (each overlay, plot ring, evolve
frames, an incorporation, a screenshot to force a render), then stops. The listener's
FULL unfiltered stderr is written to the --log path; the wrapper (check_warnings.sh
--runtime) tallies WARNING:/ERROR:/SCRIPT ERROR from it by source location.

Usage:
  python3 warnings_drive.py [--headed] [--log PATH] [--scenario demos_normal]
"""
import argparse
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️
from rig_client import RigClient  # noqa: E402


# Surfaces (overlay toggles) + the QERF cross + plot ring — opening each overlay forces
# the viz layer to build + render that surface, which is where headed-only warnings live.
OVERLAY_KEYS = ["z", "x", "c", "v", "b", "n", "m"]
PLOT_KEYS = ["g", "h", "j", "k", "l"]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--headed", action="store_true", help="boot with rendering (opengl3)")
    ap.add_argument("--log", default=None, help="listener stderr log path")
    ap.add_argument("--scenario", default="demos_normal", help="boot scenario")
    args = ap.parse_args()

    display_mode = "headed" if args.headed else "headless"
    log_path = Path(args.log).resolve() if args.log else None

    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)

    # RIG_DISABLE_LOOKAHEAD=0 → run the LIVE C++ engine (what a human's `godot` runs),
    # not the rig's usual disabled twin. rig_log_profile=None so the listener does not
    # suppress its own output — we want the raw firehose for the audit.
    proc = c.start_listener(
        scenario_id=args.scenario,
        display_mode=display_mode,
        listener_stdout="file",
        listener_log_path=log_path,
        rig_log_profile=None,
        extra_env={"RIG_DISABLE_LOOKAHEAD": "0"},
    )

    # Headed llvmpipe boot is slow; give it room.
    ready = c.wait_for_ready(proc, timeout_s=180.0 if args.headed else 90.0)
    if not c.ready_seen(ready):
        print(f"❌ listener never reached ready ({display_mode})")
        c.terminate_listener(proc)
        return 1
    print(f"✅ rig ready ({display_mode}); driving visual-stack sweep")

    turn = [0]

    def step(action, **kw):
        turn[0] += 1
        r = c.run_turn(turn[0], action, timeout_s=20.0, **kw)
        ok = r.get("ok", False)
        tag = "" if ok else f"  ⚠ {r.get('error')}"
        print(f"  t{turn[0]:02d} {action:<14}{('' if not kw else ' '+str(kw))[:40]}{tag}")
        return r

    # Make a window so the viz actually has somewhere to draw (headed).
    if args.headed:
        step("set_window_size", w=1280, h=720)

    # Let the sim breathe a few real phrames (evolve through the live engine + render).
    step("press_key", key="f", settle_frames=8)
    step("press_key", key="f", settle_frames=8)

    # Walk the plot ring (selection redraw on each).
    for k in PLOT_KEYS:
        step("press_key", key=k, settle_frames=2)

    # Open every overlay surface, settle so it renders, then close (esc). Screenshots
    # only headed: headless has no render target, so a screenshot there just self-inflicts
    # dummy-driver texture_2d_get errors that would pollute the tally.
    for k in OVERLAY_KEYS:
        step("press_key", key=k, settle_frames=4)
        if args.headed:
            step("screenshot")  # force a full render of the open surface
        step("press_key", key="escape", settle_frames=2)

    # Exercise the QERF cross on a selected plot (extract / pause / strike / fast-fwd).
    for k in ["q", "e", "r", "f"]:
        step("press_key", key=k, settle_frames=3)

    # One more settle + final render.
    step("press_key", key="f", settle_frames=12)
    if args.headed:
        step("screenshot")

    step("stop")
    c.terminate_listener(proc)
    print("✅ sweep complete; listener stopped")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
