extends SceneTree

# Writes res://assets/production/manifest.json listing every production model.
#
# Exported builds contain the imported .scn of each model, not the raw .glb, so
# scanning the directory at runtime finds nothing inside an APK. The manifest is
# generated before export and read by ReleaseAssetRegistry instead.
#
# Usage: godot --headless --path godot --script res://qa/generate_asset_manifest.gd

const ROOT := "res://assets/production"
const MANIFEST := ROOT + "/manifest.json"
const PACK_IDS := [
	"medieval_village", "nature", "characters", "buildings_extra",
	"characters_extra", "animals", "crops", "creatures"
]

func _initialize() -> void:
	_run.call_deferred()

func _collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var full := dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect(full, out)
		else:
			var lower := entry.to_lower()
			if lower.ends_with(".glb") or lower.ends_with(".gltf"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _run() -> void:
	var manifest: Dictionary = {}
	var total := 0
	for pack_id in PACK_IDS:
		var files: Array[String] = []
		_collect(ROOT.path_join(pack_id), files)
		files.sort()
		manifest[pack_id] = files
		total += files.size()
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	if file == null:
		printerr("ASSET_MANIFEST_FAILED: cannot write %s" % MANIFEST)
		quit(1)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("ASSET_MANIFEST_WRITTEN models=%d path=%s" % [total, MANIFEST])
	if total == 0:
		print("ASSET_MANIFEST_EMPTY: no production models installed, the game will use authored geometry")
	quit(0)
