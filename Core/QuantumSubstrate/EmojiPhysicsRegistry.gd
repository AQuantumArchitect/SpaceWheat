extends Node

## EmojiPhysicsRegistry — singleton of per-emoji physics atoms.
##
## Autoloaded at /root/EmojiPhysicsRegistry. Each entry is an Icon resource
## (see Core/QuantumSubstrate/Icon.gd) carrying per-emoji self-energy,
## hamiltonian couplings, and Lindblad terms — the additive union of every
## faction that speaks that emoji. These are "atoms" in the physics sense:
## the fundamental single-emoji building blocks of a biome Hamiltonian.
##
## NOT to be confused with IconLexicon (Core/Factions/IconLexicon.gd), which
## is the registry of named pair-Icons (two-emoji qubit axes). This registry
## is about single-emoji atom physics; IconLexicon is about hand-crafted axes.

const FactionRegistry = preload("res://Core/Factions/FactionRegistry.gd")
const AtomBuilder = preload("res://Core/Factions/AtomBuilder.gd")
const IconScript = preload("res://Core/QuantumSubstrate/Icon.gd")
const VerboseHelper = preload("res://Core/Config/VerboseHelper.gd")

## Dictionary mapping emoji → Icon (per-emoji atom physics object)
var atoms: Dictionary = {}

func _ready():
	VerboseHelper.info("boot", "icons", "EmojiPhysicsRegistry initializing")
	_load_builtin_atoms()
	VerboseHelper.info("boot", "icons", "EmojiPhysicsRegistry ready: %d icons registered" % atoms.size())

## Register a per-emoji atom
func register_atom(atom) -> void:
	if atom == null or atom.emoji == "":
		push_error("EmojiPhysicsRegistry: Attempted to register null or empty atom")
		return

	if atoms.has(atom.emoji):
		push_warning("EmojiPhysicsRegistry: Overwriting existing atom for %s" % atom.emoji)

	atoms[atom.emoji] = atom

## Get the atom for a given emoji
func get_atom(emoji: String):
	return atoms.get(emoji, null)

## Check if an atom exists for this emoji
func has_atom(emoji: String) -> bool:
	return atoms.has(emoji)

## Get all registered emojis
func get_all_emojis() -> Array:
	var result: Array = []
	for emoji in atoms.keys():
		result.append(emoji)
	return result

## Get all atoms (for building bath operators)
func get_all_atoms() -> Array:
	var result: Array = []
	for atom in atoms.values():
		result.append(atom)
	return result

## Get atoms by tag
func get_atoms_by_tag(tag: String) -> Array:
	var result: Array = []
	for atom_variant in atoms.values():
		var atom = atom_variant as IconScript
		if atom and tag in atom.tags:
			result.append(atom)
	return result

## Get atoms by trophic level
func get_atoms_by_trophic_level(level: int) -> Array:
	var result: Array = []
	for atom_variant in atoms.values():
		var atom = atom_variant as IconScript
		if atom and atom.trophic_level == level:
			result.append(atom)
	return result

## Build atoms from Factions
func _load_builtin_atoms() -> void:
	var registry = FactionRegistry.new()
	var all_factions = registry.get_all()
	var built_atoms = AtomBuilder.build_atoms_for_factions(all_factions)

	for atom in built_atoms:
		register_atom(atom)

	VerboseHelper.info("boot", "icons", "Built %d icons from %d factions (JSON)" % [built_atoms.size(), all_factions.size()])

## Derive atoms from a Markov chain
## Useful for bootstrapping biome atoms from transition probabilities
func derive_from_markov(markov: Dictionary, h_scale: float = 0.5, l_scale: float = 0.3) -> void:
	VerboseHelper.info("quantum", "icons", "Deriving atoms from Markov chain")

	for source in markov:
		if has_atom(source):
			continue

		var atom = IconScript.new()
		atom.emoji = source
		atom.display_name = "Markov: " + source

		var transitions = markov[source]

		for target in transitions:
			var prob = transitions[target]

			var reverse = 0.0
			if markov.has(target) and markov[target].has(source):
				reverse = markov[target][source]

			var symmetric = (prob + reverse) / 2.0
			if symmetric > 0.05:
				atom.hamiltonian_couplings[target] = symmetric * h_scale

			var asymmetric = prob - symmetric
			if asymmetric > 0.02:
				atom.lindblad_outgoing[target] = asymmetric * l_scale

		register_atom(atom)

	VerboseHelper.info("quantum", "icons", "Derived %d atoms from Markov" % markov.size())

## Debug: Print all registered atoms
func debug_print_all() -> void:
	print("\n=== EmojiPhysicsRegistry: %d atoms ===" % atoms.size())
	for emoji in atoms.keys():
		var atom = atoms[emoji]
		print("  %s - %s" % [emoji, atom.display_name])
		if not atom.hamiltonian_couplings.is_empty():
			print("    H couplings: %s" % str(atom.hamiltonian_couplings.keys()))
		if not atom.lindblad_outgoing.is_empty():
			print("    L outgoing: %s" % str(atom.lindblad_outgoing.keys()))
	print("===========================\n")
