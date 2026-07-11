#!/usr/bin/env python3
"""Mouse parity probe: QuestBoard + EscapeMenu fully drivable by pointer.

Root cause history (playtest 2, 2026-07-11): the full-width selection-row
strips used MOUSE_FILTER_PASS, which still CLAIMS GUI picks — three 1260px
invisible bands deadened every overlay control beneath them ("i can't click
on anything in the market with my mouse", "the pause menu isn't accepting
mouse commands"). Fixed: rows IGNORE (chips are STOP children), and the
tool/biome chip rows go pointer-dead while a real menu is open (the pointer
twin of the keyboard bleed-through guard). The QuestBoard is also live on
open now (pool refresh in _on_activated) with named, clickable rows/tabs.

Checks (all by real synthetic clicks, asserting STATE not just visibility):
  - market opens LIVE (offer pool populated without pressing E)
  - tab click switches frames (T manifold, Y market)
  - row click SELECTS that row (board_state.selected_index moves)
  - verb chip E refreshes without error
  - EscapeMenu: Q chip click arms the quit-confirm (confirm_state changes)
"""
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "\U0001F39B️"))
from rig_client import RigClient  # noqa: E402

_t = [0]


def turn():
    _t[0] += 1
    return _t[0]


def main():
    c = RigClient()
    c.clear_rig_files(preserve_live_sentinel=False)
    proc = c.start_listener(scenario_id="demos_normal", display_mode="headed")
    failures = []
    try:
        print("ready:", c.wait_for_ready(proc, timeout_s=200))

        def t(action, **kw):
            return c.run_turn(turn(), action, timeout_s=30, **kw)

        def check(cond, label):
            print(("PASS " if cond else "FAIL ") + label)
            if not cond:
                failures.append(label)
            return cond

        def click(name, settle=10):
            r = t("control_rect", name=name)
            if not (r.get("center") and r.get("visible")):
                return False
            t("tap", screen=r["center"], settle_frames=settle)
            return True

        # --- QuestBoard ---
        t("press_key", key="c", settle_frames=16)
        bs = t("board_state")
        check(bs.get("frame_id") == "market" and int(bs.get("offer_pool_size", 0)) > 0,
              "market is LIVE on open (pool=%s, note=%r)" % (
                  bs.get("offer_pool_size"), bs.get("market_status_note")))

        check(click("BoardTab_T"), "BoardTab_T clickable")
        check(t("board_state").get("frame_id") == "manifold", "tab click -> Manifold")
        check(click("BoardTab_Y"), "BoardTab_Y clickable")
        check(t("board_state").get("frame_id") == "market", "tab click -> Market")

        if int(t("board_state").get("offer_pool_size", 0)) > 1:
            check(click("BoardRow_1"), "BoardRow_1 clickable")
            check(int(t("board_state").get("selected_index", -1)) == 1,
                  "row click selects row 1")
            check(click("BoardRow_0"), "BoardRow_0 clickable")
            check(int(t("board_state").get("selected_index", -1)) == 0,
                  "row click selects row 0")

        check(click("BoardVerb_E"), "BoardVerb_E clickable")
        check(int(t("board_state").get("offer_pool_size", -1)) >= 0,
              "E chip refresh leaves a coherent pool")
        t("press_key", key="c", settle_frames=10)

        # --- EscapeMenu: the REAL assertion is the confirm arming, not menu
        # visibility (the old check passed whether or not the click landed).
        t("press_key", key="z", settle_frames=14)
        pre = t("control_rect", name="MenuConfirmGroup")
        check(not pre.get("visible"), "confirm group hidden before Q click")
        check(click("MenuVerb_Q", settle=12), "MenuVerb_Q clickable")
        post = t("control_rect", name="MenuConfirmGroup")
        check(bool(post.get("visible")), "Q chip click armed the quit confirm (group visible)")
        t("press_key", key="e", settle_frames=8)   # cancel
        t("press_key", key="z", settle_frames=10)  # close

    finally:
        c.terminate_listener(proc)

    print("\n%s — %d failure(s)" % ("GREEN" if not failures else "RED", len(failures)))
    for f in failures:
        print("  FAIL:", f)
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
