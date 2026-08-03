#!/usr/bin/env python3
"""
Save/verify/campaign probe — three tasks in one headed+headless run:

1. Boot headed → screenshot X SELF tab (verify TheDemos biome renders, not 'not loaded')
2. Test save/load mechanics: valid slots 0-2, invalid -1, nonexistent load, roundtrip
3. Drive campaign via Berry-phase incorporation (StarterForest → Village → extras)
   until flags stabilise. Discover biomes if possible to reach further flags.
4. Save slot 1 (campaign) to REAL game dir — actual shipped save, not rig private lane.
5. Boot fresh headless → save slot 0 (fresh demos start) to REAL game dir LAST,
   so save_slot_0 gets the highest timestamp → becomes the 'F continue' option.
"""
import os, sys, time, json
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001f39b️"))
from rig_client import RigClient  # noqa: E402
from turn_driver import TurnDriver  # noqa: E402

REAL_SAVE_DIR = Path.home() / ".local/share/godot/app_userdata/SpaceWheat - Quantum Farm/saves"
SHOTS = HERE / "playthrough_shots"
SHOTS.mkdir(exist_ok=True)
PLOT_KEYS = ["G", "H", "J", "K", "L", "SEMICOLON"]
BIOME_KEYS = ["T", "Y", "U", "I", "O", "P"]

# Historical per-script driver timeouts — deliberately NOT unified (SLOP_PATROL knot #8).
GO_TIMEOUT_S = 90
PRESS_TIMEOUT_S = 25
PRESS_SETTLE_FRAMES = 4

_driver = TurnDriver(start=0)
t = _driver.t
press = _driver.make_client_press(settle_frames=PRESS_SETTLE_FRAMES, timeout_s=PRESS_TIMEOUT_S)
go = _driver.make_client_go(timeout_s=GO_TIMEOUT_S)


def shot(c, name):
    safe = "".join(ch if ch.isalnum() else "_" for ch in name)[:40]
    path = f"user://rig/sv_{_driver.turn:03d}_{safe}.png"
    r = go(c, "screenshot", path=path)
    sc = r.get("screenshot") or {}
    abs_path = sc.get("abs", "")
    if abs_path:
        try:
            dest = SHOTS / Path(abs_path).name
            dest.write_bytes(Path(abs_path).read_bytes())
            return str(dest)
        except Exception as e:
            return abs_path
    return None


def get_flags(c):
    r = go(c, "story_flags")
    return set((r.get("flags_fired") or {}).keys())


def get_sig(c):
    r = go(c, "known_icons")
    return len(r.get("icons") or [])


def incorporate_round(c, biome_key="T", phrames=1500):
    """Druid Hadamard → Icon track → time_skip → Icon incorporate."""
    press(c, biome_key, 5)  # navigate to biome
    time.sleep(0.3)
    # Druid E (Hadamard) on all plots — excites qubits off ground eigenstate
    press(c, "0", 3)        # Druid hat
    for pk in PLOT_KEYS:
        press(c, pk, 2)
        press(c, "E", 3)
    # Icon F — start Berry-phase tracking (do NOT re-press '5' between track + incorporate)
    press(c, "5", 3)        # Icon hat
    for pk in PLOT_KEYS:
        press(c, pk, 2)
        press(c, "F", 3)
    # Let physics ripen the Berry phase (~2π solid-angle loop)
    go(c, "time_skip", phrames=phrames)
    # Icon R — incorporate into signature (if ripe; no-op if not, no cost)
    for pk in PLOT_KEYS:
        press(c, pk, 2)
        press(c, "R", 4)


def save_to_real_dir(c, filename):
    """Save game directly to the real Godot user:// directory."""
    REAL_SAVE_DIR.mkdir(parents=True, exist_ok=True)
    real_path = str(REAL_SAVE_DIR / filename)
    r = go(c, "save_game_path", path=real_path)
    saved = r.get("saved", False)
    print(f"  save_to_real '{filename}': saved={saved}")
    return saved


def try_add_resource(c, emoji, amount):
    """Attempt to add a resource via the rig instrument (may fail if _instrument null)."""
    r = go(c, "add_resource", emoji=emoji, amount=amount)
    return r.get("added", False)


# ─────────────────────────────────────────────────────────────────────────────
# SESSION 1: headed — screenshot SELF, test save/load, drive campaign
# ─────────────────────────────────────────────────────────────────────────────
def run_campaign():
    _driver.reset(0)
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(
        scenario_id="demos_normal",
        display_mode="headed",
        extra_env={"RIG_DISABLE_LOOKAHEAD": "0", "RIG_RENDERING_DRIVER": "opengl3"},
    )

    report = {"self_screenshot": None, "save_load_tests": {}, "flags": [], "sig_size": 0,
              "campaign_save": False}

    try:
        c.wait_for_ready(proc, timeout_s=180)
        time.sleep(1.5)

        # Dismiss welcome splash (any key)
        press(c, "F", 5)
        time.sleep(2.0)  # let farm fully settle after welcome dismiss

        # Navigate to StarterForest to force farm interaction (ensures active_farm is set)
        press(c, "T", 8)
        time.sleep(1.0)

        # ── 1. SELF tab screenshot ────────────────────────────────────────────
        print("\n── SELF tab screenshot ──")
        press(c, "X", 5)        # open X surface (SELF / ARC tabs)
        time.sleep(1.0)         # let content render
        p = shot(c, "SELF_tab_verify")
        report["self_screenshot"] = p
        print(f"  screenshot → {p}")
        press(c, "ESCAPE", 5)   # close X

        # ── 2. Save/load validation (write-only tests only) ──────────────────────
        # CRITICAL: do NOT call load_game in headed mode — even for an invalid slot,
        # SaveLoadCoordinator.load_and_apply routes through restart_into() which triggers
        # a full scene restart even for nonexistent slots, killing _farm/_instrument for
        # the rest of the session. Load testing is done in Session 2 (headless) where the
        # headless code path returns False gracefully for missing slots without restarting.
        print("\n── Save/load validation (save-side) ──")
        tests = report["save_load_tests"]

        for slot in [0, 1, 2]:
            r = go(c, "save_game", slot=slot)
            ok = r.get("saved", False)
            tests[f"save_slot_{slot}"] = ok
            print(f"  save slot={slot}: saved={ok}  (expect True)")

        for bad in [-1, 5]:
            r = go(c, "save_game", slot=bad)
            ok = r.get("saved", False)
            tests[f"save_slot_{bad}"] = ok
            print(f"  save slot={bad}: saved={ok}  (expect False)")
        # load_game tests are in Session 2 (headless) to avoid restart side-effects

        # ── 3. Campaign ───────────────────────────────────────────────────────
        print("\n── Campaign: Berry-phase incorporation rounds ──")

        # Give 🦅 for biome discovery (21 per discover, want up to 10 discovers)
        eagle_added = try_add_resource(c, "🦅", 300)
        print(f"  add 300🦅 for biome discovery: {'ok' if eagle_added else 'failed (will skip discover)'}")

        # StarterForest: 2 rounds (fires first_breath on round 1, builds forest_* on round 2)
        for rnd in range(1, 3):
            print(f"  StarterForest round {rnd}...")
            incorporate_round(c, biome_key="T", phrames=1500)
        f = get_flags(c); s = get_sig(c)
        print(f"  after SF rounds: flags={sorted(f)} sig={s}")

        # Village: 4 rounds (fires village_stirs → mill_wakes → mill_master)
        for rnd in range(1, 5):
            print(f"  Village round {rnd}...")
            incorporate_round(c, biome_key="Y", phrames=1800)
        f = get_flags(c); s = get_sig(c)
        print(f"  after Village rounds: flags={sorted(f)} sig={s}")

        # Discover more biomes (up to 10) so I/O/P keys map to new biomes
        print("\n  Discovering biomes...")
        new_biomes = []
        for i in range(10):
            r = go(c, "discover_biome")
            db = r.get("discover_biome") or {}
            bname = db.get("biome_name") or db.get("name") or db.get("biome") or "?"
            ok = db.get("success") or db.get("ok") or (db.get("error") is None and bname != "?")
            print(f"    discover {i+1}: {bname} ok={ok} raw={json.dumps(db, ensure_ascii=False)[:80]}")
            if ok and bname != "?":
                new_biomes.append(bname)
            if db.get("error") and "cost" in str(db.get("error", "")):
                print("    (cost blocked — stopping discovers)")
                break

        # Incorporate from newly discovered biomes on I, O, P keys
        # TheDemos (U) only has 1 icon (already known) — skip to save time
        for bkey in ["I", "O", "P"]:
            print(f"  Incorporating from biome key {bkey}...")
            incorporate_round(c, biome_key=bkey, phrames=1200)
        f = get_flags(c); s = get_sig(c)
        print(f"  after extra biome rounds: flags={sorted(f)} sig={s}")

        # Try to navigate to BloodLedger if it was discovered (would be at key beyond P)
        # Best effort: check story_flags; if ledger_opens isn't fired, report honestly
        final_flags = get_flags(c)
        final_sig = get_sig(c)
        report["flags"] = sorted(final_flags)
        report["sig_size"] = final_sig
        print(f"\n  FINAL STATE: flags={sorted(final_flags)} sig={final_sig}")

        # Save campaign state to real dir (slot 1)
        ok = save_to_real_dir(c, "save_slot_1.tres")
        report["campaign_save"] = ok

    finally:
        try:
            go(c, "stop")
        except Exception:
            pass
        c.terminate_listener(proc)

    return report


# ─────────────────────────────────────────────────────────────────────────────
# SESSION 2: headless — boot fresh demos_normal, save as slot 0 (last-modified),
#            then run load_game tests (safe in headless: no restart_into path)
# ─────────────────────────────────────────────────────────────────────────────
def save_fresh_and_test_load():
    _driver.reset(9000)
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(
        scenario_id="demos_normal",
        display_mode="headless",
        extra_env={"RIG_DISABLE_LOOKAHEAD": "0"},
    )
    fresh_ok = False
    load_tests = {}
    try:
        c.wait_for_ready(proc, timeout_s=180)
        time.sleep(0.5)
        # Save fresh state FIRST (gives it the highest timestamp → becomes F-continue)
        fresh_ok = save_to_real_dir(c, "save_slot_0.tres")

        # Load tests — safe in headless because no AppRoot in group → headless code path:
        # load_game_state(slot) returns null for missing slots → graceful False.
        # (Headed mode triggers restart_into() even for missing slots — destructive.)
        r = go(c, "load_game", slot=0)
        ok = r.get("loaded", False)
        load_tests["load_slot_0"] = ok
        print(f"  load slot=0: loaded={ok}  (expect True — fresh save exists)")

        r = go(c, "load_game", slot=99)
        ok = r.get("loaded", False)
        err = r.get("error", "")
        load_tests["load_slot_99"] = {"loaded": ok, "error": err}
        print(f"  load slot=99: loaded={ok} error={err}  (expect False — nonexistent)")
    finally:
        try:
            go(c, "stop")
        except Exception:
            pass
        c.terminate_listener(proc)
    return fresh_ok, load_tests


# ─────────────────────────────────────────────────────────────────────────────
def main():
    print("=== SpaceWheat save/verify/campaign probe ===\n")

    report = run_campaign()

    print("\n=== SESSION 2: fresh start save + load_game tests (headless) ===")
    fresh_ok, load_tests = save_fresh_and_test_load()

    print("\n=== SUMMARY ===")
    all_save_load = {**report.get("save_load_tests", {}), **load_tests}
    print(f"  SELF screenshot: {report.get('self_screenshot')}")
    print(f"  Save tests (headed): {report.get('save_load_tests')}")
    print(f"  Load tests (headless): {load_tests}")
    print(f"  Campaign flags fired ({len(report.get('flags', []))}): {report.get('flags')}")
    print(f"  Signature size: {report.get('sig_size')}")
    print(f"  Campaign save (slot 1) ok: {report.get('campaign_save')}")
    print(f"  Fresh save (slot 0) ok: {fresh_ok}")
    print()
    print(f"  Real save dir: {REAL_SAVE_DIR}")
    print("  slot 0 (fresh/F-continue): newest timestamp → F loads this on boot")
    print("  slot 1 (campaign progress): earlier timestamp")


if __name__ == "__main__":
    main()
