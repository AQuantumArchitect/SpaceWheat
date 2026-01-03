class_name QuestPanel
extends PanelContainer

## QuestPanel - Displays active quests from 32 factions
## Shows quest text, requirements, rewards, and time limits
## Allows accepting and completing quests via click interaction

signal quest_accept_clicked(quest_id: int)
signal quest_complete_clicked(quest_id: int)
signal quest_panel_clicked

# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# Quest manager reference
var quest_manager: Node = null

# UI elements
var quests_vbox: VBoxContainer
var no_quests_label: Label
var quest_title_label: Label

# Quest item displays: quest_id -> QuestItem node
var quest_items: Dictionary = {}

# Constants
const MAX_DISPLAYED_QUESTS: int = 5
const QUEST_ITEM_HEIGHT: int = 100


func set_layout_manager(manager: Node):
	"""Set the layout manager reference for dynamic scaling"""
	layout_manager = manager


func _ready():
	_create_ui()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event):
	"""Handle mouse clicks"""
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			quest_panel_clicked.emit()


func _create_ui():
	"""Create quest display UI with dynamic scaling"""
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var title_font_size = layout_manager.get_scaled_font_size(18) if layout_manager else 18
	var no_quest_font_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14

	var panel_width = int(500 * scale_factor)
	var panel_height = int(600 * scale_factor)
	custom_minimum_size = Vector2(panel_width, panel_height)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", int(10 * scale_factor))
	add_child(main_vbox)

	# Title
	quest_title_label = Label.new()
	quest_title_label.text = "📜 Active Quests"
	quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_title_label.add_theme_font_size_override("font_size", title_font_size)
	main_vbox.add_child(quest_title_label)

	# Scroll container for quests
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, int(500 * scale_factor))
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	# VBox for quest items
	quests_vbox = VBoxContainer.new()
	quests_vbox.add_theme_constant_override("separation", int(8 * scale_factor))
	scroll.add_child(quests_vbox)

	# "No quests" placeholder
	no_quests_label = Label.new()
	no_quests_label.text = "No active quests.\nQuests will appear here from the 32 factions."
	no_quests_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	no_quests_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	no_quests_label.add_theme_font_size_override("font_size", no_quest_font_size)
	no_quests_label.modulate = Color(0.6, 0.6, 0.6)
	quests_vbox.add_child(no_quests_label)


# =============================================================================
# QUEST MANAGER CONNECTION
# =============================================================================

func connect_to_quest_manager(manager: Node) -> void:
	"""Connect to QuestManager signals"""
	if not manager:
		push_warning("QuestPanel: quest_manager is null")
		return

	quest_manager = manager

	# Connect signals
	if manager.has_signal("quest_offered"):
		manager.quest_offered.connect(_on_quest_offered)
	if manager.has_signal("quest_accepted"):
		manager.quest_accepted.connect(_on_quest_accepted)
	if manager.has_signal("quest_completed"):
		manager.quest_completed.connect(_on_quest_completed)
	if manager.has_signal("quest_failed"):
		manager.quest_failed.connect(_on_quest_failed)
	if manager.has_signal("quest_expired"):
		manager.quest_expired.connect(_on_quest_expired)
	if manager.has_signal("active_quests_changed"):
		manager.active_quests_changed.connect(_on_active_quests_changed)

	# Initialize with current quests
	_refresh_all_quests()


func _on_quest_offered(quest_data: Dictionary) -> void:
	"""Handle new quest offer"""
	# Don't display offered quests, only active ones
	pass


func _on_quest_accepted(quest_id: int) -> void:
	"""Handle quest acceptance"""
	if not quest_manager:
		return

	var quest = quest_manager.get_quest_by_id(quest_id)
	if quest.is_empty():
		return

	_create_quest_item(quest)
	_update_no_quests_visibility()


func _on_quest_completed(quest_id: int, rewards: Dictionary) -> void:
	"""Handle quest completion"""
	_remove_quest_item(quest_id)
	_update_no_quests_visibility()

	# TODO: Show reward notification


func _on_quest_failed(quest_id: int, reason: String) -> void:
	"""Handle quest failure"""
	_remove_quest_item(quest_id)
	_update_no_quests_visibility()

	# TODO: Show failure notification


func _on_quest_expired(quest_id: int) -> void:
	"""Handle quest expiration"""
	# Already handled by quest_failed, but can add special handling here
	pass


func _on_active_quests_changed() -> void:
	"""Handle active quests list change"""
	_refresh_all_quests()


# =============================================================================
# QUEST ITEM MANAGEMENT
# =============================================================================

func _create_quest_item(quest: Dictionary) -> void:
	"""Create a quest item display"""
	if not quest.has("id"):
		return

	var quest_id = quest["id"]

	# Remove existing item if present
	if quest_items.has(quest_id):
		_remove_quest_item(quest_id)

	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0

	# Create quest item
	var item = QuestItem.new()
	item.set_layout_manager(layout_manager)
	item.set_quest_data(quest)
	item.quest_complete_requested.connect(_on_quest_item_complete_clicked.bind(quest_id))

	quests_vbox.add_child(item)
	quest_items[quest_id] = item

	# Start timer display if quest has time limit
	if quest.get("time_limit", -1) > 0:
		item.start_timer_update(quest_manager)


func _remove_quest_item(quest_id: int) -> void:
	"""Remove a quest item display"""
	if not quest_items.has(quest_id):
		return

	var item = quest_items[quest_id]
	item.queue_free()
	quest_items.erase(quest_id)


func _refresh_all_quests() -> void:
	"""Refresh all quest displays from quest manager"""
	# Clear existing items
	for quest_id in quest_items.keys():
		_remove_quest_item(quest_id)

	if not quest_manager:
		return

	# Create items for all active quests
	var active_quests = quest_manager.get_active_quests()
	for quest in active_quests:
		_create_quest_item(quest)

	_update_no_quests_visibility()


func _update_no_quests_visibility() -> void:
	"""Show/hide 'no quests' label"""
	if no_quests_label:  # Guard against null during initialization
		no_quests_label.visible = quest_items.is_empty()


func _on_quest_item_complete_clicked(quest_id: int) -> void:
	"""Handle quest item complete button click"""
	if not quest_manager:
		return

	# Check if player can complete quest
	if quest_manager.check_quest_completion(quest_id):
		quest_manager.complete_quest(quest_id)
	else:
		# TODO: Show "insufficient resources" message
		print("⚠️  Cannot complete quest %d: insufficient resources" % quest_id)


# =============================================================================
# QUEST ITEM COMPONENT
# =============================================================================

class QuestItem extends PanelContainer:
	"""Individual quest display item"""

	signal quest_complete_requested

	var layout_manager: Node
	var quest_data: Dictionary
	var timer_label: Label
	var complete_button: Button
	var timer_update_active: bool = false
	var quest_manager_ref: Node = null

	func set_layout_manager(manager: Node):
		layout_manager = manager

	func set_quest_data(quest: Dictionary):
		quest_data = quest
		_create_ui()

	func _create_ui():
		var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
		var faction_font_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14
		var body_font_size = layout_manager.get_scaled_font_size(12) if layout_manager else 12
		var detail_font_size = layout_manager.get_scaled_font_size(11) if layout_manager else 11

		custom_minimum_size = Vector2(0, int(100 * scale_factor))

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", int(5 * scale_factor))
		add_child(vbox)

		# Faction header
		var faction_label = Label.new()
		var faction_text = "%s %s" % [
			quest_data.get("faction_emoji", ""),
			quest_data.get("faction", "Unknown")
		]
		faction_label.text = faction_text
		faction_label.add_theme_font_size_override("font_size", faction_font_size)
		faction_label.modulate = Color(1.0, 0.9, 0.6)  # Gold tint
		vbox.add_child(faction_label)

		# Quest body (or emoji display)
		var body_label = Label.new()
		if quest_data.get("is_emoji_only", false):
			body_label.text = quest_data.get("display", "???")
		else:
			body_label.text = quest_data.get("body", "Quest details missing")
		body_label.add_theme_font_size_override("font_size", body_font_size)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(body_label)

		# Quest details (resource, time, urgency)
		var details_hbox = HBoxContainer.new()
		details_hbox.add_theme_constant_override("separation", int(15 * scale_factor))
		vbox.add_child(details_hbox)

		# Resource requirement
		var resource_label = Label.new()
		resource_label.text = "Need: %s × %d" % [
			quest_data.get("resource", "?"),
			quest_data.get("quantity", 0)
		]
		resource_label.add_theme_font_size_override("font_size", detail_font_size)
		details_hbox.add_child(resource_label)

		# Time limit
		timer_label = Label.new()
		var time_limit = quest_data.get("time_limit", -1)
		if time_limit > 0:
			timer_label.text = "⏰ %ds" % time_limit
		else:
			timer_label.text = "🕰️ No limit"
		timer_label.add_theme_font_size_override("font_size", detail_font_size)
		details_hbox.add_child(timer_label)

		# Complete button
		complete_button = Button.new()
		complete_button.text = "✅ Complete"
		complete_button.add_theme_font_size_override("font_size", detail_font_size)
		complete_button.pressed.connect(_on_complete_button_pressed)
		details_hbox.add_child(complete_button)

	func _on_complete_button_pressed():
		quest_complete_requested.emit()

	func start_timer_update(quest_manager: Node):
		"""Start updating timer display"""
		quest_manager_ref = quest_manager
		timer_update_active = true
		set_process(true)

	func _process(_delta: float):
		if not timer_update_active or not quest_manager_ref:
			return

		var quest_id = quest_data.get("id", -1)
		if quest_id < 0:
			return

		var time_left = quest_manager_ref.get_quest_time_remaining(quest_id)
		if time_left < 0:
			timer_update_active = false
			set_process(false)
			return

		timer_label.text = "⏰ %ds" % int(time_left)

		# Color warning when time is low
		if time_left < 10:
			timer_label.modulate = Color(1.0, 0.3, 0.3)  # Red
		elif time_left < 30:
			timer_label.modulate = Color(1.0, 0.8, 0.0)  # Yellow
		else:
			timer_label.modulate = Color(1.0, 1.0, 1.0)  # White
