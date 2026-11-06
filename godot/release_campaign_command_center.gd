extends Node
class_name ReleaseCampaignCommandCenter

var host: Node
var world: Node
var layer: CanvasLayer
var panel: Panel
var log_label: Label

func build(root: Node) -> void:
	host = root
	world = root.get_node_or_null("WorldState")
	if world == null:
		return
	layer = CanvasLayer.new()
	layer.name = "CampaignCommandCenter"
	root.add_child(layer)
	_build_panel()

func _button(text_value: String, pos: Vector2, size: Vector2, action: Callable) -> void:
	var b := Button.new()
	b.text = text_value
	b.position = pos
	b.size = size
	b.pressed.connect(action)
	panel.add_child(b)

func _build_panel() -> void:
	panel = Panel.new()
	panel.position = Vector2(28, 520)
	panel.size = Vector2(1220, 175)
	layer.add_child(panel)
	var title := Label.new()
	title.text = "CAMPAIGN COMMAND • ECONOMY • DIPLOMACY • FAMILY"
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 16)
	panel.add_child(title)
	_button("RECRUIT", Vector2(12, 40), Vector2(130, 38), _recruit)
	_button("UPGRADE FARM", Vector2(150, 40), Vector2(145, 38), _farm)
	_button("UPGRADE MARKET", Vector2(305, 40), Vector2(155, 38), _market)
	_button("TRADE CARAVAN", Vector2(470, 40), Vector2(150, 38), _trade)
	_button("NAVAL MOVE", Vector2(630, 40), Vector2(135, 38), _naval_move)
	_button("DIPLOMACY", Vector2(775, 40), Vector2(135, 38), _diplomacy)
	_button("FAMILY", Vector2(920, 40), Vector2(120, 38), _family)
	_button("NEXT DAY", Vector2(1050, 40), Vector2(145, 38), _next_day)
	log_label = Label.new()
	log_label.position = Vector2(14, 88)
	log_label.size = Vector2(1180, 75)
	log_label.text = "Campaign command center ready."
	panel.add_child(log_label)

func _player_settlement() -> int:
	var region := int(world.player_region_id)
	for s in world.settlements:
		if int(s.get("region",-1)) == region and String(s.get("owner","")) == String(world.player_faction):
			return int(s.get("id",-1))
	return -1

func _player_army() -> int:
	for a in world.armies:
		if String(a.get("owner","")) == String(world.player_faction) and int(a.get("region",-1)) == int(world.player_region_id):
			return int(a.get("id",-1))
	return -1

func _show(result: Dictionary) -> void:
	log_label.text = " • ".join([str(result.get("ok", false)), str(result.get("reason", result.get("message", result.get("count", ""))))])

func _recruit() -> void:
	var sid := _player_settlement()
	if sid < 0:
		_show({"ok":false,"reason":"No owned settlement in this region"})
		return
	_show(world.recruit_from_settlement(sid, "spearman", 10))

func _farm() -> void:
	var sid := _player_settlement()
	_show(world.upgrade_settlement_building(sid, "farm"))

func _market() -> void:
	var sid := _player_settlement()
	_show(world.upgrade_settlement_building(sid, "market"))

func _trade() -> void:
	var sid := _player_settlement()
	if sid < 0:
		_show({"ok":false,"reason":"No owned settlement"})
		return
	var destination := -1
	for s in world.settlements:
		if int(s.get("id",-1)) != sid and int(s.get("region",-1)) != int(world.player_region_id):
			destination = int(s.get("id",-1))
			break
	if destination < 0:
		_show({"ok":false,"reason":"No destination"})
		return
	_show(world.create_caravan(sid, destination))

func _naval_move() -> void:
	for i in range(world.ships.size()):
		var ship := world.ships[i]
		if String(ship.get("owner","")) == String(world.player_faction):
			var neighbors: Array = world.get_region_neighbors(int(ship.get("region",0)))
			for n in neighbors:
				var resource := String(world.regions[int(n)].get("resource",""))
				if resource == "fish" or resource == "salt":
					_show(world.issue_ship_move(i, int(n)))
					return
	_show({"ok":false,"reason":"No player ship available"})

func _diplomacy() -> void:
	_show(world.set_diplomacy(String(world.player_faction), "river_kingdom", "trade"))

func _family() -> void:
	_show(world.add_family_member("Aldric", "companion", 24))

func _next_day() -> void:
	world.advance_day()
	var s: Dictionary = world.get_world_status()
	_show({"ok":true,"message":"Day %d • %s • %d gold • %d armies • %d settlements" % [int(s.day), String(s.weather), int(s.gold), int(s.armies), int(s.settlements)]})
