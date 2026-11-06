extends Node
class_name ReleaseFamilySuccession

var host: Node
var panel: Panel
var label: Label
var name_input: LineEdit
var age_input: SpinBox
var role_option: OptionButton

func build(main: Node) -> void:
	host = main
	var layer := CanvasLayer.new()
	layer.name = "FamilySuccessionUI"
	host.add_child(layer)
	var button := Button.new()
	button.text = "FAMILY"
	button.position = Vector2(220, 345)
	button.size = Vector2(180, 48)
	button.pressed.connect(_toggle)
	layer.add_child(button)
	panel = Panel.new()
	panel.position = Vector2(310, 110)
	panel.size = Vector2(660, 500)
	panel.visible = false
	layer.add_child(panel)
	var title := Label.new()
	title.text = "HOUSE • FAMILY & SUCCESSION"
	title.position = Vector2(25, 20)
	title.add_theme_font_size_override("font_size", 25)
	panel.add_child(title)
	label = Label.new()
	label.position = Vector2(25, 65)
	label.size = Vector2(610, 145)
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Family member name"
	name_input.position = Vector2(25, 225)
	name_input.size = Vector2(280, 45)
	panel.add_child(name_input)
	age_input = SpinBox.new()
	age_input.min_value = 0
	age_input.max_value = 100
	age_input.value = 20
	age_input.position = Vector2(320, 225)
	age_input.size = Vector2(100, 45)
	panel.add_child(age_input)
	role_option = OptionButton.new()
	for role in ["heir","spouse","child","guardian","relative"]:
		role_option.add_item(role)
	role_option.position = Vector2(430, 225)
	role_option.size = Vector2(180, 45)
	panel.add_child(role_option)
	var add := Button.new()
	add.text = "ADD FAMILY MEMBER"
	add.position = Vector2(25, 285)
	add.size = Vector2(285, 48)
	add.pressed.connect(_add_member)
	panel.add_child(add)
	var guardian := Button.new()
	guardian.text = "HIRE GUARDIAN • 75g"
	guardian.position = Vector2(325, 285)
	guardian.size = Vector2(285, 48)
	guardian.pressed.connect(_guardian)
	panel.add_child(guardian)
	var next := Button.new()
	next.text = "ADVANCE DAY"
	next.position = Vector2(25, 355)
	next.size = Vector2(285, 48)
	next.pressed.connect(_next_day)
	panel.add_child(next)
	_refresh()

func _toggle() -> void:
	if is_instance_valid(panel):
		panel.visible = not panel.visible
		if panel.visible:
			_refresh()

func _add_member() -> void:
	if name_input.text.strip_edges().is_empty():
		return
	var role := role_option.get_item_text(role_option.selected)
	var result: Dictionary = host.world_state.add_family_member(name_input.text.strip_edges(), role, int(age_input.value))
	if result.get("ok", false):
		name_input.clear()
		host._show_status("FAMILY UPDATED", 2.0)
	_refresh()

func _guardian() -> void:
	var result: Dictionary = host.world_state.recruit_guardian()
	host._show_status("GUARDIAN: " + String(result.get("reason","HIRED" if result.get("ok",false) else "FAILED")), 2.0)
	_refresh()

func _next_day() -> void:
	host.world_state.advance_day()
	host._show_status("DAY %d" % host.world_state.day, 2.0)
	_refresh()

func _refresh() -> void:
	if not label or not host.world_state:
		return
	var f: Dictionary = host.world_state.family
	var lines: Array[String] = ["Ruler: %s" % String(f.get("ruler_name","Unknown")), "Heir: %s" % String(f.get("heir_name","None")), "Family members: %d" % host.world_state.family_members.size()]
	for m in host.world_state.family_members:
		lines.append("• %s — %s — age %d — loyalty %d" % [m.get("name",""), m.get("role",""), int(m.get("age",0)), int(m.get("loyalty",0))])
	label.text = "\n".join(lines.slice(0, 7))
