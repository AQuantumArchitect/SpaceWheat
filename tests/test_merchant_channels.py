"""Merchant channels are contracts on the C board (one contract system, PR B).

Owner, 2026-11-13: market offers and Merchant contracts are "the same thing".
A channel is now a MarketContract that settles by flow: the biome's native
faction issues it (its standing moves the price), the stake comes from the
market's one price law (MarketLattice.channel_quote → quote()), held channels
show on Commitments with their flow, open ground lists channel offers on the
Market tab (live, lockable), Merchant E quotes what the board quotes, and the
records ride the save (GameState v8 market_state.channels).

tests/merchant_channel_probe.gd boots the real game (lookahead on) with the
Village opened (regime_override = "open") and walks a channel through the
board and the hat; see its header for the phases.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import ROOT, read_source

PROBE = "tests/merchant_channel_probe.gd"


def _godot_env(tmp):
    env = dict(os.environ)
    for k in ("RIG_DISABLE_LOOKAHEAD", "SW_DISABLE_LOOKAHEAD"):
        env.pop(k, None)
    env["APPDATA"] = str(tmp)
    env["XDG_DATA_HOME"] = str(tmp)
    env["SW_PROBE_USER_DIR_PREFIX"] = str(tmp)
    env["RIG_UNLOCK_ALL"] = "1"
    return env


@pytest.fixture(scope="module")
def phases(tmp_path_factory):
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    tmp = tmp_path_factory.mktemp("channel_probe")
    result = subprocess.run(["godot", "--headless", "--script", PROBE], cwd=ROOT,
                            capture_output=True, text=True, encoding="utf-8",
                            timeout=400, env=_godot_env(tmp))
    out = result.stdout + result.stderr
    assert result.returncode == 0, f"{PROBE} failed:\n{out[-3000:]}"
    assert "SCRIPT ERROR" not in out and "Parse Error" not in out, out[-3000:]
    rows = [json.loads(l[len("CHANNEL_TRACE "):]) for l in result.stdout.splitlines()
            if l.startswith("CHANNEL_TRACE ")]
    return {r["phase"]: r for r in rows}


def test_open_ground_lists_channel_offers_issued_by_the_native_faction(phases):
    o = phases["offers"]
    assert o["count"] >= 2 and set(o["directions"]) == {"import", "export"}, o
    assert o["native"] != "" and o["issuer"] == o["native"], (
        "the biome's native faction issues its channels: %s" % o)


def test_a_locked_channel_offer_signs_at_its_locked_stake(phases):
    lock, sign = phases["lock"], phases["sign"]
    assert lock["locked"] and all(s == lock["stake"] for s in lock["stakes"]), lock
    assert lock["hat_quote_locked"] and lock["hat_quote_stake"] == lock["stake"], (
        "the Merchant hat's quote honours a lock taken on the board: %s" % lock)
    assert sign["signed"] and sign["drain_flag"], "R must sign through action_drain"
    assert sign["faction"] == phases["offers"]["native"]
    assert sign["direction"] == "export" and sign["kind"] == "thermal"
    assert sign["signed_stake"] == sign["locked_stake"] == sign["wallet_stake_paid"], sign
    assert sign["fee_paid"] == 4, "export's 🧺 fee is unchanged"
    assert sign["locks_after"] == 0 and sign["offer_left_board"]


def test_a_held_channel_shows_its_flow_on_commitments(phases):
    f = phases["flow"]
    assert f["on_commitments"] and all(s == "flowing" for s in f["statuses"]), f
    c = f["credited"]
    assert c[-1] > c[0] >= 0 and all(b >= a for a, b in zip(c, c[1:])), (
        "an export channel credits the wallet as it drains: %s" % c)
    assert f["wallet_north_gain"] > 0
    assert f["takes_no_hand"], "a channel is infrastructure on a register, not a hand"


def test_the_hat_signs_the_same_contract(phases):
    h = phases["hat"]
    assert h["success"] and h["signed"] and h["direction"] == "import", h
    assert h["faction"] == phases["offers"]["native"]
    assert h["channels"] == 2 and h["on_commitments"]


def test_merchant_e_quotes_what_the_board_quotes(phases):
    b = phases["order_book"]
    assert b["ok"] and b["register"] == b["expected_register"], b
    assert b["book_export_stake"] == b["board_export_stake"] >= 1, b
    assert b["book_faction"] == phases["offers"]["native"]


def test_channels_survive_save_and_old_saves_get_records(phases):
    s = phases["save"]
    assert s["disk_ok"] and s["saved"] == 2 and s["restored"] == 2, s
    assert s["restored_faction"] == phases["offers"]["native"]
    assert s["restored_direction"] == "export"
    assert s["restored_stake"] == phases["sign"]["signed_stake"]
    old = phases["old_save"]
    assert old["added"] == 2 and old["channels"] == 2, old
    assert old["faction"] == phases["offers"]["native"] and old["signed_at"] == 0
    assert old["direction"] == "export"


def test_closing_a_channel_is_free_and_standing_neutral(phases):
    c = phases["close"]
    assert c["closed"] and c["flag_cleared"] and c["left_commitments"], c
    assert c["standing_same"], "closing a channel is not a failed contract"
    assert c["fee_free"], "closing costs nothing"
    assert c["channels_left"] == 1


def test_sealed_ground_has_no_channels(phases):
    s = phases["sealed"]
    assert s["offers"] == 0, "openness is a place: no channel offers on sealed ground"
    assert s["refused"] and s["sealed_count"] == 1


# ---------------------------------------------------------------- source pins

def _body(src: str, header: str) -> str:
    return src.split(header, 1)[1].split("\nfunc ", 1)[0].split("\nstatic func ", 1)[0]


def test_channel_signing_prices_through_the_market():
    h = read_source("Core/Instrumentation/Handlers/LindbladHandler.gd")
    stake = _body(h, "static func _channel_stake(")
    assert "lattice.channel_quote(biome, qubit_idx, direction, kind)" in stake
    for fn in ("static func enable_persistent_drive(", "static func enable_persistent_decay("):
        body = _body(h, fn)
        assert "_channel_stake(farm, biome, qubit_idx" in body, fn
        assert "lattice.record_channel(" in body, fn
    assert "lattice.close_channel(" in _body(h, "static func settle_channels(")
    lat = read_source("Core/Markets/MarketLattice.gd")
    cq = _body(lat, "func channel_quote(")
    assert "quote(probe)" in cq and "is_locked()" in cq
    assert "channel_issuer(biome)" in _body(lat, "func _make_channel_contract(")
    qii = read_source("UI/Core/QuantumInstrumentInput.gd")
    assert "lattice.channel_quote(biome, reg" in _body(qii, "func _execute_read_price(")


def test_the_word_standing_means_reputation():
    """Channel, trade, offer: the three kinds of contract. 'Standing contract'
    and 'standing trade' are gone from the code and the live docs, because
    standing is reputation."""
    for rel in ("Core/GameState/ToolConfig.gd", "Core/Instrumentation/Handlers/LindbladHandler.gd",
                "Core/Instrumentation/QuantumInstrument.gd", "Core/Quests/QuestPipeline.gd",
                "Core/Quests/QuestVoice.gd", "UI/Overlays/QuestBoard.gd",
                "UI/Overlays/ControlsOverlay.gd", "docs/HOW_TO_PLAY.md", "docs/GAME_CODEX.md",
                "docs/CAMPAIGN.md"):
        text = read_source(rel).lower()
        assert "standing contract" not in text, rel
        assert "standing trade" not in text, rel
