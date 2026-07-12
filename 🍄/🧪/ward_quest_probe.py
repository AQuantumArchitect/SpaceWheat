#!/usr/bin/env python3
"""PREVENT_DECOHERENCE lives: in WET country the offer pool leads with a ward
quest (keep purity above min_purity for a duration). Asserts:
  1. a wet biome's pool contains a type-8 (PREVENT_DECOHERENCE) offer,
  2. accepting it tracks — progress/elapsed move while purity holds,
  3. closed-ground pools contain NO ward (a ward would be a lie there).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path("/home/primearchitect/ws/SpaceWheat/🍄") / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

WET = {"GildedRot", "Clinic", "ShrineOfAshes", "NullingChamber", "ZenoLatch",
       "WheelOfHours", "LaserGlint", "TwofacedTide", "BrittleDawn", "MothGarden"}
_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed",
                            allow_resource_injection=True)
    fails = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=60, **kw)

        def press(k, settle=8):
            return t("press_key", key=k, settle_frames=settle)

        def grid():
            return [s["biome"] for s in t("biome_slots").get("slots", []) if s.get("biome")]

        def offers_for_active():
            r = t("offer_quests")
            return r.get("quests", r.get("offers", [])) or []

        # 3. Closed ground first: TheDemos pool must have NO ward.
        press("t", settle=10)
        closed_offers = offers_for_active()
        wards_closed = [q for q in closed_offers if int(q.get("type", 0)) == 8]
        if wards_closed:
            fails.append("ward offered on CLOSED ground: %s" % wards_closed[:1])
        print("closed-ground pool: %d offers, wards=%d" % (len(closed_offers), len(wards_closed)))

        # Discover until a wet biome lands (bridge the door + cull costs).
        t("add_resource", emoji="🦅", amount=2000)
        t("add_resource", emoji="💀", amount=400)
        CORE = {"TheDemos", "Village", "StarterForest"}

        def cull(name):
            # Captain hat 7, Q arms (destructive), F confirms — the first F
            # flattens the hint toast, a later F confirms (act3_5 workaround).
            bk = next((str(s2["key"]).lower() for s2 in t("biome_slots").get("slots", [])
                       if s2["biome"] == name), "")
            if not bk:
                return False
            press(bk, settle=8)
            press("7", settle=4)
            press("q", settle=6)
            for _ in range(4):
                press("f", settle=6)
                if name not in grid():
                    return True
            return name not in grid()

        wet_on_grid = ""
        for attempt in range(24):
            g = grid()
            hits = [b for b in g if b in WET]
            if hits:
                wet_on_grid = hits[0]
                break
            if len(g) >= 6:
                victim = next((b for b in reversed(g) if b not in CORE), "")
                if not victim or not cull(victim):
                    break
            t("discover_biome")
        print("grid:", grid(), "| wet biome:", wet_on_grid or "(none)")
        if not wet_on_grid:
            fails.append("no wet biome discovered in 16 tries")
            return 1

        # Switch to it and read its pool.
        key = next(str(s["key"]).lower() for s in t("biome_slots").get("slots", [])
                   if s["biome"] == wet_on_grid)
        press(key, settle=12)
        pool = offers_for_active()
        wards = [q for q in pool if int(q.get("type", 0)) == 8]
        print("wet pool: %d offers, wards=%d" % (len(pool), len(wards)))
        if not wards:
            fails.append("no PREVENT_DECOHERENCE offer in wet pool: %s" % json.dumps(
                [{k: q.get(k) for k in ("type", "faction", "body")} for q in pool], ensure_ascii=False)[:400])
            return 1
        w = wards[0]
        print("ward offer:", json.dumps({k: w.get(k) for k in
              ("id", "faction", "min_purity", "duration", "tutorial_hint")}, ensure_ascii=False)[:300])

        # 2. Accept and watch the tracker bank time.
        qid = int(w.get("id", -1))
        acc = t("accept_quest", quest_id=qid)
        print("accept:", acc.get("accepted", acc.get("ok")))
        t("time_skip", phrames=600)
        aq = t("active_quests", full=True).get("quests", [])
        mine = next((q for q in aq if int(q.get("id", -1)) == qid), {})
        prog = float(mine.get("progress", 0) or 0)
        elapsed = float(mine.get("elapsed", 0) or 0)
        print("after 600 phrames: progress=%.3f elapsed=%.1f status=%s" % (
            prog, elapsed, mine.get("status")))
        if elapsed <= 0.0:
            fails.append("ward tracker banked no time (elapsed=%s)" % elapsed)
    finally:
        c.terminate_listener(proc)

    print("\n== FAILS (%d) ==" % len(fails))
    for f in fails:
        print(" -", f)
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
