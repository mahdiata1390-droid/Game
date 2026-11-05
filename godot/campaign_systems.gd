extends Node
class_name CampaignSystems

var world: Node
var naval_events: Array[String] = []
var family_events: Array[String] = []
var last_day := -1
var naval_initialized := false
var succession_state: Dictionary = {"active":false,"heir":"","claim":0,"support":0,"regency":false}
var pending_naval_encounter: Dictionary = {}

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
        if bool(ship.get("disabled", false)) or int(ship.get("crew", 0)) <= 0:
            ship["moving"] = false
            continue
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
    if not pending_naval_encounter.is_empty():
        return
    for i in range(world.ships.size()):
        var a: Dictionary = world.ships[i]
        for j in range(i + 1, world.ships.size()):
            var b: Dictionary = world.ships[j]
            if int(a.get("region", -1)) != int(b.get("region", -2)):
                continue
            if bool(a.get("disabled", false)) or bool(b.get("disabled", false)):
                continue
            if int(a.get("crew",0)) <= 0 or int(b.get("crew",0)) <= 0:
                continue
            if String(a.get("owner","")) == String(b.get("owner","")):
                continue
            if not _at_war(String(a.get("owner","")), String(b.get("owner",""))):
                continue
            if randi_range(1,100) > 35:
                continue
            var a_player := String(a.get("owner","")) == "free_company"
            var b_player := String(b.get("owner","")) == "free_company"
            if a_player or b_player:
                pending_naval_encounter = {"player_ship": i if a_player else j, "enemy_ship": j if a_player else i, "region": int(a.get("region",0)), "day": int(world.day)}
                naval_events.push_front("Naval encounter detected: choose ENGAGE, AUTO, or RETREAT.")
                if naval_events.size() > 8:
                    naval_events.pop_back()
                return
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

func naval_battle(attacker_id: int, defender_id: int, player_engaged: bool = false) -> Dictionary:
    if attacker_id < 0 or defender_id < 0 or attacker_id >= world.ships.size() or defender_id >= world.ships.size():
        return {"ok":false,"reason":"invalid_ship"}
    var a: Dictionary = world.ships[attacker_id]
    var b: Dictionary = world.ships[defender_id]
    var ap := _ship_power(a)
    var dp := _ship_power(b)
    var a_roll := ap * randf_range(0.80, 1.20)
    var d_roll := dp * randf_range(0.80, 1.20)
    if player_engaged:
        if String(a.get("owner","")) == "free_company":
            a_roll *= 1.10
        if String(b.get("owner","")) == "free_company":
            d_roll *= 1.10
    var winner := attacker_id if a_roll >= d_roll else defender_id
    var loser := defender_id if winner == attacker_id else attacker_id
    var winning: Dictionary = world.ships[winner]
    var losing: Dictionary = world.ships[loser]
    var loss_ratio := clamp(0.20 + abs(a_roll-d_roll) / max(1.0, max(a_roll,d_roll)) * 0.35, 0.20, 0.65)
    var crew_loss := max(1, int(round(float(losing.get("crew",1)) * loss_ratio)))
    var hull_damage := max(5, int(round(12.0 + loss_ratio * 35.0)))
    losing["crew"] = max(0, int(losing.get("crew",0)) - crew_loss)
    losing["hull"] = max(0, int(losing.get("hull",50)) - hull_damage)
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
    var disabled := int(losing.get("crew",0)) == 0 or int(losing.get("hull",50)) <= 0
    losing["disabled"] = disabled
    losing["moving"] = false
    var message := "%s defeated %s at sea • %d crew lost • %d hull damage • %d cargo seized" % [String(winning.get("name","Ship")),String(losing.get("name","Ship")),crew_loss,hull_damage,loot]
    if disabled:
        message += " • ship disabled"
    return {"ok":true,"winner":winner,"loser":loser,"crew_loss":crew_loss,"hull_damage":hull_damage,"loot":loot,"disabled":disabled,"message":message}


func has_pending_naval_encounter() -> bool:
    return not pending_naval_encounter.is_empty()

func get_pending_naval_encounter() -> Dictionary:
    return pending_naval_encounter.duplicate(true)

func resolve_pending_naval_encounter(mode: String) -> Dictionary:
    if pending_naval_encounter.is_empty():
        return {"ok":false,"reason":"no_pending_encounter"}
    var player_id := int(pending_naval_encounter.get("player_ship",-1))
    var enemy_id := int(pending_naval_encounter.get("enemy_ship",-1))
    if player_id < 0 or enemy_id < 0 or player_id >= world.ships.size() or enemy_id >= world.ships.size():
        pending_naval_encounter.clear()
        return {"ok":false,"reason":"invalid_encounter"}
    if mode == "retreat":
        var region := int(world.ships[player_id].get("region",0))
        var neighbors: Array[int] = world.get_region_neighbors(region)
        if neighbors.is_empty():
            return {"ok":false,"reason":"no_retreat_route"}
        var target := neighbors[0]
        world.ships[player_id]["target_region"] = target
        world.ships[player_id]["moving"] = true
        pending_naval_encounter.clear()
        var message := "%s retreated toward %s." % [String(world.ships[player_id].get("name","Ship")), String(world.regions[target].get("name","Region"))]
        naval_events.push_front(message)
        if naval_events.size() > 8:
            naval_events.pop_back()
        return {"ok":true,"mode":"retreat","message":message}
    var result := naval_battle(player_id, enemy_id, mode == "engage")
    if result.get("ok",false):
        pending_naval_encounter.clear()
        naval_events.push_front(String(result.get("message","Naval battle resolved.")))
        if naval_events.size() > 8:
            naval_events.pop_back()
    return result

func acquire_player_ship() -> Dictionary:
    if world == null:
        return {"ok":false,"reason":"world_unavailable"}
    var cost := 300
    if int(world.gold) < cost:
        return {"ok":false,"reason":"not_enough_gold","cost":cost}
    var region := int(world.player_region_id)
    var ship_id := world.ships.size()
    world.gold -= cost
    world.ships.append({
        "id":ship_id,
        "name":"Free Company Galley %d" % (ship_id + 1),
        "owner":"free_company",
        "region":region,
        "crew":20,
        "cargo":{"food":10,"wood":5,"iron":2},
        "moving":false,
        "target_region":region,
        "hull":100,
        "max_hull":100,
        "cannons":2,
        "cargo_capacity":100,
        "disabled":false
    })
    naval_events.push_front("The Free Company acquired a new galley.")
    if naval_events.size() > 8:
        naval_events.pop_back()
    return {"ok":true,"ship_id":ship_id,"cost":cost}

func get_player_ship_ids() -> Array[int]:
    var ids: Array[int] = []
    if world == null:
        return ids
    for i in range(world.ships.size()):
        if String(world.ships[i].get("owner","")) == "free_company":
            ids.append(i)
    return ids


func upgrade_ship(ship_id: int, stat: String) -> Dictionary:
    if ship_id < 0 or ship_id >= world.ships.size():
        return {"ok":false,"reason":"invalid_ship"}
    var ship: Dictionary = world.ships[ship_id]
    if String(ship.get("owner","")) != "free_company":
        return {"ok":false,"reason":"not_player_ship"}
    var level_key := stat + "_level"
    var level := int(ship.get(level_key, 0))
    if level >= 3:
        return {"ok":false,"reason":"max_level"}
    var cost := 150 + level * 100
    if int(world.gold) < cost:
        return {"ok":false,"reason":"not_enough_gold","cost":cost}
    world.gold -= cost
    ship[level_key] = level + 1
    match stat:
        "hull":
            ship["max_hull"] = 100 + (level + 1) * 10
            ship["hull"] = int(ship["max_hull"])
        "cannons":
            ship["cannons"] = int(ship.get("cannons", 0)) + 2
        "cargo":
            ship["cargo_capacity"] = int(ship.get("cargo_capacity", 100)) + 30
    naval_events.push_front("%s upgraded: %s level %d." % [String(ship.get("name","Ship")), stat, level + 1])
    if naval_events.size() > 8:
        naval_events.pop_back()
    return {"ok":true,"stat":stat,"level":level + 1,"cost":cost}

func get_ship_upgrade_status(ship_id: int) -> String:
    if ship_id < 0 or ship_id >= world.ships.size():
        return "Invalid ship."
    var ship: Dictionary = world.ships[ship_id]
    return "Hull Lv%d • Cannons Lv%d • Cargo Lv%d" % [
        int(ship.get("hull_level",0)),
        int(ship.get("cannons_level",0)),
        int(ship.get("cargo_level",0))
    ]

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
    var heir_name := String(world.family.get("heir_name","Unnamed Heir"))
    if age >= 45 and heir_name != "Unnamed Heir" and not bool(succession_state.get("active",false)):
        succession_state["active"] = true
        succession_state["heir"] = heir_name
        succession_state["claim"] = clamp(40 + int(world.family.get("heir_age",0)), 40, 90)
        succession_state["support"] = int(succession_state.get("support",50))
        succession_state["regency"] = age < 60
        family_events.push_front("%s is now formally recognized as heir to the Free Company." % heir_name)
    if age < 60 or heir_name == "Unnamed Heir":
        return
    var support := int(succession_state.get("support",50))
    var claim := int(succession_state.get("claim",50))
    if support + claim < 100:
        family_events.push_front("Succession delayed: the heir lacks enough support.")
        return
    _complete_succession(heir_name)

func _complete_succession(heir_name: String) -> void:
    var old_generation := int(world.family.get("generation",1))
    world.family["generation"] = old_generation + 1
    world.family["age"] = 18
    world.family["heir_age"] = 0
    world.family["heir_name"] = "Unnamed Heir"
    for member in world.family_members:
        if String(member.get("name","")) == heir_name:
            member["title"] = "House Leader"
            member["loyalty"] = clamp(int(member.get("loyalty",70)) + 10, 0, 100)
        else:
            member["loyalty"] = clamp(int(member.get("loyalty",50)) - 2, 0, 100)
    for settlement in world.settlements:
        if String(settlement.get("owner","")) == "free_company":
            settlement["prosperity"] = max(0, int(settlement.get("prosperity",50)) - 2)
    for army in world.armies:
        if String(army.get("owner","")) == "free_company":
            army["morale"] = clamp(int(army.get("morale",50)) - 4, 0, 100)
    succession_state = {"active":false,"heir":"","claim":0,"support":0,"regency":false}
    family_events.push_front("Succession completed: %s now leads the Free Company. The realm enters a new generation." % heir_name)
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

func appoint_heir(member_name: String) -> Dictionary:
    for member in world.family_members:
        if String(member.get("name","")) == member_name:
            world.family["heir_name"] = member_name
            world.family["heir_age"] = int(member.get("age",0))
            succession_state["active"] = true
            succession_state["heir"] = member_name
            succession_state["claim"] = clamp(35 + int(member.get("age",0)), 35, 90)
            succession_state["support"] = int(member.get("loyalty",50))
            succession_state["regency"] = int(world.family.get("age",18)) < 60
            family_events.push_front("%s was appointed as heir." % member_name)
            return {"ok":true,"heir":member_name}
    return {"ok":false,"reason":"member_not_found"}

func change_heir_support(amount: int) -> Dictionary:
    if not bool(succession_state.get("active",false)):
        return {"ok":false,"reason":"no_heir"}
    succession_state["support"] = clamp(int(succession_state.get("support",50)) + amount, 0, 100)
    return {"ok":true,"support":int(succession_state["support"])}

func get_succession_status() -> String:
    if not bool(succession_state.get("active",false)):
        return "No active succession claim."
    return "Heir: %s • Claim %d • Support %d • %s" % [
        String(succession_state.get("heir","Unknown")),
        int(succession_state.get("claim",0)),
        int(succession_state.get("support",0)),
        ("Regency possible" if bool(succession_state.get("regency",false)) else "Direct succession")
    ]


func transfer_cargo(ship_id: int, resource: String, amount: int) -> Dictionary:
    if ship_id < 0 or ship_id >= world.ships.size() or amount <= 0:
        return {"ok":false,"reason":"invalid_request"}
    if String(world.ships[ship_id].get("owner","")) != "free_company":
        return {"ok":false,"reason":"not_player_ship"}
    if not ["food","wood","iron"].has(resource):
        return {"ok":false,"reason":"invalid_resource"}
    var ship: Dictionary = world.ships[ship_id]
    var cargo: Dictionary = ship.get("cargo", {})
    var current := 0
    for key in cargo.keys():
        current += int(cargo[key])
    var capacity := int(ship.get("cargo_capacity",100))
    var available := max(0, capacity - current)
    var moved := min(amount, available)
    if moved <= 0:
        return {"ok":false,"reason":"cargo_full"}
    var stock := int(world.production_stock.get(resource,0))
    moved = min(moved, stock)
    if moved <= 0:
        return {"ok":false,"reason":"no_stock"}
    world.production_stock[resource] = stock - moved
    cargo[resource] = int(cargo.get(resource,0)) + moved
    ship["cargo"] = cargo
    return {"ok":true,"resource":resource,"amount":moved,"capacity":capacity}

func repair_ship(ship_id: int) -> Dictionary:
    if ship_id < 0 or ship_id >= world.ships.size():
        return {"ok":false,"reason":"invalid_ship"}
    var ship: Dictionary = world.ships[ship_id]
    var max_hull := int(ship.get("max_hull",100))
    var missing := max_hull - int(ship.get("hull",50))
    if missing <= 0:
        return {"ok":false,"reason":"already_repaired"}
    var cost := max(5, missing * 2)
    if int(world.gold) < cost:
        return {"ok":false,"reason":"not_enough_gold","cost":cost}
    world.gold -= cost
    ship["hull"] = max_hull
    ship["disabled"] = false
    ship["moving"] = false
    return {"ok":true,"cost":cost,"hull":max_hull}
