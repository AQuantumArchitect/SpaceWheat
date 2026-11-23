class_name FeedbackTuning
extends RefCounted

## FeedbackTuning — every feel knob of the harvest loop, in one place (#60).
##
## Juice is cosmetic (anti-gating law): nothing here reads or writes ρ, the
## economy or any quest state. SFXRegistry (sound) and FloatingRewardLayer
## (sight) read these constants; the renderers expose a small `punch_register`
## that FloatingRewardLayer drives.
##
## The loop's emotional shape: planting and ripening are quiet, anticipatory
## cues; Gather (pop) is the payoff. Its size is the payout's surprisal
## (−kT·log p), so rarer outcomes land bigger with no extra thresholds.
##
## Two player settings live here too, persisted beside the audio volumes in
## user://spacewheat_settings.cfg, section [feedback]:
##   intensity       0.0–1.0  scales every flourish (sound layers, particles,
##                            squash, flash). 0 keeps only the base cue and
##                            the yield number, which is information.
##   reduced_motion  bool     no squash, hitstop, flash, particles or flying;
##                            the yield number fades in place instead.

const CONFIG_PATH := "user://spacewheat_settings.cfg"
const CONFIG_SECTION := "feedback"

# ═══════════════════════════════════════════════════════════════════════
# YIELD SIZE → rel ∈ [0, 1)
# ═══════════════════════════════════════════════════════════════════════

## rel = tanh(credits / REL_CREDITS). One soft curve, shared by sound and sight.
const REL_CREDITS := 40.0
## Rare/big payout. rel 0.75 ≈ 40 credits: a real payout, not a trickle.
const BIG_POP_REL := 0.75

# ═══════════════════════════════════════════════════════════════════════
# HARVEST (pop / Gather) SOUND
# ═══════════════════════════════════════════════════════════════════════

## Quick chains climb a pentatonic ladder (Mini-Metro trick); a gap longer
## than the combo window resets it to the root.
const COMBO_WINDOW_MS := 2000
const COMBO_SEMITONES: Array[int] = [0, 2, 4, 7, 9, 12]

## Layer 1, always: the thump.
const HARVEST_BASE_VOL := 0.85
const HARVEST_BASE_VOL_PER_REL := 0.45
## Layer 2: the sparkle, faded in by surprisal above this rel.
const HARVEST_SPARKLE_MIN_REL := 0.15
const HARVEST_SPARKLE_VOL := 0.9
## Sparkle rides the ladder a touch higher so chains brighten as they climb.
const HARVEST_SPARKLE_PITCH_PER_STEP := 0.02
## Layer 3, rare payouts only (rel ≥ BIG_POP_REL): the bell.
const HARVEST_RARE_VOL := 0.8

# ═══════════════════════════════════════════════════════════════════════
# QUIET CUES (plant, explore, ripen)
# ═══════════════════════════════════════════════════════════════════════

const PLANT_VOL := 0.6
## The planted orb is revealed a beat after inject_icon; wait for it.
const PLANT_CUE_DELAY_S := 0.15
const EXPLORE_VOL := 0.75
const RIPE_VOL := 0.55

## Ripe-plot watcher: how often FloatingRewardLayer checks the active biome's
## Berry register, and how often a still-ripe plot breathes a faint ring.
const RIPE_POLL_S := 0.25
const RIPE_PULSE_PERIOD_S := 2.4
const RIPE_COLOR := Color(0.78, 0.55, 1.0)   # PlotTile's ripe violet family
const PLANT_COLOR := Color(0.55, 0.95, 0.60)

# ═══════════════════════════════════════════════════════════════════════
# HARVEST SIGHT
# ═══════════════════════════════════════════════════════════════════════

## Orb squash-and-stretch on Gather: the renderer's dot is punched to
## (1 + s, 1 − SQUASH·s, 1 + s) and springs back on its own decay.
const PUNCH_BASE := 0.35
const PUNCH_PER_REL := 0.55
const PUNCH_SQUASH := 0.45
const PUNCH_PLANT := 0.25
const PUNCH_RIPE := 0.18

## Pop-Harvest.svg badge at the plot: stretch up, squash, settle, fade.
const BADGE_PATH := "res://Assets/UI/Science/Pop-Harvest.svg"
const BADGE_SIZE := 40.0
const BADGE_SIZE_PER_REL := 22.0
const BADGE_STRETCH_S := 0.09
const BADGE_SQUASH_S := 0.10
const BADGE_SETTLE_S := 0.16
const BADGE_FADE_S := 0.22

## Particle burst: sparks thrown radially, falling slightly, fading.
const PARTICLES_BASE := 8
const PARTICLES_PER_REL := 18
const PARTICLE_SPEED := 140.0
const PARTICLE_SPEED_PER_REL := 160.0
const PARTICLE_GRAVITY := 220.0
const PARTICLE_LIFE_S := 0.55
const PARTICLE_SIZE := 2.6

## Ring burst (pop expands, measure converges).
const RING_POP_FROM := 12.0
const RING_POP_TO := 40.0
const RING_POP_TO_PER_REL := 50.0
const RING_POP_S := 0.32
const RING_MEASURE_FROM := 34.0
const RING_MEASURE_FROM_PER_REL := 26.0
const RING_MEASURE_TO := 6.0
const RING_MEASURE_S := 0.20
const RING_QUIET_TO := 30.0
const RING_QUIET_S := 0.6

## Yield flier: "+N emoji" springs out and flies to the resource counter.
const FLIER_FONT := 20
const FLIER_FONT_PER_REL := 14
const FLIER_SPRING_S := 0.15
const FLIER_HOLD_S := 0.25
const FLIER_FLY_S := 0.5
const FLIER_INPLACE_S := 1.1   # reduced motion: fade where it appeared

## Big-moment punctuation (rare pops only).
const HITSTOP_SCALE := 0.06    # how far Engine.time_scale dips
const HITSTOP_S := 0.09        # real seconds (timer ignores time_scale)
const FLASH_PEAK := 0.14
const FLASH_PEAK_PER_REL := 0.14
const MUSIC_DUCK_DB := 7.0
const MUSIC_DUCK_HOLD_S := 0.12
const MUSIC_DUCK_RESTORE_S := 0.45

## Fractal descend/ascend: every dive, so a light touch (no hitstop).
const FRACTAL_DESCEND_COLOR := Color(0.55, 0.35, 0.95)
const FRACTAL_ASCEND_COLOR := Color(0.42, 0.95, 0.88)
const FRACTAL_FLASH_PEAK := 0.10
const FRACTAL_DUCK_DB := 3.5
const FRACTAL_DUCK_HOLD_S := 0.08
const FRACTAL_DUCK_RESTORE_S := 0.30

# ═══════════════════════════════════════════════════════════════════════
# PLAYER SETTINGS (persisted)
# ═══════════════════════════════════════════════════════════════════════

const DEFAULT_INTENSITY := 1.0
const DEFAULT_REDUCED_MOTION := false

static var _loaded := false
static var _intensity := DEFAULT_INTENSITY
static var _reduced_motion := DEFAULT_REDUCED_MOTION


static func rel_for(credits: float) -> float:
	return tanh(maxf(credits, 0.0) / REL_CREDITS)


## A Gather's size: the whole payout it banked into the wallet (every emoji in
## `banked`), else `credits`, else `amount`. Gather's result carries no
## `credits` key, so reading that alone left every pop at rel 0.
static func harvest_size(result: Dictionary) -> float:
	var banked = result.get("banked", null)
	if banked is Dictionary and not banked.is_empty():
		var total := 0.0
		for e in banked:
			total += float(banked[e])
		return total
	return float(result.get("credits", result.get("amount", 0)))


static func intensity() -> float:
	_ensure_loaded()
	return _intensity


static func reduced_motion() -> bool:
	_ensure_loaded()
	return _reduced_motion


## Scale for anything that moves: 0 under reduced motion.
static func motion() -> float:
	_ensure_loaded()
	return 0.0 if _reduced_motion else _intensity


static func set_intensity(value: float) -> void:
	_ensure_loaded()
	_intensity = clampf(value, 0.0, 1.0)
	_save()


static func set_reduced_motion(on: bool) -> void:
	_ensure_loaded()
	_reduced_motion = on
	_save()


static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		_intensity = clampf(float(config.get_value(CONFIG_SECTION, "intensity", DEFAULT_INTENSITY)), 0.0, 1.0)
		_reduced_motion = bool(config.get_value(CONFIG_SECTION, "reduced_motion", DEFAULT_REDUCED_MOTION))


static func _save() -> void:
	var config := ConfigFile.new()
	config.load(CONFIG_PATH)  # keep the audio keys and anything else
	config.set_value(CONFIG_SECTION, "intensity", _intensity)
	config.set_value(CONFIG_SECTION, "reduced_motion", _reduced_motion)
	config.save(CONFIG_PATH)
