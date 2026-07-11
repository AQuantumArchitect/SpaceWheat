#!/usr/bin/env python3
"""Headed: one-finger core loop — tap measures, tap again pops.

The tap is routed through QII.handle_bubble_tap (the SAME validator +
_run_action tail as the keyboard — one mechanics authority). This probe
drives it with REAL synthetic InputEventMouseButton events via the rig
`tap` action, so the full TouchInputManager → QuantumForceGraph →
FarmView → QII chain is exercised.

Asserts:
  1. After press G (select+reveal plot 0), the bubble is live (no terminal).
  2. TAP 1 on the bubble → measured (terminal exists) — tap = Strike.
  3. TAP 2 on the bubble → back to live + wallet grew — tap = Extract.
  4. Keyboard parity afterwards: G/R/Q still measure+pop (anti-gating held).

Shots: tap_live.png, tap_measured.png, tap_popped.png
"""
import sys
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    log_path = HERE.parent.parent / "logs" / "tap_to_farm_listener.log"
    out_dir = HERE.parent.parent / "logs"
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            listener_log_path=log_path, rig_log_profile="debug",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})
    failures = []
    try:
        ready = c.wait_for_ready(proc, timeout_s=200)
        print("ready:", ready)

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=25, **kw)

        def press(k, shift=False, settle=6):
            return t("press_key", key=k, shift=shift, settle_frames=settle)

        def bubble_at(pos):
            bs = t("bubble_state")
            for b in bs.get("bubbles", []):
                if b.get("pos") == list(pos):
                    return b
            return None

        def wallet():
            rs = t("resource_snapshot")
            res = rs.get("resources", {})
            if isinstance(res, dict) and "resources" in res:
                res = res["resources"]
            return dict(res) if isinstance(res, dict) else {}

        def shot(name):
            r = t("screenshot", path="user://rig/%s.png" % name, settle_frames=4)
            sc = r.get("screenshot", {})
            abs_path = sc.get("abs", "")
            print("shot %s -> saved=%s" % (name, sc.get("saved")))
            if abs_path and Path(abs_path).exists():
                shutil.copy(abs_path, out_dir / ("%s.png" % name))
            return r

        def check(cond, label):
            print(("PASS " if cond else "FAIL ") + label)
            if not cond:
                failures.append(label)

        # Superposition so measure outcomes are non-trivial, then select+reveal
        # plot 0 by keyboard (the tile tap is PlotGridDisplay's lane; this probe
        # targets the BUBBLE tap lane).
        hg = t("gate_inject", gate="hadamard", biome="StarterForest", positions=[])
        print("hadamard ok:", hg.get("ok"))
        press("g", settle=8)
        # F/R/Q grammar (owner 2026-07-11): the expedition binds the register
        # first; the tap beats after that are strike → extract.
        press("f", settle=10)

        b0 = bubble_at((0, 0)) or bubble_at((0, 1))
        # Resolve the actual revealed plot-0 bubble in the ACTIVE biome.
        if b0 is None:
            bs = t("bubble_state")
            vis = [b for b in bs.get("bubbles", []) if b.get("visible")]
            b0 = vis[0] if vis else None
        check(b0 is not None, "plot-0 bubble revealed after G")
        if b0 is None:
            return 1
        pos = b0["pos"]
        check(not b0.get("measured", True), "bubble starts LIVE (no terminal)")
        shot("tap_live")

        # TAP 1 → measure (Strike)
        r1 = t("tap", pos=pos, settle_frames=14)
        print("tap1:", r1.get("ok"), r1.get("tapped"))
        b_after1 = bubble_at(pos)
        check(bool(b_after1 and b_after1.get("measured")), "tap 1 measured the bubble")
        ist = t("instrument_state")
        sel = ist.get("instrument", ist)
        print("selection after tap:", {k: sel.get(k) for k in ("current_plot_idx", "current_biome") if isinstance(sel, dict)})
        shot("tap_measured")

        # TAP 2 → pop (Extract): bubble back to live + SOME resource increased
        # (the pop pays in one emoji; measure costs may drain others, so the
        # NET wallet can shrink — the payout landing is what we assert).
        w_before = wallet()
        r2 = t("tap", pos=pos, settle_frames=14)
        print("tap2:", r2.get("ok"), r2.get("tapped"))
        b_after2 = bubble_at(pos)
        w_after = wallet()
        gained = {k: int(w_after.get(k, 0)) - int(w_before.get(k, 0))
                  for k in set(w_before) | set(w_after)
                  if int(w_after.get(k, 0)) > int(w_before.get(k, 0))}
        check(bool(b_after2 is not None and not b_after2.get("measured")), "tap 2 cleared back to live")
        check(bool(gained), "tap 2 paid out (gained: %s)" % (gained,))
        shot("tap_popped")

        # Keyboard parity (anti-gating): F explores, R measures, Q pops, on the
        # same plot. (tap 2's pop released the terminal — the plot is unbound.)
        press("f", settle=10)
        press("r", settle=12)
        bk = bubble_at(pos)
        check(bool(bk and bk.get("measured")), "keyboard R still measures")
        press("q", settle=12)
        bk2 = bubble_at(pos)
        check(bool(bk2 is not None and not bk2.get("measured")), "keyboard Q still pops")

    finally:
        c.terminate_listener(proc)

    print("\n%s — %d failure(s)" % ("GREEN" if not failures else "RED", len(failures)))
    for f in failures:
        print("  FAIL:", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
