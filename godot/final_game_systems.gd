extends Node
class_name FinalGameSystems

# Final gameplay layer: deeper economy, diplomacy, technology, population,
# equipment progression, trade, family, ships, wildlife, creatures and world events.
# It intentionally sits above WorldState so the existing save/battle architecture
# remains compatible while the world gains persistent consequences.

var world: WorldState
var initialized := false
var last_day := 0
var technology := {
    "agriculture": 0, "smithing": 0, "commerce": 0,
    "engineering": 0, "navigation": 0, "medicine": 0, "warfare": 0, "mysticism": 0
}
var player_stats := {"strength": 10, "leadership": 10, "tactics": 10, "trade": 5, "medicine": 3, "magic": 0}
var equipment_levels := {"weapon": 1, "armor": 1, "shield": 1, "horse": 0}
var relationships: Dictionary = {}
var npcs: Array[Dictionary] = []
var trade_routes: Array[Dictionary] = []
var wildlife: Array[Dictionary] = []
var creatures: Array[Dictionary] = []
var rebellions: Array[Dictionary] = []
var technology_points := 0
var renown := 0
var laws := {"tax": 10, "conscription": 5, "trade_duty": 5}
var player_title := "Wanderer"
var player_house := "Free Company"
var world_seed := 734921
var political_influence := 25
var political_events: Array[String] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    randomize()
    set_process(true)

func get_world_event_summary() -> String:
	var out := "WORLD EVENTS\n"
	if rebellions.is_empty():
		out += "• No active rebellions.\n"
	else:
		for rebellion in rebellions:
			out += "• %s • strength %d • pressure %d\n" % [String(rebellion.get("settlement","Unknown")),int(rebellion.get("strength",0)),int(rebellion.get("pressure",0))]
	return out

func resolve_rebellion(index: int, support: bool) -> Dictionary:
	if index < 0 or index >= rebellions.size():
		return {"ok":false,"reason":"invalid_rebellion"}
	var rebellion: Dictionary = rebellions[index]
	var settlement_name := String(rebellion.get("settlement",""))
	var delta := 15 if support else -20
	rebellion["pressure"] = clamp(int(rebellion.get("pressure",50)) + delta,0,100)
	if int(rebellion["pressure"]) >= 100:
		return {"ok":false,"reason":"rebellion_escallated","settlement":settlement_name}
	if int(rebellion["pressure"]) <= 0:
		rebellions.remove_at(index)
		renown += 2
		return {"ok":true,"message":"Rebellion resolved at " + settlement_name}
	return {"ok":true,"message":"Rebellion pressure changed at " + settlement_name}

func _process(_delta: float) -> void:
    if world and world.simulation_paused:
        return
    if not initialized:
        var scene := get_tree().current_scene
        if scene:
            world = scene.get_node_or_null("WorldState") as WorldState
            if world:
                _initialize_final_layer()
    elif world and world.day != last_day:
        _on_new_day(world.day)

func _initialize_final_layer() -> void:
    if initialized:
        return
    initialized = true
    last_day = world.day
    technology_points = 3
    _build_npcs()
    _build_trade_routes()
    _build_wildlife()
    _build_creatures()
    _sync_faction_relations()
    _apply_starting_mode()
    _emit_event("The continent is fully simulated: trade, technology, population, diplomacy and independent life are active.")

func _build_npcs() -> void:
    npcs.clear()
    var names := ["Aldric","Mira","Ronan","Elena","Tarek","Sorin","Freya","Nadir","Bran","Selene","Khaled","Ysra"]
    for i in range(names.size()):
        var faction := "Free Company"
        if i % 5 == 1: faction = "north_kingdom"
        elif i % 5 == 2: faction = "river_kingdom"
        elif i % 5 == 3: faction = "eastern_tribes"
        elif i % 5 == 4: faction = "southern_sultanate"
        npcs.append({
            "id": i, "name": names[i], "faction": faction, "age": 18 + i * 3,
            "role": ["merchant","soldier","farmer","smith"][i % 4],
            "alive": true, "loyalty": 55 + (i * 3) % 35, "skill": 3 + i % 8,
            "region": i % max(1, world.regions.size())
        })

func _build_trade_routes() -> void:
    trade_routes.clear()
    for i in range(world.regions.size()):
        var target := (i + 1) % world.regions.size()
        trade_routes.append({
            "id": i, "from": i, "to": target, "goods": _resource_for_region(i),
            "value": 20 + (i * 7) % 45, "risk": 10 + (i * 11) % 55,
            "active": true, "days": 2 + i % 4
        })

func _build_wildlife() -> void:
    wildlife.clear()
    for i in range(18):
        wildlife.append({
            "id": i, "kind": ["wolf","boar","deer","bear"][i % 4],
            "region": i % max(1, world.regions.size()), "count": 4 + i % 8,
            "aggression": 15 + i % 35
        })

func _build_creatures() -> void:
    creatures.clear()
    # Rare encounters are part of the real world rather than required story bosses.
    creatures.append({"id":0,"kind":"Wyvern","region":3,"hp":420,"power":55,"alive":true,"rare":true})
    creatures.append({"id":1,"kind":"Ancient Bear","region":0,"hp":260,"power":32,"alive":true,"rare":false})
    creatures.append({"id":2,"kind":"Sand Wyrm","region":10,"hp":500,"power":65,"alive":true,"rare":true})

func _apply_starting_mode() -> void:
    var mode := String(world.player_start)
    if mode == "king":
        player_title = "King"
        renown = 100
        player_stats["leadership"] += 8
        technology_points += 4
        world.gold += 800
    elif mode == "nomad":
        player_title = "Khan"
        renown = 70
        player_stats["tactics"] += 6
        player_stats["trade"] += 4
        technology_points += 2
    else:
        player_title = "Wanderer"
        renown = 10

func _on_new_day(day: int) -> void:
    last_day = day
    _simulate_trade()
    _simulate_npcs()
    _simulate_diplomacy()
    _simulate_rebellions()
    _simulate_wildlife()
    _simulate_creatures()
    _update_technology()
    _update_equipment()
    if day % 7 == 0:
        _weekly_world_tick()
    if day % 30 == 0:
        _monthly_family_tick()

func _simulate_trade() -> void:
    for route in trade_routes:
        if not bool(route["active"]):
            continue
        route["days"] = int(route["days"]) - 1
        if int(route["days"]) > 0:
            continue
        route["days"] = 2 + randi_range(0, 4)
        var risk := int(route["risk"])
        if randi_range(1, 100) <= risk:
            route["value"] = max(8, int(route["value"]) - randi_range(1, 5))
            continue
        var from := int(route["from"])
        var to := int(route["to"])
        if from >= world.regions.size() or to >= world.regions.size():
            continue
        var value := int(route["value"])
        var owner_a := String(world.regions[from]["owner"])
        var owner_b := String(world.regions[to]["owner"])
        var fa := _faction(owner_a)
        var fb := _faction(owner_b)
        if not fa.is_empty():
            fa["treasury"] = int(fa.get("treasury",0)) + value
        if not fb.is_empty():
            fb["treasury"] = int(fb.get("treasury",0)) + max(1, value / 2)

func _simulate_npcs() -> void:
    for npc in npcs:
        if not bool(npc["alive"]):
            continue
        if randi_range(1,100) < 12:
            npc["region"] = randi_range(0, max(0, world.regions.size()-1))
        if randi_range(1,100) < 4:
            npc["loyalty"] = clamp(int(npc["loyalty"]) + randi_range(-5,5), 0, 100)
        if int(npc["loyalty"]) < 15 and String(npc["faction"]) != "Free Company":
            npc["faction"] = "Free Company"
            _emit_event("%s defected to the Free Company." % npc["name"])

func _simulate_diplomacy() -> void:
    if world.day % 8 != 0:
        return
    var ids: Array[String] = []
    for faction in world.factions:
        ids.append(String(faction["id"]))
    if ids.size() < 2:
        return
    var a := ids[randi_range(0, ids.size()-1)]
    var b := ids[randi_range(0, ids.size()-1)]
    if a == b:
        return
    var key := _relation_key(a,b)
    var current := String(world.diplomacy.get(key, "neutral"))
    if current == "war" and randi_range(1,100) <= 18:
        world.diplomacy[key] = "truce"
        _emit_event("%s and %s signed a temporary truce." % [_faction_name(a), _faction_name(b)])
    elif current != "war" and randi_range(1,100) <= 10:
        world.diplomacy[key] = "war"
        _emit_event("%s declared war on %s." % [_faction_name(a), _faction_name(b)])

func _simulate_rebellions() -> void:
    for settlement in world.settlements:
        var prosperity := int(settlement.get("prosperity",50))
        var tax := int(float(settlement.get("tax_rate",0.10)) * 100.0)
        if prosperity < 20 and tax >= 15 and randi_range(1,100) <= 8:
            var id := int(settlement["id"])
            rebellions.append({"settlement":id,"strength":20 + randi_range(0,30),"days":5})
            settlement["garrison"] = max(0, int(settlement["garrison"]) - 10)
            _emit_event("A rebellion has begun in %s." % settlement["name"])
    for i in range(rebellions.size()-1,-1,-1):
        rebellions[i]["days"] = int(rebellions[i]["days"]) - 1
        if int(rebellions[i]["days"]) <= 0:
            rebellions.remove_at(i)

func _simulate_wildlife() -> void:
    for animal in wildlife:
        animal["count"] = clamp(int(animal["count"]) + randi_range(-1,1), 0, 20)
        if int(animal["count"]) == 0:
            animal["count"] = 2

func _simulate_creatures() -> void:
    for creature in creatures:
        if not bool(creature["alive"]):
            continue
        if randi_range(1,100) <= 2:
            var region := int(creature["region"])
            if region < world.regions.size():
                var neighbors := world.get_region_neighbors(region)
                if not neighbors.is_empty():
                    creature["region"] = neighbors[randi_range(0,neighbors.size()-1)]
                    _emit_event("%s was sighted near %s." % [creature["kind"],world.regions[int(creature["region"])]["name"]])

func _update_technology() -> void:
    if world.day % 10 == 0:
        technology_points += 1
    if technology_points <= 0:
        return
    var cheapest := ""
    var best := 99
    for key in technology.keys():
        if int(technology[key]) < best:
            best = int(technology[key])
            cheapest = key
    if cheapest != "" and int(technology[cheapest]) < 5:
        technology[cheapest] = int(technology[cheapest]) + 1
        technology_points -= 1

func _update_equipment() -> void:
    var smithing := int(technology["smithing"])
    var warfare := int(technology["warfare"])
    equipment_levels["weapon"] = min(5, 1 + (smithing + warfare) / 3)
    equipment_levels["armor"] = min(5, 1 + (smithing + technology["medicine"]) / 4)
    equipment_levels["shield"] = min(5, 1 + warfare / 2)
    equipment_levels["horse"] = min(5, technology["navigation"] / 2)

func _weekly_world_tick() -> void:
    var bonus := int(technology["agriculture"]) + int(technology["commerce"])
    for settlement in world.settlements:
        settlement["population"] = int(settlement["population"]) + 1 + bonus
        settlement["prosperity"] = clamp(int(settlement["prosperity"]) + randi_range(-1,2) + bonus / 3,0,100)
    renown += 2
    technology_points += 1

func _monthly_family_tick() -> void:
    # Family aging and succession are owned by CampaignSystems to avoid double-aging.
    political_influence = min(100, political_influence + 1)

func get_save_state() -> Dictionary:
	return {
		"technology": technology.duplicate(true),
		"player_stats": player_stats.duplicate(true),
		"equipment_levels": equipment_levels.duplicate(true),
		"relationships": relationships.duplicate(true),
		"npcs": npcs.duplicate(true),
		"trade_routes": trade_routes.duplicate(true),
		"wildlife": wildlife.duplicate(true),
		"creatures": creatures.duplicate(true),
		"rebellions": rebellions.duplicate(true),
		"technology_points": technology_points,
		"renown": renown,
		"laws": laws.duplicate(true),
		"player_title": player_title,
		"player_house": player_house,
		"political_influence": political_influence,
		"political_events": political_events.duplicate()
	}

func load_save_state(state: Dictionary) -> void:
	for key in ["technology","player_stats","equipment_levels","relationships","npcs","trade_routes","wildlife","creatures","rebellions","laws"]:
		if state.has(key) and state[key] is Dictionary:
			set(key, state[key].duplicate(true))
		elif state.has(key) and state[key] is Array:
			set(key, state[key].duplicate(true))
	for key in ["technology_points","renown","political_influence"]:
		if state.has(key):
			set(key, int(state[key]))
	if state.has("player_title"): player_title = String(state["player_title"])
	if state.has("player_house"): player_house = String(state["player_house"])
	political_events.clear()
	for event in state.get("political_events", []):
		political_events.append(String(event))
	initialized = true
	last_day = world.day if world else last_day

func get_player_combat_bonus() -> float:
    var level_sum := 0
    for value in equipment_levels.values():
        level_sum += int(value)
    return 1.0 + (float(player_stats["strength"]) + float(player_stats["tactics"]) + level_sum * 3.0) / 300.0

func get_trade_bonus() -> float:
    return 1.0 + float(player_stats["trade"] + technology["commerce"] * 2) / 100.0

func unlock_technology(name: String) -> bool:
    if not technology.has(name) or technology_points <= 0:
        return false
    if int(technology[name]) >= 5:
        return false
    technology[name] = int(technology[name]) + 1
    technology_points -= 1
    return true

func change_law(name: String, value: int) -> void:
    if laws.has(name):
        laws[name] = clamp(value, 0, 30)

func hire_npc(npc_id: int) -> bool:
    if npc_id < 0 or npc_id >= npcs.size():
        return false
    var npc := npcs[npc_id]
    if not bool(npc["alive"]):
        return false
    if int(npc["loyalty"]) < 30:
        return false
    npc["faction"] = "Free Company"
    player_stats["leadership"] += 1
    return true

func encounter_creature(creature_id: int) -> Dictionary:
    if creature_id < 0 or creature_id >= creatures.size():
        return {"ok":false,"reason":"invalid_creature"}
    var creature := creatures[creature_id]
    if not bool(creature["alive"]):
        return {"ok":false,"reason":"already_defeated"}
    var power := int(float(creature["power"]) * get_player_combat_bonus())
    var roll := randi_range(1,100) + power
    if roll >= 75:
        creature["alive"] = false
        renown += 25 if bool(creature.get("rare",false)) else 10
        world.gold += 150 if bool(creature.get("rare",false)) else 50
        _emit_event("The %s was defeated and the world remembers it." % creature["kind"])
        return {"ok":true,"victory":true,"creature":creature["kind"]}
    return {"ok":true,"victory":false,"creature":creature["kind"],"damage":randi_range(8,25)}

func order_ship(ship_id: int, target_region: int) -> bool:
    if ship_id < 0 or ship_id >= world.ships.size():
        return false
    if target_region < 0 or target_region >= world.regions.size():
        return false
    world.ships[ship_id]["target_region"] = target_region
    world.ships[ship_id]["moving"] = true
    return true

func recruit_guardian(npc_id: int) -> bool:
    return hire_npc(npc_id)

func _sync_faction_relations() -> void:
    for faction in world.factions:
        var id := String(faction["id"])
        for other in world.factions:
            var oid := String(other["id"])
            if id != oid and not faction["relations"].has(oid):
                faction["relations"][oid] = 0

func _resource_for_region(region_id: int) -> String:
    if region_id < 0 or region_id >= world.regions.size():
        return "grain"
    return String(world.regions[region_id].get("resource","grain"))

func _relation_key(a:String,b:String) -> String:
    return a + "|" + b

func _faction(id:String) -> Dictionary:
    for faction in world.factions:
        if String(faction["id"]) == id:
            return faction
    return {}

func _faction_name(id:String) -> String:
    var f := _faction(id)
    return String(f.get("name",id)) if not f.is_empty() else id

func _emit_event(message:String) -> void:
    if world:
        world.world_events.append(message)

func _faction_ids() -> Array[String]:
    var ids: Array[String] = []
    for faction in world.factions:
        var id := String(faction["id"])
        if id != "Free Company":
            ids.append(id)
    return ids

func get_political_influence() -> int:
    return political_influence

func change_law_with_influence(name: String, value: int) -> Dictionary:
    if not laws.has(name):
        return {"ok":false,"reason":"invalid_law"}
    var target := clamp(value, 0, 30)
    var current := int(laws[name])
    if target == current:
        return {"ok":false,"reason":"no_change"}
    var cost := max(1, abs(target-current) * 2)
    if political_influence < cost:
        return {"ok":false,"reason":"not_enough_influence","cost":cost}
    political_influence -= cost
    laws[name] = target
    if name == "tax":
        for settlement in world.settlements:
            settlement["tax_rate"] = float(target) / 100.0
    if name == "conscription":
        for settlement in world.settlements:
            settlement["garrison"] = max(0, int(settlement["garrison"]) + (target-current) / 2)
    political_events.push_front("Law changed: %s %d -> %d." % [name, current, target])
    _trim_political_events()
    return {"ok":true,"law":name,"value":target,"cost":cost}

func negotiate_peace(faction_id: String) -> Dictionary:
    if faction_id == "Free Company" or _faction(faction_id).is_empty():
        return {"ok":false,"reason":"invalid_faction"}
    var key := _relation_key("Free Company", faction_id)
    var reverse := _relation_key(faction_id, "Free Company")
    var relation := String(world.diplomacy.get(key, world.diplomacy.get(reverse, "neutral")))
    if relation != "war":
        return {"ok":false,"reason":"not_at_war"}
    var cost := 12
    if political_influence < cost:
        return {"ok":false,"reason":"not_enough_influence"}
    political_influence -= cost
    world.diplomacy[key] = "peace"
    world.diplomacy[reverse] = "peace"
    political_events.push_front("Peace negotiated with %s." % _faction_name(faction_id))
    _trim_political_events()
    return {"ok":true}

func declare_war(faction_id: String) -> Dictionary:
    if faction_id == "Free Company" or _faction(faction_id).is_empty():
        return {"ok":false,"reason":"invalid_faction"}
    var key := _relation_key("Free Company", faction_id)
    var reverse := _relation_key(faction_id, "Free Company")
    var cost := 18
    if political_influence < cost:
        return {"ok":false,"reason":"not_enough_influence"}
    political_influence -= cost
    world.diplomacy[key] = "war"
    world.diplomacy[reverse] = "war"
    political_events.push_front("War declared on %s." % _faction_name(faction_id))
    _trim_political_events()
    return {"ok":true}

func get_political_status() -> String:
    var out := "Influence: %d\nLaws: tax %d • conscription %d • trade duty %d\n\nRecent political events:\n" % [political_influence, int(laws["tax"]), int(laws["conscription"]), int(laws["trade_duty"])]
    for event in political_events:
        out += "• " + event + "\n"
    return out

func _trim_political_events() -> void:
    while political_events.size() > 8:
        political_events.pop_back()
