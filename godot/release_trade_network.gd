extends Node
class_name ReleaseTradeNetwork

## Dynamic trade network: routes, shortages, demand pressure and caravan risk.

var game: Node3D
var world
var tick: float = 0.0
var last_event: String = "TRADE NETWORK ONLINE"

func build(main_node: Node3D) -> void:
	game = main_node
	world = game.get("world_state")
	set_process(true)

func _process(delta: float) -> void:
	if world == null:
		world = game.get("world_state")
		return
	tick += delta
	if tick < 18.0:
		return
	tick = 0.0
	_update_trade_network()

func _update_trade_network() -> void:
	var routes: Array = []
	var settlements = world.settlements
	for i in range(settlements.size()):
		for j in range(i + 1, settlements.size()):
			var a: Dictionary = settlements[i]
			var b: Dictionary = settlements[j]
			var region_distance: int = abs(int(a.get("region", 0)) - int(b.get("region", 0)))
			if region_distance > 3:
				continue
			var a_owner: String = String(a.get("owner", ""))
			var b_owner: String = String(b.get("owner", ""))
			if a_owner == b_owner or world.get_diplomacy_state(a_owner, b_owner) in ["peace", "trade", "alliance"]:
				var volume: int = 10 + int(a.get("prosperity", 50) / 10) + int(b.get("prosperity", 50) / 10)
				routes.append({"from": i, "to": j, "distance": region_distance, "volume": volume})
				if routes.size() >= 12:
					break
		if routes.size() >= 12:
			break

	var shortages: Array = []
	for settlement in settlements:
		var stock: Dictionary = settlement.get("stockpile", {})
		var demand: int = max(10, int(settlement.get("population", 100)) / 80)
		var food: int = int(stock.get("food", 0))
		var wood: int = int(stock.get("wood", 0))
		var iron: int = int(stock.get("iron", 0))
		settlement["trade_demand"] = {"food": demand, "wood": max(5, demand / 2), "iron": max(3, demand / 3)}
		if food < demand:
			shortages.append(String(settlement.get("name", "Settlement")) + ":food")
		if wood < demand / 2:
			shortages.append(String(settlement.get("name", "Settlement")) + ":wood")
		if iron < demand / 3:
			shortages.append(String(settlement.get("name", "Settlement")) + ":iron")

	world.set_meta("trade_routes", routes)
	world.set_meta("trade_shortages", shortages)
	last_event = "Trade network updated • %d routes • %d shortages" % [routes.size(), shortages.size()]

func get_state() -> Dictionary:
	return {
		"last_event": last_event,
		"routes": world.get_meta("trade_routes", []),
		"shortages": world.get_meta("trade_shortages", [])
	}
