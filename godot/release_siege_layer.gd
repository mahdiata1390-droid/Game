extends Node3D
class_name ReleaseSiegeLayer

var host: Node3D
var world: Node
var markers: Dictionary = {}
var ui: CanvasLayer
var status: Label
var tick := 0.0

func build(root: Node3D) -> void:
	host = root
	world = root.get_node_or_null("WorldState")
	if world == null:
		return
	_build_ui()
	_sync(true)

func _process(delta: float) -> void:
	if world == null or host == null:
		return
	tick += delta
	if tick >= 0.4:
		tick = 0.0
		_sync(false)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "SiegeLayer"
	host.add_child(ui)
	var panel := Panel.new()
	panel.name = "SiegePanel"
	panel.position = Vector2(28, 355)
	panel.size = Vector2(300, 145)
	ui.add_child(panel)

	var title := Label.new()
	title.text = "SIEGE COMMAND"
	title.position = Vector2(14, 10)
	title.add_theme_font_size_override("font_size", 17)
	panel.add_child(title)

	status = Label.new()
	status.position = Vector2(14, 38)
	status.size = Vector2(272, 40)
	status.text = "No active siege."
	panel.add_child(status)

	var start := Button.new()
	start.text = "START SIEGE"
	start.position = Vector2(14, 84)
	start.size = Vector2(125, 40)
	start.pressed.connect(_start_nearest_siege)
	panel.add_child(start)

	var assault := Button.new()
	assault.text = "ASSAULT"
	assault.position = Vector2(153, 84)
	assault.size = Vector2(125, 40)
	assault.pressed.connect(_assault_active)
	panel.add_child(assault)

func _nearest_enemy_settlement() -> int:
	var best := -1
	var best_distance := INF
	if not world:
		return -1
	var region_id := int(world.player_region_id)
	if region_id < 0 or region_id >= world.regions.size():
		return -1
	var origin: Vector2 = world.regions[region_id].get("position", Vector2.ZERO)
	for settlement in world.settlements:
		var sid := int(settlement.get("id", -1))
		if int(settlement.get("region", -1)) != region_id:
			continue
		if String(settlement.get("owner", "")) == String(world.player_faction):
			continue
		var p: Vector2 = settlement.get("position", origin)
		var d := origin.distance_to(p)
		if d < best_distance:
			best_distance = d
			best = sid
	return best

func _player_army_in_region() -> int:
	for army in world.armies:
		if String(army.get("owner", "")) == String(world.player_faction) and int(army.get("region", -1)) == int(world.player_region_id) and int(army.get("soldiers", 0)) > 0:
			return int(army.get("id", -1))
	return -1

func _start_nearest_siege() -> void:
	var sid := _nearest_enemy_settlement()
	var aid := _player_army_in_region()
	if sid < 0:
		_set_status("No enemy settlement in this region.")
		return
	if aid < 0:
		_set_status("You need an army in this region.")
		return
	var result: Dictionary = world.start_siege(sid, aid)
	if result.get("ok", false):
		_set_status("Siege begun: %s" % String(result.get("settlement", "")))
	else:
		_set_status("Cannot siege: %s" % String(result.get("reason", "unknown")))

func _active_siege_id() -> int:
	for sid in world.sieges.keys():
		return int(sid)
	return -1

func _assault_active() -> void:
	var sid := _active_siege_id()
	if sid < 0:
		_set_status("No active siege.")
		return
	var result: Dictionary = world.assault_siege(sid)
	if result.get("ok", false):
		_set_status("Assault • %s • %d%% • attacker -%d / defender -%d" % [
			String(result.get("phase", "assault")),
			int(result.get("progress", 0)),
			int(result.get("attacker_losses", 0)),
			int(result.get("defender_losses", 0))
		])
	else:
		_set_status("Assault failed: %s" % String(result.get("reason", "unknown")))
	_sync(true)

func _set_status(value: String) -> void:
	if is_instance_valid(status):
		status.text = value

func _sync(force: bool) -> void:
	var seen: Dictionary = {}
	for sid_key in world.sieges.keys():
		var sid := int(sid_key)
		if sid < 0 or sid >= world.settlements.size():
			continue
		seen[sid] = true
		var marker: Node3D = markers.get(sid)
		if not is_instance_valid(marker):
			marker = _create_marker(sid)
			markers[sid] = marker
		var settlement: Dictionary = world.settlements[sid]
		var p: Vector2 = settlement.get("position", Vector2.ZERO)
		marker.position = Vector3(p.x, 0.02, p.y)
		var siege: Dictionary = world.sieges[sid]
		var label := marker.get_node_or_null("SiegeLabel") as Label3D
		if label:
			label.text = "SIEGE %d%%\\n%s" % [int(siege.get("progress", 0)), String(siege.get("phase", "approach")).to_upper()]
		var gate := marker.get_node_or_null("Gate")
		if gate:
			gate.visible = not bool(siege.get("gate_breached", false))
		if sid == _active_siege_id():
			_set_status("%s • %d%% • Gate %s" % [String(settlement.get("name", "Settlement")), int(siege.get("progress", 0)), "BREACHED" if bool(siege.get("gate_breached", false)) else "INTACT"])
	for sid in markers.keys():
		if not seen.has(sid):
			var old: Node = markers[sid]
			if is_instance_valid(old):
				old.queue_free()
			markers.erase(sid)

func _create_marker(sid: int) -> Node3D:
	var root := Node3D.new()
	root.name = "SiegeVisual_%d" % sid
	host.add_child(root)

	var camp := MeshInstance3D.new()
	var camp_mesh := ConeMesh.new()
	camp_mesh.bottom_radius = 0.48
	camp_mesh.top_radius = 0.08
	camp_mesh.height = 0.75
	camp.mesh = camp_mesh
	camp.position = Vector3(-2.0, 0.38, 1.5)
	camp.material_override = _mat(Color(0.38, 0.20, 0.10))
	root.add_child(camp)

	var ram := MeshInstance3D.new()
	var ram_mesh := BoxMesh.new()
	ram_mesh.size = Vector3(1.5, 0.32, 0.32)
	ram.mesh = ram_mesh
	ram.position = Vector3(0, 0.55, 1.1)
	ram.material_override = _mat(Color(0.25, 0.13, 0.06))
	root.add_child(ram)

	var stake := MeshInstance3D.new()
	var stake_mesh := CylinderMesh.new()
	stake_mesh.top_radius = 0.035
	stake_mesh.bottom_radius = 0.055
	stake_mesh.height = 1.3
	stake.mesh = stake_mesh
	stake.position = Vector3(1.4, 0.65, 1.4)
	stake.material_override = _mat(Color(0.18, 0.10, 0.05))
	root.add_child(stake)

	var gate := MeshInstance3D.new()
	gate.name = "Gate"
	var gate_mesh := BoxMesh.new()
	gate_mesh.size = Vector3(1.4, 1.1, 0.16)
	gate.mesh = gate_mesh
	gate.position = Vector3(0, 0.55, 0)
	gate.material_override = _mat(Color(0.16, 0.09, 0.05))
	root.add_child(gate)

	var label := Label3D.new()
	label.name = "SiegeLabel"
	label.position = Vector3(0, 2.0, 0)
	label.font_size = 22
	label.outline_size = 7
	label.modulate = Color(0.96, 0.88, 0.65)
	root.add_child(label)
	return root

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	return m
