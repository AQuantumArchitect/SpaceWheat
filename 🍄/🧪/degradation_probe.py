#!/usr/bin/env python3
"""Degradation forensics: play like the owner for N rounds, watch input health.

Owner report (2026-07-11): 'bugs accumulate over play. it always works fine
when you open it. the problem is over time as i take actions the behavior
degrades' — keyboard keeps working, mouse dies, taps pierce overlays.

Each round: measure/pop a bubble, cycle overlays (C, B, V, M), switch biomes,
open the escape menu. After each round, assert the mouse still works:
  - menu verb chip click still opens the quit confirm
  - action-bar chip click still fires a verb
  - overlay stack holds no invisible ghosts above PlayBase
Prints the first round where anything breaks, with the stack contents.
"""
import sys
import shutil
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

ROUNDS = 6
_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    out = HERE.parent.parent / "logs"
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            listener_log_path=out / "degradation.log",
                            rig_log_profile="debug")
    failures = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=30, **kw)

        def press(k, settle=8):
            return t("press_key", key=k, settle_frames=settle)

        def check(cond, label):
            print(("PASS " if cond else "FAIL ") + label)
            if not cond:
                failures.append(label)
            return cond

        def stack():
            s = t("ui_stack")
            return s.get("stack", [])

        def ghosts():
            st = stack()
            return [e for e in st[1:] if not e.get("visible")]  # above PlayBase

        def bubble(pos):
            bs = t("bubble_state")
            for b in bs.get("bubbles", []):
                if b.get("pos") == list(pos):
                    return b
            return None

        def mouse_health(round_no):
            ok = True
            # 1) Escape menu: open by key, click Q chip → confirm appears
            press("z", settle=14)
            q = t("control_rect", name="MenuVerb_Q")
            if q.get("center") and q.get("visible"):
                t("tap", screen=q["center"], settle_frames=10)
                lbl = t("control_rect", name="EscapeMenu")
                ok = check(bool(lbl.get("visible")), "r%d: menu alive after Q-chip click" % round_no) and ok
                press("e", settle=8)   # cancel confirm
            else:
                ok = check(False, "r%d: MenuVerb_Q not visible/clickable" % round_no)
            press("z", settle=12)      # close menu

            # 2) stack hygiene: base intact, no ghosts above it
            st = stack()
            ok = check(bool(st) and st[0]["name"] == "PlayBase",
                       "r%d: PlayBase still the stack base (stack: %s)" % (round_no, [e["name"] for e in st])) and ok
            g = ghosts()
            ok = check(not g, "r%d: no ghost overlays above base (found: %s)" % (round_no, [e["name"] for e in g])) and ok

            # 3) GAMEPLAY action-bar click: [R] Strike chip must fire the verb.
            # Seed the verb costs first (🍞 explore / 👥 strike, owner ruling
            # 2026-07-11) — an economy refusal is NOT input death (that
            # conflation hid the double-dispatch bug).
            t("add_resource", emoji="🍞", amount=40)
            t("add_resource", emoji="👥", amount=40)
            press("g", settle=6)
            b_before = bubble([0, 0])
            if b_before is not None and b_before.get("measured"):
                press("q", settle=8)  # clear to live first (pop releases the terminal)
                b_before = bubble([0, 0])
            # F/R/Q grammar: explore AFTER the clear — pop unbinds, and F on a
            # bound plot is fast-forward, not explore.
            press("f", settle=8)
            r_chip = t("control_rect", name="ActionBtn_R")
            if r_chip.get("center") and r_chip.get("visible"):
                t("dispatch_ledger", clear=True)  # arm exactly-once check
                t("tap", screen=r_chip["center"], settle_frames=12)
                b_after = bubble([0, 0])
                ok = check(bool(b_after and b_after.get("measured")),
                           "r%d: action-bar [R] click strikes (mouse gameplay verbs alive)" % round_no) and ok
                # EXACTLY-ONCE: one click must produce exactly one verb
                # dispatch. Two entries = the double-dispatch slop class,
                # caught directly instead of inferred from wallet drain.
                led = t("dispatch_ledger").get("ledger", [])
                ok = check(len(led) == 1,
                           "r%d: one click == one dispatch (ledger: %s)" % (round_no, led)) and ok
                press("q", settle=8)  # pop back to live for next round
            else:
                ok = check(False, "r%d: ActionBtn_R not visible/clickable" % round_no)

            # 4) Piercing: with the quest board open, a bubble tap must be inert
            press("c", settle=12)
            b0 = bubble([0, 0])
            if b0 is not None:
                t("tap", pos=[0, 0], settle_frames=10)
                b1 = bubble([0, 0])
                ok = check(bool(b1) and b1.get("measured") == b0.get("measured"),
                           "r%d: bubble tap behind quest board is inert" % round_no) and ok
            press("c", settle=10)  # close board
            return ok

        # Baseline
        t("gate_inject", gate="hadamard", biome="StarterForest", positions=[])
        press("g", settle=8)
        mouse_health(0)

        for r in range(1, ROUNDS + 1):
            # Play: measure + pop by tap (bubble 0)
            bs = t("bubble_state")
            vis = [b for b in bs.get("bubbles", []) if b.get("visible")]
            if vis:
                pos = vis[0]["pos"]
                t("tap", pos=pos, settle_frames=10)
                t("tap", pos=pos, settle_frames=10)
            # Overlay churn: C quests, B microscope, V atlas, M map
            for key in ["c", "c", "b", "b", "v", "v", "m", "m"]:
                press(key, settle=8)
            # Biome hops
            for key in ["y", "u", "t"]:
                press(key, settle=8)
            print("--- round %d stack: %s" % (r, [e["name"] for e in stack()]))
            mouse_health(r)

    finally:
        c.terminate_listener(proc)

    print("\n%s — %d failure(s)" % ("GREEN" if not failures else "RED", len(failures)))
    for f in failures:
        print("  FAIL:", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
