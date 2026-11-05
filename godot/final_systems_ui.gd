extends Node

var world: Node
var systems: Node
var campaign: Node
var layer: CanvasLayer
var open_button: Button
var panel: Panel
var content: Label
var selected_tab := "overview"
var government_controls: Array[Button] = []
var navy_controls: Array[Button] = []
var family_controls: Array[Button] = []
var naval_route_controls: Array[Button] = []
var ship_upgrade_controls: Array[Button] = []
var cargo_controls: Array[Button] = []
var naval_encounter_controls: Array[Button] = []

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_setup")

func _setup() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    world = scene.get_node_or_null("WorldState")
    systems = get_node_or_null("/root/FinalGameSystems")
    campaign = get_node_or_null("/root/CampaignSystems")
    if world == null or systems == null:
        return
    layer = CanvasLayer.new()
    layer.name = "FinalSystemsUI"
    scene.add_child(layer)

    open_button = Button.new()
    open_button.text = "WORLD SYSTEMS"
    open_button.position = Vector2(28, 345)
    open_button.size = Vector2(210, 54)
    open_button.add_theme_font_size_override("font_size", 18)
    open_button.pressed.connect(_toggle_panel)
    layer.add_child(open_button)

    panel = Panel.new()
    panel.position = Vector2(230, 55)
    panel.size = Vector2(820, 760)
    panel.visible = false
    layer.add_child(panel)

    var title := Label.new()
    title.text = "CONTINENT COMMAND"
    title.position = Vector2(25, 18)
    title.add_theme_font_size_override("font_size", 28)
    panel.add_child(title)

    var tabs := ["OVERVIEW","TECH","GOVERNMENT","FAMILY","NAVY","CREATURES","SAVE"]
    for i in range(tabs.size()):
        var b := Button.new()
        b.text = tabs[i]
        b.position = Vector2(20 + i * 112, 62)
        b.size = Vector2(105, 42)
        b.pressed.connect(_select_tab.bind(tabs[i].to_lower()))
        panel.add_child(b)

    content = Label.new()
    content.position = Vector2(28, 120)
    content.size = Vector2(760, 330)
    content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_theme_font_size_override("font_size", 18)
    panel.add_child(content)

    var actions := [
        ["TAX -1", "_political_tax", -1],
        ["TAX +1", "_political_tax", 1],
        ["CONSCRIPTION -1", "_political_conscription", -1],
        ["CONSCRIPTION +1", "_political_conscription", 1],
        ["PEACE VALORIA", "_political_peace", 0],
        ["WAR VALORIA", "_political_war", 0]
    ]
    for i in range(actions.size()):
        var action_button := Button.new()
        action_button.text = String(actions[i][0])
        action_button.position = Vector2(28 + (i % 3) * 250, 510 + (i / 3) * 36)
        action_button.size = Vector2(230, 30)
        action_button.pressed.connect(Callable(self, String(actions[i][1])).bind(int(actions[i][2])))
        panel.add_child(action_button)
        government_controls.append(action_button)

    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(330, 715)
    close.size = Vector2(160, 45)
    close.pressed.connect(_toggle_panel)
    panel.add_child(close)

func _toggle_panel() -> void:
    if panel == null:
        return
    panel.visible = not panel.visible
    if panel.visible:
        _refresh()

func _select_tab(tab: String) -> void:
    selected_tab = tab
    _refresh()

func _refresh() -> void:
    if world == null or systems == null or campaign == null or content == null:
        return
    for b in government_controls:
        b.visible = selected_tab == "government"
    _rebuild_navy_controls()
    _rebuild_family_controls()
    _rebuild_naval_route_controls()
    _rebuild_ship_upgrade_controls()
    _rebuild_cargo_controls()
    _rebuild_naval_encounter_controls()
    match selected_tab:
        "overview":
            content.text = _overview()
        "tech":
            content.text = _technology()
        "government":
            content.text = _government()
        "family":
            content.text = _family()
        "navy":
            content.text = _navy()
        "creatures":
            content.text = _creatures()
        "save":
            content.text = "SAVE / LOAD\n\nUse the buttons below to persist the entire continent."
            _add_save_buttons()
        _:
            content.text = _overview()

func _overview() -> String:
    var s := world.get_world_status()
    return "DAY %d • %s • GOLD %d\n\nLevel: %d\nRegion: %d\nSettlements: %d\nArmies: %d\nShips: %d\nSieges: %d\nCaravans: %d\n\nRenown: %d\nTitle: %s\nTechnology points: %d\n\nThe world continues to simulate while this panel is closed." % [
        int(s.get("day",1)), String(s.get("weather","clear")), int(s.get("gold",0)),
        int(s.get("level",1)), int(s.get("player_region",0)), int(s.get("settlements",0)),
        int(s.get("armies",0)), int(s.get("ships",0)), int(s.get("sieges",0)),
        int(s.get("caravans",0)), int(systems.renown), String(systems.player_title),
        int(systems.technology_points)
    ]

func _technology() -> String:
    var t: Dictionary = systems.technology
    return "TECHNOLOGY TREE\n\nAgriculture: %d / 5\nSmithing: %d / 5\nCommerce: %d / 5\nEngineering: %d / 5\nNavigation: %d / 5\nMedicine: %d / 5\nWarfare: %d / 5\nMysticism: %d / 5\n\nAvailable points: %d\n\nTechnology now affects economy, equipment, population and combat." % [
        int(t["agriculture"]),int(t["smithing"]),int(t["commerce"]),int(t["engineering"]),
        int(t["navigation"]),int(t["medicine"]),int(t["warfare"]),int(t["mysticism"]),
        int(systems.technology_points)
    ]

func _government() -> String:
    var laws: Dictionary = systems.laws
    return "GOVERNMENT & POLITICS\n\nInfluence: %d\nTax: %d\nConscription: %d\nTrade duty: %d\n\nUse political influence to change laws or negotiate war and peace.\nLow prosperity plus heavy taxation can trigger rebellions.\n\n%s" % [
        int(systems.get_political_influence()), int(laws["tax"]),int(laws["conscription"]),int(laws["trade_duty"]), systems.get_political_status()
    ]

func _family() -> String:
    var f: Dictionary = world.family
    var lines := "FAMILY & SUCCESSION\n\nAge: %d\nGeneration: %d\nHeir: %s\nHeir age: %d\n\nMembers:\n" % [
        int(f.get("age",18)),int(f.get("generation",1)),String(f.get("heir_name","Unnamed Heir")),int(f.get("heir_age",0))
    ]
    for member in world.family_members:
        lines += "• %s — %s — age %d — loyalty %d\n" % [
            String(member.get("name","Unknown")),String(member.get("role","member")),
            int(member.get("age",0)),int(member.get("loyalty",0))
        ]
    if world.family_members.is_empty():
        lines += "No household members yet."
    lines += "\n\nSUCCESSION ENGINE\n" + campaign.get_family_status()
    lines += "\n" + campaign.get_succession_status()
    return lines

func _navy() -> String:
    var out := "NAVAL COMMAND & SEA WAR\n\n"
    for ship in world.ships:
        var region_id := int(ship.get("region",0))
        var region_name := String(world.regions[region_id]["name"]) if region_id >= 0 and region_id < world.regions.size() else "Unknown"
        out += "• %s — owner %s — region %s — crew %d — hull %d\n" % [
            String(ship.get("name","Ship")),String(ship.get("owner","unknown")),
            region_name,int(ship.get("crew",0)),int(ship.get("hull",50))
        ]
    out += "\nShips move through adjacent regions and can fight hostile fleets.\n"
    out += "Player encounters pause the simulation until you choose an action.\n"
    if campaign.has_pending_naval_encounter():
        var encounter: Dictionary = campaign.get_pending_naval_encounter()
        var player_id := int(encounter.get("player_ship",-1))
        var enemy_id := int(encounter.get("enemy_ship",-1))
        if player_id >= 0 and enemy_id >= 0 and player_id < world.ships.size() and enemy_id < world.ships.size():
            out += "\n⚔ NAVAL ENCOUNTER PENDING\n"
            out += "%s vs %s\n" % [String(world.ships[player_id].get("name","Your Ship")), String(world.ships[enemy_id].get("name","Enemy Ship"))]
            out += "Choose an action below.\n"
    out += "\nVictories cause persistent crew losses and cargo seizure.\n\n"
    out += campaign.get_recent_events()
    return out


func _clear_controls(list: Array[Button]) -> void:
    for b in list:
        if is_instance_valid(b):
            b.queue_free()
    list.clear()

func _rebuild_navy_controls() -> void:
    _clear_controls(navy_controls)
    if selected_tab != "navy" or panel == null:
        return
    var buy := Button.new()
    buy.text = "BUY GALLEY • 300G"
    buy.position = Vector2(28, 435)
    buy.size = Vector2(230, 32)
    buy.pressed.connect(_buy_ship)
    panel.add_child(buy)
    navy_controls.append(buy)
    var ids: Array[int] = campaign.get_player_ship_ids()
    for k in range(min(ids.size(), 2)):
        var ship_id := ids[k]
        var repair := Button.new()
        repair.text = "REPAIR SHIP %d" % (ship_id + 1)
        repair.position = Vector2(270 + k * 245, 435)
        repair.size = Vector2(220, 32)
        repair.pressed.connect(_repair_ship.bind(ship_id))
        panel.add_child(repair)
        navy_controls.append(repair)

func _buy_ship() -> void:
    var result: Dictionary = campaign.acquire_player_ship()
    _refresh()
    if not result.get("ok", false):
        content.text = "NAVAL PURCHASE FAILED\n\n" + String(result.get("reason","unknown"))
    else:
        content.text = "NAVAL PURCHASE\n\nNew Free Company galley acquired."

func _repair_ship(ship_id: int) -> void:
    var result: Dictionary = campaign.repair_ship(ship_id)
    _refresh()
    content.text = "SHIP REPAIR\n\n" + (str(result) if result.get("ok",false) else "Repair failed: " + String(result.get("reason","unknown")))


func _rebuild_naval_route_controls() -> void:
    _clear_controls(naval_route_controls)
    if selected_tab != "navy" or panel == null:
        return
    var ids: Array[int] = campaign.get_player_ship_ids()
    for i in range(min(ids.size(), 2)):
        var ship_id := ids[i]
        var ship: Dictionary = world.ships[ship_id]
        var region_id := int(ship.get("region",0))
        var neighbors: Array[int] = world.get_region_neighbors(region_id)
        var crew := Button.new()
        crew.text = "CREW +5 • SHIP %d" % (ship_id + 1)
        crew.position = Vector2(28, 472 + i * 30)
        crew.size = Vector2(230, 30)
        crew.pressed.connect(_recruit_crew.bind(ship_id))
        panel.add_child(crew)
        naval_route_controls.append(crew)
        for n in range(min(neighbors.size(), 2)):
            var target := int(neighbors[n])
            var route := Button.new()
            route.text = "SHIP %d → %s" % [ship_id + 1, String(world.regions[target].get("name","Region"))]
            route.position = Vector2(270 + n * 245, 472 + i * 30)
            route.size = Vector2(220, 30)
            route.pressed.connect(_route_ship.bind(ship_id, target))
            panel.add_child(route)
            naval_route_controls.append(route)

func _recruit_crew(ship_id: int) -> void:
    var result: Dictionary = campaign.recruit_ship_crew(ship_id, 5)
    _refresh()
    content.text = "CREW RECRUITMENT\n\n" + (str(result) if result.get("ok",false) else "Recruitment failed: " + String(result.get("reason","unknown")))

func _route_ship(ship_id: int, target_region: int) -> void:
    var result: Dictionary = campaign.set_ship_route(ship_id, target_region)
    _refresh()
    content.text = "NAVAL ROUTE\n\n" + (str(result) if result.get("ok",false) else "Route failed: " + String(result.get("reason","unknown")))


func _rebuild_ship_upgrade_controls() -> void:
    _clear_controls(ship_upgrade_controls)
    if selected_tab != "navy" or panel == null:
        return
    var ids: Array[int] = campaign.get_player_ship_ids()
    for i in range(min(ids.size(), 2)):
        var ship_id := ids[i]
        var base_y := 536 + i * 30
        for j in range(3):
            var stats := ["hull", "cannons", "cargo"]
            var b := Button.new()
            b.text = "SHIP %d UPGRADE %s" % [ship_id + 1, String(stats[j]).to_upper()]
            b.position = Vector2(28 + j * 250, base_y)
            b.size = Vector2(230, 30)
            b.pressed.connect(_upgrade_ship.bind(ship_id, String(stats[j])))
            panel.add_child(b)
            ship_upgrade_controls.append(b)

func _upgrade_ship(ship_id: int, stat: String) -> void:
    var result: Dictionary = campaign.upgrade_ship(ship_id, stat)
    _refresh()
    content.text = "SHIP UPGRADE\n\n" + (str(result) if result.get("ok",false) else "Upgrade failed: " + String(result.get("reason","unknown")))


func _rebuild_cargo_controls() -> void:
    _clear_controls(cargo_controls)
    if selected_tab != "navy" or panel == null:
        return
    var ids: Array[int] = campaign.get_player_ship_ids()
    for i in range(min(ids.size(), 2)):
        var ship_id := ids[i]
        for j in range(3):
            var resources := ["food", "wood", "iron"]
            var b := Button.new()
            b.text = "LOAD %s +10 • SHIP %d" % [String(resources[j]).to_upper(), ship_id + 1]
            b.position = Vector2(28 + j * 250, 610 + i * 30)
            b.size = Vector2(230, 28)
            b.pressed.connect(_load_cargo.bind(ship_id, String(resources[j])))
            panel.add_child(b)
            cargo_controls.append(b)

func _load_cargo(ship_id: int, resource: String) -> void:
    var result: Dictionary = campaign.transfer_cargo(ship_id, resource, 10)
    _refresh()
    content.text = "FLEET CARGO\n\n" + (str(result) if result.get("ok",false) else "Cargo load failed: " + String(result.get("reason","unknown")))

func _rebuild_naval_encounter_controls() -> void:
    _clear_controls(naval_encounter_controls)
    if selected_tab != "navy" or panel == null or not campaign.has_pending_naval_encounter():
        return
    var engage := Button.new()
    engage.text = "ENGAGE"
    engage.position = Vector2(28, 400)
    engage.size = Vector2(230, 30)
    engage.pressed.connect(_naval_encounter_action.bind("engage"))
    panel.add_child(engage)
    naval_encounter_controls.append(engage)
    var auto := Button.new()
    auto.text = "AUTO BATTLE"
    auto.position = Vector2(270, 400)
    auto.size = Vector2(230, 30)
    auto.pressed.connect(_naval_encounter_action.bind("auto"))
    panel.add_child(auto)
    naval_encounter_controls.append(auto)
    var retreat := Button.new()
    retreat.text = "RETREAT"
    retreat.position = Vector2(512, 400)
    retreat.size = Vector2(230, 30)
    retreat.pressed.connect(_naval_encounter_action.bind("retreat"))
    panel.add_child(retreat)
    naval_encounter_controls.append(retreat)

func _naval_encounter_action(mode: String) -> void:
    var result: Dictionary = campaign.resolve_pending_naval_encounter(mode)
    _refresh()
    if result.get("ok", false):
        content.text = "NAVAL ENCOUNTER\n\n" + String(result.get("message","Encounter resolved."))
    else:
        content.text = "NAVAL ENCOUNTER\n\nAction failed: " + String(result.get("reason","unknown"))

func _rebuild_family_controls() -> void:
    _clear_controls(family_controls)
    if selected_tab != "family" or panel == null:
        return
    var candidates: Array = []
    for member in world.family_members:
        if String(member.get("role","")) != "spouse":
            candidates.append(member)
    for i in range(min(candidates.size(), 2)):
        var member: Dictionary = candidates[i]
        var b := Button.new()
        b.text = "APPOINT %s" % String(member.get("name","HEIR")).to_upper()
        b.position = Vector2(28 + i * 360, 510)
        b.size = Vector2(330, 32)
        b.pressed.connect(_appoint_heir.bind(String(member.get("name",""))))
        panel.add_child(b)
        family_controls.append(b)

func _creatures() -> String:
    var out := "RARE CREATURES & WILDLIFE\n\n"
    for creature in systems.creatures:
        out += "• %s — region %d — HP %d — %s\n" % [
            String(creature.get("kind","Creature")),int(creature.get("region",0)),
            int(creature.get("hp",0)),("alive" if bool(creature.get("alive",false)) else "defeated")
        ]
    out += "\nRare encounters are optional world events, not forced missions."
    return out

func _add_save_buttons() -> void:
    if panel.get_node_or_null("SaveNow") != null:
        return
    var save := Button.new()
    save.name = "SaveNow"
    save.text = "SAVE WORLD"
    save.position = Vector2(150, 455)
    save.size = Vector2(220, 50)
    save.pressed.connect(_save_world)
    panel.add_child(save)
    var load := Button.new()
    load.name = "LoadWorld"
    load.text = "LOAD WORLD"
    load.position = Vector2(410, 455)
    load.size = Vector2(220, 50)
    load.pressed.connect(_load_world)
    panel.add_child(load)

func _save_world() -> void:
    var ok: bool = world.save_game()
    content.text = "WORLD SAVED\n\n" + ("Save completed successfully." if ok else "Save failed.")

func _load_world() -> void:
    var ok: bool = world.load_game()
    content.text = "WORLD LOAD\n\n" + ("Save loaded successfully." if ok else "No valid save was found.")

func _political_tax(delta: int) -> void:
    var result: Dictionary = systems.change_law_with_influence("tax", int(systems.laws["tax"]) + delta)
    content.text = "POLITICAL ACTION\n\n" + (str(result) if result.get("ok",false) else "Action failed: " + String(result.get("reason","unknown")))
    _refresh()

func _political_conscription(delta: int) -> void:
    var result: Dictionary = systems.change_law_with_influence("conscription", int(systems.laws["conscription"]) + delta)
    content.text = "POLITICAL ACTION\n\n" + (str(result) if result.get("ok",false) else "Action failed: " + String(result.get("reason","unknown")))
    _refresh()

func _political_peace(_unused: int) -> void:
    var result: Dictionary = systems.negotiate_peace("river_kingdom")
    content.text = "DIPLOMACY\n\n" + (str(result) if result.get("ok",false) else "Action failed: " + String(result.get("reason","unknown")))
    _refresh()

func _political_war(_unused: int) -> void:
    var result: Dictionary = systems.declare_war("river_kingdom")
    content.text = "DIPLOMACY\n\n" + (str(result) if result.get("ok",false) else "Action failed: " + String(result.get("reason","unknown")))
    _refresh()

func _appoint_heir(member_name: String) -> void:
    var result: Dictionary = campaign.appoint_heir(member_name)
    content.text = "SUCCESSION\n\n" + (str(result) if result.get("ok",false) else "Action failed: " + String(result.get("reason","unknown")))
    _refresh()
