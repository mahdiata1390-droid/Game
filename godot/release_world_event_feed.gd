extends Node
class_name ReleaseWorldEventFeed

var host: Node
var world: Node
var layer: CanvasLayer
var panel: Panel
var label: Label
var last_count = -1

func build(root: Node) -> void:
	host = root
	world = root.get_node_or_null("WorldState")
	if world == null:
		return
	layer = CanvasLayer.new()
	layer.name = "WorldEventFeed"
	root.add_child(layer)
	panel = Panel.new()
	panel.position = Vector2(340, 30)
	panel.size = Vector2(540, 145)
	layer.add_child(panel)
	label = Label.new()
	label.position = Vector2(12, 10)
	label.size = Vector2(516, 125)
	label.text = "WORLD EVENTS\\nNo events yet."
	panel.add_child(label)

func _process(_delta: float) -> void:
	if not is_instance_valid(world) or not is_instance_valid(label):
		return
	if last_count == world.world_events.size():
		return
	last_count = world.world_events.size()
	var events = world.world_events
	var start = max(0, events.size() - 5)
	var lines: Array[String] = ["WORLD EVENTS"]
	for i in range(start, events.size()):
		lines.append("• " + String(events[i]))
	label.text = "\\n".join(lines)
