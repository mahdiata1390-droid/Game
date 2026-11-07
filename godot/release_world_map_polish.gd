extends Node
class_name ReleaseWorldMapPolish

var game: Node3D
var world
var panel: Panel
var info: Label
var tick: float = 0.0

func build(root: Node3D) -> void:
    game = root
    world = root.get("world_state")
    var layer := CanvasLayer.new()
    layer.name = "WorldMapPolish"
    root.add_child(layer)
    panel = Panel.new()
    panel.position = Vector2(18, 470)
    panel.size = Vector2(330, 190)
    layer.add_child(panel)
    var title := Label.new()
    title.text = "WORLD OVERVIEW"
    title.position = Vector2(12, 10)
    title.add_theme_font_size_override("font_size", 17)
    panel.add_child(title)
    info = Label.new()
    info.position = Vector2(12, 42)
    info.size = Vector2(305, 135)
    info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    panel.add_child(info)
    _refresh()
    set_process(true)

func _process(delta: float) -> void:
    tick += delta
    if tick >= 3.0:
        tick = 0.0
        _refresh()

func _refresh() -> void:
    if world == null:
        world = game.get("world_state")
    if world == null or info == null:
        return
    var faction := String(world.get("player_faction"))
    var owned := 0
    var enemy_armies := 0
    var sieges := 0
    for settlement in world.settlements:
        if String(settlement.get("owner","")) == faction:
            owned += 1
        if bool(settlement.get("siege", false)):
            sieges += 1
    for army in world.armies:
        if String(army.get("owner","")) != faction and int(army.get("soldiers",0)) > 0:
            enemy_armies += 1
    info.text = "Day %d
Settlements: %d  •  Enemy armies: %d
Active sieges: %d
Weather: %s
Gold: %d

Map markers, army status and strategic alerts are live." % [
        int(world.get("day",1)), owned, enemy_armies, sieges,
        String(world.get("weather","clear")), int(world.get("gold",0))
    ]
