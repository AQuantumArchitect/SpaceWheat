from pathlib import Path

import sys


ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "🍄" / "🎛️"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

from milk_hunt_characters import get_character, is_fibonacci_value, list_character_names, resolve_character_policy


def test_character_catalog_contains_demo_trio():
    names = set(list_character_names())
    assert {"granary_scout_fib", "solar_gatekeeper_fib", "village_diplomat_fib"} <= names


def test_demo_character_resources_are_fibonacci():
    for name in ("granary_scout_fib", "solar_gatekeeper_fib", "village_diplomat_fib"):
        character = get_character(name)
        assert character["resource_scale"] == "fibonacci"
        for amount in character["resources"].values():
            assert is_fibonacci_value(int(amount))


def test_character_policy_resolution_uses_engine_graph_and_inline_quantum_overrides():
    character = get_character("granary_scout_fib")
    engine_policy = resolve_character_policy(character, "engine_policy")
    quantum_policy = resolve_character_policy(character, "quantum_register")

    assert engine_policy["policy_kind"] == "ucb"
    assert engine_policy["policy_graph_path"].endswith("Core/Config/PolicyGraph/ucb/granary_scout.jsonl")
    assert quantum_policy["policy_kind"] == "quantum_register"
    assert quantum_policy["policy_graph_path"].endswith("Core/Config/PolicyGraph/default.jsonl")
    assert len(quantum_policy["policy_graph_jsonl"]) >= 1
