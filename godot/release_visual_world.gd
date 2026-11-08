extends Node3D
class_name ReleaseVisualWorld

# Authored procedural medieval vertical slice.
# This is intentionally self-contained so the Android build has a real,
# colored 3D world even when external binary art packs are absent.

var host: Node3D
var root: Node3D

func build(main_node: Node3D) -> void:
	host = main_node
	root = Node3D.new()
	root.name = "ProductionVisualWorld"
	host.add_child(root)
	_build_ground()
	_build_water()
	_build_mountains()
	_build_forest()
	_build_village(Vector3(-12.0, 0.0, -24.0))
	_build_castle(Vector3(0.0, 0.0, -42.0))
	_build_army(Vector3(0.0, 0.0, -14.0), 42, Color(0.48, 0.06, 0.05))
	_build_army(Vector3(18.0, 0.0, -18.0), 30, Color(0.08, 0.16, 0.42))
	_build_siege_camp(Vector3(11.0, 0.0, -30.0))
	_build_harbor(Vector3(34.0, 0.0, -24.0))
	_build_ship(Vector3(27.0, 0.15, -12.0), 1.0)
	_build_ship(Vector3(43.0, 0.15, -31.0), 0.82)
	_build_road()
	_build_lamps_and_banners()
	_build_sun()

func _mat(color: Color, roughness := 0.8, metallic := 0.0, transparency := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if transparency > 0.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = transparency
	return m

func _box(size: Vector3, pos: Vector3, color: Color, parent: Node3D, rot := Vector3.ZERO, roughness := 0.8) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.rotation_degrees = rot
	n.material_override = _mat(color, roughness)
	parent.add_child(n)
	return n

func _cylinder(radius: float, height: float, pos: Vector3, color: Color, parent: Node3D, sides := 16) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.04
	mesh.height = height
	mesh.radial_segments = sides
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _sphere(radius: float, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _cone(radius: float, height: float, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	n.mesh = mesh
	n.position = pos
	n.material_override = _mat(color)
	parent.add_child(n)
	return n

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(180.0, 180.0)
	ground.mesh = mesh
	ground.material_override = _mat(Color(0.19, 0.34, 0.14), 1.0)
	ground.position = Vector3(0, -0.05, -20)
	root.add_child(ground)
	for i in range(80):
		var x := float((i * 37) % 150) - 75.0
		var z := float((i * 61) % 135) - 88.0
		var rock := _sphere(0.18 + float(i % 4) * 0.08, Vector3(x, 0.12, z), Color(0.31, 0.30, 0.25), root)
		rock.scale.y = 0.45

func _build_water() -> void:
	var water := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(42.0, 125.0)
	water.mesh = mesh
	water.position = Vector3(43.0, 0.08, -30.0)
	water.rotation_degrees.y = 8.0
	water.material_override = _mat(Color(0.05, 0.36, 0.58, 0.88), 0.12, 0.05, 0.88)
	root.add_child(water)
	for i in range(28):
		var foam := _box(Vector3(1.2 + float(i % 3) * 0.5, 0.015, 0.07), Vector3(26.0 + float((i * 11) % 34), 0.11, -76.0 + float((i * 17) % 105)), Color(0.82, 0.93, 0.95, 0.55), root)
		foam.material_override = _mat(Color(0.82, 0.93, 0.95, 0.55), 0.1, 0.0, 0.55)

func _build_mountains() -> void:
	for i in range(10):
		var x := -58.0 + float(i) * 13.0
		var z := -72.0 - float(i % 3) * 5.0
		var h := 18.0 + float((i * 7) % 12)
		_cone(10.0 + float(i % 3) * 3.0, h, Vector3(x, h * 0.5 - 0.1, z), Color(0.31, 0.34, 0.29), root)
		_cone(4.8 + float(i % 2), h * 0.42, Vector3(x, h * 0.78, z), Color(0.83, 0.86, 0.84), root)

func _tree(pos: Vector3, scale := 1.0) -> void:
	var t := Node3D.new()
	t.position = pos
	t.scale = Vector3.ONE * scale
	root.add_child(t)
	_cylinder(0.22, 2.4, Vector3(0, 1.2, 0), Color(0.25, 0.12, 0.055), t, 10)
	_cone(1.65, 3.4, Vector3(0, 3.0, 0), Color(0.08, 0.29, 0.11), t)
	_cone(1.25, 2.8, Vector3(0, 4.45, 0), Color(0.10, 0.36, 0.13), t)
	_cone(0.78, 2.0, Vector3(0, 5.55, 0), Color(0.13, 0.42, 0.16), t)

func _build_forest() -> void:
	for i in range(55):
		var x := -62.0 + float((i * 29) % 120)
		var z := -10.0 + float((i * 43) % 82)
		if x > 20.0 and z < 10.0:
			continue
		_tree(Vector3(x, 0, z), 0.72 + float(i % 5) * 0.10)

func _house(pos: Vector3, scale := 1.0) -> void:
	var h := Node3D.new()
	h.position = pos
	h.scale = Vector3.ONE * scale
	root.add_child(h)
	_box(Vector3(3.4, 2.5, 3.0), Vector3(0, 1.25, 0), Color(0.55, 0.42, 0.28), h)
	_box(Vector3(3.65, 0.18, 3.25), Vector3(0, 2.6, 0), Color(0.23, 0.10, 0.055), h, Vector3(0, 0, 7))
	_box(Vector3(0.65, 1.2, 0.10), Vector3(0, 0.6, -1.53), Color(0.16, 0.09, 0.045), h)
	_box(Vector3(0.48, 0.58, 0.08), Vector3(-0.9, 1.35, -1.55), Color(0.18, 0.48, 0.62), h)
	_box(Vector3(0.48, 0.58, 0.08), Vector3(0.9, 1.35, -1.55), Color(0.18, 0.48, 0.62), h)
	_box(Vector3(3.0, 0.10, 0.12), Vector3(0, 1.65, -1.57), Color(0.19, 0.10, 0.05), h)
	_box(Vector3(0.10, 2.0, 0.12), Vector3(-1.2, 1.3, -1.57), Color(0.19, 0.10, 0.05), h)
	_box(Vector3(0.10, 2.0, 0.12), Vector3(1.2, 1.3, -1.57), Color(0.19, 0.10, 0.05), h)
	_cylinder(0.25, 0.9, Vector3(1.0, 3.0, 0.7), Color(0.28, 0.28, 0.26), h)

func _build_village(center: Vector3) -> void:
	for i in range(12):
		var a := TAU * float(i) / 12.0
		var r := 8.0 + float(i % 3) * 2.0
		_house(center + Vector3(cos(a) * r, 0, sin(a) * r), 0.82 + float(i % 3) * 0.08)
	for i in range(8):
		_tree(center + Vector3(-14.0 + float(i) * 3.8, 0, 13.0 + float(i % 2) * 2.5), 0.72)

func _tower(pos: Vector3, radius := 2.0, height := 9.0) -> void:
	_cylinder(radius, height, pos + Vector3(0, height * 0.5, 0), Color(0.42, 0.43, 0.40), root, 20)
	for i in range(8):
		var a := TAU * float(i) / 8.0
		_box(Vector3(0.55, 0.8, 0.7), pos + Vector3(cos(a) * (radius - 0.1), height + 0.15, sin(a) * (radius - 0.1)), Color(0.32, 0.33, 0.31), root)
	_cone(radius * 0.95, 2.8, pos + Vector3(0, height + 1.55, 0), Color(0.24, 0.15, 0.10), root)

func _wall(pos: Vector3, size: Vector3, rot_y := 0.0) -> void:
	var w := _box(size, pos, Color(0.43, 0.44, 0.41), root)
	w.rotation_degrees.y = rot_y
	for i in range(5):
		var x := -size.x * 0.42 + float(i) * size.x * 0.21
		var top := pos + Vector3(x, size.y * 0.55, 0)
		_box(Vector3(0.8, 0.65, size.z + 0.12), top, Color(0.31, 0.32, 0.30), root)

func _build_castle(center: Vector3) -> void:
	_wall(center + Vector3(0, 4.0, 10.5), Vector3(34, 8, 2.2))
	_wall(center + Vector3(0, 4.0, -10.5), Vector3(34, 8, 2.2))
	_wall(center + Vector3(-16.0, 4.0, 0), Vector3(2.2, 8, 23))
	_wall(center + Vector3(16.0, 4.0, 0), Vector3(2.2, 8, 23))
	_tower(center + Vector3(-16, 0, -10.5), 2.7, 10)
	_tower(center + Vector3(16, 0, -10.5), 2.7, 10)
	_tower(center + Vector3(-16, 0, 10.5), 2.7, 10)
	_tower(center + Vector3(16, 0, 10.5), 2.7, 10)
	_box(Vector3(9.0, 6.0, 2.6), center + Vector3(0, 3.0, -10.8), Color(0.45, 0.45, 0.42), root)
	_box(Vector3(4.0, 5.0, 0.5), center + Vector3(0, 2.5, -12.2), Color(0.18, 0.10, 0.055), root)
	for i in range(3):
		_tower(center + Vector3(-5.5 + float(i) * 5.5, 0, 0), 2.0, 8.0 + float(i % 2) * 2.0)
	_box(Vector3(13.0, 7.0, 9.0), center + Vector3(0, 3.5, 3.0), Color(0.40, 0.41, 0.39), root)
	_cone(7.0, 3.8, center + Vector3(0, 9.0, 3.0), Color(0.23, 0.14, 0.09), root)
	_box(Vector3(0.22, 7.0, 0.22), center + Vector3(0, 12.0, 3.0), Color(0.18, 0.11, 0.06), root)
	_box(Vector3(2.8, 1.5, 0.08), center + Vector3(1.35, 11.2, 3.0), Color(0.65, 0.08, 0.07), root)
	for i in range(6):
		var window_x := -4.5 + float(i) * 1.8
		_box(Vector3(0.65, 1.2, 0.08), center + Vector3(window_x, 4.0, -1.58), Color(0.09, 0.22, 0.28), root)

func _soldier(pos: Vector3, faction_color: Color, mounted := false) -> void:
	var s := Node3D.new()
	s.position = pos
	root.add_child(s)
	if mounted:
		_box(Vector3(1.35, 0.42, 2.0), Vector3(0, 0.72, 0), Color(0.20, 0.10, 0.055), s)
	_cylinder(0.24, 1.25, Vector3(0, 1.55, 0), Color(0.24, 0.25, 0.27), s, 10)
	_sphere(0.25, Vector3(0, 2.35, 0), Color(0.65, 0.47, 0.32), s)
	_box(Vector3(0.16, 1.25, 0.12), Vector3(0.52, 1.6, 0), Color(0.72, 0.73, 0.70), s, Vector3(0, 0, -18))
	_cylinder(0.38, 0.08, Vector3(-0.48, 1.6, 0.18), faction_color, s)

func _build_army(center: Vector3, count: int, faction_color: Color) -> void:
	var cols := 7
	for i in range(count):
		var row := i / cols
		var col := i % cols
		var x := (float(col) - 3.0) * 1.25 + float(row % 2) * 0.35
		var z := float(row) * 1.45
		_soldier(center + Vector3(x, 0, z), faction_color, i % 9 == 0)
	for i in range(5):
		_box(Vector3(0.08, 4.5, 0.08), center + Vector3(-7.0 + float(i) * 3.5, 2.3, -1.5), Color(0.16, 0.10, 0.06), root)
		_box(Vector3(1.3, 0.8, 0.08), center + Vector3(-6.35 + float(i) * 3.5, 3.8, -1.5), faction_color, root)

func _build_siege_camp(pos: Vector3) -> void:
	for i in range(3):
		var x := -5.0 + float(i) * 5.0
		_box(Vector3(3.8, 2.4, 3.0), pos + Vector3(x, 1.2, 5.0), Color(0.37, 0.23, 0.13), root)
		_cone(2.6, 1.8, pos + Vector3(x, 3.2, 5.0), Color(0.24, 0.12, 0.07), root)
	_box(Vector3(5.5, 3.2, 2.5), pos + Vector3(0, 1.6, -3.0), Color(0.35, 0.27, 0.18), root)
	_box(Vector3(7.0, 0.35, 0.35), pos + Vector3(0, 3.4, -3.0), Color(0.18, 0.10, 0.055), root)

func _build_harbor(pos: Vector3) -> void:
	for i in range(7):
		_box(Vector3(1.0, 0.6, 7.0), pos + Vector3(float(i) * 2.0 - 6.0, 0.25, 0), Color(0.30, 0.18, 0.09), root)
	_box(Vector3(18.0, 0.45, 2.2), pos + Vector3(0, 0.2, -4.0), Color(0.32, 0.20, 0.10), root)

func _build_ship(pos: Vector3, scale_value: float) -> void:
	var ship := Node3D.new()
	ship.position = pos
	ship.scale = Vector3.ONE * scale_value
	root.add_child(ship)
	_box(Vector3(7.5, 0.8, 2.0), Vector3(0, 0.3, 0), Color(0.16, 0.08, 0.045), ship)
	_box(Vector3(5.8, 0.32, 1.55), Vector3(0, 0.85, 0), Color(0.36, 0.20, 0.10), ship)
	_cylinder(0.14, 8.0, Vector3(0, 4.0, 0), Color(0.18, 0.11, 0.06), ship)
	_box(Vector3(3.8, 3.0, 0.08), Vector3(0, 4.0, 0), Color(0.76, 0.66, 0.48), ship)
	for i in range(8):
		_sphere(0.10, Vector3(-2.7 + float(i) * 0.75, 1.2, 0), Color(0.45, 0.30, 0.18), ship)

func _build_road() -> void:
	for i in range(22):
		var x := -17.0 + float(i) * 1.55
		_box(Vector3(1.4, 0.04, 2.4), Vector3(x, 0.03, -4.0 - float(i) * 1.3), Color(0.39, 0.31, 0.20), root)

func _build_lamps_and_banners() -> void:
	for i in range(8):
		var x := -18.0 + float(i) * 5.0
		_cylinder(0.08, 3.0, Vector3(x, 1.5, -8.0), Color(0.10, 0.07, 0.04), root, 8)
		_sphere(0.22, Vector3(x, 3.1, -8.0), Color(0.95, 0.60, 0.12), root)
	for i in range(6):
		var x := -13.0 + float(i) * 5.0
		_box(Vector3(0.10, 4.2, 0.10), Vector3(x, 2.1, -39.0), Color(0.14, 0.09, 0.05), root)
		_box(Vector3(1.8, 1.2, 0.05), Vector3(x + 0.85, 3.1, -39.0), Color(0.52, 0.055, 0.045), root)

func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "ProductionSun"
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	root.add_child(sun)
