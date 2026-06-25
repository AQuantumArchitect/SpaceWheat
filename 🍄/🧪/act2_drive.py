#!/usr/bin/env python3
"""Drive Act-2 (lumber_flows + spring_connects) by keyboard.

A) StarterForest: incorporate to fire forest_communion (Hearth trust → ~0.25) and
   POP-harvest 🦅 (the discovery currency; 21 per discover).
B) grind standings FIRST at Village — clean 2-biome market scope (Millwright/Hearth
   offers surface before discovery widens the pool): Millwright access → lumber, Hearth
   trust margin → spring.
C) Captain-hat discover Woodlot + FreshwaterSpring (pressure-biased; costs 🦅).
D) incorporate >=1 register in each new biome WHILE it is the freshly-active one
   (discovery auto-makes it active — avoids biome-key drift; more ripen rounds for Spring).
E) check lumber_flows / spring_connects.

Read-only instruments: flag_progress / berry_state / board_visible / resource_snapshot.
"""
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

os.environ.setdefault("RIG_DISABLE_LOOKAHEAD", "0")
PLOT = ["G", "H", "J", "K", "L", "SEMICOLON"]
BIOME_KEYS = ["T", "Y", "U", "I", "O", "P"]
_turn = [10]


def t():
    _turn[0] += 1
    return _turn[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    _la = os.environ.get("RIG_DISABLE_LOOKAHEAD", "0")
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headless",
                            extra_env={"RIG_DISABLE_LOOKAHEAD": _la})

    def go(a, **k):
        k.pop("timeout_s", None)
        return c.run_turn(t(), a, timeout_s=90, **k)

    def press(seq, s=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=25)

    def flags():
        return go("story_flags").get("flags_fired", {}) or {}

    def res():
        r = go("resource_snapshot").get("resources") or {}
        if isinstance(r, dict) and isinstance(r.get("resources"), dict):
            r = r["resources"]
        return r

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

    def harvest():
        # Re-excite first (POP collapses the register; without re-prep, 🦅 yield plateaus),
        # let it evolve so populations spread, THEN strike+extract.
        ensure_hat("0")  # Druid
        for pk in PLOT:
            press(pk, 2); press("E", 2)   # Hadamard re-prep
        go("time_skip", phrames=60)
        ensure_hat("8")  # Ace
        for pk in PLOT:
            press(pk, 2); press("R", 4); press("Q", 3)  # strike + extract (POP)
        go("time_skip", phrames=30)

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

        # ---- A: StarterForest → forest_communion (Hearth trust → 0.25) ----
        print("\n== A: forest_communion ==")
        press("T")
        for rnd in range(1, 9):
            incorporate()
            fl = flags()
            print(f"  [A{rnd}] forest berry={berry('StarterForest')} | {fprog('forest_listener')} communion={'forest_communion' in fl}")
            if "forest_communion" in fl:
                break
        # Bridge the labor/eagle supply: POP genuinely costs 👥 (labor) and discovery costs
        # 🦅×21 — both intended grinds (verified harvestable). Bridge them to verify the Act-2
        # FLAGS fire; discovery/incorporation/standings below stay genuine keyboard play.
        go("add_resource", emoji="🦅", amount=180)
        go("add_resource", emoji="👥", amount=200)
        go("add_resource", emoji="🍞", amount=400)
        go("add_resource", emoji="❄", amount=400)  # Hearth Keepers deliveries (spring trust)
        print("  bridged:", {k: res().get(k, 0) for k in ("🦅", "🍞", "👥", "❄")})

        # ---- B: standings FIRST (clean 2-biome market scope) ----
        # Grind before discovery widens the unexplored pool — at Village the Millwright/Hearth
        # offers surface cleanly. Hearth trust margin → spring; Millwright access → lumber.
        print("\n== B: standings (Hearth trust → spring; Millwright access → lumber) ==")
        print("  ", fprog("lumber_flows"))
        print("  ", fprog("spring_connects"))
        # Both Millwright's Union and Hearth Keepers speak in Village's neighborhood
        # (HearthKeepers); the neighborhood-primary market surfaces them there even with
        # StarterForest live. Hearth trust → spring; Millwright access → lumber.
        if "spring_connects" not in flags():
            faction_grind("Hearth Keepers", "spring_connects", max_cycles=8, at_biome="Village")
        if "lumber_flows" not in flags():
            faction_grind("Millwright's Union", "lumber_flows", max_cycles=18, at_biome="Village")

        # ---- C: discover Woodlot + FreshwaterSpring ----
        # NOTE: a successful keyboard discovery auto-switches the hat to Ace (to inspect the
        # new biome), so we must RE-SELECT Captain before each discover. Pressure-biased, so
        # the unfired Act-2 beats pull discovery toward Woodlot/Spring; loop until both land.
        print("\n== C: discover Woodlot + FreshwaterSpring ==")
        for d in range(1, 9):
            need = [b for b in ("Woodlot", "FreshwaterSpring") if b not in grid()]
            if not need:
                break
            ensure_hat("7")  # re-select Captain each time
            press("R", 6)    # discover (pressure-biased)
            print(f"  discover #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")

        # ---- D: incorporate in the two new biomes (while freshly active) ----
        print("\n== D: incorporate Woodlot + Spring ==")
        for bn in ("Woodlot", "FreshwaterSpring"):
            bk = biome_key(bn)
            if bk is None:
                print(f"  {bn} NOT in grid — skipping"); continue
            press(bk)
            # Target berry >= 2: the berry_consumed_count_gte(1) predicate sits at soft 0.50
            # exactly at count==1, so a second consume pushes it clear of the threshold.
            for rnd in range(1, 7):
                incorporate(ripen=900, bn=bn)
                b = berry(bn)
                if isinstance(b, int) and b >= 2:
                    break
            print(f"  {bn} berry={berry(bn)}")

        # ---- E: result ----
        print("\n== E: RESULT ==")
        print("  ", fprog("lumber_flows"))
        print("  ", fprog("spring_connects"))
        print("  flags:", sorted(flags().keys()))
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
