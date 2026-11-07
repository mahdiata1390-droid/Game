extends Node
class_name ReleaseTradeNetwork

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
	var shortages: Array = []
	for i in range(world.settlements.size()):
		var a: Dictionary = world.settlements[i]
		var a_owner: String = String(a.get("owner", ""))
		for j in range(i + 1, world.settlements.size()):
			var b: Dictionary = world.settlements[j]
			var b_owner: String = String(b.get("owner", ""))
			var distance: int = abs(int(a.get("region", 0)) - int(b.get("region", 0)))
			var relation: String = String(world.get_diplomacy_state(a_owner, b_owner))
			if distance <= 3 and (a_owner == b_owner or relation in ["peace", "trade", "alliance"]):
				routes.append({"from": i, "to": j, "distance": distance, "volume": 10 + int(a.get("prosperity", 50) / 10)})
				if routes.size() >= 12:
					break
		if routes.size() >= 12:
			break
	for settlement in world.settlements:
		var stock: Dictionary = settlement.get("stockpile", {})
		var demand: int = max(10, int(settlement.get("population", 100)) / 80)
		settlement["trade_demand"] = {"food": demand, "wood": max(5, demand / 2), "iron": max(3, demand / 3)}
		if int(stock.get("food", 0)) < demand:
			shortages.append(String(settlement.get("name", "Settlement")) + ":food")
		if int(stock.get("wood", 0)) < demand / 2:
			shortages.append(String(settlement.get("name", "Settlement")) + ":wood")
		if int(stock.get("iron", 0)) < demand / 3:
			shortages.append(String(settlement.get("name", "Settlement")) + ":iron")
	world.set_meta("trade_routes", routes)
	world.set_meta("trade_shortages", shortages)
	last_event = "Trade network updated • %d routes • %d shortages" % [routes.size(), shortages.size()]

func get_state() -> Dictionary:
	return {"last_event": last_event, "routes": world.get_meta("trade_routes", []), "shortages": world.get_meta("trade_shortages", [])}
