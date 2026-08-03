#!/usr/bin/env python3
"""Validate A1 (toast yields F to confirm chord) + A2 (full 6-plot ring).

A2a: pressing each plot key G..; lands the cursor on 0..5 (SEMICOLON no longer clamps to 4).
A2b: inject icons into Village until it reaches 6 qubits / 12 atoms (the 6th plot ; is usable).
A1 : arm a Cull (Captain Q) and confirm with a SINGLE F (no toast double-F needed).
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

    def qn(bn):
        return len(go("berry_state", biome=bn).get("qubits", []))

    def grid():
        g = go("grid_snapshot").get("grid", {})
        return g.get("biomes", g)

    def biome_key(name):
        for s in go("biome_slots").get("slots", []):
            if s.get("biome") == name:
                return s.get("key")
        return None

    def active():
        return go("biome_slots").get("active", "")

    def ist():
        return go("instrument_state")

    def ensure_hat(h):
        other = "7" if h != "7" else "8"
        press(other, 2); press(h, 2)

    def goto(name):
        bk = biome_key(name)
        for _ in range(4):
            if active() == name:
                return True
            press(bk, 3)
        return active() == name

    def bridge(emoji, amount):
        go("add_resource", emoji=emoji, amount=amount)

    def incorporate(bn, ripen=900):
        qs = go("berry_state", biome=bn).get("qubits", [])
        plots = PLOT[:len(qs)] if qs else PLOT
        ensure_hat("0")
        for pk in plots:
            press(pk, 3); press("E", 3)
        ensure_hat("5")
        trk = [bool(q.get("tracked")) for q in go("berry_state", biome=bn).get("qubits", [])]
        for i, pk in enumerate(plots):
            if i < len(trk) and not trk[i]:
                press(pk, 3); press("F", 3)
        go("time_skip", phrames=ripen)
        for pk in plots:
            press(pk, 3); press("R", 4)

    def plant_into(name):
        goto(name)
        nq = qn(name)
        ensure_hat("5")
        for pk in (PLOT[nq:] + PLOT):
            press(pk, 3); press("R", 4)
            if not go("submenu_state").get("in_submenu"):
                continue
            slots = go("submenu_state").get("slots", {})
            real = {k: v for k, v in slots.items() if v.get("north") and v.get("south")}
            if not real:
                press("ESCAPE", 2); continue
            k = ("Q" if "Q" in real else ("R" if "R" in real else list(real)[0]))
            v = real[k]
            bridge(str(v.get("south", "")), 12); bridge("🌱", 15)
            before = qn(name)
            for _ in range(3):
                press(k, 4)
                if qn(name) > before:
                    return True
                if not go("submenu_state").get("in_submenu"):
                    break
            press("ESCAPE", 2)
        return False

    try:
        c.wait_for_ready(proc, timeout_s=180)
        vk = biome_key("Village") or "Y"

        # ---- A2a: plot-key → cursor index (SEMICOLON must reach 5) ----
        print("=== A2a: plot ring indices (Village) ===")
        goto("Village"); ensure_hat("5")
        idxs = []
        for pk in PLOT:
            press(pk, 4)
            idxs.append(ist().get("current_plot_idx"))
            print(f"  {pk:10s} → plot_idx={idxs[-1]}")
        print(f"  RESULT A2a: SEMICOLON→{idxs[-1]} ({'OK (5)' if idxs[-1] == 5 else 'FAIL'})")

        # ---- A2b: inject Village to 6 qubits ----
        print("\n=== A2b: inject Village toward 6 qubits ===")
        fk = biome_key("StarterForest") or "T"
        goto("StarterForest")
        for _ in range(3):
            incorporate("StarterForest")
        goto("Village")
        for _ in range(3):
            incorporate("Village")
        print(f"  Village qubits before plant: {qn('Village')}")
        for n in range(1, 8):
            if qn("Village") >= 6:
                break
            if not plant_into("Village"):
                print(f"  plant #{n} FAILED at {qn('Village')} qubits"); break
            print(f"  plant #{n}: Village qubits now {qn('Village')}")
        print(f"  RESULT A2b: Village qubits={qn('Village')} ({'OK (>=6)' if qn('Village') >= 6 else 'SHORT'})")

        # ---- A1: single-F cull ----
        print("\n=== A1: single-F destructive confirm (Cull) ===")
        before = set(grid())
        bridge("🦅", 80)
        ensure_hat("7"); press("R", 6)  # discover something to cull
        new = [b for b in grid() if b not in before]
        if new:
            tgt = new[0]
            bridge("💀", 50)
            goto(tgt); ensure_hat("7")
            press("Q", 3)
            cs = go("confirm_state")
            print(f"  armed: pending={cs.get('pending', {}).get('label')} active={cs.get('active_biome')}")
            press("F", 4)  # SINGLE F — should confirm now that toast yields
            gone = tgt not in grid()
            print(f"  after single F: {tgt} {'REMOVED — OK' if gone else 'still present — FAIL'}")
        else:
            print("  (no biome discovered to cull; skipped)")
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
