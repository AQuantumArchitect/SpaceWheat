extends SceneTree

## Live Attractor Test - Watch attractor personality emerge over time

const BioticFluxBiome = preload("res://Core/Environment/BioticFluxBiome.gd")
const MarketBiome = preload("res://Core/Environment/MarketBiome.gd")
const StrangeAttractorAnalyzer = preload("res://Core/QuantumSubstrate/StrangeAttractorAnalyzer.gd")

func _init():
	print("\n" + "=".repeat(70))
	print("LIVE ATTRACTOR EVOLUTION TEST")
	print("=".repeat(70) + "\n")

	# Create two biomes to compare
	test_biotic_flux_attractor()
	test_market_attractor()

	print("\n" + "=".repeat(70))
	print("TEST COMPLETE - Both biomes evolved for 10 seconds")
	print("=".repeat(70) + "\n")

	quit()


func test_biotic_flux_attractor():
	print("TEST: BioticFlux Biome Attractor Evolution")
	print("-".repeat(70))

	var biome = BioticFluxBiome.new()
	root.add_child(biome)
	biome._ready()

	if not biome.attractor_analyzer:
		print("  ✗ ERROR: Attractor analyzer not initialized!")
		return

	print("  Phase space axes: %s" % str(biome.attractor_analyzer.selected_emojis))
	print("  Evolving biome for 10 seconds (600 steps @ 60fps)...\n")

	var dt = 1.0 / 60.0  # 60 FPS

	# Evolve for 10 seconds
	for step in range(600):
		biome.advance_simulation(dt)

		# Print status every 2 seconds
		if step % 120 == 0 and step > 0:
			var time = step / 60.0
			var signature = biome.attractor_analyzer.get_signature()

			if signature.has("personality") and signature.personality != "unknown":
				var personality = signature.personality
				var emoji = StrangeAttractorAnalyzer.get_personality_emoji(personality)
				print("  [t=%.1fs] %s %s | Lyapunov=%.3f | Spread=%.3f | Points=%d" % [
					time,
					emoji,
					personality.capitalize(),
					signature.lyapunov_exponent,
					signature.spread,
					signature.trajectory_length
				])
			else:
				print("  [t=%.1fs] Collecting data... (%d points)" % [
					time,
					signature.get("trajectory_length", 0)
				])

	# Final report
	print("\n  Final Attractor Signature:")
	print("    (DEBUG: actual trajectory.size() = %d)" % biome.attractor_analyzer.trajectory.size())
	var final_sig = biome.attractor_analyzer.get_signature()

	if final_sig.personality != "unknown":
		print("    Personality: %s %s" % [
			StrangeAttractorAnalyzer.get_personality_emoji(final_sig.personality),
			final_sig.personality.capitalize()
		])
		print("    Description: %s" % StrangeAttractorAnalyzer.get_personality_description(final_sig.personality))
		print("    Lyapunov Exponent: %.3f" % final_sig.lyapunov_exponent)
		print("    Spread: %.3f" % final_sig.spread)
		print("    Periodicity: %.3f" % final_sig.periodicity)
		print("    Trajectory Points: %d" % final_sig.trajectory_length)
	else:
		print("    Insufficient data for classification")
		print("    Signature status: %s" % final_sig.get("status", "no_status"))
		print("    Reported trajectory_length: %d" % final_sig.get("trajectory_length", -1))

	biome.queue_free()
	print()


func test_market_attractor():
	print("\nTEST: Market Biome Attractor Evolution")
	print("-".repeat(70))

	var biome = MarketBiome.new()
	root.add_child(biome)
	biome._ready()

	if not biome.attractor_analyzer:
		print("  ✗ ERROR: Attractor analyzer not initialized!")
		return

	print("  Phase space axes: %s" % str(biome.attractor_analyzer.selected_emojis))
	print("  Evolving biome for 10 seconds (600 steps @ 60fps)...\n")

	var dt = 1.0 / 60.0

	# Evolve for 10 seconds
	for step in range(600):
		biome.advance_simulation(dt)

		# Print status every 2 seconds
		if step % 120 == 0 and step > 0:
			var time = step / 60.0
			var signature = biome.attractor_analyzer.get_signature()

			if signature.has("personality") and signature.personality != "unknown":
				var personality = signature.personality
				var emoji = StrangeAttractorAnalyzer.get_personality_emoji(personality)
				print("  [t=%.1fs] %s %s | Lyapunov=%.3f | Spread=%.3f | Points=%d" % [
					time,
					emoji,
					personality.capitalize(),
					signature.lyapunov_exponent,
					signature.spread,
					signature.trajectory_length
				])
			else:
				print("  [t=%.1fs] Collecting data... (%d points)" % [
					time,
					signature.get("trajectory_length", 0)
				])

	# Final report
	print("\n  Final Attractor Signature:")
	var final_sig = biome.attractor_analyzer.get_signature()

	if final_sig.personality != "unknown":
		print("    Personality: %s %s" % [
			StrangeAttractorAnalyzer.get_personality_emoji(final_sig.personality),
			final_sig.personality.capitalize()
		])
		print("    Description: %s" % StrangeAttractorAnalyzer.get_personality_description(final_sig.personality))
		print("    Lyapunov Exponent: %.3f" % final_sig.lyapunov_exponent)
		print("    Spread: %.3f" % final_sig.spread)
		print("    Periodicity: %.3f" % final_sig.periodicity)
		print("    Trajectory Points: %d" % final_sig.trajectory_length)
		print("    Centroid: (%.2f, %.2f, %.2f)" % [
			final_sig.centroid.x,
			final_sig.centroid.y,
			final_sig.centroid.z
		])
	else:
		print("    Insufficient data for classification")

	# Show attractor comparison
	print("\n  📊 Comparing BioticFlux vs Market Attractors:")
	print("    Different biomes develop different topological personalities!")

	biome.queue_free()
	print()
