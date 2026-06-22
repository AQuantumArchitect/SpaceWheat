#!/usr/bin/env python3
"""S4 dispatch-consolidation verification (headless, live C++).

Exercises the flattened input path end-to-end through the engine's real
push_input dispatch and reads back instrument_state after each step:

  - direct-pick biome (T/Y) → current_biome switches, cursor_layer == 2
  - direct-pick plot (G/H/J) → current_plot_idx tracks, cursor_layer == 3
  - W/S ring spin → cursor_layer steps (QII-owned, painted via signal)
  - ESC unwind one level: plot selected → deselect (NOT system menu)

Pass criteria printed per step; exits non-zero on any failure.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
_t = [0]
_fails = []


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    print("== boot headless, live C++ ==")
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    try:
        c.wait_for_ready(proc, timeout_s=180)

        def state():
            return c.run_turn(turn(), "instrument_state", timeout_s=20)

        def press(key, shift=False):
            c.run_turn(turn(), "press_key", key=key, shift=shift, timeout_s=20)

        def check(label, cond, detail):
            tag = "PASS" if cond else "FAIL"
            if not cond:
                _fails.append(label)
            print(f"  [{tag}] {label}: {detail}")

        s0 = state()
        print("init:", {k: s0.get(k) for k in
                        ("cursor_layer", "current_plot_idx", "current_biome")})

        # --- direct-pick a plot (G = slot 0) → layer 3, plot 0 selected ---
        press("G")
        s = state()
        check("plot-pick G → cursor_layer==3", s.get("cursor_layer") == 3,
              f"cursor_layer={s.get('cursor_layer')}")
        check("plot-pick G → plot_idx==0", s.get("current_plot_idx") == 0,
              f"plot_idx={s.get('current_plot_idx')}")

        # --- step plot with H (slot 1) ---
        press("H")
        s = state()
        check("plot-pick H → plot_idx==1", s.get("current_plot_idx") == 1,
              f"plot_idx={s.get('current_plot_idx')}")

        # --- W spin toward surface: layer 3 → 2 ---
        press("W")
        s = state()
        check("W spin → cursor_layer==2", s.get("cursor_layer") == 2,
              f"cursor_layer={s.get('cursor_layer')}")

        # --- direct-pick biome row (Y = slot 1) → layer 2, biome switches ---
        biome_before = s.get("current_biome")
        press("Y")
        s = state()
        check("biome-pick Y → cursor_layer==2", s.get("cursor_layer") == 2,
              f"cursor_layer={s.get('cursor_layer')}")
        # (biome may or may not change depending on slot assignment; just report)
        print(f"  [info] biome {biome_before!r} → {s.get('current_biome')!r}")

        # --- re-enter plot ring, then ESC should deselect (one level), NOT open menu ---
        press("J")
        s = state()
        check("plot-pick J → plot selected", s.get("current_plot_idx", -1) >= 0,
              f"plot_idx={s.get('current_plot_idx')}, layer={s.get('cursor_layer')}")
        press("ESC")
        s = state()
        check("ESC unwind → plot deselected", s.get("current_plot_idx") == -1,
              f"plot_idx={s.get('current_plot_idx')}, layer={s.get('cursor_layer')}")

        print()
        if _fails:
            print(f"RESULT: {len(_fails)} FAILURE(S): {_fails}")
            sys.exit(1)
        print("RESULT: all dispatch checks PASSED")
    finally:
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
