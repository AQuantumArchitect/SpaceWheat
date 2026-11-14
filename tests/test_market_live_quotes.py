"""Board offers are priced live from ρ, and Lock holds a price without accepting.

Owner, 2026-11-13: market offers "should be running off of the live state",
"the contracts would be shifting around while you're looking at them, and then
that's why a lock button is useful. You might not want to accept it, but you
still might want to lock it." Picked terms: Lock is free, holds 3 offers at
once, for 60 s of play (the clock stops while paused); every live quote carries
the issuer's standing factor.

- tests/market_live_quote_probe.gd boots the real game (lookahead on), opens
  the board on Market with the player's keys (C, Y) and watches one offer:
  live asks move across heartbeats; F locks it and the ask holds while the live
  ask keeps moving; E re-deals and the lock stays; the paused world holds the
  lock clock; the lock survives a save (GameState v8 market_state); R accepts
  at the locked ask; a lock that runs out moves again.
- Source pins: one price function, the regime of the place (not the world
  switch) decides the prior and the collapse, and a delivery settles on its
  own biome.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/market_live_quote_probe.gd"


def _godot_env(tmp):
    env = dict(os.environ)
    for k in ("RIG_DISABLE_LOOKAHEAD", "SW_DISABLE_LOOKAHEAD"):
        env.pop(k, None)                    # the player default: lookahead on
    env["APPDATA"] = str(tmp)               # Windows: user:// lives under %APPDATA%
    env["XDG_DATA_HOME"] = str(tmp)         # Linux / macOS
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    env["RIG_UNLOCK_ALL"] = "1"             # the C board is a menu unlock in Act 0
    return env


@pytest.fixture(scope="module")
def phases(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("market_probe")
    result = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8",
                            timeout=400, env=_godot_env(tmp))
    out = result.stdout + result.stderr
    assert result.returncode == 0, f"{PROBE} failed:\n{out[-3000:]}"
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = [json.loads(l[len("MARKET_TRACE "):]) for l in result.stdout.splitlines()
            if l.startswith("MARKET_TRACE ")]
    return {r["phase"]: r for r in rows}


def test_an_offer_price_moves_while_the_board_is_open(phases):
    live = phases["live"]
    assert len(set(live["asks"])) >= 3, (
        "the board heartbeat must requote from ρ: one offer's ask over %d heartbeats "
        "was %s (marginals %s)" % (len(live["asks"]), live["asks"], live["ps"]))
    assert len(set(live["ps"])) >= 3, "the quote must read a marginal that moves"


def test_lock_holds_the_price_while_the_live_price_moves(phases):
    locked = phases["locked"]
    assert all(a == locked["ask"] for a in locked["asks"]), (
        "a locked offer's ask must not move: %s (locked at %d)" % (locked["asks"], locked["ask"]))
    assert len(set(locked["live_asks"])) >= 2, (
        "the live price must keep moving beside the lock, or the lock proved nothing: %s"
        % locked["live_asks"])
    secs = locked["seconds"]
    assert secs[0] <= 60.0 and all(b < a for a, b in zip(secs, secs[1:])), (
        "the lock clock must run down while time plays: %s" % secs)


def test_refresh_keeps_the_lock_and_pause_stops_its_clock(phases):
    refresh = phases["refresh"]
    assert refresh["present"] and refresh["locked"], "E re-deals unlocked rows only"
    assert refresh["ask"] == phases["locked"]["ask"]
    paused = phases["paused"]
    assert paused["was_paused"], "E pauses the sim (PlayerShell side-effect peek)"
    assert paused["seconds_after"] == paused["seconds_before"], (
        "a paused world holds every lock: %s" % paused)


def test_a_lock_survives_save_and_load(phases):
    save = phases["save"]
    assert save["version"] == 8
    assert save["disk_ok"], "the GameState with market_state must write and read back as a .tres"
    assert save["state_locks"] == 1, "GameStateSerializer must capture market_state"
    assert save["saved_locks"] == 1 and save["restored_locked"]
    assert save["restored_ask"] == phases["locked"]["ask"]
    assert save["restored_view_qty"] == phases["locked"]["ask"], "the locked row comes back whole"
    assert 0.0 < save["restored_seconds"] <= 60.0


def test_accept_takes_the_locked_ask_and_frees_the_slot(phases):
    acc = phases["accept"]
    assert acc["held"], "R on the locked row must accept it"
    assert acc["held_qty"] == acc["ask"] == phases["locked"]["ask"]
    assert acc["locks_after"] == 0, "an accepted offer is held, not locked"
    assert not acc["held_locked_field"], "the held quest carries no lock fields"


def test_a_lock_that_runs_out_moves_again(phases):
    exp = phases["expire"]
    if exp.get("skipped"):
        pytest.skip("the board dealt only one live offer")
    assert exp["unlocked"]
    assert len(set(exp["asks_after"])) >= 2, exp


# ---------------------------------------------------------------- source pins

def _body(src: str, header: str) -> str:
    return src.split(header, 1)[1].split("\nfunc ", 1)[0].split("\nstatic func ", 1)[0]


def test_one_price_function_prices_every_dealt_offer():
    lat = read_source("Core/Markets/MarketLattice.gd")
    q = _body(lat, "func quote(c)")
    assert "EnergyPricing.surprisal_energy(p_live, kT)" in q
    assert "_arbitrage_energy(p_live, prior, kT)" in q
    assert "PriceModel.standing_factor(c.faction, _farm)" in q
    for fn in ("func propose_offers(", "func propose_faction_offers(", "func propose_pair_offers(",
               "func propose_neighborhood_offers(", "func propose_neighborhood_offers_scoped("):
        assert "_apply_quote(c)" in _body(lat, fn), fn
    board = read_source("UI/Overlays/QuestBoard.gd")
    assert "_requote_pool()" in _body(board, "func _process(delta: float)")


def test_openness_is_a_place_in_the_market():
    lat = read_source("Core/Markets/MarketLattice.gd")
    exercise = _body(lat, "func exercise(contract_id: int)")
    assert "dissipative_enabled" not in exercise
    assert "_qc_open(qc)" in exercise
    for fn in ("func propose_neighborhood_offers(", "func propose_neighborhood_offers_scoped("):
        body = _body(lat, fn)
        assert "_qc_open(qc)" in body and "_static_marginals_from_spec(" in body, fn
        assert "dissipative_enabled" not in body, fn


def test_a_delivery_settles_on_its_own_biome():
    qm = read_source("Core/Quests/QuestManager.gd")
    complete = _body(qm, "func complete_quest(")
    assert "synthesize_and_exercise(required_emoji, faction_name, settle_biome)" in complete
    lat = read_source("Core/Markets/MarketLattice.gd")
    syn = _body(lat, "func synthesize_and_exercise(")
    assert syn.index("_resolve_biome_by_name(biome_name)") < syn.index("_find_biome_for_emoji(emoji)")
