extends Node
class_name ReleaseSaveSlots

var host:Node
var panel:Panel
var label:Label

func build(main:Node)->void:
	host=main
	var layer:=CanvasLayer.new()
	host.add_child(layer)
	var open:=Button.new()
	open.text="SAVE SLOTS"
	open.position=Vector2(1020,525)
	open.size=Vector2(180,48)
	open.pressed.connect(_toggle)
	layer.add_child(open)
	panel=Panel.new()
	panel.position=Vector2(380,150)
	panel.size=Vector2(520,370)
	panel.visible=false
	layer.add_child(panel)
	var title:=Label.new()
	title.text="CAMPAIGN SAVE"
	title.position=Vector2(24,20)
	title.add_theme_font_size_override("font_size",24)
	panel.add_child(title)
	label=Label.new()
	label.position=Vector2(24,70)
	label.size=Vector2(470,150)
	panel.add_child(label)
	var save:=Button.new()
	save.text="SAVE CAMPAIGN"
	save.position=Vector2(24,240)
	save.size=Vector2(210,50)
	save.pressed.connect(_save)
	panel.add_child(save)
	var load:=Button.new()
	load.text="LOAD CAMPAIGN"
	load.position=Vector2(260,240)
	load.size=Vector2(210,50)
	load.pressed.connect(_load)
	panel.add_child(load)
	_refresh()

func _refresh()->void:
	if host.world_state:
		var s:Dictionary=host.world_state.get_world_status()
		label.text="Day %d\nGold %d\nSettlements %d\nArmies %d\nSieges %d" % [int(s.get("day",1)),int(s.get("gold",0)),int(s.get("settlements",0)),int(s.get("armies",0)),int(s.get("sieges",0))]

func _save()->void:
	var ok:=host.world_state.save_game()
	host._show_status("SAVE • "+("SUCCESS" if ok else "FAILED"),2.0)
	_refresh()

func _load()->void:
	var ok:=host.world_state.load_game()
	host._show_status("LOAD • "+("SUCCESS" if ok else "NO SAVE"),2.0)
	_refresh()

func _toggle()->void:
	panel.visible=not panel.visible
	_refresh()
