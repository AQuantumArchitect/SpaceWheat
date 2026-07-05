import json
import re
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _flag_biomes() -> set:
    flags = json.loads((PROJECT_ROOT / "Core/Quests/data/story_flags.json").read_text())
    if isinstance(flags, dict):
        flags = flags.get("flags", [])
    biomes = set()
    for f in flags:
        for p in f.get("predicates", []):
            b = str(p.get("biome", ""))
            if b:
                biomes.add(b)
    return biomes


def _scenario_arrays(path: Path, key: str) -> list:
    text = path.read_text()
    m = re.search(key + r"\s*=\s*(?:Array\[String\]\()?\[([^\]]*)\]", text)
    if not m:
        return []
    return re.findall(r'"([^"]+)"', m.group(1))


def test_demos_pool_contains_every_campaign_biome() -> None:
    # The captain-hat draw is restricted to the scenario's curated pool
    # (ObservationFrame.get_unexplored_biomes). A story flag whose biome is
    # neither unlocked at boot nor in the pool is UNREACHABLE no matter how
    # much discovery pressure the narrative applies — the compass glows for a
    # door that isn't in the deck. This exact bug shipped once: the trilogy
    # landmarks (GildedRot, Lanternfall, ZenoLatch, ShrineOfAshes,
    # NullingChamber) were missing from demos_normal's pool, silently walling
    # acts 3–8.
    scenario = PROJECT_ROOT / "Scenarios/demos_normal.tres"
    pool = set(_scenario_arrays(scenario, "unexplored_biome_pool"))
    unlocked = set(_scenario_arrays(scenario, "unlocked_biomes"))
    assert pool, "demos_normal has no curated pool — did the scenario format change?"

    missing = sorted(_flag_biomes() - pool - unlocked)
    assert not missing, (
        "story flags reference biomes the shipped scenario can never discover: "
        f"{missing} — add them to unexplored_biome_pool in {scenario.name}"
    )
