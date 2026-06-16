#!/usr/bin/env python3
"""Actually PLAY demos_normal start-to-finish through the rig and narrate it.

Drives the real loop with the live C++ engine: inspect offers (faction quests +
market contracts), open the quest board, accept an offer, run the measure/harvest
loop to produce resources, complete/claim, discover a biome, fire story beats, then
victory-lap the farm. Dumps the data structures so the loop can be explained, and
screenshots the board + farm. Also re-validates the keyboard action path that the
push_input fix restored.
"""
import sys, time, json
from pathlib import Path
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

SHOTS = HERE / "playthrough_shots"
SHOTS.mkdir(exist_ok=True)


def j(o, n=1400):
    return json.dumps(o, ensure_ascii=False, indent=2)[:n]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    log = c.runner_root / "logs" / "rig_listener.log"
    try: log.write_text("")
    except OSError: pass
    t = [0]
    def nt(): t[0] += 1; return t[0]
    def cmd(action, **kw):
        return c.run_turn(nt(), action, timeout_s=kw.pop("timeout_s", 30), **kw)
    def key(k, **kw): cmd("press_key", key=k, settle_frames=kw.get("s", 4))
    def shot(label):
        r = cmd("screenshot", path=f"user://rig/play_{t[0]:03d}_{label}.png")
        ab = (r.get("screenshot") or {}).get("abs")
        if ab:
            try: (SHOTS / f"PLAY_{label}.png").write_bytes(Path(ab).read_bytes())
            except OSError: pass
    def totals(label):
        r = cmd("resource_snapshot").get("resources", {})
        inner = r.get("resources", r) if isinstance(r, dict) else {}
        print(f"  [{label}] resources: " + ", ".join(f"{k}×{v}" for k, v in inner.items() if isinstance(v, (int, float)) and v))
        return inner

    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": "0"})  # live C++ engine
    try:
        c.wait_for_ready(proc, timeout_s=150); time.sleep(1.2)

        print("\n================ 1. STARTING STATE ================")
        totals("start")
        shot("01_farm")
        print("  known icons:", j(cmd("known_icons").get("known_icons", cmd("known_icons").get("icons", [])), 300))

        print("\n================ 2. OFFERS (quests + market contracts) ================")
        offers = cmd("offer_quests", full=True).get("offers", [])
        print(f"  {len(offers)} offers on the board:")
        for i, o in enumerate(offers[:8]):
            kind = "CONTRACT" if (o.get("market_projection") or o.get("cost_emoji")) else "QUEST"
            print(f"   [{i}] {kind}: {o.get('full_text') or o.get('faction')} | resource={o.get('resource')} "
                  f"qty={o.get('quantity')} reward={o.get('reward_resources', {})} "
                  f"cost={o.get('cost_amount','-')}{o.get('cost_emoji','')}")
        if offers:
            print("\n  raw offer[0]:", j(offers[0], 900))

        print("\n================ 3. QUEST BOARD via C key ================")
        key("C"); shot("02_quest_board")
        ov = cmd("overlay_snapshot", overlay="quests")
        print("  quest board overlay ok:", ov.get("ok"), "snapshot keys:", list((ov.get("snapshot") or {}).keys()))
        key("ESCAPE", s=2)

        print("\n================ 4. ACCEPT an offer ================")
        acc = cmd("accept_offer", offer_index=0)
        qid = acc.get("quest_id", -1)
        print(f"  accepted offer[0] -> accepted={acc.get('accepted')} quest_id={qid}")
        aq = cmd("active_quests", full=True).get("quests", cmd("active_quests", full=True).get("active_quests", []))
        print("  active quests:", j(aq, 700))

        print("\n================ 5. PLAY THE LOOP (measure + harvest via keys) ================")
        before = totals("before play")
        key("8")                       # Ace hat
        for plot in ["T", "G"]:        # biome T, plot G
            key(plot, s=2)
        key("E", s=5)                  # Measure (projective collapse -> resource)
        shot("03_after_measure")
        key("'", s=2)                  # bulk-select all plots
        key("Q", s=3); key("F", s=4)   # mass-harvest (Q -> F confirm)
        shot("04_after_harvest")
        after = totals("after play")
        gained = {k: after.get(k, 0) - before.get(k, 0) for k in set(after) | set(before)
                  if after.get(k, 0) - before.get(k, 0) != 0}
        print("  Δ resources from play:", gained)

        print("\n================ 6. COMPLETE / CLAIM the quest ================")
        coc = cmd("complete_or_claim", quest_id=qid)
        print("  complete_or_claim:", coc.get("completed_or_claimed"))
        comp = cmd("complete_quest", quest_id=qid)
        print("  complete_quest:", comp.get("completed"), "rewards:", comp.get("rewards"))
        clm = cmd("claim_quest", quest_id=qid)
        print("  claim_quest:", clm.get("claimed"))
        totals("after quest")

        print("\n================ 7. DISCOVER a biome ================")
        fc = cmd("discovery_forecast")
        print("  forecast:", j(fc.get("discovery_forecast", fc.get("forecast", {})), 400))
        disc = cmd("discover_biome")
        print("  discover_biome:", j({k: v for k, v in disc.items() if k not in ('turn', 'request_id', 'action')}, 400))

        print("\n================ 8. STORY BEATS ================")
        sf = cmd("story_flags")
        print("  story_flags:", j(sf.get("story_flags", sf), 700))

        print("\n================ 9. VICTORY LAP (run the whole farm) ================")
        vl = cmd("victory_lap", timeout_s=90)
        print("  victory_lap:", j({k: v for k, v in vl.items() if k not in ('turn', 'request_id', 'action')}, 700))
        totals("final")
        shot("05_final")

    finally:
        try: cmd("stop", timeout_s=8)
        except Exception: pass
        c.terminate_listener(proc)

    errs = [l for l in log.read_text(errors="replace").splitlines()
            if any(x in l for x in ("SCRIPT ERROR", "ERROR:", "push_error"))]
    print(f"\n================ LOG ERRORS: {len(errs)} ================")
    for e in errs[:12]:
        print("  ⚠", e)


if __name__ == "__main__":
    main()
