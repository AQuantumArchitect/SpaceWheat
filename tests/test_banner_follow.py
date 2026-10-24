"""The banner follower (🍄/🧪/banner_follow.py): a player who presses only the
keys the objective banner names. See docs/design/GUIDANCE_FROM_THE_SPEC.md.

The fast tests pin how a banner line is read. The long test is a ratchet:
the number of main-campaign beats where following the banner moves the story
may only go up. Baseline 2026-10-19: 2 of 40 (arc_handover, mill_master).
With the Guide resolver: 38 of 40; the floor leaves 2 beats of slack for
measurement luck. The two that stall (first_harvest, loom_opens) are Act 0
fixtures with nothing planted to reap; a fresh game fires both by banner.
"""
import os
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "🍄" / "🧪"))
import banner_follow as BF  # noqa: E402

MOVED_FLOOR = 36


def test_a_banner_line_reads_as_its_keys_in_order():
    assert BF.parse_keys("📜 The Wheel Is Yours waits — 📖 [X], Arc [I], Accept [R]") == [
        ("x", False), ("i", False), ("r", False)]
    assert BF.parse_keys("▸ [7] Captain, then [R] Chart FreshwaterSpring") == [("7", False), ("r", False)]
    assert BF.parse_keys("▸ SHIFT [F] to multi explore") == [("f", True)]
    assert BF.parse_keys("▸ ESC closes") == [("escape", False)]
    assert BF.parse_keys("Strike a sleeping plot.") == []


@pytest.mark.skipif(os.environ.get("SW_SKIP_LONG") == "1", reason="SW_SKIP_LONG=1 — banner sweep skipped")
@pytest.mark.timeout(3600)
def test_following_the_banner_moves_at_least_the_floor():
    import shutil
    if shutil.which("godot") is None:
        pytest.skip("godot not available on PATH")
    sys.path.insert(0, str(ROOT / "tools" / "campaign"))
    import spec as S
    beats = [b["id"] for c, _a, _ch, b in S.iter_beats(S.load()) if c["id"] == "demos"]
    results = [BF.run_one(b, BF.PRESS_CAP) for b in beats]
    moved = [r["beat"] for r in results if r.get("outcome") == "moved"]
    print("BANNER FOLLOW moved %d/%d: %s" % (len(moved), len(beats), moved))
    assert len(moved) >= MOVED_FLOOR, "guidance regressed: %s" % moved
