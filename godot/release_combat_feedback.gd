extends Node
class_name ReleaseCombatFeedback

var game: Node3D
var world: Node
var tick = 0.0

func build(main_node: Node3D) -> void:
    game = main_node
    world = game.get("world_state")
    set_process(true)

func _process(delta: float) -> void:
    if not is_instance_valid(game):
        return
    tick += delta
    if tick < 0.25:
        return
    tick = 0.0
    _refresh_bars()

func _refresh_bars() -> void:
    var troops_value: Variant = game.get("troops")
    if not (troops_value is Array):
        return
    for troop_value in troops_value:
        if not (troop_value is Dictionary):
            continue
        var node_value: Variant = troop_value.get("node")
        if not (node_value is Node3D) or not is_instance_valid(node_value):
            continue
        var hp = int(troop_value.get("hp", troop_value.get("health", 100)))
        var label = node_value.get_node_or_null("CombatHP") as Label3D
        if label == null:
            label = Label3D.new()
            label.name = "CombatHP"
            label.position = Vector3(0, 2.1, 0)
            label.font_size = 18
            label.outline_size = 5
            node_value.add_child(label)
        label.text = "HP %d" % hp
