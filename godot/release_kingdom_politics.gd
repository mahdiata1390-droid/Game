extends Node
class_name ReleaseKingdomPolitics

var game: Node3D
var world
var tick: float = 0.0
var loyalty: Dictionary = {}
var last_event: String = "KINGDOM POLITICS READY"

func build(root: Node3D) -> void:
    game = root
    world = root.get("world_state")
    set_process(true)
    _refresh()

func _process(delta: float) -> void:
    tick += delta
    if tick >= 12.0:
        tick = 0.0
        _refresh()

func _refresh() -> void:
    if world == null:
        world = game.get("world_state")
    if world == null:
        return
    var player := String(world.get("player_faction"))
    for faction in world.factions:
        var id := String(faction.get("id",""))
        if id == "" or id == player:
            continue
        var score: int = int(loyalty.get(id,60))
        var relation_key := player + "|" + id
        var relation: String = String(world.diplomacy.get(relation_key,"neutral"))
        if relation == "alliance":
            score += 1
        elif relation == "war":
            score -= 1
        loyalty[id] = clampi(score,0,100)
    _apply_player_stability(player)
    last_event = "Faction loyalty and political stability updated"

func _apply_player_stability(player: String) -> void:
    var owned: int = 0
    var unrest: int = 0
    for settlement in world.settlements:
        if String(settlement.get("owner","")) == player:
            owned += 1
            var satisfaction: int = int(settlement.get("satisfaction",55))
            if satisfaction < 40:
                unrest += 1
    world.set_meta("political_stability", clampi(70 + owned * 3 - unrest * 10,0,100))

func appoint_lord(faction_id: String, personality: String) -> Dictionary:
    if world == null:
        return {"ok":false,"reason":"world_not_ready"}
    if not ["aggressive","defensive","raider","balanced"].has(personality):
        return {"ok":false,"reason":"invalid_personality"}
    for faction in world.factions:
        if String(faction.get("id","")) == faction_id:
            faction["ruling_personality"] = personality
            return {"ok":true,"faction":faction_id,"personality":personality}
    return {"ok":false,"reason":"faction_not_found"}

func get_state() -> Dictionary:
    return {"loyalty":loyalty.duplicate(true),"last_event":last_event}
