"""Anti-regression ratchets for the two 2026-07 purges.

1. DISK THRASH (2026-07-05 postmortem): a per-evolution-tick JSON cache
   (OperatorCache → BundledCache/) once maxed the owner's drive at 100%%.
   The cache is deleted; this test pins (a) zero references to it in game
   code, (b) no cache dir on disk, and (c) every FileAccess WRITE site in
   game code stays inside a reviewed whitelist — a new writer must be added
   here consciously, with its write frequency understood.

2. GDSCRIPT SHADOW PHYSICS (2026-07-06 purge): the GDScript evolution
   kernel, the per-pair mutual-information recompute (610ms/frame), and
   every silent native→GDScript fallback route were deleted. The native
   engine is the ONLY integrator; boot hard-fails without it. This test
   pins the deleted symbols out of existence and the boot gate in.
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME_DIRS = ["Core", "UI", "scenes"]


def _game_gd_files():
    for d in GAME_DIRS:
        yield from (ROOT / d).rglob("*.gd")


def _grep_game(pattern: str):
    hits = []
    rx = re.compile(pattern)
    for f in _game_gd_files():
        for n, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
            if rx.search(line):
                hits.append(f"{f.relative_to(ROOT)}:{n}: {line.strip()}")
    return hits


# ---------------------------------------------------------------------------
# 1. Disk thrash
# ---------------------------------------------------------------------------

def test_operator_cache_stays_dead():
    hits = _grep_game(r"OperatorCache|BundledCache|operator_cache|bundled_cache")
    assert not hits, "operator-cache reference resurfaced in game code:\n" + "\n".join(hits)


def test_no_cache_dir_on_disk():
    assert not (ROOT / "BundledCache").exists(), "BundledCache/ is back on disk"


# Every game-code file allowed to open a file for writing, with the reviewed
# reason. Adding a writer means extending this list in the same commit — that
# review moment is the whole point.
WRITE_WHITELIST = {
    "Core/GameState/SaveStore.gd",          # player saves (atomic temp+rename)
    "Core/GameState/ScenarioLedger.gd",     # once per scenario completion
    "Core/GameState/GameStateManager.gd",   # save orchestration
    "Core/Gallery/PostcardCapture.gd",      # explicit F12 screenshot
    "Core/Audio/MusicManager.gd",           # boot-once vector cache (truncate mode)
    "Core/Config/VerboseConfig.gd",         # opt-in file log, 50MB hard cap
    "Core/Instrumentation/QuantumInstrument.gd",  # explicit balance_export rig action
    "Core/Instrumentation/FractalAtlas.gd",  # export_json_path: atlas snapshot on inject/enter/ascend, not per-frame
    # Exactly one write, at the end of a profiling run, and only when
    # SW_PERF_LOG is set — which is never in a player's build. Reviewed
    # because a per-frame sampler writing per-frame would be this test's
    # nightmare case: the in-memory ring is flushed once, on the way out.
    "Core/Debug/PerfSampler.gd",
    # _materialize_web_save: at most one write per boot, and only reached when
    # OS.has_feature("web") AND SW_LOAD_PATH names a relative (non-user://,
    # non-res://) path — the headed web profiling lane fetching a save
    # same-origin into user:// before load. Never on a player's default path.
    "scenes/GameRoot.gd",
}


def test_every_write_site_is_whitelisted():
    offenders = []
    rx = re.compile(r"FileAccess\.open\s*\(.*(WRITE|READ_WRITE)")
    for f in _game_gd_files():
        rel = str(f.relative_to(ROOT))
        if rx.search(f.read_text(encoding="utf-8")) and rel not in WRITE_WHITELIST:
            offenders.append(rel)
    assert not offenders, (
        "new disk-writer(s) outside the reviewed whitelist "
        "(check write frequency, then extend WRITE_WHITELIST consciously):\n"
        + "\n".join(offenders)
    )


# ---------------------------------------------------------------------------
# 2. Native-only physics
# ---------------------------------------------------------------------------

def test_gdscript_integrator_stays_dead():
    qc = (ROOT / "Core/QuantumSubstrate/QuantumComputer.gd").read_text(encoding="utf-8")
    for symbol in ["func evolve(", "func _evolve_step(", "func _evolve_unitary(",
                   "func _entropy_of_marginal(", "func _entropy_of_joint(",
                   "func get_mutual_information("]:
        assert symbol not in qc, f"GDScript shadow-physics symbol resurrected: {symbol}"

    stepper = (ROOT / "Core/Environment/BiomeDeterministicStepper.gd").read_text(encoding="utf-8")
    assert "func run_direct_biome_cycle(" not in stepper, "run_direct_biome_cycle resurrected"

    hits = _grep_game(r"\.evolve\(")
    assert not hits, "something calls a GDScript .evolve() again:\n" + "\n".join(hits)


def test_boot_gate_requires_native_engine():
    boot = (ROOT / "Core/Boot/BootManager.gd").read_text(encoding="utf-8")
    assert "REQUIRED_NATIVE_CLASSES" in boot, "BootManager native gate deleted"
    for cls in ["QuantumMatrixNative", "QuantumEvolutionEngine",
                "MultiBiomeLookaheadEngine", "QuantumMythosEngine"]:
        assert cls in boot, f"BootManager native gate no longer checks {cls}"
    assert "quit(1)" in boot, "BootManager native gate no longer refuses to boot"


def test_native_extension_is_buildable_and_present():
    lib = ROOT / "native/bin/linux/libquantummatrix.linux.template_release.x86_64.so"
    assert lib.exists(), "native Linux engine binary missing — the game cannot run without it"
