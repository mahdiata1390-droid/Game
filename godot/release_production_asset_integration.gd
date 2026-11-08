extends Node3D
class_name ReleaseProductionAssetIntegration

# Turns the downloaded production packs into actual in-world content.
# Only non-restricted visual categories are auto-instantiated here:
# medieval environment, nature, and humanoid characters.

var registry: ReleaseAssetRegistry
var spawned: Array[Node] = []
var asset_nodes_by_role: Dictionary = {}
var world_state_ref: Node = null
var host_ref: Node = null

const MAX_WORLD_PROPS = 96
const MAX_NATURE = 180
const MAX_CHARACTERS = 18
const MAX_EXTRA_CHARACTERS = 24
const MAX_CREATURES = 12
const MAX_CROPS = 48

func setup(asset_registry: ReleaseAssetRegistry) -> void:
    registry = asset_registry
    host_ref = get_parent()
    call_deferred("_populate")

func _populate() -> void:
    if not is_instance_valid(registry):
        return
    _clear_previous()
    asset_nodes_by_role.clear()
    _populate_environment()
    _populate_extra_buildings()
    _populate_nature()
    _populate_animals()
    _populate_crops()
    _populate_characters()
    _populate_extra_characters()
    _populate_creatures()
    _bind_world_content()
    _apply_live_actor_visuals()

func _clear_previous() -> void:
    for node in spawned:
        if is_instance_valid(node):
            node.queue_free()
    spawned.clear()

func _load_scene(path: String) -> Node:
    var resource = ResourceLoader.load(path)
    if resource != null and resource is PackedScene:
        var instance = (resource as PackedScene).instantiate()
        if instance is Node3D:
            return instance
        instance.queue_free()

    # Direct GLTF fallback for Android/CI where editor import cache is unavailable.
    var lower := path.to_lower()
    if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
        return null
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    var err := document.append_from_file(path, state)
    if err != OK:
        return null
    var generated = document.generate_scene(state)
    if generated is Node3D:
        return generated
    if generated != null:
        generated.queue_free()
    return null

func _models(pack_id: String) -> Array:
    return registry.get_models(pack_id)

func _populate_environment() -> void:
    var models = _models("medieval_village")
    if models.is_empty():
        return
    var count = mini(models.size(), MAX_WORLD_PROPS)
    for i in range(count):
        var path: String = models[i]
        var lower = path.to_lower()
        # Skip obviously tiny/duplicate technical files.
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node = _load_scene(path)
        if node == null:
            continue
        var angle = float(i) * 0.83
        var radius = 18.0 + float(i % 9) * 7.0
        node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        node.scale = Vector3.ONE * (0.82 + float(i % 4) * 0.08)
        add_child(node)
        spawned.append(node)
        _register_role("settlement", node)


func _populate_extra_buildings() -> void:
    var models = _models("buildings_extra")
    if models.is_empty():
        return
    var placed = 0
    for i in range(models.size()):
        var path: String = models[i]
        var lower = path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node = _load_scene(path)
        if node == null:
            continue
        var angle = float(i) * 1.71
        var radius = 105.0 + float(i % 7) * 12.0
        node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        node.scale = Vector3.ONE * (0.85 + float(i % 3) * 0.08)
        add_child(node)
        spawned.append(node)
        _register_role("building", node)
        placed += 1
        if placed >= 24:
            break

func _populate_animals() -> void:
    var models = _models("animals")
    if models.is_empty():
        return
    var placed = 0
    for i in range(models.size()):
        var path: String = models[i]
        var lower = path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node = _load_scene(path)
        if node == null:
            continue
        var angle = float(i) * 2.17
        var radius = 72.0 + float(i % 8) * 5.0
        node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        node.scale = Vector3.ONE * (0.55 + float(i % 4) * 0.08)
        add_child(node)
        spawned.append(node)
        _register_role("animal", node)
        placed += 1
        if placed >= 20:
            break

func _populate_nature() -> void:
    var models = _models("nature")
    if models.is_empty():
        return
    var count = mini(models.size(), MAX_NATURE)
    var placed = 0
    for i in range(count):
        var path: String = models[i]
        var lower = path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node = _load_scene(path)
        if node == null:
            continue
        var angle = float(i) * 2.39996
        var radius = 55.0 + float(i % 13) * 6.0
        node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        node.scale = Vector3.ONE * (0.65 + float(i % 5) * 0.08)
        add_child(node)
        spawned.append(node)
        _register_role("nature", node)
        placed += 1
        if placed >= MAX_NATURE:
            break

func _populate_characters() -> void:
    var models = _models("characters")
    if models.is_empty():
        return
    var count = mini(models.size(), MAX_CHARACTERS)
    for i in range(count):
        var path: String = models[i]
        var lower = path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node = _load_scene(path)
        if node == null:
            continue
        var angle = float(i) * TAU / float(maxi(count, 1))
        node.position = Vector3(cos(angle) * 12.0, 0.0, sin(angle) * 12.0)
        node.scale = Vector3.ONE * 1.0
        add_child(node)
        spawned.append(node)
        _register_role("character", node)


func _populate_crops() -> void:
    _populate_ring("crops", MAX_CROPS, 42.0, 5.5, 0.7, 2.11)

func _populate_extra_characters() -> void:
    _populate_ring("characters_extra", MAX_EXTRA_CHARACTERS, 20.0, 3.0, 1.0, 0.97)

func _populate_creatures() -> void:
    _populate_ring("creatures", MAX_CREATURES, 88.0, 8.0, 0.8, 2.73)

func _populate_ring(pack_id: String, limit: int, radius: float, spacing: float, scale_base: float, angle_step: float) -> void:
    var models = _models(pack_id)
    if models.is_empty():
        return
    var placed = 0
    for i in range(models.size()):
        var path: String = models[i]
        var lower = path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node = _load_scene(path)
        if node == null:
            continue
        var angle = float(i) * angle_step
        var r = radius + float(i % 7) * spacing
        node.position = Vector3(cos(angle) * r, 0.0, sin(angle) * r)
        node.scale = Vector3.ONE * (scale_base + float(i % 4) * 0.06)
        add_child(node)
        spawned.append(node)
        _register_role(pack_id, node)
        placed += 1
        if placed >= limit:
            break

func bind_world(world: Node) -> void:
    world_state_ref = world
    host_ref = get_parent()
    call_deferred("_bind_world_content")
    call_deferred("_apply_live_actor_visuals")

func _apply_live_actor_visuals() -> void:
    if not is_instance_valid(host_ref):
        return
    var character_pool = get_role_nodes("character")
    if character_pool.is_empty():
        return
    var source: Node3D = character_pool[0] as Node3D
    if source == null:
        return
    var actors: Array[Node3D] = []
    var player_node = host_ref.get("player") as Node3D
    if player_node != null:
        actors.append(player_node)
    var troop_data: Array = host_ref.get("troops")
    for data in troop_data:
        var troop = data.get("node") as Node3D
        if troop != null:
            actors.append(troop)
    var troop_index = 0
    for actor in actors:
        if not is_instance_valid(actor) or actor.get_node_or_null("ProductionHumanoidVisual") != null:
            continue
        for child in actor.get_children():
            if child is MeshInstance3D:
                (child as MeshInstance3D).visible = false
        var visual = source.duplicate()
        visual.name = "ProductionHumanoidVisual"
        actor.add_child(visual)
        visual.position = Vector3(0.0, -0.92, 0.0)
        visual.rotation = Vector3.ZERO
        visual.scale = Vector3.ONE * (0.88 + float((troop_index + actors.size()) % 4) * 0.045)
        if actor != player_node and troop_index < troop_data.size():
            var faction = String(troop_data[troop_index].get("faction",""))
            if faction == "eastern_tribes":
                visual.rotation.y = PI
            elif faction == "southern_sultanate":
                visual.rotation.y = PI * 0.5
            troop_index += 1

func _bind_world_content() -> void:
    if world_state_ref == null or not is_instance_valid(world_state_ref):
        return
    var settlements: Array = world_state_ref.get("settlements")
    if settlements.is_empty():
        return
    var settlement_nodes = get_role_nodes("settlement")
    var building_nodes = get_role_nodes("building")
    var character_nodes = get_role_nodes("character")
    var extra_character_nodes = get_role_nodes("characters_extra")
    var animal_nodes = get_role_nodes("animal")
    var crop_nodes = get_role_nodes("crops")
    var creature_nodes = get_role_nodes("creatures")
    var nature_nodes = get_role_nodes("nature")
    var used = {}
    for i in range(settlements.size()):
        var settlement: Dictionary = settlements[i]
        var p: Vector2 = settlement.get("position", Vector2.ZERO)
        var center = Vector3(p.x, 0.0, p.y)
        var kind = String(settlement.get("type", "village"))
        var settlement_scale = 1.0
        var building_slots = 2
        var building_radius = 3.2
        if kind == "town":
            settlement_scale = 1.12
            building_slots = 4
            building_radius = 4.6
        elif kind == "city":
            settlement_scale = 1.28
            building_slots = 6
            building_radius = 6.2
        elif kind == "castle":
            settlement_scale = 1.42
            building_slots = 7
            building_radius = 7.0

        if i < settlement_nodes.size():
            var house: Node3D = settlement_nodes[i]
            house.position = center
            house.rotation.y = deg_to_rad(float((i * 37) % 360))
            house.scale = Vector3.ONE * settlement_scale
            used[house] = true

        # Each settlement gets a deterministic layout based on its type:
        # villages are compact, towns form a market ring, cities form a larger
        # civic ring, and castles keep a defensive outer ring.
        for slot in range(building_slots):
            var bi = i * 3 + slot
            if bi < building_nodes.size():
                var building: Node3D = building_nodes[bi]
                var angle = TAU * float(slot) / float(maxi(building_slots, 1)) + deg_to_rad(float(i * 17))
                var radius = building_radius + float(slot % 2) * 0.9
                building.position = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
                building.rotation.y = angle + PI * 0.5
                building.scale = Vector3.ONE * (0.88 + settlement_scale * 0.08)
                used[building] = true
        for slot in range(2):
            var ci = i * 2 + slot
            var pool: Array = extra_character_nodes if slot == 1 and not extra_character_nodes.is_empty() else character_nodes
            var idx = ci if slot == 0 else i
            if idx < pool.size():
                var npc: Node3D = pool[idx]
                var angle = deg_to_rad(float(slot * 180 + i * 29))
                npc.position = center + Vector3(cos(angle) * 3.8, 0.0, sin(angle) * 3.8)
                npc.rotation.y = angle + PI
                npc.scale = Vector3.ONE * 0.92
                used[npc] = true
        if kind == "village" or kind == "town":
            var farm_radius = 7.0 if kind == "village" else 9.5
            for slot in range(4 if kind == "town" else 2):
                var fi = i * 2 + slot
                if fi < crop_nodes.size():
                    var crop: Node3D = crop_nodes[fi]
                    var angle = TAU * float(slot) / float(maxi(4 if kind == "town" else 2, 1))
                    crop.position = center + Vector3(cos(angle) * farm_radius, 0.0, sin(angle) * farm_radius)
                    crop.scale = Vector3.ONE * (0.72 if kind == "village" else 0.8)
                    used[crop] = true
            if not animal_nodes.is_empty():
                var ai = i % animal_nodes.size()
                var animal: Node3D = animal_nodes[ai]
                animal.position = center + Vector3(farm_radius * 0.65, 0.0, -farm_radius * 0.65)
                animal.scale = Vector3.ONE * 0.62
                used[animal] = true

        # Larger settlements get a broader natural buffer so the world does not
        # look like every location is sitting inside the same forest ring.
        if kind == "city" or kind == "castle":
            var buffer_count = 8 if kind == "city" else 10
            for b in range(buffer_count):
                var ni = (i * 9 + b) % max(1, nature_nodes.size())
                if ni < nature_nodes.size():
                    var tree: Node3D = nature_nodes[ni]
                    var buffer_angle = TAU * float(b) / float(buffer_count)
                    var buffer_radius = 15.0 if kind == "city" else 18.0
                    tree.position = center + Vector3(cos(buffer_angle) * buffer_radius, 0.0, sin(buffer_angle) * buffer_radius)
                    tree.scale = Vector3.ONE * (0.82 if kind == "city" else 0.9)
                    used[tree] = true
    for i in range(nature_nodes.size()):
        var tree: Node3D = nature_nodes[i]
        if used.has(tree):
            continue
        var region_id = i % max(1, settlements.size())
        var base: Vector2 = settlements[region_id].get("position", Vector2.ZERO)
        var angle = float(i) * 2.39996
        var radius = 10.0 + float(i % 8) * 2.1
        tree.position = Vector3(base.x + cos(angle) * radius, 0.0, base.y + sin(angle) * radius)
        tree.scale = Vector3.ONE * (0.7 + float(i % 4) * 0.07)
    for i in range(creature_nodes.size()):
        var creature: Node3D = creature_nodes[i]
        var region_id = (i * 3 + 4) % max(1, settlements.size())
        var base: Vector2 = settlements[region_id].get("position", Vector2.ZERO)
        var angle = float(i) * 2.73
        creature.position = Vector3(base.x + cos(angle) * 15.0, 0.0, base.y + sin(angle) * 15.0)
        creature.scale = Vector3.ONE * 0.8

    # Any unused production nodes stay far enough from the playable settlement ring
    # to act as background dressing instead of overlapping the campaign structures.
    for node in spawned:
        if not is_instance_valid(node) or used.has(node):
            continue
        if node is Node3D and (node.position.length() < 7.0):
            node.position += Vector3(35.0, 0.0, 35.0)

func _register_role(role: String, node: Node) -> void:
    if not asset_nodes_by_role.has(role):
        asset_nodes_by_role[role] = []
    asset_nodes_by_role[role].append(node)

func get_role_nodes(role: String) -> Array:
    var result: Array = []
    for node in asset_nodes_by_role.get(role, []):
        if is_instance_valid(node):
            result.append(node)
    return result

func attach_asset_to_actor(actor: Node3D, role: String = "character") -> Node3D:
    if actor == null:
        return null
    var pool = get_role_nodes(role)
    if pool.is_empty():
        return null
    var source: Node3D = pool[0] as Node3D
    if source == null:
        return null
    var copy = source.duplicate()
    actor.add_child(copy)
    copy.position = Vector3.ZERO
    return copy

func get_status() -> Dictionary:
    return {
        "spawned": spawned.size(),
        "environment": registry.get_models("medieval_village").size(),
        "buildings_extra": registry.get_models("buildings_extra").size(),
        "nature": registry.get_models("nature").size(),
        "animals": registry.get_models("animals").size(),
        "characters": registry.get_models("characters").size(),
        "characters_extra": registry.get_models("characters_extra").size(),
        "crops": registry.get_models("crops").size(),
        "creatures": registry.get_models("creatures").size()
    }
