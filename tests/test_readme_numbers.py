"""The README's numbers are counted, not remembered. Before October 2026 it
said 64 biomes in one paragraph and 164 in another. tools/repo_stats.py
counts the tree; this test fails when the README drifts from it."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import repo_stats  # noqa: E402


def test_readme_counts_match_the_tree():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    g = repo_stats.game()
    assert re.search(rf"\| Biomes \| {g['biomes']}\b", readme), f"README biome count != {g['biomes']}"
    assert re.search(rf"\| Factions \| {g['factions']}, with {g['icons']} icons", readme), \
        f"README factions/icons != {g['factions']}/{g['icons']}"
    assert re.search(rf"\| Gates \| {len(g['gates'])} exact unitaries", readme), \
        f"README gate count != {len(g['gates'])}"


def test_readme_names_every_campaign_and_its_status():
    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    for c in repo_stats.game()["campaigns"]:
        assert c["title"] in readme, c["title"]
    assert "still in development" in readme
