extends Node3D
class_name ReleaseProductionAssetIntegration

# Turns the downloaded production packs into actual in-world content.
# Only non-restricted visual categories are auto-instantiated here:
# medieval environment, nature, and humanoid characters.

var registry: ReleaseAssetRegistry
var spawned: Array[Node] = []

const MAX_WORLD_PROPS := 72
const MAX_NATURE := 140
const MAX_CHARACTERS := 12
const MAX_EXTRA_CHARACTERS := 18
const MAX_CREATURES := 12
const MAX_CROPS := 48

func setup(asset_registry: ReleaseAssetRegistry) -> void:
    registry = asset_registry
    call_deferred("_populate")

func _populate() -> void:
    if not is_instance_valid(registry):
        return
    _clear_previous()
    _populate_environment()
    _populate_extra_buildings()
    _populate_nature()
    _populate_animals()
    _populate_crops()
    _populate_characters()
    _populate_extra_characters()
    _populate_creatures()

func _clear_previous() -> void:
    for node in spawned:
        if is_instance_valid(node):
            node.queue_free()
    spawned.clear()

func _load_scene(path: String) -> Node:
    var resource := ResourceLoader.load(path)
    if resource == null or not resource is PackedScene:
        return null
    var instance := (resource as PackedScene).instantiate()
    if instance is Node3D:
        return instance
    instance.queue_free()
    return null

func _models(pack_id: String) -> Array:
    return registry.get_models(pack_id)

func _populate_environment() -> void:
    var models := _models("medieval_village")
    if models.is_empty():
        return
    var count := mini(models.size(), MAX_WORLD_PROPS)
    for i in range(count):
        var path: String = models[i]
        var lower := path.to_lower()
        # Skip obviously tiny/duplicate technical files.
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf") or lower.ends_with(".fbx")):
            continue
        var node := _load_scene(path)
        if node == null:
            continue
        var angle := float(i) * 0.83
        var radius := 18.0 + float(i % 9) * 7.0
        node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        node.scale = Vector3.ONE * (0.82 + float(i % 4) * 0.08)
        add_child(node)
        spawned.append(node)



func _populate_extra_buildings() -> void:
    var models := _models("buildings_extra")
    if models.is_empty():
        return
    var placed := 0
    for i in range(models.size()):
        var path: String = models[i]
        var lower := path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node := _load_scene(path)
        if node == null:
            continue
        var angle := float(i) * 1.71
        var radius := 105.0 + float(i % 7) * 12.0
        node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        node.scale = Vector3.ONE * (0.85 + float(i % 3) * 0.08)
        add_child(node)
        spawned.append(node)
        placed += 1
        if placed >= 24:
            break

func _populate_animals() -> void:
    var models := _models("animals")
    if models.is_empty():
        return
    var placed := 0
    for i in range(models.size()):
        var path: String = models[i]
        var lower := path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node := _load_scene(path)
        if node == null:
            continue
        var angle := float(i) * 2.17
        var radius := 72.0 + float(i % 8) * 5.0
        node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        node.scale = Vector3.ONE * (0.55 + float(i % 4) * 0.08)
        add_child(node)
        spawned.append(node)
        placed += 1
        if placed >= 20:
            break

func _populate_nature() -> void:
    var models := _models("nature")
    if models.is_empty():
        return
    var count := mini(models.size(), MAX_NATURE)
    var placed := 0
    for i in range(count):
        var path: String = models[i]
        var lower := path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node := _load_scene(path)
        if node == null:
            continue
        var angle := float(i) * 2.39996
        var radius := 55.0 + float(i % 13) * 6.0
        node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        node.scale = Vector3.ONE * (0.65 + float(i % 5) * 0.08)
        add_child(node)
        spawned.append(node)
        placed += 1
        if placed >= MAX_NATURE:
            break

func _populate_characters() -> void:
    var models := _models("characters")
    if models.is_empty():
        return
    var count := mini(models.size(), MAX_CHARACTERS)
    for i in range(count):
        var path: String = models[i]
        var lower := path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf")):
            continue
        var node := _load_scene(path)
        if node == null:
            continue
        var angle := float(i) * TAU / float(maxi(count, 1))
        node.position = Vector3(cos(angle) * 12.0, 0.0, sin(angle) * 12.0)
        node.scale = Vector3.ONE * 1.0
        add_child(node)
        spawned.append(node)



func _populate_crops() -> void:
    _populate_ring("crops", MAX_CROPS, 42.0, 5.5, 0.7, 2.11)

func _populate_extra_characters() -> void:
    _populate_ring("characters_extra", MAX_EXTRA_CHARACTERS, 20.0, 3.0, 1.0, 0.97)

func _populate_creatures() -> void:
    _populate_ring("creatures", MAX_CREATURES, 88.0, 8.0, 0.8, 2.73)

func _populate_ring(pack_id: String, limit: int, radius: float, spacing: float, scale_base: float, angle_step: float) -> void:
    var models := _models(pack_id)
    if models.is_empty():
        return
    var placed := 0
    for i in range(models.size()):
        var path: String = models[i]
        var lower := path.to_lower()
        if not (lower.ends_with(".glb") or lower.ends_with(".gltf") or lower.ends_with(".fbx")):
            continue
        var node := _load_scene(path)
        if node == null:
            continue
        var angle := float(i) * angle_step
        var r := radius + float(i % 7) * spacing
        node.position = Vector3(cos(angle) * r, 0.0, sin(angle) * r)
        node.scale = Vector3.ONE * (scale_base + float(i % 4) * 0.06)
        add_child(node)
        spawned.append(node)
        placed += 1
        if placed >= limit:
            break

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
