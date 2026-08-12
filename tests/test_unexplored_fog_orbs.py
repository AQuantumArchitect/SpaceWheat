"""Unexplored ground still draws a ball, and the reveal gates still hold.

Owner ruling 2026-08-11: "unexplored registers/plots should be dimmed spheres
with no emojis on them. so a biome will always hold the same shape, but just be
unlabelled when unexplored."

That closes #513. The orbs were ALWAYS pickable — `_orb_at`/`_try_pick` never
filtered on visibility — but an invisible orb is not a click affordance, so a
mouse-only player could drive the loop and still not choose WHICH plot to
explore. Measured live before the change, at act1_complete: `bubble_count=1,
visible_count=0` and a screenshot with no orb on screen at all.

The change has one sharp edge, which is what these tests actually guard. The
reveal state used to be INFERRED from `b.mesh.visible`, and seven separate
channels asked it there (MI edges, metro lines, Lindblad arrows, state vectors,
Bloch trails, descend satellites, the rig surface). The moment unexplored ground
starts drawing a ball that proxy is false, and every one of those gates silently
opens — an unexplored register would begin displaying physics the player has
never looked at. So the flag is now stored once and read once.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FIELD = ROOT / "Core/Visualization/QuantumField3D.gd"


def src() -> str:
    return FIELD.read_text(encoding="utf-8")


def func(name: str) -> str:
    body = src().split("func %s(" % name)
    assert len(body) > 1, "%s() is gone — this test reads it rather than guessing" % name
    return body[1].split("\nfunc ")[0]


def test_the_ball_is_the_ground_and_ground_does_not_come_and_go() -> None:
    body = func("_set_bubble_revealed")
    assert "mesh.visible = true" in body, (
        "the Bloch ball must draw whether or not the plot is explored — that "
        "constant shape IS the ruling, and it is what gives a pointer a target "
        "on every plot (#513)"
    )


def test_an_unexplored_orb_carries_no_label_and_no_readout() -> None:
    """`np`/`spr` are the |0>/|1> pole emoji, `dot` the live Bloch state point,
    `ring` the gold ripeness ring, `eq`/`axisline` the phase circle and
    measurement axis. Every one of them reports state the player has not looked
    at yet."""
    body = func("_set_bubble_revealed")
    hidden = body.split("for k in [")[1].split("]")[0]
    for part in ("eq", "axisline", "np", "spr", "dot", "ring"):
        assert '"%s"' % part in hidden, (
            "%r must be reveal-gated: an unexplored register is a DIMMED, "
            "UNLABELLED sphere, not a live instrument" % part
        )
    assert '"mesh"' not in hidden, (
        "the ball must not be in the hidden set — that is the whole change"
    )


def test_reveal_state_is_stored_once_not_inferred_from_the_renderer() -> None:
    setter = func("_set_bubble_revealed")
    assert 'b["revealed"] = revealed' in setter, (
        "the reveal flag must be STORED. It used to be read back off "
        "`mesh.visible`, which stopped being a truthful proxy the moment "
        "unexplored ground started drawing a ball."
    )
    reader = func("_bubble_shown")
    assert 'b.get("revealed"' in reader, (
        "_bubble_shown is the single question every reveal-gated channel asks; "
        "it must read the stored flag"
    )
    assert "mesh.visible" not in reader, (
        "asking mesh.visible here opens every gate at once — unexplored orbs "
        "would draw MI edges, metro lines, flow arrows, state vectors and trails"
    )


def test_no_bubble_channel_still_reads_visibility_as_exploration() -> None:
    """The sharp edge, swept. `dp2.mesh.visible` (descend PORTAL nodes) is a
    different thing and legitimately stays — portals really are shown/hidden."""
    offenders = []
    for i, line in enumerate(src().splitlines(), start=1):
        if line.lstrip().startswith("#") or line.lstrip().startswith("##"):
            continue
        if re.search(r"\bb\.mesh\.visible\b", line) or re.search(r'b\.get\("mesh"\)\)? and b\.mesh\.visible', line):
            offenders.append("%d: %s" % (i, line.strip()))
    assert not offenders, (
        "these read a BUBBLE's mesh visibility as its exploration state, which "
        "is no longer true — route them through _bubble_shown():\n  %s"
        % "\n  ".join(offenders)
    )


def test_the_rig_reports_exploration_not_pixels() -> None:
    """A mouse leg filters its targets on `visible`. It must keep meaning
    "explored" (every probe in 🍄/🧪 counts on that, and reveal_probe asserts
    visible_count==0 at boot), while `screen_pos` carries the on-screen truth —
    otherwise the harness re-tells exactly the lie that made #513 read as
    "unrevealed plots have no mouse target"."""
    body = func("rig_bubble_state")
    assert '"visible": _bubble_shown(b)' in body, (
        "rig `visible` must be the explored flag, not mesh visibility"
    )
    assert '"screen_pos"' in body, (
        "and every orb — fog included — must report where to aim, or a mouse "
        "leg cannot target the ground it can now see"
    )


def test_the_cursor_is_not_reveal_gated() -> None:
    """Focusing unexplored ground used to be invisible under the 3D renderer.
    The fog ball gives the selection ring something to sit on; gating the ring
    on exploration would re-open the silent-focus hole underneath it."""
    body = func("_update_selection_visuals")
    assert "_bubble_shown" not in body and "mesh.visible" not in body, (
        "the selection ring is the CURSOR — it must show wherever the cursor "
        "is, including on fog"
    )


def test_fog_is_dimmer_and_greyer_than_a_live_orb() -> None:
    text = src()
    m = re.search(r"const FOG_SAT\s*:=\s*([0-9.]+)", text)
    v = re.search(r"const FOG_VAL\s*:=\s*([0-9.]+)", text)
    assert m and v, "the fog tint must be named constants, not magic numbers"
    assert float(m.group(1)) < 0.5, (
        "unexplored ground must be DESATURATED — at full biome saturation it "
        "competes with the live registers instead of receding behind them"
    )
    assert float(v.group(1)) < 0.75, "and darker than a live orb's glow"
