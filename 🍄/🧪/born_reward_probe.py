#!/usr/bin/env python3
"""PT6 laws: the die is honest, the price is visible, extract pops home.

  A. CHIP COSTS — with a plot focused, the Ace bar shows Explore/Strike with
     numeric cost labels (playtest 6: "all the actions need to display costs").
  B. EXTRACT → UNEXPLORED — F/R/Q on a plot ends with the bubble hidden and
     the plot absent from farm.revealed_plots; F re-explores and re-reveals.
  C. BORN HONESTY — repeated explore→measure→pop cycles on TheDemos register 0
     produce BOTH poles (the frozen-seed bug collapsed the same pole forever),
     and at least one pop pays more than the +1 floor.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path("/home/primearchitect/ws/SpaceWheat/🍄") / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            allow_resource_injection=True)
    fails = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            _t[0] += 1
            return c.run_turn(_t[0], action, timeout_s=60, **kw)

        def press(k, settle=8):
            return t("press_key", key=k, settle_frames=settle)

        t("add_resource", emoji="🍞", amount=500)
        t("add_resource", emoji="👥", amount=500)

        # ---- LAW A: chip costs visible on the Ace bar --------------------
        press("t", settle=10)   # TheDemos active
        press("g", settle=10)   # focus plot 0 (reveals)
        bar = t("overlay_text", under="ActionPreviewRow")
        texts = [str(x.get("text", x)) if isinstance(x, dict) else str(x)
                 for x in bar.get("lines", [])]
        print("action bar:", texts)
        joined = " | ".join(texts)
        if "Explore" not in joined:
            fails.append("Ace F chip does not read Explore on unexplored plot: %s" % joined)
        if not any(tx.strip().isdigit() for tx in texts):
            fails.append("no whole-number cost label on the action bar: %s" % joined)

        # ---- LAW B: extract pops the bubble back to unexplored ------------
        def demos_bubble():
            bs = t("bubble_state")
            for b in bs.get("bubbles", []):
                if b.get("biome") == "TheDemos" and int(b.get("register_id", -1)) == 0:
                    b["_revealed_set"] = bs.get("revealed_plots", [])
                    return b
            return {}

        press("f", settle=10)   # explore (bind)
        b1 = demos_bubble()
        pos = b1.get("pos", [-1, -1])
        if not b1.get("visible", False) or pos not in b1.get("_revealed_set", []):
            fails.append("explored plot not visible/revealed: %s" % json.dumps(b1)[:200])
        press("r", settle=10)   # strike (measure)
        press("q", settle=12)   # extract (pop)
        b2 = demos_bubble()
        if b2.get("visible", True):
            fails.append("bubble still visible after extract: %s" % json.dumps(b2)[:200])
        if pos in b2.get("_revealed_set", []):
            fails.append("plot still in revealed_plots after extract")
        press("f", settle=10)   # re-explore re-reveals
        b3 = demos_bubble()
        if not b3.get("visible", False):
            fails.append("re-explore after extract did not re-reveal the bubble")
        press("r", settle=8)
        press("q", settle=8)    # leave the register unbound for LAW C

        # ---- LAW C: Born honesty + reward chain ---------------------------
        ki = t("known_icons")
        print("known_icons:", json.dumps(ki.get("known_icons", ki.get("icons", [])),
                                         ensure_ascii=False)[:200])
        outcomes = {}
        rewards = []
        probs = []
        for i in range(40):
            r = t("probe_cycle", biome="TheDemos").get("probe", {})
            if not r.get("success", False):
                # refill and retry once per failure kind
                t("add_resource", emoji="👥", amount=200)
                t("add_resource", emoji="🍞", amount=200)
                r = t("probe_cycle", biome="TheDemos").get("probe", {})
                if not r.get("success", False):
                    fails.append("probe_cycle failed at %d: %s" % (i, json.dumps(r)[:200]))
                    break
            m = r.get("measure", {})
            p = r.get("pop", {})
            out = str(m.get("outcome", "?"))
            outcomes[out] = outcomes.get(out, 0) + 1
            probs.append(float(m.get("probability", -1)))
            rewards.append((out, round(float(m.get("probability", -1)), 3),
                            int(p.get("amount", 0))))
            t("time_skip", phrames=90)  # let H re-spread before the next strike

        print("outcome histogram:", json.dumps(outcomes, ensure_ascii=False))
        print("samples (outcome, p, amount):", rewards[:20])
        mean_p = sum(probs) / max(1, len(probs))
        print("mean recorded p=%.3f over %d cycles" % (mean_p, len(probs)))
        if len(outcomes) < 2 and 0.10 <= mean_p <= 0.90:
            fails.append("Born sampler still frozen: %d cycles, one outcome %s at mean p=%.2f"
                         % (len(probs), list(outcomes.keys()), mean_p))
        if rewards and max(a for (_, _, a) in rewards) <= 1:
            fails.append("every pop paid the +1 floor across %d cycles (reward chain dead)"
                         % len(rewards))
    finally:
        c.terminate_listener(proc)

    print("\n== FAILS (%d) ==" % len(fails))
    for f in fails:
        print(" -", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
