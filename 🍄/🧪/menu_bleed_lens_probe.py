#!/usr/bin/env python3
"""Two input-routing laws, asserted live:

1. NO BLEED: with a full menu open (X>I Arc tab), the plot-ring keys GHJKL;
   belong to the menu. Pressing G must NOT select/reveal a plot bubble in the
   field behind (owner: "pressed G in X>I and the bubble appeared in the
   background"). The cursor-layer anchor runs only when a key actually falls
   through to gameplay.

2. B IS GLASS: with the B magnifier open, QERF still drives the active plot
   beneath (owner: "I CAN'T take actions while in the B menu"). R strikes and
   Q extracts must land in QII's dispatch ledger while B is up.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path("/home/primearchitect/ws/SpaceWheat/🍄") / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            allow_resource_injection=True)
    failures = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=40, **kw)

        def press(k, settle=8):
            return t("press_key", key=k, settle_frames=settle)

        def visible_bubbles():
            rows = t("bubble_state").get("bubbles", [])
            return [b for b in rows if b.get("visible")]

        def ledger(clear=False):
            return t("dispatch_ledger", clear=clear).get("ledger", [])

        # Strike/extract costs are real (raw economy) — seed the wallet.
        t("add_resource", emoji="🍞", amount=30)
        t("add_resource", emoji="👥", amount=30)

        # ---- LAW 1: G in X>I must not touch the field ----
        before = visible_bubbles()
        press("x", settle=10)
        press("i", settle=10)
        ledger(clear=True)
        for _ in range(3):
            press("g", settle=6)
        after_menu = visible_bubbles()
        menu_dispatches = [e for e in ledger() if e.get("success")]
        press("escape", settle=10)
        if len(after_menu) != len(before):
            failures.append("BLEED: G in X>I changed visible bubbles %d → %d"
                            % (len(before), len(after_menu)))
        if menu_dispatches:
            failures.append("BLEED: G in X>I dispatched gameplay actions: %s"
                            % json.dumps(menu_dispatches))
        print("law1: bubbles %d → %d, dispatches in menu: %d"
              % (len(before), len(after_menu), len(menu_dispatches)))

        # Sanity: the same key in the FIELD does select/reveal (mechanism alive).
        press("g", settle=8)
        field_after = visible_bubbles()
        if len(field_after) <= len(before):
            failures.append("SANITY: G in the field revealed nothing (%d → %d)"
                            % (len(before), len(field_after)))
        print("sanity: field G reveals %d → %d" % (len(before), len(field_after)))

        # ---- LAW 2: QERF drives the plot while B is open ----
        press("b", settle=12)
        stack = t("ui_stack").get("stack", [])
        print("stack with B:", [s.get("name") for s in stack])
        ledger(clear=True)
        press("f", settle=10)   # explore the selected plot (expedition, 🍞)
        press("r", settle=10)   # strike (measure) it (👥)
        press("q", settle=10)   # extract it (free)
        lens_entries = ledger()
        acted = [e for e in lens_entries if e.get("success")]
        press("escape", settle=8)
        if not acted:
            failures.append("B-GLASS: no successful QERF dispatch while B open: %s"
                            % json.dumps(lens_entries))
        print("law2: dispatches under B:", json.dumps(lens_entries))

    finally:
        c.terminate_listener(proc)

    print("\n== FAILURES (%d) ==" % len(failures))
    for f in failures:
        print(" -", f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
