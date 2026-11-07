extends Node
class_name ReleaseArmyLogistics

## Army supply: consumption, resupply, attrition and morale pressure.

var game: Node3D
var world
var tick: float = 0.0
var last_event: String = "ARMY LOGISTICS ONLINE"
var resupplies: int = 0
var attrition_events: int = 0

func build(main_node: Node3D) -> void:
	game = main_node
	world = game.get("world_state")
	set_process(true)

func _process(delta: float) -> void:
	if world == null:
		world = game.get("world_state")
		return
	tick += delta
	if tick < 14.0:
		return
	tick = 0.0
	_update_supply()

func _update_supply() -> void:
	var supplied: int = 0
	var hungry: int = 0
	for army in world.armies:
		var soldiers: int = max(1, int(army.get("soldiers", 1)))
		var food: int = int(army.get("food", 0))
		var daily_need: int = max(1, int(ceil(float(soldiers) / 70.0)))
		var region: int = int(army.get("region", -1))
		var source = _nearest_owned_settlement(region, String(army.get("owner", "")))
		if source != null and food < 65:
			var stock: Dictionary = source.get("stockpile", {})
			var available: int = min(50, int(stock.get("food", 0)))
			if available > 0:
				var transfer: int = min(available, 65 - food)
				stock["food"] = available - transfer
				army["food"] = food + transfer
				food = int(army["food"])
				resupplies += 1
		army["food"] = max(0, food - daily_need)
		if int(army["food"]) <= 0:
			hungry += 1
			army["morale"] = max(0, int(army.get("morale", 70)) - 4)
			var losses: int = max(1, int(soldiers * 0.01))
			army["soldiers"] = max(1, soldiers - losses)
			attrition_events += 1
		else:
			supplied += 1
			if int(army.get("morale", 70)) < 80:
				army["morale"] = min(80, int(army.get("morale", 70)) + 1)
	last_event = "Supply update • %d supplied • %d hungry" % [supplied, hungry]

func _nearest_owned_settlement(region: int, owner: String):
	var best = null
	var best_distance: int = 999999
	for settlement in world.settlements:
		if String(settlement.get("owner", "")) != owner:
			continue
		var distance: int = abs(int(settlement.get("region", 0)) - region)
		if distance < best_distance:
			best_distance = distance
			best = settlement
	return best

func get_army_supply(army_id: int) -> Dictionary:
	for army in world.armies:
		if int(army.get("id", -1)) == army_id:
			return {"food": int(army.get("food", 0)), "soldiers": int(army.get("soldiers", 0)), "morale": int(army.get("morale", 0)), "status": "critical" if int(army.get("food", 0)) <= 0 else ("low" if int(army.get("food", 0)) < 30 else "supplied")}
	return {}

func get_state() -> Dictionary:
	return {"last_event": last_event, "resupplies": resupplies, "attrition_events": attrition_events}
