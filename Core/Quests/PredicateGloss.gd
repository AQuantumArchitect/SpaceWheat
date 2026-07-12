extends RefCounted

## ONE home for the player-facing one-line gloss of a quest/flag predicate.
## Used by QuestBoard (C) and the Arc tab (ControlsOverlay X→I) — these were
## two hand-maintained copies that drifted every time a predicate type landed
## (merged 2026-07-06). Pass the QuestManager so numeric targets show the REAL
## fire threshold (predicate_fire_target inverts the soft-gate); without it,
## raw authored values are shown.


static func summary(pred: Dictionary, qm = null) -> String:
	var t := str(pred.get("type", "?"))
	var tgt: float = float(pred.get("value", 0.0))
	if qm and qm.has_method("predicate_fire_target"):
		tgt = qm.predicate_fire_target(pred)
	var itgt: int = int(ceil(tgt))
	match t:
		"signature_size_gte":
			return "know %d icons — Icon hat (5) incorporates them" % itgt
		"berry_consumed_count_gte":
			# Nine fleet testers stalled on "berries[X] ≥ 3" — the gloss must teach
			# the loop, not just name the count. Live N/M: the ladder is cumulative,
			# and every incorporation must visibly move the number.
			var b := str(pred.get("biome", ""))
			var have := int(qm.berry_consumed_in(b)) if (qm and qm.has_method("berry_consumed_in")) else -1
			var count_str := ("%d/%d" % [have, itgt]) if have >= 0 else str(itgt)
			return "berries %s in %s — Icon hat (5): F tracks, ripens, R incorporates" % [count_str, b]
		"berry_total_phase_gte":
			return "phase[%s] ≥ %.2f" % [str(pred.get("biome", "")), tgt]
		"standing_gte":
			return "standing %s.%s ≥ %.2f" % [str(pred.get("faction", "")), str(pred.get("channel", "trust")), tgt]
		"biome_state_gte":
			return "%s.%s ≥ %.2f" % [str(pred.get("biome", "")), str(pred.get("atom", "")), tgt]
		"biome_state_lte":
			return "%s.%s ≤ %.2f" % [str(pred.get("biome", "")), str(pred.get("atom", "")), tgt]
		"soul_purity_gte":
			return "you · Tr(ρ²) ≥ %.2f" % tgt
		"biome_evolving":
			return "%s evolving" % str(pred.get("biome", ""))
		"story_flag_set":
			# Speak the beat's display name, not the internal id ("flag
			# 'village_identity' set" read as a dead end to playtesters).
			var fid := str(pred.get("id", ""))
			var disp := fid
			if qm and qm.has_method("flag_display_name"):
				disp = str(qm.flag_display_name(fid))
			return "after the beat '%s'" % disp
		"signature_growth_gte":
			return "learn %d new icon%s — Icon hat (5): F tracks, R incorporates" % [maxi(1, itgt), "s" if itgt > 1 else ""]
		"atom_count_gte":
			return "%s atoms ≥ %d" % [str(pred.get("biome", "")), itgt]
		"atom_diversity_gte":
			return "atom diversity ≥ %d" % itgt
		"atom_in_biome":
			return "%s ∋ %s" % [str(pred.get("biome", "")), str(pred.get("atom", ""))]
		"biome_attractor_emoji_gte":
			return "%s attractor[%s] ≥ %.2f" % [str(pred.get("biome", "")), str(pred.get("emoji", "")), tgt]
		"biome_eigenvalue_gap_gte":
			return "%s gap ≥ %.2f" % [str(pred.get("biome", "")), tgt]
		"biome_spectral_gap_gte":
			return "%s stable (gap ≥ %.2f)" % [str(pred.get("biome", "")), tgt]
		"biome_spectral_gap_lte":
			return "%s chaotic (gap ≤ %.2f)" % [str(pred.get("biome", "")), tgt]
		"biome_energy_variance_gte":
			return "%s restless ≥ %.2f" % [str(pred.get("biome", "")), tgt]
		"biome_energy_variance_lte":
			return "%s settled ≤ %.2f" % [str(pred.get("biome", "")), tgt]
		"biome_purity_trending":
			return "%s purity↑" % str(pred.get("biome", ""))
		"coherence_at_least":
			return "coherence ≥ %.2f" % float(pred.get("value", 0.0))
		"purity_at_least":
			return "purity ≥ %.2f" % float(pred.get("value", 0.0))
		"entropy_at_most":
			return "entropy ≤ %.2f" % float(pred.get("value", 1.0))
		"mutual_information_at_least":
			return "entanglement (MI) ≥ %.2f" % float(pred.get("value", 0.5))
		"gate_sequence_contains":
			return "%s ×%d" % [str(pred.get("gate", "?")), int(pred.get("count", 1))]
		"gate_order":
			# The braid word, spelled as the player will drill it: "H → CNOT".
			var word: Array = pred.get("gates", [])
			var pretty: Array[String] = []
			for g in word:
				pretty.append(gate_glyph(str(g)))
			return "in order: %s" % " → ".join(pretty)
		"dynamics_at_most":
			return "stillness — motion ≤ %.2f" % float(pred.get("value", 0.2))
		"dynamics_at_least":
			return "breathing — motion ≥ %.2f" % float(pred.get("value", 0.25))
		"purity_at_most":
			return "let it gray — Tr(ρ²) ≤ %.2f" % float(pred.get("value", 1.0))
		"coherence_fell":
			return "watch it fade — coherence %.2f → ≤ %.2f" % [float(pred.get("from", 0.3)), float(pred.get("to", 0.15))]
		"attractor_emoji_gte":
			return "deep state[%s] ≥ %.2f" % [str(pred.get("emoji", "")), float(pred.get("value", 0.5))]
		"eigenvalue_gap_gte":
			return "compass gap ≥ %.2f" % float(pred.get("value", 0.1))
		"frozen_loops_gte":
			return "close %d berry loop%s" % [int(pred.get("count", 1)), "s" if int(pred.get("count", 1)) != 1 else ""]
		"loops_linked":
			return "🪢 link two loops — winding ≥ %d" % int(pred.get("value", 1))
		"winding_gte":
			return "🪢 mutual winding ≥ %d" % int(pred.get("value", 1))
		"biome_frozen_loops_gte":
			return "bank %d loop%s in %s" % [int(pred.get("count", 1)), "s" if int(pred.get("count", 1)) != 1 else "", str(pred.get("biome", "?"))]
		"biome_loops_linked":
			return "🪢 link loops in %s — winding ≥ %d" % [str(pred.get("biome", "?")), int(pred.get("value", 1))]
		"bridge_built_gte":
			return "🌉 raise %d span%s" % [int(pred.get("value", 1)), "s" if int(pred.get("value", 1)) != 1 else ""]
		"bridge_braids_gte":
			return "🪢 braid the span ×%d" % int(pred.get("value", 1))
		"bridge_fused_gte":
			return "⚛ fuse %d bridge%s" % [int(pred.get("value", 1)), "s" if int(pred.get("value", 1)) != 1 else ""]
		_:
			return t


## Short display glyph for a gate dispatch name ("hadamard" → "H").
static func gate_glyph(gate_name: String) -> String:
	match gate_name.strip_edges().to_lower():
		"hadamard": return "H"
		"cnot": return "CNOT"
		"cz": return "CZ"
		"swap": return "SWAP"
		"bell": return "Bell"
		"ghz": return "GHZ"
		"cluster": return "Cluster"
		"pauli_x": return "X"
		"pauli_y": return "Y"
		"pauli_z": return "Z"
		"s_gate": return "S"
		"t_gate": return "T"
		"sdg": return "S†"
		"tdg": return "T†"
		"rx": return "Rx"
		"ry": return "Ry"
		"rz": return "Rz"
		_: return gate_name.to_upper()
