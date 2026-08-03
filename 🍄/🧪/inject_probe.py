#!/usr/bin/env python3
"""Nail icon injection (plant) into Village under the toast-intercept bug.

PlayerShell eats E (pause-decay) and F (flatten) when a toast is live, so an inject
submenu slot on E is never selected (Mill@Q worked, wood@E didn't). Strategy tested here:
  - clear toasts (F on an EMPTY plot — flattens topmost toast or no-ops) BEFORE opening
    the submenu, so E/R/Q slots all select cleanly;
  - prefer the Q slot for "any icon" plants;
  - verify the qubit count actually grew (don't trust a slot press).
Learns icons first (incorporate StarterForest + Village), then plants several into Village.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402
from turn_driver import TurnDriver  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]
# Historical per-script driver timeouts — deliberately NOT unified (SLOP_PATROL knot #8).
GO_TIMEOUT_S = 90
PRESS_TIMEOUT_S = 25
PRESS_SETTLE_FRAMES = 4

_driver = TurnDriver(start=10)


t = _driver.t


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S)

    press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)

    def qstate(bn):
        return go("berry_state", biome=bn).get("qubits", [])

    def active_biome():
        return go("biome_slots").get("active", "")

    def biome_key(name):
        for s in go("biome_slots").get("slots", []):
            if s.get("biome") == name:
                return s.get("key")
        return None

    def ensure_hat(h):
        other = "7" if h != "7" else "8"
        press(other, 2); press(h, 2)

    def bridge(emoji, amount):
        go("add_resource", emoji=emoji, amount=amount)

    def incorporate(bn, ripen=900):
        qs = qstate(bn)
        plots = PLOT[:len(qs)] if qs else PLOT
        ensure_hat("0")
        for pk in plots:
            press(pk, 3); press("E", 3)
        ensure_hat("5")
        trk = [bool(q.get("tracked")) for q in qstate(bn)]
        for i, pk in enumerate(plots):
            if i < len(trk) and not trk[i]:
                press(pk, 3); press("F", 3)
        go("time_skip", phrames=ripen)
        for pk in plots:
            press(pk, 3); press("R", 4)

    def clear_toasts(empty_pk):
        # F on an empty plot flattens the topmost toast (PlayerShell consumes it) or no-ops.
        press(empty_pk, 2)
        for _ in range(3):
            press("F", 2)

    def select_slot(slot_key, bn):
        before = len(qstate(bn))
        for _ in range(4):
            press(slot_key, 4)
            if len(qstate(bn)) > before:
                return True
            if not go("submenu_state").get("in_submenu"):
                return False
        return len(qstate(bn)) > before

    def plant_any(bk, prefer="Q"):
        press(bk)
        bn = active_biome()
        nq = len(qstate(bn))
        ensure_hat("5")
        empties = PLOT[nq:] if nq < len(PLOT) else []
        for pk in (empties + PLOT):
            clear_toasts(pk)
            press(pk, 3); press("R", 4)
            if not go("submenu_state").get("in_submenu"):
                continue
            slots = go("submenu_state").get("slots", {})
            real = {k: v for k, v in slots.items() if v.get("north") and v.get("south")}
            if not real:
                press("ESCAPE", 2); continue
            order = [prefer] + [k for k in ("Q", "R", "E") if k != prefer]
            order = [k for k in order if k in real] or list(real.keys())
            k = order[0]
            v = real[k]
            bridge(str(v.get("south", "")), 12); bridge("🌱", 15)
            if select_slot(k, bn):
                print(f"    planted {v.get('north')}/{v.get('south')} via slot {k} → qubits now {len(qstate(bn))}")
                return True
            press("ESCAPE", 2)
        print("    ✗ plant failed")
        return False

    try:
        c.wait_for_ready(proc, timeout_s=180)
        # learn icons
        fk = biome_key("StarterForest") or "T"
        press(fk)
        for _ in range(3):
            incorporate("StarterForest")
        vk = biome_key("Village") or "Y"
        press(vk)
        for _ in range(3):
            incorporate("Village")
        known = go("known_icons").get("icons", [])
        print("known icons:", [f"{i.get('north')}/{i.get('south')}" for i in known])

        print("\n=== plant 4 icons into Village (clear-toast + verify) ===")
        for n in range(1, 5):
            q0 = len(qstate("Village"))
            ok = plant_any(vk)
            q1 = len(qstate("Village"))
            print(f"  plant #{n}: qubits {q0}→{q1}  {'OK' if q1 > q0 else 'FAIL'}")
            if q1 == q0:
                break
        print(f"\nFINAL Village qubits: {len(qstate('Village'))}")
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
