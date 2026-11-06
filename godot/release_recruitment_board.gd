extends Node
class_name ReleaseRecruitmentBoard

var host: Node
var panel: Panel
var settlements: OptionButton
var troops_box: OptionButton
var amount: SpinBox
var info: Label

func build(main: Node) -> void:
	host = main
	var layer := CanvasLayer.new()
	host.add_child(layer)
	var open := Button.new()
	open.text = "RECRUIT"
	open.position = Vector2(820,345)
	open.size = Vector2(180,48)
	open.pressed.connect(_toggle)
	layer.add_child(open)
	panel = Panel.new()
	panel.position = Vector2(280,110)
	panel.size = Vector2(720,460)
	panel.visible = false
	layer.add_child(panel)
	var title := Label.new()
	title.text = "RECRUITMENT & BUILDINGS"
	title.position = Vector2(24,20)
	title.add_theme_font_size_override("font_size",24)
	panel.add_child(title)
	info = Label.new()
	info.position = Vector2(24,62)
	info.size = Vector2(660,100)
	panel.add_child(info)
	settlements = OptionButton.new()
	settlements.position = Vector2(24,175)
	settlements.size = Vector2(320,48)
	panel.add_child(settlements)
	troops_box = OptionButton.new()
	for t in ["levy","spearman","archer","horseman"]:
		troops_box.add_item(t)
	troops_box.position = Vector2(360,175)
	troops_box.size = Vector2(170,48)
	panel.add_child(troops_box)
	amount = SpinBox.new()
	amount.min_value = 1
	amount.max_value = 100
	amount.value = 10
	amount.position = Vector2(545,175)
	amount.size = Vector2(120,48)
	panel.add_child(amount)
	var recruit := Button.new()
	recruit.text = "RECRUIT"
	recruit.position = Vector2(24,245)
	recruit.size = Vector2(210,50)
	recruit.pressed.connect(_recruit)
	panel.add_child(recruit)
	var farm := Button.new()
	farm.text = "UPGRADE FARM"
	farm.position = Vector2(250,245)
	farm.size = Vector2(190,50)
	farm.pressed.connect(func(): _upgrade("farm"))
	panel.add_child(farm)
	var market := Button.new()
	market.text = "UPGRADE MARKET"
	market.position = Vector2(455,245)
	market.size = Vector2(190,50)
	market.pressed.connect(func(): _upgrade("market"))
	panel.add_child(market)
	var barracks := Button.new()
	barracks.text = "UPGRADE BARRACKS"
	barracks.position = Vector2(24,315)
	barracks.size = Vector2(210,50)
	barracks.pressed.connect(func(): _upgrade("barracks"))
	panel.add_child(barracks)
	var workshop := Button.new()
	workshop.text = "UPGRADE WORKSHOP"
	workshop.position = Vector2(250,315)
	workshop.size = Vector2(190,50)
	workshop.pressed.connect(func(): _upgrade("workshop"))
	panel.add_child(workshop)
	_refresh()

func _selected() -> int:
	if settlements.item_count == 0:
		return -1
	return int(settlements.get_item_metadata(settlements.selected))

func _refresh() -> void:
	if not host.world_state:
		return
	settlements.clear()
	for i in range(host.world_state.settlements.size()):
		var s: Dictionary = host.world_state.settlements[i]
		if String(s.get("owner","")) == host.world_state.player_faction:
			settlements.add_item(String(s.get("name","Settlement")))
			settlements.set_item_metadata(settlements.item_count-1,i)
	var sid := _selected()
	if sid >= 0:
		var s: Dictionary = host.world_state.settlements[sid]
		info.text = "%s  •  Population %d  •  Garrison %d\nGold: %d  •  Buildings: %s" % [String(s.get("name","")),int(s.get("population",0)),int(s.get("garrison",0)),host.world_state.gold,String(s.get("buildings",{}))]
	else:
		info.text = "No owned settlement."

func _recruit() -> void:
	var sid := _selected()
	if sid < 0: return
	var result: Dictionary = host.world_state.recruit_from_settlement(sid,troops_box.get_item_text(troops_box.selected),int(amount.value))
	host._show_status("RECRUIT • "+("SUCCESS" if result.get("ok",false) else String(result.get("reason","FAILED"))),2.0)
	_refresh()

func _upgrade(building: String) -> void:
	var sid := _selected()
	if sid < 0: return
	var result: Dictionary = host.world_state.upgrade_settlement_building(sid,building)
	host._show_status("BUILD • "+("SUCCESS" if result.get("ok",false) else String(result.get("reason","FAILED"))),2.0)
	_refresh()

func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()
