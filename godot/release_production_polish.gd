extends Node
# Final production layer: mobile controls, graphics presets, tutorial, autosave,
# performance culling and a small in-game QA/status panel.
# This layer only coordinates existing systems; WorldState remains authoritative.

var game: Node3D
var world: Node
var player: CharacterBody3D
var settings := {
	"quality": "balanced",
	"fps": 60,
	"touch_sensitivity": 1.0,
	"tutorial_seen": false,
	"autosave_minutes": 2
}
var autosave_clock := 0.0
var perf_clock := 0.0
var fps_label: Label
var qa_label: Label
var tutorial_panel: Panel
var settings_panel: Panel
var touch_layer: Control
var touch_look_start := Vector2.ZERO
var touch_look_id := -1
var hidden_nodes: Array[Node3D] = []
var base_visibility := {}
var _built := false

func _ready() -> void:
	call_deferred("_attach_to_game")

func _attach_to_game() -> void:
	if _built:
		return
	var scene := get_tree().current_scene
	if scene == null:
		call_deferred("_attach_to_game")
		return
	var root := scene as Node3D
	if root == null:
		return
	build(root)

func build(main_node: Node3D) -> void:
	if _built:
		return
	_built = true
	game = main_node
	world = game.get("world_state")
	player = game.get("player")
	_load_local_settings()
	_apply_quality()
	_build_production_ui()
	_build_touch_controls()
	_build_tutorial()
	set_process(true)

func _process(delta: float) -> void:
	if world == null or player == null:
		return
	autosave_clock += delta
	perf_clock += delta
	if autosave_clock >= float(settings["autosave_minutes"]) * 60.0:
		autosave_clock = 0.0
	_autosave()
	if perf_clock >= 1.0:
		perf_clock = 0.0
		_update_streaming_visibility()
		_update_status()

func _load_local_settings() -> void:
	var path := "user://medieval_production_settings.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		for key in settings.keys():
			if parsed.has(key):
				settings[key] = parsed[key]

func _save_local_settings() -> void:
	var file := FileAccess.open("user://medieval_production_settings.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(settings))

func _apply_quality() -> void:
	var fps := int(settings["fps"])
	Engine.max_fps = fps
	var quality := String(settings["quality"])
	var viewport := get_viewport()
	if quality == "performance":
		Engine.max_fps = min(fps, 45)
		viewport.scaling_3d_scale = 0.75
	elif quality == "quality":
		Engine.max_fps = fps
		viewport.scaling_3d_scale = 1.0
	else:
		Engine.max_fps = fps
		viewport.scaling_3d_scale = 0.88

func cycle_quality() -> void:
	var modes := ["performance", "balanced", "quality"]
	var index := modes.find(String(settings["quality"]))
	settings["quality"] = modes[(index + 1) % modes.size()]
	_apply_quality()
	_save_local_settings()
	_update_status()

func toggle_fps() -> void:
	settings["fps"] = 30 if int(settings["fps"]) >= 60 else 60
	_apply_quality()
	_save_local_settings()
	_update_status()

func _autosave() -> void:
	if world != null and world.has_method("save_game"):
		world.call("save_game")
	elif world != null and world.has_method("save"):
		world.call("save")

func manual_save() -> void:
	_autosave()
	_show_message("✓ GAME SAVED")

func manual_load() -> void:
	if world != null and world.has_method("load_game"):
		world.call("load_game")
		_show_message("✓ GAME LOADED")

func _build_production_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProductionPolishUI"
	game.add_child(layer)

	var panel := Panel.new()
	panel.name = "ProductionPanel"
	panel.position = Vector2(16, 16)
	panel.size = Vector2(245, 150)
	layer.add_child(panel)

	var title := Label.new()
	title.text = "FINAL • GAME SETTINGS"
	title.position = Vector2(12, 8)
	title.size = Vector2(220, 26)
	panel.add_child(title)

	var quality := Button.new()
	quality.text = "QUALITY"
	quality.position = Vector2(10, 38)
	quality.size = Vector2(105, 34)
	quality.pressed.connect(cycle_quality)
	panel.add_child(quality)

	var fps := Button.new()
	fps.text = "FPS 30/60"
	fps.position = Vector2(120, 38)
	fps.size = Vector2(105, 34)
	fps.pressed.connect(toggle_fps)
	panel.add_child(fps)

	var save := Button.new()
	save.text = "SAVE"
	save.position = Vector2(10, 78)
	save.size = Vector2(105, 34)
	save.pressed.connect(manual_save)
	panel.add_child(save)

	var load := Button.new()
	load.text = "LOAD"
	load.position = Vector2(120, 78)
	load.size = Vector2(105, 34)
	load.pressed.connect(manual_load)
	panel.add_child(load)

	qa_label = Label.new()
	qa_label.position = Vector2(10, 118)
	qa_label.size = Vector2(225, 28)
	panel.add_child(qa_label)

	fps_label = Label.new()
	fps_label.position = Vector2(16, 172)
	fps_label.size = Vector2(300, 26)
	layer.add_child(fps_label)

func _update_status() -> void:
	if fps_label != null:
		fps_label.text = "FPS %d • %s • Autosave %ds" % [
			int(Engine.get_frames_per_second()),
			String(settings["quality"]).to_upper(),
			max(0, int(float(settings["autosave_minutes"]) * 60.0 - autosave_clock))
		]
	if qa_label != null and game != null:
		var final_layer = game.get("final_completion")
		if is_instance_valid(final_layer) and final_layer.has_method("run_qa"):
			var result: Dictionary = final_layer.run_qa()
			qa_label.text = "QA %d checks • %d errors" % [
				int(result.get("checks", 0)),
				int(result.get("errors", 0))
			]

func _build_touch_controls() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	touch_layer = Control.new()
	touch_layer.name = "FinalTouchControls"
	touch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(touch_layer)

	var hint := Label.new()
	hint.text = "DRAG RIGHT SIDE • LOOK"
	hint.position = Vector2(0, 0)
	hint.anchor_left = 0.62
	hint.anchor_top = 0.88
	hint.anchor_right = 0.98
	hint.anchor_bottom = 0.98
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.55
	touch_layer.add_child(hint)

	touch_layer.gui_input.connect(_on_touch_input)

func _on_touch_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.58:
			touch_look_id = event.index
			touch_look_start = event.position
		elif not event.pressed and event.index == touch_look_id:
			touch_look_id = -1
	elif event is InputEventScreenDrag and event.index == touch_look_id:
		if player == null:
			return
		var delta: Vector2 = event.relative * 0.0035 * float(settings["touch_sensitivity"])
		player.rotate_y(-delta.x)
		if game.get("camera") != null:
			var cam: Camera3D = game.get("camera")
			cam.rotation_degrees.x = clamp(cam.rotation_degrees.x - delta.y * 45.0, -70.0, 55.0)

func _build_tutorial() -> void:
	if bool(settings["tutorial_seen"]):
		return
	tutorial_panel = Panel.new()
	tutorial_panel.name = "FinalTutorial"
	tutorial_panel.position = Vector2(0, 0)
	tutorial_panel.size = Vector2(360, 220)
	tutorial_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var title := Label.new()
	title.text = "MEDIEVAL SANDBOX"
	title.position = Vector2(22, 18)
	title.size = Vector2(315, 32)
	tutorial_panel.add_child(title)
	var body := Label.new()
	body.text = "Explore freely.\nAttack • recruit • trade • command armies\nSiege settlements • sail • negotiate • build your house\nThere is no forced main quest."
	body.position = Vector2(22, 58)
	body.size = Vector2(315, 90)
	tutorial_panel.add_child(body)
	var close := Button.new()
	close.text = "START SANDBOX"
	close.position = Vector2(22, 162)
	close.size = Vector2(315, 38)
	close.pressed.connect(_close_tutorial)
	tutorial_panel.add_child(close)
	var layer := CanvasLayer.new()
	layer.name = "FinalTutorialLayer"
	game.add_child(layer)
	layer.add_child(tutorial_panel)

func _close_tutorial() -> void:
	settings["tutorial_seen"] = true
	_save_local_settings()
	if is_instance_valid(tutorial_panel):
		tutorial_panel.queue_free()

func _update_streaming_visibility() -> void:
	if player == null:
		return
	var distance_limit := 70.0
	match String(settings["quality"]):
		"performance":
			distance_limit = 48.0
		"balanced":
			distance_limit = 70.0
		"quality":
			distance_limit = 105.0
	for child in game.get_children():
		var node: Node3D = child as Node3D
		if node == null or node == player or node == game:
			continue
		if child is Camera3D or child is WorldEnvironment or child is DirectionalLight3D:
			continue
		if not (node is MeshInstance3D or node.get_child_count() > 0):
			continue
		var distance := player.global_position.distance_to(node.global_position)
		if distance > distance_limit and not node.has_meta("always_visible"):
			node.visible = false
		elif node.visible == false and distance <= distance_limit:
			node.visible = true

func _show_message(message: String) -> void:
	var label := game.get_node_or_null("StatusLabel") as Label
	if label != null:
		label.text = message

func get_save_state() -> Dictionary:
	return {"settings": settings.duplicate(true)}

func load_save_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	var incoming = data.get("settings", {})
	if incoming is Dictionary:
		for key in settings.keys():
			if incoming.has(key):
				settings[key] = incoming[key]
	_apply_quality()
	_save_local_settings()
