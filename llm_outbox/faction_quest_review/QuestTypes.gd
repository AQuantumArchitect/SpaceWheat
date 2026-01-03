class_name QuestTypes
extends RefCounted

## Quest Type Definitions
## Defines different kinds of quests beyond simple delivery

enum Type {
	DELIVERY,       # Deliver X resources (current system)
	SHAPE_ACHIEVE,  # Achieve target observable value once
	SHAPE_MAINTAIN, # Maintain observable value for duration
	EVOLUTION,      # Change observable by delta amount
	ENTANGLEMENT    # Create coherence between species
}


static func get_type_icon(type: Type) -> String:
	"""Get emoji icon for quest type"""
	match type:
		Type.DELIVERY:
			return "📦"
		Type.SHAPE_ACHIEVE:
			return "🎯"
		Type.SHAPE_MAINTAIN:
			return "⏱️"
		Type.EVOLUTION:
			return "🌀"
		Type.ENTANGLEMENT:
			return "🔗"
	return "❓"


static func get_type_name(type: Type) -> String:
	"""Get human-readable type name"""
	match type:
		Type.DELIVERY:
			return "Delivery"
		Type.SHAPE_ACHIEVE:
			return "Shape Achievement"
		Type.SHAPE_MAINTAIN:
			return "Shape Maintenance"
		Type.EVOLUTION:
			return "Evolution"
		Type.ENTANGLEMENT:
			return "Entanglement"
	return "Unknown"


static func get_type_description(type: Type) -> String:
	"""Get description of what this quest type requires"""
	match type:
		Type.DELIVERY:
			return "Deliver resources to complete"
		Type.SHAPE_ACHIEVE:
			return "Reach target quantum state once"
		Type.SHAPE_MAINTAIN:
			return "Hold quantum state for duration"
		Type.EVOLUTION:
			return "Change quantum observable by amount"
		Type.ENTANGLEMENT:
			return "Create quantum coherence"
	return ""


static func requires_tracking(type: Type) -> bool:
	"""Does this quest type need continuous state monitoring?"""
	match type:
		Type.DELIVERY:
			return false  # Checked on resource events only
		Type.SHAPE_ACHIEVE, Type.SHAPE_MAINTAIN, Type.EVOLUTION, Type.ENTANGLEMENT:
			return true  # Need _physics_process monitoring
	return false
