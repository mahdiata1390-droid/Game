extends Node
class_name ReleaseStrategicLayer

var host: Node3D
var world
var layer: CanvasLayer
var panel: Panel
var info: Label
var timer: float = 0.0

func build(root: Node3D) -> void:
	host = root
	world = root.get("world_state")
	layer = CanvasLayer.new()
	layer.name = "StrategicLayer"
	root.add_child(layer)
	panel = Panel.new()
	panel.position = Vector2(12, 72)
	panel.size = Vector2(335, 205)
	layer.add_child(panel)
	info = Label.new()
	info.position = Vector2(10, 8)
	info.size = Vector2(315, 190)
	info.add_theme_font_size_override("font_size", 13)
	panel.add_child(info)
	_update()

func _process(delta: float) -> void:
	timer += delta
	if timer >= 3.0:
		timer = 0.0
		_update()

func _update() -> void:
	if world == null:
		return
	var owned := 0
	var enemy := 0
	var sieged := 0
	for s in world.settlements:
		if String(s.get("owner","")) == String(world.player_faction):
			owned += 1
		if bool(s.get("siege",false)):
			sieged += 1
	for a in world.armies:
		if String(a.get("owner","")) != String(world.player_faction):
			enemy += 1
	var wars := 0
	for key in world.diplomacy.keys():
		if String(world.diplomacy[key]) == "war":
			wars += 1
	info.text = "STRATEGIC WORLD\n\nTerritory: %d settlements\nEnemy armies: %d\nActive sieges: %d\nWar relations: %d\nDay: %d\nWeather: %s\n\nYour gold: %d\nYour armies: %d" % [owned, enemy, sieged, wars, int(world.day), String(world.weather), int(world.gold), _player_armies()]

func _player_armies() -> int:
	var count := 0
	for a in world.armies:
		if String(a.get("owner","")) == String(world.player_faction):
			count += 1
	return count
