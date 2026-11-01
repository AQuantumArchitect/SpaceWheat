"""The music selector must build its emoji vectors from files that exist.

Playtest 2026-10-29: "the music isn't updating via the eigenvalue selector".
MusicManager loaded biomes_merged.json / factions_merged.json, retired files;
the loader is required:false, so it silently built EMPTY vectors. Layer 4
(nearest-sounding biome) and the IconMap refinement never fired; 122 of 164
biomes, TheDemos included, sat on the fallback track.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MM = ROOT / "Core" / "Audio" / "MusicManager.gd"


def _src() -> str:
    return MM.read_text(encoding="utf-8")


def test_vector_sources_exist():
    src = _src()
    for const in ("BIOMES_JSON_PATH", "FACTIONS_JSON_PATH"):
        m = re.search(r'const %s := "res://([^"]+)"' % const, src)
        assert m, const
        assert (ROOT / m.group(1)).is_file(), "%s points at a missing file: %s" % (const, m.group(1))


def test_refinement_only_scores_biomes_with_a_track():
    body = src = _src()
    body = src.split("func get_iconmap_similarities(")[1].split("\nfunc ")[0]
    assert "if not BIOME_TRACKS.has(biome_name):" in body
    assert "BIOME_TRACKS.get(biome_name, FALLBACK_TRACK)" not in body


def test_rate_limited_crossfade_is_retried_not_dropped():
    src = _src()
    xf = src.split("func crossfade_to(")[1].split("\nfunc ")[0]
    assert "_pending_track = track_key" in xf
    tick = src.split("func _tick_health(")[1].split("\nfunc ")[0]
    assert "crossfade_to(deferred)" in tick
    stop = src.split("func stop(")[1].split("\nfunc ")[0]
    assert '_pending_track = ""' in stop
