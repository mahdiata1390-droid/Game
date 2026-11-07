extends Node
class_name ReleaseEconomyBalance

var game: Node3D
var world
var tick: float = 0.0
var last_event: String = "ECONOMY BALANCE READY"

func build(root: Node3D) -> void:
    game = root
    world = root.get("world_state")
    set_process(true)
    _refresh()

func _process(delta: float) -> void:
    tick += delta
    if tick >= 15.0:
        tick = 0.0
        _refresh()

func _refresh() -> void:
    if world == null:
        world = game.get("world_state")
    if world == null:
        return
    for i in range(world.settlements.size()):
        var settlement: Dictionary = world.settlements[i]
        var prosperity: int = clampi(int(settlement.get("prosperity",50)),0,100)
        var stock: Dictionary = settlement.get("stockpile",{})
        var food: int = int(stock.get("food",0))
        var wood: int = int(stock.get("wood",0))
        var iron: int = int(stock.get("iron",0))
        var food_pressure: int = 0 if food >= 30 else 10
        var market_index: int = clampi(100 + (50 - prosperity) + food_pressure - min(20,wood / 10) - min(20,iron / 10),70,180)
        settlement["market_index"] = market_index
        settlement["food_shortage"] = food < 10
        settlement["wealth"] = clampi(prosperity * 10 + food + wood + iron,0,2000)
        world.settlements[i] = settlement
    last_event = "Prices, shortages and settlement wealth rebalanced"

func get_market(settlement_id: int) -> Dictionary:
    if world == null or settlement_id < 0 or settlement_id >= world.settlements.size():
        return {}
    var s: Dictionary = world.settlements[settlement_id]
    return {
        "index":int(s.get("market_index",100)),
        "wealth":int(s.get("wealth",0)),
        "food_shortage":bool(s.get("food_shortage",false))
    }

func get_state() -> Dictionary:
    return {"last_event":last_event}
