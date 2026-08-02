#!/usr/bin/env python3
"""Mirror FractalAtlas.child_id determinism without Godot."""
import hashlib
import json
import unittest
from pathlib import Path


def child_id(parent_world_id: str, register_id: int, pole_0: str, pole_1: str) -> str:
    payload = f"{parent_world_id}|{register_id}|{pole_0}|{pole_1}"
    h = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    return f"icon:{h[:16]}"


class FractalAtlasMirrorTest(unittest.TestCase):
    def test_stable(self):
        a = child_id("world:campaign:StarterForest", 0, "☀", "⚡")
        b = child_id("world:campaign:StarterForest", 0, "☀", "⚡")
        self.assertEqual(a, b)
        self.assertTrue(a.startswith("icon:"))
        self.assertEqual(len(a), len("icon:") + 16)

    def test_differs_by_register(self):
        a = child_id("world:campaign:StarterForest", 0, "☀", "⚡")
        b = child_id("world:campaign:StarterForest", 1, "☀", "⚡")
        self.assertNotEqual(a, b)

    def test_example_face_schema(self):
        # yurt face if mounted
        for p in [
            Path("/mnt/c/Users/Luke Spooner/ws-win/yurt-sync/commons/vitals/fractal_atlas.json"),
            Path("commons/vitals/fractal_atlas.json"),
        ]:
            if p.is_file():
                data = json.loads(p.read_text(encoding="utf-8"))
                self.assertEqual(data.get("schema"), "fractal_atlas/v1")
                self.assertIn("nodes", data)
                break


if __name__ == "__main__":
    unittest.main()
