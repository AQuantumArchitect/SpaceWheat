#!/usr/bin/env python3
"""witness_readings — the one authority for Witness gauge → umwelt sensor readings.

Extracted from almanac.py's `_digest_checkpoint` (2026-08-01) so that the batch
learner (almanac, local pickle brain) and the live hearth poster
(witness_hearth.py, umweltd over the wire) share ONE conversion instead of two
drifting copies. Adding a third consumer means calling this, not copying it.

The gauge shape this reads is produced by `WitnessProjection.gauge`
(Core/Witness/WitnessProjection.gd) and served by the rig verb `witness_gauge`:

    {"spec_hash": str, "gamma_scale": float,
     "clusters": {"self":        {"bloch": {role: [x,y,z]}, "purity": f, ...},
                  "biome:<Name>": {"bloch": {role: [x,y,z]}, "purity": f, ...}},
     "observes_total": int,
     "surprise": {source: {"ema": f, "n": int}}}

THE ABSENCE LAW (umwelt FIELD_NOTES §3, proven in almanac): a faded Witness
belief is an ABSENCE, not a zero reading. The in-game field decays in
game-seconds, so a quiet gauge says "nothing happened here this leg" — emitting
that as 0.0 would overwrite real history at full strength. Readings with
|z| < ABSENCE_FLOOR are therefore DROPPED, never posted as zero.
"""
from __future__ import annotations

from typing import Callable, Iterable, Iterator

ABSENCE_FLOOR = 0.1
BIOME_PREFIX = "biome:"
SELF_CLUSTER = "self"


def iter_role_z(gauge: dict, *, include_self: bool = False,
                include_biomes: bool = True) -> Iterator[tuple[str | None, str, float]]:
    """Yield (biome_name_or_None, role, bloch_z) for every populated role.

    `biome_name_or_None` is None for the non-biome `self` cluster. No floor is
    applied here — this is raw extraction; policy belongs to the caller.
    """
    for cname, cluster in (gauge.get("clusters") or {}).items():
        if cname.startswith(BIOME_PREFIX):
            if not include_biomes:
                continue
            biome: str | None = cname.split(":", 1)[1]
        elif cname == SELF_CLUSTER:
            if not include_self:
                continue
            biome = None
        else:
            continue
        for role, vec in (cluster.get("bloch") or {}).items():
            if not isinstance(vec, (list, tuple)) or len(vec) < 3:
                continue
            yield biome, role, float(vec[2])


def gauge_to_readings(
    gauge: dict,
    *,
    name_fn: Callable[[str | None, str], str | None],
    roles: Iterable[str] | None = None,
    floor: float = ABSENCE_FLOOR,
    include_self: bool = False,
    include_biomes: bool = True,
) -> dict[str, float]:
    """Convert a Witness gauge into {sensor_id: z}, honouring the absence law.

    `name_fn(biome_or_None, role)` returns the sensor id, or None to skip —
    that is how a caller restricts itself to biomes it has vocabulary for.
    `roles` (if given) restricts which roles are considered at all.
    """
    wanted = set(roles) if roles is not None else None
    out: dict[str, float] = {}
    for biome, role, z in iter_role_z(gauge, include_self=include_self,
                                      include_biomes=include_biomes):
        if wanted is not None and role not in wanted:
            continue
        if abs(z) < floor:
            continue  # absence, not zero — see THE ABSENCE LAW above
        sensor = name_fn(biome, role)
        if sensor:
            out[sensor] = z
    return out


def surprise_readings(gauge: dict, *, name_fn: Callable[[str], str | None]) -> dict[str, float]:
    """Innovation EMA per observation source → {sensor_id: ema}.

    Unlike Bloch readings this has no absence law: a source whose innovation has
    settled to ~0 is genuinely "this channel stopped surprising me", which is
    real information, not a faded memory.
    """
    out: dict[str, float] = {}
    for source, entry in (gauge.get("surprise") or {}).items():
        if not isinstance(entry, dict) or "ema" not in entry:
            continue
        sensor = name_fn(source)
        if sensor:
            out[sensor] = float(entry["ema"])
    return out
