extends Node

var world: Node
var systems: Node
var layer: CanvasLayer
var open_button: Button
var panel: Panel
var content: Label
var selected_tab := "overview"

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_setup")

func _setup() -> void:
    var scene := get_tree().current_scene
    if scene == null:
        return
    world = scene.get_node_or_null("WorldState")
    systems = get_node_or_null("/root/FinalGameSystems")
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
    panel.size = Vector2(820, 610)
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
    content.size = Vector2(760, 385)
    content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    content.add_theme_font_size_override("font_size", 18)
    panel.add_child(content)

    var close := Button.new()
    close.text = "CLOSE"
    close.position = Vector2(330, 545)
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
    if world == null or systems == null or content == null:
        return
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
    return "GOVERNMENT & POLITICS\n\nTax: %d\nConscription: %d\nTrade duty: %d\n\nFaction relations and wars change over time.\nLow prosperity plus heavy taxation can trigger rebellions.\nTrade routes feed faction treasuries and affect the wider economy." % [
        int(laws["tax"]),int(laws["conscription"]),int(laws["trade_duty"])
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
    return lines

func _navy() -> String:
    var out := "NAVY & SEA\n\n"
    for ship in world.ships:
        out += "• %s — owner %s — region %d — crew %d\n" % [
            String(ship.get("name","Ship")),String(ship.get("owner","unknown")),
            int(ship.get("region",0)),int(ship.get("crew",0))
        ]
    out += "\nShips carry cargo and can move between coastal regions.\nNaval engagements use crew, cargo value and combat power to produce persistent casualties and loot."
    return out

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
