"""The Almanac — SpaceWheat AS IT FEELS TO PLAY, as a learning umwelt world.

The third layer (owner's objective, 2026-07-14): a gauge-backed learning
graph that LEARNS the answer to the game from the tracked history of play.
Not the authored physics — the phenomenology. Its nodes are the experiential
topology; its learnable fiber and (eventually) grown couplings converge
toward how the game actually plays; every increment of that understanding is
a diff-stable gauge committed to git. The repo history of gauges IS the
fleet learning the game, auditable line by line.

Distinct from its siblings:
    the Witness (in-engine)  — one playthrough's beliefs; dies with the save
    the hive  (umweltd)      — the PROJECT's coordination state
    the Almanac (this)       — the GAME's felt shape, learned across all play

Sensors are per-session digests of real play: the Witness gauges banked
beside every checkpoint (a play session's own belief field — yield/outcome/
coverage per country), the flag manifests (story motion), and leg report
vitals (pace, fortune). Sessions are sparse discrete events → observe-
collapse semantics (the hive lesson), at referee-grade α where the reading
is manifest-derived.

Convergence criterion — "the answer to the game": the fiber quiets (param
drift → 0), grown topology goes dry, and the Almanac's forecasts of next-
session outcomes beat persistence prequentially. Until then, it is honestly
a student.
"""
from __future__ import annotations

from umwelt.spec import roles as role_registry
from umwelt.spec.schema import BindingSpec, DomainSpec, NodeSpec

COUNTRIES = ("demos", "village", "forest", "spring", "woodlot")

for _r in ("generous", "bright", "known", "story", "pace", "fortune"):
    role_registry.register_role_mode(_r, "dissipative", analog=True)

_Z_NORM = {"type": "range", "lo": -1.0, "hi": 1.0}   # witness bloch z passthrough


def _country_nodes() -> tuple:
    return tuple(
        NodeSpec(country, parent="game", kind="entity",
                 roles=("generous", "bright", "known"),
                 role_modes={"generous": "dissipative", "bright": "dissipative",
                             "known": "dissipative"},
                 # In-country couplings are NOT authored: if generosity co-moves
                 # with brightness, dream-topology growth must discover it from play.
                 params={"gamma_diss": (2.7e-7, 1e-7, 0.0, 1e-4)})
        for country in COUNTRIES
    )


def _country_bindings() -> tuple:
    out = []
    for c in COUNTRIES:
        out.append(BindingSpec(f"felt_{c}_yield", zone=c, role="generous",
                               normalizer=_Z_NORM, force_observe=True, collapse_alpha=0.6))
        out.append(BindingSpec(f"felt_{c}_outcome", zone=c, role="bright",
                               normalizer=_Z_NORM, force_observe=True, collapse_alpha=0.6))
        out.append(BindingSpec(f"felt_{c}_coverage", zone=c, role="known",
                               normalizer=_Z_NORM, force_observe=True, collapse_alpha=0.6))
    return tuple(out)


ALMANAC_SPEC = DomainSpec(
    name="spacewheat-almanac",
    nodes=(
        NodeSpec("game", parent=None, kind="root", roles=()),
        *_country_nodes(),
        NodeSpec("journey", parent="game", kind="entity",
                 roles=("story", "pace", "fortune"),
                 role_modes={"story": "dissipative", "pace": "dissipative",
                             "fortune": "dissipative"},
                 params={"gamma_diss": (1.3e-7, 1e-7, 0.0, 1e-4)}),
    ),
    bindings=_country_bindings() + (
        # Story motion: total fired flags this session (campaign has 44+).
        BindingSpec("session_flags", zone="journey", role="story",
                    normalizer={"type": "range", "lo": 0.0, "hi": 30.0},
                    force_observe=True, collapse_alpha=0.7),
        # Pace: presses per session (a leg's budget is ~250).
        BindingSpec("session_presses", zone="journey", role="pace",
                    normalizer={"type": "range", "lo": 0.0, "hi": 250.0},
                    force_observe=True, collapse_alpha=0.5),
        # Fortune: the money line.
        BindingSpec("session_coin", zone="journey", role="fortune",
                    normalizer={"type": "range", "lo": 0.0, "hi": 200.0},
                    force_observe=True, collapse_alpha=0.5),
    ),
    # Wall-clock decay: the Almanac remembers for ~a month between
    # sessions (gamma ~ 2.7e-7/s), unlike its in-game siblings whose
    # seconds are game-seconds. Forgetting is still legal - just slow.
    ingest_hold_s=3600.0,  # sessions are hours apart
)
