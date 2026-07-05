#!/usr/bin/env python3
"""Fast-verify the two cost-gated mechanics the Act-4/5 driver depends on:
  - inject_icon (plant) with the 4×south + 10×🌱 cost bridged → qubit grows + atom lands.
  - remove_biome (cull) via Captain Q + F confirm with 34×💀 bridged → grid shrinks.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]
_turn = [10]


def t():
    _turn[0] += 1
    return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})

    def go(a, **k):
        k.pop("timeout_s", None)
        return c.run_turn(t(), a, timeout_s=90, **k)

    def press(seq, s=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=25)

    def grid():
        g = go("grid_snapshot").get("grid", {})
        return g.get("biomes", g)

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

    try:
        c.wait_for_ready(proc, timeout_s=180)
        vk = biome_key("Village") or "Y"

        # ---- INJECT with bridged cost ----
        print("=== INJECT (plant_first into Village, cost bridged) ===")
        press(vk)
        q0 = len(qstate("Village"))
        ensure_hat("5")
        planted = False
        for pk in (PLOT[q0:] + PLOT):
            press(pk, 3); press("R", 4)
            if not go("submenu_state").get("in_submenu"):
                continue
            slots = go("submenu_state").get("slots", {})
            # pick the first slot with a REAL icon (some slots are empty placeholders)
            real = [(k, v) for k, v in sorted(slots.items())
                    if v.get("north") and v.get("south")]
            if real:
                k, v = real[0]
                print(f"  offering {v.get('north')}/{v.get('south')} at slot {k}; bridging {v.get('south')}×12 + 🌱×15")
                bridge(str(v.get("south", "")), 12); bridge("🌱", 15)
                press(k, 4)
                planted = True
                break
            press("ESCAPE", 2)
        q1 = len(qstate("Village"))
        print(f"  Village qubits {q0} → {q1}  (inject {'OK' if q1 > q0 else 'FAILED'})")

        # ---- CULL with bridged 💀 ----
        print("\n=== CULL (discover a biome, then Captain Q+F with 💀 bridged) ===")
        before = set(grid())
        bridge("🦅", 80)
        ensure_hat("7"); press("R", 6)  # discover
        new = [b for b in grid() if b not in before]
        print(f"  discovered: {new}  grid={grid()}")
        if new:
            target = new[0]
            tk = biome_key(target)
            g_before = grid()
            bridge("💀", 50)
            press(tk); ensure_hat("7")
            cs0 = go("confirm_state")
            print(f"  pre-Q: frame={cs0.get('current_frame')} active={cs0.get('active_biome')} pending={cs0.get('pending')}")
            press("Q", 3)
            cs1 = go("confirm_state")
            print(f"  post-Q: frame={cs1.get('current_frame')} active={cs1.get('active_biome')} pending={cs1.get('pending')}")
            for fi in range(1, 5):
                press("F", 3)
                cs2 = go("confirm_state")
                print(f"  post-F#{fi}: pending={cs2.get('pending')} grid={grid()}")
                if target not in grid():
                    break
            g_after = grid()
            print(f"  CULL {'OK' if target not in g_after else 'FAILED'}")
        else:
            print("  no biome discovered to cull")
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
