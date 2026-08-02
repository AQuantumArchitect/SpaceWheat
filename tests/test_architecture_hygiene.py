from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SELF_PATH = Path(__file__).resolve()
TEXT_SUFFIXES = {".gd", ".py", ".md", ".txt", ".json", ".jsonl", ".sh", ".cpp", ".h", ".cfg", ".tscn"}
SCAN_ROOTS = [
    ROOT / "Core",
    ROOT / "UI",
    ROOT / "docs",
    ROOT / "tests",
    ROOT / "native" / "src",
    ROOT / "🍄",
]

BANNED_PATTERNS = {
    "IconLexicon": "old icon registry layer",
    "EmojiPhysicsRegistry": "old emoji physics registry",
    "BiomeIcon": "old biome icon DTO",
    "ConversationHamiltonian": "old story wrapper",
    "ContractMarket": "old market facade",
    "QuantumContractEngine": "old native contract engine",
    "icon_lexicon": "old icon registry variable",
    "_ensure_icon_lexicon": "old icon registry helper",
    "contract_market": "old contract market path",
    "get_realization_icons": "retired biome accessor",
    "realize_faction_loadout": "retired biome-builder helper",
    "_resolve_realization_loadout": "retired biome-builder resolver",
    "realized_faction": "retired biome-builder metadata",
    "realization_icons": "retired biome loadout cache",
    "known_pairs": "retired icon-loadout vocabulary",
    "known_pair": "retired icon-loadout vocabulary",
    "known-pairs": "retired icon-loadout vocabulary",
    "known pairs": "retired icon-loadout vocabulary",
}

ARCHIVE_ROOT = ROOT / "archive"

# The hive's runtime ledgers (walls.jsonl and friends) are machine-appended
# playtest reports — sensor prose, not shipped code. A haiku describing a bug
# using retired vocabulary is data ABOUT the fleet, not residue IN the tree.
HIVE_RUNTIME_DIR = ROOT / "🍄" / "🧪" / "hive"

# Slop-patrol reports are the same category: duplication audits that QUOTE live and
# archived filenames as findings. A report naming tools/build_icon_lexicon.py (which
# exists, outside the scan roots) is data about the tree, not resurrected code.
SLOP_PATROL_GLOB = "SLOP_PATROL_*.md"
ARCHIVED_PATHS = {
    ROOT / "tests" / "contract_market_smoke.gd",
    ROOT / "docs" / "biomemissions" / "STARTERFOREST_VILLAGE_CONNECTIONS.md",
    ROOT / "🍄" / "PLAYER_FACTION.md",
}


def _iter_live_files():
    for base in SCAN_ROOTS:
        if not base.exists():
            continue
        if base.is_file():
            if base.suffix in TEXT_SUFFIXES and ARCHIVE_ROOT not in base.parents:
                yield base
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            if ARCHIVE_ROOT in path.parents:
                continue
            if HIVE_RUNTIME_DIR in path.parents and path.suffix == ".jsonl":
                continue
            if path.match(SLOP_PATROL_GLOB):
                continue
            if path.suffix not in TEXT_SUFFIXES:
                continue
            if path.resolve() == SELF_PATH:
                continue
            yield path


def test_archived_residue_not_present_in_live_tree():
    for archived_path in ARCHIVED_PATHS:
        assert not archived_path.exists(), f"archived path still present in live tree: {archived_path}"

    hits = []
    for path in _iter_live_files():
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for pattern, reason in BANNED_PATTERNS.items():
            if pattern in text:
                hits.append(f"{path}: {pattern} ({reason})")

    assert not hits, "retired system names still present in live tree:\n" + "\n".join(hits)
