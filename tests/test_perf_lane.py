"""A performance lane must address a parser that actually ships.

For at least one release cycle this repository carried fourteen files of
profiling tooling — four scripts, seven test-runners, two summarisers and a
GDScript harness — all of which drove the game with `--runtime-profile-mode=…`
and friends. Nothing has ever parsed those flags. The one file that could
(`tests/test_headed_runtime_profile.gd`) read `PROFILE_*` environment variables
instead, was invoked by nothing, and lived under `tests/`, which every export
preset excludes. So the lane launched a game, waited, found no JSON, and
reported the missing output as a build failure. `docs/EXPORT_HEALTH.md` and
`scripts/validate-desktop-release.sh --profile` both trusted it.

The failure was not "a script broke". It was that an instrument addressed
something that did not exist, and nothing could tell. These tests make that
specific silence impossible: the perf channel must be reachable from a SHIPPED
build, and no script may talk to the phantom again.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SAMPLER = ROOT / "Core/Debug/PerfSampler.gd"
RUNTIME_ENV = ROOT / "Core/Config/RuntimeEnv.gd"
PROJECT = ROOT / "project.godot"
EXPORT_LANE = ROOT / "scripts/profile-export-runtime.sh"
PRESETS = ROOT / "export_presets.cfg"


def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_no_script_addresses_the_phantom_profile_parser():
    """The flags that fourteen files spoke to, and nothing listened for.

    Executable lines only. Prose is allowed to name the dead flags — this file
    does, and so does the architecture note that records the deletion — because
    the danger was never the string, it was a script passing it to a binary.
    """
    speakers = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts or ".claude" in path.parts:
            continue
        # This file is the checker; it necessarily writes the dead flag down,
        # in a docstring and in its own failure message.
        if path.suffix not in {".sh", ".py", ".gd"} or path == Path(__file__):
            continue
        try:
            lines = path.read_text(encoding="utf-8").splitlines()
        except (UnicodeDecodeError, OSError):
            continue
        for n, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue
            if "--runtime-profile-" in line:
                speakers.append(f"{path.relative_to(ROOT)}:{n}")
    assert not speakers, (
        "these pass `--runtime-profile-*` to something, and no code in this repo parses "
        "it: " + ", ".join(speakers)
    )


def test_the_perf_channel_is_reachable_from_a_shipped_build():
    """`🍄/**` and `tests/**` are excluded from every export, so the sampler
    cannot live in either — that exclusion is what made the old harness
    unreachable from the pack a player runs."""
    assert SAMPLER.exists(), "Core/Debug/PerfSampler.gd is the perf channel; it is missing"
    rel = str(SAMPLER.relative_to(ROOT))
    presets = _read(PRESETS)
    for exclusion in ("🍄/**", "tests/**", "Core/Tests/**"):
        assert exclusion in presets, f"expected {exclusion} in the export exclude filter"
    assert not rel.startswith(("🍄/", "tests/", "Core/Tests/")), (
        f"{rel} sits inside an export-excluded tree — it would not ship"
    )
    assert f'PerfSampler="*res://{rel}"' in _read(PROJECT), (
        "PerfSampler must be an autoload, or nothing starts it in an exported game"
    )


def test_the_sampler_is_inert_without_its_env_var():
    """A player's build must pay one env read at boot and nothing after."""
    src = _read(SAMPLER)
    ready = src.split("func _ready()")[1].split("\nfunc ")[0]
    assert "set_process(false)" in ready and "return" in ready, (
        "_ready must disable processing when SW_PERF_LOG is unset"
    )
    assert 'env_str("SW_PERF_LOG", "")' in _read(RUNTIME_ENV), (
        "SW_PERF_LOG belongs to RuntimeEnv — the single authority for runtime switches"
    )


def test_a_report_says_when_it_cannot_be_trusted():
    """An fps number without its renderer is an adjective.

    Two numbers have already been published off invalid renderers: 10.4 fps on
    SwiftShader (docs/release/WEB_DOOR.md) and the llvmpipe desktop runs. The
    report has to carry its own disqualification rather than leave the reader to
    remember which box produced it.
    """
    src = _read(SAMPLER)
    assert "software_rendering_suspected" in src
    assert '"trustworthy"' in src, "the report must state a verdict, not just raw fields"
    assert "detect_software_renderer" in src, (
        "software-rasteriser detection has one owner (PerformanceOptimizer); a second "
        "list here could drift, and the game would cap for software while the report "
        "called the run trustworthy"
    )
    # Vsync and an fps cap each silently flatten a result to the refresh rate.
    assert "vsync is on" in src and "max_fps" in src


def test_the_uncap_switch_is_recorded_in_every_report():
    """SW_UNCAP_FPS produces a number no player can see. It must be impossible
    to mistake an uncapped run for a capped one after the fact."""
    optimizer = _read(ROOT / "Core/Settings/PerformanceOptimizer.gd")
    assert "RuntimeEnv.uncap_frame_rate()" in optimizer, (
        "the frame cap has one owner; the profiling override must go through it"
    )
    env_src = _read(RUNTIME_ENV)
    assert 'flag("SW_UNCAP_FPS", false)' in env_src, "must default OFF for players"
    describe = env_src.split("static func describe()")[1]
    assert '"uncap_frame_rate": uncap_frame_rate()' in describe, (
        "describe() is embedded verbatim in every perf report — if the flag is not in "
        "it, an uncapped run reads exactly like a capped one"
    )
    assert '"runtime_env": RuntimeEnv.describe()' in _read(SAMPLER)


def test_the_export_lane_drives_the_shipping_parser():
    src = _read(EXPORT_LANE)
    assert "SW_PERF_LOG" in src, "the export profiler must drive the channel that ships"
    for scenario in ("SW_AUTOSTART", "SW_LOAD_PATH"):
        assert scenario in src, (
            f"{scenario} is how the lane reaches real game state; without it every "
            "scenario measures the title card"
        )
    # A missing report is a fact about the build, not a mystery.
    assert re.search(r"no report at .*PerfSampler", src), (
        "when no report appears the lane must name the likely cause (a pack built "
        "before the sampler existed), not just warn"
    )


def test_loading_a_save_does_not_require_asking_for_a_screenshot():
    """SW_LOAD_PATH used to live inside GameRoot._dev_screenshot(), which quits
    the moment the capture lands — so the richest state in the game could be
    photographed but never run, and never profiled."""
    src = _read(ROOT / "scenes/GameRoot.gd")
    hooks = src.split("func _run_boot_env_hooks()")[1].split("\nfunc ")[0]
    assert "SW_LOAD_PATH" in hooks, "the checkpoint load must be its own step"
    shot = src.split("func _dev_screenshot()")[1].split("\nfunc ")[0]
    assert "SW_LOAD_PATH" not in shot, (
        "the screenshot path must not own the checkpoint load again"
    )
