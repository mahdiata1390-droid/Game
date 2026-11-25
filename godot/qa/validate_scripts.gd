extends SceneTree

# Headless script validation.
# The Godot editor reports parse errors but still exits with code 0, so CI could
# pass with a completely broken project. This script loads every GDScript in the
# project, instantiates the main scene's script, and exits non-zero on failure.

func _initialize() -> void:
	_run.call_deferred()

func _collect_scripts(dir_path: String, out: Array[String]) -> void:
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
			if entry != "qa":
				_collect_scripts(full, out)
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()

func _run() -> void:
	var scripts: Array[String] = []
	_collect_scripts("res://", scripts)
	scripts.sort()
	var failures: Array[String] = []
	for path in scripts:
		var script: Script = load(path)
		if script == null:
			failures.append("%s: failed to load" % path)
			continue
		if script is GDScript and not script.can_instantiate():
			failures.append("%s: script has parse or compile errors" % path)
			continue
		print("OK    %s" % path)
	print("---")
	if failures.is_empty():
		print("SCRIPT VALIDATION PASSED (%d scripts)" % scripts.size())
		quit(0)
	else:
		for failure in failures:
			printerr("SCRIPT VALIDATION FAILED: %s" % failure)
		quit(1)
