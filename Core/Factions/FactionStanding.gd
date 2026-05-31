class_name FactionStanding
extends RefCounted

## FactionStanding — six-channel reputation edge field for one faction.
##
## Replaces the previous scalar `standing: float` model. Each channel is an
## independent quality of the player↔faction relationship; they can be in
## tension (high trust + high debt = a friend you owe; high access + high
## attention = welcome but watched). Wired into QuestRewards (success/failure
## deltas), FactionAffinity (soft affinity bonus), and the Farm save format.
##
## All channels default to 0.0 and are unbounded in code (callers clamp where
## they care). `scalar()` is an aggregate for consumers that want one float.

## 🤝 Positive interactions; completed contracts; vouched-for actions.
var trust: float = 0.0

## 🩸 Unsettled obligations; broken promises; resources owed back.
var debt: float = 0.0

## 🧿 The faction is watching this player; can be earned via notable actions
## (good or bad). High attention amplifies the consequence of future actions.
var attention: float = 0.0

## 🗝 Unlocked services, shops, contract tiers, or hidden information.
var access: float = 0.0

## ⚖ Standing within the faction's own social order; "rank" without authority.
## Distinct from trust (which is interpersonal/transactional).
var legitimacy: float = 0.0

## 🕸 Conspiratorial / ambiguous / shared-secret ties. Neither friendly nor
## hostile; an entanglement edge that complicates other channels.
var entanglement: float = 0.0


func scalar() -> float:
	# Legacy aggregate. Used by code that hasn't migrated to channels yet.
	# Range roughly [-1, 1]; debt subtracts, the constructive channels add.
	return clampf((trust - debt + access + legitimacy) * 0.25, -1.0, 1.0)


func to_dict() -> Dictionary:
	return {
		"trust": trust,
		"debt": debt,
		"attention": attention,
		"access": access,
		"legitimacy": legitimacy,
		"entanglement": entanglement,
	}


static func from_dict(data: Dictionary) -> FactionStanding:
	var s = load("res://Core/Factions/FactionStanding.gd").new()
	if data == null or data.is_empty():
		return s
	s.trust = float(data.get("trust", 0.0))
	s.debt = float(data.get("debt", 0.0))
	s.attention = float(data.get("attention", 0.0))
	s.access = float(data.get("access", 0.0))
	s.legitimacy = float(data.get("legitimacy", 0.0))
	s.entanglement = float(data.get("entanglement", 0.0))
	return s


func _to_string() -> String:
	return "FactionStanding(trust=%.2f debt=%.2f attn=%.2f access=%.2f legit=%.2f ent=%.2f)" % [
		trust, debt, attention, access, legitimacy, entanglement,
	]
