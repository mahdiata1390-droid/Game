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
var touch_forward := false
var touch_back := false
var touch_left := false
var touch_right := false
var touch_look_active := false
var troops: Array[Dictionary] = []
var status_label: Label
var hp_label: Label
var attack_cooldown := 0.0
var battle_time := 0.0
var battle_in_progress := false
var battle_initial_attacker := 0
var battle_initial_defender := 0
var battle_casualties := {"ALLY": 0, "ENEMY": 0}
var battle_casualty_types := {"ALLY": {}, "ENEMY": {}}
var battle_attacker_force: Dictionary = {}
var battle_defender_force: Dictionary = {}
var world_state: Node
var world_map_panel: Control
var world_map_label: Label
var map_open := false
var travel_buttons: Array[Node] = []
var map_canvas: Control
var army_command_panel: Panel
var camera_first_person := false
var settlement_interior: Node3D
var interior_active := false
var current_settlement_id := -1
var interior_npcs: Array[Node3D] = []
var inventory_panel: Panel
var inventory_label: Label
var inventory_open := false
var status_hold := 0.0
var pause_panel: Panel
var game_paused := false

func _ready() -> void:
	# Start the player/camera first. The scene already contains a guaranteed
	# fallback world, so a later gameplay/content error cannot leave Android
	# without a controllable camera.
	call_deferred("_boot_gameplay")

func _set_boot_status(message: String) -> void:
	var hint := get_node_or_null("BootStatus/Hint") as Label
	if is_instance_valid(hint):
		hint.text = message

func _boot_gameplay() -> void:
	_set_boot_status("Starting player and camera…")
	_build_player()
	_set_boot_status("Building terrain and settlements…")
	_build_world()
	_set_boot_status("Loading campaign world…")
	world_state = WorldState.new()
	world_state.name = "WorldState"
	add_child(world_state)
	world_state.initialize_continent()
	_set_boot_status("Spawning troops and gameplay UI…")
	_build_warband()
	_build_ui()
	_build_interaction_ui()
	_spawn_extra_banners()
	_spawn_continent_world()
	_build_visual_content_upgrade()
	_build_campaign_visuals()
	_build_siege_layer()
	_build_battle_command_layer()
	_build_world_map_ui()
	_set_boot_status("WORLD READY • sandbox systems online")
	var boot := get_node_or_null("BootStatus") as CanvasLayer
	if is_instance_valid(boot):
		await get_tree().create_timer(1.5).timeout
		boot.queue_free()

func _build_visual_content_upgrade() -> void:
	var upgrade := ContentUpgrade.new()
	upgrade.name = "VisualContentUpgrade"
	add_child(upgrade)
	upgrade.build(self)

func _build_campaign_visuals() -> void:
	var campaign := ReleaseCampaignVisual.new()
	campaign.name = "ReleaseCampaignVisual"
	add_child(campaign)
	campaign.build(self)


func _build_siege_layer() -> void:
	var siege_layer := ReleaseSiegeLayer.new()
	siege_layer.name = "ReleaseSiegeLayer"
	add_child(siege_layer)
	siege_layer.build(self)


func _build_battle_command_layer() -> void:
	var battle_layer := ReleaseBattleCommandLayer.new()
	battle_layer.name = "ReleaseBattleCommandLayer"
	add_child(battle_layer)
	battle_layer.build(self)

func _toggle_camera_mode() -> void:
	camera_first_person = not camera_first_person
	if is_instance_valid(status_label):
		status_label.text = "Camera: %s" % ("FIRST PERSON" if camera_first_person else "THIRD PERSON")

func _spawn_extra_banners_once() -> void:
	_spawn_extra_banners()

func _build_world() -> void:
	# Keep the core render path intentionally small and deterministic.
	# Detailed content is added only after a valid player camera exists.
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
	# Camera sits behind the player and therefore looks toward -Z.
	camera.rotation_degrees = Vector3(-12, 0, 0)
	player.add_child(camera)
	camera.current = true

func _build_warband() -> void:
	# Small free-roam skirmish until a real settlement battle is selected.
	for i in range(6):
		_spawn_troop("ALLY", "north_kingdom", Vector3(-5 + i * 2.0, 1, 3 + (i % 2) * 1.8), "levy", 1)
	for i in range(8):
		_spawn_troop("ENEMY", "river_kingdom", Vector3(-7 + i * 2.0, 1, -10 - (i % 2) * 1.8), "levy", 1)

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

func _spawn_troop(team: String, faction_id: String, pos: Vector3, troop_type: String = "levy", represented_count: int = 1) -> void:
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
	var stats := _troop_combat_stats(troop_type)
	troops.append({"node": troop, "team": team, "faction": faction_id, "troop_type": troop_type, "represented_count": max(1, represented_count), "hp": int(stats["hp"]), "max_hp": int(stats["hp"]), "attack_damage": int(stats["damage"]), "cooldown": 0.0})

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
	attack.text = "⚔ ATTACK"
	attack.position = Vector2(1035, 545)
	attack.size = Vector2(205, 105)
	attack.add_theme_font_size_override("font_size", 22)
	attack.pressed.connect(_player_attack)
	layer.add_child(attack)

	# Mobile controls: large, thumb-friendly buttons for movement and pause.
	var pad := Control.new()
	pad.name = "TouchMovementPad"
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(pad)
	var up := _make_touch_button(pad, "▲", Vector2(105, 505), "forward")
	var down := _make_touch_button(pad, "▼", Vector2(105, 615), "back")
	var left := _make_touch_button(pad, "◀", Vector2(25, 560), "left")
	var right := _make_touch_button(pad, "▶", Vector2(185, 560), "right")
	for b in [up, down, left, right]:
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	var pause := Button.new()
	pause.text = "Ⅱ"
	pause.position = Vector2(1170, 24)
	pause.size = Vector2(70, 52)
	pause.add_theme_font_size_override("font_size", 22)
	pause.pressed.connect(_toggle_pause)
	layer.add_child(pause)

func _make_touch_button(parent: Control, label: String, pos: Vector2, direction: String) -> Button:
	var b := Button.new()
	b.text = label
	b.position = pos
	b.size = Vector2(70, 70)
	b.add_theme_font_size_override("font_size", 24)
	b.button_down.connect(func():
		match direction:
			"forward": touch_forward = true
			"back": touch_back = true
			"left": touch_left = true
			"right": touch_right = true
	)
	b.button_up.connect(func():
		match direction:
			"forward": touch_forward = false
			"back": touch_back = false
			"left": touch_left = false
			"right": touch_right = false
	)
	parent.add_child(b)
	return b

func _toggle_pause() -> void:
	game_paused = not game_paused
	if world_state:
		world_state.simulation_paused = game_paused
	if game_paused:
		if is_instance_valid(pause_panel):
			pause_panel.queue_free()
		pause_panel = Panel.new()
		pause_panel.position = Vector2(360, 145)
		pause_panel.size = Vector2(560, 380)
		add_child(pause_panel)
		var title := Label.new()
		title.text = "GAME PAUSED"
		title.position = Vector2(28, 24)
		title.add_theme_font_size_override("font_size", 28)
		pause_panel.add_child(title)
		var info := Label.new()
		info.text = "Day %d • Gold %d\nProgress is safe while paused." % [world_state.day, world_state.gold]
		info.position = Vector2(28, 72)
		info.add_theme_font_size_override("font_size", 18)
		pause_panel.add_child(info)
		var resume := Button.new()
		resume.text = "RESUME"
		resume.position = Vector2(28, 150)
		resume.size = Vector2(220, 52)
		resume.pressed.connect(_toggle_pause)
		pause_panel.add_child(resume)
		var save := Button.new()
		save.text = "SAVE GAME"
		save.position = Vector2(28, 220)
		save.size = Vector2(220, 52)
		save.pressed.connect(_pause_save)
		pause_panel.add_child(save)
	else:
		if is_instance_valid(pause_panel):
			pause_panel.queue_free()
		pause_panel = null

func _pause_save() -> void:
	if world_state.save_game():
		_show_status("GAME SAVED", 2.5)
	else:
		_show_status("SAVE FAILED", 2.5)

func _build_interaction_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameplayInteractionUI"
	add_child(layer)
	var enter := Button.new()
	enter.text = "ENTER SETTLEMENT"
	enter.position = Vector2(28, 105)
	enter.size = Vector2(220, 54)
	enter.pressed.connect(_enter_nearest_settlement)
	layer.add_child(enter)
	var leave := Button.new()
	leave.text = "LEAVE SETTLEMENT"
	leave.position = Vector2(28, 225)
	leave.size = Vector2(220, 54)
	leave.pressed.connect(_leave_settlement)
	layer.add_child(leave)
	var inv := Button.new()
	inv.text = "INVENTORY"
	inv.position = Vector2(28, 285)
	inv.size = Vector2(180, 54)
	inv.pressed.connect(_toggle_inventory)
	layer.add_child(inv)
	inventory_panel = Panel.new()
	inventory_panel.position = Vector2(300, 120)
	inventory_panel.size = Vector2(520, 430)
	inventory_panel.visible = false
	layer.add_child(inventory_panel)
	inventory_label = Label.new()
	inventory_label.position = Vector2(25, 25)
	inventory_label.size = Vector2(470, 330)
	inventory_label.add_theme_font_size_override("font_size", 22)
	inventory_panel.add_child(inventory_label)
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(180, 360)
	close.size = Vector2(160, 48)
	close.pressed.connect(_toggle_inventory)
	inventory_panel.add_child(close)

func _nearest_settlement_id() -> int:
	if not world_state or not is_instance_valid(player):
		return -1
	var best := -1
	var best_dist := 16.0
	for s in world_state.settlements:
		var region := int(s.get("region", -1))
		if region != world_state.player_region_id:
			continue
		var p := Vector3(float(s["position"].x), 0, float(s["position"].y if s["position"] is Vector2 else s["position"].z))
		var d := player.global_position.distance_to(p)
		if d < best_dist:
			best_dist = d
			best = int(s["id"])
	return best

func _enter_nearest_settlement() -> void:
	var id := _nearest_settlement_id()
	if id < 0:
		status_label.text = "No settlement nearby. Travel there from WORLD MAP."
		return
	_enter_settlement(id)

func _enter_settlement(settlement_id: int) -> void:
	if interior_active:
		return
	if settlement_id < 0 or settlement_id >= world_state.settlements.size():
		return
	current_settlement_id = settlement_id
	interior_active = true
	var s:Dictionary = world_state.settlements[settlement_id]
	if is_instance_valid(player):
		player.visible = false
	settlement_interior = Node3D.new()
	settlement_interior.name = "SettlementInterior_%s" % String(s["name"])
	add_child(settlement_interior)
	_create_interior_environment(settlement_interior, String(s["type"]))
	_spawn_interior_npcs(settlement_interior, settlement_id)
	status_label.text = "%s • INTERIOR • Talk to the people, visit the market, or leave." % String(s["name"])

func _create_interior_environment(root: Node3D, kind: String) -> void:
	var floor_color := Color(0.25,0.19,0.13)
	var wall_color := Color(0.40,0.34,0.27)
	_mesh_box(Vector3(24,0.25,18),Vector3(0,-0.12,0),floor_color,root)
	_mesh_box(Vector3(24,4,0.35),Vector3(0,2,-9),wall_color,root)
	_mesh_box(Vector3(24,4,0.35),Vector3(0,2,9),wall_color,root)
	_mesh_box(Vector3(0.35,4,18),Vector3(-12,2,0),wall_color,root)
	_mesh_box(Vector3(0.35,4,18),Vector3(12,2,0),wall_color,root)
	for i in range(5):
		var stall := Node3D.new()
		stall.position=Vector3(-9+i*4.5,0,-5.5)
		root.add_child(stall)
		_mesh_box(Vector3(3.4,1.2,1.5),Vector3(0,0.6,0),Color(0.31,0.20,0.11),stall)
		_mesh_box(Vector3(3.8,0.18,1.9),Vector3(0,1.35,0),Color(0.12,0.08,0.05),stall)
	_mesh_box(Vector3(5,2.2,1),Vector3(0,1.1,6.5),Color(0.20,0.13,0.08),root)
	var title:=Label3D.new()
	title.text="%s • %s" % [String(world_state.settlements[current_settlement_id]["name"]),kind.to_upper()]
	title.position=Vector3(0,3.5,7.5)
	title.font_size=48
	root.add_child(title)

func _spawn_interior_npcs(root: Node3D, settlement_id: int) -> void:
	interior_npcs.clear()
	for i in range(8):
		var npc:=Node3D.new()
		npc.name="Civilian_%d"%i
		npc.position=Vector3(-8+(i%4)*5.0,0.0,-1.5+(i/4)*5.0)
		root.add_child(npc)
		_mesh_box(Vector3(0.55,0.9,0.38),Vector3(0,0.95,0),Color(0.28+float(i%3)*0.05,0.18+float(i%2)*0.05,0.12),npc)
		_mesh_sphere(0.25,Vector3(0,1.65,0),Color(0.68,0.48,0.32),npc)
		var role:=Label3D.new()
		role.text=["Merchant","Farmer","Smith","Guard"][i%4]
		role.position=Vector3(0,2.1,0)
		role.font_size=28
		npc.add_child(role)
		interior_npcs.append(npc)

func _leave_settlement() -> void:
	if not interior_active:
		return
	if is_instance_valid(settlement_interior):
		settlement_interior.queue_free()
	settlement_interior=null
	interior_npcs.clear()
	interior_active=false
	if is_instance_valid(player):
		player.visible=true
	status_label.text="Outside settlement."

func _toggle_inventory() -> void:
	inventory_open=not inventory_open
	inventory_panel.visible=inventory_open
	if inventory_open:
		var eq:=world_state.player_equipment
		var inv:=world_state.player_inventory
		inventory_label.text="INVENTORY • LOOT & EQUIPMENT\n\nFood: %d\nWood: %d\nIron: %d\n\nEQUIPMENT\nWeapon: %s\nArmor: %s\nShield: %s\nHorse: %s\n\nGold: %d" % [int(inv.get("food",0)),int(inv.get("wood",0)),int(inv.get("iron",0)),String(eq.get("weapon","none")),String(eq.get("armor","none")),String(eq.get("shield","none")),String(eq.get("horse","none")),world_state.gold]

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
	if game_paused:
		return
	if interior_active and Input.is_action_just_pressed("ui_cancel"):
		_leave_settlement()
	battle_time += delta
	attack_cooldown = max(0.0, attack_cooldown - delta)
	_update_player(delta)
	_update_troops(delta)
	hp_label.text = "HP: %d / %d" % [player_hp, MAX_HP]
	if status_label.text == "":
		status_label.text = "ONE CONTINENT • Day %d • %d settlements • %d armies" % [world_state.day, world_state.settlements.size(), world_state.armies.size()]

func _update_player(_delta: float) -> void:
	var input_vec := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if touch_forward: input_vec.y -= 1.0
	if touch_back: input_vec.y += 1.0
	if touch_left: input_vec.x -= 1.0
	if touch_right: input_vec.x += 1.0
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()
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
	if camera_first_person:
		camera.position = Vector3(0, 1.55, 0.10)
		camera.rotation_degrees = Vector3(pitch, 0, 0)
	else:
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

func _troop_combat_stats(troop_type: String) -> Dictionary:
	match troop_type:
		"spearman": return {"hp": 78, "damage": 15}
		"archer": return {"hp": 52, "damage": 13}
		"horseman": return {"hp": 92, "damage": 20}
		_: return {"hp": 60, "damage": 12}

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
				_damage_troop(target, int(data.get("attack_damage", ATTACK_DAMAGE)))
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

func _damage_troop(target: Node3D, damage: int = ATTACK_DAMAGE) -> void:
	for i in range(troops.size()):
		if troops[i].node == target:
			troops[i].hp = int(troops[i].hp) - max(1, damage)
			if int(troops[i].hp) <= 0:
				var dead_team := String(troops[i].team)
				var dead_type := String(troops[i].get("troop_type", "levy"))
				var dead_count := int(troops[i].get("represented_count", 1))
				battle_casualties[dead_team] = int(battle_casualties.get(dead_team, 0)) + dead_count
				if dead_team == "ENEMY" and world_state:
					world_state.player_inventory["iron"] = int(world_state.player_inventory.get("iron",0)) + randi_range(0,2)
					world_state.player_inventory["wood"] = int(world_state.player_inventory.get("wood",0)) + (1 if randi_range(1,100) <= 35 else 0)
				var type_map: Dictionary = battle_casualty_types.get(dead_team, {})
				type_map[dead_type] = int(type_map.get(dead_type, 0)) + dead_count
				battle_casualty_types[dead_team] = type_map
				target.queue_free()
				troops.remove_at(i)
				return

var siege_visual_root: Node3D
var siege_wall_segments: Array[Node3D] = []
var siege_gate: Node3D
var siege_gate_hp := 120
var siege_wall_hp := 500

func create_siege_visual(settlement_name: String, wall_level: int) -> void:
	clear_siege_visual()
	siege_visual_root=Node3D.new()
	siege_visual_root.name="ActiveSiege_%s"%settlement_name
	add_child(siege_visual_root)
	var wall_color:=Color(0.30,0.30,0.31)
	var timber:=Color(0.18,0.12,0.08)
	var stone:=Color(0.42,0.42,0.40)
	var wall_len:=18.0+float(wall_level)*2.0
	for side in [-1.0,1.0]:
		for i in range(5):
			var seg:=Node3D.new()
			seg.position=Vector3(-wall_len/2.0+i*(wall_len/4.0),0,side*8.0)
			siege_visual_root.add_child(seg)
			_mesh_box(Vector3(wall_len/4.4,3.2,1.1),Vector3(0,1.6,0),wall_color,seg)
			_mesh_box(Vector3(wall_len/4.8,0.18,1.35),Vector3(0,3.25,0),stone,seg)
			siege_wall_segments.append(seg)
	for side in [-1.0,1.0]:
		var tower:=Node3D.new()
		tower.position=Vector3(side*wall_len/2.0,0,8.0)
		siege_visual_root.add_child(tower)
		_mesh_box(Vector3(2.6,5.0,2.6),Vector3(0,2.5,0),wall_color,tower)
		_mesh_box(Vector3(3.0,0.35,3.0),Vector3(0,5.1,0),timber,tower)
		_create_war_banner(tower.position+Vector3(0,5.1,0),world_state.player_faction if world_state else "Free Company")
	siege_gate=Node3D.new()
	siege_gate.position=Vector3(0,0,8.0)
	siege_visual_root.add_child(siege_gate)
	_mesh_box(Vector3(4.0,3.0,0.9),Vector3(0,1.5,0),timber,siege_gate)
	_mesh_box(Vector3(0.18,3.3,1.0),Vector3(-2.05,1.65,0),stone,siege_gate)
	_mesh_box(Vector3(0.18,3.3,1.0),Vector3(2.05,1.65,0),stone,siege_gate)
	siege_gate_hp=120
	siege_wall_hp=max(100,wall_level*100)

func update_siege_visual(progress:int, gate_breached:bool, gate_hp:int=120, wall_hp:int=500) -> void:
	if not is_instance_valid(siege_visual_root): return
	siege_gate_hp=gate_hp
	siege_wall_hp=wall_hp
	if is_instance_valid(siege_gate):
		if gate_breached or gate_hp<=0:
			siege_gate.rotation_degrees.y=-55
			siege_gate.position.x=3.0
		else:
			siege_gate.rotation_degrees.y=clamp(float(120-gate_hp)*0.35,0.0,30.0)
	for i in range(siege_wall_segments.size()):
		var seg:=siege_wall_segments[i]
		if not is_instance_valid(seg): continue
		var damage_ratio:=clamp(float(siege_wall_hp)/500.0,0.15,1.0)
		seg.scale.y=damage_ratio
		if progress>=60 and i%2==0:
			seg.rotation_degrees.z=3.0 if i%4==0 else -3.0

func clear_siege_visual() -> void:
	if is_instance_valid(siege_visual_root): siege_visual_root.queue_free()
	siege_visual_root=null
	siege_wall_segments.clear()
	siege_gate=null

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

func _clear_battlefield() -> void:
	for data in troops:
		var node: Node3D = data.get("node")
		if is_instance_valid(node):
			node.queue_free()
	troops.clear()

func _spawn_force(force: Dictionary, team: String, faction_id: String, center: Vector3) -> void:
	var composition: Dictionary = force.get("troops", {})
	var total := max(1, int(force.get("soldiers", 1)))
	var visual_cap := 24
	var remaining_visual := visual_cap
	var types := ["horseman", "spearman", "archer", "levy"]
	var spawned := 0
	for troop_type in types:
		var actual := int(composition.get(troop_type, 0))
		if actual <= 0 or remaining_visual <= 0:
			continue
		var visual_count := min(remaining_visual, max(1, int(ceil(float(actual) * float(visual_cap) / float(total)))))
		var represented := max(1, int(ceil(float(actual) / float(visual_count))))
		for i in range(visual_count):
			var row := i / 6
			var col := i % 6
			var side := -1.0 if team == "ALLY" else 1.0
			var pos := center + Vector3((col - 2.5) * 1.7, 0, side * (row * 1.9))
			_spawn_troop(team, faction_id, pos, troop_type, min(represented, actual))
			actual -= min(represented, actual)
			spawned += 1
			remaining_visual -= 1
			if actual <= 0 or remaining_visual <= 0:
				break
	if spawned == 0:
			_spawn_troop(team, faction_id, center, "levy", total)

func prepare_battle(attacker: Dictionary, defender: Dictionary) -> void:
	_clear_battlefield()
	battle_in_progress = true
	battle_attacker_force = attacker.duplicate(true)
	battle_defender_force = defender.duplicate(true)
	battle_initial_attacker = max(0, int(attacker.get("soldiers", 0)))
	battle_initial_defender = max(0, int(defender.get("soldiers", 0)))
	battle_casualties = {"ALLY": 0, "ENEMY": 0}
	battle_casualty_types = {"ALLY": {}, "ENEMY": {}}
	var attacker_faction := String(attacker.get("owner", world_state.player_faction if world_state else "Free Company"))
	var defender_faction := String(defender.get("owner", "river_kingdom"))
	_spawn_force(attacker, "ALLY", attacker_faction, player.global_position + Vector3(0, 0, -2))
	_spawn_force(defender, "ENEMY", defender_faction, player.global_position + Vector3(0, 0, -13))

func get_battle_casualties() -> Dictionary:
	return {"attacker": int(battle_casualties.get("ALLY", 0)), "defender": int(battle_casualties.get("ENEMY", 0)), "attacker_types": battle_casualty_types.get("ALLY", {}).duplicate(), "defender_types": battle_casualty_types.get("ENEMY", {}).duplicate()}

func get_battle_remaining() -> Dictionary:
	var ally := 0
	var enemy := 0
	for data in troops:
		if String(data.get("team", "")) == "ALLY": ally += int(data.get("represented_count", 1))
		elif String(data.get("team", "")) == "ENEMY": enemy += int(data.get("represented_count", 1))
	return {"attacker": ally, "defender": enemy}

func _spawn_extra_banners() -> void:
	_create_war_banner(Vector3(-12, 0, -10), "north_kingdom")
	_create_war_banner(Vector3(12, 0, 10), "eastern_tribes")

func _player_attack() -> void:
	if interior_active:
		return
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
		var player_damage := ATTACK_DAMAGE
		if world_state and world_state.has_method("get_player_combat_bonus"):
			player_damage = max(ATTACK_DAMAGE, int(round(float(ATTACK_DAMAGE) * float(world_state.get_player_combat_bonus()))))
		_damage_troop(closest, player_damage)
		_show_status("⚔ HIT", 0.8)
	else:
		_show_status("No enemy in range.", 0.8)


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

func _show_status(message: String, duration: float = 2.0) -> void:
	if status_label:
		status_label.text = message
		status_hold = duration

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if interior_active:
			_leave_settlement()
		else:
			_toggle_pause()
	if world_state and status_label:
		status_hold = max(0.0, status_hold - delta)
		if status_hold <= 0.0:
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
	world_map_panel.size = Vector2(980, 720)
	world_map_panel.color = Color(0.035, 0.045, 0.06, 0.97)
	world_map_panel.visible = false
	layer.add_child(world_map_panel)

	var title := Label.new()
	title.text = "CONTINENT MAP  •  TAP A SETTLEMENT TO TRAVEL"
	title.position = Vector2(24, 16)
	title.add_theme_font_size_override("font_size", 22)
	world_map_panel.add_child(title)

	map_canvas = Control.new()
	map_canvas.name = "StrategicMap"
	map_canvas.position = Vector2(24, 58)
	map_canvas.size = Vector2(520, 560)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.set_script(load("res://world_map_visual.gd"))
	world_map_panel.add_child(map_canvas)
	map_canvas.call("set_world", world_state)

	world_map_label = Label.new()
	world_map_label.position = Vector2(575, 58)
	world_map_label.size = Vector2(375, 560)
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

	var market:=Button.new(); market.text="MARKET"; market.position=Vector2(575,625); market.size=Vector2(100,36); market.pressed.connect(_open_current_market); world_map_panel.add_child(market)
	var diplomacy:=Button.new(); diplomacy.text="DIPLOMACY"; diplomacy.position=Vector2(685,625); diplomacy.size=Vector2(120,36); diplomacy.pressed.connect(_open_diplomacy); world_map_panel.add_child(diplomacy)
	var caravan:=Button.new(); caravan.text="CARAVAN"; caravan.position=Vector2(815,625); caravan.size=Vector2(110,36); caravan.pressed.connect(_create_quick_caravan); world_map_panel.add_child(caravan)
	var save:=Button.new(); save.text="SAVE"; save.position=Vector2(575,665); save.size=Vector2(100,30); save.pressed.connect(_save_game); world_map_panel.add_child(save)
	var load:=Button.new(); load.text="LOAD"; load.position=Vector2(685,665); load.size=Vector2(100,30); load.pressed.connect(_load_game); world_map_panel.add_child(load)
	var manage:=Button.new(); manage.text="MANAGE"; manage.position=Vector2(795,665); manage.size=Vector2(110,30); manage.pressed.connect(_open_management); world_map_panel.add_child(manage)

func _open_current_market()->void:
	for i in range(world_state.settlements.size()):
		if int(world_state.settlements[i]["region"])==world_state.player_region_id:
			_open_trade(i); return
	status_label.text="No settlement market in this region."

func _open_diplomacy()->void:
	var panel:=Panel.new(); panel.position=Vector2(230,105); panel.size=Vector2(600,430); add_child(panel)
	var title:=Label.new(); title.text="DIPLOMACY • FREE COMPANY"; title.position=Vector2(20,16); title.add_theme_font_size_override("font_size",22); panel.add_child(title)
	var states=["peace","war","trade","alliance"]; var y:=58
	for f in world_state.factions:
		if String(f["id"])==String(world_state.player_faction) or String(f["id"])=="Free Company": continue
		var label:=Label.new(); label.text=String(f["name"]); label.position=Vector2(20,y+6); label.size=Vector2(230,30); panel.add_child(label)
		for j in range(states.size()):
			var b:=Button.new(); b.text=states[j].to_upper(); b.position=Vector2(250+j*78,y); b.size=Vector2(72,30); b.pressed.connect(_set_diplomacy.bind(String(f["id"]),states[j],panel)); panel.add_child(b)
		y+=52
	var close2:=Button.new(); close2.text="CLOSE"; close2.position=Vector2(250,360); close2.size=Vector2(100,34); close2.pressed.connect(panel.queue_free); panel.add_child(close2)

func _set_diplomacy(faction:String,state:String,panel:Panel)->void:
	var result:=world_state.set_diplomacy(world_state.player_faction,faction,state)
	_show_status("Diplomacy: %s" % state.to_upper(), 2.5)
	if result.get("ok",false): panel.queue_free()

func _create_quick_caravan()->void:
	var origin:=-1; var destination:=-1
	for i in range(world_state.settlements.size()):
		if int(world_state.settlements[i]["region"])==world_state.player_region_id: origin=i; break
	if origin<0: status_label.text="No settlement for caravan."; return
	for i in range(world_state.settlements.size()):
		if i!=origin: destination=i; break
	if destination<0: return
	var result:=world_state.create_caravan(origin,destination)
	_show_status("Caravan launched." if result.get("ok",false) else "Caravan failed: %s" % result.get("reason","unknown"), 2.5)

func _save_game()->void:
	_show_status("GAME SAVED" if world_state.save_game() else "SAVE FAILED", 2.5)

func _load_game()->void:
	_show_status("GAME LOADED" if world_state.load_game() else "NO SAVE FOUND", 2.5)
	if map_open: _refresh_world_map()

func _open_management()->void:
	var panel:=Panel.new(); panel.position=Vector2(205,90); panel.size=Vector2(670,560); add_child(panel)
	var title:=Label.new(); title.text="FREE COMPANY • MANAGEMENT"; title.position=Vector2(22,16); title.add_theme_font_size_override("font_size",23); panel.add_child(title)
	var info:=Label.new(); var summary:=world_state.get_world_status(); info.text="Level %d  •  Gold %d  •  Day %d  •  Weather %s\nEquipment: %s / %s / %s / %s" % [summary["level"],summary["gold"],summary["day"],summary["weather"],world_state.player_equipment["weapon"],world_state.player_equipment["armor"],world_state.player_equipment["horse"],world_state.player_equipment["shield"]]; info.position=Vector2(22,55); info.size=Vector2(620,60); panel.add_child(info)
	var settlement_id:=-1
	for i in range(world_state.settlements.size()):
		if int(world_state.settlements[i]["region"])==world_state.player_region_id and String(world_state.settlements[i]["owner"])==world_state.player_faction: settlement_id=i; break
	if settlement_id>=0:
		var s:=world_state.settlements[settlement_id]
		var city:=Label.new(); city.text="Settlement: %s • Garrison %d • Wall %d\nBuildings: Farm %d • Workshop %d • Market %d • Barracks %d" % [s["name"],s["garrison"],s["wall_level"],s["buildings"]["farm"],s["buildings"]["workshop"],s["buildings"]["market"],s["buildings"]["barracks"]]; city.position=Vector2(22,125); city.size=Vector2(620,55); panel.add_child(city)
		var builds=["farm","workshop","market","barracks"]
		for i in range(builds.size()):
			var bb:=Button.new(); bb.text="UPGRADE "+builds[i].to_upper(); bb.position=Vector2(22+i*155,190); bb.size=Vector2(145,36); bb.pressed.connect(_upgrade_building.bind(settlement_id,builds[i],panel)); panel.add_child(bb)
	var eq_title:=Label.new(); eq_title.text="EQUIPMENT"; eq_title.position=Vector2(22,245); eq_title.add_theme_font_size_override("font_size",18); panel.add_child(eq_title)
	var equipment=[["weapon","steel_sword",120],["armor","plate_armor",250],["horse","war_horse",300],["shield","steel_shield",100]]
	for i in range(equipment.size()):
		var e:=equipment[i]; var eb:=Button.new(); eb.text="%s • %d G"%(String(e[1]).replace("_"," ").capitalize(),int(e[2])); eb.position=Vector2(22+(i%2)*250,280+(i/2)*42); eb.size=Vector2(230,34); eb.pressed.connect(_upgrade_equipment.bind(String(e[0]),String(e[1]),int(e[2]),panel)); panel.add_child(eb)
	var family_label:=Label.new(); family_label.text="FAMILY • Generation %d • Heir: %s" % [world_state.family["generation"],world_state.family["heir_name"]]; family_label.position=Vector2(22,375); panel.add_child(family_label)
	var guardian:=Button.new(); guardian.text="HIRE HOUSEHOLD GUARDIAN • 75 G"; guardian.position=Vector2(22,410); guardian.size=Vector2(270,36); guardian.pressed.connect(_hire_guardian); panel.add_child(guardian)
	var close:=Button.new(); close.text="CLOSE"; close.position=Vector2(270,500); close.size=Vector2(120,36); close.pressed.connect(panel.queue_free); panel.add_child(close)

func _upgrade_building(settlement_id:int,building:String,panel:Panel)->void:
	var r:=world_state.upgrade_settlement_building(settlement_id,building); status_label.text="Building upgraded." if r.get("ok",false) else "Upgrade failed: "+String(r.get("reason","unknown")); panel.queue_free(); _refresh_world_map()

func _upgrade_equipment(slot:String,item:String,cost:int,panel:Panel)->void:
	var r:=world_state.upgrade_player_equipment(slot,item,cost); status_label.text="Equipped "+item if r.get("ok",false) else "Equipment failed: "+String(r.get("reason","unknown")); panel.queue_free()

func _hire_guardian()->void:
	var r:=world_state.recruit_guardian(); status_label.text="Household guardian hired." if r.get("ok",false) else "Cannot hire guardian."

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

	# Rebuild the map layer cleanly so repeated refreshes never stack duplicate
	# territories, labels, or settlement markers.
	for child in map_canvas.get_children():
		child.queue_free()

	# Player army command controls: select an army, then choose an adjacent region.
	for i in range(world_state.armies.size()):
		var army: Dictionary = world_state.armies[i]
		if String(army["owner"]) != String(world_state.player_faction) and String(army["owner"]) != "Free Company":
			continue
		var command := Button.new()
		command.text = "ARMY %d • %s" % [i + 1, String(army["name"])]
		command.position = Vector2(575, 500 + (i % 2) * 36)
		command.size = Vector2(360, 32)
		command.add_theme_font_size_override("font_size", 12)
		command.pressed.connect(_open_army_command.bind(i))
		world_map_panel.add_child(command)
		travel_buttons.append(command)

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

func _open_start_mode() -> void:
	var panel:=Panel.new()
	panel.position=Vector2(220,150); panel.size=Vector2(560,300)
	add_child(panel)
	var title:=Label.new(); title.text="CHOOSE YOUR LIFE"; title.position=Vector2(24,20); title.add_theme_font_size_override("font_size",24); panel.add_child(title)
	var modes=[["ORDINARY","Start with little gold and build your power."],["KING","Start as a ruler with 1000 gold."],["TRIBAL LEADER","Start as a tribal leader with 500 gold."]]
	for i in range(modes.size()):
		var b:=Button.new(); b.text=modes[i][0]+"  •  "+modes[i][1]; b.position=Vector2(24,70+i*58); b.size=Vector2(510,46)
		b.pressed.connect(_choose_start_mode.bind(modes[i][0].to_lower().replace(" ","_"),panel)); panel.add_child(b)

func _choose_start_mode(mode:String,panel:Panel)->void:
	var result:=world_state.set_player_mode("tribal_leader" if mode=="tribal_leader" else ("king" if mode=="king" else "ordinary"))
	status_label.text="You begin as %s • Gold %d" % [result["mode"],world_state.gold]
	panel.queue_free()

func _open_trade(settlement_id:int)->void:
	var panel:=Panel.new(); panel.position=Vector2(180,110); panel.size=Vector2(640,420); add_child(panel)
	var title:=Label.new(); title.text="MARKET • "+String(world_state.settlements[settlement_id]["name"]); title.position=Vector2(24,18); title.add_theme_font_size_override("font_size",24); panel.add_child(title)
	var prices:=world_state.get_market_prices(settlement_id)
	var resources=["food","wood","iron"]
	for i in range(resources.size()):
		var res:=resources[i]; var row:=Label.new(); row.text="%s  •  Price %d  •  Owned %d" % [res.capitalize(),int(prices[res]),int(world_state.player_inventory.get(res,0))]; row.position=Vector2(28,70+i*90); panel.add_child(row)
		var buy:=Button.new(); buy.text="BUY 10"; buy.position=Vector2(360,62+i*90); buy.size=Vector2(110,42); buy.pressed.connect(_trade.bind(settlement_id,res,10,true,panel)); panel.add_child(buy)
		var sell:=Button.new(); sell.text="SELL 10"; sell.position=Vector2(485,62+i*90); sell.size=Vector2(110,42); sell.pressed.connect(_trade.bind(settlement_id,res,10,false,panel)); panel.add_child(sell)
	var close:=Button.new(); close.text="CLOSE"; close.position=Vector2(250,350); close.size=Vector2(140,42); close.pressed.connect(panel.queue_free); panel.add_child(close)

func _trade(settlement_id:int,res:String,amount:int,buy:bool,panel:Panel)->void:
	var result:=world_state.trade_resource(settlement_id,res,amount,buy)
	status_label.text=("TRADE COMPLETE" if result.get("ok",false) else "TRADE FAILED: "+String(result.get("reason","unknown")))
	if result.get("ok",false): panel.queue_free()

func _open_recruitment(settlement_id: int) -> void:
	if settlement_id < 0 or settlement_id >= world_state.settlements.size():
		return
	var settlement: Dictionary = world_state.settlements[settlement_id]
	var troop_types := ["levy", "spearman", "archer", "horseman"]
	var costs := {"levy":5, "spearman":9, "archer":11, "horseman":18}
	var panel := Panel.new()
	panel.name = "RecruitmentPanel"
	panel.position = Vector2(565, 360)
	panel.size = Vector2(390, 245)
	world_map_panel.add_child(panel)
	var title := Label.new()
	title.text = "RECRUITMENT • %s" % String(settlement["name"])
	title.position = Vector2(16, 10)
	title.add_theme_font_size_override("font_size", 17)
	panel.add_child(title)
	var gold_label := Label.new()
	gold_label.text = "Gold: %d  •  Choose a troop type" % world_state.gold
	gold_label.position = Vector2(16, 38)
	panel.add_child(gold_label)
	for i in range(troop_types.size()):
		var troop_type := troop_types[i]
		var button := Button.new()
		button.text = "%s  •  %d gold each" % [troop_type.capitalize(), costs[troop_type]]
		button.position = Vector2(16, 70 + i * 36)
		button.size = Vector2(355, 30)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_recruit_troop.bind(settlement_id, troop_type, panel))
		panel.add_child(button)
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(280, 205)
	close.size = Vector2(90, 28)
	close.pressed.connect(func():
		if is_instance_valid(panel):
			panel.queue_free()
	)
	panel.add_child(close)

func _recruit_troop(settlement_id: int, troop_type: String, panel: Panel) -> void:
	var result: Dictionary = world_state.recruit_from_settlement(settlement_id, troop_type, 10)
	if result.get("ok", false):
		status_label.text = "%s: +%d %s • -%d gold" % [result["army"], result["count"], troop_type, result["cost"]]
	else:
		status_label.text = "Recruitment unavailable: %s" % result.get("reason", "unknown")
	if is_instance_valid(panel):
		panel.queue_free()
	_refresh_world_map()

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


func _open_army_command(army_id: int) -> void:
	if army_id < 0 or army_id >= world_state.armies.size():
		return
	if is_instance_valid(army_command_panel):
		army_command_panel.queue_free()
	army_command_panel = null
	var army: Dictionary = world_state.armies[army_id]
	army_command_panel = Panel.new()
	army_command_panel.position = Vector2(565, 300)
	army_command_panel.size = Vector2(390, 270)
	world_map_panel.add_child(army_command_panel)
	var info := Label.new()
	info.text = "%s\nTroops: %d • Morale: %d • Food: %d\nRegion: %s" % [army["name"], army["soldiers"], army["morale"], army["food"], world_state.regions[int(army["region"])]["name"]]
	info.position = Vector2(16, 12)
	info.size = Vector2(350, 65)
	info.add_theme_font_size_override("font_size", 14)
	army_command_panel.add_child(info)
	var formation_title:=Label.new(); formation_title.text="FORMATION"; formation_title.position=Vector2(16,80); formation_title.add_theme_font_size_override("font_size",12); army_command_panel.add_child(formation_title)
	var formations=["line","shield_wall","wedge","skirmish"]
	for j in range(formations.size()):
		var fb:=Button.new(); fb.text=formations[j].to_upper(); fb.position=Vector2(16+(j%2)*88,100+(j/2)*28); fb.size=Vector2(82,24); fb.pressed.connect(_set_army_formation.bind(army_id,formations[j])); army_command_panel.add_child(fb)
	var order_title:=Label.new(); order_title.text="ORDER"; order_title.position=Vector2(200,80); order_title.add_theme_font_size_override("font_size",12); army_command_panel.add_child(order_title)
	var orders=["hold","attack","defend","raid"]
	for j in range(orders.size()):
		var ob:=Button.new(); ob.text=orders[j].to_upper(); ob.position=Vector2(200+(j%2)*88,100+(j/2)*28); ob.size=Vector2(82,24); ob.pressed.connect(_set_army_order.bind(army_id,orders[j])); army_command_panel.add_child(ob)

	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(280, 220)
	close.size = Vector2(90, 30)
	close.pressed.connect(func():
		if is_instance_valid(army_command_panel):
			army_command_panel.queue_free()
		army_command_panel = null
	)
	army_command_panel.add_child(close)
	var neighbors: Array[int] = world_state.get_region_neighbors(int(army["region"]))
	for j in range(neighbors.size()):
		var region_id := neighbors[j]
		var move := Button.new()
		move.text = "MOVE → %s" % String(world_state.regions[region_id]["name"])
		move.position = Vector2(16 + (j % 2) * 178, 160 + (j / 2) * 31)
		move.size = Vector2(168, 27)
		move.add_theme_font_size_override("font_size", 11)
		move.pressed.connect(_issue_player_army_move.bind(army_id, region_id))
		army_command_panel.add_child(move)

func _set_army_formation(army_id:int,formation:String)->void:
	var r:=world_state.set_army_formation(army_id,formation); status_label.text="Formation: "+formation if r.get("ok",false) else "Formation failed."

func _set_army_order(army_id:int,order:String)->void:
	var r:=world_state.set_army_order(army_id,order); status_label.text="Order: "+order if r.get("ok",false) else "Order failed."

func _issue_player_army_move(army_id: int, target_region: int) -> void:
	var result: Dictionary = world_state.issue_army_move(army_id, target_region)
	if result.get("ok", false):
		status_label.text = "%s marching toward %s" % [result["army"], result["target"]]
	else:
		status_label.text = "Army move failed: %s" % result.get("reason", "unknown")
	if is_instance_valid(army_command_panel):
		army_command_panel.queue_free()
	army_command_panel = null
	_refresh_world_map()
