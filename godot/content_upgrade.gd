class_name ContentUpgrade
extends Node3D

# Deterministic authored-style procedural content layer. This is intentionally
# separate from the simulation so visual iteration cannot corrupt campaign state.

var root: Node3D
var rng := RandomNumberGenerator.new()

func build(world_root: Node3D) -> void:
	root = world_root
	rng.seed = 914273
	_build_landmarks()
	_build_village_detail(Vector3(-8, 0, -7))
	_build_village_detail(Vector3(10, 0, -10))
	_build_forest(Vector3(-22, 0, 14), 34, 0.95)
	_build_forest(Vector3(22, 0, 18), 28, 1.15)
	_build_road_markers()

func _mat(c: Color, roughness := 0.86) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = roughness
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.rotation_degrees = rot
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color, sides := 8) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.05
	mesh.height = height
	mesh.radial_segments = sides
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.left_to_right = false
	mesh.size = Vector3(radius * 2.0, height, radius * 2.0)
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _build_landmarks() -> void:
	var fort := Node3D.new()
	fort.name = "StoneHillFort"
	fort.position = Vector3(0, 0, 12)
	root.add_child(fort)
	var stone := Color(0.28, 0.30, 0.32)
	var dark := Color(0.12, 0.10, 0.09)
	# Curtain wall and four towers create a recognizable silhouette at a distance.
	_box(fort, Vector3(18, 3.2, 0.9), Vector3(0, 1.6, -8.5), stone)
	_box(fort, Vector3(18, 3.2, 0.9), Vector3(0, 1.6, 8.5), stone)
	_box(fort, Vector3(0.9, 3.2, 16.2), Vector3(-8.5, 1.6, 0), stone)
	_box(fort, Vector3(0.9, 3.2, 16.2), Vector3(8.5, 1.6, 0), stone)
	for p in [Vector3(-8.5, 2.6, -8.5), Vector3(8.5, 2.6, -8.5), Vector3(-8.5, 2.6, 8.5), Vector3(8.5, 2.6, 8.5)]:
		_cylinder(fort, 1.55, 5.2, p, stone, 10)
		_box(fort, Vector3(2.8, 0.35, 2.8), p + Vector3(0, 2.75, 0), dark)
	# Gatehouse, bridge and banner.
	_box(fort, Vector3(5.0, 4.5, 1.8), Vector3(0, 2.25, -8.8), stone)
	_box(fort, Vector3(1.5, 2.5, 2.0), Vector3(0, 1.15, -8.0), dark)
	for x in [-1.8, 1.8]:
		_box(fort, Vector3(0.18, 4.2, 0.18), Vector3(x, 5.1, -8.8), Color(0.10, 0.07, 0.05))
		_box(fort, Vector3(1.6, 2.2, 0.08), Vector3(x, 4.0, -8.9), Color(0.48, 0.06, 0.06))

func _build_village_detail(center: Vector3) -> void:
	var village := Node3D.new()
	village.name = "VillageDetail_%d_%d" % [int(center.x), int(center.z)]
	village.position = center
	root.add_child(village)
	var wood := Color(0.27, 0.16, 0.09)
	var canvas := Color(0.63, 0.48, 0.30)
	var stone := Color(0.36, 0.34, 0.30)
	# Market stalls.
	for i in range(4):
		var x := float(i) * 2.4 - 3.6
		_box(village, Vector3(1.8, 1.1, 1.2), Vector3(x, 0.55, -4.8), wood)
		for px in [-0.72, 0.72]:
			_cylinder(village, 0.07, 2.0, Vector3(x + px, 1.0, -4.8), wood, 6)
		_box(village, Vector3(2.0, 0.12, 1.5), Vector3(x, 2.0, -4.8), canvas, Vector3(0, 0, rng.randf_range(-7.0, 7.0)))
	# Well and stone trough.
	_cylinder(village, 0.9, 0.75, Vector3(4.5, 0.38, -2.8), stone, 12)
	_cylinder(village, 0.58, 0.82, Vector3(4.5, 0.82, -2.8), Color(0.08, 0.16, 0.19), 12)
	for side in [-1.0, 1.0]:
		_box(village, Vector3(0.14, 1.9, 0.14), Vector3(4.5 + side * 0.65, 1.25, -2.8), wood)
	_box(village, Vector3(1.7, 0.14, 0.14), Vector3(4.5, 2.05, -2.8), wood)
	# Village palisade fragment and watch post.
	for i in range(8):
		var a := deg_to_rad(-70.0 + i * 20.0)
		var p := Vector3(cos(a) * 8.5, 1.1, sin(a) * 8.5)
		_cylinder(village, 0.10, 2.2, p, wood, 6)
	# Central fire bowl.
	_cylinder(village, 0.7, 0.35, Vector3(-4.8, 0.18, 1.8), stone, 10)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1.0, 0.45, 0.16)
	fire.light_energy = 1.6
	fire.omni_range = 7.0
	fire.position = Vector3(-4.8, 1.0, 1.8)
	village.add_child(fire)
	_box(village, Vector3(0.22, 0.75, 0.22), Vector3(-4.8, 0.7, 1.8), Color(0.95, 0.22, 0.04))

func _build_forest(center: Vector3, count: int, scale: float) -> void:
	var forest := Node3D.new()
	forest.name = "Forest_%d_%d" % [int(center.x), int(center.z)]
	root.add_child(forest)
	for i in range(count):
		var p := center + Vector3(rng.randf_range(-10.0, 10.0), 0, rng.randf_range(-10.0, 10.0))
		var s := scale * rng.randf_range(0.75, 1.3)
		_cylinder(forest, 0.20 * s, 1.9 * s, p + Vector3(0, 0.95 * s, 0), Color(0.18, 0.11, 0.055), 7)
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.08 * s
		cone.bottom_radius = 1.0 * s
		cone.height = 2.6 * s
		cone.radial_segments = 7
		crown.mesh = cone
		crown.position = p + Vector3(0, 2.7 * s, 0)
		crown.material_override = _mat(Color(0.08, 0.22 + rng.randf_range(0.0, 0.08), 0.10))
		forest.add_child(crown)

func _build_road_markers() -> void:
	var roads := Node3D.new()
	roads.name = "RoadMarkers"
	root.add_child(roads)
	for z in range(-28, 29, 4):
		_box(roads, Vector3(1.0, 0.035, 2.5), Vector3(0, 0.02, z), Color(0.31, 0.24, 0.16))
