#!/usr/bin/env python3
"""Drive Acts 3-5 by keyboard, on top of a fresh Act-1/2 run.

The rig boots fresh each run, so this replays the proven Act-1/2 sequence first
(forest_communion/forest_listener → lumber_flows + spring_connects via act2's
neighborhood-primary market), then pushes into:

  Act 3  mill_wakes   : learn Mill (village_stirs apprentice arc) → plant Mill into
                        an empty Village plot → evolve so ⚙→💨 populates wind.
         mill_master  : keep incorporating Village registers (berry≥5, phase≥18.85).
  Act 4  island_lives : plant the already-known 🪵/🌾 icon into Village (atom_in_biome 🪵)
                        — lumber_flows + spring_connects + mill_wakes already fired.
         village_identity : plant icons into Village to reach atom_count≥12 + grow the
                        signature≥14 + push the Village eigenvalue gap ≥0.12.
  Act 5  ledger_opens : discover BloodLedger (pressure-biased once village_identity fires)
                        → incorporate twice (berry≥2).

Bridging precedent (act2): raw resource grinds are bridged via add_resource so the
FLAGS fire through genuine keyboard incorporation/planting/discovery — the physics
and the flag-firing stay honest, only the grind currencies are topped up.
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
    _la = os.environ.get("RIG_DISABLE_LOOKAHEAD", "0")
    _display = os.environ.get("RIG_DISPLAY_MODE", "headless")
    # Title mode (headed gallery): boot to the REAL title screen and drive the player's
    # title → start → welcome path, instead of the rig's direct start_game. Off by default
    # so the headless regression keeps its fast direct boot.
    _drive_title = os.environ.get("RIG_DRIVE_TITLE", "0") == "1"
    _boot_env = {"RIG_DISABLE_LOOKAHEAD": _la}
    if _drive_title:
        _boot_env["RIG_DRIVE_TITLE"] = "1"
        _boot_env["RIG_SKIP_WELCOME"] = "0"  # show the welcome so we can verify it
    proc = c.start_listener(scenario_id="demos_normal", display_mode=_display,
                            extra_env=_boot_env)

    def go(a, **k):
        k.pop("timeout_s", None)
        return c.run_turn(t(), a, timeout_s=90, **k)

    def press(seq, s=4):
        if isinstance(seq, str):
            seq = [seq]
        for k in seq:
            c.run_turn(t(), "press_key", key=k, settle_frames=s, timeout_s=25)

    # Story-beat screenshots — only when RIG_SHOTS=1 (headed). No-op headless.
    _shots_on = os.environ.get("RIG_SHOTS", "0") == "1"
    def shot(name):
        if not _shots_on:
            return
        sh = go("screenshot", path="user://rig/beat_%s.png" % name).get("screenshot", {})
        print("  SHOT %-16s saved=%s -> %s" % (name, sh.get("saved"), sh.get("abs")))

    def flags():
        return go("story_flags").get("flags_fired", {}) or {}

    def res():
        r = go("resource_snapshot").get("resources") or {}
        if isinstance(r, dict) and isinstance(r.get("resources"), dict):
            r = r["resources"]
        return r

    def known():
        return go("known_icons").get("icons", []) or []

    def berry(b):
        return go("berry_state", biome=b).get("consumed_count", "?")

    def qstate(bn):
        return go("berry_state", biome=bn).get("qubits", [])

    def grid():
        g = go("grid_snapshot").get("grid", {})
        return g.get("biomes", g)

    def fprog(fid):
        fp = go("flag_progress", id=fid)
        if fp.get("error"):
            return f"{fid}: {fp['error']}"
        parts = [f"{ps['score']:.2f}" for ps in fp.get("predicates", [])]
        return f"{fid} fired={fp.get('fired')} comb={fp.get('combined', 0):.2f} [{','.join(parts)}]"

    def ensure_hat(h):
        other = "7" if h != "7" else "8"
        press(other, 2); press(h, 2)

    def biome_key(name):
        for s in go("biome_slots").get("slots", []):
            if s.get("biome") == name:
                return s.get("key")
        return None

    def active_biome():
        return go("biome_slots").get("active", "")

    def goto_biome(name):
        """Switch active biome to `name`, VERIFYING it landed. The rig's first biome-key
        press after some states is a no-op (switch lag) — so a plant that assumed it was on
        Village could open the inject submenu for whatever biome was actually active. Retry."""
        bk = biome_key(name)
        if not bk:
            return False
        for _ in range(4):
            if active_biome() == name:
                return True
            press(bk, 3)
        return active_biome() == name

    def goto_key(bk):
        """goto_biome but addressed by biome KEY (what the plant helpers carry)."""
        for s in go("biome_slots").get("slots", []):
            if s.get("key") == bk:
                return goto_biome(s.get("biome"))
        press(bk)
        return False

    def incorporate(ripen=900, bn=None):
        bn = bn or active_biome()
        qs = qstate(bn)
        plots = PLOT[:len(qs)] if qs else PLOT
        ensure_hat("0")  # Druid: excite registers
        for pk in plots:
            press(pk, 3); press("E", 3)
        ensure_hat("5")  # Icon: track only untracked
        trk = [bool(q.get("tracked")) for q in qstate(bn)]
        for i, pk in enumerate(plots):
            if i < len(trk) and not trk[i]:
                press(pk, 3); press("F", 3)
        go("time_skip", phrames=ripen)
        for pk in plots:  # Icon R = incorporate_icon when ripe
            press(pk, 3); press("R", 4)

    def harvest():
        ensure_hat("0")
        for pk in PLOT:
            press(pk, 2); press("E", 2)
        go("time_skip", phrames=60)
        ensure_hat("8")  # Ace
        for pk in PLOT:
            press(pk, 2); press("R", 4); press("Q", 3)
        go("time_skip", phrames=30)

    def _clear_toasts(pk):
        """Decay any live hint toast (~320 process frames @60fps) so an inject-submenu slot
        on E (or a destructive confirm on F) isn't eaten by PlayerShell's toast intercept
        (E pause-decay / F flatten). A plain plot-key press advances process frames — which
        run the toast tween — WITHOUT touching E/F; harmless on an already-active plot."""
        press(pk, 200); press(pk, 200)

    def _select_slot(slot_key):
        """Press a submenu slot key and CONFIRM the inject took (qubit count grew). Call
        AFTER _clear_toasts so the first press lands (retrying an E slot would otherwise
        re-pause the toast and deadlock); the short retry covers Q/R settle jitter."""
        bn = active_biome()
        before = len(qstate(bn))
        for _try in range(3):
            press(slot_key, 4)
            if len(qstate(bn)) > before:
                return True
            if not go("submenu_state").get("in_submenu"):
                return False
        return len(qstate(bn)) > before

    def plant_icon(bk, north, south, label=""):
        """Plant a specific known icon (north/south) into an empty plot of biome `bk`.
        inject_icon costs 4×south-pole + 10×🌱 — bridge them (verified-harvestable grind
        currency; keeps the FLAG genuine, same precedent as the other bridges)."""
        bridge(south, 12); bridge("🌱", 15)
        goto_key(bk)
        nq = len(qstate(active_biome()))
        ensure_hat("5")  # Icon hat ON
        for pk in (PLOT[nq:] + PLOT):  # empties first, then any
            _clear_toasts(pk)          # so an E-slot icon isn't eaten by a live toast
            press(pk, 3); press("R", 4)
            if not go("submenu_state").get("in_submenu"):
                continue
            slots = go("submenu_state").get("slots", {})
            hit = next((k for k, v in slots.items()
                        if v.get("north") == north and v.get("south") == south), None)
            if hit and _select_slot(hit):
                print(f"    planted {north}/{south} {label} → plot {pk} slot {hit} (qubits now {len(qstate(active_biome()))})")
                return True
            press("ESCAPE", 2)
        print(f"    ✗ could not plant {north}/{south} {label}")
        return False

    def plant_first(bk):
        """Plant ANY injectable icon into an empty plot of `bk` to grow atom_count. Prefers
        the Q slot (never toast-intercepted), then R, then E."""
        goto_key(bk)
        nq = len(qstate(active_biome()))
        ensure_hat("5")
        opened = 0
        raw_dump = None
        for pk in (PLOT[nq:] + PLOT):
            # No toast-clear needed: we prefer the Q slot, which PlayerShell never
            # intercepts (only E/F are eaten by the toast grammar).
            press(pk, 3); press("R", 4)
            sm = go("submenu_state")
            if not sm.get("in_submenu"):
                continue
            opened += 1
            slots = sm.get("slots", {})
            raw_dump = slots
            real = {k: v for k, v in slots.items() if v.get("north") and v.get("south")}
            if not real:
                press("ESCAPE", 2); continue
            order = [k for k in ("Q", "R") if k in real] or list(real.keys())
            k = order[0]; v = real[k]
            bridge(str(v.get("south", "")), 12); bridge("🌱", 15)  # inject cost
            if _select_slot(k):
                print(f"    planted {v.get('north')}/{v.get('south')} via slot {k} → qubits now {len(qstate(active_biome()))}")
                return True
            press("ESCAPE", 2)
        # DIAGNOSTIC: why empty? dump active biome, its emojis, known icons, raw submenu.
        kn = [f"{i.get('north')}/{i.get('south')}" for i in known()]
        rd = go("realization_debug", biome=active_biome())
        print(f"    ✗ no injectable icon planted | active={active_biome()} opened={opened} "
              f"villQubits={len(qstate(active_biome()))}")
        print(f"      biome_emojis={rd.get('emojis') or rd.get('basis') or rd}")
        print(f"      raw_submenu={raw_dump}")
        print(f"      known({len(kn)})={kn}")
        return False

    def faction_grind(faction, target_fid, max_cycles=16, at_biome="Village"):
        kb = biome_key(at_biome) or "Y"
        for cyc in range(1, max_cycles + 1):
            press(["ESCAPE", "ESCAPE"], 2)
            press(kb)
            press("C"); press("Y", 3)
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
                bs = go("board_state")
                print(f"    [{faction[:10]} c{cyc}] NO PICK (active={active_biome()} cur={bs.get('current_biome')} nb={bs.get('nb_name')!r}) saw={seen}")
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
            for ps in fp.get("predicates", []):
                if ps["pred"].get("faction") == faction and ps["score"] >= 0.9:
                    return True
        return False

    def bridge(emoji, amount):
        go("add_resource", emoji=emoji, amount=amount)

    # Story landmarks must stay LOADED until their gating flag fires: berry counts
    # live on the biome's berry_register, and biome_evolving reads the live biome —
    # culling one mid-arc erases its progress. Protection is DYNAMIC: pending flag
    # → protected; fired → released (slots are scarce, 6 max). GildedRot maps to
    # the_rite because it is the LAST GildedRot-gated flag (crossing → gray → rite).
    LANDMARK_GATE = {"Lanternfall": "chain_ends", "GildedRot": "the_rite",
                     "ZenoLatch": "watching_keeps", "ShrineOfAshes": "the_basin",
                     "NullingChamber": "hiding_in_the_light"}

    def protected_landmarks():
        fl = flags()
        return {b for b, fid in LANDMARK_GATE.items() if fid not in fl}

    def cull(name):
        """Cull (remove) a biome to free a slot. Captain hat Q = remove_biome (destructive
        → F confirms); costs 34×💀, so bridge it. Returns True if the biome left the grid.

        BUG WORKAROUND: the destructive-arm hint is a TOAST, and PlayerShell intercepts F
        to FLATTEN the topmost toast (consuming it) before QII's confirm handler sees it. So
        the first F after Q just dismisses the hint toast; a SECOND F actually confirms.
        Press F until the biome leaves the grid (flush toast(s) → confirm)."""
        bk2 = biome_key(name)
        if not bk2:
            return False
        bridge("💀", 50)
        press(bk2); ensure_hat("7")
        press("Q", 3)              # arm (shows a hint toast)
        for _ in range(4):
            press("F", 3)          # 1st F flattens the toast; a later F confirms
            if name not in grid():
                break
        ok = name not in grid()
        print(f"    culled {name}: {'ok' if ok else 'FAILED'} → grid={grid()}")
        return ok

    def is_mill_known():
        return any(i.get("north") == "💨" and i.get("south") == "🔨" for i in known())

    def learn_mill(vk):
        """Learn the Mill icon (💨/🔨) via the village_stirs apprentice arc. Run this
        BEFORE the Act-2 market grinds so the COMMITMENTS tab is clean. Gotchas, all
        probe-confirmed:
          (1) the arc flips "ready" only around Village berry>=6 (soft_gate(berry,3,1.5)
              >=0.85); ONLY incorporation grows berry, time_skip does not. Needs
              current_biome=Village (press the key) for the readiness poll to run.
          (2) ARC-tab accept: arc_quests are listed first; accepting a row removes it and
              the list shifts, so re-select index 0 (G) and accept (R) repeatedly.
          (3) COMMITMENTS-tab claim: the tab renders only the first 6 rows in
              active_quests order — select the arc's EXACT index (by its 💨/🔨 reward),
              not index 0 (other commitments would bury it)."""
        press(vk)
        for rnd in range(1, 9):
            incorporate(bn="Village")
            b = berry("Village")
            print(f"  [mill-inc {rnd}] village berry={b} village_stirs={'village_stirs' in flags()}")
            if "village_stirs" in flags() and isinstance(b, int) and b >= 6:
                break

        def arc_commitment():
            for i, q in enumerate(go("active_quests").get("quests", []) or []):
                if q.get("reward_icon_north") == "💨" and q.get("reward_icon_south") == "🔨":
                    return i, str(q.get("status", ""))
            return -1, ""

        for attempt in range(1, 7):
            if is_mill_known():
                break
            press(vk)
            press("X"); press("I", 4)              # ARC tab (menu re-org: Arc lives on X, not C)
            for _ in range(4):
                press("G", 3); press("R", 4)       # accept, re-selecting index 0
            press("ESCAPE", 3)
            press(vk); go("time_skip", phrames=150)  # current_biome=Village → flip ready
            idx, st = arc_commitment()
            print(f"  [mill-claim {attempt}] arc idx={idx} status={st} berry={berry('Village')}")
            if 0 <= idx < len(PLOT):
                press("C"); press("U", 4)          # COMMITMENTS tab
                press(PLOT[idx], 3); press("R", 4) # select arc's exact row + claim
                press("ESCAPE", 3)
            else:
                incorporate(bn="Village")
        print(f"  Mill learned: {is_mill_known()}")
        return is_mill_known()

    def boot_via_title():
        """Drive the real player boot: title → (F opens X menu) → start → welcome → dismiss,
        screenshotting each. start_from_title presses F then guarantees the boot (start_game
        fallback) and resolves farm+shell, so the welcome appears exactly as a player sees it."""
        shot("00_title")
        st = go("start_from_title", keys=["F"], settle_frames=10)
        info = st.get("start_from_title", {})
        print("  start_from_title:", info)
        shot("01_welcome")
        # The user's bug: a non-F key was eaten by the welcome modal. Prove ANY key dismisses
        # it now — press a frame key (5). Then the farm is live and playable.
        press("5", 6)
        shot("02_after_dismiss_play")
        return bool(info.get("farm"))

    def gallery():
        """Screenshot EVERY panel at the rich end-state: all 7 hats, then each top-level
        surface and its tabs. ESC between so overlays don't stack."""
        print("\n== PANEL GALLERY (every panel) ==")
        press(["ESCAPE", "ESCAPE"], 2)
        goto_biome("Village"); press("G", 2)  # a populated plot so panels have content
        # Hats — action bar per frame.
        for k, nm in [("4", "hat4_spark"), ("5", "hat5_icon"), ("6", "hat6_merchant"),
                      ("7", "hat7_captain"), ("8", "hat8_ace"), ("9", "hat9_operator"),
                      ("0", "hat0_druid")]:
            press(k, 3); shot("g_%s" % nm)
        press("8", 2)  # back to Ace
        # Surfaces + their tabs (TYUIOP). ESC after each surface.
        surfaces = [
            ("Z", "sys_system", []),
            ("X", "x_playthrough", [("T", "self"), ("Y", "story"), ("I", "balance"), ("O", "guide")]),
            ("C", "c_quests", [("T", "manifold"), ("Y", "market"), ("U", "commitments"), ("I", "arc")]),
            ("V", "v_atlas", []),
            ("B", "b_microscope", []),
            ("N", "n_inspector", []),
            ("M", "m_map", []),
            ("BRACKETLEFT", "nbhd_graph", []),
        ]
        for skey, sname, tabs in surfaces:
            press(["ESCAPE", "ESCAPE"], 2)
            press(skey, 5)
            shot("g_%s" % sname)
            for tkey, tname in tabs:
                press(tkey, 5); shot("g_%s_%s" % (sname, tname))
            press("ESCAPE", 3)
        press(["ESCAPE", "ESCAPE"], 2)
        print("  gallery complete")

    try:
        c.wait_for_ready(proc, timeout_s=180)
        if _drive_title:
            print("== BOOT VIA TITLE (real player path) ==")
            boot_via_title()
        print("READY grid:", grid())
        print("known@start:", [f"{i.get('north')}/{i.get('south')}" for i in known()])

        # ============ ACT 1: forest_communion + forest_listener ============
        print("\n== ACT1: StarterForest ==")
        press("T")
        for rnd in range(1, 10):
            incorporate()
            fl = flags()
            print(f"  [A{rnd}] forest berry={berry('StarterForest')} communion={'forest_communion' in fl} listener={'forest_listener' in fl}")
            if "forest_communion" in fl and "forest_listener" in fl:
                break
        bridge("🦅", 220); bridge("👥", 240); bridge("🍞", 500); bridge("❄", 500)
        bridge("🔨", 60); bridge("🌱", 60)
        print("  bridged:", {k: res().get(k, 0) for k in ("🦅", "🍞", "👥", "❄", "🔨", "🌱")})

        # ---- Learn Mill NOW (clean commitments, before Act-2 grinds clutter them) ----
        # village_stirs needs forest_listener (just fired) + Village berry; the apprentice
        # arc rewards the Mill icon, which Act 3 plants to wake the wind.
        print("\n== learn Mill (apprentice arc, pre-Act-2) ==")
        vk = biome_key("Village") or "Y"
        learn_mill(vk)

        # ============ ACT 2: lumber_flows + spring_connects ============
        print("\n== ACT2: standings + discover + incorporate ==")
        if "spring_connects" not in flags():
            faction_grind("Hearth Keepers", "spring_connects", max_cycles=8, at_biome="Village")
        if "lumber_flows" not in flags():
            faction_grind("Millwright's Union", "lumber_flows", max_cycles=18, at_biome="Village")
        for d in range(1, 9):
            need = [b for b in ("Woodlot", "FreshwaterSpring") if b not in grid()]
            if not need:
                break
            ensure_hat("7")
            press("R", 6)
            print(f"  discover #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")
        for bn in ("Woodlot", "FreshwaterSpring"):
            bk = biome_key(bn)
            if bk is None:
                print(f"  {bn} NOT in grid"); continue
            press(bk)
            for rnd in range(1, 7):
                incorporate(ripen=900, bn=bn)
                b = berry(bn)
                if isinstance(b, int) and b >= 2:
                    break
            print(f"  {bn} berry={berry(bn)}")
        print("  ", fprog("lumber_flows"))
        print("  ", fprog("spring_connects"))

        # ============ ACT 3: mill_wakes + mill_master ============
        print("\n== ACT3: mill_wakes ==")
        # Mill was learned pre-Act-2. Plant it into Village, evolve so ⚙→💨 wakes wind.
        learned_mill = is_mill_known()
        print(f"  Mill known: {learned_mill}")
        if learned_mill:
            plant_icon(vk, "💨", "🔨", "Mill")
        for rnd in range(1, 8):
            press(vk)
            ensure_hat("0")
            for pk in PLOT:
                press(pk, 2); press("E", 2)
            go("time_skip", phrames=250)
            print(f"  [mw-evolve {rnd}] {fprog('mill_wakes')}")
            if "mill_wakes" in flags():
                break

        # mill_master: more Village incorporation (berry≥5, phase≥18.85)
        print("\n== ACT3: mill_master ==")
        for rnd in range(1, 9):
            if "mill_master" in flags():
                break
            incorporate(bn="Village")
            print(f"  [mm {rnd}] village berry={berry('Village')} | {fprog('mill_master')}")

        # ============ ACT 4: island_lives + village_identity ============
        print("\n== ACT4: island_lives (🪵 into Village) ==")
        # plant the already-known 🪵/🌾 lumber icon into Village
        if not go("flag_progress", id="island_lives").get("fired"):
            wood = next((i for i in known() if "🪵" in (i.get("north", ""), i.get("south", ""))), None)
            if wood:
                plant_icon(vk, wood["north"], wood["south"], "wood")
            press(vk); go("time_skip", phrames=120)
        print("  ", fprog("island_lives"))

        # Branch-divergence reachability check (FINDING 2026-06-26): only village_path_artisan
        # auto-fires, because the Mill mechanically plants 🔨 into Village. The other branches
        # gate on a specific EMOJI in Village (💧/🏭/🦅/💀). commons needs 💧 — reachable in
        # principle (FreshwaterSpring realizes 💧-bearing icons like 🌿/💧, 🔥/💧), but ONLY if
        # you deliberately track+incorporate the 💧 qubit, then plant it before the 6-plot ring
        # saturates. The generic incorporate() doesn't target 💧, so commons stays dormant.
        # Best-effort: if a 💧-bearing icon is already known, plant it to demonstrate commons.
        spring = next((i for i in known() if "💧" in (i.get("north", ""), i.get("south", ""))), None)
        if spring:
            plant_icon(vk, spring["north"], spring["south"], "spring 💧 (commons)")
            press(vk); go("time_skip", phrames=120)
        else:
            print("  (no 💧-bearing icon known → village_path_commons unreachable this run)")

        print("\n== ACT4: village_identity (Village built + cross-biome atom diversity) ==")
        # predicates: [island_lives, atom_count Village>=8, atom_diversity>=N, signature>=14, gap>=0.12]
        # Reframed (owner): a biome's plot grid caps it at 5 qubits/10 atoms, so the old
        # atom_count_gte Village 12 was unsatisfiable. Now the LOCAL check is "Village built
        # out" (>=8, cleared by base+Mill+wood = 10 atoms) and the real goal is CROSS-BIOME
        # atom diversity — a varied ecology spread across the 6 biome slots. So KEEP discovered
        # biomes LOADED (their atoms count toward diversity) rather than culling them away.
        print("  start:", fprog("village_identity"))
        core = {"StarterForest", "Village", "Woodlot", "FreshwaterSpring"}

        def vi_pred(i):
            p = go("flag_progress", id="village_identity").get("predicates", [])
            return p[i]["score"] if i < len(p) else 0.0

        # local atom_count: Village built out (Mill+wood already did it; top up if short)
        for _ in range(3):
            if vi_pred(1) >= 0.9:
                break
            if not plant_first(vk):
                break
            press(vk); go("time_skip", phrames=120)

        # diversity (pred 2) + signature (pred 3): fill the 6 biome slots with DIVERSE biomes
        # and incorporate each. Keep them loaded so their atoms bank toward diversity; only
        # cull to SWAP out the thinnest non-core biome if full and still short.
        for rnd in range(1, 16):
            if vi_pred(2) >= 0.9 and vi_pred(3) >= 0.9:
                break
            if len(grid()) < 6:
                before = set(grid())
                bridge("🦅", 80)
                ensure_hat("7"); press("R", 6)  # Captain discover (fill a slot)
                for nb in [b for b in grid() if b not in before]:
                    bk2 = biome_key(nb)
                    if bk2:
                        press(bk2)
                        for _ in range(2):
                            incorporate(bn=nb)
            else:
                # 6 loaded but still short → drop the thinnest non-core biome, rediscover next round
                per = go("atom_diversity").get("per_biome", {})
                keep = core | protected_landmarks()
                thin = sorted([(v, b) for b, v in per.items() if b not in keep])
                if thin:
                    cull(thin[0][1])
            ad = go("atom_diversity")
            print(f"    [vi {rnd}] loaded={len(grid())} distinct={ad.get('distinct')} "
                  f"sig={len(known())} | {fprog('village_identity')}")
        print("  ", fprog("village_identity"))

        # ============ ACT 5: ledger_opens ============
        print("\n== ACT5: ledger_opens (discover BloodLedger + berry≥2) ==")
        # village_identity must have fired → BloodLedger inherits discovery pressure.
        # Slots cap ~6: cull the non-core biomes (discovered for sig) to make room, then
        # the pressured draw lands BloodLedger.
        for d in range(1, 16):
            if "BloodLedger" in grid():
                break
            cullable = [b for b in grid() if b not in (core | protected_landmarks()) and b != "BloodLedger"]
            if cullable:
                cull(cullable[0])
            bridge("🦅", 80)
            ensure_hat("7"); press("R", 6)  # discover (BloodLedger pressured)
            print(f"  discover BL #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")
        if "BloodLedger" in grid():
            blk = biome_key("BloodLedger")
            press(blk)
            for rnd in range(1, 8):
                incorporate(ripen=900, bn="BloodLedger")
                b = berry("BloodLedger")
                print(f"  [bl {rnd}] BloodLedger berry={b} | {fprog('ledger_opens')}")
                if isinstance(b, int) and b >= 2 and "ledger_opens" in flags():
                    break

        # ============ ACT 6: rigid empire vs plural island — the closed-native ending ====
        # The physics: a concentrated biome (the empire) has a WIDE H-gap (one dominant mode
        # it rigidly imposes); a diverse built island has a SMALL gap (many modes coexisting).
        # empire_imposes: ledger_opens + BloodLedger H-gap >= 0.6 (rigid monoculture — RECOGNIZED).
        # island_free:    empire_imposes + Village H-gap <= 0.45 (plural, many-voiced, free) +
        #                 diversity + signature. Freedom = irreducible plurality, not stillness.
        print("\n== ACT6: rigid empire vs plural island (empire_imposes -> island_free) ==")

        def gap(bn):
            r = go("energy_variance", biome=bn)
            return float(r.get("h_gap", -1.0)), float(r.get("var_h", -1.0))

        if "BloodLedger" in grid() and "ledger_opens" in flags():
            bl_g, bl_v = gap("BloodLedger")
            vg_g, vg_v = gap("Village")
            # MEASURE — empire should read a WIDE gap (rigid); the built island a SMALL one (plural).
            print(f"  MEASURE BloodLedger: H-gap={bl_g:.4f}  Var(H)={bl_v:.4f}   (rigid ⟺ gap ≥ 0.60)")
            print(f"  MEASURE Village:     H-gap={vg_g:.4f}  Var(H)={vg_v:.4f}   (plural ⟺ gap ≤ 0.45)")
            print(f"  baseline {fprog('empire_imposes')}")
            for rnd in range(1, 6):
                print(f"  [impose {rnd}] {fprog('empire_imposes')}")
                if "empire_imposes" in flags():
                    break
                go("time_skip", phrames=200)
            for rnd in range(1, 6):
                print(f"  [free {rnd}] {fprog('island_free')}")
                if "island_free" in flags():
                    break
                go("time_skip", phrames=300)
            # Story-beat captures: the finale mechanic made legible (B microscope on the
            # rigid empire vs the plural island) + the Arc spine in its fired end state.
            goto_biome("BloodLedger"); press("G", 3); press("B", 5); shot("b_bloodledger_rigid"); press("B", 3)
            goto_biome("Village"); press("G", 3); press("B", 5); shot("b_village_plural"); press("B", 3)
            press("C", 4); press("I", 3); shot("arc_final"); press("C", 3)
        else:
            print("  (BloodLedger/ledger_opens not reached — ending skipped)")

        # ============ B3: village_identity divergent branches ============
        print("\n== B3: village path branches (fire on which atom you built) ==")
        # What atoms actually ended up in Village (drives which paths can fire) + its H-gap
        # (does a coherent, diverse build stay plural?).
        vatoms = []
        vrm = go("realization_debug", biome="Village")
        try:
            vqc = go("energy_variance", biome="Village")
            print(f"  Village: H-gap={vqc.get('h_gap', -1):.4f} (plural ⟺ ≤0.45)  atoms_emojis={vrm.get('emojis')}")
        except Exception as e:
            print(f"  Village readout error: {e}")
        for fid in ("village_path_commons", "village_path_industrial", "village_path_artisan",
                    "village_path_watched", "village_path_cemetery"):
            print("  ", fprog(fid))

        # ============ ACT 6-8: the wet country (endgame; ACT35_ENDGAME=1) ============
        # The crossing into GildedRot, What Fades, and What Connects III-V. Discovery
        # pressure CHAINS here by construction: each next-reachable flag names its biome
        # in a predicate, so the Captain draw pulls Lanternfall -> GildedRot -> ZenoLatch
        # -> ShrineOfAshes -> NullingChamber in story order, no hand-tuned leans.
        if os.environ.get("ACT35_ENDGAME", "0") == "1":
            print("\n== ACT6-8: the wet country (crossing -> rite -> door) ==")

            def discover_target(target, tries=16):
                # The endgame releases the act-2 anchors (their flags are long fired)
                # so slots exist for the wet landmarks; landmark protection is dynamic.
                endgame_core = {"Village", "StarterForest"}
                for d in range(1, tries + 1):
                    if target in grid():
                        return True
                    keep = endgame_core | protected_landmarks()
                    cullable = [b for b in grid() if b not in keep and b != target]
                    if cullable:
                        cull(cullable[0])
                    bridge("🦅", 80)
                    ensure_hat("7"); press("R", 6)
                    print(f"  discover {target} #{d}: grid={grid()}")
                return target in grid()

            def berries_to(target_biome, want, fid):
                for rnd in range(1, 10):
                    incorporate(ripen=900, bn=target_biome)
                    b = berry(target_biome)
                    print(f"  [{target_biome} {rnd}] berry={b} | {fprog(fid)}")
                    if isinstance(b, int) and b >= want and fid in flags():
                        return True
                return fid in flags()

            # chain_ends (act-3 trilogy prerequisite for the_chain_tested)
            if discover_target("Lanternfall"):
                berries_to("Lanternfall", 1, "chain_ends")

            # the_crossing + the_gray: GildedRot is the wet-country door
            if discover_target("GildedRot"):
                go("time_skip", phrames=300)
                print(f"  {fprog('the_crossing')}")
                berries_to("GildedRot", 1, "the_gray")

            # the_span / braid_alphabet / the_fusion: Majorana bridge across the map.
            # Spark hat mode 2: R anchors near shore (StarterForest), R in another biome
            # (GildedRot) raises the span; F braids; Q fuses (destructive: Q arms, F commits).
            if "GildedRot" in grid():
                ensure_hat("4"); press("2", 3)
                press(biome_key("StarterForest")); press("G", 3); press("R", 5)
                press(biome_key("GildedRot")); press("G", 3); press("R", 5)
                print(f"  {fprog('the_span')}")
                for _ in range(4):
                    press("F", 4)                       # braid the span
                print(f"  {fprog('braid_alphabet')}")
                press("Q", 4); press("F", 5)            # fuse (arm + confirm)
                press("1", 3)                           # back to shift mode
                print(f"  {fprog('the_fusion')}")

            # the_first_contract: a spark recorded in the gate sequence — jolt on wet ground
            if "GildedRot" in grid():
                press(biome_key("GildedRot")); ensure_hat("4"); press("1", 3)
                press("G", 3); press("R", 5)             # spark north (legal: open ground)
                print(f"  {fprog('the_first_contract')}")

            # watching_keeps -> the_basin -> hiding_in_the_light: the wet landmarks
            for target, fid in (("ZenoLatch", "watching_keeps"),
                                ("ShrineOfAshes", "the_basin"),
                                ("NullingChamber", "hiding_in_the_light")):
                if discover_target(target):
                    go("time_skip", phrames=300)
                    print(f"  {fprog(fid)}")

            # the_rite: three seasons of GildedRot berries; the_door_stays_open: sig>=18
            berries_to("GildedRot", 3, "the_rite")
            go("time_skip", phrames=300)
            print(f"  {fprog('the_door_stays_open')}")

            print("\n== ENDGAME RESULT ==")
            for fid in ("chain_ends", "the_crossing", "the_gray", "the_span",
                        "watching_keeps", "the_verbs_come_home", "the_first_contract",
                        "the_basin", "the_chain_tested", "hiding_in_the_light",
                        "braid_alphabet", "the_fusion", "the_rite", "the_door_stays_open"):
                print("  ", fprog(fid))

        # ============ RESULT ============
        print("\n== RESULT ==")
        for fid in ("mill_wakes", "mill_master", "island_lives", "village_identity",
                    "ledger_opens", "empire_imposes", "island_free"):
            print("  ", fprog(fid))
        print("  flags:", sorted(flags().keys()))

        # ============ PANEL GALLERY — screenshot every panel (headed + RIG_SHOTS) ============
        if _shots_on:
            gallery()
    finally:
        go("stop")
        c.terminate_listener(proc)


if __name__ == "__main__":
    main()
