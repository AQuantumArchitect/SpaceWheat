## ControlsInterface - Abstract contract between UI Layout and Simulation Machinery
##
## The layout uses this interface to control ANY simulation.
## The simulation implements this interface.
## This allows swapping simulations without changing the UI.
##
## Example:
##   var controls: ControlsInterface
##   controls = farm  # Farm implements ControlsInterface
##   controls.select_tool(1)  # Works regardless of simulation type

extends Node
class_name ControlsInterface

## Signals emitted BY the simulation for UI updates

signal tool_selected(tool_num: int)
signal plot_selected(position: Vector2i)
signal action_executed(action: String, position: Vector2i, success: bool)

signal credits_changed(new_amount: int)
signal inventory_changed(resource: String, amount: int)
signal plot_state_changed(position: Vector2i)
signal plot_planted(position: Vector2i)
signal plot_harvested(position: Vector2i, yield_amount: int)
signal qubit_measured(position: Vector2i, outcome: String)
signal plots_entangled(pos1: Vector2i, pos2: Vector2i)


## CONTROL METHODS - Called by the layout to control simulation

func select_tool(tool_num: int) -> void:
	"""Select a tool (1-6)"""
	push_error("ControlsInterface.select_tool() not implemented by simulation!")


func select_plot(position: Vector2i) -> void:
	"""Select/highlight a plot"""
	push_error("ControlsInterface.select_plot() not implemented by simulation!")


func trigger_action(action_key: String, position: Vector2i = Vector2i.ZERO) -> bool:
	"""Trigger an action (Q/E/R key). Returns success/failure."""
	push_error("ControlsInterface.trigger_action() not implemented by simulation!")
	return false


func move_cursor(direction: Vector2i) -> void:
	"""Move selection cursor (WASD)"""
	push_error("ControlsInterface.move_cursor() not implemented by simulation!")


func quick_select_location(index: int) -> void:
	"""Quick select a location (Y/U/I/O/P keys, index 1-5)"""
	push_error("ControlsInterface.quick_select_location() not implemented by simulation!")


## QUERY METHODS - Layout calls these to get current state

func get_current_tool() -> int:
	"""Get currently selected tool (1-6)"""
	return 0


func get_current_selection() -> Vector2i:
	"""Get currently selected plot position"""
	return Vector2i.ZERO


func get_credits() -> int:
	"""Get current credits/currency amount"""
	return 0


func get_inventory(resource: String) -> int:
	"""Get amount of a resource in inventory"""
	return 0
