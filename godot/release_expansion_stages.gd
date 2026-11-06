extends Node
class_name ReleaseExpansionStages

# Stages 6-9: world travel, economy, family/succession and naval campaign.
# These layers are intentionally data-driven and reuse WorldState as authority.

var game: Node3D
var world: Node
var tick = 0.0
var travel: Dictionary = {}
var economy: Dictionary = {}
var family: Dictionary = {}
var naval: Dictionary = {}
var status_label: Label

func build(main_node: Node3D) -> void:
    game = main_node
    world = game.get("world_state")
    _create_ui()
    set_process(true)

func _process(delta: float) -> void:
    if world == null:
        world = game.get("world_state")
        return
    tick += delta
    _update_travel(delta)
    if tick >= 5.0:
        tick = 0.0
        _economy_tick()
        _family_tick()
        _naval_tick()
        _update_status()

# ---------------- Stage 6: World Map + Travel ----------------

func travel_to_region(target_region: int) -> Dictionary:
    if target_region < 0 or target_region >= world.regions.size():
        return {"ok":false,"reason":"invalid_region"}
    var start = int(world.get("player_region_id"))
    var route = _find_route(start,target_region)
    if route.is_empty():
        return {"ok":false,"reason":"no_route"}
    travel = {"active":true,"route":route,"index":0,"progress":0.0,"speed":1.0}
    world.set_meta("player_travel_route",route)
    world.set_meta("player_travel_active",true)
    return {"ok":true,"route":route}

func _find_route(start:int,target:int) -> Array:
    if start == target:
        return [start]
    if not world.has_method("get_region_neighbors"):
        return []
    var queue = [start]
    var previous = {start:-1}
    var head = 0
    while head < queue.size():
        var current:int = queue[head]
        head += 1
        for next in world.get_region_neighbors(current):
            if previous.has(next):
                continue
            previous[next] = current
            if next == target:
                var route:Array = [target]
                var cursor = target
                while int(previous[cursor]) != -1:
                    cursor = int(previous[cursor])
                    route.push_front(cursor)
                return route
            queue.append(next)
    return []

func _update_travel(delta:float) -> void:
    if not bool(travel.get("active",false)):
        return
    travel["progress"] = float(travel.get("progress",0.0)) + delta * 0.12 * float(travel.get("speed",1.0))
    if float(travel["progress"]) < 1.0:
        return
    travel["progress"] = 0.0
    var route:Array = travel.get("route",[])
    var idx = int(travel.get("index",0)) + 1
    if idx >= route.size():
        travel["active"] = false
        world.set_meta("player_travel_active",false)
        return
    travel["index"] = idx
    if world.has_method("set"):
        world.set("player_region_id",int(route[idx]))

func get_travel_state() -> Dictionary:
    return travel.duplicate(true)

# ---------------- Stage 7: Economy + Trade ----------------

func trade(settlement_id:int, resource:String, amount:int, buy:bool) -> Dictionary:
    if settlement_id < 0 or settlement_id >= world.settlements.size() or amount <= 0:
        return {"ok":false,"reason":"invalid_trade"}
    var s:Dictionary = world.settlements[settlement_id]
    var stock:Dictionary = s.get("resources",{})
    var key = String(resource)
    var current = int(stock.get(key,0))
    var price = _resource_price(s,key)
    var gold = int(world.get("gold"))
    if buy:
        var cost = price * amount
        if current < amount or gold < cost:
            return {"ok":false,"reason":"insufficient_stock_or_gold"}
        stock[key] = current - amount
        world.set("gold",gold-cost)
        economy["last_trade"] = "Bought %d %s" % [amount,key]
    else:
        stock[key] = current + amount
        world.set("gold",gold+int(price*amount*0.8))
        economy["last_trade"] = "Sold %d %s" % [amount,key]
    s["resources"] = stock
    s["prosperity"] = clampi(int(s.get("prosperity",50)) + (1 if buy else 2),0,100)
    world.set("gold",int(world.get("gold")))
    return {"ok":true,"price":price,"gold":world.get("gold"),"stock":stock.get(key,0)}

func _resource_price(s:Dictionary,key:String) -> int:
    var base = {"food":4,"wood":6,"stone":8,"iron":12,"cloth":10,"horses":20}.get(key,7)
    var stock = int(s.get("resources",{}).get(key,20))
    var prosperity = int(s.get("prosperity",50))
    return max(1,int(float(base) * (1.35 - min(stock,100)/180.0) * (0.8 + prosperity/250.0)))

func _economy_tick() -> void:
    for s in world.settlements:
        var resources:Dictionary = s.get("resources",{})
        var prosperity = int(s.get("prosperity",50))
        resources["food"] = int(resources.get("food",20)) + max(1,prosperity/35)
        resources["wood"] = int(resources.get("wood",20)) + max(1,prosperity/55)
        if int(resources.get("food",0)) > 120:
            prosperity = min(100,prosperity+1)
        elif int(resources.get("food",0)) < 10:
            prosperity = max(0,prosperity-2)
        s["resources"] = resources
        s["prosperity"] = prosperity

# ---------------- Stage 8: Family + Generations ----------------

func add_family_member_role(role:String,name:String) -> Dictionary:
    if not family.has("members"):
        family["members"] = []
    var id = int(family.get("next_id",1))
    family["next_id"] = id + 1
    family["members"].append({"id":id,"name":name,"role":role,"age":18,"loyalty":70,"alive":true})
    return {"ok":true,"id":id}

func _family_tick() -> void:
    if not family.has("members"):
        family["members"] = []
    for member in family["members"]:
        if not bool(member.get("alive",true)):
            continue
        member["age"] = int(member.get("age",18)) + 1
        member["loyalty"] = clampi(int(member.get("loyalty",70)) + (1 if member.get("role","") == "heir" else 0),0,100)
    _update_heir()

func _update_heir() -> void:
    var best_id = -1
    var best_score = -1
    for member in family.get("members",[]):
        if not bool(member.get("alive",true)):
            continue
        var score = int(member.get("age",0))*2 + int(member.get("loyalty",0))
        if String(member.get("role","")) == "heir":
            score += 50
        if score > best_score:
            best_score = score
            best_id = int(member.get("id",-1))
    family["heir_id"] = best_id

func get_family_state() -> Dictionary:
    return family.duplicate(true)

# ---------------- Stage 9: Naval Campaign ----------------

func create_naval_route(ship_id:int,target_port:int) -> Dictionary:
    if ship_id < 0 or ship_id >= world.ships.size():
        return {"ok":false,"reason":"invalid_ship"}
    naval["ship_id"] = ship_id
    naval["target_port"] = target_port
    naval["active"] = true
    naval["progress"] = 0.0
    if world.has_method("issue_ship_move"):
        var result = world.issue_ship_move(ship_id,target_port)
        if result is Dictionary and not bool(result.get("ok",true)):
            naval["active"] = false
            return result
    return {"ok":true,"ship":ship_id,"target":target_port}

func _naval_tick() -> void:
    if not bool(naval.get("active",false)):
        return
    naval["progress"] = float(naval.get("progress",0.0)) + 0.1
    var ship_id = int(naval.get("ship_id",-1))
    if ship_id >= 0 and ship_id < world.ships.size():
        var ship:Dictionary = world.ships[ship_id]
        ship["fatigue"] = min(100,int(ship.get("fatigue",0))+1)
        if int(ship.get("fatigue",0)) >= 100:
            ship["status"] = "needs_repair"
        world.ships[ship_id] = ship
    if float(naval["progress"]) >= 1.0:
        naval["active"] = false
        naval["progress"] = 0.0

func get_naval_state() -> Dictionary:
    return naval.duplicate(true)

func _create_ui() -> void:
    var layer = CanvasLayer.new()
    layer.name = "ExpansionStagesUI"
    game.add_child(layer)
    var panel = Panel.new()
    panel.position = Vector2(18,320)
    panel.size = Vector2(330,80)
    panel.modulate.a = 0.88
    layer.add_child(panel)
    status_label = Label.new()
    status_label.position = Vector2(10,8)
    status_label.size = Vector2(310,65)
    status_label.text = "WORLD SYSTEMS\nTravel • Economy • Family • Naval"
    panel.add_child(status_label)

func _update_status() -> void:
    if not is_instance_valid(status_label):
        return
    var route:Array = travel.get("route",[])
    status_label.text = "WORLD SYSTEMS\nTravel:%s  Trade:%s\nHeir:%s  Naval:%s" % [
        "ON" if bool(travel.get("active",false)) else "READY",
        String(economy.get("last_trade","READY")),
        str(family.get("heir_id",-1)),
        "ON" if bool(naval.get("active",false)) else "READY"
    ]

func get_save_state() -> Dictionary:
    return {"travel":travel.duplicate(true),"economy":economy.duplicate(true),"family":family.duplicate(true),"naval":naval.duplicate(true)}

func load_save_state(data:Dictionary) -> void:
    travel = data.get("travel",{}).duplicate(true)
    economy = data.get("economy",{}).duplicate(true)
    family = data.get("family",{}).duplicate(true)
    naval = data.get("naval",{}).duplicate(true)
