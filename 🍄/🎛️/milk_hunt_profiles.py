#!/usr/bin/env python3
from __future__ import annotations

from typing import Any, Dict, List


ProfileDict = Dict[str, Any]


PROFILES: Dict[str, ProfileDict] = {
    "balanced_survival": {
        "description": "Stable probing and quest throughput with broad starter economy.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 300,
            "🌾": 300,
            "🍞": 160,
            "❄️": 160,
            "🌱": 120,
            "⚙": 120,
            "🔥": 120,
        },
        "unlocked_biomes": ["StarterForest", "Village"],
        "active_biome": "Village",
        "known_pairs": [{"north": "🌾", "south": "👥"}],
        "strict_biome_economy": True,
    },
    "probe_heavy": {
        "description": "High probe-cycle fuel for fast biome output sampling.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 180,
            "🌾": 180,
            "🍞": 320,
            "❄️": 320,
            "🌱": 80,
            "⚙": 80,
            "🔥": 80,
        },
        "unlocked_biomes": ["StarterForest", "Village"],
        "active_biome": "Village",
        "known_pairs": [{"north": "🌾", "south": "👥"}],
        "strict_biome_economy": True,
    },
    "quest_push": {
        "description": "Delivery quest throughput focus with high civic resources.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 420,
            "🌾": 420,
            "🍞": 100,
            "❄️": 100,
            "🌱": 70,
            "⚙": 70,
            "🔥": 70,
        },
        "unlocked_biomes": ["StarterForest", "Village"],
        "active_biome": "Village",
        "known_pairs": [{"north": "🌾", "south": "👥"}],
        "strict_biome_economy": False,
    },
    "injection_biased": {
        "description": "Supports repeated vocab injections as pairs unlock.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 220,
            "🌾": 220,
            "🍞": 140,
            "❄️": 140,
            "🌱": 260,
            "⚙": 90,
            "🔥": 90,
        },
        "unlocked_biomes": ["StarterForest", "Village", "BioticFlux"],
        "active_biome": "Village",
        "known_pairs": [{"north": "🌾", "south": "👥"}],
        "strict_biome_economy": False,
    },
    "scarcity_stress": {
        "description": "Tight economy stress test for route robustness.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 120,
            "🌾": 120,
            "🍞": 80,
            "❄️": 80,
            "🌱": 40,
            "⚙": 40,
            "🔥": 40,
        },
        "unlocked_biomes": ["StarterForest", "Village"],
        "active_biome": "Village",
        "known_pairs": [{"north": "🌾", "south": "👥"}],
        "strict_biome_economy": True,
    },
    "hard": {
        "description": "Hard mode: scarcity_stress profile saved as a named slot.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 120,
            "🌾": 120,
            "🍞": 80,
            "❄️": 80,
            "🌱": 40,
            "⚙": 40,
            "🔥": 40,
        },
        "unlocked_biomes": ["StarterForest", "Village"],
        "active_biome": "Village",
        "known_pairs": [{"north": "🌾", "south": "👥"}],
        "strict_biome_economy": True,
    },
    "milk_hunt_scarsity": {
        "description": "Alias for hard mode (scarcity stress).",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 120,
            "🌾": 120,
            "🍞": 80,
            "❄️": 80,
            "🌱": 40,
            "⚙": 40,
            "🔥": 40,
        },
        "unlocked_biomes": ["StarterForest", "Village"],
        "active_biome": "Village",
        "known_pairs": [{"north": "🌾", "south": "👥"}],
        "strict_biome_economy": True,
    },
    "biotic_flux_ladder": {
        "description": "BioticFlux-forward profile for ecosystem-driven quest chains.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 260,
            "🌾": 340,
            "🍞": 180,
            "❄️": 160,
            "🌱": 140,
            "⚙": 100,
            "🔥": 100,
        },
        "unlocked_biomes": ["StarterForest", "Village", "BioticFlux"],
        "active_biome": "BioticFlux",
        "known_pairs": [{"north": "🌾", "south": "👥"}, {"north": "🍄", "south": "🌾"}],
        "strict_biome_economy": True,
    },
    "volcanic_bridge": {
        "description": "Bridge profile for VolcanicWorlds and high-energy faction exposure.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 240,
            "🌾": 240,
            "🍞": 140,
            "❄️": 180,
            "🌱": 220,
            "⚙": 140,
            "🔥": 220,
        },
        "unlocked_biomes": ["StarterForest", "Village", "VolcanicWorlds"],
        "active_biome": "VolcanicWorlds",
        "known_pairs": [
            {"north": "🌾", "south": "👥"},
            {"north": "🔥", "south": "👥"},
            {"north": "✨", "south": "🔥"},
        ],
        "strict_biome_economy": False,
    },
    "fungal_long_horizon": {
        "description": "Fungal network exploration with microbial resource pressure.",
        "scenario_id": "default",
        "resource_mode": "set",
        "resources": {
            "👥": 200,
            "🌾": 260,
            "🍞": 140,
            "❄️": 140,
            "🌱": 180,
            "⚙": 110,
            "🔥": 110,
        },
        "unlocked_biomes": ["StarterForest", "Village", "FungalNetworks"],
        "active_biome": "FungalNetworks",
        "known_pairs": [
            {"north": "🌾", "south": "👥"},
            {"north": "🍄", "south": "🌾"},
            {"north": "🦠", "south": "🍄"},
        ],
        "strict_biome_economy": True,
    },
}


def get_profile(name: str) -> ProfileDict:
    if name not in PROFILES:
        available = ", ".join(sorted(PROFILES.keys()))
        raise ValueError(f"unknown profile '{name}'. available: {available}")
    profile = PROFILES[name].copy()
    profile["name"] = name
    return profile


def list_profiles() -> List[ProfileDict]:
    return [get_profile(name) for name in sorted(PROFILES.keys())]
