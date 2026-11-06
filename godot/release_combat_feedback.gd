extends Node
class_name ReleaseCombatFeedback

var host: Node
var bars: Dictionary = {}
var pulse_time := 0.0

func build(main: Node) -> void:
	host = main
	set_process(true)

func _process(delta: float) -> void:
	if not host or not host.has_method("_troop_combat_stats"):
		return
	pulse_time += delta
	var live: Dictionary = {}
	for data in host.troops:
		var node: Node3D = data.get("node")
		if not is_instance_valid(node):
			continue
		live[node] = true
		var bar: Label = bars.get(node)
		if not is_instance_valid(bar):
			bar = Label3D.new()
			bar.name = "CombatHP"
			bar.font_size = 22
			bar.outline_size = 5
			bar.position = Vector3(0, 2.65, 0)
			node.add_child(bar)
			bars[node] = bar
		var hp := max(0, int(data.get("hp", 0)))
		var max_hp := max(1, int(data.get("max_hp", hp)))
		var filled := clampi(int(round(float(hp) / float(max_hp) * 10.0)), 0, 10)
		bar.text = "HP " + "█".repeat(filled) + "░".repeat(10-filled)
		bar.modulate = Color(0.35, 1.0, 0.45) if filled > 5 else (Color(1.0, 0.75, 0.25) if filled > 2 else Color(1.0, 0.35, 0.30))
		if int(data.get("hp", 0)) < int(data.get("max_hp", 0)) and is_instance_valid(node):
			var body := node.get_node_or_null("Body") as Node3D
			if body:
				body.scale = Vector3.ONE * (1.0 + 0.025 * sin(pulse_time * 18.0))
	for node in bars.keys():
		if not live.has(node) or not is_instance_valid(node):
			bars.erase(node)
