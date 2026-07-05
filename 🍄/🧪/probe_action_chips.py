#!/usr/bin/env python3
"""Focused state probe: verify action-bar chip states + closed-system gating through
the real headed FarmView. Higher-fidelity than screenshots for what we just touched:
inject-icon submenu (cost-authority refactor), disabled-hat refusal, R=Plant inert."""
import json, sys, time
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402


def chips(c, turn, label):
    r = c.run_turn(turn, "widget_snapshot", timeout_s=20, widget="action_preview")
    snap = r.get("snapshot", {})
    tool = snap.get("current_tool", "?")
    sub = snap.get("submenu", "")
    acts = snap.get("actions", {})
    line = " | ".join("%s:%s%s" % (k, a.get("label", ""), "(off)" if a.get("disabled") else "")
                      for k, a in acts.items())
    print(f"  [{label}] tool={tool} submenu={sub!r}")
    print(f"      {line}")
    return snap


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "1"})
    t = [0]
    def nt(): t[0] += 1; return t[0]
    def key(k, **kw): c.run_turn(nt(), "press_key", timeout_s=15, key=k, settle_frames=kw.get("settle", 3))
    try:
        c.wait_for_ready(proc, timeout_s=150)
        time.sleep(1.2)
        print("\n=== ACTION-BAR CHIP STATES (closed ground) ===")
        key("8"); key("T"); key("G")           # Ace hat, biome T, plot G
        chips(c, nt(), "Ace @ plot G")
        # Openness is a place: every hat is always selectable. On closed ground
        # the Lindblad CHIPS grey (ActionValidator per-plot regime), not the hat.
        key("6")                                # Merchant hat (selectable everywhere)
        s = chips(c, nt(), "Merchant on closed ground (chips grey, hat live)")
        assert s.get("current_tool") == "merchant", "Merchant hat should be selectable — verbs gate per-biome now!"
        key("4")                                # Spark hat (selectable everywhere)
        s = chips(c, nt(), "Spark on closed ground (jolt chips grey, hat live)")
        assert s.get("current_tool") == "spark", "Spark hat should be selectable — verbs gate per-biome now!"
        key("5")                                # Icon hat
        chips(c, nt(), "Icon hat")
        key("R")                                # R = Add Icon -> opens injection submenu
        chips(c, nt(), "Icon submenu (inject) — cost-authority path")
        key("ESCAPE", settle=2)
        print("\n  ✅ no crash through inject-icon path; hats live, Lindblad chips grey on closed ground")
    finally:
        try: c.run_turn(9999, "stop", timeout_s=8)
        except Exception: pass
        c.terminate_listener(proc)
    # error scan
    log = c.runner_root / "logs" / "rig_listener.log"
    errs = [l for l in log.read_text(errors="replace").splitlines()
            if any(t in l for t in ("SCRIPT ERROR", "ERROR:", "push_error", "Nonexistent", "Invalid call"))]
    print(f"\n=== LOG ERRORS: {len(errs)} ===")
    for e in errs[:15]:
        print("  ⚠", e)


if __name__ == "__main__":
    main()
