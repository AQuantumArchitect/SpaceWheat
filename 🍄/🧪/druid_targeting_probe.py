#!/usr/bin/env python3
"""Druid gate targeting: every slot gates ITS OWN qubit, or refuses loudly.

Owner report (playtest 2, 2026-07-11): "if i spin the qubit on 'J' it spins
the sun/moon despite displaying the Skull". Root cause: gate targeting wrapped
out-of-range slots with posmod(slot_index, num_qubits), silently spinning a
DIFFERENT plot's qubit than the bubble on screen. Fixed by PlotRegisterResolver
(ONE slot→qubit authority, column law, bounded, never wrapped) shared by the
display seeder, GateActionHandler, and LindbladHandler.

Per biome, per plot slot (G H J K L ;):
  - valid slot k  → druid R+E must move register k's bloch z MORE than any
    other register, and the dispatch ledger records successful verbs.
  - ghost slot (column ≥ num_qubits) → NO register moves and the ledger
    records the refusal (success=false, honest message via toast in-game).
Also asserts display/gate agreement via the plot_register_map diagnostic.
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

SLOT_KEYS = [("g", None), ("h", None), ("j", None), ("k", None), ("l", None), (None, 59)]  # ; = KEY_SEMICOLON
_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless")
    failures = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=30, **kw)

        def press(k=None, keycode=None, settle=8):
            if keycode is not None:
                return t("press_key", keycode=keycode, settle_frames=settle)
            return t("press_key", key=k, settle_frames=settle)

        def check(cond, label):
            print(("PASS " if cond else "FAIL ") + label)
            if not cond:
                failures.append(label)
            return cond

        def bloch_z(biome):
            r = t("viz_bloch", biome=biome)
            return [q.get("live_z", 999.0) for q in r.get("qubits", [])]

        # 0) Structural agreement: display and gate share the ONE authority.
        rows = t("plot_register_map").get("rows", [])
        bad = [r for r in rows if not r.get("agrees")]
        check(rows and not bad, "display == gate for all %d plots (bad: %s)" % (
            len(rows), [(r.get("pos"), r.get("biome")) for r in bad]))

        # Pause the sim (E peek) so bloch deltas come from OUR gates only,
        # then put on the druid hat (0). Seed the rotate costs (⛰/🏜) —
        # an economy refusal is honest feedback, not a targeting failure.
        press(k="e", settle=8)
        press(k="0", settle=8)
        t("add_resource", emoji="⛰", amount=100)
        t("add_resource", emoji="🏜", amount=100)

        # biome key ring: [{slot, key, biome}]
        slots = t("biome_slots").get("slots", [])
        biome_keys = {s["biome"]: str(s["key"]).lower() for s in slots if s.get("biome") and s.get("key")}
        for biome, bkey in sorted(biome_keys.items()):
            press(k=bkey, settle=8)
            z0 = bloch_z(biome)
            nq = len(z0)
            if nq == 0:
                check(False, "%s exposes no qubits via viz_bloch" % biome)
                continue
            for col, (skey, skcode) in enumerate(SLOT_KEYS):
                press(k=skey, keycode=skcode, settle=6)
                t("dispatch_ledger", clear=True)
                before = bloch_z(biome)
                press(k="r", settle=8)   # rotate_up
                press(k="e", settle=8)   # hadamard (E peek re-pauses, harmless)
                led = t("dispatch_ledger").get("ledger", [])
                after = bloch_z(biome)
                deltas = [abs(a - b) for a, b in zip(after, before)]
                if col < nq:
                    moved = max(range(nq), key=lambda i: deltas[i])
                    ok_move = deltas[moved] > 1e-9 and moved == col
                    check(ok_move, "%s slot %d gates its own qubit (deltas=%s)" % (
                        biome, col, ["%.2e" % d for d in deltas]))
                    check(led and all(e.get("success") for e in led),
                          "%s slot %d verbs dispatched clean (ledger=%s)" % (biome, col, led))
                else:
                    ghost_still = max(deltas) < 1e-9 if deltas else True
                    check(ghost_still, "%s ghost slot %d moves NOTHING (deltas=%s)" % (
                        biome, col, ["%.2e" % d for d in deltas]))
                    check(led and all(not e.get("success") for e in led),
                          "%s ghost slot %d refuses LOUDLY (ledger=%s)" % (biome, col, led))

    finally:
        c.terminate_listener(proc)

    print("\n%s — %d failure(s)" % ("GREEN" if not failures else "RED", len(failures)))
    for f in failures:
        print("  FAIL:", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
