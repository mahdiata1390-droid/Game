extends Node
class_name ReleaseCaravanTrade

var host: Node
var panel: Panel
var label: Label

func build(main: Node) -> void:
	host = main
	var layer := CanvasLayer.new()
	layer.name = "CaravanTradeUI"
	host.add_child(layer)
	var button := Button.new()
	button.text = "TRADE"
	button.position = Vector2(620, 345)
	button.size = Vector2(180, 48)
	button.pressed.connect(_toggle)
	layer.add_child(button)
	panel = Panel.new()
	panel.position = Vector2(320, 130)
	panel.size = Vector2(620, 430)
	panel.visible = false
	layer.add_child(panel)
	var title := Label.new()
	title.text = "TRADE NETWORK • CARAVANS"
	title.position = Vector2(25, 20)
	title.add_theme_font_size_override("font_size", 25)
	panel.add_child(title)
	label = Label.new()
	label.position = Vector2(25, 65)
	label.size = Vector2(610, 230)
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	var create := Button.new()
	create.text = "CREATE CARAVAN • 100g"
	create.position = Vector2(25, 300)
	create.size = Vector2(285, 50)
	create.pressed.connect(_create)
	panel.add_child(create)
	var day := Button.new()
	day.text = "ADVANCE DAY"
	day.position = Vector2(330, 300)
	day.size = Vector2(275, 50)
	day.pressed.connect(_next_day)
	panel.add_child(day)
	_refresh()

func _refresh() -> void:
	if not host.world_state:
		return
	var s: Dictionary = host.world_state.get_world_status()
	var lines: Array[String] = ["Gold: %d" % int(s.get("gold",0)), "Caravans active: %d" % int(s.get("caravans",0)), "Ships: %d" % int(s.get("ships",0)), "Day %d • %s • %s" % [int(s.get("day",1)), String(s.get("weather","clear")), String(s.get("time","day"))]]
	for c in host.world_state.caravans:
		lines.append("• %s → %s • cargo %s" % [String(c.get("from","?")), String(c.get("to","?")), String(c.get("cargo","?"))])
	label.text = "\n".join(lines.slice(0, 8))

func _create() -> void:
	var owned := -1
	for i in range(host.world_state.settlements.size()):
		if String(host.world_state.settlements[i].get("owner","")) == host.world_state.player_faction:
			owned = i
			break
	if owned < 0:
		host._show_status("NO OWNED SETTLEMENT", 2.0)
		return
	var neighbors: Array = host.world_state.get_region_neighbors(int(host.world_state.settlements[owned]["region"]))
	if neighbors.is_empty():
		host._show_status("NO TRADE ROUTE", 2.0)
		return
	var result: Dictionary = host.world_state.create_caravan(owned, int(neighbors[0]))
	host._show_status("CARAVAN • " + ("CREATED" if result.get("ok",false) else String(result.get("reason","FAILED"))), 2.0)
	_refresh()

func _next_day() -> void:
	host.world_state.advance_day()
	_refresh()

func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()
