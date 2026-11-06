extends Node
class_name ReleaseSiegeCommand

var host: Node
var panel: Panel
var settlement_box: OptionButton
var army_box: OptionButton
var info: Label

func build(main: Node) -> void:
	host=main
	var layer:=CanvasLayer.new()
	host.add_child(layer)
	var open:=Button.new()
	open.text="SIEGE"
	open.position=Vector2(1020,345)
	open.size=Vector2(180,48)
	open.pressed.connect(_toggle)
	layer.add_child(open)
	panel=Panel.new()
	panel.position=Vector2(300,100)
	panel.size=Vector2(680,500)
	panel.visible=false
	layer.add_child(panel)
	var title:=Label.new()
	title.text="SIEGE COMMAND • BREACH & ASSAULT"
	title.position=Vector2(24,20)
	title.add_theme_font_size_override("font_size",24)
	panel.add_child(title)
	info=Label.new()
	info.position=Vector2(24,65)
	info.size=Vector2(630,110)
	panel.add_child(info)
	settlement_box=OptionButton.new()
	settlement_box.position=Vector2(24,190)
	settlement_box.size=Vector2(300,48)
	panel.add_child(settlement_box)
	army_box=OptionButton.new()
	army_box.position=Vector2(350,190)
	army_box.size=Vector2(280,48)
	panel.add_child(army_box)
	var start:=Button.new()
	start.text="START SIEGE"
	start.position=Vector2(24,260)
	start.size=Vector2(280,50)
	start.pressed.connect(_start)
	panel.add_child(start)
	var refresh:=Button.new()
	refresh.text="REFRESH SIEGES"
	refresh.position=Vector2(350,260)
	refresh.size=Vector2(280,50)
	refresh.pressed.connect(_refresh)
	panel.add_child(refresh)
	var day:=Button.new()
	day.text="ADVANCE DAY"
	day.position=Vector2(24,330)
	day.size=Vector2(280,50)
	day.pressed.connect(_day)
	panel.add_child(day)
	_refresh()

func _refresh()->void:
	if not host.world_state:return
	settlement_box.clear()
	army_box.clear()
	for i in range(host.world_state.settlements.size()):
		var s:Dictionary=host.world_state.settlements[i]
		if String(s.get("owner",""))!=host.world_state.player_faction:
			settlement_box.add_item(String(s.get("name","Settlement")))
			settlement_box.set_item_metadata(settlement_box.item_count-1,i)
	for i in range(host.world_state.armies.size()):
		var a:Dictionary=host.world_state.armies[i]
		if String(a.get("owner",""))==host.world_state.player_faction:
			army_box.add_item("%s • %d troops" % [String(a.get("name","Army")),int(a.get("soldiers",0))])
			army_box.set_item_metadata(army_box.item_count-1,i)
	info.text="Active sieges: %d\nChoose an enemy settlement and your army. Siege requires the factions to be at war." % host.world_state.sieges.size()

func _start()->void:
	if settlement_box.item_count==0 or army_box.item_count==0:return
	var sid:=int(settlement_box.get_item_metadata(settlement_box.selected))
	var aid:=int(army_box.get_item_metadata(army_box.selected))
	var result:Dictionary=host.world_state.start_siege(sid,aid)
	host._show_status("SIEGE • "+("STARTED" if result.get("ok",false) else String(result.get("reason","FAILED"))),2.5)
	if result.get("ok",false):
		host.create_siege_visual(String(host.world_state.settlements[sid].get("name","Settlement")),int(host.world_state.settlements[sid].get("wall_level",1)))
	_refresh()

func _day()->void:
	host.world_state.advance_day()
	_refresh()

func _toggle()->void:
	panel.visible=not panel.visible
	_refresh()
