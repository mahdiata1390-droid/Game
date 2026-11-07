extends Node
class_name ReleaseCombatPolish

var game: Node3D
var world
var tick: float = 0.0
var last_event: String = "COMBAT POLISH READY"

func build(root: Node3D) -> void:
    game = root
    world = root.get("world_state")
    set_process(true)
    _refresh()

func _process(delta: float) -> void:
    tick += delta
    if tick >= 5.0:
        tick = 0.0
        _refresh()

func _refresh() -> void:
    if world == null:
        world = game.get("world_state")
    if world == null:
        return
    for i in range(world.armies.size()):
        var army: Dictionary = world.armies[i]
        var soldiers: int = int(army.get("soldiers",0))
        if soldiers <= 0:
            continue
        var morale: int = clampi(int(army.get("morale",60)),0,100)
        var readiness: int = clampi(int(army.get("combat_readiness",morale)),0,100)
        var cavalry: int = int(army.get("troops",{}).get("horseman",0))
        var archers: int = int(army.get("troops",{}).get("archer",0))
        var formation: String = String(army.get("formation","line"))
        var flank: int = clampi(cavalry * 2 + int(morale / 12),0,300)
        var ranged: int = clampi(archers * 2 + int(morale / 10),0,300)
        var power: int = soldiers + int(morale * 2) + flank + ranged + readiness
        army["combat_power"] = power
        army["retreat_threshold"] = 25
        army["flank_power"] = flank
        army["ranged_power"] = ranged
        army["formation_bonus"] = 10 if formation == "shield_wall" else (8 if formation == "wedge" else 4)
        world.armies[i] = army
    last_event = "Combat power, flanking and ranged support synchronized"

func apply_battle_morale(army_id: int, delta: int) -> Dictionary:
    if world == null or army_id < 0 or army_id >= world.armies.size():
        return {"ok":false,"reason":"invalid_army"}
    var army: Dictionary = world.armies[army_id]
    army["morale"] = clampi(int(army.get("morale",60)) + delta,0,100)
    world.armies[army_id] = army
    return {"ok":true,"morale":int(army["morale"])}

func get_state() -> Dictionary:
    return {"last_event":last_event}
