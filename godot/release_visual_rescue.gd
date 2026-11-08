extends Node3D
class_name ReleaseVisualRescue

# Guaranteed authored visual layer for Android.
# It does not replace gameplay systems; it guarantees a readable,
# colorful medieval scene even if imported production meshes fail to render.

var root: Node3D
var materials: Dictionary = {}

func build(host: Node) -> void:
    root = Node3D.new()
    root.name = "AuthoredWorldVisual"
    host.add_child(root)
    _build_materials()
    _build_terrain()
    _build_roads()
    _build_village(Vector3(-8, 0, -7), "village", 0.0)
    _build_town(Vector3(10, 0, -10))
    _build_castle(Vector3(0, 0, 13))
    _build_forest()
    _build_banners()
    _build_lighting_accents()

func _mat(id: String, color: Color = Color.WHITE, metallic: float = 0.0, roughness: float = 0.8) -> StandardMaterial3D:
    if materials.has(id):
        return materials[id]
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    materials[id] = m
    return m

func _mesh_box(size: Vector3, pos: Vector3, mat: Material, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    n.rotation_degrees = rot
    n.material_override = mat
    parent.add_child(n)
    return n

func _mesh_cylinder(radius: float, height: float, pos: Vector3, mat: Material, parent: Node3D, sides := 12) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius * 1.03
    mesh.height = height
    mesh.radial_segments = sides
    n.mesh = mesh
    n.position = pos
    n.material_override = mat
    parent.add_child(n)
    return n

func _mesh_sphere(radius: float, pos: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
    var n := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 8
    n.mesh = mesh
    n.position = pos
    n.material_override = mat
    parent.add_child(n)
    return n

func _build_materials() -> void:
    _mat("grass", Color("#4f7d43"))
    _mat("grass2", Color("#6f9b50"))
    _mat("soil", Color("#76553a"))
    _mat("road", Color("#b08a5c"))
    _mat("stone", Color("#737b83"))
    _mat("stone_dark", Color("#454d55"))
    _mat("wood", Color("#6e4327"))
    _mat("wood_dark", Color("#3e2618"))
    _mat("plaster", Color("#c7ad7c"))
    _mat("roof", Color("#8b3f32"))
    _mat("roof2", Color("#5d3030"))
    _mat("water", Color("#2f7890"))
    _mat("leaf", Color("#3f7d3d"))
    _mat("leaf2", Color("#6a9b4b"))
    _mat("gold", Color("#d6a43a"), 0.15, 0.4)
    _mat("red", Color("#9d3030"))
    _mat("blue", Color("#315c9c"))
    _mat("cream", Color("#e7d7ad"))
    _mat("dark", Color("#1c2026"))
    _mat("fire", Color("#e46d2f"), 0.0, 0.35)

func _build_terrain() -> void:
    _mesh_box(Vector3(150, 0.5, 150), Vector3(0, -0.28, 0), _mat("grass"), root)
    # Subtle terrain tiles prevent a flat black-looking horizon.
    for x in range(-6, 7):
        for z in range(-6, 7):
            if (x + z) % 2 == 0:
                _mesh_box(Vector3(11.5, 0.035, 11.5), Vector3(x * 12.0, 0.02, z * 12.0), _mat("grass2"), root)
    _mesh_box(Vector3(28, 0.08, 18), Vector3(42, 0.06, -22), _mat("water"), root)

func _build_roads() -> void:
    _mesh_box(Vector3(62, 0.09, 3.8), Vector3(0, 0.07, -7), _mat("road"), root)
    _mesh_box(Vector3(3.8, 0.09, 60), Vector3(-8, 0.075, 5), _mat("road"), root, Vector3(0, 0, 0))
    _mesh_box(Vector3(5.0, 0.10, 48), Vector3(2, 0.08, 16), _mat("road"), root)

func _house(parent: Node3D, pos: Vector3, scale_factor: float, roof_mat: Material) -> void:
    var h := Node3D.new()
    h.position = pos
    h.scale = Vector3.ONE * scale_factor
    parent.add_child(h)
    _mesh_box(Vector3(3.6, 2.5, 3.2), Vector3(0, 1.25, 0), _mat("plaster"), h)
    _mesh_box(Vector3(3.9, 0.42, 3.5), Vector3(0, 2.63, 0), roof_mat, h, Vector3(0, 0, 3))
    _mesh_box(Vector3(0.65, 1.25, 0.12), Vector3(0, 0.63, -1.64), _mat("wood_dark"), h)
    _mesh_box(Vector3(0.48, 0.55, 0.12), Vector3(-0.9, 1.35, -1.65), _mat("blue"), h)
    _mesh_box(Vector3(0.48, 0.55, 0.12), Vector3(0.9, 1.35, -1.65), _mat("blue"), h)
    _mesh_box(Vector3(3.1, 0.11, 0.12), Vector3(0, 1.55, -1.68), _mat("wood_dark"), h)
    _mesh_box(Vector3(0.11, 1.9, 0.12), Vector3(-1.28, 1.25, -1.68), _mat("wood_dark"), h)
    _mesh_box(Vector3(0.11, 1.9, 0.12), Vector3(1.28, 1.25, -1.68), _mat("wood_dark"), h)
    _mesh_box(Vector3(0.42, 0.85, 0.42), Vector3(1.05, 3.05, 0.75), _mat("stone_dark"), h)

func _build_village(center: Vector3, kind: String, yaw: float) -> void:
    var village := Node3D.new()
    village.name = "AuthoredVillage"
    village.position = center
    village.rotation.y = yaw
    root.add_child(village)
    _mesh_cylinder(7.8, 0.12, Vector3(0, 0.12, 0), _mat("soil"), village, 32)
    var spots = [Vector3(-4,0,-3),Vector3(3.5,0,-3.2),Vector3(-3.2,0,3.4),Vector3(3.5,0,3.2),Vector3(0,0,0)]
    for i in range(spots.size()):
        _house(village, spots[i], 0.95 if i < 4 else 0.82, _mat("roof" if i % 2 == 0 else "roof2"))
    _mesh_cylinder(1.1, 0.18, Vector3(0,0.18,0), _mat("stone"), village, 16)
    _mesh_cylinder(0.8, 1.2, Vector3(0,0.8,0), _mat("wood"), village, 12)
    _mesh_cylinder(0.98, 0.15, Vector3(0,1.45,0), _mat("roof"), village, 12)

func _build_town(center: Vector3) -> void:
    var town := Node3D.new()
    town.name = "AuthoredTown"
    town.position = center
    root.add_child(town)
    _mesh_box(Vector3(18,0.28,18), Vector3(0,0.12,0), _mat("stone_dark"), town)
    _mesh_box(Vector3(15,0.32,15), Vector3(0,0.31,0), _mat("soil"), town)
    for i in range(6):
        var a := TAU * float(i) / 6.0
        _house(town, Vector3(cos(a)*6.0,0,sin(a)*6.0), 1.0, _mat("roof2" if i%2 else "roof"))
    _mesh_cylinder(1.4, 0.25, Vector3(0,0.35,0), _mat("stone"), town, 16)
    _mesh_cylinder(0.95, 2.2, Vector3(0,1.45,0), _mat("plaster"), town, 12)
    _mesh_box(Vector3(1.1,2.1,0.18), Vector3(0,1.4,-1.02), _mat("wood_dark"), town)
    _mesh_box(Vector3(0.18,2.2,1.4), Vector3(-0.55,1.5,0), _mat("wood_dark"), town)
    _mesh_box(Vector3(0.18,2.2,1.4), Vector3(0.55,1.5,0), _mat("wood_dark"), town)
    _mesh_cylinder(1.65, 0.3, Vector3(0,2.65,0), _mat("roof"), town, 12)

func _build_castle(center: Vector3) -> void:
    var castle := Node3D.new()
    castle.name = "AuthoredCastle"
    castle.position = center
    root.add_child(castle)
    _mesh_box(Vector3(28,0.35,28), Vector3(0,0.18,0), _mat("stone_dark"), castle)
    _mesh_box(Vector3(23,0.45,23), Vector3(0,0.45,0), _mat("stone"), castle)
    for p in [Vector3(-11,2,-11),Vector3(11,2,-11),Vector3(-11,2,11),Vector3(11,2,11)]:
        _mesh_cylinder(2.1, 5.0, p, _mat("stone"), castle, 12)
        _mesh_cylinder(2.35, 0.5, p + Vector3(0,2.75,0), _mat("roof2"), castle, 12)
    _mesh_box(Vector3(17,5,2), Vector3(0,2.5,-11), _mat("stone"), castle)
    _mesh_box(Vector3(17,5,2), Vector3(0,2.5,11), _mat("stone"), castle)
    _mesh_box(Vector3(2,5,17), Vector3(-11,2.5,0), _mat("stone"), castle)
    _mesh_box(Vector3(2,5,17), Vector3(11,2.5,0), _mat("stone"), castle)
    _mesh_box(Vector3(4.2,5.2,2.4), Vector3(0,2.6,-10.5), _mat("wood_dark"), castle)
    _mesh_box(Vector3(7,0.4,7), Vector3(0,5.2,0), _mat("wood"), castle)
    _mesh_cylinder(3.4, 4.8, Vector3(0,2.5,0), _mat("plaster"), castle, 12)
    _mesh_cylinder(3.8, 0.4, Vector3(0,5.0,0), _mat("roof"), castle, 12)

func _tree(pos: Vector3, scale_factor: float = 1.0) -> void:
    var t := Node3D.new()
    t.position = pos
    t.scale = Vector3.ONE * scale_factor
    root.add_child(t)
    _mesh_cylinder(0.24, 2.2, Vector3(0,1.1,0), _mat("wood"), t, 10)
    _mesh_sphere(1.15, Vector3(0,2.45,0), _mat("leaf"), t)
    _mesh_sphere(0.82, Vector3(0.55,2.85,0.1), _mat("leaf2"), t)
    _mesh_sphere(0.72, Vector3(-0.5,2.75,-0.15), _mat("leaf"), t)

func _build_forest() -> void:
    var points = [
        Vector3(-26,0,-24),Vector3(-20,0,-20),Vector3(-28,0,-10),Vector3(-24,0,4),
        Vector3(-28,0,16),Vector3(-20,0,24),Vector3(20,0,22),Vector3(28,0,14),
        Vector3(26,0,2),Vector3(24,0,-10),Vector3(28,0,-20),Vector3(18,0,-26),
        Vector3(-2,0,28),Vector3(8,0,27),Vector3(-10,0,25)
    ]
    for i in range(points.size()):
        _tree(points[i], 0.9 + float(i % 4) * 0.12)
    for i in range(28):
        var x := float((i * 13) % 56) - 28.0
        var z := float((i * 19) % 52) - 26.0
        if abs(x) < 16.0 and abs(z) < 16.0:
            continue
        _mesh_sphere(0.45 + float(i%3)*0.12, Vector3(x,0.4,z), _mat("stone"), root)

func _build_banners() -> void:
    for data in [
        [Vector3(-8,0,-12),_mat("blue")],
        [Vector3(10,0,-14),_mat("red", Color("#9d3030"))],
        [Vector3(0,0,0),_mat("gold", Color("#d6a43a"))]
    ]:
        var p: Vector3 = data[0]
        var pole := Node3D.new()
        pole.position = p
        root.add_child(pole)
        _mesh_cylinder(0.09, 4.0, Vector3(0,2,0), _mat("wood_dark", Color("#3e2618")), pole, 8)
        _mesh_box(Vector3(1.2,0.8,0.08), Vector3(0.55,3.35,0), data[1], pole)
        _mesh_cylinder(0.16,0.22,Vector3(0,4.1,0),_mat("gold", Color("#d6a43a")),pole,8)

func _build_lighting_accents() -> void:
    for p in [Vector3(-8,0,-7),Vector3(10,0,-10),Vector3(0,0,13)]:
        var light := OmniLight3D.new()
        light.position = p + Vector3(0,3.0,0)
        light.light_color = Color(1.0,0.72,0.38)
        light.light_energy = 0.45
        light.omni_range = 8.0
        root.add_child(light)
