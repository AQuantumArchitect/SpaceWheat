extends RefCounted

## ONE home for the player-facing one-line gloss of a quest/flag predicate.
## Used by QuestBoard (C) and the Arc tab (ControlsOverlay X→I) — these were
## two hand-maintained copies that drifted every time a predicate type landed
## (merged 2026-07-06). Pass the QuestManager so numeric targets show the REAL
## fire threshold (predicate_fire_target inverts the soft-gate); without it,
## raw authored values are shown.
##
## TARGETS (below) is the MACHINE side of the same knowledge: per predicate
## type, which surface/hat advances it. summary()'s prose and target()'s key
## live in one file so they cannot drift — an anti-drift smoke asserts every
## hat-kind prose names the digit target() returns.


# Explicit preload, not the bare class_name identifier — bare autoload/class
# identifiers are compile bombs under --check-only harnesses (same law as the
# GameStateManager lookups elsewhere).
const ToolConfig = preload("res://Core/GameState/ToolConfig.gd")


## Per-predicate-type structured target: which literal key advances this
## predicate. kind "hat" resolves a ToolConfig frame to its digit; "menu" is
## a ZXCVBNM surface key; "gate" picks druid/operator from the gate name;
## "biome" has no key of its own (the work IS being in that biome). Types
## absent here have no honest single target — the spotlight stays dark for
## them rather than guessing (same law as the tutorial table).
const TARGETS := {
	"berry_consumed_count_gte": {"kind": "hat", "frame": "icon"},
	"berry_total_phase_gte":    {"kind": "hat", "frame": "icon"},
	"signature_size_gte":       {"kind": "hat", "frame": "icon"},
	"signature_growth_gte":     {"kind": "hat", "frame": "icon"},
	"atom_count_gte":           {"kind": "hat", "frame": "icon"},
	"atom_in_biome":            {"kind": "hat", "frame": "icon"},
	"atom_diversity_gte":       {"kind": "hat", "frame": "icon"},
	"frozen_loops_gte":         {"kind": "hat", "frame": "icon"},
	"biome_frozen_loops_gte":   {"kind": "hat", "frame": "icon"},
	"standing_gte":             {"kind": "menu", "key": "C"},
	"biome_spectral_gap_gte":   {"kind": "menu", "key": "B"},
	"biome_spectral_gap_lte":   {"kind": "menu", "key": "B"},
	"gate_sequence_contains":   {"kind": "gate"},
	"biome_evolving":           {"kind": "biome"},
	"active_biome_is":          {"kind": "biome"},
	# What Turns (gauge/holonomy): compass verbs live on Operator, the mirror
	# and the loop-walking on Icon.
	"biome_betti_gte":          {"kind": "hat", "frame": "icon"},
	"biome_loop_closed_upstairs": {"kind": "hat", "frame": "icon"},
	"biome_linking_valid":      {"kind": "hat", "frame": "icon"},
	"wilson_survived_flip":     {"kind": "hat", "frame": "operator"},
	"spinor_read":              {"kind": "hat", "frame": "icon"},
	"winding_changed_uncut":    {"kind": "hat", "frame": "icon"},
	"soul_purity_gte":          {"kind": "hat", "frame": "icon"},
}

## Gate dispatch name → the hat that fires it (single-qubit rotations are
## Druid's; entangling gates are Operator's).
const GATE_FRAMES := {
	"hadamard": "druid", "rx": "druid", "ry": "druid", "rz": "druid",
	"pauli_x": "druid", "pauli_y": "druid", "pauli_z": "druid",
	"s_gate": "druid", "t_gate": "druid", "sdg": "druid", "tdg": "druid",
	"cnot": "operator", "cz": "operator", "swap": "operator",
	"bell": "operator", "ghz": "operator", "cluster": "operator",
	"gauge_flip": "operator", "wilson_inspect": "operator",
	"gauge_fix": "operator", "gauge_scramble": "operator",
	"mark_reference": "icon", "interfere": "icon",
}


## Structured target for a predicate: {"key": String, "biome": String,
## "atom": String}, or {} when this type has no honest single target.
static func target(pred: Dictionary) -> Dictionary:
	var t := str(pred.get("type", ""))
	if not TARGETS.has(t):
		return {}
	var spec: Dictionary = TARGETS[t]
	var biome := str(pred.get("biome", ""))
	var atom := str(pred.get("atom", pred.get("emoji", "")))
	match str(spec.get("kind", "")):
		"hat":
			var hk := hat_key_for_frame(str(spec.get("frame", "")))
			return {} if hk == "" else {"key": hk, "biome": biome, "atom": atom}
		"menu":
			return {"key": str(spec.get("key", "")), "biome": biome, "atom": atom}
		"gate":
			var frame := str(GATE_FRAMES.get(str(pred.get("gate", "")).strip_edges().to_lower(), ""))
			if frame == "":
				return {}
			var ghk := hat_key_for_frame(frame)
			return {} if ghk == "" else {"key": ghk, "biome": biome, "atom": atom}
		"biome":
			return {} if biome == "" else {"key": "", "biome": biome, "atom": atom}
	return {}


## "Icon hat (5)" — the prose name summary() interpolates, derived from the
## SAME frame resolution target() uses so the two can't disagree.
static func verb_home(frame: String) -> String:
	var digit := hat_key_for_frame(frame)
	var word := frame.capitalize()
	return "%s hat (%s)" % [word, digit] if digit != "" else "%s hat" % word


static func hat_key_for_frame(frame: String) -> String:
	for hat_key in ToolConfig.HAT_KEY_TO_FRAME:
		if str(ToolConfig.HAT_KEY_TO_FRAME[hat_key]) == frame:
			return str(hat_key)
	return ""


static func summary(pred: Dictionary, qm = null) -> String:
	var t := str(pred.get("type", "?"))
	var tgt: float = float(pred.get("value", 0.0))
	if qm and qm.has_method("predicate_fire_target"):
		tgt = qm.predicate_fire_target(pred)
	var itgt: int = int(ceil(tgt))
	match t:
		"signature_size_gte":
			# Live N/M — the soft-gate bar is a sigmoid, so near the target it
			# reads single-digit percent while the count is nearly there (hub
			# leg L4a walled reading 9% as "1-2 of 15" when it held 12).
			var sig_have := int(qm.signature_size_now()) if (qm and qm.has_method("signature_size_now")) else -1
			var sig_str := ("%d/%d" % [sig_have, itgt]) if sig_have >= 0 else str(itgt)
			return "know %s icons — claim teachings (Arc X→I, then C→U); Icon hat (5) R incorporates" % sig_str
		"berry_consumed_count_gte":
			# Nine fleet testers stalled on "berries[X] ≥ 3" — the gloss must teach
			# the loop, not just name the count. Live N/M: the ladder is cumulative,
			# and every incorporation must visibly move the number.
			var b := str(pred.get("biome", ""))
			var have := int(qm.berry_consumed_in(b)) if (qm and qm.has_method("berry_consumed_in")) else -1
			var count_str := ("%d/%d" % [have, itgt]) if have >= 0 else str(itgt)
			# "F again STOPS" is load-bearing: F is a toggle, and runners who
			# poll ripeness with F destroy their own loop (fleet #4, hub L4f —
			# two fleets lost to the same reflex despite the stop-toast).
			return "berries %s in %s — Icon hat (5): F tracks (F again STOPS the loop), time ripens, R incorporates" % [count_str, b]
		"berry_total_phase_gte":
			return "phase[%s] ≥ %.2f — %s: F tracks, wide orbits build phase" % [str(pred.get("biome", "")), tgt, verb_home("icon")]
		"standing_gte":
			# Live have/target — a standing gate without the current value reads
			# as an unpayable toll (the access-0.2 wall cost the fleet ~5 legs).
			# Completed contracts move it; the player must SEE it move.
			var sg_faction := str(pred.get("faction", ""))
			var sg_channel := str(pred.get("channel", "trust"))
			var have_str := ""
			if qm and qm.has_method("standing_channel_now"):
				have_str = "%.2f/" % qm.standing_channel_now(sg_faction, sg_channel)
			return "standing %s.%s %s%.2f — their contracts (C board) raise it" % [sg_faction, sg_channel, have_str, tgt]
		"biome_state_gte":
			return "%s.%s ≥ %.2f" % [str(pred.get("biome", "")), str(pred.get("atom", "")), tgt]
		"biome_state_lte":
			return "%s.%s ≤ %.2f" % [str(pred.get("biome", "")), str(pred.get("atom", "")), tgt]
		"soul_purity_gte":
			# The campaign's ONE meta-state gate. Banner-first sentence must fit
			# OBJECTIVE_MAX_CHARS (70) and name the hat digit in (N) form so
			# predicate_target_smoke can pin the spotlight. The lever is real —
			# Farm._pump_for_icon pumps the owning faction on each incorporation;
			# τ=300s decay pulls it back.
			var sp_have := ""
			if qm and qm.has_method("soul_purity_now"):
				sp_have = "%.2f/" % qm.soul_purity_now()
			return "you · Tr(ρ²) %s%.2f — Icon (5): F track, R take. Fades ~5 min." % [sp_have, tgt]
		"biome_evolving":
			# A biome you haven't found yet reads as an impossible ask (marathon
			# #4: "requires BloodLedger to be active" with no verb) — teach
			# discovery when it isn't loaded.
			var evb := str(pred.get("biome", ""))
			var loaded := bool(qm.atom_count_in(evb) > 0) if (qm and qm.has_method("atom_count_in")) else true
			if loaded:
				return "%s evolving" % evb
			return "%s awake — discover it first (Captain 7: R), then work its plots" % evb
		"active_biome_is":
			# The wayfinding gate: arrival is the whole ask. The objective banner's
			# travel line already names the literal tab key while you're elsewhere;
			# this gloss names the row so the two never disagree on the verb.
			return "stand in %s — the biome tabs (T Y U row, or tap one) carry you there" % str(pred.get("biome", "?"))
		"story_flag_set":
			# Speak the beat's display name, not the internal id ("flag
			# 'village_identity' set" read as a dead end to playtesters).
			var fid := str(pred.get("id", ""))
			var disp := fid
			if qm and qm.has_method("flag_display_name"):
				disp = str(qm.flag_display_name(fid))
			return "after the beat '%s'" % disp
		"story_flag_any":
			# The branch-choice predicate: ANY one of the named beats satisfies
			# it — spell the alternatives so the choice reads as a choice.
			var names: Array[String] = []
			for aid in pred.get("ids", []):
				var adisp := str(aid)
				if qm and qm.has_method("flag_display_name"):
					adisp = str(qm.flag_display_name(str(aid)))
				names.append("'%s'" % adisp)
			return "choose one door — any of: %s" % ", ".join(names)
		"signature_growth_gte":
			return "learn %d new icon%s — Icon hat (5): F tracks, R incorporates" % [maxi(1, itgt), "s" if itgt > 1 else ""]
		"atom_count_gte":
			# The act-4/5 buildout gate — teach the verb (marathon #3: five legs
			# never planted an icon because nothing said to).
			var acb := str(pred.get("biome", ""))
			var ac_have := int(qm.atom_count_in(acb)) if (qm and qm.has_method("atom_count_in")) else -1
			var ac_str := ("%d/%d" % [ac_have, itgt]) if ac_have >= 0 else str(itgt)
			return "settle %s atoms in %s — Icon hat (5): R on an EMPTY plot plants a word you know" % [ac_str, acb]
		"atom_diversity_gte":
			var ad_have := int(qm.atom_diversity_now()) if (qm and qm.has_method("atom_diversity_now")) else -1
			var ad_str := ("%d/%d" % [ad_have, itgt]) if ad_have >= 0 else str(itgt)
			return "%s kinds of atom across your lands — plant new icons (%s: R on an EMPTY plot); discover biomes (%s: R)" % [ad_str, verb_home("icon"), verb_home("captain")]
		"atom_in_biome":
			# The Act-5 fork's actual gate — for months this glossed as bare set
			# notation ("Village ∋ 💧") with no verb, leaving the game's one
			# real narrative choice undiscoverable. Teach the plant verb AND
			# the full-ring escape hatch (Village runs zero-slack).
			return "seat %s in %s — %s: R on an EMPTY plot plants it; ring full? Q unseats one first" % [
					str(pred.get("atom", "")), str(pred.get("biome", "")), verb_home("icon")]
		"biome_attractor_emoji_gte":
			return "%s attractor[%s] ≥ %.2f" % [str(pred.get("biome", "")), str(pred.get("emoji", "")), tgt]
		"biome_eigenvalue_gap_gte":
			return "%s gap ≥ %.2f" % [str(pred.get("biome", "")), tgt]
		"biome_spectral_gap_gte":
			# Live now→target, same shape as atom_count_gte's N/M — the gap
			# gates the ENDING and read as a black box with no current value.
			var gg_biome := str(pred.get("biome", ""))
			var gg_now: float = qm.spectral_gap_in(gg_biome) if (qm and qm.has_method("spectral_gap_in")) else -1.0
			var gg_live := ("gap %.2f → need ≥ %.2f" % [gg_now, tgt]) if gg_now >= 0.0 else ("gap ≥ %.2f" % tgt)
			return "%s rigid: %s — the microscope (B) reads it" % [gg_biome, gg_live]
		"biome_spectral_gap_lte":
			var gl_biome := str(pred.get("biome", ""))
			var gl_now: float = qm.spectral_gap_in(gl_biome) if (qm and qm.has_method("spectral_gap_in")) else -1.0
			var gl_live := ("gap %.2f → need ≤ %.2f" % [gl_now, tgt]) if gl_now >= 0.0 else ("gap ≤ %.2f" % tgt)
			return "%s plural: %s — unseat a heavy word (%s Q), seat a stranger one (R); B reads it" % [
					gl_biome, gl_live, verb_home("icon")]
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
			var gname := str(pred.get("gate", "?")).strip_edges().to_lower()
			var gframe := str(GATE_FRAMES.get(gname, ""))
			var ghome := (" — %s: gate a focused plot" % verb_home(gframe)) if gframe != "" else ""
			return "%s ×%d%s" % [gate_glyph(str(pred.get("gate", "?"))), int(pred.get("count", 1)), ghome]
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
			return "close %d berry loop%s — %s: F tracks" % [int(pred.get("count", 1)), "s" if int(pred.get("count", 1)) != 1 else "", verb_home("icon")]
		"loops_linked":
			return "🪢 link two loops — winding ≥ %d" % int(pred.get("value", 1))
		"winding_gte":
			return "🪢 mutual winding ≥ %d" % int(pred.get("value", 1))
		"biome_frozen_loops_gte":
			return "bank %d loop%s in %s — %s: F tracks" % [int(pred.get("count", 1)), "s" if int(pred.get("count", 1)) != 1 else "", str(pred.get("biome", "?")), verb_home("icon")]
		"biome_loops_linked":
			return "🪢 link loops in %s — winding ≥ %d" % [str(pred.get("biome", "?")), int(pred.get("value", 1))]
		"bridge_built_gte":
			return "🌉 raise %d span%s" % [int(pred.get("value", 1)), "s" if int(pred.get("value", 1)) != 1 else ""]
		"bridge_braids_gte":
			return "🪢 braid the span ×%d" % int(pred.get("value", 1))
		"bridge_fused_gte":
			return "⚛ fuse %d bridge%s" % [int(pred.get("value", 1)), "s" if int(pred.get("value", 1)) != 1 else ""]
		"biome_betti_gte":
			return "🧭 %s needs %d loop%s in its coupling graph (β₁) — %s R adds icons; cycles make places invariants live" % [
				str(pred.get("biome", "?")), int(pred.get("count", 1)),
				"s" if int(pred.get("count", 1)) != 1 else "", verb_home("icon")]
		"biome_loop_closed_upstairs":
			return "close a lift upstairs in %s — walk the SAME loop again (%s: F tracks) until the loose ends meet (Ω ≡ 0 mod 4π)" % [
				str(pred.get("biome", "?")), verb_home("icon")]
		"biome_linking_valid":
			return "🪢 two closed lifts in %s — %s: walk two qubits each to upstairs closure; only then is linking a legal question" % [
				str(pred.get("biome", "?")), verb_home("icon")]
		"wilson_survived_flip":
			return "read the loops, then turn — %s 🧭: E reads the loop card, R flips a plot, the Wilson products hold" % verb_home("operator")
		"spinor_read":
			return "🪞 read a sign product of %+d — %s 🪞: R holds a reference home, E compares a ripe traveler against it" % [
				int(pred.get("value", -1)), verb_home("icon")]
		"winding_changed_uncut":
			return "🪢 make the winding change without cutting — %s: re-walk the partner with its axis swung, bank it, watch the integer move" % verb_home("icon")
		_:
			return t


## Compact math-formula line for a predicate — the literalist counterpart to
## summary(): where summary() hand-authors player-voice prose per type, formula()
## reads the raw config (type, target, width, count-gate-vs-soft-gate) straight
## off the predicate dict + QuestManager's own width/count-gate accessors, so it
## can never drift from the physics summary() paraphrases. No per-type authoring —
## one generic template covers every predicate type in FLAG_PREDICATE_TYPES.
## d1-02: rendered on Arc E-inspect (ControlsOverlay) beside summary().
static func formula(pred: Dictionary, qm = null) -> String:
	var t := str(pred.get("type", "?"))
	var center: float = float(pred.get("value", 0.0))
	var is_count: bool = bool(qm != null and qm.has_method("predicate_is_count_gate") and qm.predicate_is_count_gate(pred))
	var width: float = float(qm.predicate_width(pred)) if (qm and qm.has_method("predicate_width")) else float(pred.get("width", 0.05))
	var fire_target: float = float(qm.predicate_fire_target(pred)) if (qm and qm.has_method("predicate_fire_target")) else center
	var op := "≤" if t.ends_with("_lte") else "≥"
	var subject := _formula_subject(pred, t)
	var gate_kind := "count_gate" if is_count else "soft_gate"
	if is_count:
		# Fires exactly AT the authored integer — no width-shifted target to report.
		return "%s %s %d  ·  %s, width %s" % [subject, op, int(round(center)), gate_kind, _num(width)]
	return "%s %s %s  ·  %s(x, %s, w=%s), fires ~%s" % [subject, op, _num(center), gate_kind, _num(center), _num(width), _num(fire_target)]


## Compact float formatting for formula() — GDScript's String % operator has no %g,
## so trim trailing zeros off a fixed 3-decimal render by hand (3.000 → 3, 0.437 → 0.437).
static func _num(x: float) -> String:
	var s := "%.3f" % x
	if not s.contains("."):
		return s
	while s.ends_with("0"):
		s = s.substr(0, s.length() - 1)
	if s.ends_with("."):
		s = s.substr(0, s.length() - 1)
	return s


## The "x" side of the formula — the observable/count the predicate reads, named
## from whatever identifying fields the predicate dict carries (biome/atom/
## faction/channel/emoji), falling back to the bare type name.
static func _formula_subject(pred: Dictionary, t: String) -> String:
	var parts: Array[String] = [t]
	for key in ["biome", "atom", "faction", "channel", "emoji", "gate"]:
		if pred.has(key):
			parts.append(str(pred[key]))
	return ".".join(parts)


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
