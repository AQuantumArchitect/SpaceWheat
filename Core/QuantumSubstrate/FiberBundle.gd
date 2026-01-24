class_name FiberBundle
extends RefCounted

## Fiber Bundle: Context-Dependent Action System
##
## In differential geometry, a fiber bundle attaches additional structure
## (the "fiber") to each point of a base space. Here, we attach action
## variants to each semantic region.
##
## The "base space" is the semantic phase space (8 octants).
## The "fiber" at each point contains tool action variants.
##
## Example:
##   Tool 1 (Grower) has a "Plant" action.
##   In the PHOENIX region, it becomes "Plant Fire Wheat" (fast-growing, volatile)
##   In the SAGE region, it becomes "Plant Wisdom Wheat" (slow, high quality)
##   In the WARRIOR region, it becomes "Plant Battle Wheat" (resilient, low yield)
##
## This creates context-dependent gameplay where the same action
## produces different results based on semantic position.

const SemanticOctant = preload("res://Core/QuantumSubstrate/SemanticOctant.gd")

## Tool ID this bundle belongs to
var tool_id: int = -1

## Base actions (from ToolConfig, unchanged)
var base_actions: Dictionary = {}

## Context-specific variants: Region -> {action_key -> override_dict}
## Example:
##   context_variants[Region.PHOENIX]["Q"] = {
##       "label": "Plant Phoenix Wheat",
##       "emoji": "🔥🌾",
##       "modifier": "fire_growth"
##   }
var context_variants: Dictionary = {}

## ========================================
## Initialization
## ========================================

func _init(tid: int = -1):
	tool_id = tid


func set_base_actions(actions: Dictionary) -> void:
	"""Set the base actions from ToolConfig"""
	base_actions = actions.duplicate(true)


## ========================================
## Variant Registration
## ========================================

func add_variant(region: SemanticOctant.Region, action_key: String, override: Dictionary) -> void:
	"""Add a context-specific variant for an action

	Args:
		region: Semantic region where this variant applies
		action_key: "Q", "E", or "R" (action keybind)
		override: Dictionary with keys to override from base action
		          Common keys: label, emoji, description, modifier, effect

	Example:
		bundle.add_variant(SemanticOctant.Region.PHOENIX, "Q", {
			"label": "Plant Phoenix Wheat",
			"emoji": "🔥🌾",
			"description": "Fast-growing, fire-resistant wheat",
			"modifier": {"growth_rate": 1.5, "fire_resist": 0.8}
		})
	"""
	if not context_variants.has(region):
		context_variants[region] = {}

	context_variants[region][action_key] = override


func add_variants_for_action(action_key: String, region_overrides: Dictionary) -> void:
	"""Add variants for a single action across multiple regions

	Args:
		action_key: "Q", "E", or "R"
		region_overrides: Dictionary mapping Region -> override_dict

	Example:
		bundle.add_variants_for_action("Q", {
			SemanticOctant.Region.PHOENIX: {"label": "Phoenix Plant", "emoji": "🔥🌾"},
			SemanticOctant.Region.SAGE: {"label": "Sage Plant", "emoji": "📿🌾"},
		})
	"""
	for region in region_overrides:
		add_variant(region, action_key, region_overrides[region])


## ========================================
## Action Resolution
## ========================================

func get_action(action_key: String, current_region: SemanticOctant.Region) -> Dictionary:
	"""Get action definition for current context

	Merges base action with any context-specific overrides.
	Override values replace base values; missing keys use base.

	Args:
		action_key: "Q", "E", or "R"
		current_region: Current semantic region

	Returns:
		Merged action dictionary
	"""
	# Start with base action
	var action = base_actions.get(action_key, {}).duplicate(true)

	# Apply context override if exists
	if context_variants.has(current_region):
		var overrides = context_variants[current_region]
		if overrides.has(action_key):
			var override = overrides[action_key]
			# Merge override into action
			for key in override:
				action[key] = override[key]

	# Add context metadata
	action["_context_region"] = current_region
	action["_context_name"] = SemanticOctant.get_region_name(current_region)

	return action


func get_all_actions(current_region: SemanticOctant.Region) -> Dictionary:
	"""Get all actions for current context

	Returns:
		Dictionary: {action_key -> resolved_action}
	"""
	var result = {}
	for action_key in base_actions:
		result[action_key] = get_action(action_key, current_region)
	return result


func has_variant(action_key: String, region: SemanticOctant.Region) -> bool:
	"""Check if a specific variant exists"""
	if not context_variants.has(region):
		return false
	return context_variants[region].has(action_key)


func get_variant_regions(action_key: String) -> Array[SemanticOctant.Region]:
	"""Get all regions that have variants for this action"""
	var result: Array[SemanticOctant.Region] = []
	for region in context_variants:
		if context_variants[region].has(action_key):
			result.append(region)
	return result


## ========================================
## Bundle Presets (Factory Methods)
## ========================================

static func create_grower_bundle() -> FiberBundle:
	"""Create fiber bundle for Tool 1 (Grower) with semantic variants"""
	var FiberBundleScript = load("res://Core/QuantumSubstrate/FiberBundle.gd")
	var bundle = FiberBundleScript.new(1)

	# Base action (used when no variant applies)
	bundle.base_actions = {
		"Q": {
			"action": "plant",
			"label": "Plant",
			"emoji": "🌾",
			"description": "Plant wheat in selected plots"
		},
		"E": {
			"action": "harvest",
			"label": "Harvest",
			"emoji": "🌾➡️📦",
			"description": "Harvest mature crops"
		},
		"R": {
			"action": "clear",
			"label": "Clear",
			"emoji": "🗑️",
			"description": "Clear dead or unwanted crops"
		}
	}

	# PHOENIX: Fire-enhanced crops
	bundle.add_variant(SemanticOctant.Region.PHOENIX, "Q", {
		"label": "Plant Phoenix Wheat",
		"emoji": "🔥🌾",
		"description": "Fast-growing, fire-resistant wheat. Higher yield, shorter lifespan.",
		"modifier": {"growth_rate": 1.5, "lifespan": 0.7, "fire_resist": 0.9}
	})

	# SAGE: Wisdom crops
	bundle.add_variant(SemanticOctant.Region.SAGE, "Q", {
		"label": "Plant Sage Wheat",
		"emoji": "📿🌾",
		"description": "Slow-growing, high-quality spiritual wheat. Preserves coherence.",
		"modifier": {"growth_rate": 0.6, "quality": 1.5, "coherence_preserve": 0.8}
	})

	# WARRIOR: Battle crops
	bundle.add_variant(SemanticOctant.Region.WARRIOR, "Q", {
		"label": "Plant Battle Wheat",
		"emoji": "⚔️🌾",
		"description": "Hardy wheat that survives harsh conditions. Lower yield.",
		"modifier": {"growth_rate": 0.9, "resilience": 1.5, "yield": 0.8}
	})

	# MERCHANT: Trade crops
	bundle.add_variant(SemanticOctant.Region.MERCHANT, "Q", {
		"label": "Plant Trade Wheat",
		"emoji": "💰🌾",
		"description": "High-value wheat optimized for market. Standard growth.",
		"modifier": {"growth_rate": 1.0, "value": 1.5, "trade_bonus": 0.2}
	})

	# GARDENER: Harmonious crops
	bundle.add_variant(SemanticOctant.Region.GARDENER, "Q", {
		"label": "Plant Garden Wheat",
		"emoji": "🌱🌾",
		"description": "Balanced wheat that harmonizes with ecosystem. Boosts neighbors.",
		"modifier": {"growth_rate": 1.2, "neighbor_bonus": 0.15, "harmony": 1.3}
	})

	# INNOVATOR: Experimental crops
	bundle.add_variant(SemanticOctant.Region.INNOVATOR, "Q", {
		"label": "Plant Quantum Wheat",
		"emoji": "💡🌾",
		"description": "Experimental wheat with unpredictable mutations. High variance.",
		"modifier": {"growth_rate": 1.1, "mutation_chance": 0.3, "variance": 2.0}
	})

	# GUARDIAN: Defensive crops
	bundle.add_variant(SemanticOctant.Region.GUARDIAN, "Q", {
		"label": "Plant Shield Wheat",
		"emoji": "🛡️🌾",
		"description": "Protective wheat that shields neighbors. Slow but steady.",
		"modifier": {"growth_rate": 0.8, "protection": 0.3, "stability": 1.4}
	})

	# ASCETIC: Minimal crops
	bundle.add_variant(SemanticOctant.Region.ASCETIC, "Q", {
		"label": "Plant Essence Wheat",
		"emoji": "🧘🌾",
		"description": "Minimal wheat requiring few resources. Pure but sparse.",
		"modifier": {"growth_rate": 0.5, "resource_cost": 0.5, "purity": 1.5}
	})

	return bundle


static func create_quantum_bundle() -> FiberBundle:
	"""Create fiber bundle for Tool 2 (Quantum) with semantic variants"""
	var FiberBundleScript = load("res://Core/QuantumSubstrate/FiberBundle.gd")
	var bundle = FiberBundleScript.new(2)

	bundle.base_actions = {
		"Q": {
			"action": "entangle",
			"label": "Entangle",
			"emoji": "🔗",
			"description": "Create quantum entanglement between plots"
		},
		"E": {
			"action": "measure",
			"label": "Measure",
			"emoji": "📏",
			"description": "Collapse quantum state via measurement"
		},
		"R": {
			"action": "superpose",
			"label": "Superpose",
			"emoji": "🌀",
			"description": "Put plot into superposition state"
		}
	}

	# PHOENIX: Energetic entanglement
	bundle.add_variant(SemanticOctant.Region.PHOENIX, "Q", {
		"label": "Fire Link",
		"emoji": "🔥🔗",
		"description": "High-energy entanglement. Faster correlation, faster decay.",
		"modifier": {"entangle_strength": 1.5, "decay_rate": 1.3}
	})

	# SAGE: Stable entanglement
	bundle.add_variant(SemanticOctant.Region.SAGE, "Q", {
		"label": "Wisdom Bond",
		"emoji": "📿🔗",
		"description": "Stable, long-lasting entanglement. Slow to form, slow to break.",
		"modifier": {"entangle_strength": 1.0, "decay_rate": 0.5, "formation_time": 1.5}
	})

	# INNOVATOR: Chaotic entanglement
	bundle.add_variant(SemanticOctant.Region.INNOVATOR, "Q", {
		"label": "Chaos Link",
		"emoji": "💡🔗",
		"description": "Unpredictable entanglement. May create multi-party correlations.",
		"modifier": {"entangle_strength": 1.2, "multi_party_chance": 0.3}
	})

	return bundle


static func create_biome_bundle() -> FiberBundle:
	"""Create fiber bundle for Tool 4 (Biome Control) with semantic variants"""
	var FiberBundleScript = load("res://Core/QuantumSubstrate/FiberBundle.gd")
	var bundle = FiberBundleScript.new(4)

	bundle.base_actions = {
		# NOTE: energy_tap ("Q") removed (2026-01) - system deprecated
		"E": {
			"action": "inspect",
			"label": "Inspect",
			"emoji": "🔍",
			"description": "View biome quantum state details"
		},
		"R": {
			"action": "reset",
			"label": "Reset",
			"emoji": "🔄",
			"description": "Reset biome to initial state"
		}
	}

	# NOTE: Energy tap variants for "Q" removed (2026-01) - system deprecated

	return bundle


## ========================================
## Debug & Inspection
## ========================================

func get_variant_summary() -> String:
	"""Get summary of all variants in this bundle"""
	var s = "FiberBundle (Tool %d)\n" % tool_id
	s += "Base actions: %s\n" % str(base_actions.keys())
	s += "Variants:\n"

	for region in context_variants:
		var region_name = SemanticOctant.get_region_name(region)
		var actions = context_variants[region].keys()
		s += "  %s: %s\n" % [region_name, str(actions)]

	return s
