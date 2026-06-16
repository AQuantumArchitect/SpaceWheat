#!/usr/bin/env python3
"""Headed visual playthrough — drive FarmView through the keyboard like manual play.

Boots the rig with a real window up (RIG_DISPLAY_MODE=headed, opengl3 on WSL) and
injects InputEventKeys through the same shell/overlay/input stack a human hits. At
each step it screenshots the rendered viewport and snapshots UI/game state, then
scans the listener log for engine errors. Hunts edge cases: overlay-stack underflow,
disabled-hat presses (Spark/Merchant in the closed system), reserved keys, rapid hat
churn, confirm chords, surface teleport while an overlay is open.

Env:
  RIG_DISABLE_LOOKAHEAD  0 to drive the live C++ engine (tests the mixed-dim fix),
                         1 (default) for the GDScript stepper.
  PT_SCENARIO            scenario id (default: demos_normal).
"""
import json
import os
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))  # 🍄/🎛️
from rig_client import RigClient  # noqa: E402

SHOTS = HERE / "playthrough_shots"
SHOTS.mkdir(exist_ok=True)
SCEN = os.environ.get("PT_SCENARIO", "demos_normal")
LOOKAHEAD_ON = os.environ.get("RIG_DISABLE_LOOKAHEAD", "1") == "0"

errors = []      # (step, detail)
notes = []       # observations
_turn = [10]


def step(c):
    _turn[0] += 1
    return _turn[0]


def keys(c, label, seq, shot=True, settle=4):
    """Press a sequence of keys; optionally screenshot afterwards."""
    for k in seq:
        kspec = k if isinstance(k, dict) else {"key": k}
        kspec.setdefault("settle_frames", settle)
        r = c.run_turn(step(c), "press_key", timeout_s=20, **kspec)
        if not r.get("ok", False) and "press_key" not in r:
            errors.append((label, f"press {kspec}: {r}"))
    if shot:
        screenshot(c, label)


def screenshot(c, label):
    safe = "".join(ch if ch.isalnum() else "_" for ch in label)[:48]
    path = f"user://rig/pt_{_turn[0]:03d}_{safe}.png"
    r = c.run_turn(step(c), "screenshot", timeout_s=20, path=path)
    sc = r.get("screenshot") or {}
    if not sc.get("saved"):
        errors.append((label, f"screenshot failed: {r}"))
        return None
    abs_path = sc.get("abs")
    # copy out to repo shots dir for easy viewing
    try:
        dest = SHOTS / Path(abs_path).name
        dest.write_bytes(Path(abs_path).read_bytes())
        return dest
    except Exception as e:
        notes.append(f"{label}: shot saved at {abs_path} (copy failed: {e})")
        return abs_path


def snap(c, label, action, **kw):
    to = kw.pop("timeout_s", 30)
    r = c.run_turn(step(c), action, timeout_s=to, **kw)
    if not r.get("ok", True):
        errors.append((label, f"{action}: {r.get('error')}"))
    return r


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    log_path = c.runner_root / "logs" / "rig_listener.log"
    try:
        log_path.write_text("")  # truncate so our error-scan is this run only
    except OSError:
        pass

    print(f"== boot headed (scenario={SCEN}, lookahead={'ON' if LOOKAHEAD_ON else 'off'}) ==")
    proc = c.start_listener(
        scenario_id=SCEN,
        display_mode="headed",
        extra_env={"RIG_DISABLE_LOOKAHEAD": os.environ.get("RIG_DISABLE_LOOKAHEAD", "1")},
    )
    try:
        lines = c.wait_for_ready(proc, timeout_s=180)
        print(f"READY ({len(lines)} boot lines)")
        time.sleep(1.0)

        # ---- baseline ----
        screenshot(c, "00_farmview_baseline")
        g = snap(c, "grid", "grid_snapshot")
        gs = g.get("grid_snapshot") or g.get("grid") if isinstance(g, dict) else None
        biomes = None
        if isinstance(gs, dict):
            b = gs.get("biomes")
            biomes = list(b.keys()) if isinstance(b, dict) else b
        elif isinstance(gs, list):
            biomes = gs
        notes.append(f"biomes at boot: {biomes}")
        snap(c, "hud", "full_snapshot")

        # ============ PHASE 1: surface tour ============
        # M global map + all 6 pages + BroadGraph drill
        keys(c, "M_map_open", ["M"])
        snap(c, "M_overlay", "overlay_snapshot", overlay="map_meta")
        for pg, name in zip("TYUIOP", ["vectors", "eigenstate", "drift", "bits", "atlas", "graph"]):
            keys(c, f"M_page_{name}", [pg])
        # BroadGraph (P page) drill: pick a biome (G), drill into neighborhood (E), return (F)
        keys(c, "M_graph_pickbiome", ["G"])
        keys(c, "M_graph_drill_E", ["E"])
        keys(c, "M_graph_return_F", ["F"])
        keys(c, "M_close_esc", ["ESCAPE"])

        # surface key -> (label, registered overlay name) for overlay_snapshot
        for k, surf, ov in [("N", "network", "inspector"), ("V", "atlas", "atlas"),
                            ("B", "microscope", "biome_detail"), ("C", "quest", "quests"),
                            ("X", "self", "controls")]:
            keys(c, f"{surf}_open", [k])
            snap(c, f"{surf}_overlay", "overlay_snapshot", overlay=ov)
            keys(c, f"{surf}_close", ["ESCAPE"], shot=False)

        # X self sub-frames
        keys(c, "X_open2", ["X"])
        for pg in "TYUIO":
            keys(c, f"X_frame_{pg}", [pg])
        keys(c, "X_close", ["ESCAPE"], shot=False)

        # ============ PHASE 2: hats ============
        # cycle hats via Tab, then direct-select, verifying disabled Spark(4)/Merchant(6)
        for i in range(7):
            keys(c, f"tab_hat_{i}", ["TAB"], shot=(i in (0, 3, 6)))
        for hatkey, hatname in [("8", "ace"), ("0", "druid"), ("9", "operator"),
                                ("7", "captain"), ("5", "icon")]:
            keys(c, f"hat_{hatname}", [hatkey])
        # disabled hats — closed system
        keys(c, "hat_spark_DISABLED", ["4"])
        snap(c, "spark_policy", "policy_snapshot")
        keys(c, "hat_merchant_DISABLED", ["6"])
        # Druid sub-modes
        keys(c, "druid_submodes", ["0", "1", "2", "3"])

        # ============ PHASE 3: gameplay actions ============
        keys(c, "select_biome_T", ["T"], shot=False)
        keys(c, "select_plot_G", ["G"], shot=False)
        keys(c, "ace_hat", ["8"], shot=False)
        # E = Measure (projective collapse + pause)
        keys(c, "ace_measure_E", ["E"])
        snap(c, "after_measure_grid", "grid_snapshot")
        snap(c, "after_measure_resources", "resource_snapshot")
        # F = resume
        keys(c, "ace_resume_F", ["F"], shot=False)
        # R = Plant (inert in closed system)
        keys(c, "ace_plant_R_inert", ["R"])
        # Q = Harvest → pending QF confirm; F confirms
        keys(c, "ace_harvest_Q_pending", ["Q"])
        keys(c, "ace_harvest_F_confirm", ["F"])
        snap(c, "after_harvest_resources", "resource_snapshot")
        # Druid Hadamard + rotations
        keys(c, "druid_hat2", ["0"], shot=False)
        keys(c, "druid_hadamard_E", ["E"])
        keys(c, "druid_rotations", ["Q", "R"])
        # Operator gate
        keys(c, "operator_hat", ["9"], shot=False)
        keys(c, "operator_inspect_E", ["E"])
        # time scale
        keys(c, "timescale_faster", ["EQUAL", "EQUAL"])
        keys(c, "timescale_slower", ["MINUS", "MINUS"])
        keys(c, "resolution_shift", [{"key": "EQUAL", "shift": True}, {"key": "MINUS", "shift": True}], shot=False)
        # let the sim run a bit, then snapshot live state (esp. lookahead-on engine)
        snap(c, "time_skip_live", "time_skip", phrames=120, timeout_s=60)
        screenshot(c, "after_timeskip")
        snap(c, "batcher_metrics", "batcher_metrics")
        snap(c, "lindblad_snapshot", "lindblad_snapshot")

        # ============ PHASE 4: edge cases / stress ============
        # rapid ESC spam (overlay-stack underflow → should land on FarmView / open Z, not crash)
        keys(c, "esc_spam", ["ESCAPE"] * 6, settle=2)
        # reserved keys — must be no-ops
        keys(c, "reserved_keys", ["BACKSPACE", "BRACKETLEFT", "BRACKETRIGHT",
                                  "BACKSLASH", "SLASH", "QUOTELEFT", "COMMA", "PERIOD"], settle=2)
        # bulk select then mass harvest
        keys(c, "bulk_select_apostrophe", ["APOSTROPHE"])
        keys(c, "mass_harvest_shiftQ", [{"key": "Q", "shift": True}, {"key": "F"}])
        # rapid hat churn (incl. disabled)
        keys(c, "rapid_hat_churn", ["4", "5", "6", "7", "8", "9", "0"], settle=1, shot=False)
        screenshot(c, "after_hat_churn")
        # surface teleport while overlay open (M then Z without ESC)
        keys(c, "teleport_M", ["M"], shot=False)
        keys(c, "teleport_to_Z", ["Z"])
        keys(c, "teleport_to_N", ["N"])
        keys(c, "teleport_to_farm_esc", ["ESCAPE", "ESCAPE"], shot=False)
        # number hats while an overlay is open
        keys(c, "open_V_then_hats", ["V"], shot=False)
        keys(c, "hats_under_overlay", ["8", "0", "9"], settle=2)
        keys(c, "close_V", ["ESCAPE"], shot=False)
        screenshot(c, "final_state")

        # final live state
        snap(c, "final_full", "full_snapshot")

    finally:
        try:
            c.run_turn(9999, "stop", timeout_s=10)
        except Exception:
            pass
        c.terminate_listener(proc)

    # ============ error scan ============
    print("\n========== ENGINE LOG ERROR SCAN ==========")
    log_errs = []
    try:
        txt = log_path.read_text(errors="replace")
        for ln in txt.splitlines():
            if any(t in ln for t in ("SCRIPT ERROR", "ERROR:", "Cannot call", "Trying to",
                                     "Condition \"", "push_error", "nil ", "Invalid access",
                                     "out of bounds", "SEGV", "Signal", "crash")):
                log_errs.append(ln.strip())
    except OSError as e:
        log_errs.append(f"(could not read log: {e})")
    for e in log_errs[:60]:
        print("  ⚠", e)
    print(f"  ({len(log_errs)} flagged log lines)")

    print("\n========== TURN-RESULT ERRORS ==========")
    for s, d in errors:
        print(f"  ✗ [{s}] {d}")
    print(f"  ({len(errors)} turn errors)")

    print("\n========== NOTES ==========")
    for n in notes:
        print("  •", n)

    print(f"\nScreenshots: {SHOTS}  ({len(list(SHOTS.glob('*.png')))} png)")
    print(f"Lookahead: {'ON (live C++ engine)' if LOOKAHEAD_ON else 'off (GDScript stepper)'}")


if __name__ == "__main__":
    main()
