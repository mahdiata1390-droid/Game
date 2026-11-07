extends Node
class_name ReleaseArmyAndSettlementManager

var host: Node
var world: Node
var layer: CanvasLayer
var panel: Panel
var info: Label
var selected_army = 0
var selected_settlement = 0

func build(root: Node) -> void:
	host = root
	world = root.get_node_or_null("WorldState")
	if world == null:
		return
	layer = CanvasLayer.new()
	layer.name = "ArmySettlementManager"
	root.add_child(layer)
	_build()

func _build() -> void:
	panel = Panel.new()
	panel.position = Vector2(28, 30)
	panel.size = Vector2(320, 430)
	layer.add_child(panel)
	var title = Label.new()
	title.text = "ARMY & SETTLEMENT"
	title.position = Vector2(12, 10)
	title.add_theme_font_size_override("font_size", 17)
	panel.add_child(title)
	info = Label.new()
	info.position = Vector2(12, 42)
	info.size = Vector2(296, 160)
	panel.add_child(info)
	var labels = ["NEXT ARMY","FORM LINE","SHIELD WALL","WEDGE","SKIRMISH","HOLD","ATTACK","DEFEND","RAID","GARRISON","BUILD BARRACKS"]
	for i in range(labels.size()):
		var b = Button.new()
		b.text = labels[i]
		b.position = Vector2(12 + (i % 2) * 150, 215 + (i / 2) * 35)
		b.size = Vector2(140, 30)
		b.pressed.connect(_action.bind(labels[i]))
		panel.add_child(b)
	_update()

func _action(action: String) -> void:
	if action == "NEXT ARMY":
		selected_army = (selected_army + 1) % max(1, world.armies.size())
	elif action in ["FORM LINE","SHIELD WALL","WEDGE","SKIRMISH"]:
		var f = {"FORM LINE":"line","SHIELD WALL":"shield_wall","WEDGE":"wedge","SKIRMISH":"skirmish"}[action]
		world.set_army_formation(selected_army, f)
	elif action in ["HOLD","ATTACK","DEFEND","RAID"]:
		world.set_army_order(selected_army, action.to_lower())
	elif action == "GARRISON":
		var sid = _owned_settlement()
		world.garrison_army_in_settlement(selected_army, sid)
	elif action == "BUILD BARRACKS":
		var sid = _owned_settlement()
		world.upgrade_settlement_building(sid, "barracks")
	_update()

func _owned_settlement() -> int:
	for s in world.settlements:
		if String(s.get("owner","")) == String(world.player_faction) and int(s.get("region",-1)) == int(world.player_region_id):
			return int(s.get("id",-1))
	return -1

func _update() -> void:
	if world.armies.is_empty():
		info.text = "No armies."
		return
	selected_army = clamp(selected_army, 0, world.armies.size()-1)
	var a: Dictionary = world.armies[selected_army]
	var sid = _owned_settlement()
	var sname = "None"
	if sid >= 0 and sid < world.settlements.size():
		sname = String(world.settlements[sid].get("name",""))
	info.text = "Army: %s\\nTroops: %d\\nMorale: %d\\nRegion: %s\\nFormation: %s\\nOrder: %s\\n\\nOwned settlement: %s" % [
		String(a.get("name","")), int(a.get("soldiers",0)), int(a.get("morale",0)),
		String(world.regions[int(a.get("region",0))].get("name","")), String(a.get("formation","line")),
		String(a.get("order","hold")), sname]
