extends Node
class_name CampaignSystems

var world: Node
var naval_events: Array[String] = []
var family_events: Array[String] = []
var last_day := -1
var naval_initialized := false

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_bind")

func _bind() -> void:
    var scene := get_tree().current_scene
    if scene:
        world = scene.get_node_or_null("WorldState")
    if world:
        last_day = int(world.day)

func _process(_delta: float) -> void:
    if world == null:
        _bind()
        return
    if int(world.day) != last_day:
        var d := int(world.day)
        last_day = d
        _daily_tick(d)

func _daily_tick(day: int) -> void:
    _move_ships()
    _resolve_naval_encounters()
    if day % 30 == 0:
        _advance_family_month()
    if day % 365 == 0:
        _advance_family_year()

func _move_ships() -> void:
    for ship in world.ships:
        if not bool(ship.get("moving", false)):
            continue
        var target := int(ship.get("target_region", ship.get("region", 0)))
        var current := int(ship.get("region", 0))
        if current == target:
            ship["moving"] = false
            continue
        var neighbors: Array[int] = world.get_region_neighbors(current)
        if neighbors.has(target):
            ship["region"] = target
        elif not neighbors.is_empty():
            ship["region"] = neighbors[0]
        else:
            ship["region"] = target
        if int(ship["region"]) == target:
            ship["moving"] = false

func _resolve_naval_encounters() -> void:
    for i in range(world.ships.size()):
        var a: Dictionary = world.ships[i]
        for j in range(i + 1, world.ships.size()):
            var b: Dictionary = world.ships[j]
            if int(a.get("region", -1)) != int(b.get("region", -2)):
                continue
            if String(a.get("owner","")) == String(b.get("owner","")):
                continue
            if not _at_war(String(a.get("owner","")), String(b.get("owner",""))):
                continue
            if randi_range(1,100) > 35:
                continue
            var result := naval_battle(i, j)
            if result.get("ok", false):
                naval_events.push_front(String(result["message"]))
                if naval_events.size() > 8:
                    naval_events.pop_back()
                return

func _at_war(a: String, b: String) -> bool:
    var key1 := a + "|" + b
    var key2 := b + "|" + a
    return String(world.diplomacy.get(key1, world.diplomacy.get(key2, "neutral"))) == "war"

func _ship_power(ship: Dictionary) -> float:
    var crew := int(ship.get("crew", 0))
    var cargo := ship.get("cargo", {})
    var cargo_value := 0
    if cargo is Dictionary:
        for value in cargo.values():
            cargo_value += int(value)
    return float(crew) * 2.0 + float(cargo_value) * 0.15 + float(ship.get("hull", 50)) * 0.6 + float(ship.get("cannons", 0)) * 12.0

func naval_battle(attacker_id: int, defender_id: int) -> Dictionary:
    if attacker_id < 0 or defender_id < 0 or attacker_id >= world.ships.size() or defender_id >= world.ships.size():
        return {"ok":false,"reason":"invalid_ship"}
    var a: Dictionary = world.ships[attacker_id]
    var b: Dictionary = world.ships[defender_id]
    var ap := _ship_power(a)
    var dp := _ship_power(b)
    var a_roll := ap * randf_range(0.80, 1.20)
    var d_roll := dp * randf_range(0.80, 1.20)
    var winner := attacker_id if a_roll >= d_roll else defender_id
    var loser := defender_id if winner == attacker_id else attacker_id
    var winning: Dictionary = world.ships[winner]
    var losing: Dictionary = world.ships[loser]
    var loss_ratio := clamp(0.20 + abs(a_roll-d_roll) / max(1.0, max(a_roll,d_roll)) * 0.35, 0.20, 0.65)
    var crew_loss := max(1, int(round(float(losing.get("crew",1)) * loss_ratio)))
    losing["crew"] = max(0, int(losing.get("crew",0)) - crew_loss)
    var loot := 0
    var cargo: Dictionary = losing.get("cargo", {})
    for key in cargo.keys():
        var amount := max(0, int(cargo[key]))
        var taken := int(round(float(amount) * 0.35))
        loot += taken
        cargo[key] = amount - taken
    var winner_cargo: Dictionary = winning.get("cargo", {})
    winner_cargo["loot"] = int(winner_cargo.get("loot",0)) + loot
    winning["cargo"] = winner_cargo
    losing["cargo"] = cargo
    var sunk := int(losing.get("crew",0)) == 0
    var message := "%s defeated %s at sea • %d crew lost • %d cargo seized" % [String(winning.get("name","Ship")),String(losing.get("name","Ship")),crew_loss,loot]
    if sunk:
        message += " • ship disabled"
    return {"ok":true,"winner":winner,"loser":loser,"crew_loss":crew_loss,"loot":loot,"sunk":sunk,"message":message}

func set_ship_route(ship_id: int, target_region: int) -> Dictionary:
    if ship_id < 0 or ship_id >= world.ships.size():
        return {"ok":false,"reason":"invalid_ship"}
    if target_region < 0 or target_region >= world.regions.size():
        return {"ok":false,"reason":"invalid_region"}
    var neighbors: Array[int] = world.get_region_neighbors(int(world.ships[ship_id].get("region",0)))
    if target_region != int(world.ships[ship_id].get("region",0)) and not neighbors.has(target_region):
        return {"ok":false,"reason":"not_adjacent"}
    world.ships[ship_id]["target_region"] = target_region
    world.ships[ship_id]["moving"] = true
    return {"ok":true}

func recruit_ship_crew(ship_id: int, amount: int) -> Dictionary:
    if ship_id < 0 or ship_id >= world.ships.size() or amount <= 0:
        return {"ok":false,"reason":"invalid_request"}
    var cost := amount * 4
    if int(world.gold) < cost:
        return {"ok":false,"reason":"not_enough_gold"}
    world.gold -= cost
    world.ships[ship_id]["crew"] = int(world.ships[ship_id].get("crew",0)) + amount
    return {"ok":true,"crew":int(world.ships[ship_id]["crew"])}

func _advance_family_month() -> void:
    world.family["age"] = int(world.family.get("age",18)) + 1
    for member in world.family_members:
        member["age"] = int(member.get("age",0)) + 1
        member["loyalty"] = clamp(int(member.get("loyalty",50)) + randi_range(-2,2),0,100)
    var heir_age := int(world.family.get("heir_age",0))
    if String(world.family.get("heir_name","Unnamed Heir")) != "Unnamed Heir":
        world.family["heir_age"] = heir_age + 1
    elif int(world.family["age"]) >= 28:
        world.family["heir_name"] = "First Heir"
        world.family["heir_age"] = 1
        family_events.push_front("A first heir has been born into the house.")
    if family_events.size() > 8:
        family_events.pop_back()

func _advance_family_year() -> void:
    var age := int(world.family.get("age",18))
    if age < 60:
        return
    var heir_name := String(world.family.get("heir_name","Unnamed Heir"))
    if heir_name == "Unnamed Heir":
        return
    world.family["generation"] = int(world.family.get("generation",1)) + 1
    world.family["age"] = 18
    world.family["heir_age"] = 0
    world.family["heir_name"] = "Unnamed Heir"
    family_events.push_front("Succession completed: the next generation now leads the Free Company.")
    if family_events.size() > 8:
        family_events.pop_back()

func get_family_status() -> String:
    return "Age %d • Generation %d • Heir %s (%d)" % [int(world.family.get("age",18)),int(world.family.get("generation",1)),String(world.family.get("heir_name","Unnamed Heir")),int(world.family.get("heir_age",0))]

func get_naval_status() -> String:
    var out := ""
    for ship in world.ships:
        out += "%s • crew %d • region %s • hull %d\n" % [String(ship.get("name","Ship")),int(ship.get("crew",0)),String(world.regions[int(ship.get("region",0))]["name"]),int(ship.get("hull",50))]
    return out

func get_recent_events() -> String:
    var out := "NAVAL EVENTS\n"
    for e in naval_events:
        out += "• " + e + "\n"
    out += "\nFAMILY EVENTS\n"
    for e in family_events:
        out += "• " + e + "\n"
    return out
