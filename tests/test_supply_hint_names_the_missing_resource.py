"""Out-of-resource hints walk the MISSING resource, not always 🧺.

Playtest 2026-10-29: out of 🦅 (Captain chart), the banner and toasts sent
the player to the Village for baskets. 🦅 has its own Village trade
(10🌾 → 7🦅) that costs no gather at all; baskets only matter when the
missing resource has to be gathered and the gather fee can't be paid.
Source-contract pins on UI/Core/UIProgression.gd.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UIP = ROOT / "UI" / "Core" / "UIProgression.gd"


def _fn(name: str) -> str:
    src = UIP.read_text(encoding="utf-8")
    return src.split("static func %s(" % name)[1].split("\nstatic func ")[0]


def test_banner_chooser_prefers_the_missing_resource_trade():
    body = _fn("_supply_need_now")
    assert '_need_or_basket("🦅")' in body
    assert '_need_or_basket("🌱")' in body
    assert 'return "🧺" if _basket_short() else ""' not in body, (
        "the chooser must not jump straight to baskets for a short 🦅/🌱"
    )


def test_need_or_basket_tries_the_trade_first():
    body = _fn("_need_or_basket")
    assert body.index("_trade_walk_ok(emoji)") < body.index("_basket_short()")


def test_trade_walk_ok_requires_a_payable_trade_for_that_emoji():
    body = _fn("_trade_walk_ok")
    assert "_supply_step(emoji)" in body
    assert 'str(t.get("emoji", "")) == emoji' in body
    assert "_trade_affordable(t)" in body


def test_walked_resource_is_priced_at_its_real_cost():
    body = _fn("_supply_cost")
    assert '"🦅"' in body and "_chart_eagles()" in body
    assert '"🌱"' in body


def test_eagle_and_sprout_walks_check_the_trade_before_baskets():
    for name in ("eagle_short_refusal", "_eagle_gather_line", "_eagle_gather_target"):
        body = _fn(name)
        assert body.index('_trade_walk_ok("🦅")') < body.index("_basket_short()" if "_basket_short()" in body else "gather_price()"), name
    body = _fn("_sprout_gather_line")
    assert body.index('_trade_walk_ok("🌱")') < body.index("_basket_short()")
