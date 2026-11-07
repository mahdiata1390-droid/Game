extends Node
class_name ReleaseWarLoop

# Stage 4: War Loop integration.
# Kingdom -> War -> Army -> Siege -> Assault -> Capture -> Economy.
# Uses WorldState as the authoritative source for diplomacy, armies and ownership.

var game: Node3D
var world: Node
var siege_stage: Node
var tick: float = 0.0
var status: String = "WAR LOOP READY"
var active_target: int = -1
var active_army: int = -1
var auto_assault: bool = false
var status_label: Label

func build(main_node: Node3D) -> void:
    game = main_node
    world = game.get("world_state")
    siege_stage = game.get_node_or_null("SiegeStage")
    _create_ui()
    set_process(true)

func _process(delta: float) -> void:
    if world == null:
        world = game.get("world_state")
        return
    tick += delta
    if tick < 2.0:
        return
    tick = 0.0
    _sync_war_state()
    if auto_assault:
        _auto_assault_tick()
    _update_ui()

func declare_war(target_faction: String) -> Dictionary:
    if world == null:
        return {"ok":false,"reason":"world_not_ready"}
    var player := String(world.get("player_faction"))
    if target_faction == "" or target_faction == player:
        return {"ok":false,"reason":"invalid_target"}
    if not world.has_method("set_diplomacy"):
        return {"ok":false,"reason":"diplomacy_api_missing"}
    var result: Dictionary = world.set_diplomacy(player, target_faction, "war")
    if bool(result.get("ok",false)):
        status = "WAR DECLARED • %s" % world.get_faction_name(target_faction)
    return result

func prepare_nearest_war() -> Dictionary:
    if world == null:
        return {"ok":false,"reason":"world_not_ready"}
    var target := _nearest_hostile_settlement()
    if target < 0:
        return {"ok":false,"reason":"no_hostile_settlement"}
    var army := _nearest_player_army_to_settlement(target)
    if army < 0:
        return {"ok":false,"reason":"no_player_army"}
    active_target = target
    active_army = army
    status = "TARGET READY • %s" % String(world.settlements[target].get("name","Settlement"))
    return {"ok":true,"settlement":target,"army":army}

func start_siege() -> Dictionary:
    if world == null:
        return {"ok":false,"reason":"world_not_ready"}
    if active_target < 0 or active_army < 0:
        var prepared := prepare_nearest_war()
        if not bool(prepared.get("ok",false)):
            return prepared
    var result: Dictionary = world.start_siege(active_target, active_army)
    if bool(result.get("ok",false)):
        auto_assault = true
        status = "SIEGE STARTED • %s" % String(result.get("settlement","Settlement"))
    else:
        status = "SIEGE BLOCKED • %s" % String(result.get("reason","FAILED"))
    return result

func assault_once() -> Dictionary:
    if world == null or active_target < 0:
        return {"ok":false,"reason":"no_active_target"}
    if not world.sieges.has(active_target):
        return {"ok":false,"reason":"no_siege"}
    var result: Dictionary = world.assault_siege(active_target)
    if bool(result.get("captured",false)):
        auto_assault = false
        status = "SETTLEMENT CAPTURED • %s" % String(result.get("settlement","Settlement"))
        active_target = -1
        active_army = -1
    elif bool(result.get("ok",false)):
        status = "ASSAULT • %s • %d%%" % [
            String(world.settlements[active_target].get("name","Settlement")),
            int(result.get("progress",0))
        ]
    return result

func set_auto_assault(enabled: bool) -> void:
    auto_assault = enabled

func get_state() -> Dictionary:
    return {
        "status": status,
        "active_target": active_target,
        "active_army": active_army,
        "auto_assault": auto_assault
    }

func _auto_assault_tick() -> void:
    if active_target < 0:
        return
    if not world.sieges.has(active_target):
        auto_assault = false
        return
    assault_once()

func _sync_war_state() -> void:
    var player := String(world.get("player_faction"))
    var wars := 0
    for faction in world.factions:
        var id := String(faction.get("id",""))
        if id != "" and id != player and world.get_diplomacy(player,id) == "war":
            wars += 1
    game.set_meta("campaign_wars", wars)
    game.set_meta("war_loop_status", status)

func _nearest_hostile_settlement() -> int:
    var player := String(world.get("player_faction"))
    var best := -1
    var best_distance := INF
    var player_region := int(world.get("player_region_id"))
    for i in range(world.settlements.size()):
        var s: Dictionary = world.settlements[i]
        var owner := String(s.get("owner",""))
        if owner == "" or owner == player:
            continue
        if world.get_diplomacy(player,owner) != "war":
            continue
        var distance := abs(int(s.get("region",0)) - player_region)
        if distance < best_distance:
            best_distance = distance
            best = i
    return best

func _nearest_player_army_to_settlement(settlement_id: int) -> int:
    if settlement_id < 0 or settlement_id >= world.settlements.size():
        return -1
    var target_region := int(world.settlements[settlement_id].get("region",0))
    var player := String(world.get("player_faction"))
    var best := -1
    var best_distance := INF
    for i in range(world.armies.size()):
        var army: Dictionary = world.armies[i]
        if String(army.get("owner","")) != player or int(army.get("soldiers",0)) <= 0:
            continue
        var distance := abs(int(army.get("region",0)) - target_region)
        if distance < best_distance:
            best_distance = distance
            best = i
    return best

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "WarLoopUI"
    game.add_child(layer)

    var button := Button.new()
    button.text = "WAR LOOP"
    button.position = Vector2(420,400)
    button.size = Vector2(180,48)
    button.pressed.connect(_toggle)
    layer.add_child(button)

    var panel := Panel.new()
    panel.name = "Panel"
    panel.position = Vector2(300,130)
    panel.size = Vector2(680,300)
    panel.visible = false
    layer.add_child(panel)

    var title := Label.new()
    title.text = "WAR LOOP • KINGDOM → SIEGE → CAPTURE"
    title.position = Vector2(24,20)
    title.add_theme_font_size_override("font_size",22)
    panel.add_child(title)

    status_label = Label.new()
    status_label.position = Vector2(24,65)
    status_label.size = Vector2(630,70)
    panel.add_child(status_label)

    var prepare := Button.new()
    prepare.text = "FIND WAR TARGET"
    prepare.position = Vector2(24,145)
    prepare.size = Vector2(195,50)
    prepare.pressed.connect(func(): prepare_nearest_war())
    panel.add_child(prepare)

    var siege := Button.new()
    siege.text = "START SIEGE"
    siege.position = Vector2(240,145)
    siege.size = Vector2(195,50)
    siege.pressed.connect(func(): start_siege())
    panel.add_child(siege)

    var assault := Button.new()
    assault.text = "ASSAULT ONCE"
    assault.position = Vector2(456,145)
    assault.size = Vector2(195,50)
    assault.pressed.connect(func(): assault_once())
    panel.add_child(assault)

    var auto := Button.new()
    auto.text = "AUTO ASSAULT"
    auto.position = Vector2(24,210)
    auto.size = Vector2(195,50)
    auto.pressed.connect(func(): set_auto_assault(not auto_assault))
    panel.add_child(auto)

    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(456,210)
    close.size = Vector2(195,50)
    close.pressed.connect(func(): panel.visible = false)
    panel.add_child(close)

    status_label.text = status

func _update_ui() -> void:
    if not is_instance_valid(status_label):
        return
    status_label.text = "%s\nTarget: %d  Army: %d  Auto: %s" % [
        status, active_target, active_army, "ON" if auto_assault else "OFF"
    ]

func _toggle() -> void:
    var panel := game.get_node_or_null("WarLoopUI/Panel")
    if panel is Panel:
        panel.visible = not panel.visible
