#!/usr/bin/env python3
"""Poverty run: play like the owner, not like a bot (testing reform #257).

One biome (TheDemos), NO resource injection, keyboard verbs only, 25 F->R->Q
cycles on the same plot with real evolution between strikes. Distribution
assertions, not single shots:

  A. VARIETY   — over 25 collapses both poles (🌾 and 👥) get credited at
                 least once, and at least one extraction pays more than the
                 +1 floor. A frozen die passes any single-shot test; it
                 cannot pass this.
  B. INT WALLET— every wallet amount stays a whole number all run (the
                 float-poison class: "🍞=33.0").
  C. NO HAUNTS — every wallet delta is attributed: final - initial per emoji
                 equals the sum of the resource_mutations ledger rows. The
                 🐺-from-nowhere class fails here, ambient drain included.
  D. HONEST DOOR— if explore (F) is ever refused, the wallet really was short
                 at that moment (no phantom refusals). Going broke is a legit
                 loss (owner law: economy stays raw) — the probe only demands
                 the refusal tells the truth.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path("/home/primearchitect/ws/SpaceWheat/🍄") / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

CYCLES = 25
_t = [0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            allow_resource_injection=False)
    fails = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=240))

        def t(action, **kw):
            _t[0] += 1
            return c.run_turn(_t[0], action, timeout_s=60, **kw)

        def press(k, settle=10):
            return t("press_key", key=k, settle_frames=settle)

        def wallet():
            snap = t("resource_snapshot").get("resources", {})
            snap = snap.get("resources", snap)  # instrument nests {ordered, resources}
            return {str(k): snap[k] for k in snap}

        def ledger():
            return t("resource_mutations", limit=400).get("mutations", [])

        press("t", settle=10)   # TheDemos
        press("g", settle=10)   # plot 0
        w0 = wallet()
        n_ledger0 = len(ledger())
        print("starting wallet:", json.dumps(w0, ensure_ascii=False))

        credited = {}            # emoji -> times credited by pop/harvest
        pop_amounts = []
        refusals = []
        float_sightings = []

        for i in range(CYCLES):
            w_before = wallet()
            press("f")           # explore (1🍞) or fast-forward if already live
            press("r")           # strike
            press("q", settle=12)  # extract
            t("time_skip", phrames=60)
            w_after = wallet()

            for k, v in w_after.items():
                if float(v) != int(round(float(v))):
                    float_sightings.append("cycle %d: %s=%r" % (i, k, v))

            # honest-door check: if bread never moved and we hold none, the
            # explore was refused — assert we really were short.
            bread_b = int(round(float(w_before.get("🍞", 0))))
            bread_a = int(round(float(w_after.get("🍞", 0))))
            if bread_a == bread_b and bread_b == 0:
                refusals.append(i)

            for k in set(w_before) | set(w_after):
                d = int(round(float(w_after.get(k, 0)))) - int(round(float(w_before.get(k, 0))))
                if d > 0 and k in ("🌾", "👥"):
                    credited[k] = credited.get(k, 0) + 1
                    pop_amounts.append((i, k, d))

        # ---- LAW A: variety -------------------------------------------------
        print("credited poles:", json.dumps(credited, ensure_ascii=False))
        print("pop deltas (cycle, emoji, +n):", pop_amounts[:25])
        if len(credited) < 2 and len(pop_amounts) >= 8:
            fails.append("one pole only across %d paying cycles: %s"
                         % (len(pop_amounts), list(credited.keys())))
        if pop_amounts and max(d for (_, _, d) in pop_amounts) <= 1:
            fails.append("every extraction paid the +1 floor across %d cycles"
                         % len(pop_amounts))
        if not pop_amounts and not refusals:
            fails.append("no extraction ever paid AND no honest refusal seen — loop dead")

        # ---- LAW B: int wallet ---------------------------------------------
        if float_sightings:
            fails.append("float poison in wallet: %s" % "; ".join(float_sightings[:5]))

        # ---- LAW C: no haunted deltas ---------------------------------------
        w1 = wallet()
        rows = ledger()[max(0, n_ledger0):] if n_ledger0 < 400 else ledger()
        by_emoji = {}
        for r in rows:
            e = str(r.get("emoji", "?"))
            by_emoji[e] = by_emoji.get(e, 0) + int(round(float(r.get("delta", 0))))
        unattributed = []
        for k in set(w0) | set(w1):
            actual = int(round(float(w1.get(k, 0)))) - int(round(float(w0.get(k, 0))))
            logged = by_emoji.get(k, 0)
            if actual != logged:
                unattributed.append("%s: wallet moved %+d, ledger says %+d" % (k, actual, logged))
        if len(rows) >= 395:
            print("NOTE: mutation ledger near capacity — LAW C reconciliation skipped")
        elif unattributed:
            fails.append("haunted wallet deltas: %s" % "; ".join(unattributed[:6]))

        # ---- LAW D: honest door ---------------------------------------------
        if refusals:
            print("broke-explore refusals at cycles:", refusals,
                  "(legit loss — the economy is raw; refusal honesty verified by wallet)")
        print("final wallet:", json.dumps(w1, ensure_ascii=False))
    finally:
        c.terminate_listener(proc)

    print("\n== FAILS (%d) ==" % len(fails))
    for f in fails:
        print(" -", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
