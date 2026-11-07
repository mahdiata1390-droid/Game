extends Node
class_name ReleaseWorldSimulation

## Stage 5: autonomous world life.
## NPC factions act without waiting for the player: diplomacy, army movement,
## sieges, settlement capture, recovery and simple trade activity.

var game: Node3D
var world: Node
var tick := 0.0
var day_clock := 0.0
var actions := 0
var last_event := "WORLD SIMULATION READY"
var state: Dictionary = {"actions":0,"wars_started":0,"settlements_captured":0,"trade_runs":0,"npc_battles":0}

func build(main_node: Node3D) -> void:
    game = main_node
    world = game.get("world_state")
    set_process(true)

func _process(delta: float) -> void:
    if world == null:
        world = game.get("world_state")
        return
    tick += delta
    day_clock += delta
    if tick >= 4.0:
        tick = 0.0
        _simulate_factions()
        _simulate_armies()
        _simulate_recovery()
    if day_clock >= 20.0:
        day_clock = 0.0
        if world.has_method("advance_day"):
            world.advance_day()

func _simulate_factions() -> void:
    var factions := _faction_ids()
    for faction in factions:
        if faction == String(world.get("player_faction")):
            continue
        var enemy := _choose_enemy(faction)
        if enemy == "":
            continue
        if world.get_diplomacy(faction, enemy) != "war":
            if _faction_strength(faction) > _faction_strength(enemy) * 0.85:
                var result: Dictionary = world.set_diplomacy(faction, enemy, "war")
                if bool(result.get("ok",false)):
                    state["wars_started"] = int(state["wars_started"]) + 1
                    last_event = "%s declared war on %s" % [faction, enemy]
                    actions += 1

func _simulate_armies() -> void:
    for i in range(world.armies.size()):
        var army: Dictionary = world.armies[i]
        var owner := String(army.get("owner",""))
        if owner == "" or owner == String(world.get("player_faction")):
            continue
        var current_region := int(army.get("region",0))
        var target := _enemy_settlement(owner,current_region)
        if target < 0:
            continue
        var target_region := int(world.settlements[target].get("region",0))
        if current_region != target_region:
            army["region"] = _step_toward(current_region,target_region)
            army["morale"] = max(20,int(army.get("morale",60))-1)
            world.armies[i] = army
            actions += 1
            last_event = "%s army marches toward %s" % [String(army.get("name","Army")),String(world.settlements[target].get("name","Settlement"))]
            continue
        if not world.sieges.has(target):
            var siege_result: Dictionary = world.start_siege_for_faction(target,i)
            if bool(siege_result.get("ok",false)):
                actions += 1
                last_event = "%s besieges %s" % [owner,String(world.settlements[target].get("name","Settlement"))]
        if world.sieges.has(target) and world.has_method("assault_siege"):
            var result: Dictionary = world.assault_siege(target)
            if bool(result.get("captured",false)):
                state["settlements_captured"] = int(state["settlements_captured"]) + 1
                actions += 1
                last_event = "%s captured %s" % [owner,String(result.get("settlement","Settlement"))]

func _simulate_recovery() -> void:
    for i in range(world.armies.size()):
        var army: Dictionary = world.armies[i]
        var soldiers := int(army.get("soldiers",0))
        var max_soldiers := max(soldiers,int(army.get("max_soldiers",soldiers)))
        if soldiers > 0 and max_soldiers > soldiers:
            army["soldiers"] = min(max_soldiers,soldiers+2)
            army["morale"] = min(100,int(army.get("morale",50))+1)
            world.armies[i] = army
    for settlement in world.settlements:
        var owner := String(settlement.get("owner",""))
        var garrison := int(settlement.get("garrison",0))
        if owner != "" and garrison > 0:
            settlement["garrison"] = min(max(garrison,20),garrison+1)
        settlement["prosperity"] = clampi(int(settlement.get("prosperity",50)) + (1 if int(settlement.get("garrison",0)) > 0 else -1),0,100)

func _choose_enemy(faction:String) -> String:
    var best := ""
    var best_score := -INF
    for other in _faction_ids():
        if other == faction:
            continue
        var relation := world.get_diplomacy(faction,other)
        if relation == "alliance":
            continue
        var score := float(_faction_strength(other))
        if relation == "war":
            score += 10000.0
        elif relation == "trade":
            score -= 5000.0
        if score > best_score:
            best_score = score
            best = other
    return best

func _enemy_settlement(faction:String,from_region:int) -> int:
    var best := -1
    var best_distance := INF
    for i in range(world.settlements.size()):
        var settlement: Dictionary = world.settlements[i]
        var owner := String(settlement.get("owner",""))
        if owner == faction or owner == "":
            continue
        if world.get_diplomacy(faction,owner) != "war":
            continue
        var distance := abs(int(settlement.get("region",0)) - from_region)
        if distance < best_distance:
            best_distance = distance
            best = i
    return best

func _faction_strength(faction:String) -> int:
    var score := 0
    for settlement in world.settlements:
        if String(settlement.get("owner","")) == faction:
            score += 50 + int(settlement.get("garrison",0))
    for army in world.armies:
        if String(army.get("owner","")) == faction:
            score += int(army.get("soldiers",0))
    return score

func _faction_ids() -> Array[String]:
    var result: Array[String] = []
    for faction in world.factions:
        var id := String(faction.get("id",faction.get("name","")))
        if id != "" and not result.has(id):
            result.append(id)
    return result

func _step_toward(from:int,to:int) -> int:
    if from == to:
        return from
    return from + (1 if to > from else -1)

func get_state() -> Dictionary:
    var copy := state.duplicate(true)
    copy["actions"] = actions
    copy["last_event"] = last_event
    return copy

func get_save_state() -> Dictionary:
    return get_state()

func load_save_state(data:Dictionary) -> void:
    state = data.duplicate(true)
    actions = int(state.get("actions",0))
    last_event = String(state.get("last_event","WORLD SIMULATION READY"))
