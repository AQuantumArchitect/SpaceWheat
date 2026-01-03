class_name GoalsSystem
extends Node

## Goals System - Tracks player progression and objectives
## Provides clear goals for the first few "levels" + active contracts

signal goal_completed(goal: Dictionary)
signal all_goals_completed
signal active_goal_changed

# Goal state
var current_goal_index: int = 0
var goals_completed: Array[bool] = []

# Active contracts (from faction system)
var active_contracts: Array = []  # Contracts that player has accepted
var displayed_goal_index: int = 0  # Which goal/contract is currently displayed (0 = tutorial, 1+ = contracts)

# Goal definitions for early game progression
var goals: Array[Dictionary] = [
	{
		"id": "first_harvest",
		"title": "First Harvest",
		"description": "Plant and harvest your first wheat",
		"type": "harvest_count",
		"target": 1,
		"reward_credits": 10,
		"completed": false
	},
	{
		"id": "profit_maker",
		"title": "Profit Maker",
		"description": "Accumulate 200 wheat",
		"type": "wheat_inventory",
		"target": 200,
		"reward_credits": 25,
		"completed": false
	},
	{
		"id": "quantum_farmer",
		"title": "Quantum Farmer",
		"description": "Create your first entanglement",
		"type": "entanglement_count",
		"target": 1,
		"reward_credits": 15,
		"completed": false
	},
	{
		"id": "wheat_baron",
		"title": "Wheat Baron",
		"description": "Harvest 50 total wheat",
		"type": "total_wheat_harvested",
		"target": 50,
		"reward_credits": 50,
		"completed": false
	},
	{
		"id": "entanglement_master",
		"title": "Entanglement Master",
		"description": "Create 10 entanglements",
		"type": "entanglement_count",
		"target": 10,
		"reward_credits": 75,
		"completed": false
	},
	{
		"id": "tycoon",
		"title": "Farm Tycoon",
		"description": "Accumulate 1000 wheat",
		"type": "wheat_inventory",
		"target": 1000,
		"reward_credits": 100,
		"completed": false
	}
]

# Progress tracking
var progress: Dictionary = {
	"harvest_count": 0,
	"total_wheat_harvested": 0,
	"entanglement_count": 0,
	"measurements_made": 0
}


func _ready():
	# Initialize completed array
	for goal in goals:
		goals_completed.append(false)
	print("🎯 Goals System initialized with %d goals" % goals.size())


## Progress Tracking

func record_harvest(wheat_credits: int):
	"""Record a wheat harvest event (credits earned)"""
	progress["harvest_count"] += 1
	progress["total_wheat_harvested"] += wheat_credits
	_check_goals()


func record_entanglement():
	"""Record an entanglement creation"""
	progress["entanglement_count"] += 1
	_check_goals()


func record_measurement():
	"""Record a measurement"""
	progress["measurements_made"] += 1
	_check_goals()


## Goal Checking

func _check_goals():
	"""Check all incomplete goals for completion"""
	for i in range(goals.size()):
		if goals_completed[i]:
			continue  # Skip already completed goals

		var goal = goals[i]
		var target = goal["target"]
		var current_value = progress.get(goal["type"], 0)

		# Special case for wheat_inventory - check economy directly
		if goal["type"] == "wheat_inventory":
			# Will be checked by check_wheat_goal when wheat changes
			continue

		if current_value >= target:
			_complete_goal(i)


func check_wheat_goal(current_wheat: int):
	"""Check wheat-based goals (called from FarmView when wheat changes)"""
	for i in range(goals.size()):
		if goals_completed[i]:
			continue

		var goal = goals[i]
		if goal["type"] == "wheat_inventory" and current_wheat >= goal["target"]:
			_complete_goal(i)


func _complete_goal(goal_index: int):
	"""Mark goal as complete and award reward"""
	if goals_completed[goal_index]:
		return  # Already completed

	goals_completed[goal_index] = true
	var goal = goals[goal_index]
	goal["completed"] = true

	print("🎉 Goal completed: %s" % goal["title"])
	print("   Reward: +%d credits" % goal["reward_credits"])

	goal_completed.emit(goal)

	# Check if all goals complete
	if goals_completed.all(func(c): return c):
		all_goals_completed.emit()


## UI Helpers

func get_current_goal() -> Dictionary:
	"""Get the next incomplete goal"""
	for i in range(goals.size()):
		if not goals_completed[i]:
			return goals[i]

	# All goals complete
	return {"title": "All Goals Complete!", "description": "You've mastered quantum farming!", "completed": true}


func get_goal_progress(goal: Dictionary) -> float:
	"""Get progress 0.0-1.0 for a goal"""
	if goal.get("completed", false):
		return 1.0

	var goal_type = goal.get("type", "")
	var target = goal.get("target", 1)

	if goal_type == "credits":
		return 0.0  # Handled externally

	var current = progress.get(goal_type, 0)
	return min(float(current) / float(target), 1.0)


func get_goal_progress_text(goal: Dictionary, current_wheat: int = 0) -> String:
	"""Get progress text like '3/10' for a goal"""
	if goal.get("completed", false):
		return "Complete!"

	var goal_type = goal.get("type", "")
	var target = goal.get("target", 1)

	if goal_type == "wheat_inventory":
		return "%d / %d wheat" % [current_wheat, target]

	var current = progress.get(goal_type, 0)
	return "%d / %d" % [current, target]


func get_all_goals() -> Array[Dictionary]:
	"""Get all goals for UI display"""
	return goals


func get_stats() -> Dictionary:
	"""Get goal statistics"""
	var completed_count = goals_completed.count(true)
	return {
		"total_goals": goals.size(),
		"completed_goals": completed_count,
		"current_goal_index": current_goal_index,
		"progress": progress
	}


## Contract Management

func add_active_contract(contract):
	"""Add a contract to active goals"""
	if contract not in active_contracts:
		active_contracts.append(contract)
		print("📜 Contract added to active goals: %s" % contract.contract_title)
		active_goal_changed.emit()


func remove_active_contract(contract):
	"""Remove a contract from active goals"""
	if contract in active_contracts:
		active_contracts.erase(contract)
		active_goal_changed.emit()


func get_displayed_goal() -> Dictionary:
	"""Get the currently displayed goal (tutorial or contract)"""
	if displayed_goal_index == 0:
		# Show current tutorial goal
		return get_current_goal()
	elif displayed_goal_index <= active_contracts.size():
		# Show active contract
		var contract = active_contracts[displayed_goal_index - 1]
		# Convert contract to goal format
		return {
			"title": contract.contract_title,
			"description": contract.contract_description,
			"type": "contract",
			"contract": contract,
			"completed": false
		}
	else:
		# Fallback to tutorial goal
		displayed_goal_index = 0
		return get_current_goal()


func cycle_displayed_goal():
	"""Cycle to next goal/contract"""
	var total_options = 1 + active_contracts.size()  # Tutorial + contracts
	displayed_goal_index = (displayed_goal_index + 1) % total_options
	active_goal_changed.emit()


func get_goal_count() -> int:
	"""Get total number of goals/contracts available"""
	return 1 + active_contracts.size()  # Tutorial + contracts
