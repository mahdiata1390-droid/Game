extends Node
class_name ReleaseNavalCommand

var host: Node
var panel: Panel
var ship_box: OptionButton
var region_box: OptionButton
var info: Label

func build(main:Node)->void:
	host=main
	var layer:=CanvasLayer.new()
	host.add_child(layer)
	var open:=Button.new()
	open.text="NAVY"
	open.position=Vector2(1020,405)
	open.size=Vector2(180,48)
	open.pressed.connect(_toggle)
	layer.add_child(open)
	panel=Panel.new()
	panel.position=Vector2(310,120)
	panel.size=Vector2(660,440)
	panel.visible=false
	layer.add_child(panel)
	var title:=Label.new()
	title.text="NAVY • FLEET COMMAND"
	title.position=Vector2(24,20)
	title.add_theme_font_size_override("font_size",24)
	panel.add_child(title)
	info=Label.new()
	info.position=Vector2(24,65)
	info.size=Vector2(610,100)
	panel.add_child(info)
	ship_box=OptionButton.new()
	ship_box.position=Vector2(24,185)
	ship_box.size=Vector2(280,48)
	panel.add_child(ship_box)
	region_box=OptionButton.new()
	region_box.position=Vector2(330,185)
	region_box.size=Vector2(280,48)
	panel.add_child(region_box)
	var move:=Button.new()
	move.text="ORDER SHIP TO PORT"
	move.position=Vector2(24,255)
	move.size=Vector2(280,50)
	move.pressed.connect(_move)
	panel.add_child(move)
	var day:=Button.new()
	day.text="ADVANCE DAY"
	day.position=Vector2(330,255)
	day.size=Vector2(280,50)
	day.pressed.connect(_day)
	panel.add_child(day)
	_refresh()

func _refresh()->void:
	if not host.world_state:return
	ship_box.clear()
	region_box.clear()
	for i in range(host.world_state.ships.size()):
		var s:Dictionary=host.world_state.ships[i]
		if String(s.get("owner",""))==host.world_state.player_faction:
			ship_box.add_item("%s • crew %d" % [String(s.get("name","Ship")),int(s.get("crew",0))])
			ship_box.set_item_metadata(ship_box.item_count-1,i)
	for i in range(host.world_state.regions.size()):
		var r:Dictionary=host.world_state.regions[i]
		var resource:=String(r.get("resource",""))
		if resource=="fish" or resource=="salt":
			region_box.add_item(String(r.get("name","Port")))
			region_box.set_item_metadata(region_box.item_count-1,i)
	info.text="Fleet: %d ships\nOrders are persistent in the world state." % host.world_state.ships.size()

func _move()->void:
	if ship_box.item_count==0 or region_box.item_count==0:return
	var result:Dictionary=host.world_state.issue_ship_move(int(ship_box.get_item_metadata(ship_box.selected)),int(region_box.get_item_metadata(region_box.selected)))
	host._show_status("NAVY • "+("ORDER SENT" if result.get("ok",false) else String(result.get("reason","FAILED"))),2.0)
	_refresh()

func _day()->void:
	host.world_state.advance_day()
	_refresh()

func _toggle()->void:
	panel.visible=not panel.visible
	_refresh()
