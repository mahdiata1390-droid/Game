extends Node
class_name ReleaseEquipmentArmory

var host: Node
var panel: Panel
var label: Label

func build(main: Node) -> void:
	host = main
	var layer := CanvasLayer.new()
	layer.name = "EquipmentArmoryUI"
	host.add_child(layer)
	var button := Button.new()
	button.text = "ARMORY"
	button.position = Vector2(28, 345)
	button.size = Vector2(180, 48)
	button.pressed.connect(_toggle)
	layer.add_child(button)

	panel = Panel.new()
	panel.position = Vector2(300, 120)
	panel.size = Vector2(680, 470)
	panel.visible = false
	layer.add_child(panel)

	var title := Label.new()
	title.text = "ARMORY • EQUIPMENT"
	title.position = Vector2(25, 20)
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)
	label = Label.new()
	label.position = Vector2(25, 68)
	label.size = Vector2(620, 120)
	label.add_theme_font_size_override("font_size", 18)
	panel.add_child(label)
	_add_upgrade("weapon", "STEEL SWORD", 120, 220)
	_add_upgrade("armor", "PLATE ARMOR", 180, 285)
	_add_upgrade("horse", "WAR HORSE", 220, 350)
	_add_upgrade("shield", "STEEL SHIELD", 100, 415)
	_refresh()

func _add_upgrade(slot: String, item: String, cost: int, y: int) -> void:
	var b := Button.new()
	b.text = "%s  •  %dg" % [item, cost]
	b.position = Vector2(25, y)
	b.size = Vector2(300, 48)
	b.pressed.connect(func(): _buy(slot, item, cost))
	panel.add_child(b)

func _buy(slot: String, item: String, cost: int) -> void:
	if not host.world_state:
		return
	var result: Dictionary = host.world_state.upgrade_player_equipment(slot, item, cost)
	if result.get("ok", false):
		host._show_status("EQUIPPED • %s" % item, 2.0)
	else:
		host._show_status("ARMORY • %s" % String(result.get("reason", "FAILED")), 2.0)
	_refresh()

func _refresh() -> void:
	if not label or not host.world_state:
		return
	var eq: Dictionary = host.world_state.player_equipment
	label.text = "Gold: %d\nWeapon: %s\nArmor: %s\nHorse: %s\nShield: %s\nCombat bonus: +%d%%" % [host.world_state.gold, eq.get("weapon","basic_sword"), eq.get("armor","cloth_armor"), eq.get("horse","none"), eq.get("shield","wood_shield"), int(host.world_state.get_player_combat_bonus() * 100.0)]

func _toggle() -> void:
	panel.visible = not panel.visible
	_refresh()
