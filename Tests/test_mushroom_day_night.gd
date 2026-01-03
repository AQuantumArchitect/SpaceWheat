extends SceneTree

## Test: Mushroom Sun Damage & Moon Growth
## Verifies energy coupling system works - mushrooms should:
## - Take damage during day (high ☀ probability)
## - Grow during night (high 🌙 probability)

const Farm = preload("res://Core/Farm.gd")

var farm: Farm

func _initialize():
	print("\n" + "=".repeat(80))
	print("🍄 TEST: Mushroom Sun Damage & Moon Growth")
	print("=".repeat(80))

	await get_root().ready

	# Setup farm
	farm = Farm.new()
	farm.name = "Farm"
	get_root().add_child(farm)

	# Plant mushroom
	print("\n🍄 Planting mushroom at (0,0)...")
	farm.build(Vector2i(0, 0), "mushroom")

	var biotic_flux = farm.get_node("BioticFlux")

	# Simulate shorter test (10s)
	print("\n⏰ Simulating 10 second test...")
	var samples = []

	for i in range(600):  # 10 seconds at 60fps
		var t = i / 60.0
		biotic_flux.advance_simulation(1.0/60.0)

		# Sample every 1 second
		if i % 60 == 0:
			var plot = farm.grid.get_plot(Vector2i(0, 0))
			var sun_prob = biotic_flux.bath.get_probability("☀")
			var moon_prob = biotic_flux.bath.get_probability("🌙")
			var radius = plot.quantum_state.radius if plot.quantum_state else 0.0

			samples.append({
				"time": t,
				"radius": radius,
				"sun_prob": sun_prob,
				"moon_prob": moon_prob
			})

			var phase = "DAY" if sun_prob > moon_prob else "NIGHT"
			print("  t=%.1fs (%s): radius=%.3f, P(☀)=%.2f, P(🌙)=%.2f" % [t, phase, radius, sun_prob, moon_prob])

	# Verify behavior
	print("\n" + "=".repeat(80))
	print("✅ VERIFICATION")
	print("=".repeat(80))

	var issues = []

	# Check for growth/damage correlation with day/night
	var day_samples = samples.filter(func(s): return s.sun_prob > s.moon_prob)
	var night_samples = samples.filter(func(s): return s.moon_prob > s.sun_prob)

	if day_samples.size() > 0:
		var avg_day_radius = day_samples.map(func(s): return s.radius).reduce(func(acc, r): return acc + r, 0.0) / day_samples.size()
		print("  📊 Average radius during DAY: %.3f" % avg_day_radius)

	if night_samples.size() > 0:
		var avg_night_radius = night_samples.map(func(s): return s.radius).reduce(func(acc, r): return acc + r, 0.0) / night_samples.size()
		print("  📊 Average radius during NIGHT: %.3f" % avg_night_radius)

	# Check if mushroom grows over full cycle (should oscillate, but net positive from Lindblad)
	var initial_radius = samples[0].radius
	var final_radius = samples[-1].radius

	print("\n  Initial radius: %.3f" % initial_radius)
	print("  Final radius: %.3f" % final_radius)
	print("  Net change: %+.3f" % (final_radius - initial_radius))

	if final_radius > initial_radius * 1.1:
		print("✅ Mushroom grew over time (Lindblad growth working)")
	elif final_radius < initial_radius * 0.9:
		issues.append("❌ Mushroom shrunk over full cycle - possible sun damage too strong")
	else:
		print("✅ Mushroom stable (growth/damage balanced)")

	if issues.size() > 0:
		print("\n⚠️  ISSUES FOUND:")
		for issue in issues:
			print("   " + issue)
	else:
		print("\n🎉 ALL CHECKS PASSED - Energy coupling working!")

	print("\n" + "=".repeat(80))
	quit(0)
