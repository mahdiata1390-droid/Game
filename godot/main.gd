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

func _ready() -> void:
	_build_world()
	_build_player()
	_build_warband()
	_build_ui()

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

func _create_settlement(center: Vector3) -> void:
	for i in range(5):
		var house := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.0, 2.2, 2.8)
		house.mesh = box
		house.position = center + Vector3((i % 3) * 3.6 - 3.6, 1.1, (i / 3) * 3.8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.35, 0.28, 0.20)
		house.material_override = mat
		add_child(house)

func _create_tree_cluster() -> void:
	for i in range(35):
		var tree := MeshInstance3D.new()
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.18
		trunk.bottom_radius = 0.25
		trunk.height = 1.8
		tree.mesh = trunk
		var x := float((i * 17) % 50) - 25.0
		var z := float((i * 29) % 50) - 25.0
		tree.position = Vector3(x, 0.9, z)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.22, 0.12, 0.07)
		tree.material_override = mat
		add_child(tree)

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
		_spawn_troop("ALLY", Vector3(-5 + i * 2.0, 1, 3 + (i % 2) * 1.8), Color(0.15, 0.65, 0.95))
	for i in range(8):
		_spawn_troop("ENEMY", Vector3(-7 + i * 2.0, 1, -10 - (i % 2) * 1.8), Color(0.80, 0.22, 0.22))

func _spawn_troop(team: String, pos: Vector3, color: Color) -> void:
	var troop := CharacterBody3D.new()
	troop.position = pos
	add_child(troop)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.7
	capsule.radius = 0.38
	mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material_override = mat
	troop.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.7
	shape.radius = 0.38
	collision.shape = shape
	troop.add_child(collision)
	troops.append({"node": troop, "team": team, "hp": 60, "cooldown": 0.0})

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
		var delta := event.relative
		yaw -= delta.x * 0.15
		pitch = clamp(pitch - delta.y * 0.10, -35.0, 15.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	_update_player(delta)
	_update_troops(delta)
	hp_label.text = "HP: %d / %d" % [player_hp, MAX_HP]
	if status_label.text == "":
		status_label.text = "WASD / Touch • ATTACK for the prototype"

func _update_player(delta: float) -> void:
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
			if distance > ATTACK_RANGE:
				var dir := (target.global_position - node.global_position)
				dir.y = 0
				node.velocity = dir.normalized() * TROOP_SPEED
				node.move_and_slide()
			elif data.cooldown <= 0.0:
				_damage_troop(target)
				data.cooldown = 0.9
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

func _player_attack() -> void:
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
