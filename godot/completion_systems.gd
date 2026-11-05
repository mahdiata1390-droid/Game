extends Node
class_name CompletionSystems

var world: Node
var campaign: Node
var last_day := -1
var panel: Panel
var event_label: Label
var status_label: Label
var ui_layer: CanvasLayer
var mission_resource := "food"
var mission_amount := 20
var mission_target := 0

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_bind")

func _bind() -> void:
    var scene := get_tree().current_scene
    if scene:
        world = scene.get_node_or_null("WorldState")
    campaign = get_node_or_null("/root/CampaignSystems")
    if world and ui_layer == null:
        last_day = int(world.day)
        _build_ui()

func _process(_delta: float) -> void:
    if world == null:
        _bind()
        return
    if int(world.day) != last_day:
        last_day = int(world.day)
        _refresh_ui()

func _build_ui() -> void:
    ui_layer = CanvasLayer.new()
    ui_layer.layer = 40
    add_child(ui_layer)
    var open := Button.new()
    open.text = "EVENTS / ACTIVITIES"
    open.position = Vector2(28, 345)
    open.size = Vector2(230, 48)
    open.pressed.connect(_toggle_panel)
    ui_layer.add_child(open)

func _toggle_panel() -> void:
    if is_instance_valid(panel):
        panel.queue_free()
        panel = null
        return
    panel = Panel.new()
    panel.position = Vector2(250, 55)
    panel.size = Vector2(780, 610)
    ui_layer.add_child(panel)

    var title := Label.new()
    title.text = "WORLD EVENTS • ACTIVITIES • NAVAL MISSIONS"
    title.position = Vector2(22, 16)
    title.add_theme_font_size_override("font_size", 22)
    panel.add_child(title)

    event_label = Label.new()
    event_label.position = Vector2(22, 58)
    event_label.size = Vector2(735, 240)
    event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    event_label.add_theme_font_size_override("font_size", 15)
    panel.add_child(event_label)

    var mission_title := Label.new()
    mission_title.text = "NAVAL CONTRACT"
    mission_title.position = Vector2(22, 315)
    mission_title.add_theme_font_size_override("font_size", 18)
    panel.add_child(mission_title)

    var target := OptionButton.new()
    target.position = Vector2(22, 355)
    target.size = Vector2(350, 38)
    for i in range(world.regions.size()):
        target.add_item(String(world.regions[i].get("name", "Region")), i)
    target.select(clamp(mission_target, 0, max(0, world.regions.size() - 1)))
    target.item_selected.connect(func(index:int): mission_target = index)
    panel.add_child(target)

    var amount := SpinBox.new()
    amount.position = Vector2(22, 405)
    amount.size = Vector2(170, 38)
    amount.min_value = 10
    amount.max_value = 200
    amount.step = 10
    amount.value = mission_amount
    amount.value_changed.connect(func(v:float): mission_amount = int(v))
    panel.add_child(amount)

    var resource := OptionButton.new()
    resource.position = Vector2(205, 405)
    resource.size = Vector2(167, 38)
    for r in ["food", "wood", "iron"]:
        resource.add_item(r.capitalize())
    resource.select(0)
    resource.item_selected.connect(func(index:int): mission_resource = ["food", "wood", "iron"][index])
    panel.add_child(resource)

    var create := Button.new()
    create.text = "CREATE NAVAL MISSION"
    create.position = Vector2(22, 455)
    create.size = Vector2(350, 42)
    create.pressed.connect(_create_naval_mission)
    panel.add_child(create)

    status_label = Label.new()
    status_label.position = Vector2(22, 505)
    status_label.size = Vector2(530, 32)
    status_label.add_theme_font_size_override("font_size", 14)
    panel.add_child(status_label)

    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(600, 520)
    close.size = Vector2(130, 40)
    close.pressed.connect(func():
        if is_instance_valid(panel):
            panel.queue_free()
        panel = null
    )
    panel.add_child(close)
    _refresh_ui()

func _refresh_ui() -> void:
    if not is_instance_valid(event_label) or world == null:
        return
    var lines: Array[String] = []
    lines.append("DAY %d • GOLD %d • REGION %s" % [int(world.day), int(world.gold), String(world.regions[int(world.player_region_id)].get("name", "Unknown"))])
    lines.append("")
    var recent: Array[String] = []
    for e in world.world_events:
        recent.append(String(e))
    for e in world.battle_events:
        recent.append(String(e))
    if campaign and campaign.has_method("get_recent_events"):
        recent.append(String(campaign.get_recent_events()))
    var count := 0
    for entry in recent:
        if count >= 10:
            break
        lines.append("• " + entry.replace("\n", " | "))
        count += 1
    if count == 0:
        lines.append("• The world is quiet. Factions are preparing their next moves.")
    event_label.text = "\n".join(lines)

func _create_naval_mission() -> void:
    if campaign == null or world == null:
        return
    var player_ships: Array = campaign.get_player_ship_ids() if campaign.has_method("get_player_ship_ids") else []
    if player_ships.is_empty():
        status_label.text = "Acquire a player ship first."
        return
    if mission_target < 0 or mission_target >= world.regions.size():
        status_label.text = "Choose a valid destination."
        return
    var ship_id := int(player_ships[0])
    var stock := int(world.production_stock.get(mission_resource, 0))
    var amount := min(mission_amount, stock)
    if amount <= 0:
        status_label.text = "Not enough %s stock." % mission_resource
        return
    world.production_stock[mission_resource] = stock - amount
    var reward := amount * (4 if mission_resource == "food" else (7 if mission_resource == "wood" else 11))
    var mission := {
        "id": campaign.naval_missions.size(),
        "ship_id": ship_id,
        "resource": mission_resource,
        "amount": amount,
        "destination_region": mission_target,
        "days_left": 3,
        "reward": reward,
        "complete": false
    }
    campaign.naval_missions.append(mission)
    campaign.naval_events.push_front("Naval mission launched: %s × %d → %s." % [mission_resource, amount, String(world.regions[mission_target].get("name", "Region"))])
    if campaign.naval_events.size() > 8:
        campaign.naval_events.pop_back()
    status_label.text = "Mission launched • reward %dG" % reward
    _refresh_ui()
