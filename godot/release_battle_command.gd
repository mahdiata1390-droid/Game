extends Node3D
class_name ReleaseBattleCommandLayer

var host: Node
var world: Node
var canvas: CanvasLayer
var panel: Panel
var status: Label
var formation := "line"
var order := "hold"
var tick := 0.0

func build(root: Node) -> void:
	host = root
	world = root.get_node_or_null("WorldState")
	_build_ui()

func _process(delta: float) -> void:
	if not is_instance_valid(host):
		return
	tick += delta
	if tick >= 0.5:
		tick = 0.0
		_update_status()
		_apply_formation()

func _build_ui() -> void:
	canvas = CanvasLayer.new()
	canvas.name = "BattleCommandLayer"
	host.add_child(canvas)
	panel = Panel.new()
	panel.position = Vector2(920, 150)
	panel.size = Vector2(300, 335)
	canvas.add_child(panel)

	var title := Label.new()
	title.text = "BATTLE COMMAND"
	title.position = Vector2(14, 10)
	title.add_theme_font_size_override("font_size", 18)
	panel.add_child(title)

	status = Label.new()
	status.position = Vector2(14, 42)
	status.size = Vector2(270, 55)
	panel.add_child(status)

	var formation_title := Label.new()
	formation_title.text = "FORMATION"
	formation_title.position = Vector2(14, 102)
	panel.add_child(formation_title)

	var forms := ["line", "shield_wall", "wedge", "skirmish"]
	for i in range(forms.size()):
		var b := Button.new()
		b.text = forms[i].replace("_", " ").to_upper()
		b.position = Vector2(14 + (i % 2) * 136, 128 + (i / 2) * 38)
		b.size = Vector2(128, 32)
		b.pressed.connect(_set_formation.bind(forms[i]))
		panel.add_child(b)

	var order_title := Label.new()
	order_title.text = "ORDER"
	order_title.position = Vector2(14, 210)
	panel.add_child(order_title)

	var orders := ["hold", "advance", "charge", "retreat"]
	for i in range(orders.size()):
		var b := Button.new()
		b.text = orders[i].to_upper()
		b.position = Vector2(14 + (i % 2) * 136, 236 + (i / 2) * 38)
		b.size = Vector2(128, 32)
		b.pressed.connect(_set_order.bind(orders[i]))
		panel.add_child(b)

	var first := Button.new()
	first.text = "FIRST / THIRD PERSON"
	first.position = Vector2(14, 316)
	first.size = Vector2(272, 32)
	first.pressed.connect(_toggle_camera)
	panel.add_child(first)

func _set_formation(value: String) -> void:
	formation = value
	if is_instance_valid(host):
		host.battle_command_formation = value
	_update_status()

func _set_order(value: String) -> void:
	order = value
	if is_instance_valid(host):
		host.battle_command_order = value
	_update_status()

func _toggle_camera() -> void:
	if host.has_method("_toggle_camera_mode"):
		host._toggle_camera_mode()
	else:
		host.camera_first_person = not bool(host.camera_first_person)
		if is_instance_valid(host.status_label):
			host.status_label.text = "Camera: %s" % ("FIRST PERSON" if host.camera_first_person else "THIRD PERSON")

func _allies() -> Array:
	var result: Array = []
	if not host.has_method("_nearest_enemy"):
		return result
	for data in host.troops:
		if String(data.get("team", "")) == "ALLY" and is_instance_valid(data.get("node")):
			result.append(data)
	return result

func _apply_formation() -> void:
	if not is_instance_valid(host.player):
		return
	var allies := _allies()
	if allies.is_empty():
		return
	var center := host.player.global_position + Vector3(0, 0, -3.0)
	var forward := -host.player.global_transform.basis.z
	var right := host.player.global_transform.basis.x
	var count := allies.size()
	for i in range(count):
		var node: Node3D = allies[i].get("node")
		var target := center
		match formation:
			"line":
				target += right * (float(i) - float(count - 1) / 2.0) * 1.45
			"shield_wall":
				target += right * (float(i) - float(count - 1) / 2.0) * 1.15
				target += forward * 0.5
			"wedge":
				var row := i / 2
				var side := -1.0 if i % 2 == 0 else 1.0
				target += right * side * (float(row) + 0.5) * 1.0
				target += forward * float(row) * 1.25
			"skirmish":
				target += right * (float(i) - float(count - 1) / 2.0) * 2.0
				target += forward * float(i % 3) * 1.2
		if order == "advance":
			target += forward * 4.0
		elif order == "charge":
			target += forward * 7.0
		elif order == "retreat":
			target -= forward * 5.0
		# Blend instead of teleporting so formation changes look like troop movement.
		node.global_position = node.global_position.lerp(target, 0.08)

func _update_status() -> void:
	var allies := 0
	var enemies := 0
	for data in host.troops:
		if not is_instance_valid(data.get("node")):
			continue
		if String(data.get("team", "")) == "ALLY":
			allies += int(data.get("represented_count", 1))
		else:
			enemies += int(data.get("represented_count", 1))
	status.text = "ALLIES %d  •  ENEMY %d\\nFORMATION: %s\\nORDER: %s" % [allies, enemies, formation.to_upper(), order.to_upper()]
