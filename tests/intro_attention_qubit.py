"""Two-qubit proxy of a new player's first minute.

q0 Attention: |0⟩ = listen, |1⟩ = do
q1 Register:  |0⟩ = story,  |1⟩ = machine (formula, 'accept this', act 0)

Computational basis of the experience:

    |00⟩  reading story
    |01⟩  reading engine dialect
    |10⟩  acting on the field with a story in mind
    |11⟩  mashing keys at a machine

Each intro surface is a reset-toward channel (a completely-positive map
that with probability p collapses toward a ket, else leaves ρ alone).
A player archetype is an initial density matrix plus which maps they
actually fire — what they click, skip, or stare at.

After the walk we score:

    story_fidelity  = ⟨00|ρ|00⟩ + ⟨10|ρ|10⟩     want high
    machine_leak    = ⟨01|ρ|01⟩ + ⟨11|ρ|11⟩     want low
    readiness       = ⟨10|ρ|10⟩                 will tap the right thing
    confusion       = 1 − Tr(ρ²)                pulled two ways

The NEW intro is the one shipping: welcome scene, story toast with
tap-for-more, Arc postcard, field visible through glass.
The OLD intro is the screenshot: keymap wall, 'accept' toast, Arc
formula. Tests assert NEW dominates OLD across archetypes.

This is a proxy, not a player. It exists so a change to the first minute
has a number that moves when the information flow gets more coherent.
"""
from __future__ import annotations

from typing import Callable, Dict, List, Sequence, Tuple

Complex = complex
Mat = List[List[Complex]]
Vec = List[Complex]


def _zero(n: int = 4) -> Mat:
    return [[0j] * n for _ in range(n)]


def _eye(n: int = 4) -> Mat:
    m = _zero(n)
    for i in range(n):
        m[i][i] = 1 + 0j
    return m


def _add(a: Mat, b: Mat, sa: float = 1.0, sb: float = 1.0) -> Mat:
    n = len(a)
    out = _zero(n)
    for i in range(n):
        for j in range(n):
            out[i][j] = sa * a[i][j] + sb * b[i][j]
    return out


def _matmul(a: Mat, b: Mat) -> Mat:
    n = len(a)
    out = _zero(n)
    for i in range(n):
        for k in range(n):
            aik = a[i][k]
            if aik == 0:
                continue
            for j in range(n):
                out[i][j] += aik * b[k][j]
    return out


def _dagger(a: Mat) -> Mat:
    n = len(a)
    return [[a[j][i].conjugate() for j in range(n)] for i in range(n)]


def _outer(ket: Sequence[Complex]) -> Mat:
    n = len(ket)
    return [[ket[i] * ket[j].conjugate() for j in range(n)] for i in range(n)]


def ket(*amps: float) -> Vec:
    return [complex(a) for a in amps]


KET_STORY_LISTEN = ket(1, 0, 0, 0)   # |00⟩
KET_MACHINE_LISTEN = ket(0, 1, 0, 0)  # |01⟩
KET_STORY_DO = ket(0, 0, 1, 0)        # |10⟩
KET_MACHINE_DO = ket(0, 0, 0, 1)      # |11⟩


def rho_pure(k: Sequence[Complex]) -> Mat:
    return _outer(k)


def rho_mixed(pairs: Sequence[Tuple[float, Sequence[Complex]]]) -> Mat:
    acc = _zero()
    for w, k in pairs:
        acc = _add(acc, _outer(k), 1.0, w)
    return acc


def reset_toward(rho: Mat, target: Sequence[Complex], p: float) -> Mat:
    """With probability p, collapse toward |ψ⟩⟨ψ|; else identity."""
    p = max(0.0, min(1.0, p))
    return _add(rho, _outer(target), 1.0 - p, p)


def tr(rho: Mat) -> Complex:
    return sum(rho[i][i] for i in range(len(rho)))


def purity(rho: Mat) -> float:
    rr = _matmul(rho, rho)
    return float(tr(rr).real)


def pop(rho: Mat, i: int) -> float:
    return float(rho[i][i].real)


def scores(rho: Mat) -> Dict[str, float]:
    s00, s01, s10, s11 = pop(rho, 0), pop(rho, 1), pop(rho, 2), pop(rho, 3)
    return {
        "story_fidelity": s00 + s10,
        "machine_leak": s01 + s11,
        "readiness": s10,
        "listen_story": s00,
        "confusion": 1.0 - purity(rho),
        "purity": purity(rho),
    }


# ── surfaces as channels ──────────────────────────────────────────────────

Channel = Callable[[Mat], Mat]


def ch(target: Sequence[Complex], p: float) -> Channel:
    return lambda rho, t=target, pr=p: reset_toward(rho, t, pr)


# OLD first-minute (the screenshot).
OLD = {
    "welcome": ch(KET_MACHINE_LISTEN, 0.55),   # keymap wall, field blacked out
    "toast": ch(KET_MACHINE_LISTEN, 0.70),     # "tap here to accept"
    "banner": ch(KET_STORY_DO, 0.45),          # strike/gather — the one honest line
    "arc": ch(KET_MACHINE_LISTEN, 0.80),       # act 0 / REAP ×1 / soft_gate
    "expand": ch(KET_MACHINE_LISTEN, 0.60),    # more formula
    "field": ch(KET_MACHINE_DO, 0.40),         # mash at a hidden farm
}

# NEW first-minute (this pass).
NEW = {
    "welcome": ch(KET_STORY_LISTEN, 0.70),     # scene, field as illustration
    "toast": ch(KET_STORY_LISTEN, 0.75),       # "The Demos sleeps"
    "banner": ch(KET_STORY_DO, 0.55),          # same live ask, now agreed
    "arc": ch(KET_STORY_LISTEN, 0.65),         # postcard, featured NOW door
    "expand": ch(KET_STORY_DO, 0.50),          # tap-for-more → the how, then the field
    "field": ch(KET_STORY_DO, 0.55),           # field visible, first tap is strike
}


# ── archetypes: initial ρ + the walk they actually take ───────────────────

Walk = List[str]  # keys into OLD/NEW


ARCHETYPES: Dict[str, Dict] = {
    "reader": {
        "rho0": rho_pure(KET_STORY_LISTEN),
        "walk": ["welcome", "toast", "expand", "arc", "banner", "field"],
        "note": "Reads everything, taps for more, opens Arc, then the field.",
    },
    "masher": {
        "rho0": rho_pure(KET_MACHINE_DO),
        "walk": ["welcome", "field", "banner"],
        "note": "Any-key dismiss, ignores toast, looks at the field, maybe the banner.",
    },
    "lost_lamb": {
        "rho0": rho_mixed([(0.5, KET_STORY_LISTEN), (0.5, KET_MACHINE_LISTEN)]),
        "walk": ["welcome", "toast", "arc", "expand"],
        "note": "Dismisses, taps the toast, lands on Arc. The postcard has to hold them.",
    },
    "mouse": {
        "rho0": rho_pure(KET_STORY_LISTEN),
        "walk": ["welcome", "toast", "expand", "banner", "field"],
        "note": "Tap begin, tap toast for more, tap the gold banner, tap a plot.",
    },
    "keyboard": {
        "rho0": rho_pure(KET_STORY_LISTEN),
        "walk": ["welcome", "banner", "arc", "field"],
        "note": "F to begin, reads the banner, X→I for Arc, then the field.",
    },
    "skip_welcome": {
        "rho0": rho_mixed([(0.6, KET_STORY_LISTEN), (0.4, KET_STORY_DO)]),
        "walk": ["toast", "banner", "field"],
        "note": "Returning / rig skip: no splash. Recap + banner must still agree.",
    },
    "arc_first": {
        "rho0": rho_pure(KET_MACHINE_LISTEN),
        "walk": ["arc", "expand", "banner", "field"],
        "note": "Opens Arc before doing anything. Featured door must be the live lesson, not First Harvest.",
    },
}


def run_walk(rho: Mat, walk: Walk, atlas: Dict[str, Channel]) -> Mat:
    for name in walk:
        rho = atlas[name](rho)
    return rho


def experience(archetype: str, atlas: Dict[str, Channel]) -> Dict[str, float]:
    spec = ARCHETYPES[archetype]
    rho = run_walk(spec["rho0"], spec["walk"], atlas)
    out = scores(rho)
    out["archetype"] = archetype  # type: ignore[assignment]
    return out


def compare_all() -> List[Dict[str, object]]:
    rows = []
    for name, spec in ARCHETYPES.items():
        old = experience(name, OLD)
        new = experience(name, NEW)
        rows.append({
            "archetype": name,
            "note": spec["note"],
            "old": old,
            "new": new,
            "delta_story": new["story_fidelity"] - old["story_fidelity"],
            "delta_leak": new["machine_leak"] - old["machine_leak"],
            "delta_ready": new["readiness"] - old["readiness"],
            "delta_confusion": new["confusion"] - old["confusion"],
        })
    return rows


def spine_tokens() -> Dict[str, str]:
    """The live-ask the NEW surfaces must agree on at minute one.

    Banner, first toast, and Arc featured door all name 'strike' — the
    first irreversible tap. First Harvest / reap is the capstone, not
    the first door.
    """
    return {
        "welcome_first_verb": "strike",  # the middle card; explore wakes, strike locks
        "toast_live_ask": "strike",
        "banner_live_ask": "strike",
        "arc_featured": "strike",
        "first_harvest_role": "capstone",
    }
