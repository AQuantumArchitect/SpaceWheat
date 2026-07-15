#!/usr/bin/env python3
"""Drive Acts 3-5 by keyboard, on top of a fresh Act-1/2 run.

The rig boots fresh each run, so this replays the proven Act-1 sequence first
(forest beats through loop_remembers + the mill apprenticeship), then walks the
Country Chapter order for Act 2 (the Millwright/Woodlot reweave):

  Act 2  woodlot_door  : fires off new_voices; grants Millwright access; its arc
                         points the discovery compass at Woodlot.
         woodlot_contact → lumber_flows : Millwright contracts ×3 at Village
                         (access 0.02 → 0.05 with authored widths), then CLAIM the
                         timber teaching (🪵/🪓) on the Arc tab.
         woodlot_wakes : plant 🪵/🪓 into Woodlot, then into Village (the DELIVER).
         timber_rhythm : Woodlot berries ≥2; claim the gear-bench word (🏭/⚙).
         spring chapter (Hearth Keepers — gate channel TRUST, banked ~0.30 from
         act 1): spring_door fires off lumber_flows → discover FreshwaterSpring
         (pressured #1 — the stagger) → Hearth deliveries ×2-3 clear
         spring_contact (trust 0.35 w.02) + the teaching gate (0.42 w.02) →
         claim the water teaching (💧/🌊) → plant the spring, then the Village
         (the mill pond DELIVER) → Spring berries ≥2 → pond_depths/pond_breathes.

then pushes into:

  Act 3  mill_wakes   : learn Mill (village_stirs apprentice arc) → plant Mill into
                        an empty Village plot → evolve so ⚙→💨 populates wind.
         mill_master  : keep incorporating Village registers (berry≥5, phase≥18.85).
         lantern chapter (Lamplighters — contact by WITNESS, not contracts; their
         market opens nowhere early): lantern_door fires off mill_wakes → discover
         Lanternfall → berry ×1 + stand the watch → chain_ends (grants trust 0.08,
         which clears the teaching gate 0.07 w.01) → hold the beacon 🪔 ≥ 55% to
         ready the claim → claim the bridge word (🌉/🪔) → plant it INTO LANTERNFALL
         (no Village coupling — the chain is complete in itself) → lantern_wakes →
         chain_flipped (deepening: the horn drains, the bridge holds).
  Act 4  island_lives : fires by construction (the three chapter plants put 🪵 in the
                        Village and lumber_flows + spring_connects + mill_wakes fired).
         village_identity : A Character — the re-priced hub gate (atoms 12 / diversity
                        banked / signature 14): ONE more deliberate incorporation.
         five_doors + eagle_overhead + serfs_ledger : the naming beat and the two dark
                        teachers cascade; claim the Throne's word (🩸/🦅), unseat the
                        timber register (Icon hat Q — flags latch), plant the eagle's
                        key → village_path_watched fires (first time in QA history).
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
        # goto FIRST: plot keys land on the ACTIVE biome — reading qstate(bn) while
        # pressing keys at whatever was active silently farmed the wrong biome
        # (Lanternfall banked 0 berries across 9 rounds this exact way).
        if bn:
            goto_biome(bn)
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

    def farm_berries(target_biome, want, fid, rounds=12):
        # ONE SITE PER ROUND: rigid-H biomes (the SSH chain, the empire monolith)
        # are near-stationary when every site is excited at once — the joint state
        # parks in an eigenstate and nothing ripens. A single excitation always
        # beats against its pinned neighbours. (Measured on Lanternfall: -77 rad
        # per 1800 phrames single-site vs flat 0.0 all-sites.)
        goto_biome(target_biome)
        n = len(qstate(target_biome)) or 1
        for rnd in range(1, rounds + 1):
            idx = (rnd - 1) % min(n, len(PLOT))
            pk = PLOT[idx]
            ensure_hat("0"); press(pk, 3); press("E", 3)
            ensure_hat("5"); press(pk, 3)
            trk = [bool(q.get("tracked")) for q in qstate(target_biome)]
            if idx >= len(trk) or not trk[idx]:
                press("F", 3)
            go("time_skip", phrames=900)
            press(pk, 3); press("R", 4)
            b = berry(target_biome)
            print(f"  [{target_biome} {rnd}] berry={b} | {fprog(fid)}")
            if isinstance(b, int) and b >= want and fid in flags():
                return True
        return fid in flags()

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
        bridge(south, 18); bridge("🌱", 10)  # inject = 5×🌱 + 13×south
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
            bridge(str(v.get("south", "")), 18); bridge("🌱", 10)  # inject = 5×🌱 + 13×south
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
    LANDMARK_GATE = {"Lanternfall": "chain_flipped", "GildedRot": "the_rite",
                     "ZenoLatch": "watching_keeps", "ShrineOfAshes": "the_basin",
                     "NullingChamber": "hiding_in_the_light"}

    def protected_landmarks():
        fl = flags()
        return {b for b, fid in LANDMARK_GATE.items() if fid not in fl}

    def cullable_from(grid_now, keep, extra_exclude=()):
        """Non-protected first; if the grid is ALL keep (protection deadlock —
        6 slots, 6 protected = no room to discover, the loop starves), release
        a zero-progress landmark: it holds no berries, and discovery pressure
        re-pulls it the moment its flag is next-reachable."""
        cand = [b for b in grid_now if b not in keep and b not in extra_exclude]
        if cand:
            return cand
        return [b for b in grid_now
                if b in LANDMARK_GATE and b not in extra_exclude
                and not (isinstance(berry(b), int) and berry(b) > 0)]

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

    def word_known(north, south):
        return any(i.get("north") == north and i.get("south") == south for i in known())

    def is_mill_known():
        return word_known("💨", "🔨")

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

    def claim_teaching(north, south, work_biome, accept_snippet, work=None):
        """Learn a faction word via a story ARC claim (the ONLY teacher of vocabulary —
        contracts never teach). Gotchas, all probe-confirmed on the mill apprenticeship:
          (1) the arc flips "ready" via berries in `work_biome`; ONLY incorporation
              grows berry, time_skip does not. Needs current_biome=work_biome (press
              its key) for the readiness poll to run.
          (2) ARC-tab accept must be TARGETED (match the row by `accept_snippet`):
              a blind accept-all also accepts tutorial/guidance rows, and the claim
              then lands past the COMMITMENTS tab's 6-row render cap (measured:
              idx=8 READY, unclaimable).
          (3) COMMITMENTS-tab claim: select the arc's EXACT index (by its reward
              pair), not index 0 (other commitments would bury it)."""
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
            go("time_skip", phrames=150)           # current_biome=work_biome → flip ready
            idx, st, qid = arc_commitment()
            print(f"  [claim {north}/{south} #{attempt}] arc idx={idx} status={st} berry={berry(work_biome)}")
            if st == "ready":
                if 0 <= idx < len(PLOT):
                    press("C"); press("U", 4)      # COMMITMENTS tab
                    press(PLOT[idx], 3); press("R", 4)  # select arc's exact row + claim
                    press("ESCAPE", 3)
                if not word_known(north, south) and qid >= 0:
                    # Row beyond the 6-row cap — claim through the SAME
                    # QuestManager seam by id. NOTE: a claim that "succeeds"
                    # without teaching means the signature REFUSED the pair
                    # (Farm.discover_icon: north must be new) — a data problem,
                    # not a driver problem.
                    r = go("complete_or_claim", quest_id=qid)
                    print(f"    (claim by id: {bool(r.get('completed_or_claimed'))})")
            else:
                if work is not None:
                    work()          # chapter-specific readiness ritual (e.g. the lamp hold)
                else:
                    incorporate(bn=work_biome)
        ok = word_known(north, south)
        print(f"  {north}/{south} learned: {ok}")
        return ok

    def learn_mill(vk):
        """Learn the Mill icon (💨/🔨) via the village_stirs apprentice arc. Run this
        BEFORE the Act-2 market grinds so the COMMITMENTS tab is clean."""
        press(vk)
        for rnd in range(1, 9):
            incorporate(bn="Village")
            b = berry("Village")
            print(f"  [mill-inc {rnd}] village berry={b} village_stirs={'village_stirs' in flags()}")
            if "village_stirs" in flags() and isinstance(b, int) and b >= 6:
                break
        return claim_teaching("💨", "🔨", "Village", "Apprentice to the Mill")

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
        vk = biome_key("Village") or "Y"

        # Shared cross-act helpers (used by acts 2-6 on every lane).
        def plant_pair(bn_name, north, south, label=""):
            # Picker keys first; the picker shows only ~3 slots, so a grown
            # signature can hide the pair — fall back to the inject_icon
            # instrument (same injection seam).
            bk3 = biome_key(bn_name)
            if bk3 and plant_icon(bk3, north, south, label):
                return True
            bridge(south, 18); bridge("🌱", 10)  # inject = 5×🌱 + 13×south
            rr = go("inject_icon", biome=bn_name, north=north, south=south).get("inject_result", {})
            print(f"    (picker path failed — inject_icon {north}/{south} → {bn_name}: success={rr.get('success')})")
            return bool(rr.get("success"))

        def biome_pops(bn):
            snap = go("lindblad_snapshot", biome=bn).get("lindblad_snapshot", {})
            for _, bd in (snap.get("biomes") or {}).items():
                return bd.get("populations", {}) or {}
            return {}

        # ============ ACT 1: forest_communion + forest_listener ============
        # Resume lanes (the relay-fleet pattern — a full fresh run no longer fits
        # one 10-minute window, so legs bank checkpoints and hand off):
        #   ACT35_RESUME=1        loads the banked post-island_free checkpoint and
        #                         skips straight to the endgame (as before).
        #   ACT35_RESUME_ACT3=path loads a mid-run bank (post-mill or post-lantern)
        #                         and re-enters the spine there: the lantern chapter
        #                         self-skips once chain_flipped is fired.
        #   ACT35_BANK=prefix     banks <prefix>_mill.tres after mill_master and
        #                         <prefix>_lantern.tres after the lantern chapter.
        # Story flags survive save/load (verified 2026-07-05); the listener rebinds
        # its farm after loads. KNOWN GAP: per-biome berry counters reset on load,
        # so berry-readiness bars re-earn on a resumed leg (acceptable-generous:
        # incorporation is always available).
        _resume = os.environ.get("ACT35_RESUME", "0") == "1"
        _ckpt = os.environ.get("ACT35_CHECKPOINT", "/tmp/sw_act6_checkpoint.tres")
        _r3 = os.environ.get("ACT35_RESUME_ACT3", "")
        _bank = os.environ.get("ACT35_BANK", "")
        if _resume:
            r_ld = go("load_game_path", path=_ckpt)
            print(f"  RESUME: loaded={r_ld.get('loaded')} flags={len(flags())} grid={grid()}")
        elif _r3:
            r_ld3 = go("load_game_path", path=_r3)
            print(f"  RESUME-ACT3: loaded={r_ld3.get('loaded')} flags={len(flags())} grid={grid()}")
        if not _resume and not _r3:
            print("\n== ACT1: StarterForest ==")
            goto_biome("StarterForest")  # slots follow scenario order now (TheDemos boots on T)
            # loop_remembers (forest berry ≥7) is now LOAD-BEARING: new_voices needs it,
            # and the whole Act-2 timber chapter hangs off new_voices → woodlot_door.
            for rnd in range(1, 13):
                incorporate()
                fl = flags()
                print(f"  [A{rnd}] forest berry={berry('StarterForest')} communion={'forest_communion' in fl} "
                      f"listener={'forest_listener' in fl} loop_remembers={'loop_remembers' in fl}")
                if "forest_communion" in fl and "forest_listener" in fl and "loop_remembers" in fl:
                    break
            bridge("🦅", 220); bridge("👥", 240); bridge("🍞", 500); bridge("❄", 500)
            bridge("🔨", 60); bridge("🌱", 60)
            print("  bridged:", {k: res().get(k, 0) for k in ("🦅", "🍞", "👥", "❄", "🔨", "🌱")})

            # ---- Learn Mill NOW (clean commitments, before Act-2 grinds clutter them) ----
            # village_stirs needs forest_listener (just fired) + Village berry; the apprentice
            # arc rewards the Mill icon, which Act 3 plants to wake the wind.
            print("\n== learn Mill (apprentice arc, pre-Act-2) ==")
            learn_mill(vk)

            # ============ ACT 2: the timber chapter (Country Chapter order) ============
            # door → contact → teaching → wakes → rhythm; spring keeps its
            # pre-reweave path until chapter 2 lands.
            print("\n== ACT2: timber country (door → contact → teaching → wakes → rhythm) ==")
            go("time_skip", phrames=120)  # let new_voices → woodlot_door cascade fire
            print("  ", fprog("new_voices"))
            print("  ", fprog("woodlot_door"))

            # Beat 1 (door): discover Woodlot — its beats name it, so the compass is
            # story-pressured toward it. FreshwaterSpring waits for ITS door (the
            # stagger: one pressured biome at a time).
            for d in range(1, 9):
                if "Woodlot" in grid():
                    break
                ensure_hat("7")
                press("R", 6)
                print(f"  discover #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")

            # Beats 2+3 (contact → teaching): Millwright contracts at Village. The door
            # grant (access 0.02) + ~2 deliveries × 0.02 clears contact (0.02 w.008)
            # then the teaching gate (0.05 w.01) — the owner's 2-3 contract budget.
            if "lumber_flows" not in flags():
                faction_grind("Millwright's Union", "lumber_flows", max_cycles=8, at_biome="Village")
            print("  ", fprog("woodlot_contact"))
            print("  ", fprog("lumber_flows"))

            # Beat 3 claim: the teaching IS the claim (Arc tab). Readiness = Village
            # berries ≥4, already banked by the mill apprenticeship.
            claim_teaching("🪵", "🪓", "Village", "teach you timber")

            # Beat 4 (wakes): plant timber into the woodlot's ring, then couple the
            # Village (the DELIVER — the island economy line). plant_pair is the
            # shared helper (picker first, inject_icon instrument fallback).
            if word_known("🪵", "🪓"):
                plant_pair("Woodlot", "🪵", "🪓", "timber → Woodlot")
                plant_pair("Village", "🪵", "🪓", "timber → Village (couple)")
            press(vk); go("time_skip", phrames=120)
            print("  ", fprog("woodlot_wakes"))

            # Beat 5 (rhythm): berries in the now-awake country, then claim the
            # gear-bench word (⚙/🏭 — pre-seeds the industrial door).
            farm_berries("Woodlot", 2, "timber_rhythm", rounds=8)
            print("  ", fprog("timber_rhythm"))
            if "timber_rhythm" in flags():
                farm_berries("Woodlot", 4, "timber_rhythm", rounds=6)
                claim_teaching("🏭", "⚙", "Woodlot", "The Gear-Bench")

        # -- relay bank #-1: act 1 + timber chapter done (all claims settled) --
        if _bank and not _resume and "pond_breathes" not in flags():
            r_bt = go("save_game_path", path=_bank + "_timber.tres")
            print(f"  BANK timber checkpoint: {r_bt.get('saved')} -> {_bank}_timber.tres")

        if not _resume and "pond_breathes" not in flags():
            # ---- chapter-2 country (Spring): door → contact → teaching → wakes → depths ----
            print("\n== ACT2: spring country (Hearth Keepers — trust, not access) ==")
            go("time_skip", phrames=120)  # let lumber_flows → spring_door cascade fire
            print("  ", fprog("spring_door"))

            # Beat 1 (door): discover FreshwaterSpring — the compass pressures it #1 now.
            # Same slot dance as the lantern/BL loops: a full grid REFUSES discovery
            # (leg 2026-07-14: 8 draws no-oped against 6 held slots and the lane lost
            # the water word for good — flags latched on, registers never planted).
            act2_core = {"StarterForest", "TheDemos", "Village", "Woodlot"}
            for d in range(1, 9):
                if "FreshwaterSpring" in grid():
                    break
                if len(grid()) >= 6:
                    cullable = cullable_from(grid(), act2_core | protected_landmarks(),
                                             ("FreshwaterSpring",))
                    if cullable:
                        cull(cullable[0])
                bridge("🦅", 80)
                ensure_hat("7")
                press("R", 6)
                print(f"  discover spring #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")

            # Beats 2+3 (contact → teaching gate): Hearth deliveries. Their channel
            # is TRUST (banked ~0.30 from act 1); +0.05/delivery clears contact
            # (0.35 w.02) then the teaching gate (0.42 w.02) — the 2-3 contract budget.
            if "spring_connects" not in flags():
                faction_grind("Hearth Keepers", "spring_connects", max_cycles=8, at_biome="Village")
            print("  ", fprog("spring_contact"))
            print("  ", fprog("spring_connects"))

            # Beat 3 claim: readiness = StarterForest berries ≥8 (one more loop in
            # the shared forest — act 1 banked 7 for loop_remembers).
            claim_teaching("💧", "🌊", "StarterForest", "teach you water")

            # Beat 4 (wakes): plant water into the spring's stone, then couple the
            # Village (the mill pond DELIVER).
            if word_known("💧", "🌊"):
                plant_pair("FreshwaterSpring", "💧", "🌊", "water → FreshwaterSpring")
                plant_pair("Village", "💧", "🌊", "water → Village (mill pond)")
            press(vk); go("time_skip", phrames=120)
            print("  ", fprog("spring_wakes"))

            # Beat 5 (deepening): Spring berries ≥2 → pond_depths; pond_breathes chains.
            farm_berries("FreshwaterSpring", 2, "pond_depths", rounds=8)
            print("  ", fprog("pond_depths"))
            print("  ", fprog("pond_breathes"))

        # -- relay bank #0: acts 1-2 done (a loaded machine can stall a fresh leg
        #    before the mill; the next leg re-enters at act 3) --
        if _bank and not _resume and "mill_master" not in flags():
            r_b0 = go("save_game_path", path=_bank + "_spring.tres")
            print(f"  BANK spring checkpoint: {r_b0.get('saved')} -> {_bank}_spring.tres")

        if not _resume and "mill_master" not in flags():
            # ============ ACT 3: mill_wakes + mill_master ============
            print("\n== ACT3: mill_wakes ==")
            # Mill was learned pre-Act-2. Plant it into Village, evolve so ⚙→💨 wakes wind.
            learned_mill = is_mill_known()
            print(f"  Mill known: {learned_mill}")
            if learned_mill:
                plant_icon(vk, "💨", "🔨", "Mill")

            def mill_measure(tag):
                p = biome_pops("Village")
                fp = go("flag_progress", id="mill_wakes")
                sc = ["%.4f" % float(ps["score"]) for ps in fp.get("predicates", [])]
                print(f"    MEASURE[{tag}] Village 💨={float(p.get('💨', 0)):.4f} "
                      f"⚙={float(p.get('⚙', 0)):.4f} (register sums) scores={sc}")

            mill_measure("at-plant")
            for rnd in range(1, 8):
                press(vk)
                ensure_hat("0")
                for pk in PLOT:
                    press(pk, 2); press("E", 2)
                go("time_skip", phrames=250)
                print(f"  [mw-evolve {rnd}] {fprog('mill_wakes')}")
                mill_measure(f"evolve-{rnd}")
                if "mill_wakes" in flags():
                    break

            # mill_master: more Village incorporation (berry≥5, phase≥18.85)
            print("\n== ACT3: mill_master ==")
            for rnd in range(1, 9):
                if "mill_master" in flags():
                    break
                incorporate(bn="Village")
                print(f"  [mm {rnd}] village berry={berry('Village')} | {fprog('mill_master')}")
            bs_v = go("berry_state", biome="Village")
            print(f"  MEASURE mill_master: berries={bs_v.get('consumed_count')} "
                  f"phase={float(bs_v.get('consumed_phase', 0) or 0):.2f} (gates: berries 8, phase 50.27)")

        # -- relay bank #1: acts 1-2 + mill done (leg 2 re-enters at the lantern) --
        if _bank and not _resume and "chain_flipped" not in flags():
            r_b1 = go("save_game_path", path=_bank + "_mill.tres")
            print(f"  BANK mill checkpoint: {r_b1.get('saved')} -> {_bank}_mill.tres")

        if not _resume and "chain_flipped" not in flags():
            # ============ ACT 3: lantern country (chapter 3 — contact by witness) ====
            print("\n== ACT3: lantern country (Lamplighters — witness, not contracts) ==")
            go("time_skip", phrames=120)  # mill_wakes → lantern_door cascade
            print("  ", fprog("lantern_door"))

            # Beat 1 (door): discover Lanternfall — chain_ends names it, so once the
            # door fires the compass pressures the coast. Slots may be full of act-2
            # land; cull non-core strays (never the act-2 anchors, never TheDemos,
            # never protected landmarks).
            act3_core = {"StarterForest", "TheDemos", "Village", "Woodlot",
                         "FreshwaterSpring"}
            for d in range(1, 10):
                if "Lanternfall" in grid():
                    break
                if len(grid()) >= 6:
                    cullable = cullable_from(grid(), act3_core | protected_landmarks(),
                                             ("Lanternfall",))
                    if cullable:
                        cull(cullable[0])
                bridge("🦅", 80)
                ensure_hat("7"); press("R", 6)
                print(f"  discover lantern #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")

            if "Lanternfall" in grid():
                # Beat 2 (witness): stand the watch — one berry in the chain fires
                # chain_ends (its trust grant 0.08 then clears the teaching gate
                # 0.07 w.01 by itself: witness, not baskets).
                farm_berries("Lanternfall", 1, "chain_ends", rounds=9)
                print("  ", fprog("chain_ends"))
                go("time_skip", phrames=120)  # grant → lantern_teaching cascade
                print("  ", fprog("lantern_teaching"))

                # Beat 3 (teaching): hold the beacon 🪔 ≥ 55% to ready the claim.
                # Readiness LATCHES (QuestManager marks ready at the first 0.85
                # crossing), so the lamp's oscillation only has to peak once while
                # the claim is accepted.
                def lamp_hold():
                    goto_biome("Lanternfall")
                    ensure_hat("0")
                    for _ in range(3):
                        press("G", 3); press("E", 3)  # excite the beacon (site 0)
                        go("time_skip", phrames=900)
                        p = biome_pops("Lanternfall")
                        print(f"    [lamp] 🪔={float(p.get('🪔', 0)):.3f} "
                              f"🗼={float(p.get('🗼', 0)):.3f} "
                              f"📯={float(p.get('📯', 0)):.3f}")

                claim_teaching("🌉", "🪔", "Lanternfall", "teach you the bridge",
                               work=lamp_hold)

                # Beat 4 (wakes): plant the bridge INTO LANTERNFALL — the chain
                # closes on itself; no Village coupling (the Lamplighter variation).
                if word_known("🌉", "🪔"):
                    plant_pair("Lanternfall", "🌉", "🪔", "bridge → Lanternfall")
                goto_biome("Lanternfall"); go("time_skip", phrames=120)
                ev3 = go("energy_variance", biome="Lanternfall")
                p3 = {k: round(float(v), 3) for k, v in biome_pops("Lanternfall").items()}
                print(f"  MEASURE Lanternfall post-plant: h_gap={float(ev3.get('h_gap', -1)):.4f} pops={p3}")
                print("  ", fprog("lantern_wakes"))

                # Beat 5 (deepening): chain_flipped rides lantern_wakes; its arc bar
                # (📯 ≤ 25% while 🌉 ≥ 35%) is LIVE now — the plant realized 🌉.
                go("time_skip", phrames=300)
                print("  ", fprog("chain_flipped"))
            else:
                print("  (Lanternfall not discovered — lantern chapter skipped)")

        # -- relay bank #2: act 3 complete (leg 3 re-enters at the act-4 hub) --
        if _bank and not _resume:
            r_b2 = go("save_game_path", path=_bank + "_lantern.tres")
            print(f"  BANK lantern checkpoint: {r_b2.get('saved')} -> {_bank}_lantern.tres")

        if not _resume:
            # ============ ACT 4: island_lives + village_identity ============
            print("\n== ACT4: island_lives (🪵 into Village) ==")
            # plant the already-known 🪵/🌾 lumber icon into Village
            if not go("flag_progress", id="island_lives").get("fired"):
                wood = next((i for i in known() if "🪵" in (i.get("north", ""), i.get("south", ""))), None)
                if wood:
                    plant_icon(vk, wood["north"], wood["south"], "wood")
                press(vk); go("time_skip", phrames=120)
            print("  ", fprog("island_lives"))

            # Branch-divergence (FINDING 2026-06-26, resolved by chapter 2): commons needs
            # 💧 in Village — the spring chapter's mill-pond DELIVER plants it by
            # construction, so village_path_commons is now story-reachable. Fallback
            # only if the chapter somehow didn't land the plant. CHECK THE LIVE STATE,
            # not the spring_wakes flag: on a relay lane the flag can be banked while
            # the plant died with an unsaved leg (flags latch; registers are state) —
            # trusting the flag left Village at 10 atoms and deadlocked village_identity.
            vpc0 = go("flag_progress", id="village_path_commons").get("predicates", [])
            water_in = any(p.get("pred", {}).get("type") == "atom_in_biome"
                           and float(p.get("score", 0.0)) > 0.5 for p in vpc0)
            if water_in:
                print("  (💧 lives in Village — commons armed)")
            else:
                if not word_known("💧", "🌊"):
                    # Relay lane: spring_connects latched but its CLAIM died with an
                    # unsaved leg. StoryEngine restores unclaimed arc offers on load —
                    # re-claim the water teaching (readiness = forest berries 8).
                    print("  (water word missing on a relay lane — re-claiming the spring teaching)")
                    claim_teaching("💧", "🌊", "StarterForest", "teach you water")
                spring = next((i for i in known() if "💧" in (i.get("north", ""), i.get("south", ""))), None)
                if spring:
                    # plant_pair, not bare plant_icon: the picker hides pairs once the
                    # signature outgrows its ~3 visible slots — the inject_icon fallback
                    # is the same seam and is what actually lands on a relay lane.
                    plant_pair("Village", spring["north"], spring["south"], "spring 💧 (commons)")
                    press(vk); go("time_skip", phrames=120)
                else:
                    print("  (no 💧-bearing icon known → village_path_commons unreachable this run)")

            print("\n== ACT4: village_identity (A Character — one more deliberate word) ==")
            # RE-PRICED (act-4 hub chapter): atoms 12 (Village at its 6-qubit cap — banked
            # by construction: 3 natives + mill + wood + pond) / diversity CAL (banked by
            # the loaded chapter countries) / signature 14 (post-island_lives canonical
            # reads 13 — ONE more deliberate incorporation fires it). The old 30-round
            # RNG discovery grind is gone; island_free's own diversity-18 bar is carried
            # by the same loaded countries (measured 34 on the canonical build).
            core = {"StarterForest", "Village", "Woodlot", "FreshwaterSpring"}
            ad0 = go("atom_diversity")
            print(f"  CALIBRATE post-island_lives: village_atoms={ad0.get('per_biome', {}).get('Village')} "
                  f"distinct={ad0.get('distinct')} sig={len(known())} "
                  f"villageBerries={berry('Village')} forestBerries={berry('StarterForest')}")
            print("  start:", fprog("village_identity"))
            # The one deliberate act: incorporate a word the road didn't hand you —
            # untapped registers live in the lantern's horn / woodlot / spring.
            for bn in ("Lanternfall", "Woodlot", "FreshwaterSpring", "StarterForest"):
                if go("flag_progress", id="village_identity").get("fired"):
                    break
                if bn not in grid():
                    continue
                b0 = berry(bn)
                want = (b0 + 1) if isinstance(b0, int) else 1
                farm_berries(bn, want, "village_identity", rounds=3)
            press(vk); go("time_skip", phrames=150)
            print("  ", fprog("village_identity"))

            # Relay bank #3.5 (identity): the hub gate is the act-4 midpoint; the
            # water-reclaim + eagle-claim stretches each cost minutes of berry
            # re-earn on a loaded lane — don't make a dead leg repeat both.
            if _bank and not _resume and go("flag_progress", id="village_identity").get("fired"):
                r_b35 = go("save_game_path", path=_bank + "_identity.tres")
                print(f"  BANK identity checkpoint: {r_b35.get('saved')} -> {_bank}_identity.tres")

            # ---- five_doors + both branch teachers cascade off village_identity;
            #      commons (💧, pond) + artisan (🔨, mill) are armed by construction.
            print("\n== ACT4: five doors (the naming beat + the two dark teachers) ==")
            go("time_skip", phrames=120)
            for fid in ("five_doors", "eagle_overhead", "serfs_ledger",
                        "village_path_commons", "village_path_artisan"):
                print("  ", fprog(fid))

            # ---- the eagle door (village_path_watched — never fired in QA history):
            # claim the Throne's word (🩸/🦅 — Predation FLIPPED per the signature law:
            # 🦅 was organically incorporated in act 1 via Raptor 🦅/🐇), unseat the
            # timber word (island_lives long fired — flags latch), plant the key.
            print("\n== ACT4: the eagle door (claim 🩸/🦅 → unseat the mill → plant the key) ==")
            if not go("flag_progress", id="eagle_overhead").get("fired"):
                # The eagle arc is offered when eagle_overhead FIRES (← village_identity).
                # Claiming an unoffered arc farms berries into a void (leg 2026-07-14:
                # six blind rounds, ~6 min) — bail loudly instead.
                print("  (eagle_overhead not fired — hub gate still open; door skipped)")
            else:
                claim_teaching("🩸", "🦅", "Village", "The Eagle's Word")

            def trim_village_last():
                """Icon hat Q = Trim Icon (destructive: Q arms; the confirm toast eats
                the FIRST F — press F until the qubit count drops, the cull() dance).
                Targets the LAST register — deterministic on BOTH lanes: on a fresh
                run the last Village plant is the mill (natives 0-2, wood 3, pond 4,
                mill 5), and on a resumed run the plot-terminal binding is not
                restored so remove_icon falls back to num_qubits-1 anyway. Every
                flag that needed 💨/🔨 (mill_wakes, artisan) is long fired — flags
                latch. Cost: 13🐺 + 3 of each pole — bridged like every grind."""
                goto_biome("Village")
                before = len(qstate("Village"))
                if before < 2:
                    print(f"    ✗ trim: too few registers (qubits={before})")
                    return False
                bridge("🐺", 30); bridge("💨", 6); bridge("🔨", 6)
                ensure_hat("5")
                press(PLOT[before - 1], 3)
                press("Q", 3)
                for _ in range(4):
                    press("F", 3)
                    if len(qstate("Village")) < before:
                        break
                ok = len(qstate("Village")) < before
                print(f"    trimmed last register: {'ok' if ok else 'FAILED'} "
                      f"(qubits {before}→{len(qstate('Village'))}) | {fprog('island_lives')}")
                return ok

            if word_known("🩸", "🦅") and not go("flag_progress", id="village_path_watched").get("fired"):
                trim_village_last()
                plant_pair("Village", "🩸", "🦅", "the eagle's key → Village")
                press(vk); go("time_skip", phrames=180)
                ev4 = go("energy_variance", biome="Village")
                print(f"  MEASURE Village post-eagle: H-gap={float(ev4.get('h_gap', -1)):.4f} "
                      f"(island_free gate ≤ 0.55, empire band 0.6)")
                print("  ", fprog("village_path_watched"))
            ad4 = go("atom_diversity")
            print(f"  post-doors: distinct={ad4.get('distinct')} sig={len(known())}")

            # Relay bank #4 (hub): act 4 done, act 5-6 (ledger → ending) still ahead.
            # Under machine load the lantern→ending stretch no longer fits one leg.
            if _bank and not _resume:
                r_b4 = go("save_game_path", path=_bank + "_hub.tres")
                print(f"  BANK hub checkpoint: {r_b4.get('saved')} -> {_bank}_hub.tres")

            # ============ ACT 5: ledger_opens ============
            print("\n== ACT5: ledger_opens (discover BloodLedger + berry≥2) ==")
            # village_identity must have fired → BloodLedger inherits discovery pressure.
            # Slots cap ~6: cull the non-core biomes (discovered for sig) to make room, then
            # the pressured draw lands BloodLedger.
            for d in range(1, 16):
                if "BloodLedger" in grid():
                    break
                cullable = cullable_from(grid(), core | protected_landmarks(), ("BloodLedger",))
                if cullable:
                    cull(cullable[0])
                bridge("🦅", 80)
                ensure_hat("7"); press("R", 6)  # discover (BloodLedger pressured)
                print(f"  discover BL #{d}: grid={grid()} 🦅={res().get('🦅', 0)}")
            if "BloodLedger" in grid():
                farm_berries("BloodLedger", 2, "ledger_opens", rounds=12)

            # ============ ACT 6: rigid empire vs plural island — the closed-native ending ====
            # The physics: a concentrated biome (the empire) has a WIDE H-gap (one dominant mode
            # it rigidly imposes); a diverse built island has a SMALL gap (many modes coexisting).
            # empire_imposes: ledger_opens + BloodLedger H-gap >= 0.6 (rigid monoculture — RECOGNIZED).
            # island_free:    empire_imposes + Village H-gap <= 0.55 (plural, many-voiced, free;
            #                 re-pinned from 0.45 when chapter 2's mill-pond DELIVER made 💧/🌊
            #                 a canonical Village resident — measured 0.5099) +
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
                print(f"  MEASURE Village:     H-gap={vg_g:.4f}  Var(H)={vg_v:.4f}   (plural ⟺ gap ≤ 0.55)")
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
                print(f"  Village: H-gap={vqc.get('h_gap', -1):.4f} (plural ⟺ ≤0.55)  atoms_emojis={vrm.get('emojis')}")
            except Exception as e:
                print(f"  Village readout error: {e}")
            for fid in ("village_path_commons", "village_path_industrial", "village_path_artisan",
                        "village_path_watched", "village_path_cemetery"):
                print("  ", fprog(fid))

        if not _resume:
            r_sv = go("save_game_path", path=_ckpt)
            print(f"  checkpoint saved: {r_sv.get('saved')} -> {_ckpt}")

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
                    cullable = cullable_from(grid(), keep, (target,))
                    if cullable:
                        cull(cullable[0])
                    bridge("🦅", 80)
                    ensure_hat("7"); press("R", 6)
                    print(f"  discover {target} #{d}: grid={grid()}")
                return target in grid()

            def berries_to(target_biome, want, fid):
                return farm_berries(target_biome, want, fid, rounds=9)

            # chain_ends (act-3 trilogy prerequisite for the_chain_tested) — fired
            # in the main lane's lantern chapter on a fresh run; only chase it here
            # on a resume lane whose checkpoint predates the chapter.
            if "chain_ends" not in flags():
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
                # Soft-gate convention: score is 0.5 AT the predicate's center and fires
                # ~0.87·width past it (QuestMath.fire_value). So OVERSHOOT everything:
                # 2 spans (built_gte 1, w .75), 6 braids (braids_gte 4, w 1.0),
                # 2 fusions (fused_gte 1, w .75).
                ensure_hat("4"); press("2", 3)
                goto_biome("StarterForest"); press("G", 3); press("R", 5)   # span 1 near
                goto_biome("GildedRot"); press("G", 3); press("R", 5)       # span 1 far
                goto_biome("StarterForest"); press("G", 3); press("R", 5)   # span 2 near
                goto_biome("Village"); press("G", 3); press("R", 5)         # span 2 far
                bl = go("bridge_list")
                print(f"  [span] built={bl.get('built_total')} | {fprog('the_span')}")
                for _ in range(6):
                    press("F", 4)                       # braid (braids_total += 1 each)
                print(f"  {fprog('braid_alphabet')}")
                # Fuse targets bridges anchored at the CURRENT biome — one fuse per shore.
                goto_biome("Village"); press("Q", 4); press("F", 5)        # fuse span 2
                goto_biome("GildedRot"); press("Q", 4); press("F", 5)      # fuse span 1
                bl = go("bridge_list")
                print(f"  [span] braids={bl.get('braids_total')} fused={bl.get('fused_total')}")
                press("1", 3)                           # back to shift mode
                print(f"  {fprog('the_fusion')}")

            # the_first_contract: sparks recorded in the gate sequence — jolts on wet
            # ground. The jolt SPENDS the register's north-pole emoji, so stock it
            # first (same resource-bridge convention as the standings grind), and
            # overshoot the soft gate: 3 hits reads soft(3,1,1.5)=0.9.
            if "GildedRot" in grid():
                goto_biome("GildedRot")
                gr_axis = (qstate("GildedRot") or [{}])[0]
                north_e = str(gr_axis.get("north", "🌹"))
                bridge(north_e, 60)
                ensure_hat("4"); press("1", 3)
                for _ in range(3):
                    press("G", 3); press("R", 5)         # spark north (open ground)
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
        for fid in ("woodlot_door", "woodlot_contact", "lumber_flows", "woodlot_wakes",
                    "timber_rhythm",
                    "spring_door", "spring_contact", "spring_connects", "spring_wakes",
                    "pond_depths", "pond_breathes",
                    "mill_wakes", "mill_master",
                    "lantern_door", "chain_ends", "lantern_teaching", "lantern_wakes",
                    "chain_flipped",
                    "island_lives", "village_identity", "five_doors",
                    "eagle_overhead", "serfs_ledger", "village_path_watched",
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
