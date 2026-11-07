extends Node
class_name ReleasePresentationPolish

var game: Node3D
var world
var layer: CanvasLayer
var label: Label
var tick: float = 0.0

func build(root: Node3D) -> void:
    game = root
    world = root.get("world_state")
    layer = CanvasLayer.new()
    layer.name = "PresentationPolish"
    root.add_child(layer)
    var panel := Panel.new()
    panel.position = Vector2(930,18)
    panel.size = Vector2(330,95)
    layer.add_child(panel)
    label = Label.new()
    label.position = Vector2(12,10)
    label.size = Vector2(305,75)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size",13)
    panel.add_child(label)
    _refresh()
    set_process(true)

func _process(delta: float) -> void:
    tick += delta
    if tick >= 2.0:
        tick = 0.0
        _refresh()

func _refresh() -> void:
    if world == null:
        world = game.get("world_state")
    if world == null or label == null:
        return
    var phase: String = String(game.get_meta("campaign_phase","survival"))
    var stability: int = int(world.get_meta("political_stability",70))
    label.text = "MEDIEVAL SANDBOX
PHASE: %s  •  STABILITY: %d
Day %d  •  Weather: %s" % [
        phase.to_upper(), stability, int(world.get("day",1)), String(world.get("weather","clear"))
    ]
