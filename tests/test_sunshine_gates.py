"""Sunshine honesty gates. No Godot. Missing flake is dark, not a fail."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HIVE = ROOT / "🍄" / "🧪" / "hive"
sys.path.insert(0, str(HIVE))
import sunshine  # noqa: E402


def test_missing_flake_is_dark_not_fail():
    assert sunshine.load_flake(ROOT / "no-such-sunshine.json") is None
    assert sunshine.gates(None) == []
    assert sunshine.sun_ready(None) is False
    assert sunshine.prefer_web(None) is False


def test_ready_counts_are_sun():
    flake = {
        "sun": "ready",
        "earning_usd": None,
        "titles": [
            {
                "named": "spacewheat",
                "page": "ready",
                "views": 18,
                "downloads": 2,
                "purchases": 0,
            }
        ],
    }
    assert sunshine.sun_ready(flake) is True
    assert sunshine.prefer_web(flake) is True
    assert sunshine.gates(flake) == []


def test_refuse_sun_claim_without_counts():
    flake = {"sun": "ready", "earning_usd": None, "titles": []}
    assert sunshine.gates(flake) == ["sun-claimed-dark"]


def test_refuse_invented_money_and_url():
    flake = {
        "sun": "dark",
        "earning_usd": 12,
        "titles": [{"named": "spacewheat", "url": "https://example.invalid/x"}],
    }
    fails = sunshine.gates(flake)
    assert "earning_usd" in fails
    assert "url" in fails


def test_wall_needs_tried_saw_path():
    ok = {
        "chapter": "act0_fresh",
        "report": "tried Ace R; saw splash; expected the ritual to name itself",
    }
    bad = {"chapter": "act0_fresh", "report": ""}
    assert sunshine.gates({"sun": "dark", "earning_usd": None}, walls=[ok]) == []
    assert "wall-no-path" in sunshine.gates(
        {"sun": "dark", "earning_usd": None}, walls=[bad]
    )


def test_roundtrip_s3_schema():
    raw = json.dumps(
        {
            "schema": "semantica3-itch-sunshine/0.1",
            "id": "itch.sunshine",
            "sun": "ready",
            "earning_usd": None,
            "customer_use": False,
            "titles": [
                {
                    "named": "spacewheat",
                    "slug": "spacewheat",
                    "page": "ready",
                    "views": 18,
                    "downloads": 0,
                    "purchases": 0,
                }
            ],
        }
    )
    flake = json.loads(raw)
    assert sunshine.sun_ready(flake) is True
    assert sunshine.prefer_web(flake) is False
    assert sunshine.gates(flake) == []
