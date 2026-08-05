extends "res://tests/smoke_test_base.gd"

## Pin the gloss↔target coupling in PredicateGloss: the prose summary() speaks
## and the machine key target() returns live in ONE table, and this smoke is
## the compiler for that claim — for every hat/gate-kind TARGETS entry, the
## summary prose must name the digit target() resolves; menu kinds must name
## their surface letter. A prose edit that drops the key, or a TARGETS entry
## pointing at a frame the prose doesn't teach, fails here instead of shipping
## a spotlight that pulses one key while the text says another.
##
## Run: godot --headless --path . --script tests/predicate_target_smoke.gd

const PredicateGloss := preload("res://Core/Quests/PredicateGloss.gd")

## One representative predicate per TARGETS type (authored field shapes).
const SAMPLES := {
	"berry_consumed_count_gte": {"type": "berry_consumed_count_gte", "biome": "Village", "value": 3},
	"berry_total_phase_gte":    {"type": "berry_total_phase_gte", "biome": "Village", "value": 12.5},
	"signature_size_gte":       {"type": "signature_size_gte", "value": 3},
	"signature_growth_gte":     {"type": "signature_growth_gte", "value": 1},
	"atom_count_gte":           {"type": "atom_count_gte", "biome": "Village", "value": 12},
	"atom_in_biome":            {"type": "atom_in_biome", "biome": "Village", "atom": "💧"},
	"atom_diversity_gte":       {"type": "atom_diversity_gte", "value": 18},
	"frozen_loops_gte":         {"type": "frozen_loops_gte", "count": 1},
	"biome_frozen_loops_gte":   {"type": "biome_frozen_loops_gte", "biome": "Village", "count": 2},
	"standing_gte":             {"type": "standing_gte", "faction": "Hearth Keepers", "channel": "trust", "value": 0.15},
	"biome_spectral_gap_gte":   {"type": "biome_spectral_gap_gte", "biome": "BloodLedger", "value": 0.6},
	"biome_spectral_gap_lte":   {"type": "biome_spectral_gap_lte", "biome": "Village", "value": 0.55},
	"gate_sequence_contains":   {"type": "gate_sequence_contains", "gate": "hadamard", "count": 3},
	"biome_evolving":           {"type": "biome_evolving", "biome": "BloodLedger"},
}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== Predicate gloss↔target coupling smoke ===")

	_check(SAMPLES.keys().size() == PredicateGloss.TARGETS.keys().size()
			and SAMPLES.keys().all(func(k): return PredicateGloss.TARGETS.has(k)),
			"every TARGETS type has a sample here (extend SAMPLES with the table)")

	for t in PredicateGloss.TARGETS:
		var pred: Dictionary = SAMPLES.get(t, {})
		var spec: Dictionary = PredicateGloss.TARGETS[t]
		var kind := str(spec.get("kind", ""))
		var tgt := PredicateGloss.target(pred)
		var prose := PredicateGloss.summary(pred, null)
		match kind:
			"hat", "gate":
				var key := str(tgt.get("key", ""))
				_check(key != "", "%s resolves a hat digit" % t, str(tgt))
				_check(prose.contains("(%s)" % key),
						"%s prose names its digit (%s)" % [t, key], "prose: %s" % prose)
			"menu":
				var mkey := str(tgt.get("key", ""))
				_check(mkey != "", "%s resolves a surface key" % t)
				_check(prose.contains(mkey),
						"%s prose names its surface (%s)" % [t, mkey], "prose: %s" % prose)
			"biome":
				_check(str(tgt.get("key", "")) == "" and str(tgt.get("biome", "")) != "",
						"%s carries the biome with no key (honest focus-only target)" % t, str(tgt))

	# Structured passthrough: the fork's gate carries its biome AND atom.
	var fork := PredicateGloss.target(SAMPLES["atom_in_biome"])
	_check(fork.get("biome", "") == "Village" and fork.get("atom", "") == "💧",
			"atom_in_biome target carries biome + atom", str(fork))

	# Entangling gates route to the Operator hat, not Druid.
	var cnot := PredicateGloss.target({"type": "gate_sequence_contains", "gate": "cnot", "count": 1})
	var druid := PredicateGloss.target(SAMPLES["gate_sequence_contains"])
	_check(cnot.get("key", "") != druid.get("key", ""),
			"cnot and hadamard resolve different hats", "%s vs %s" % [cnot, druid])

	# No-table types stay honestly dark.
	_check(PredicateGloss.target({"type": "story_flag_set", "id": "x"}).is_empty(),
			"types outside TARGETS return {} (no guessing)")

	_finish("predicate target smoke")
