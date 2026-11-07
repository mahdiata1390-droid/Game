extends Node
class_name ReleaseSettlementManagement

## Player-facing settlement command panel: taxes, buildings and militia.

var host: Node3D
var world
var layer: CanvasLayer
var panel: Panel
var info: Label
var selected_settlement: int = 0

func build(root: Node3D) -> void:
	host = root
	world = root.get("world_state")
	layer = CanvasLayer.new()
	layer.name = "SettlementManagement"
	root.add_child(layer)
	_build()
	_update()

func _build() -> void:
	panel = Panel.new()
	panel.position = Vector2(365, 30)
	panel.size = Vector2(330, 430)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "SETTLEMENT MANAGEMENT"
	title.position = Vector2(12, 10)
	title.add_theme_font_size_override("font_size", 17)
	panel.add_child(title)
	info = Label.new()
	info.position = Vector2(12, 42)
	info.size = Vector2(316, 165)
	panel.add_child(info)
	var labels := ["NEXT SETTLEMENT","TAX -","TAX +","FARM","MARKET","WORKSHOP","BARRACKS","LEVY","ARCHER","SPEARMAN"]
	for i in range(labels.size()):
		var b := Button.new()
		b.text = labels[i]
		b.position = Vector2(12 + (i % 2) * 150, 215 + (i / 2) * 35)
		b.size = Vector2(140, 30)
		b.pressed.connect(_action.bind(labels[i]))
		panel.add_child(b)

func _owned_settlements() -> Array:
	var result: Array = []
	if world == null:
		return result
	for s in world.settlements:
		if String(s.get("owner","")) == String(world.player_faction):
			result.append(int(s.get("id",-1)))
	return result

func _current_id() -> int:
	var ids := _owned_settlements()
	if ids.is_empty():
		return -1
	if selected_settlement not in ids:
		selected_settlement = ids[0]
	return selected_settlement

func _action(action: String) -> void:
	if world == null:
		return
	var ids := _owned_settlements()
	if ids.is_empty():
		_update()
		return
	if action == "NEXT SETTLEMENT":
		var idx := ids.find(_current_id())
		selected_settlement = ids[(idx + 1) % ids.size()]
	elif action == "TAX -":
		var s: Dictionary = world.settlements[_current_id()]
		s["tax_rate"] = max(0.05, float(s.get("tax_rate",0.10)) - 0.01)
	elif action == "TAX +":
		var s: Dictionary = world.settlements[_current_id()]
		s["tax_rate"] = min(0.20, float(s.get("tax_rate",0.10)) + 0.01)
	elif action in ["FARM","MARKET","WORKSHOP","BARRACKS"]:
		world.upgrade_settlement_building(_current_id(), action.to_lower())
	elif action in ["LEVY","ARCHER","SPEARMAN"]:
		var troop: String = String({"LEVY":"levy","ARCHER":"archer","SPEARMAN":"spearman"}[action])
		world.recruit_from_settlement(_current_id(), troop, 5)
	_update()

func _update() -> void:
	if world == null:
		info.text = "World loading..."
		return
	var sid := _current_id()
	if sid < 0:
		info.text = "No owned settlements. Capture or acquire one first."
		return
	var s: Dictionary = world.settlements[sid]
	var b: Dictionary = s.get("buildings",{})
	info.text = "Settlement: %s\nPopulation: %d\nSatisfaction: %d\nProsperity: %d\nGarrison: %d\nMilitia: %d / %d\nTax: %.0f%%\n\nBuildings  Farm %d • Market %d\nWorkshop %d • Barracks %d\nGold: %d" % [
		String(s.get("name","")), int(s.get("population",0)), int(s.get("satisfaction",55)),
		int(s.get("prosperity",50)), int(s.get("garrison",0)), int(s.get("militia_ready",0)),
		int(s.get("militia_cap",0)), float(s.get("tax_rate",0.10))*100.0,
		int(b.get("farm",1)), int(b.get("market",1)), int(b.get("workshop",1)),
		int(b.get("barracks",1)), int(world.gold)]
