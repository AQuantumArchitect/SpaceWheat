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

    # Positive half: the flag fires FROM the action. The berry chapter sits in
    # act 3 behind two act-2 teachings (forest_evolving requires lumber_flows
    # AND spring_connects), so build that state honestly-by-construction with
    # the spec fixture: start_at_beat replays every ancestor door through the
    # real claim path and lets QuestManager open forest_evolving itself.
    fx = rig.run_turn(50, "start_at_beat", id="forest_evolving", timeout_s=240.0)
    assert fx.get("ok", False) and fx.get("fired", False) and not fx.get("forced"), fx
    assert fx.get("offer_present", False), fx
    pre = rig.run_turn(51, "story_flags", timeout_s=30.0).get("flags_fired", {})
    assert "forest_listener" not in pre, "forest_listener fired without the berries"

    # The action: accept the forest's offer, incorporate berries until its
    # count gate (3 in StarterForest) fills, claim — and forest_listener (the
    # next beat, door rule) fires from that claim, not from anything at boot.
    offers = rig.run_turn(52, "story_offers", timeout_s=30.0).get("story_offers", [])
    q = next(o for o in offers if o.get("source_flag") == "forest_evolving")
    acc = rig.run_turn(53, "accept_quest", quest_id=int(q["id"]), timeout_s=30.0)
    assert acc.get("accepted", False), acc
    berry_row = rig.run_turn(
        99,
        "consume_berry",
        timeout_s=30.0,
        biome="StarterForest",
        count=4,
        phase_each=3.14159,
    )
    assert berry_row.get("ok", False), berry_row
    deadline = time.time() + 20.0
    turn = 100
    while time.time() < deadline:
        qs = rig.run_turn(turn, "active_quests", full=True, timeout_s=30.0).get("quests", [])
        mine = [a for a in qs if a.get("source_flag") == "forest_evolving"]
        if not mine:
            break  # claimed already
        if mine[0].get("status") == "ready":
            rig.run_turn(turn + 1, "claim_quest", quest_id=int(mine[0]["id"]), timeout_s=30.0)
        turn += 2
        time.sleep(0.25)
    story_row = _wait_for_story_flag(rig, "forest_listener", timeout_s=20.0)
    flags_fired = story_row.get("flags_fired", {})
    assert "forest_listener" in flags_fired, story_row
    story_log = story_row.get("story_log", [])
    assert any(str(entry.get("id", "")) == "forest_listener" for entry in story_log), story_row


def test_story_tab_never_narrates_unfired_beats(rig_boot) -> None:
    # Owner P0 (2026-07-11): a FRESH boot, X→Y, showed first_breath's past-tense
    # "You did something..." prose with zero player actions taken. Story is
    # memoir (behind) + murmur (beside). Attention may name a live lens
    # ("leaning toward …") but beat prose renders only for FIRED flags.
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
    visible_up = visible.upper()
    assert "FOCUS" not in visible_up, (
        "FOCUS pane came back — Story is memoir + murmur, not a second plot:\n"
        f"{visible[:2000]}"
    )
    assert (
        "MURMUR" in visible_up
        or "LEANING TOWARD" in visible_up
        or "MEMOIR" in visible_up
    ), f"story tab did not render memoir/murmur:\n{visible[:2000]}"

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
