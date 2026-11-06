extends Node
class_name ReleaseDiplomacyBoard

var host: Node
var panel: Panel
var label: Label
var faction_option: OptionButton
var action_option: OptionButton

func build(main: Node) -> void:
	host = main
	var layer := CanvasLayer.new()
	layer.name = "DiplomacyBoardUI"
	host.add_child(layer)
	var button := Button.new()
	button.text = "DIPLOMACY"
	button.position = Vector2(420, 345)
	button.size = Vector2(180, 48)
	button.pressed.connect(_toggle)
	layer.add_child(button)
	panel = Panel.new()
	panel.position = Vector2(300, 90)
	panel.size = Vector2(680, 540)
	panel.visible = false
	layer.add_child(panel)
	var title := Label.new()
	title.text = "DIPLOMACY • FACTIONS"
	title.position = Vector2(25, 20)
	title.add_theme_font_size_override("font_size", 25)
	panel.add_child(title)
	label = Label.new()
	label.position = Vector2(25, 65)
	label.size = Vector2(630, 125)
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)
	faction_option = OptionButton.new()
	faction_option.position = Vector2(25, 205)
	faction_option.size = Vector2(300, 48)
	panel.add_child(faction_option)
	action_option = OptionButton.new()
	for action in ["peace","war","alliance","vassal"]:
		action_option.add_item(action)
	action_option.position = Vector2(345, 205)
	action_option.size = Vector2(260, 48)
	panel.add_child(action_option)
	var apply := Button.new()
	apply.text = "SET RELATION"
	apply.position = Vector2(25, 275)
	apply.size = Vector2(300, 50)
	apply.pressed.connect(_apply)
	panel.add_child(apply)
	var refresh := Button.new()
	refresh.text = "REFRESH"
	refresh.position = Vector2(345, 275)
	refresh.size = Vector2(260, 50)
	refresh.pressed.connect(_refresh)
	panel.add_child(refresh)
	_refresh()

func _refresh() -> void:
	if not host.world_state:
		return
	faction_option.clear()
	for f in host.world_state.factions:
		var id := String(f.get("id",""))
		if id != host.world_state.player_faction:
			faction_option.add_item(String(f.get("name",id)))
			faction_option.set_item_metadata(faction_option.item_count - 1, id)
	var lines: Array[String] = ["Your faction: %s" % host.world_state.get_faction_name(host.world_state.player_faction)]
	for f in host.world_state.factions:
		var id := String(f.get("id",""))
		if id == host.world_state.player_faction:
			continue
		var relation := host.world_state.get_diplomacy(host.world_state.player_faction, id)
		lines.append("• %s: %s" % [String(f.get("name",id)), String(relation)])
	label.text = "\n".join(lines.slice(0, 7))

func _apply() -> void:
	if faction_option.item_count == 0:
		return
	var id := String(faction_option.get_item_metadata(faction_option.selected))
	var action := action_option.get_item_text(action_option.selected)
	var result: Dictionary = host.world_state.set_diplomacy(host.world_state.player_faction, id, action)
	host._show_status("DIPLOMACY • " + ("UPDATED" if result.get("ok",false) else String(result.get("reason","FAILED"))), 2.0)
	_refresh()

func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()
