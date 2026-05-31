extends SceneTree

## faction_affinity_parity.gd — faction affinity verification.
##
## Run:  godot --headless --quit --script tests/faction_affinity_parity.gd
##
## Confirms every loaded faction has an AlignmentGraph initialized at
## the corner state |bits⟩⟨bits|, and that get_axial_bits() returns
## a value identical to the raw bits config (so all consumers that
## switched to the accessor see no behavioral change).

const FactionRegistryCls = preload("res://Core/Factions/FactionRegistry.gd")

func _init() -> void:
	print("=== Faction affinity parity ===")
	var reg = FactionRegistryCls.new()
	reg.load_factions()
	var all_factions: Array = reg.get_all()
	print("  loaded %d factions" % all_factions.size())
	if all_factions.is_empty():
		push_error("no factions loaded — registry/data path broken")
		quit(1)
		return

	var failed := 0
	var no_affinity := 0
	var bit_mismatch := 0
	var purity_drift := 0
	var inter_overlap_fail := 0

	for f in all_factions:
		if f.alignment == null:
			no_affinity += 1
			failed += 1
			continue
		var via_substrate: PackedByteArray = f.get_axial_bits()
		if via_substrate.size() != f.bits.size():
			bit_mismatch += 1
			failed += 1
			continue
		var ok := true
		for i in range(f.bits.size()):
			if via_substrate[i] != f.bits[i]:
				ok = false
				break
		if not ok:
			bit_mismatch += 1
			failed += 1
			continue
		var p: float = f.alignment.purity()
		if abs(p - 1.0) > 1e-9:
			purity_drift += 1
			failed += 1

	# Inter-faction overlap kernel sanity: identical-bits → 1, distinct → 0.
	var sample_pairs := 0
	var sample_limit := 30
	for i in range(min(all_factions.size(), 12)):
		for j in range(i + 1, min(all_factions.size(), 12)):
			if sample_pairs >= sample_limit:
				break
			var a = all_factions[i]
			var b = all_factions[j]
			if a.alignment == null or b.alignment == null:
				continue
			var bits_match := true
			if a.bits.size() != b.bits.size():
				bits_match = false
			else:
				for k in range(a.bits.size()):
					if a.bits[k] != b.bits[k]:
						bits_match = false
						break
			var ov: float = a.alignment.overlap(b.alignment)
			var expected := 1.0 if bits_match else 0.0
			if abs(ov - expected) > 1e-9:
				inter_overlap_fail += 1
				failed += 1
				print("  ✗ overlap(%s, %s) = %.6f, expected %.1f" % [a.name, b.name, ov, expected])
			sample_pairs += 1

	print("  factions checked: %d" % all_factions.size())
	print("  overlap pairs sampled: %d" % sample_pairs)
	if failed == 0:
		print("=== PASS ===")
		quit(0)
	else:
		print("=== FAIL: no_affinity=%d bit_mismatch=%d purity_drift=%d overlap_fail=%d ===" %
			[no_affinity, bit_mismatch, purity_drift, inter_overlap_fail])
		quit(1)
