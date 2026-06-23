#!/usr/bin/env python3
"""Verify the KEYBOARD market now supplies 🔨 after routing _adapt_contracts_for_view
through QuestPipeline.from_market_contract. Fresh boot, drive C→Y market by keyboard,
accept+complete, watch 🔨 + 🍞/👥 deltas. No arc needed."""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

SCEN = os.environ.get("PT_SCENARIO", "demos_normal")
os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT_KEYS = ["G", "H", "J", "K", "L", "SEMICOLON"]
_turn = [10]


def t():
    _turn[0] += 1
    return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id=SCEN, display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    def go(action, **kw):
        kw.pop("timeout_s", None)
        return c.run_turn(t(), action, timeout_s=60, **kw)

    def press(seq, settle=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            c.run_turn(t(), "press_key", key=k, settle_frames=settle, timeout_s=25)

    def res():
        r = go("resource_snapshot").get("resources") or {}
        if isinstance(r, dict) and isinstance(r.get("resources"), dict):
            r = r["resources"]
        return r

    try:
        c.wait_for_ready(proc, timeout_s=180)
        press("Y")  # Village active
        r0 = res()
        print("start: 🔨=%d 🍞=%d 👥=%d" % (r0.get("🔨", 0), r0.get("🍞", 0), r0.get("👥", 0)))
        for rnd in range(1, 9):
            press("C"); press("Y", settle=3)     # Market frame
            press("E", settle=3)                  # refresh pool
            for pk in PLOT_KEYS:                   # accept every visible offer
                press(pk, settle=2); press("R", settle=3)
            press("ESCAPE", settle=3)
            go("time_skip", phrames=40)
            press("C"); press("U", settle=3)      # Commitments
            for pk in PLOT_KEYS:                   # complete deliverable ones
                press(pk, settle=2); press("R", settle=4)
            press("ESCAPE", settle=3)
            r = res()
            print("[r%d] 🔨=%d 🍞=%d 👥=%d ⚙=%d 💨=%d" % (
                rnd, r.get("🔨", 0), r.get("🍞", 0), r.get("👥", 0), r.get("⚙", 0), r.get("💨", 0)))
            if r.get("🔨", 0) >= 13:
                print("  ✓ reached 13 🔨"); break
        print("FINAL:", res())
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
