#!/usr/bin/env python3
"""holonomy — measure whether a belief loop closes, without appointing a judge.

THE PROBLEM. A chain of components carries a signal from the world, through
sensing, belief, recommendation, and action, back to the world. Every component
declares what it does. Any of them can be wrong about itself, and a component
that is wrong about itself will pass every test written against its own
declaration. The usual answer is a referee — but a referee is just one more
component with a declaration, and in this codebase the referees were caught
calling the writers they refereed (cognifold_bouquet 2026-08-02, ref_tightness).

THE IDEA. Do not audit components. Audit LOOPS.

Give each hop an unknown orientation s ∈ {+1, −1}: does its output move with its
input, or against it? Nobody is asked. Each hop's declaration is ignored. What
is measured is the composite orientation of a whole closed path — perturb the
start, observe the end, take the sign. That composite is the product of the hops
it traverses, so writing s as a bit (0 = agrees, 1 = inverts) makes each measured
loop one linear equation over GF(2):

        Σ_{h ∈ L} s_h  ≡  parity(L)   (mod 2)

Measure several loops that share hops and you get a linear system. Then:

  * **INCONSISTENT** — no assignment of orientations to hops explains the
    measurements. Some component is not a sign-consistent map at all: it is
    stateful, nondeterministic, or lying. This is a proof of dishonesty that
    names no judge and needs no ground truth.
  * **CONSISTENT, with free variables** — the honest normal case. Absolute
    orientations are NOT observable; only loop parities are. This is a gauge
    freedom in the exact sense of the word, and pretending otherwise is how you
    get two components each "obviously correct" and a system that runs backwards.
  * **CONSISTENT, fully determined** (after fixing a gauge) — every hop's
    orientation recovered, none of them measured in isolation.

WHY THIS IS THE RIGHT SHAPE. A single loop tells you only that an EVEN or ODD
number of its hops invert — which is precisely the dead end this codebase hit
when two −z conventions were found multiplying to +1 and nothing could say which
one was "the" convention. Loops that share hops break the tie. Black boxes are
fine: a hop nobody can open still contributes its bit.

WHAT IT CANNOT DO. It sees orientation, not magnitude. A hop that scales by
0.001 has orientation +1 and destroys the loop anyway; `Hop.gain` is recorded so
that shows up, but it is not part of the algebra. A hop whose derivative is zero
at the probe point (a dead zone — see witness_readings.ABSENCE_FLOOR, which is
exactly such a zone for |z| < 0.1) has NO orientation there, and is reported as
UNDEFINED rather than silently folded in as agreement.

Usage:
    from holonomy import Hop, Loop, audit
    report = audit(hops, loops)         # -> dict, JSON-safe
    python3 holonomy.py                 # audit the live spacewheat-self ring
"""
from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Iterable, Sequence

# A derivative smaller than this is not a direction, it is a dead zone.
DEAD_ZONE = 1e-9

AGREES, INVERTS, UNDEFINED = 0, 1, None


# ── measuring one hop or one whole path ───────────────────────────────────────

@dataclass
class Hop:
    """One named, orientable link in a loop. `probe` is only needed if you want to
    measure this hop ALONE; the point of the module is that you usually cannot.

    `anchor` pins this hop's orientation to fix the gauge. Use it ONLY where the
    orientation is known by construction rather than by belief — an identity map
    inverts nothing as a matter of arithmetic, and that is a different kind of
    claim from "this component says it doesn't invert". An anchor enters the
    solve as one more equation, so an anchor that contradicts the measurements
    surfaces as an INCONSISTENCY rather than quietly bending the answer.
    """
    name: str
    probe: Callable[[float], float] | None = None
    note: str = ""
    anchor: int | None = None


@dataclass
class Loop:
    """A closed path: the hops it traverses, and how to drive it end to end.

    `drive(x) -> y` runs the whole path. The measured parity is the sign of
    dy/dx, taken by central difference at `x0`. Nothing about the individual
    hops is consulted.
    """
    name: str
    hops: Sequence[str]
    drive: Callable[[float], float]
    x0: float = 0.0
    eps: float = 0.6
    note: str = ""
    # filled by measure()
    parity: int | None = field(default=None, init=False)
    gain: float | None = field(default=None, init=False)
    hi: float | None = field(default=None, init=False)
    lo: float | None = field(default=None, init=False)

    def measure(self) -> "Loop":
        self.hi = float(self.drive(self.x0 + self.eps))
        self.lo = float(self.drive(self.x0 - self.eps))
        d = self.hi - self.lo
        self.gain = d / (2.0 * self.eps)
        self.parity = UNDEFINED if abs(d) < DEAD_ZONE else (AGREES if d > 0 else INVERTS)
        return self


# ── the GF(2) solve ───────────────────────────────────────────────────────────

def solve_gf2(rows: list[tuple[set[str], int]], unknowns: Sequence[str]) -> dict:
    """Solve Σ s_h ≡ p (mod 2) for the hop orientations.

    Returns {consistent, solved: {hop: bit}, free: [hop], conflict: [loop-index]}.
    `solved` is relative to setting every free variable to 0 — a GAUGE CHOICE,
    reported as such, never as a measurement.
    """
    idx = {h: i for i, h in enumerate(unknowns)}
    n = len(unknowns)
    # augmented matrix as integer bitmasks: bit i = unknown i, bit n = parity
    mat: list[int] = []
    prov: list[int] = []          # which input row each matrix row came from
    for r, (hops, p) in enumerate(rows):
        v = 0
        for h in hops:
            v ^= 1 << idx[h]
        if p:
            v ^= 1 << n
        mat.append(v)
        prov.append(r)

    pivot_of: dict[int, int] = {}   # column -> matrix row
    row = 0
    for col in range(n):
        piv = next((r for r in range(row, len(mat)) if mat[r] >> col & 1), None)
        if piv is None:
            continue
        mat[row], mat[piv] = mat[piv], mat[row]
        prov[row], prov[piv] = prov[piv], prov[row]
        for r in range(len(mat)):
            if r != row and (mat[r] >> col & 1):
                mat[r] ^= mat[row]
        pivot_of[col] = row
        row += 1

    # a row of 0 = 1 is a contradiction: no orientation assignment explains it
    conflict = [prov[r] for r in range(len(mat))
                if (mat[r] & ((1 << n) - 1)) == 0 and (mat[r] >> n & 1)]
    if conflict:
        return {"consistent": False, "solved": {}, "free": list(unknowns),
                "conflict_rows": conflict}

    free = [unknowns[c] for c in range(n) if c not in pivot_of]
    solved = {unknowns[c]: (mat[r] >> n & 1) for c, r in pivot_of.items()}
    for h in free:                       # the gauge choice, stated openly
        solved[h] = 0
    return {"consistent": True, "solved": solved, "free": free, "conflict_rows": []}


def audit(hops: Iterable[Hop], loops: Iterable[Loop]) -> dict:
    """Measure every loop, solve, and report. Never asserts; returns evidence."""
    hops = list(hops)
    hop_names = [h.name for h in hops]
    measured = [lp.measure() for lp in loops]
    usable = [lp for lp in measured if lp.parity is not None]
    dead = [lp.name for lp in measured if lp.parity is None]

    rows = [(set(lp.hops), lp.parity) for lp in usable]
    # anchors ride in as ordinary equations, so a wrong anchor shows up as a
    # conflict instead of silently choosing the answer
    anchored = [h for h in hops if h.anchor is not None]
    rows += [({h.name}, int(h.anchor)) for h in anchored]
    labels = [lp.name for lp in usable] + [f"anchor:{h.name}" for h in anchored]

    sol = solve_gf2(rows, hop_names) if rows else {
        "consistent": True, "solved": {}, "free": hop_names, "conflict_rows": []}

    return {
        "schema": "holonomy/0.1",
        "hops": [{"name": h.name, "note": h.note,
                  "anchored": h.anchor is not None} for h in hops],
        "loops": [{"name": lp.name, "hops": list(lp.hops),
                   "parity": lp.parity,
                   "orientation": ("undefined" if lp.parity is None
                                   else "agrees" if lp.parity == AGREES else "INVERTS"),
                   "gain": None if lp.gain is None else round(lp.gain, 6),
                   "hi": None if lp.hi is None else round(lp.hi, 6),
                   "lo": None if lp.lo is None else round(lp.lo, 6),
                   "note": lp.note}
                  for lp in measured],
        "dead_zone_loops": dead,
        "consistent": sol["consistent"],
        "orientations": {k: ("inverts" if v else "agrees")
                         for k, v in sorted(sol["solved"].items())},
        "gauge_free": sorted(sol["free"]),
        "anchors": [h.name for h in anchored],
        "conflicts": [labels[i] for i in sol["conflict_rows"] if i < len(labels)],
        "law": ("loop parity is gauge-invariant; single-hop orientation is not. "
                "inconsistency = a component is not a sign-consistent map."),
    }


def render(report: dict) -> str:
    """Human-readable. The instrument has to be legible or it is not an instrument."""
    out = [f"holonomy audit  ({len(report['loops'])} loops, {len(report['hops'])} hops)", ""]
    w = max((len(l["name"]) for l in report["loops"]), default=4)
    for l in report["loops"]:
        mark = {"agrees": "  +", "INVERTS": "  -", "undefined": "  ?"}[l["orientation"]]
        gain = "     —" if l["gain"] is None else f"{l['gain']:+.3f}"
        out.append(f"  {l['name']:<{w}}  {mark}  gain {gain}   [{' · '.join(l['hops'])}]")
    out.append("")
    if report["dead_zone_loops"]:
        out.append(f"  DEAD ZONE (no orientation at this probe point): "
                   f"{', '.join(report['dead_zone_loops'])}")
    if not report["consistent"]:
        out.append("  INCONSISTENT — no orientation assignment explains these loops.")
        out.append(f"  A component is not a sign-consistent map. Conflicts: "
                   f"{', '.join(report['conflicts'])}")
        return "\n".join(out)
    out.append("  consistent. hop orientations:")
    for hop, o in report["orientations"].items():
        tag = ("  (anchor)" if hop in report.get("anchors", []) else
               "  *" if hop in report["gauge_free"] else "")
        out.append(f"    {hop:<28s} {o}{tag}")
    if report["gauge_free"]:
        out.append(f"  * gauge choice, not a measurement — "
                   f"{len(report['gauge_free'])} free: {', '.join(report['gauge_free'])}")
    return "\n".join(out)


# ── the live ring: spacewheat-self ────────────────────────────────────────────
# The sensor leg of the hive's body, audited against itself. Four configurations
# of ONE binding give four loops over four hops; the solve recovers each hop's
# orientation without ever probing a hop alone.

def _umwelt_src() -> str:
    p = os.environ.get("UMWELT_SRC") or str(Path.home() / "ws" / "umwelt" / "src")
    if not (Path(p) / "umwelt").is_dir():
        raise SystemExit(f"[holonomy] umwelt not found at {p} — set UMWELT_SRC")
    return p


# What spacewheat-self DECLARES: every normalizer this world is allowed to bind
# (see _SHIPPED_BY_NORMALIZER below) was chosen specifically because its own
# docstring promises "this reading IS already a Bloch-z, land the belief AT it"
# — a declaration of AGREES, by construction of the allowlist, not by parsing
# world.py's prose. This does NOT "hold whichever normalizer the world picks":
# it holds only for normalizers on that allowlist. A newly-added mirror-breaking
# normalizer would not be caught here automatically — shipped_loop() would just
# report it as "not checked" (see below) rather than silently asserting AGREES.
SHIPPED_DECLARES = AGREES

# Which loop is "shipped" is READ FROM THE WORLD, never hardcoded. A snapshot here
# would go stale the moment someone edits the world — and an instrument that reports a
# stale verdict about its own subject is the exact failure this module exists to catch.
# (It went stale once already, minutes after the first fix. Hence this.)
_SHIPPED_BY_NORMALIZER = {"forecast_zflip": "zflip+observe"}
DEFAULT_WORLD = "/mnt/c/Users/Luke Spooner/ws-win/yurt/worlds/spacewheat_self/world.py"


def _force_observe_values(src: str, normalizer_marker: str) -> set[bool]:
    """force_observe values that co-occur with `normalizer_marker` at binding sites.

    Both fields live in the SAME BindingSpec(...) call in world.py, a few lines
    apart — this is a text-proximity read, same discipline as the Z_MIRROR line
    match below, not an import.
    """
    lines = src.splitlines()
    vals: set[bool] = set()
    for i, l in enumerate(lines):
        if normalizer_marker in l:
            for look in lines[i:i + 5]:
                if "force_observe=True" in look:
                    vals.add(True)
                    break
                if "force_observe=False" in look:
                    vals.add(False)
                    break
    return vals


def shipped_loop(world_py: str | None = None) -> tuple[str | None, str]:
    """(loop name, why) for the binding config the live world actually declares."""
    path = Path(world_py or os.environ.get("SPACEWHEAT_WORLD_PY") or DEFAULT_WORLD)
    if not path.is_file():
        return None, f"world spec not readable at {path} — cannot say what ships"
    src = path.read_text(encoding="utf-8")
    line = next((l for l in src.splitlines()
                 if l.startswith("Z_MIRROR")), None)
    if line is None:
        return None, f"no Z_MIRROR assignment in {path.name}"
    fo = _force_observe_values(src, "normalizer=Z_MIRROR")
    for norm, loop in _SHIPPED_BY_NORMALIZER.items():
        if norm in line:
            wants_observe = loop.endswith("+observe")
            if fo and fo != {wants_observe}:
                return None, (f"{path.name} sets Z_MIRROR to {norm}, but its bindings' "
                               f"force_observe values ({sorted(fo)}) don't uniformly "
                               f"match the '{loop}' path this table assumes")
            return loop, f"{path.name} sets Z_MIRROR to {norm}"
    # anything that is not a named flipping normalizer is the identity mirror —
    # but only if its bindings actually route through the observe path, since
    # that's the half of "ident+observe" this fallback name asserts.
    if fo and fo != {True}:
        return None, (f"{path.name} sets Z_MIRROR to an identity-range mirror, but its "
                       f"bindings' force_observe values ({sorted(fo)}) aren't uniformly "
                       f"True — 'ident+observe' would misdescribe the ingest path")
    return "ident+observe", f"{path.name} sets Z_MIRROR to an identity-range mirror"


def spacewheat_ring(role: str = "ripeness", settle: int = 12, alpha: float = 0.30):
    """Build the sensor-leg loops. Returns (hops, loops).

    Each loop drives ONE binding config end to end: post a reading, settle the
    engine, read the cluster's Bloch-z back. The hops are the two independent
    choices that binding makes — which normalizer, and which ingest path.
    """
    sys.path.insert(0, _umwelt_src())
    from umwelt.boot import build_engine
    from umwelt.spec import roles
    from umwelt.spec.schema import BindingSpec, DomainSpec, NodeSpec

    roles.register_role_mode(role, "dissipative", analog=True)
    IDENTITY = {"type": "range", "lo": -1.0, "hi": 1.0}

    def driver(normalizer, force_observe):
        def drive(x: float) -> float:
            node = NodeSpec("probe", parent=None, kind="root", roles=(role,),
                            role_modes={role: "dissipative"},
                            params={"gamma_diss": (0.02, 0.005, 0.0, 1.0)})
            b = BindingSpec("probe_felt", zone="probe", role=role,
                            normalizer=normalizer, force_observe=force_observe,
                            collapse_alpha=alpha, description="holonomy probe")
            spec = DomainSpec(name="holonomy-probe", nodes=(node,),
                              bindings=(b,), outputs=())
            eng = build_engine(spec=spec, population=False,
                               calibration=False, fractal=False)
            for _ in range(settle):
                eng.ingest(sensor_readings={"probe_felt": x})
            return float(eng.field.clusters["probe"].role_bloch(role)[2])
        return drive

    hops = [
        Hop("norm:forecast_zflip", note="spec/normalizers.py:25 — returns -clamp(val)"),
        # the one honest anchor available: range(-1,+1) IS x, by arithmetic
        Hop("norm:identity", note="range lo=-1 hi=+1 — identity by construction",
            anchor=AGREES),
        Hop("path:observe", note="membranes/ingress.py:178 — force_observe=True"),
        Hop("path:dissipative", note="the non-observe continuous drive"),
    ]
    # Notes on which loop "ships" are READ LIVE, same discipline as shipped_loop()
    # itself — a hand-written note here is exactly the kind of unprotected
    # snapshot the module's own docstring warns about, and it DID go stale once
    # already: this note said "what spacewheat-self actually ships" on
    # zflip+observe for weeks after the world moved to the identity mirror.
    _shipped_name, _shipped_why = shipped_loop()

    def _ships_note(loop_name: str) -> str:
        if _shipped_name is None:
            return f"shipped config not checked — {_shipped_why}"
        return (f"currently ships ({_shipped_why})" if loop_name == _shipped_name
                else f"does NOT currently ship — {_shipped_why}")

    loops = [
        Loop("zflip+observe", ("norm:forecast_zflip", "path:observe"),
             driver("forecast_zflip", True),
             note=_ships_note("zflip+observe")),
        Loop("zflip+diss", ("norm:forecast_zflip", "path:dissipative"),
             driver("forecast_zflip", False),
             note=("the mismatched pairing: forecast_zflip routed through the path "
                   "its own docstring never names — that docstring (normalizers.py:25) "
                   "describes only the observe path (ingress.py:530)")),
        Loop("ident+observe", ("norm:identity", "path:observe"),
             driver(IDENTITY, True), note=_ships_note("ident+observe")),
        Loop("ident+diss", ("norm:identity", "path:dissipative"),
             driver(IDENTITY, False)),
    ]
    return hops, loops


def verdict(report: dict, world_py: str | None = None) -> dict:
    """Compare the shipped loop's MEASURED orientation against what it DECLARES."""
    name, why_shipped = shipped_loop(world_py)
    if name is None:
        return {"checked": False, "why": why_shipped}
    loop = next((l for l in report["loops"] if l["name"] == name), None)
    if loop is None or loop["parity"] is None:
        return {"checked": False, "why": f"shipped loop {name!r} not measurable here"}
    agree = loop["parity"] == SHIPPED_DECLARES
    declared = "agrees" if SHIPPED_DECLARES == AGREES else "inverts"
    return {
        "checked": True, "loop": name, "shipped_because": why_shipped,
        "declared": declared,
        "measured": loop["orientation"].lower(),
        "honest": agree,
        "why": ("declaration matches measurement" if agree else
                f"loop {name!r} measured {loop['orientation'].lower()}, but the shipped "
                f"config ({why_shipped}) is assumed to declare {declared} — the "
                f"instrument would render this axis at its wrong pole"),
    }


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    as_json = "--json" in argv
    hops, loops = spacewheat_ring()
    report = audit(hops, loops)
    report["verdict"] = verdict(report)
    if as_json:
        print(json.dumps(report, ensure_ascii=False, indent=1))
    else:
        print(render(report))
        v = report["verdict"]
        print()
        if not v.get("checked"):
            print(f"  VERDICT: not checked — {v['why']}")
        else:
            print(f"  VERDICT [{v['loop']}]  declared={v['declared']}  "
                  f"measured={v['measured']}  ->  "
                  f"{'HONEST' if v['honest'] else 'LIES'}")
            print(f"    shipped config read live: {v['shipped_because']}")
            if not v["honest"]:
                print(f"    {v['why']}")
    # A ring whose measured orientation contradicts what the world declares is the
    # finding this tool exists for — but reporting it is the job, not exiting hot.
    return 0 if report["consistent"] else 1


if __name__ == "__main__":
    sys.exit(main())
