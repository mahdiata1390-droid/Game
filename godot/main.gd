extends Node3D

const PLAYER_SPEED := 5.0
const TROOP_SPEED := 2.1
const ATTACK_RANGE := 1.7
const ATTACK_DAMAGE := 12
const MAX_HP := 100

var player: CharacterBody3D
var player_hp := MAX_HP
var camera: Camera3D
var yaw := 0.0
var pitch := -12.0
var move_touch := Vector2.ZERO
var look_touch := Vector2.ZERO
var touch_look_active := false
var troops: Array[Dictionary] = []
var status_label: Label
var hp_label: Label
var attack_cooldown := 0.0
var battle_time := 0.0
var world_state: WorldState
var world_map_panel: Control
var world_map_label: Label
var map_open := false
var travel_buttons: Array[Node] = []
var map_canvas: ColorRect

func _ready() -> void:
	world_state = WorldState.new()
	world_state.name = "WorldState"
	add_child(world_state)
	world_state.initialize_continent()
	_build_world()
	_build_player()
	_build_warband()
	_build_ui()
	_spawn_extra_banners()
	_spawn_continent_world()
	_build_world_map_ui()

func _spawn_extra_banners_once() -> void:
	_spawn_extra_banners()

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.075, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.62, 0.72)
	environment.ambient_light_energy = 0.8
	world_env.environment = environment
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.2
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "Ground"
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(70, 70)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.20, 0.25, 0.16)
	mesh.material_override = mat
	ground.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(70, 0.2, 70)
	shape.shape = box
	shape.position.y = -0.1
	ground.add_child(shape)
	add_child(ground)

	_create_settlement(Vector3(-8, 0, -7))
	_create_settlement(Vector3(10, 0, -10))
	_create_tree_cluster()
	_create_rocks_and_paths()

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.82
	return m

func _mesh_box(size: Vector3, pos: Vector3, color: Color, parent: Node3D, rotation := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.rotation_degrees = rotation
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _mesh_cylinder(radius: float, height: float, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.05
	mesh.height = height
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _mesh_sphere(radius: float, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _create_settlement(center: Vector3) -> void:
	# Settlements are stylized authored silhouettes: readable from gameplay distance,
	# with enough construction detail to never look like colored placeholder blocks.
	for i in range(5):
		var house := Node3D.new()
		house.name = "MedievalHouse_%d" % i
		house.position = center + Vector3((i % 3) * 4.2 - 4.2, 0, (i / 3) * 4.4)
		add_child(house)
		var wall := _mat(Color(0.42, 0.30, 0.20))
		_mesh_box(Vector3(3.4, 2.4, 3.0), Vector3(0, 1.2, 0), wall.albedo_color, house)
		_mesh_box(Vector3(3.7, 0.35, 3.3), Vector3(0, 2.55, 0), Color(0.16, 0.08, 0.055), house, Vector3(0, 0, 3.0))
		_mesh_box(Vector3(0.7, 1.25, 0.08), Vector3(0, 0.63, -1.53), Color(0.12, 0.065, 0.035), house)
		_mesh_box(Vector3(0.45, 0.55, 0.08), Vector3(-0.9, 1.35, -1.54), Color(0.10, 0.18, 0.22), house)
		_mesh_box(Vector3(0.45, 0.55, 0.08), Vector3(0.9, 1.35, -1.54), Color(0.10, 0.18, 0.22), house)
		# Timber framing and a small chimney make each building read as designed.
		_mesh_box(Vector3(3.0, 0.12, 0.10), Vector3(0, 1.55, -1.56), Color(0.16, 0.09, 0.05), house)
		_mesh_box(Vector3(0.12, 1.9, 0.10), Vector3(-1.25, 1.25, -1.56), Color(0.16, 0.09, 0.05), house)
		_mesh_box(Vector3(0.12, 1.9, 0.10), Vector3(1.25, 1.25, -1.56), Color(0.16, 0.09, 0.05), house)
		_mesh_box(Vector3(0.42, 0.8, 0.42), Vector3(1.0, 3.0, 0.7), Color(0.22, 0.22, 0.20), house)

func _create_tree_cluster() -> void:
	for i in range(35):
		var tree := Node3D.new()
		var x := float((i * 17) % 50) - 25.0
		var z := float((i * 29) % 50) - 25.0
		tree.position = Vector3(x, 0, z)
		add_child(tree)
		_mesh_cylinder(0.18, 1.8, Vector3(0, 0.9, 0), Color(0.22, 0.12, 0.07), tree)
		_mesh_sphere(0.95, Vector3(0, 2.0, 0), Color(0.08, 0.30, 0.10), tree)
		_mesh_sphere(0.7, Vector3(0.45, 2.55, 0.1), Color(0.10, 0.38, 0.13), tree)

func _create_rocks_and_paths() -> void:
	for i in range(24):
		var x := float((i * 11) % 48) - 24.0
		var z := float((i * 7) % 38) - 19.0
		_mesh_sphere(0.25 + float(i % 3) * 0.12, Vector3(x, 0.2, z), Color(0.25, 0.27, 0.25), self)
	for i in range(11):
		_mesh_box(Vector3(2.4, 0.08, 1.1), Vector3(-8 + i * 1.7, 0.05, -2.0), Color(0.32, 0.27, 0.19), self)

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	add_child(player)
	player.position = Vector3(0, 1, 8)

	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.8
	capsule.radius = 0.45
	body.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.42, 0.78)
	body.material_override = mat
	player.add_child(body)

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.height = 1.8
	capsule_shape.radius = 0.45
	collision.shape = capsule_shape
	player.add_child(collision)

	camera = Camera3D.new()
	camera.position = Vector3(0, 4.2, 7.5)
	camera.rotation_degrees = Vector3(-12, 180, 0)
	player.add_child(camera)
	camera.current = true

func _build_warband() -> void:
	for i in range(6):
		_spawn_troop("ALLY", "north_kingdom", Vector3(-5 + i * 2.0, 1, 3 + (i % 2) * 1.8))
	for i in range(8):
		_spawn_troop("ENEMY", "river_kingdom", Vector3(-7 + i * 2.0, 1, -10 - (i % 2) * 1.8))

func _faction_troop_palette(faction_id: String) -> Dictionary:
	match faction_id:
		"north_kingdom":
			return {"armor": Color(0.16,0.20,0.25), "cloth": Color(0.055,0.11,0.25), "metal": Color(0.78,0.82,0.86), "leather": Color(0.20,0.14,0.09), "shield": Color(0.055,0.11,0.25), "style": "north"}
		"river_kingdom":
			return {"armor": Color(0.28,0.25,0.21), "cloth": Color(0.13,0.09,0.06), "metal": Color(0.76,0.68,0.48), "leather": Color(0.24,0.13,0.06), "shield": Color(0.13,0.09,0.06), "style": "royal"}
		"eastern_tribes":
			return {"armor": Color(0.31,0.20,0.14), "cloth": Color(0.34,0.055,0.035), "metal": Color(0.70,0.58,0.38), "leather": Color(0.28,0.16,0.08), "shield": Color(0.34,0.055,0.035), "style": "steppe"}
		"southern_sultanate":
			return {"armor": Color(0.50,0.40,0.25), "cloth": Color(0.16,0.10,0.045), "metal": Color(0.86,0.70,0.30), "leather": Color(0.24,0.12,0.05), "shield": Color(0.16,0.10,0.045), "style": "sahr"}
		_:
			return {"armor": Color(0.24,0.20,0.28), "cloth": Color(0.10,0.075,0.13), "metal": Color(0.68,0.72,0.70), "leather": Color(0.20,0.12,0.08), "shield": Color(0.10,0.075,0.13), "style": "clan"}

func _spawn_troop(team: String, faction_id: String, pos: Vector3) -> void:
	var troop := CharacterBody3D.new()
	troop.position = pos
	troop.name = faction_id + "_Soldier"
	add_child(troop)
	_create_soldier_visual(troop, faction_id)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.7
	shape.radius = 0.38
	collision.shape = shape
	troop.add_child(collision)
	troops.append({"node": troop, "team": team, "faction": faction_id, "hp": 60, "cooldown": 0.0})

func _create_soldier_visual(parent: Node3D, faction_id: String) -> void:
	var p := _faction_troop_palette(faction_id)
	var armor: Color = p["armor"]
	var cloth: Color = p["cloth"]
	var metal: Color = p["metal"]
	var leather: Color = p["leather"]
	var shield: Color = p["shield"]
	var style: String = p["style"]
	_mesh_box(Vector3(0.72, 0.85, 0.42), Vector3(0, 1.05, 0), armor, parent).name = "Body"
	_mesh_box(Vector3(0.22, 0.72, 0.22), Vector3(-0.23, 0.35, 0), leather, parent)
	_mesh_box(Vector3(0.22, 0.72, 0.22), Vector3(0.23, 0.35, 0), leather, parent)
	_mesh_sphere(0.30, Vector3(0, 1.78, 0), Color(0.72, 0.53, 0.38), parent)
	_mesh_cylinder(0.34, 0.18, Vector3(0, 1.99, 0), metal, parent)
	_mesh_box(Vector3(0.16, 0.65, 0.16), Vector3(-0.48, 0.98, 0), armor, parent, Vector3(0, 0, -18))
	_mesh_box(Vector3(0.16, 0.65, 0.16), Vector3(0.48, 0.98, 0), armor, parent, Vector3(0, 0, 18))
	var sword := _mesh_box(Vector3(0.10, 0.95, 0.07), Vector3(0.68, 0.93, -0.15), metal, parent, Vector3(0, 0, -18))
	sword.name = "Sword"
	_mesh_box(Vector3(0.30, 0.07, 0.12), Vector3(0.68, 0.58, -0.15), leather, parent)
	_mesh_cylinder(0.42, 0.10, Vector3(-0.48, 1.0, 0.30), shield, parent)
	if style == "north":
		_mesh_box(Vector3(0.58, 0.72, 0.10), Vector3(0, 0.98, 0.25), cloth.darkened(0.12), parent)
		_mesh_box(Vector3(0.08, 0.38, 0.08), Vector3(0, 2.15, 0), metal, parent)
	elif style == "royal":
		_mesh_box(Vector3(0.62, 0.10, 0.48), Vector3(0, 1.43, 0), cloth, parent)
		_mesh_box(Vector3(0.16, 0.12, 0.06), Vector3(0, 2.12, -0.20), metal, parent)
	elif style == "steppe":
		_mesh_box(Vector3(0.76, 0.16, 0.50), Vector3(0, 1.45, 0), cloth, parent)
		_mesh_box(Vector3(0.08, 0.50, 0.08), Vector3(0, 2.18, 0), cloth, parent)
	elif style == "sahr":
		_mesh_box(Vector3(0.78, 0.18, 0.12), Vector3(0, 1.48, -0.22), cloth, parent)
		_mesh_box(Vector3(0.12, 0.42, 0.08), Vector3(0, 2.14, 0), metal, parent)
	else:
		_mesh_box(Vector3(0.78, 0.22, 0.44), Vector3(0, 1.44, 0), cloth, parent)
		_mesh_box(Vector3(0.10, 0.34, 0.08), Vector3(0, 2.13, 0), metal, parent)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	hp_label = Label.new()
	hp_label.position = Vector2(28, 24)
	hp_label.add_theme_font_size_override("font_size", 24)
	layer.add_child(hp_label)

	status_label = Label.new()
	status_label.position = Vector2(28, 58)
	status_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(status_label)

	var attack := Button.new()
	attack.text = "ATTACK"
	attack.position = Vector2(1080, 580)
	attack.size = Vector2(150, 80)
	attack.add_theme_font_size_override("font_size", 22)
	attack.pressed.connect(_player_attack)
	layer.add_child(attack)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().size.x * 0.5:
			touch_look_active = true
			look_touch = event.position
		elif not event.pressed:
			touch_look_active = false
	elif event is InputEventScreenDrag and touch_look_active:
		var drag_delta: Vector2 = event.relative
		yaw -= drag_delta.x * 0.15
		pitch = clamp(pitch - drag_delta.y * 0.10, -35.0, 15.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	battle_time += delta
	attack_cooldown = max(0.0, attack_cooldown - delta)
	_update_player(delta)
	_update_troops(delta)
	hp_label.text = "HP: %d / %d" % [player_hp, MAX_HP]
	if status_label.text == "":
		status_label.text = "ONE CONTINENT • Day %d • %d settlements • %d armies"

func _update_player(_delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input_vec.x, 0, input_vec.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	direction = basis * direction
	player.velocity.x = direction.x * PLAYER_SPEED
	player.velocity.z = direction.z * PLAYER_SPEED
	player.velocity.y = -1.0
	player.move_and_slide()
	player.rotation.y = deg_to_rad(yaw)
	camera.position = Vector3(0, 4.2, 7.5)
	camera.rotation_degrees = Vector3(pitch, 180, 0)

func _animate_troop_visual(troop: Node3D, moving: bool, attacking: bool, phase: float) -> void:
	if not is_instance_valid(troop):
		return
	var body := troop.get_node_or_null("Body") as Node3D
	var sword := troop.get_node_or_null("Sword") as Node3D
	if body:
		body.position.y = 1.05 + (sin(phase * 10.0) * 0.035 if moving else 0.0)
	if sword:
		if attacking:
			sword.rotation_degrees.z = -65.0 + sin(phase * 24.0) * 10.0
		else:
			sword.rotation_degrees.z = -18.0

func _update_troops(delta: float) -> void:
	for i in range(troops.size() - 1, -1, -1):
		var data = troops[i]
		var node: CharacterBody3D = data.node
		if not is_instance_valid(node):
			troops.remove_at(i)
			continue
		data.cooldown = max(0.0, float(data.cooldown) - delta)
		var target := _nearest_enemy(node, String(data.team))
		if target:
			var distance := node.global_position.distance_to(target.global_position)
			var moving := false
			var attacking := false
			if distance > ATTACK_RANGE:
				var dir := (target.global_position - node.global_position)
				dir.y = 0
				node.velocity = dir.normalized() * TROOP_SPEED
				node.move_and_slide()
				moving = true
			elif data.cooldown <= 0.0:
				_damage_troop(target)
				data.cooldown = 0.9
				attacking = true
			else:
				attacking = float(data.cooldown) > 0.55
			var look_target := target.global_position
			look_target.y = node.global_position.y
			if node.global_position.distance_to(look_target) > 0.05:
				node.look_at(look_target, Vector3.UP)
			_animate_troop_visual(node, moving, attacking, battle_time + float(i))
		troops[i] = data

func _nearest_enemy(from: Node3D, team: String) -> Node3D:
	var best: Node3D
	var best_distance := INF
	for data in troops:
		if String(data.team) == team:
			continue
		var node: Node3D = data.node
		if not is_instance_valid(node):
			continue
		var distance := from.global_position.distance_to(node.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func _damage_troop(target: Node3D) -> void:
	for i in range(troops.size()):
		if troops[i].node == target:
			troops[i].hp = int(troops[i].hp) - ATTACK_DAMAGE
			if int(troops[i].hp) <= 0:
				target.queue_free()
				troops.remove_at(i)
				return

func _create_banner(parent: Node3D, position: Vector3, team_color: Color) -> void:
	# Battlefield banners use the same authored heraldic language as settlement flags.
	_mesh_cylinder(0.055, 2.8, position + Vector3(0, 1.4, 0), Color(0.18, 0.14, 0.10), parent)
	_mesh_sphere(0.10, position + Vector3(0, 2.84, 0), Color(0.65, 0.52, 0.22), parent)
	_mesh_box(Vector3(1.02, 0.72, 0.05), position + Vector3(0.50, 2.38, 0), team_color, parent)
	_mesh_box(Vector3(0.92, 0.055, 0.055), position + Vector3(0.50, 2.68, -0.035), Color(0.82, 0.70, 0.30), parent)
	_mesh_box(Vector3(0.92, 0.055, 0.055), position + Vector3(0.50, 2.08, -0.035), Color(0.82, 0.70, 0.30), parent)

func _create_war_banner(position: Vector3, faction_id: String) -> void:
	var root := Node3D.new()
	root.name = "WarBanner_" + faction_id
	root.position = position
	add_child(root)
	_create_faction_banner(root, faction_id, 1.0)

func _spawn_extra_banners() -> void:
	_create_war_banner(Vector3(-12, 0, -10), "north_kingdom")
	_create_war_banner(Vector3(12, 0, 10), "eastern_tribes")

func _player_attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.45
	var closest: Node3D
	var best := ATTACK_RANGE + 0.6
	for data in troops:
		if String(data.team) != "ENEMY":
			continue
		var node: Node3D = data.node
		if not is_instance_valid(node):
			continue
		var d := player.global_position.distance_to(node.global_position)
		if d < best:
			best = d
			closest = node
	if closest:
		_damage_troop(closest)
		status_label.text = "Hit!"
	else:
		status_label.text = "No enemy in range."


func _spawn_continent_world() -> void:
	for settlement in world_state.settlements:
		var p: Vector2 = settlement["position"]
		var owner: String = settlement["owner"]
		var marker := Node3D.new()
		marker.name = "Settlement_%s" % settlement["name"]
		marker.position = Vector3(p.x, 0, p.y)
		add_child(marker)
		var color := world_state.get_faction_color(owner)
		var kind: String = settlement["type"]
		var height := 0.9
		if kind == "city":
			height = 1.5
		elif kind == "castle":
			height = 1.3
		if kind == "castle":
			_build_castle_visual(marker, color, owner)
		elif kind == "city":
			_build_city_visual(marker, color, owner)
		else:
			_build_village_visual(marker, color, owner)
		_create_settlement_heraldry(marker, owner, kind)
		var label := Label3D.new()
		label.text = String(settlement["name"])
		label.font_size = 24
		label.outline_size = 6
		label.position = Vector3(0, height + 2.35, 0)
		marker.add_child(label)

func _build_village_visual(root: Node3D, faction_color: Color, owner: String) -> void:
	_mesh_box(Vector3(1.8, 0.8, 1.5), Vector3(0, 0.4, 0), Color(0.38, 0.27, 0.18), root)
	_mesh_box(Vector3(2.0, 0.18, 1.7), Vector3(0, 0.88, 0), Color(0.14, 0.075, 0.045), root, Vector3(0, 0, 3))
	_mesh_cylinder(0.055, 1.8, Vector3(0.75, 1.0, 0.35), Color(0.16,0.12,0.08), root)
	_mesh_box(Vector3(0.55,0.32,0.04), Vector3(1.02,1.72,0.35), faction_color, root)

func _build_city_visual(root: Node3D, faction_color: Color, owner: String) -> void:
	# Compact skyline silhouette: gatehouse, four corner towers and central hall.
	_mesh_box(Vector3(3.4, 1.3, 2.8), Vector3(0, 0.65, 0), Color(0.38,0.37,0.34), root)
	for x in [-1.55, 1.55]:
		for z in [-1.15, 1.15]:
			_mesh_cylinder(0.42, 2.5, Vector3(x, 1.25, z), Color(0.31,0.31,0.29), root)
	_mesh_box(Vector3(0.9, 1.0, 0.12), Vector3(0, 0.55, -1.46), Color(0.12,0.075,0.04), root)
	_mesh_cylinder(0.06, 2.8, Vector3(0, 2.1, 0), Color(0.16,0.12,0.08), root)
	_mesh_box(Vector3(0.72,0.38,0.05), Vector3(0.36,3.25,0), faction_color, root)

func _build_castle_visual(root: Node3D, faction_color: Color, owner: String) -> void:
	# Strong readable castle silhouette without forcing a close-up/detail zoom.
	_mesh_box(Vector3(4.8, 0.65, 4.0), Vector3(0, 0.32, 0), Color(0.27,0.27,0.26), root)
	for x in [-2.15, 2.15]:
		for z in [-1.65, 1.65]:
			_mesh_cylinder(0.52, 3.6, Vector3(x, 1.8, z), Color(0.32,0.32,0.30), root)
	_mesh_box(Vector3(2.4, 2.2, 2.0), Vector3(0, 1.1, 0), Color(0.36,0.35,0.32), root)
	_mesh_box(Vector3(1.0, 1.25, 0.14), Vector3(0, 0.63, -1.08), Color(0.12,0.075,0.04), root)
	_mesh_box(Vector3(5.1, 0.16, 0.18), Vector3(0, 2.65, -1.95), Color(0.20,0.19,0.17), root)
	_mesh_cylinder(0.055, 3.5, Vector3(0, 2.2, 0), Color(0.16,0.12,0.08), root)
	_mesh_box(Vector3(0.9,0.5,0.05), Vector3(0.45,3.8,0), faction_color, root)

func _create_settlement_heraldry(root: Node3D, owner: String, kind: String) -> void:
	# Each realm gets its own original heraldic identity, inspired by medieval-fantasy
	# visual language rather than copying any film/show emblem.
	var banner_root := Node3D.new()
	banner_root.name = "FactionHeraldry"
	banner_root.position = Vector3(0, 0, -1.9)
	root.add_child(banner_root)
	_create_faction_banner(banner_root, owner, 0.72 if kind == "village" else 0.92)

func _create_faction_banner(parent: Node3D, faction_id: String, scale := 1.0) -> void:
	var bg := world_state.get_faction_banner(faction_id)
	var accent := world_state.get_faction_accent(faction_id)
	var emblem := world_state.get_faction_emblem(faction_id)
	var pole_h := 3.2 * scale
	var flag_w := 1.35 * scale
	var flag_h := 0.82 * scale
	_mesh_cylinder(0.045 * scale, pole_h, Vector3(0, pole_h * 0.5, 0), Color(0.16,0.12,0.08), parent)
	_mesh_sphere(0.085 * scale, Vector3(0, pole_h + 0.05 * scale, 0), accent, parent)
	_mesh_box(Vector3(flag_w, flag_h, 0.055 * scale), Vector3(flag_w * 0.5, pole_h - 0.72 * scale, 0), bg, parent)
	_mesh_box(Vector3(flag_w * 0.88, 0.055 * scale, 0.065 * scale), Vector3(flag_w * 0.5, pole_h - 0.35 * scale, -0.035 * scale), accent, parent)
	_mesh_box(Vector3(flag_w * 0.88, 0.055 * scale, 0.065 * scale), Vector3(flag_w * 0.5, pole_h - 1.10 * scale, -0.035 * scale), accent, parent)
	_draw_heraldic_emblem(parent, emblem, Vector3(flag_w * 0.50, pole_h - 0.72 * scale, -0.07 * scale), scale, accent)

func _draw_heraldic_emblem(parent: Node3D, emblem: String, center: Vector3, scale: float, accent: Color) -> void:
	# Bold geometric charges keep the flags readable at normal gameplay distance.
	if emblem == "wolf":
		_mesh_box(Vector3(0.10,0.46,0.07)*scale, center + Vector3(0,0.02,0), accent, parent)
		_mesh_box(Vector3(0.42,0.10,0.07)*scale, center + Vector3(0,0.10,0), accent, parent)
		_mesh_box(Vector3(0.28,0.12,0.07)*scale, center + Vector3(-0.17,-0.12,0), accent, parent, Vector3(0,0,-28))
		_mesh_box(Vector3(0.28,0.12,0.07)*scale, center + Vector3(0.17,-0.12,0), accent, parent, Vector3(0,0,28))
	elif emblem == "stag":
		_mesh_cylinder(0.055*scale, 0.48*scale, center + Vector3(0,-0.01,0), accent, parent)
		_mesh_box(Vector3(0.48,0.07,0.07)*scale, center + Vector3(0,0.12,0), accent, parent)
		_mesh_box(Vector3(0.07,0.28,0.07)*scale, center + Vector3(-0.22,0.28,0), accent, parent, Vector3(0,0,-18))
		_mesh_box(Vector3(0.07,0.28,0.07)*scale, center + Vector3(0.22,0.28,0), accent, parent, Vector3(0,0,18))
		_mesh_box(Vector3(0.12,0.20,0.07)*scale, center + Vector3(-0.28,0.40,0), accent, parent, Vector3(0,0,-25))
		_mesh_box(Vector3(0.12,0.20,0.07)*scale, center + Vector3(0.28,0.40,0), accent, parent, Vector3(0,0,25))
	elif emblem == "falcon":
		_mesh_box(Vector3(0.56,0.09,0.07)*scale, center, accent, parent)
		_mesh_box(Vector3(0.32,0.10,0.07)*scale, center + Vector3(-0.22,0.15,0), accent, parent, Vector3(0,0,28))
		_mesh_box(Vector3(0.32,0.10,0.07)*scale, center + Vector3(0.22,0.15,0), accent, parent, Vector3(0,0,-28))
		_mesh_box(Vector3(0.10,0.24,0.07)*scale, center + Vector3(0,-0.12,0), accent, parent)
	elif emblem == "sun":
		_mesh_cylinder(0.18*scale, 0.06*scale, center, accent, parent)
		for angle in [0,45,90,135]:
			var rad := deg_to_rad(float(angle))
			var p := center + Vector3(cos(rad)*0.30*scale, sin(rad)*0.30*scale, 0)
			_mesh_box(Vector3(0.18,0.055,0.055)*scale, p, accent, parent, Vector3(0,0,float(angle)))
	else:
		_mesh_box(Vector3(0.10,0.50,0.07)*scale, center, accent, parent)
		_mesh_box(Vector3(0.38,0.10,0.07)*scale, center + Vector3(0,0.10,0), accent, parent, Vector3(0,0,18))
		_mesh_box(Vector3(0.38,0.10,0.07)*scale, center + Vector3(0,-0.10,0), accent, parent, Vector3(0,0,-18))

func _process(_delta: float) -> void:
	if world_state and status_label:
		status_label.text = "ONE CONTINENT  •  Day %d  •  %d regions  •  %d settlements  •  %d armies" % [world_state.day, world_state.regions.size(), world_state.settlements.size(), world_state.armies.size()]


func _build_world_map_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WorldMapUI"
	add_child(layer)
	var button := Button.new()
	button.text = "WORLD MAP"
	button.position = Vector2(28, 105)
	button.size = Vector2(190, 58)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_toggle_world_map)
	layer.add_child(button)

	world_map_panel = ColorRect.new()
	world_map_panel.position = Vector2(150, 45)
	world_map_panel.size = Vector2(980, 650)
	world_map_panel.color = Color(0.035, 0.045, 0.06, 0.97)
	world_map_panel.visible = false
	layer.add_child(world_map_panel)

	var title := Label.new()
	title.text = "CONTINENT MAP  •  TAP A SETTLEMENT TO TRAVEL"
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 22)
	world_map_panel.add_child(title)

	map_canvas = ColorRect.new()
	map_canvas.position = Vector2(24, 58)
	map_canvas.size = Vector2(520, 500)
	map_canvas.color = Color(0.10, 0.15, 0.12, 1.0)
	world_map_panel.add_child(map_canvas)

	world_map_label = Label.new()
	world_map_label.position = Vector2(575, 58)
	world_map_label.size = Vector2(375, 500)
	world_map_label.add_theme_font_size_override("font_size", 16)
	world_map_panel.add_child(world_map_label)

	var next_day := Button.new()
	next_day.text = "NEXT DAY"
	next_day.position = Vector2(575, 575)
	next_day.size = Vector2(120, 48)
	next_day.pressed.connect(_advance_world_day)
	world_map_panel.add_child(next_day)

	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(830, 575)
	close.size = Vector2(120, 48)
	close.pressed.connect(_toggle_world_map)
	world_map_panel.add_child(close)

func _toggle_world_map() -> void:
	map_open = not map_open
	world_map_panel.visible = map_open
	if map_open:
		_refresh_world_map()

func _refresh_world_map() -> void:
	for b in travel_buttons:
		if is_instance_valid(b):
			b.queue_free()
	travel_buttons.clear()

	var text := "DAY %d     GOLD %d\n" % [world_state.day, world_state.gold]
	text += "CURRENT REGION: %s\n\n" % world_state.regions[world_state.player_region_id]["name"]
	text += "TERRITORIES\n"
	for faction in world_state.factions:
		text += "◆ %s — %d regions\n" % [faction["name"], faction["territory"].size()]
	text += "\nSETTLEMENTS\n"
	for settlement in world_state.settlements:
		text += "• %s — %s — %s\n" % [
			settlement["name"],
			settlement["type"].capitalize(),
			world_state.get_faction_name(settlement["owner"])
		]
	text += "\nARMIES\n"
	for army in world_state.armies:
		text += "⚔ %s — %d troops — %s\n" % [
			army["name"],
			army["soldiers"],
			world_state.get_faction_name(army["owner"])
		]
	world_map_label.text = text

	# Territory layer: every region gets an authored color block and border.
	for region in world_state.regions:
		var p: Vector2 = region["position"]
		var map_x := 20.0 + ((p.x + 22.0) / 44.0) * 470.0
		var map_y := 30.0 + ((p.y + 18.0) / 36.0) * 430.0
		var territory := ColorRect.new()
		territory.position = Vector2(map_x - 48, map_y - 30)
		territory.size = Vector2(96, 60)
		var faction_color := world_state.get_faction_color(String(region["owner"]))
		territory.color = Color(faction_color.r, faction_color.g, faction_color.b, 0.30)
		territory.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_canvas.add_child(territory)
		var region_label := Label.new()
		region_label.text = String(region["name"])
		region_label.position = Vector2(map_x - 44, map_y - 24)
		region_label.size = Vector2(88, 48)
		region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		region_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		region_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		region_label.add_theme_font_size_override("font_size", 10)
		region_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		map_canvas.add_child(region_label)

	# Real clickable settlement markers stay above the territory layer.
	for i in range(world_state.settlements.size()):
		var settlement: Dictionary = world_state.settlements[i]
		var p: Vector2 = settlement["position"]
		var map_x := 20.0 + ((p.x + 22.0) / 44.0) * 470.0
		var map_y := 30.0 + ((p.y + 18.0) / 36.0) * 430.0
		var travel := Button.new()
		travel.text = "● " + String(settlement["name"])
		travel.position = Vector2(map_x - 50, map_y + 22)
		travel.size = Vector2(145, 34)
		travel.add_theme_font_size_override("font_size", 11)
		travel.tooltip_text = "Travel to %s" % String(settlement["name"])
		travel.pressed.connect(_travel_to_settlement.bind(i))
		map_canvas.add_child(travel)
		travel_buttons.append(travel)

func _open_recruitment(settlement_id: int) -> void:
	var settlement: Dictionary = world_state.settlements[settlement_id]
	var troop_types := ["levy", "spearman", "archer", "horseman"]
	var costs := {"levy":5, "spearman":9, "archer":11, "horseman":18}
	var lines := "RECRUITMENT • %s\nGold: %d\n\n" % [settlement["name"], world_state.gold]
	for troop_type in troop_types:
		lines += "%s — %d gold each\n" % [troop_type.capitalize(), costs[troop_type]]
	var recruit := Button.new()
	recruit.text = "Recruit 10 mixed troops"
	recruit.position = Vector2(575, 525)
	recruit.size = Vector2(220, 44)
	recruit.pressed.connect(func():
		var result := world_state.recruit_from_settlement(settlement_id, "levy", 10)
		if result["ok"]:
			status_label.text = "Recruited %d troops • -%d gold" % [result["count"], result["cost"]]
		else:
			status_label.text = "Recruitment unavailable: %s" % result["reason"]
		recruit.queue_free()
		_refresh_world_map()
	)
	world_map_panel.add_child(recruit)

func _travel_to_settlement(settlement_id: int) -> void:
	var result: Dictionary = world_state.travel_to_settlement(settlement_id)
	if not result.get("ok", false):
		return
	var settlement: Dictionary = world_state.settlements[settlement_id]
	var p: Vector2 = settlement["position"]
	player.position = Vector3(p.x, 1.0, p.y + 4.0)
	player.velocity = Vector3.ZERO
	status_label.text = "Travelled to %s • %d day(s)" % [result["settlement"], result["days"]]
	_open_recruitment(settlement_id)
	_refresh_world_map()

func _advance_world_day() -> void:
	world_state.advance_day()
	if map_open:
		_refresh_world_map()
