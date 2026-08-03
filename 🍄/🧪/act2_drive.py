#!/usr/bin/env python3
"""Drive Act-2 (the timber chapter + the spring chapter) by keyboard.

Country Chapter order (chapters 1+2: Millwrights/Woodlot, Hearth Keepers/Spring):

A) StarterForest: incorporate through forest_communion AND loop_remembers (berry ≥7)
   — new_voices needs loop_remembers, and the whole chapter hangs off new_voices.
B) Village: incorporate + the village_stirs apprentice arc → new_voices fires →
   woodlot_door fires instantly (grants Millwright access 0.02, opens their board).
C) Captain-hat discover Woodlot (story-pressured by the door's beats; costs 🦅).
D) Millwright contracts at Village: door grant + ~2 deliveries × access 0.02 clears
   woodlot_contact (0.02 w.008) then the teaching gate on lumber_flows (0.05 w.01).
E) CLAIM the timber teaching (🪵/🪓) on the Arc tab — the claim IS the teaching.
F) plant 🪵/🪓 into Woodlot, then into Village (woodlot_wakes + its DELIVER).
G) Woodlot berries ≥2 → timber_rhythm (the deepening; ⚙/🏭 waits on its claim).
H) spring chapter (Hearth Keepers — their gate channel is TRUST, banked ~0.30
   from act 1): spring_door fires off lumber_flows → discover FreshwaterSpring
   (story pressure ranks it #1 now — the stagger) → Hearth deliveries ×2-3
   (trust +0.05 each) clear spring_contact (0.35 w.02) then the teaching gate
   (0.42 w.02) → CLAIM the water teaching (💧/🌊; readiness = StarterForest
   berries ≥8) → plant 💧 into the spring, then the Village (the mill pond
   DELIVER) → Spring berries ≥2 → pond_depths (pond_breathes chains).

Read-only instruments: flag_progress / berry_state / board_visible / resource_snapshot.
Mutations beyond keyboard play: add_resource bridges (grind currencies) + inject_icon
for the two plants (the picker-key path is proven in act3_5_drive; this driver stays lean).
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
BIOME_KEYS = ["T", "Y", "U", "I", "O", "P"]
# Historical per-script driver timeouts — deliberately NOT unified (SLOP_PATROL knot #8).
GO_TIMEOUT_S = 90
PRESS_TIMEOUT_S = 25
PRESS_SETTLE_FRAMES = 4

_driver = TurnDriver(start=10)


t = _driver.t


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    _la = os.environ.get("RIG_DISABLE_LOOKAHEAD", "0")
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": _la})

    go = _driver.make_go(c, timeout_s=GO_TIMEOUT_S)

    press = _driver.make_press(c, settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)

    def flags():
        return go("story_flags").get("flags_fired", {}) or {}

    def res():
        r = go("resource_snapshot").get("resources") or {}
        if isinstance(r, dict) and isinstance(r.get("resources"), dict):
            r = r["resources"]
        return r

    def known():
        return go("known_icons").get("icons", []) or []

    def word_known(north, south):
        return any(i.get("north") == north and i.get("south") == south for i in known())

    def berry(b):
        return go("berry_state", biome=b).get("consumed_count", "?")

    def grid():
        g = go("grid_snapshot").get("grid", {})
        return g.get("biomes", g)

    def fprog(fid):
        fp = go("flag_progress", id=fid)
        if fp.get("error"):
            return fid + ": " + str(fp["error"])
        parts = [f"{ps['score']:.2f}" for ps in fp.get("predicates", [])]
        return f"{fid} fired={fp.get('fired')} comb={fp.get('combined', 0):.2f} [{','.join(parts)}]"

    def ensure_hat(h):
        other = "7" if h != "7" else "8"
        press(other, 2); press(h, 2)

    def biome_key(name):
        # Use the TRUE slot→key map (grid_snapshot is sorted differently).
        for s in go("biome_slots").get("slots", []):
            if s.get("biome") == name:
                return s.get("key")
        return None

    def active_biome():
        return go("biome_slots").get("active", "")

    def qstate(bn):
        return go("berry_state", biome=bn).get("qubits", [])

    def incorporate(ripen=900, bn=None):
        # Driver hygiene: press ONLY the biome's real registers (a 2-qubit biome has no
        # plot 3-6), and F-track idempotently (F is a TOGGLE — re-pressing an already-
        # tracked qubit untracks it, which across retry rounds could flip a ripe qubit off
        # before R). Track only currently-UNtracked registers.
        if bn:
            bk = biome_key(bn)
            if bk:
                press(bk)
        bn = bn or active_biome()
        qs = qstate(bn)
        plots = PLOT[:len(qs)] if qs else PLOT
        ensure_hat("0")  # Druid: excite the real registers
        for pk in plots:
            press(pk, 3); press("E", 3)
        ensure_hat("5")  # Icon: track only the untracked ones
        trk = [bool(q.get("tracked")) for q in qstate(bn)]
        for i, pk in enumerate(plots):
            if i < len(trk) and not trk[i]:
                press(pk, 3); press("F", 3)
        go("time_skip", phrames=ripen)
        for pk in plots:  # Icon R resolves to incorporate_icon only when ripe
            press(pk, 3); press("R", 4)

    def _arc_row_key_for(snippet):
        """Find the Arc-tab row key ([G]/[H]/…) whose body contains `snippet`.
        Rows render as a standalone '[K]' label line followed by the row's text."""
        import re as _re
        cur = None
        for l in go("overlay_text").get("lines", []) or []:
            s = str(l.get("text", "")).strip()
            m = _re.match(r"^\[([A-Z;])\]$", s)
            if m:
                cur = m.group(1)
                continue
            if cur and snippet in s:
                return "SEMICOLON" if cur == ";" else cur
        return None

    def claim_teaching(north, south, work_biome, accept_snippet):
        """Learn a faction word via a story ARC claim (contracts never teach).
        Accept ONLY the teaching's row on the Arc tab (X → I) — a blind accept-all
        buries the claim past the COMMITMENTS tab's 6-row render cap (idx=8 was
        READY but unclaimable). Then work berries in `work_biome` until READY and
        claim the arc's EXACT commitments row (by its reward pair)."""
        wb_key = biome_key(work_biome)

        def arc_commitment():
            for i, q in enumerate(go("active_quests").get("quests", []) or []):
                if q.get("reward_icon_north") == north and q.get("reward_icon_south") == south:
                    return i, str(q.get("status", "")), int(q.get("id", -1))
            return -1, "", -1

        def accept_arc():
            # Keyboard first: the row may be on the visible Arc tab.
            press("X"); press("I", 4)
            row = _arc_row_key_for(accept_snippet)
            if row:
                press(row, 3); press("R", 4)
            press("ESCAPE", 3)
            if arc_commitment()[0] >= 0:
                return True
            # Beyond the Arc tab's 6-row render cap → accept through the SAME
            # QuestManager seam by id (story_offers/accept_quest = what R does).
            for o in go("story_offers").get("story_offers", []) or []:
                if o.get("reward_icon_north") == north and o.get("reward_icon_south") == south:
                    r = go("accept_quest", quest_id=int(o.get("id", -1)))
                    print(f"    (offer beyond Arc-tab cap — accepted by id: {bool(r.get('accepted'))})")
                    return bool(r.get("accepted"))
            return False

        for attempt in range(1, 7):
            if word_known(north, south):
                break
            if arc_commitment()[0] < 0:            # not accepted yet → targeted accept
                accept_arc()
            if wb_key:
                press(wb_key)
            go("time_skip", phrames=150)           # readiness poll runs on current_biome
            idx, st, qid = arc_commitment()
            print(f"  [claim {north}/{south} #{attempt}] arc idx={idx} status={st} berry={berry(work_biome)}")
            if st == "ready":
                if 0 <= idx < len(PLOT):
                    press("C"); press("U", 4)      # COMMITMENTS tab
                    press(PLOT[idx], 3); press("R", 4)
                    press("ESCAPE", 3)
                if not word_known(north, south) and qid >= 0:
                    # Keyboard claim didn't take (board row mismatch / beyond the
                    # 6-row cap) — claim through the SAME QuestManager seam by id.
                    r = go("complete_or_claim", quest_id=qid)
                    print(f"    (keyboard claim didn't take — complete_or_claim by id: {bool(r.get('completed_or_claimed'))})")
            else:
                incorporate(bn=work_biome)
        ok = word_known(north, south)
        print(f"  {north}/{south} learned: {ok}")
        return ok

    def plant_pair(bn, north, south, label=""):
        """Plant a specific known pair into `bn` via the inject_icon instrument.
        Costs 5×🌱 + 13×south (EconomyConstants) — bridge them with margin
        (verified-harvestable grind currency)."""
        go("add_resource", emoji=south, amount=18)
        go("add_resource", emoji="🌱", amount=10)
        r = go("inject_icon", biome=bn, north=north, south=south).get("inject_result", {})
        print(f"    plant {north}/{south} → {bn} {label}: {r}")
        return bool(r.get("ok", r))

    def faction_grind(faction, target_fid, max_cycles=16, at_biome="Village"):
        """Accept+complete affordable DELIVERY contracts from `faction` to build its standing.
        Self-logging: prints board state + what it saw EVERY cycle so a silent grind is visible."""
        kb = biome_key(at_biome) or "Y"
        for cyc in range(1, max_cycles + 1):
            press(["ESCAPE", "ESCAPE"], 2)  # clear any stale overlay before opening fresh
            press(kb)                       # active = the biome where this faction speaks
            press("C"); press("Y", 3)
            bstate = go("board_state")
            pick = None
            seen = []
            for _r in range(4):
                press("E", 3)
                vis = go("board_visible").get("visible", []) or []
                seen = [f"{o.get('faction','?')[:8]}:{o.get('resource')}x{o.get('quantity')}{'✓' if o.get('affordable') else '✗'}" for o in vis]
                for o in vis:
                    if o.get("index", 99) < len(PLOT) and o.get("affordable") and o.get("faction") == faction:
                        pick = o; break
                if pick:
                    break
            if not pick:
                bs2 = go("board_state")
                print(f"    [{faction[:10]} c{cyc}] NO PICK (active={go('biome_slots').get('active')} cur_biome={bs2.get('current_biome')} nb={bs2.get('nb_name')!r} note={bs2.get('market_status_note')!r}) saw={seen}")
                press("ESCAPE", 3)
                continue
            press(PLOT[pick["index"]], 2); press("R", 3); press("ESCAPE", 3)
            go("time_skip", phrames=40)
            press("C"); press("U", 3)
            for pk in PLOT:
                press(pk, 2); press("R", 4)
            press("ESCAPE", 3)
            print(f"    [{faction[:10]} c{cyc}] PICK {pick['resource']}x{pick['quantity']} | {fprog(target_fid)}")
            fp = go("flag_progress", id=target_fid)
            # the standing predicate is the one with faction set; stop when it's high
            for ps in fp.get("predicates", []):
                if ps["pred"].get("faction") == faction and ps["score"] >= 0.9:
                    return True
        return False

    try:
        c.wait_for_ready(proc, timeout_s=180)
        print("READY grid:", grid())

        # ---- A: StarterForest → forest_communion + loop_remembers ----
        # Address the forest by SLOT LOOKUP: TheDemos boots on T (scenario order),
        # so a bare press("T") silently farms the wrong biome — berry stays 0 forever.
        print("\n== A: forest beats (communion + loop_remembers) ==")
        for rnd in range(1, 13):
            incorporate(bn="StarterForest")
            fl = flags()
            print(f"  [A{rnd}] forest berry={berry('StarterForest')} | {fprog('forest_listener')} "
                  f"communion={'forest_communion' in fl} loop_remembers={'loop_remembers' in fl}")
            if "forest_communion" in fl and "loop_remembers" in fl:
                break
        # Bridge the labor/eagle supply: POP genuinely costs 👥 (labor) and discovery costs
        # 🦅×21 — both intended grinds (verified harvestable). Bridge them to verify the Act-2
        # FLAGS fire; discovery/incorporation/standings below stay genuine keyboard play.
        go("add_resource", emoji="🦅", amount=180)
        go("add_resource", emoji="👥", amount=200)
        go("add_resource", emoji="🍞", amount=400)
        go("add_resource", emoji="❄", amount=400)  # Hearth Keepers deliveries (spring trust)
        print("  bridged:", {k: res().get(k, 0) for k in ("🦅", "🍞", "👥", "❄")})

        # ---- B: Village → village_stirs → new_voices → woodlot_door ----
        print("\n== B: village_stirs → new_voices → woodlot_door ==")
        for rnd in range(1, 7):
            incorporate(bn="Village")
            b = berry("Village")
            print(f"  [B{rnd}] village berry={b} stirs={'village_stirs' in flags()}")
            if "village_stirs" in flags() and isinstance(b, int) and b >= 4:
                break  # ≥4 also banks the lumber teaching's readiness
        go("time_skip", phrames=120)  # let new_voices → woodlot_door cascade fire
        print("  ", fprog("new_voices"))
        print("  ", fprog("woodlot_door"))

        # ---- C: discover Woodlot (story-pressured) ----
        # NOTE: a successful keyboard discovery auto-switches the hat to Ace, so RE-SELECT
        # Captain before each discover. FreshwaterSpring waits for ITS door (the stagger:
        # one pressured biome at a time).
        print("\n== C: discover Woodlot ==")
        for d in range(1, 9):
            if "Woodlot" in grid():
                break
            ensure_hat("7")  # re-select Captain each time
            press("R", 6)    # discover (pressure-biased)
            print(f"  discover #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")

        # ---- D: Millwright contracts → woodlot_contact → lumber_flows ----
        print("\n== D: Millwright contracts (contact → teaching) ==")
        print("  ", fprog("woodlot_contact"))
        if "lumber_flows" not in flags():
            faction_grind("Millwright's Union", "lumber_flows", max_cycles=8, at_biome="Village")
        print("  ", fprog("woodlot_contact"))
        print("  ", fprog("lumber_flows"))

        # ---- E: claim the timber teaching (🪵/🪓) ----
        print("\n== E: the teaching (Arc-tab claim) ==")
        claim_teaching("🪵", "🪓", "Village", "teach you timber")

        # ---- F: plant timber — Woodlot ring, then couple the Village ----
        print("\n== F: plant 🪵/🪓 (Woodlot, then Village) ==")
        if word_known("🪵", "🪓"):
            plant_pair("Woodlot", "🪵", "🪓", "(the ring)")
            plant_pair("Village", "🪵", "🪓", "(the coupling)")
        go("time_skip", phrames=120)
        print("  ", fprog("woodlot_wakes"))

        # ---- G: Woodlot berries → timber_rhythm ----
        print("\n== G: the deepening (Woodlot berries) ==")
        for rnd in range(1, 7):
            incorporate(ripen=900, bn="Woodlot")
            b = berry("Woodlot")
            print(f"  [G{rnd}] woodlot berry={b} | {fprog('timber_rhythm')}")
            if "timber_rhythm" in flags():
                break

        # ---- H: spring country (door → contact → teaching → wakes → depths) ----
        print("\n== H: spring country (Hearth Keepers — trust, not access) ==")
        go("time_skip", phrames=120)  # let lumber_flows → spring_door cascade fire
        print("  ", fprog("spring_door"))

        # Beat 1 (door): discover FreshwaterSpring — the compass pressures it #1 now.
        for d in range(1, 9):
            if "FreshwaterSpring" in grid():
                break
            ensure_hat("7")
            press("R", 6)
            print(f"  discover #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")

        # Beats 2+3 (contact → teaching gate): Hearth deliveries at Village. Their
        # channel is TRUST (banked ~0.30 from act 1); +0.05/delivery clears contact
        # (0.35 w.02) then the teaching gate (0.42 w.02) — the 2-3 contract budget.
        if "spring_connects" not in flags():
            faction_grind("Hearth Keepers", "spring_connects", max_cycles=8, at_biome="Village")
        print("  ", fprog("spring_contact"))
        print("  ", fprog("spring_connects"))

        # Beat 3 claim: readiness = StarterForest berries ≥8 (one more loop in the
        # shared forest — act 1 banked 7 for loop_remembers).
        claim_teaching("💧", "🌊", "StarterForest", "teach you water")

        # Beat 4 (wakes): plant water into the spring's stone, then couple the
        # Village (the mill pond DELIVER).
        if word_known("💧", "🌊"):
            plant_pair("FreshwaterSpring", "💧", "🌊", "(the spring)")
            plant_pair("Village", "💧", "🌊", "(the mill pond)")
        go("time_skip", phrames=120)
        print("  ", fprog("spring_wakes"))

        # Beat 5 (deepening): Spring berries ≥2 → pond_depths; pond_breathes chains.
        for rnd in range(1, 7):
            incorporate(ripen=900, bn="FreshwaterSpring")
            b = berry("FreshwaterSpring")
            print(f"  [H{rnd}] spring berry={b} | {fprog('pond_depths')}")
            if "pond_depths" in flags():
                break

        # ---- RESULT ----
        print("\n== RESULT ==")
        for fid in ("woodlot_door", "woodlot_contact", "lumber_flows",
                    "woodlot_wakes", "timber_rhythm",
                    "spring_door", "spring_contact", "spring_connects",
                    "spring_wakes", "pond_depths", "pond_breathes"):
            print("  ", fprog(fid))
        print("  flags:", sorted(flags().keys()))
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
