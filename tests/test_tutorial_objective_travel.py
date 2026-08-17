"""The Act-0 objective line must name a key, and must change when you obey it.

Found by running the literalist and the lost-lamb through a fresh Act 0 on the
same day: both walled at tutorial step 1, independently, for two halves of one
defect.

  - The step's mechanic happens in StarterForest, and the hint opened with
    "Cross to StarterForest." Once the player HAD crossed, the banner still
    said it — so the literalist read a standing order it had already obeyed,
    and the lost-lamb (which re-derives the objective every single turn and
    holds no memory of having crossed) reported LOOPING.
  - `objective_target()` already knew better: it pulses the biome tab before
    the verb chip. Only the TEXT was state-blind. Two halves of one guidance
    system, one of them lying.

The repair moves travel out of authored prose and onto the step's own `biome`
field, which both channels now read. These tests pin that the prose does not
grow the duplicate back.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARC = ROOT / "Core/Quests/data/tutorial_arc.json"
PROGRESSION = ROOT / "UI/Core/UIProgression.gd"
QII = ROOT / "UI/Core/QuantumInstrumentInput.gd"

BIOME_NAMES = ("TheDemos", "StarterForest", "Village")


def steps() -> list:
    return json.loads(ARC.read_text(encoding="utf-8"))["steps"]


def max_chars() -> int:
    m = re.search(r"OBJECTIVE_MAX_CHARS\s*:=\s*(\d+)", PROGRESSION.read_text(encoding="utf-8"))
    assert m, "OBJECTIVE_MAX_CHARS moved — this test reads it rather than hardcoding"
    return int(m.group(1))


def test_travel_is_derived_from_the_step_biome_not_written_into_prose() -> None:
    src = PROGRESSION.read_text(encoding="utf-8")
    assert "func _travel_line(" in src, (
        "the banner must lead with 'cross to <biome>' when the step's mechanic "
        "is somewhere the player isn't"
    )
    body = src.split("static func _travel_line(")[1].split("\nstatic func ")[0]
    assert 'get("biome"' in body, "travel must read the step's own biome field"
    assert "get_active_biome()" in body, (
        "and compare it against where the player actually stands, or the line "
        "never changes — which is the LOOPING defect this fixes"
    )
    assert '"TUTORIAL"' in body, (
        "scoped to TUTORIAL: arc quests carry biomes per-predicate and already "
        "resolve targets through PredicateGloss. A second, coarser travel rule "
        "for them would be the parallel authority UIProgression exists to avoid."
    )


def test_no_hint_hardcodes_a_journey() -> None:
    for s in steps():
        hint = str(s.get("tutorial_hint", ""))
        assert not re.search(r"\bCross to\b", hint, re.I), (
            "step %s still writes the journey into its prose; the banner "
            "derives it from `biome` now, and two copies drift: %r"
            % (s.get("tutorial_step"), hint)
        )


def test_a_hint_never_names_a_biome_other_than_its_own() -> None:
    """Step 5 declared biome=StarterForest while instructing the player to
    gather 'on TheDemos'. The spotlight reads `biome`, so the cue pointed at
    one country while the words named another."""
    for s in steps():
        own = str(s.get("biome", ""))
        hint = str(s.get("tutorial_hint", ""))
        for name in BIOME_NAMES:
            if name in hint:
                assert name == own, (
                    "step %s says %r in its hint but declares biome=%r — the "
                    "spotlight would pulse one tab while the text names another"
                    % (s.get("tutorial_step"), name, own)
                )


def test_every_hint_leads_with_a_sentence_the_banner_can_show_whole() -> None:
    """The banner truncates at OBJECTIVE_MAX_CHARS, cutting at a sentence
    boundary when one exists. So the FIRST sentence must fit and must stand on
    its own — otherwise the one line a player actually reads is a stump."""
    limit = max_chars()
    for s in steps():
        hint = str(s.get("tutorial_hint", "")).strip()
        if hint == "":
            continue
        first = re.split(r"(?<=[.!?])\s", hint)[0]
        assert len(first) <= limit, (
            "step %s's first sentence is %d chars, over the %d-char banner: "
            "it will be cut mid-clause and read as a broken instruction. %r"
            % (s.get("tutorial_step"), len(first), limit, first)
        )


def test_focusing_empty_ground_is_not_silent() -> None:
    """The other half of the same stall. Act 0 says "Pick a plot with G H J K L ;"
    while the starting biome has ONE register, so H..; move the cursor onto
    register-less ground. Under the 3D renderer that move is invisible: no orb
    exists there, and PlotGridDisplay — which would have drawn the selected tile
    — is hidden (visible == false), so set_selected_plot() paints nothing. The
    state really changed (F would explore the new plot), and the screen did not."""
    body = QII.read_text(encoding="utf-8").split("func _focus_plot(")[1].split("\nfunc ")[0]
    assert "_get_active_biome_register_count()" in body, (
        "_focus_plot must know whether the plot it just focused has a live "
        "register — that is what decides if anything is visible there"
    )
    assert "RefusalVoice" in body, (
        "a focus move onto empty ground must SPEAK. It lands with zero on-screen "
        "change otherwise, and a silent state change is what the anti-gating law "
        "exists to forbid."
    )


def test_act0_teaches_no_berry_ritual() -> None:
    """The 2026-08-17 reorder: berry phase is mid-game content ('we're not
    trying to teach a physics class' — owner). Act 0 must contain no track/
    incorporate step, and no tutorial gate may ask for signature growth —
    both walls the 2026-08-10 playtest personas hit in the first two minutes."""
    for s in steps():
        assert str(s.get("tutorial_teaches", "")) not in ("vocabulary", "vocab_escape"), (
            "the berry/vocabulary steps moved to the act-3 chapter "
            "(first_breath, story_flags.json) — they must not regrow here"
        )
        for p in s.get("state_predicates", []) or []:
            assert str(p.get("type", "")) not in (
                "signature_size_gte", "signature_growth_gte",
                "berry_consumed_count_gte", "berry_total_phase_gte",
            ), (
                "step %s gates on the berry/signature ritual — that is mid-game "
                "content now" % s.get("tutorial_step")
            )


def test_the_incorporation_teaching_survives_the_banner_and_names_the_wait() -> None:
    """Incorporating an icon is press-5 → F → WAIT → R. The wait is the part a
    player cannot guess, and the original hint omitted it entirely, so both
    personas fell back on the explore/strike verbs they already knew and got
    nowhere. The teaching now lives on the act-3 beat `first_breath`
    (story_flags.json) — same banner physics apply: the first sentence is what
    a player actually reads (arc hints sentence-cut at OBJECTIVE_MAX_CHARS),
    and it must name the hat, the tracking verb, and the honest wait."""
    flags = json.loads((ROOT / "Core/Quests/data/story_flags.json").read_text(encoding="utf-8"))
    fb = next((f for f in flags if f.get("id") == "first_breath"), None)
    assert fb is not None, "first_breath (the incorporation teaching) is missing"
    assert int(fb.get("act", -1)) >= 3, (
        "first_breath is the berry chapter's opener — mid-game (act 3+), never "
        "the on-ramp (the 2026-08-17 reorder)"
    )
    hint = str((fb.get("arc_quest") or {}).get("hint", ""))
    first = re.split(r"(?<=[.!?])\s", hint)[0]
    assert len(first) <= max_chars(), (
        "first_breath's hint lead is %d chars, over the %d-char banner — the one "
        "line a player reads would be a stump" % (len(first), max_chars())
    )
    assert "5" in first, "the lead must name the Icon hat key"
    assert re.search(r"\bF\b", first), "the lead must name the tracking verb F"
    assert re.search(r"\bR\b", hint), "the hint must name R (incorporate)"
    assert re.search(r"wait|orbit|ripe|clock|⏩", hint, re.I), (
        "must name the TIME beat — the loop ripens in real time, and that is the "
        "only step of the ritual that isn't a key press."
    )
    assert "90" in hint, (
        "must carry the honest duration: two legs measured ~90s at ×1, and the "
        "old authored '~30s'/'half a minute' was simply wrong"
    )
