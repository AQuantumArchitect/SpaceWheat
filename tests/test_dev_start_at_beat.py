"""Escape → Dev → "start at beat…": the dev jump lists campaigns → acts →
beats from the compiled spec and starts a fresh demos_normal run at the moment
the picked beat opens (Core/Campaign/CampaignFixture.gd).

Driven by keys only, the way a developer would: Z menu, O (Dev tab), pick the
action, R into the picker, R through campaign/act, R on the beat. Dev-only:
the Dev tab keeps its gate (UIProgression.ESCAPE_TAB_LOCKED_UNTIL_ACT0_DONE);
this lane runs with the rig's default RIG_UNLOCK_ALL=1, the dev setting.

Skip with SW_SKIP_LONG=1 (also skipped without godot on PATH).
"""
import json
import os
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
LONG = pytest.mark.skipif(os.environ.get("SW_SKIP_LONG") == "1",
                          reason="SW_SKIP_LONG=1 — headless dev-jump test skipped")
KEYS = "ghjkl;"


def test_dev_tab_lists_the_beat_picker_and_keeps_its_gate():
    src = (ROOT / "UI/Overlays/EscapeMenu.gd").read_text(encoding="utf-8")
    assert '"id": "start_at_beat"' in src
    actions = src.split("const DEV_ACTIONS := [")[1].split("]\n")[0]
    assert actions.strip().rstrip(",").splitlines()[-1].strip().startswith('{"id": "full_reset"'), (
        "full_reset must stay the LAST dev action (never the default-armed row)")
    assert "CampaignFixture.jump(" in src
    prog = (ROOT / "UI/Core/UIProgression.gd").read_text(encoding="utf-8")
    assert '"dev": true' in prog, "the Dev tab (and so the beat jump) stays locked until Act 0 is done"


def _row_of(lines, label):
    cur = None
    for s in lines:
        s = s.strip()
        if len(s) == 3 and s[0] == "[" and s[2] == "]":
            cur = s[1].lower()
            continue
        if cur and label in s:
            return cur
    return None


@LONG
def test_dev_jump_starts_a_fresh_run_at_the_picked_beat(rig_boot):
    beat, campaign_title, act = "village_stirs", None, 1
    camp = json.loads((ROOT / "Core/Quests/data/campaign_runtime.json").read_text(encoding="utf-8"))
    campaign_title = camp["campaigns"][0]["title"]
    flags = json.loads((ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))
    beat_name = next(f["display_name"] for f in flags if f["id"] == beat)

    rig, _proc = rig_boot(prefix="sw_dev_jump_", scenario_id="demos_normal",
                          display_mode="headless", listener_stdout="null",
                          rig_log_profile="quiet", sentinel_timeout_s=240.0)
    n = [0]

    def t(action, **kw):
        n[0] += 1
        return rig.run_turn(n[0], action, timeout_s=60, **kw)

    def press(k, settle=8):
        return t("press_key", key=k, settle_frames=settle)

    def lines():
        return [str(x.get("text", "")) for x in t("overlay_text").get("lines", [])]

    press("z", 10)  # Z — the system (escape) menu
    press("o", 10)  # Dev tab
    row = _row_of(lines(), "start at beat")
    assert row, "Dev tab has no 'start at beat…' row:\n%s" % "\n".join(lines()[:60])
    press(row)
    press("r", 10)  # open the picker
    for label in (campaign_title, "Act %d" % act, beat_name):
        row = _row_of(lines(), label)
        assert row, "picker has no row %r:\n%s" % (label, "\n".join(lines()[:60]))
        press(row)
        press("r", 12)

    deadline = time.time() + 120
    fired, offers = {}, []
    while time.time() < deadline:
        time.sleep(1.0)
        fired = t("story_flags").get("flags_fired", {}) or {}
        if beat in fired:
            offers = t("story_offers").get("story_offers", []) or []
            if any(o.get("source_flag") == beat for o in offers):
                break
    assert beat in fired, "dev jump never opened %s (fired: %s)" % (beat, sorted(fired))
    assert any(o.get("source_flag") == beat for o in offers), offers
    assert "arc_handover" in fired and "first_harvest" in fired
