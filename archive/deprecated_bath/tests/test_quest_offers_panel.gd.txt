#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test FactionQuestOffersPanel with emergent quest generation
## Verifies UI displays faction offers based on biome state

const FactionQuestOffersPanel = preload("res://UI/Panels/FactionQuestOffersPanel.gd")
const QuestManager = preload("res://Core/Quests/QuestManager.gd")
const QuantumBath = preload("res://Core/QuantumSubstrate/QuantumBath.gd")
const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")

func _init():
	print("\n" + "=".repeat(80))
	print("🧪 FACTION QUEST OFFERS PANEL TEST")
	print("=".repeat(80))

	# Create mock biome with bath
	var test_biome = create_test_biome()

	# Create layout manager
	var layout_manager = UILayoutManager.new()
	root.add_child(layout_manager)

	# Create quest manager
	var quest_manager = QuestManager.new()
	root.add_child(quest_manager)

	# Create quest offers panel
	print("\n📋 Creating FactionQuestOffersPanel...")
	var panel = FactionQuestOffersPanel.new()
	panel.set_layout_manager(layout_manager)
	panel.connect_to_quest_manager(quest_manager)
	root.add_child(panel)

	# Manually trigger _ready() since we're in headless mode
	panel._ready()

	# Connect signals
	panel.quest_offer_accepted.connect(_on_quest_accepted)
	panel.panel_closed.connect(_on_panel_closed)

	print("  ✅ Panel created and configured")

	# Test showing offers
	print("\n🎯 Testing show_offers() with test biome...")
	panel.show_offers(test_biome)

	# Verify panel is visible and populated
	print("\n📊 Verification:")
	print("  Panel visible: %s" % panel.visible)
	print("  Panel children count: %d" % panel.get_child_count())

	# Debug: Print panel structure
	if panel.get_child_count() > 0:
		var main_vbox = panel.get_child(0)
		print("  Main VBox children: %d" % main_vbox.get_child_count())

		for i in range(main_vbox.get_child_count()):
			var child = main_vbox.get_child(i)
			print("    [%d] %s" % [i, child.get_class()])

		# Look for scroll container
		for i in range(main_vbox.get_child_count()):
			var child = main_vbox.get_child(i)
			if child is ScrollContainer:
				print("  Found ScrollContainer at index %d" % i)
				var scroll_children = child.get_child_count()
				print("    ScrollContainer children: %d" % scroll_children)
				if scroll_children > 0:
					var offers_vbox = child.get_child(0)
					var offer_count = offers_vbox.get_child_count()
					print("    Quest offers: %d" % offer_count)

					if offer_count > 0:
						print("  ✅ Quest offers successfully generated!")

						# Show first 3 quests
						for j in range(min(3, offer_count)):
							print("      Quest %d generated" % (j + 1))
	else:
		print("  ⚠️  Panel has no children - UI not created")

	print("\n" + "=".repeat(80))
	print("✅ TEST COMPLETE")
	print("=".repeat(80) + "\n")

	quit(0)


func create_test_biome():
	"""Create a minimal biome with quantum bath for testing"""
	var biome = Node.new()
	biome.name = "TestBiome"
	biome.set_script(preload("res://Core/Environment/BiomeBase.gd"))

	# Initialize bath with test emojis
	var bath = QuantumBath.new()
	bath.initialize_with_emojis(["🌾", "🍄", "💨", "🍂", "🍅"])

	biome.bath = bath
	biome.biome_name = "TestBiome"
	biome.use_bath_mode = true

	print("🛁 Test biome created with 5-emoji bath")
	print("   Emojis: 🌾 🍄 💨 🍂 🍅")

	# Verify bath state
	var purity = bath.get_purity()
	print("   Bath purity: %.3f" % purity)

	return biome


func _on_quest_accepted(quest: Dictionary):
	print("📜 Quest accepted in test: %s - %s" % [quest.get("faction", ""), quest.get("body", "")])


func _on_panel_closed():
	print("🚪 Panel closed signal received")
