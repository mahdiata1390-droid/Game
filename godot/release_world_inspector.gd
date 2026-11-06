extends Node
class_name ReleaseWorldInspector

var host:Node
var panel:Panel
var label:Label

func build(main:Node)->void:
	host=main
	var layer:=CanvasLayer.new()
	host.add_child(layer)
	var open:=Button.new()
	open.text="WORLD"
	open.position=Vector2(1020,465)
	open.size=Vector2(180,48)
	open.pressed.connect(_toggle)
	layer.add_child(open)
	panel=Panel.new()
	panel.position=Vector2(350,90)
	panel.size=Vector2(580,520)
	panel.visible=false
	layer.add_child(panel)
	var title:=Label.new()
	title.text="WORLD INSPECTOR"
	title.position=Vector2(24,20)
	title.add_theme_font_size_override("font_size",25)
	panel.add_child(title)
	label=Label.new()
	label.position=Vector2(24,65)
	label.size=Vector2(530,420)
	label.add_theme_font_size_override("font_size",18)
	panel.add_child(label)
	var refresh:=Button.new()
	refresh.text="REFRESH WORLD"
	refresh.position=Vector2(24,450)
	refresh.size=Vector2(240,45)
	refresh.pressed.connect(_refresh)
	panel.add_child(refresh)
	_refresh()

func _refresh()->void:
	if not host.world_state:return
	var s:Dictionary=host.world_state.get_world_status()
	var lines:Array[String]=[
		"DAY %d • %s • %02d:00" % [int(s.get("day",1)),String(s.get("weather","clear")),int(float(s.get("time",12.0)))],
		"Gold: %d • Level: %d" % [int(s.get("gold",0)),int(s.get("level",1))],
		"Settlements: %d • Armies: %d" % [int(s.get("settlements",0)),int(s.get("armies",0))],
		"Sieges: %d • Caravans: %d • Ships: %d" % [int(s.get("sieges",0)),int(s.get("caravans",0)),int(s.get("ships",0))],
		"",
		"FACTIONS"
	]
	for f in host.world_state.factions:
		lines.append("• %s" % String(f.get("name",f.get("id","Unknown"))))
	label.text="\n".join(lines.slice(0,16))

func _toggle()->void:
	panel.visible=not panel.visible
	_refresh()
