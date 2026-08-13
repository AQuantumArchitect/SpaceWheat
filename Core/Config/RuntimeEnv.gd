class_name RuntimeEnv
extends RefCounted

## SINGLE AUTHORITY for every runtime switch that can make one boot of the game behave
## differently from another — display capability, onboarding/boot variant, physics-engine
## toggles, and gameplay/perf overrides. Before this file these were ~75 raw
## `OS.get_environment(...)` / `DisplayServer.get_name()` reads smeared across 14 files, each
## with its OWN default and its OWN truthiness logic. That is exactly how the `godot` (real
## player) path and the rig (test harness) path silently drift apart — e.g. RIG_DISABLE_LOOKAHEAD
## defaulted to "1" in 🟢.sh but "0" in a probe, and the welcome splash was skipped on one path
## but not the other (a player-facing bug the rig never hit).
##
## RULE: any code that wants to know "am I headless?", "should I show the welcome?", "is the
## C++ lookahead on?" etc. asks THIS class. Do not re-read the env elsewhere. One key, one
## default, one truthiness rule, defined once — so the divergence surface is auditable in a
## single file and `describe()` can dump the whole mode-matrix for a rig-vs-player diff.
##
## What does NOT live here (by design, not omission):
##  - Rig IPC plumbing (RIG_QUEUE_PATH, RIG_RESULT_PATH, RIG_QUEUE_POLL_MS, RIG_LOG_PROFILE,
##    RIG_SCENARIO, RIG_LOAD_SLOT, …) — the player never reads these, so they can't cause a
##    rig-vs-player divergence; they stay in 🍄/🎛️/rig_listener.gd.
##  - VERBOSE_* logging gates — owned by Core/Config/VerboseConfig.gd (the logging authority).
##
## All accessors are static (callable from autoloads, static contexts like SaveStore, and the
## rig's SceneTree alike) and read the env fresh — the OS env is constant for a process, and
## the few hot callers (QuantumComputer, BiomeEvolutionBatcher) cache the result themselves.

const _TRUE_TOKENS := ["1", "true", "yes", "on"]
const _FALSE_TOKENS := ["0", "false", "no", "off"]

# ============================================================================
# Generic typed readers — for the long tail with caller-specific defaults.
# ============================================================================

static func _truthy(raw: String) -> bool:
	return raw.strip_edges().to_lower() in _TRUE_TOKENS

static func flag(key: String, default_value: bool = false) -> bool:
	var raw := OS.get_environment(key)
	if raw.strip_edges() == "":
		return default_value
	return _truthy(raw)

static func env_int(key: String, default_value: int) -> int:
	var raw := OS.get_environment(key)
	if raw == "" or not raw.is_valid_int():
		return default_value
	return raw.to_int()

static func env_float(key: String, default_value: float) -> float:
	var raw := OS.get_environment(key)
	if raw == "" or not raw.is_valid_float():
		return default_value
	return raw.to_float()

static func env_str(key: String, default_value: String = "") -> String:
	var raw := OS.get_environment(key).strip_edges()
	return raw if raw != "" else default_value

## Tri-state env read: 1 = truthy, 0 = explicitly falsy, -1 = unset/unknown (caller falls back).
static func tristate(key: String) -> int:
	var v := OS.get_environment(key).strip_edges().to_lower()
	if v in _TRUE_TOKENS:
		return 1
	if v in _FALSE_TOKENS:
		return 0
	return -1

# ============================================================================
# Display capability — "is there a screen / audio device?" The single source.
# ============================================================================

## True when running without a display (CI, the headless rig, `--headless`). Rendering, the
## emoji atlas, the force graph and audio are no-ops here. NOT a proxy for "is the rig" — a
## headed rig (RIG_DISPLAY_MODE=headed) is NOT headless and runs the player's full pipeline.
static func is_headless() -> bool:
	return OS.has_feature("headless") or DisplayServer.get_name() == "headless"

static func is_touch() -> bool:
	return OS.has_feature("touchscreen")

# ============================================================================
# Onboarding / boot variant — the class of switch that hid the welcome-trap bug.
# ============================================================================

## Skip the first-run welcome splash and begin the tutorial immediately. The rig sets this for
## fast automation; a real player never has it set, so they see the splash. A headed run that
## means to verify the player's onboarding must leave this FALSE.
static func skip_welcome() -> bool:
	return flag("RIG_SKIP_WELCOME", false)

## Headed rig only: leave the title card up and drive title → menu → welcome with synthetic
## keys (the REAL player boot), instead of calling AppRoot.start_game() directly.
static func drive_title() -> bool:
	return flag("RIG_DRIVE_TITLE", false)

# ============================================================================
# Time-skip (the rig's synchronous fast-forward path).
# ============================================================================

static func debug_timeskip() -> bool:
	return flag("RIG_DEBUG_TIMESKIP", false)

static func time_skip_skip_lindblad() -> bool:
	return flag("RIG_TIME_SKIP_SKIP_LINDBLAD", false)

static func time_skip_require_activity() -> bool:
	return flag("RIG_TIME_SKIP_REQUIRE_ACTIVITY", false)

## Allow the rig add_resource/set_resource commands. Default TRUE (absent/empty = allowed).
static func allow_resource_injection() -> bool:
	return flag("RIG_ALLOW_RESOURCE_INJECTION", true)

# ============================================================================
# Physics engine toggles. The RIG_* forms are HEADLESS-ONLY (the headless guard) — so a HEADED
# rig runs the player's exact physics (lookahead + MI + force) regardless of these. The SW_*
# forms apply everywhere. This guard is the reason the headed gallery run was physics-faithful.
# ============================================================================

## RIG_ flags are honored only headless, unless SW_DISABLE_HEADLESS_GUARD overrides.
static func _rig_flags_enabled() -> bool:
	return flag("SW_DISABLE_HEADLESS_GUARD", false) or is_headless()

## global SW_ flag wins outright; otherwise the RIG_ flag applies only when rig flags are enabled.
static func _resolve_flag(rig_key: String, global_key: String) -> bool:
	if flag(global_key, false):
		return true
	return _rig_flags_enabled() and flag(rig_key, false)

static func disable_lookahead() -> bool:
	return _resolve_flag("RIG_DISABLE_LOOKAHEAD", "SW_DISABLE_LOOKAHEAD")

static func disable_mi() -> bool:
	return _resolve_flag("RIG_DISABLE_MI", "SW_DISABLE_MI")

static func disable_force() -> bool:
	return _resolve_flag("RIG_DISABLE_FORCE_GRAPH", "SW_DISABLE_FORCE") \
		or _resolve_flag("RIG_DISABLE_FORCE", "SW_DISABLE_FORCE")

# ============================================================================
# Gameplay / perf overrides.
# ============================================================================

## SPACEWHEAT_ADVANCED_MODE as a tri-state; PlayerShell falls back to save-state / debug-build.
static func advanced_mode_tristate() -> int:
	return tristate("SPACEWHEAT_ADVANCED_MODE")

## Is the developer readout (FPS / PhHz / per-biome dt strip) allowed on screen?
##
## Defaults to OS.is_debug_build(), which is what a shipped player build answers:
## false. But the rig drives a DEBUG binary, so every headed capture — including
## the store-page screenshots — showed a profiler strip no player will ever see.
## One shipped screenshot went out that way. SW_DEBUG_READOUT=0 lets a capture
## look like the release it is advertising, without a second visibility rule
## living in the HUD.
static func debug_readout_enabled() -> bool:
	return flag("SW_DEBUG_READOUT", OS.is_debug_build())

## Where Core/Debug/PerfSampler.gd writes its JSON report. Empty (the default,
## and every player's build) disables sampling entirely on the first frame.
##
## This is the ONLY machine-readable perf channel a shipped build has: `🍄/**` —
## the rig listener — is excluded from every export preset, so the pack a player
## downloads cannot be asked anything by the harness. Before this, profiling an
## export meant photographing the FPS strip.
static func perf_log_path() -> String:
	return env_str("SW_PERF_LOG", "")

## Seconds of boot churn kept out of the steady-state percentiles. Sampled and
## reported separately rather than dropped — boot cost is real, it just isn't
## the number an fps floor is about.
static func perf_warmup_seconds() -> float:
	return env_float("SW_PERF_WARMUP_SECONDS", 15.0)

## Measurement window after warmup. 0 = sample until the game exits.
static func perf_duration_seconds() -> float:
	return env_float("SW_PERF_SECONDS", 0.0)

## Quit once the window closes, so an unattended run terminates itself instead of
## waiting for a window nobody is sitting at. Only applies when SW_PERF_SECONDS
## bounds the run.
static func perf_quit_when_done() -> bool:
	return flag("SW_PERF_QUIT", true)

static func perf_snapshot_interval_seconds() -> float:
	return env_float("SW_PERF_SNAPSHOT_SECONDS", 1.0)

## Lift the frame-rate ceiling PerformanceOptimizer normally applies (vsync on a
## real GPU, max_fps 60 on the OpenGL backend, max_fps 30 on a software one).
##
## Not a quality setting — a measurement one. Capped, the game answers "does the
## player get a smooth 60?"; uncapped, it answers "how much headroom is there?".
## Both are worth knowing and neither substitutes for the other, so the profiling
## kit runs both and the report says which it was.
static func uncap_frame_rate() -> bool:
	return flag("SW_UNCAP_FPS", false)

## "" | "low" | "medium"/"med" | "high" — bubble graphics quality override.
static func bubble_quality_override() -> String:
	return OS.get_environment("SW_BUBBLE_QUALITY").strip_edges().to_lower()

static func force_operator_rebuild() -> bool:
	return flag("SW_FORCE_OPERATOR_REBUILD", false)

static func skip_operator_rebuild() -> bool:
	return flag("SW_SKIP_OPERATOR_REBUILD", false)

# ============================================================================
# Semantica explorer (W3b, one-way compiler seam). OFF by default — a normal
# player boot never sees this. When on, BiomeRegistry/IconRegistry additively
# load every *.biome.json / *.icons.json under Core/Config/semantica/ (compiled
# by 🍄/🧪/semantica_compiler.py from an umwelt world spec) ON TOP OF canon,
# after the canonical biomes.json/icons.json. Canon files are never edited —
# "crafted artifacts" law — this is a second, additive load pass.
# ============================================================================

static func semantica_explorer() -> bool:
	return flag("SEMANTICA_EXPLORER", false)

# ============================================================================
# The full mode-matrix — for logging at boot and for a rig-vs-player diff/test.
# ============================================================================

static func describe() -> Dictionary:
	return {
		"headless": is_headless(),
		"touch": is_touch(),
		"skip_welcome": skip_welcome(),
		"drive_title": drive_title(),
		"debug_timeskip": debug_timeskip(),
		"time_skip_skip_lindblad": time_skip_skip_lindblad(),
		"time_skip_require_activity": time_skip_require_activity(),
		"allow_resource_injection": allow_resource_injection(),
		"disable_lookahead": disable_lookahead(),
		"disable_mi": disable_mi(),
		"disable_force": disable_force(),
		"advanced_mode_tristate": advanced_mode_tristate(),
		"debug_readout_enabled": debug_readout_enabled(),
		"perf_log_path": perf_log_path(),
		"perf_warmup_seconds": perf_warmup_seconds(),
		"perf_duration_seconds": perf_duration_seconds(),
		"uncap_frame_rate": uncap_frame_rate(),
		"bubble_quality_override": bubble_quality_override(),
		"force_operator_rebuild": force_operator_rebuild(),
		"skip_operator_rebuild": skip_operator_rebuild(),
		"semantica_explorer": semantica_explorer(),
	}
