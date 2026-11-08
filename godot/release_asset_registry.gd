extends Node3D
class_name ReleaseAssetRegistry

# Production asset registry for the medieval sandbox.
# External art is intentionally kept in named packs so the runtime never
# hard-depends on a single vendor or a placeholder mesh.
#
# Recommended CC0 sources:
# - Quaternius Medieval Village MegaKit: 300+ textured modular medieval environment models.
# - Quaternius Stylized Nature MegaKit: 116 textured trees/plants/rocks.
# - Quaternius Universal Base Characters: 6 rigged humanoid bases + hairstyles.
#
# The project accepts glTF/GLB/OBJ/FBX assets under res://assets/production/.
# When a pack is present, this registry exposes it to the world builder.

const ROOT := "res://assets/production"

const PACKS := {
	"medieval_village": {
		"path": ROOT + "/medieval_village",
		"license": "CC0-1.0",
		"source": "Quaternius Medieval Village MegaKit",
		"source_url": "https://quaternius.itch.io/medieval-village-megakit"
	},
	"nature": {
		"path": ROOT + "/nature",
		"license": "CC0-1.0",
		"source": "Quaternius Stylized Nature MegaKit",
		"source_url": "https://quaternius.itch.io/stylized-nature-megakit"
	},
	"characters": {
		"path": ROOT + "/characters",
		"license": "CC0-1.0",
		"source": "Quaternius Universal Base Characters",
		"source_url": "https://quaternius.itch.io/universal-base-characters"
	},
	"buildings_extra": {
		"path": ROOT + "/buildings_extra",
		"license": "CC0-1.0",
		"source": "Quaternius Modular Medieval Pack",
		"source_url": "https://opengameart.org/"
	},
	"characters_extra": {
		"path": ROOT + "/characters_extra",
		"license": "CC0-1.0",
		"source": "Quaternius Ultimate Animated Character Pack",
		"source_url": "https://opengameart.org/"
	},
	"animals": {
		"path": ROOT + "/animals",
		"license": "CC0-1.0",
		"source": "Quaternius Farm Animals Pack",
		"source_url": "https://opengameart.org/"
	},
	"crops": {
		"path": ROOT + "/crops",
		"license": "CC0-1.0",
		"source": "Quaternius Nature Crops Pack",
		"source_url": "https://opengameart.org/"
	},
	"creatures": {
		"path": ROOT + "/creatures",
		"license": "CC0-1.0",
		"source": "Quaternius Animated Monster Pack",
		"source_url": "https://opengameart.org/"
	}
}

var available: Dictionary = {}

func _ready() -> void:
	scan()

func scan() -> void:
	available.clear()
	for pack_id in PACKS:
		var pack: Dictionary = PACKS[pack_id]
		var files: Array[String] = []
		_collect_models(String(pack["path"]), files)
		available[pack_id] = files

func _collect_models(path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if item.begins_with("."):
			item = dir.get_next()
			continue
		var full := path.path_join(item)
		if dir.current_is_dir():
			_collect_models(full, out)
		else:
			var lower := item.to_lower()
			if lower.ends_with(".glb") or lower.ends_with(".gltf"):
				out.append(full)
		item = dir.get_next()
	dir.list_dir_end()

func has_pack(pack_id: String) -> bool:
	return available.has(pack_id) and not available[pack_id].is_empty()

func get_models(pack_id: String) -> Array:
	return available.get(pack_id, [])

func get_status() -> Dictionary:
	var result := {}
	for pack_id in PACKS:
		result[pack_id] = {
			"present": has_pack(pack_id),
			"models": get_models(pack_id).size(),
			"source": PACKS[pack_id]["source"],
			"license": PACKS[pack_id]["license"]
		}
	return result
