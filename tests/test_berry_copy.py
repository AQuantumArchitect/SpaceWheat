"""Guard the current berry lesson and payout in player-facing copy."""

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
HOW_TO_PLAY = ROOT / "docs/HOW_TO_PLAY.md"
GLOSSARY = ROOT / "Core/Documentation/glossary"

ACT_THREE = re.compile(r"\bact[\s-]+(?:3|iii|three)\b", re.IGNORECASE)
TIMES_FOUR = re.compile(r"(?<!\w)(?:[×x*]\s*4|4\s*[×x])(?!(?:\w|[×x]))", re.IGNORECASE)
PAYOUT_COPY = re.compile(
    r"\b(?:bonus|harvest\w*|known[- ](?:word|icon)|incorporat\w*|"
    r"vocabulary|strikes?|pays?|payout|yield_label)\b",
    re.IGNORECASE,
)
STRING = re.compile(r""" "(?:[^"\\]|\\.)*" | '(?:[^'\\]|\\.)*' """, re.VERBOSE)
CONTINUATION = re.compile(r"\n[ \t]*\+[ \t]*(?=[\"'])")


def test_player_berry_lesson_starts_in_act_one():
    guide = HOW_TO_PLAY.read_text(encoding="utf-8")
    berry_section = guide.split("\n## Berries", 1)[1].split("\n## ", 1)[0]
    assert not ACT_THREE.search(berry_section), berry_section
    assert re.search(r"\bAct 1\b", berry_section), berry_section


@pytest.mark.parametrize(
    "path",
    (HOW_TO_PLAY, ROOT / "docs/GAME_CODEX.md", *sorted(GLOSSARY.glob("*.md"))),
    ids=lambda path: path.relative_to(ROOT).as_posix(),
)
def test_player_docs_do_not_advertise_a_four_times_vocabulary_payout(path):
    for paragraph in path.read_text(encoding="utf-8").split("\n\n"):
        assert not (TIMES_FOUR.search(paragraph) and PAYOUT_COPY.search(paragraph)), (
            paragraph
        )


def test_in_game_copy_does_not_advertise_a_four_times_vocabulary_payout():
    for directory in ("Core", "UI", "scenes"):
        for path in (ROOT / directory).rglob("*"):
            if path.suffix not in {".gd", ".json", ".tscn", ".tres"}:
                continue
            source = path.read_text(encoding="utf-8")
            statements = CONTINUATION.sub(" + ", source).splitlines()
            for line in statements:
                if line.lstrip().startswith(("#", ";")):
                    continue
                strings = " ".join(STRING.findall(line))
                if TIMES_FOUR.search(strings):
                    assert not PAYOUT_COPY.search(line), (
                        f"{path.relative_to(ROOT)}: {line.strip()}"
                    )
