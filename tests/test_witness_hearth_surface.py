"""The sensor leg: Witness gauge → umwelt sensor readings → hearth.

Guards the contract that lets SpaceWheat be a live organ of the hive rather
than a spectator (plan: "SpaceWheat as the hive's body", 2026-08-01). Three
properties are load-bearing and all three have bitten us before:

  1. THE ABSENCE LAW — a faded belief is an absence, never a posted zero.
     The Witness field decays in game-seconds; emitting the decayed value as
     0.0 would overwrite real history at full strength.
  2. THE UNMATCHED LAW — a biome with no node is REPORTED, never dropped.
     Silently-dropped readings are exactly how hive-ops sat at 186/186
     unmatched with a fully-mixed field while the mesh trusted its beliefs.
  3. NO ACCIDENTAL POSTS — the poster is opt-in; importing it, or running it
     without SEMANTICA_POST=1, must never touch the network.

These run offline: no rig, no game, no hearth.
"""
import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "\U0001F344" / "\U0001F9EA"
HIVE = TOOLS / "hive"
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(HIVE))

witness_hearth = pytest.importorskip("witness_hearth")
witness_readings = pytest.importorskip("witness_readings")


def _gauge(clusters, **extra):
    return {"clusters": clusters, "spec_hash": "test", **extra}


def _bloch(**roles):
    return {"bloch": {r: [0.0, 0.0, z] for r, z in roles.items()}, "purity": 0.5}


# ---------------------------------------------------------------- absence law

def test_faded_belief_is_absence_not_zero():
    """|z| below the floor is dropped entirely — not posted as 0.0."""
    gauge = _gauge({"biome:Village": _bloch(yield_=0.0)})
    gauge["clusters"]["biome:Village"]["bloch"] = {"yield": [0, 0, 0.05],
                                                   "outcome": [0, 0, 0.9]}
    readings = witness_hearth.collect(gauge)
    assert "village_yield_felt" not in readings, "a faded belief must not be posted"
    assert readings["village_outcome_felt"] == pytest.approx(0.9)


def test_maximally_mixed_field_posts_no_belief_readings():
    """A fully-relaxed field (the 'starving world' state) yields nothing to claim."""
    gauge = _gauge({f"biome:{b}": _bloch(**{r: 0.0 for r in witness_hearth.BIOME_ROLES})
                    for b in ("Village", "Woodlot", "TheDemos")})
    readings = witness_hearth.collect(gauge)
    assert readings == {}, f"a dead field must claim nothing, got {readings}"


def test_sign_is_preserved():
    """Negative evidence is real evidence, not noise to be clamped away."""
    gauge = _gauge({"biome:Woodlot": _bloch(drain=-0.8)})
    assert witness_hearth.collect(gauge)["woodlot_drain_felt"] == pytest.approx(-0.8)


# -------------------------------------------------------------- unmatched law

def test_unmapped_biome_is_reported_not_silently_dropped():
    gauge = _gauge({"biome:Village": _bloch(yield_=0.5),
                    "biome:Wildwood": _bloch(yield_=0.9)})
    gauge["clusters"]["biome:Village"]["bloch"] = {"yield": [0, 0, 0.5]}
    gauge["clusters"]["biome:Wildwood"]["bloch"] = {"yield": [0, 0, 0.9]}
    assert witness_hearth.unmapped_biomes(gauge) == ["Wildwood"]
    readings = witness_hearth.collect(gauge)
    assert "village_yield_felt" in readings
    assert not any("wildwood" in k for k in readings), "unmapped must not post under a wrong id"


def test_every_mapped_biome_and_role_has_a_sensor_name():
    """No mapped (biome, role) pair may silently produce None."""
    for biome in witness_hearth.BIOME_NODES:
        for role in witness_hearth.BIOME_ROLES:
            assert witness_hearth.sensor_name(biome, role), f"{biome}.{role} has no sensor id"
    for role in witness_hearth.SELF_ROLES:
        assert witness_hearth.sensor_name(None, role), f"self.{role} has no sensor id"


def test_sensor_ids_are_unique_across_the_whole_spec():
    names = [witness_hearth.sensor_name(b, r)
             for b in witness_hearth.BIOME_NODES for r in witness_hearth.BIOME_ROLES]
    names += [witness_hearth.sensor_name(None, r) for r in witness_hearth.SELF_ROLES]
    assert len(names) == len(set(names)), "duplicate sensor id would collide two beliefs"


# ------------------------------------------------------------ surprise channel

def test_surprise_has_no_absence_floor():
    """A settled innovation EMA is real information, unlike a faded Bloch z."""
    gauge = _gauge({}, surprise={"terminal_measured": {"ema": 0.0, "n": 9}})
    assert witness_hearth.collect(gauge)["surprise_terminal_measured_ema"] == 0.0


# --------------------------------------------------------------- no-post laws

def test_running_without_opt_in_refuses_and_posts_nothing():
    proc = subprocess.run(
        [sys.executable, str(TOOLS / "witness_hearth.py")],
        capture_output=True, text=True, env={"PATH": "/usr/bin:/bin"}, timeout=60)
    assert proc.returncode == 2
    assert "SEMANTICA_POST" in proc.stderr


def test_dry_run_reports_ok_without_network(tmp_path):
    gauge_p = tmp_path / "g.json"
    gauge_p.write_text(json.dumps(_gauge({"biome:Village": {
        "bloch": {"yield": [0, 0, 0.7]}, "purity": 0.5}})), encoding="utf-8")
    proc = subprocess.run(
        [sys.executable, str(TOOLS / "witness_hearth.py"),
         "--gauge", str(gauge_p), "--dry-run"],
        capture_output=True, text=True, timeout=60)
    assert proc.returncode == 0, proc.stderr
    report = json.loads(proc.stdout)
    assert report["dry_run"] is True
    assert report["payload"]["village_yield_felt"] == pytest.approx(0.7)


# ------------------------------------------- shared-authority (no drift) proof

def test_sensor_ids_match_the_hearth_world_spec():
    """The poster and the world spec live in different REPOS and must agree.

    Every id the poster can emit needs a binding, and every binding needs a
    feeder — an unmatched reading is invisible ingest, an unfed binding is a
    belief that can only ever decay. Skips where the yurt tree isn't mounted.
    """
    world_dir = Path("/mnt/c/Users/Luke Spooner/ws-win/yurt/worlds/spacewheat_self")
    if not (world_dir / "world.py").exists():
        pytest.skip("yurt worlds tree not mounted on this machine")
    src = (world_dir / "world.py").read_text(encoding="utf-8")

    # Node list must be identical on both sides, or ids silently diverge.
    for node in witness_hearth.BIOME_NODES.values():
        assert f'"{node}"' in src, f"world spec has no node for {node}"
    for role in witness_hearth.BIOME_ROLES:
        assert f'"{role}"' in src, f"world spec lacks biome role {role}"
    for role in witness_hearth.SELF_ROLES:
        assert f'"{role}"' in src, f"world spec lacks self role {role}"


def test_almanac_uses_the_shared_converter():
    """almanac must not regrow its own copy of the conversion."""
    src = (HIVE / "almanac.py").read_text(encoding="utf-8")
    assert "from witness_readings import" in src
    assert "startswith(\"biome:\")" not in src, "almanac re-inlined the converter"


# ------------------------------------------------- the phantom-axis law (2026-08-02)
# A role the game declares but never BINDS can never carry a value. Posted anyway, it
# becomes a hearth register that renders ⚪ forever — and ⚪ reads as CALM, not as
# "this sense does not exist". That is the DARK-vs-STALE lie one layer down in the
# data, and it is invisible to every other test in this file because absence and
# never-existed are the same picture.
#
# Measured 2026-08-02 across 100 banked real-play gauges (522 biome-clusters):
#     coverage 76/522 · yield 14/522 · outcome 11/522 · drain 0/522 · ripeness 0/522
# `ripeness` was removed from BIOME_ROLES; it has NO binding and sits on the spec's
# own `ignored` list. `drain` stayed: it IS bound (resource_mutated.drain, and
# `lindblad_drain` has 13 emit sites in Core/*.gd), so its zero is an anomaly to
# chase, not a phantom. These tests keep that distinction from rotting.

WITNESS_SPEC = ROOT / "Core" / "Witness" / "witness_spec.json"


def _spec():
    return json.loads(WITNESS_SPEC.read_text(encoding="utf-8"))


def _bound_roles():
    return {b.get("role") for b in _spec().get("bindings", [])}


def test_every_posted_role_is_actually_bound_in_the_witness_spec():
    """THE PHANTOM-AXIS LAW: do not post a role the game cannot feed.

    If this fails you have added a role to BIOME_ROLES/SELF_ROLES that no binding
    in witness_spec.json drives — so the hearth will grow registers that are
    structurally incapable of ever moving, and the instrument will render them as
    a calm world instead of an absent sense.
    """
    bound = _bound_roles()
    posted = set(witness_hearth.BIOME_ROLES) | set(witness_hearth.SELF_ROLES)
    unbound = sorted(posted - bound)
    assert not unbound, (
        f"roles posted with no binding in witness_spec.json: {unbound}. "
        f"Either bind them in the game or stop posting them — a register that "
        f"cannot move must not exist. Bound roles are: {sorted(bound)}")


def test_ripeness_stays_out_until_the_game_actually_observes_it():
    """The specific regression. witness_spec.json's own `ignored` list carries
    ["biome:*.ripeness bindings", "phase 2: ..."], so re-adding ripeness to
    BIOME_ROLES before that phase lands would put 13 permanently-vacuum registers
    back on the hearth. When phase 2 ships, the ignored entry goes away and this
    test tells you so instead of silently passing."""
    ignored = {str(pair[0]) for pair in _spec().get("ignored", []) if pair}
    still_ignored = any("ripeness" in entry for entry in ignored)
    if still_ignored:
        assert "ripeness" not in witness_hearth.BIOME_ROLES, (
            "witness_spec.json still lists ripeness bindings as ignored, but the "
            "poster posts ripeness — those registers can never move")
    else:
        pytest.fail(
            "witness_spec.json no longer ignores ripeness bindings — phase 2 has "
            "landed. Add 'ripeness' back to witness_hearth.BIOME_ROLES AND to "
            "yurt/worlds/spacewheat_self/world.py BIOME_ROLES (one contract, two "
            "files), then delete this branch.")
