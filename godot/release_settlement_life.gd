extends Node
class_name ReleaseSettlementLife

## Settlement life simulation: workforce, food pressure, garrison upkeep,
## satisfaction, militia readiness and local prosperity feedback.

var game: Node3D
var world
var tick: float = 0.0
var last_event: String = "SETTLEMENT LIFE ONLINE"

func build(main_node: Node3D) -> void:
	game = main_node
	world = game.get("world_state")
	set_process(true)

func _process(delta: float) -> void:
	if world == null:
		world = game.get("world_state")
		return
	tick += delta
	if tick < 15.0:
		return
	tick = 0.0
	_simulate_settlement_life()

func _simulate_settlement_life() -> void:
	var affected: int = 0
	for settlement in world.settlements:
		var population: int = max(1, int(settlement.get("population", 100)))
		var prosperity: int = int(settlement.get("prosperity", 50))
		var buildings: Dictionary = settlement.get("buildings", {})
		var stock: Dictionary = settlement.get("stockpile", {})
		var food: int = int(stock.get("food", 0))
		var garrison: int = int(settlement.get("garrison", 0))
		var farm: int = int(buildings.get("farm", 1))
		var market: int = int(buildings.get("market", 1))
		var barracks: int = int(buildings.get("barracks", 1))
		var workshop: int = int(buildings.get("workshop", 1))

		var food_need: int = max(2, int(population / 120))
		var food_supply: int = food + farm * 3
		var satisfaction: int = int(settlement.get("satisfaction", 55))

		if food_supply >= food_need * 3:
			satisfaction += 2
			prosperity += 1
		elif food_supply < food_need:
			satisfaction -= 5
			prosperity -= 2
		else:
			satisfaction -= 1

		var garrison_ratio: float = float(garrison) / float(max(1, population))
		if garrison_ratio > 0.08:
			satisfaction -= 2
		elif garrison_ratio > 0.04:
			satisfaction -= 1

		if market >= 3:
			satisfaction += 1
		if workshop >= 3:
			prosperity += 1
		if barracks >= 3:
			satisfaction += 1

		var militia_cap: int = max(5, int(population / 35) + barracks * 4)
		var militia_ready: int = int(settlement.get("militia_ready", min(militia_cap, garrison)))
		if satisfaction >= 60:
			militia_ready = min(militia_cap, militia_ready + 2)
		elif satisfaction < 35:
			militia_ready = max(0, militia_ready - 2)

		var tax_rate: float = clampf(float(settlement.get("tax_rate", 0.10)), 0.05, 0.20)
		if satisfaction < 30:
			tax_rate = max(0.05, tax_rate - 0.01)
		elif satisfaction > 75:
			tax_rate = min(0.20, tax_rate + 0.005)

		settlement["satisfaction"] = clampi(satisfaction, 0, 100)
		settlement["prosperity"] = clampi(prosperity, 0, 100)
		settlement["militia_ready"] = militia_ready
		settlement["militia_cap"] = militia_cap
		settlement["tax_rate"] = tax_rate
		settlement["food_demand"] = food_need
		settlement["workforce"] = max(0, population - garrison)
		affected += 1

	last_event = "Settlement life updated • %d settlements" % affected

func get_settlement_status(settlement_id: int) -> Dictionary:
	if world == null or settlement_id < 0 or settlement_id >= world.settlements.size():
		return {}
	var settlement: Dictionary = world.settlements[settlement_id]
	return {
		"name": String(settlement.get("name", "Settlement")),
		"population": int(settlement.get("population", 0)),
		"satisfaction": int(settlement.get("satisfaction", 55)),
		"prosperity": int(settlement.get("prosperity", 50)),
		"garrison": int(settlement.get("garrison", 0)),
		"militia_ready": int(settlement.get("militia_ready", 0)),
		"militia_cap": int(settlement.get("militia_cap", 0)),
		"workforce": int(settlement.get("workforce", 0)),
		"food_demand": int(settlement.get("food_demand", 0)),
		"tax_rate": float(settlement.get("tax_rate", 0.10))
	}

func get_state() -> Dictionary:
	return {"last_event": last_event}
