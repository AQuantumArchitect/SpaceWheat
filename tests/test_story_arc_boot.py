import time
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _wait_for_story_flag(rig, flag_id: str, *, timeout_s: float = 12.0):
    deadline = time.time() + timeout_s
    turn = 1
    last_row = None
    while time.time() < deadline:
        last_row = rig.run_turn(turn, "story_flags", timeout_s=30.0)
        if last_row.get("ok", False):
            fired = last_row.get("flags_fired", {})
            if isinstance(fired, dict) and flag_id in fired:
                return last_row
        turn += 1
        time.sleep(0.25)
    raise AssertionError(f"timed out waiting for story flag {flag_id}: {last_row}")


def test_story_flags_fire_from_action_not_boot(rig_boot) -> None:
    # Principle: story flags fire as a RESULT of human action, never at a fresh boot.
    # Run on the SHIPPED DEFAULT scenario (demos_normal). first_breath now gates on
    # signature_GROWTH past the seeded boot baseline (signature_growth_gte 0.5 width 0.4),
    # NOT an absolute size — so it reads 0 at boot for ANY scenario (1 seeded icon or 5) and
    # only crosses once the player incorporates one MORE this run. This is scenario-proof:
    # the old absolute signature_size_gte 1.5 fired at boot for any start with ≥2 icons
    # (e.g. new_game_easy, or a Demos start with a 2-icon signature). The forest beats below
    # then fire from a real action (consuming berries).
    rig, _proc = rig_boot(
        prefix="sw_pytest_story_boot_",
        load_slot=None,
        scenario_id="demos_normal",
        allow_resource_injection=True,
        listener_stdout="null",
        rig_log_profile="quiet",
        extra_env={"RIG_QUEUE_POLL_MS": "80"},
    )

    # No action taken yet → first_breath must NOT have fired at boot.
    boot_row = rig.run_turn(1, "story_flags", timeout_s=30.0)
    assert boot_row.get("ok", False), boot_row
    assert "first_breath" not in boot_row.get("flags_fired", {}), boot_row

    # Positive half: the flag fires FROM the action. forest_evolving gates on
    # biome_evolving(StarterForest) + berry_consumed_count_gte 1, which under soft
    # geometry needs ~2.3 berries to cross the 0.85 fire threshold — so consume a few.
    # (The full forest→village→empire chain is covered end-to-end by act3_5_drive.py.)
    berry_row = rig.run_turn(
        99,
        "consume_berry",
        timeout_s=30.0,
        biome="StarterForest",
        count=4,
        phase_each=3.14159,
    )
    assert berry_row.get("ok", False), berry_row
    story_row = _wait_for_story_flag(rig, "forest_evolving", timeout_s=20.0)
    flags_fired = story_row.get("flags_fired", {})
    assert "forest_evolving" in flags_fired, story_row
    story_log = story_row.get("story_log", [])
    assert any(str(entry.get("id", "")) == "forest_evolving" for entry in story_log), story_row


def test_story_tab_never_narrates_unfired_beats(rig_boot) -> None:
    # Owner P0 (2026-07-11): a FRESH boot, X→Y, showed first_breath's past-tense
    # "You did something..." prose with zero player actions taken. The FOCUS pane
    # shows where graph ATTENTION sits (boot seeds density on the act-0 node) —
    # attention is not history, so beat prose renders only for FIRED flags.
    # Guard for ALL flags: open the story tab fresh and assert no un-fired
    # flag's arc_beat prose is visible anywhere.
    import json

    flags = json.loads(
        (PROJECT_ROOT / "Core" / "Quests" / "data" / "story_flags.json").read_text()
    )
    prose_by_flag = {}
    for f in flags:
        fid = str(f.get("id", ""))
        frags = []
        beat = str(f.get("arc_beat", "")).strip()
        if beat:
            frags.append(beat[:40])
        for cb in f.get("conditional_beat", []) or []:
            t = str(cb.get("text", "")).strip()
            if t:
                frags.append(t[:40])
        if fid and frags:
            prose_by_flag[fid] = frags

    rig, _proc = rig_boot(
        prefix="sw_pytest_story_tab_",
        load_slot=None,
        scenario_id="demos_normal",
        listener_stdout="null",
        rig_log_profile="quiet",
        extra_env={"RIG_QUEUE_POLL_MS": "80"},
    )

    boot_row = rig.run_turn(1, "story_flags", timeout_s=30.0)
    assert boot_row.get("ok", False), boot_row
    fired = set(boot_row.get("flags_fired", {}) or {})

    # Open X (playthrough) → Y (story tab), then read what the player SEES.
    rig.run_turn(2, "press_key", key="x", settle_frames=10)
    rig.run_turn(3, "press_key", key="y", settle_frames=10)
    text_row = rig.run_turn(4, "overlay_text", timeout_s=30.0)
    assert text_row.get("ok", False), text_row
    visible = "\n".join(str(line.get("text", "")) for line in text_row.get("lines", []))
    assert "FOCUS" in visible.upper(), f"story tab did not render a focus section:\n{visible[:2000]}"

    leaks = []
    for fid, frags in prose_by_flag.items():
        if fid in fired:
            continue
        for frag in frags:
            if frag in visible:
                leaks.append((fid, frag))
    assert not leaks, (
        "story tab narrates beats that never fired (past-tense prose for "
        f"un-fired flags): {leaks}"
    )
