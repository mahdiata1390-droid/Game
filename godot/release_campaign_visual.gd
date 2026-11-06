extends Node3D
class_name ReleaseCampaignVisual

var host: Node3D
var world: Node
var army_nodes: Dictionary = {}
var tick := 0.0

func build(root: Node3D) -> void:
	host = root
	world = root.get_node_or_null("WorldState")
	if world == null:
		return
	set_process(true)
	_sync_armies(true)

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world) or host == null:
		return
	tick += delta
	if tick < 0.35:
		return
	tick = 0.0
	_sync_armies(false)

func _sync_armies(force: bool) -> void:
	var seen: Dictionary = {}
	for army in world.armies:
		var id := int(army.get("id", -1))
		if id < 0:
			continue
		seen[id] = true
		var marker: Node3D = army_nodes.get(id)
		if not is_instance_valid(marker):
			marker = _create_army_marker(army)
			army_nodes[id] = marker
		var target_region := int(army.get("target_region", army.get("region", 0)))
		var current_region := int(army.get("region", 0))
		if current_region < 0 or current_region >= world.regions.size():
			continue
		var current_pos: Vector2 = world.regions[current_region].get("position", Vector2.ZERO)
		var target_pos: Vector2 = current_pos
		if target_region >= 0 and target_region < world.regions.size():
			target_pos = world.regions[target_region].get("position", current_pos)
		var destination := Vector3(target_pos.x, 0.08, target_pos.y)
		var moving := bool(army.get("moving", false)) and target_region != current_region
		if moving:
			var from := Vector3(current_pos.x, 0.08, current_pos.y)
			var to := Vector3(target_pos.x, 0.08, target_pos.y)
			var pulse := fmod(float(Time.get_ticks_msec()) / 900.0 + float(id), 1.0)
			destination = from.lerp(to, pulse * 0.35)
			marker.position = marker.position.lerp(destination, 0.30)
		else:
			marker.position = marker.position.lerp(destination, 0.45)
		var label := marker.get_node_or_null("ArmyLabel") as Label3D
		if label:
			var order := String(army.get("order", "hold")).to_upper()
			var formation := String(army.get("formation", "line")).to_upper()
			label.text = "%s\\n%d troops • %s\\n%s" % [String(army.get("name", "Army")), int(army.get("soldiers", 0)), order, formation]
		var flag := marker.get_node_or_null("Flag") as MeshInstance3D
		if flag:
			var faction := String(army.get("owner", "Free Company"))
			flag.material_override = _material(world.get_faction_banner(faction), world.get_faction_accent(faction))
		if force:
			marker.position = destination
	for id in army_nodes.keys():
		if not seen.has(id):
			var old: Node = army_nodes[id]
			if is_instance_valid(old):
				old.queue_free()
			army_nodes.erase(id)

func _create_army_marker(army: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "CampaignArmy_%d" % int(army.get("id", 0))
	host.add_child(root)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.48
	base_mesh.bottom_radius = 0.58
	base_mesh.height = 0.16
	base.mesh = base_mesh
	base.position.y = 0.08
	base.material_override = _material(Color(0.10,0.10,0.10), Color(0.75,0.62,0.25))
	root.add_child(base)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.025
	pole_mesh.bottom_radius = 0.035
	pole_mesh.height = 2.1
	pole.mesh = pole_mesh
	pole.position = Vector3(0, 1.05, 0)
	pole.material_override = _material(Color(0.16,0.11,0.07), Color(0.7,0.55,0.25))
	root.add_child(pole)

	var flag := MeshInstance3D.new()
	flag.name = "Flag"
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.95, 0.55, 0.045)
	flag.mesh = flag_mesh
	flag.position = Vector3(0.48, 1.55, 0)
	root.add_child(flag)

	var spear := MeshInstance3D.new()
	var spear_mesh := CylinderMesh.new()
	spear_mesh.top_radius = 0.0
	spear_mesh.bottom_radius = 0.025
	spear_mesh.height = 0.75
	spear.mesh = spear_mesh
	spear.position = Vector3(0.0, 1.45, 0.0)
	spear.material_override = _material(Color(0.72,0.72,0.68), Color(0.85,0.75,0.35))
	root.add_child(spear)

	var label := Label3D.new()
	label.name = "ArmyLabel"
	label.position = Vector3(0, 2.35, 0)
	label.font_size = 24
	label.outline_size = 7
	label.modulate = Color(0.94, 0.92, 0.82)
	root.add_child(label)

	return root

func _material(primary: Color, accent: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = primary
	material.metallic = 0.15
	material.roughness = 0.65
	return material
