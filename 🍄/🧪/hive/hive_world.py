"""The fleet's hive world — SpaceWheat's DEVELOPMENT CAMPAIGN as an umwelt world.

Not the game: the PROJECT. One shared belief field that the whole fleet
(haiku playtester legs, implementation agents, referees, the supervisor)
reads and writes, run under umweltd. Beliefs answer the coordination
questions the supervisor has been carrying by hand:

    campaign chapters — is this chapter progressing? is something blocking it?
    build             — is the tree green (suite / campaign drive)?
    fleet             — are the agents' reports trustworthy lately? momentum?

THE HIVE LAW (learned 2026-07-14, taped in umwelt examples/hive_relay):
agent claims are sensor readings at HONEST η, never writes. Every chapter's
`progress` leaf takes two sensors — the leg's claim (low α) and the manifest
referee (high α) — so a confabulated report can bend shared belief only as
far as its earned confidence allows, and the referee corrects it.

All roles are analog-dissipative: one-polarity evidence must relax
(the dissipative-role law), and a blank hive must boot UNKNOWN, not
"everything is broken" (the blank-mix law).

Registered with umweltd via spec_path (a first-class external world).
"""
from __future__ import annotations

from umwelt.spec import roles as role_registry
from umwelt.spec.schema import BindingSpec, DomainSpec, NodeSpec

CHAPTERS = ("woodlot", "spring", "act3", "hub")

for _r in ("progress", "blocked", "suite", "drive", "truthful", "momentum"):
    role_registry.register_role_mode(_r, "dissipative", analog=True)


def _chapter_nodes() -> tuple:
    return tuple(
        NodeSpec(ch, parent="campaign", kind="entity", roles=("progress", "blocked"),
                 role_modes={"progress": "dissipative", "blocked": "dissipative"},
                 params={"gamma_diss": (0.02, 0.01, 0.0, 1.0)})
        for ch in CHAPTERS
    )


def _chapter_bindings() -> tuple:
    out = []
    for ch in CHAPTERS:
        # The leg's own claim: fluent, structured, sometimes wrong — α says so.
        out.append(BindingSpec(f"claim_{ch}", zone=ch, role="progress",
                               normalizer="binary", force_observe=True, collapse_alpha=0.25))
        # The referee (manifest diff / checkpoint dir): boring and right.
        out.append(BindingSpec(f"truth_{ch}", zone=ch, role="progress",
                               normalizer="binary", force_observe=True, collapse_alpha=0.9))
        # Stuck-point reports: the legs' most reliable output historically.
        out.append(BindingSpec(f"blocked_{ch}", zone=ch, role="blocked",
                               normalizer="binary", force_observe=True, collapse_alpha=0.6))
    return tuple(out)


HIVE_SPEC = DomainSpec(
    name="spacewheat-hive",
    nodes=(
        NodeSpec("campaign", parent=None, kind="root", roles=()),
        *_chapter_nodes(),
        NodeSpec("build", parent="campaign", kind="entity", roles=("suite", "drive"),
                 role_modes={"suite": "dissipative", "drive": "dissipative"},
                 params={"gamma_diss": (0.01, 0.01, 0.0, 1.0)}),
        NodeSpec("fleet", parent="campaign", kind="entity",
                 roles=("truthful", "momentum"),
                 role_modes={"truthful": "dissipative", "momentum": "dissipative"},
                 params={"gamma_diss": (0.008, 0.01, 0.0, 1.0),
                         "gamma_diss_momentum": (0.03, 0.01, 0.0, 1.0)}),
    ),
    bindings=_chapter_bindings() + (
        BindingSpec("suite_result", zone="build", role="suite",
                    normalizer="binary", force_observe=True, collapse_alpha=0.95),
        BindingSpec("drive_result", zone="build", role="drive",
                    normalizer="binary", force_observe=True, collapse_alpha=0.95),
        # Per-leg claim accuracy, judged by the referee after the fact — the
        # fleet's calibration belief ("how much is a report worth lately").
        BindingSpec("leg_accurate", zone="fleet", role="truthful",
                    normalizer="binary", force_observe=True, collapse_alpha=0.5),
        BindingSpec("leg_completed", zone="fleet", role="momentum",
                    normalizer="binary", force_observe=True, collapse_alpha=0.4),
    ),
    ingest_hold_s=600.0,  # legs land minutes-to-hours apart: sparse by nature
)
