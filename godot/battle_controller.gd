extends Node

var world_state: WorldState
var main_scene: Node
var battle_settlement_id := -1
var battle_active := false
var first_person := false
var prompt: Panel
var result_panel: Panel
var title_label: Label
var report_label: Label
var mode_label: Label
var prompt_shown := false
var siege_active := false
var siege_panel: Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(_delta: float) -> void:
	if not main_scene:
		main_scene = get_tree().current_scene
	if not world_state and main_scene:
		world_state = main_scene.get_node_or_null("WorldState") as WorldState
	if not main_scene or not world_state:
		return
	if not battle_active and not prompt_shown and not siege_active:
		_check_for_encounter()

func _check_for_encounter() -> void:
	if world_state.player_region_id < 0:
		return
	for i in range(world_state.settlements.size()):
		var s: Dictionary = world_state.settlements[i]
		if int(s["region"]) != world_state.player_region_id:
			continue
		if String(s["owner"]) == world_state.player_faction:
			continue
		_show_battle_prompt(i)
		return

func _ensure_layer() -> CanvasLayer:
	var layer := main_scene.get_node_or_null("BattleUI") as CanvasLayer
	if layer:
		return layer
	layer = CanvasLayer.new()
	layer.name = "BattleUI"
	main_scene.add_child(layer)
	return layer

func _show_battle_prompt(settlement_id: int) -> void:
	prompt_shown = true
	battle_settlement_id = settlement_id
	var layer := _ensure_layer()
	prompt = Panel.new()
	prompt.position = Vector2(330, 160)
	prompt.size = Vector2(620, 460)
	layer.add_child(prompt)
	var title := Label.new()
	title.text = "⚔ BATTLE AT %s" % world_state.settlements[settlement_id]["name"]
	title.position = Vector2(28, 22)
	title.add_theme_font_size_override("font_size", 28)
	prompt.add_child(title)
	var info := Label.new()
	info.text = "A hostile force controls this settlement.\nChoose how you want this battle to be resolved."
	info.position = Vector2(30, 75)
	info.add_theme_font_size_override("font_size", 18)
	prompt.add_child(info)
	var third := Button.new()
	third.text = "THIRD PERSON • FIGHT"
	third.position = Vector2(35, 145)
	third.size = Vector2(255, 70)
	third.pressed.connect(func(): _start_manual(false))
	prompt.add_child(third)
	var first := Button.new()
	first.text = "FIRST PERSON • FIGHT"
	first.position = Vector2(330, 145)
	first.size = Vector2(255, 70)
	first.pressed.connect(func(): _start_manual(true))
	prompt.add_child(first)
	var auto := Button.new()
	auto.text = "AUTO BATTLE • SIMULATE"
	auto.position = Vector2(35, 235)
	auto.size = Vector2(550, 70)
	auto.pressed.connect(_start_auto)
	prompt.add_child(auto)
	var cancel := Button.new()
	cancel.text = "LEAVE / WAIT"
	var siege := Button.new()
	siege.text = "SIEGE • BEGIN / CONTINUE"
	siege.position = Vector2(35, 320)
	siege.size = Vector2(550, 60)
	siege.pressed.connect(_begin_siege)
	prompt.add_child(siege)
	cancel.position = Vector2(200, 395)
	cancel.size = Vector2(220, 45)
	cancel.pressed.connect(_leave_prompt)
	prompt.add_child(cancel)

func _begin_siege() -> void:
	if is_instance_valid(prompt): prompt.queue_free()
	prompt=null
	var army_id:=-1
	for i in range(world_state.armies.size()):
		if String(world_state.armies[i]["owner"])==world_state.player_faction and int(world_state.armies[i]["region"])==world_state.player_region_id:
			army_id=i; break
	if army_id<0:
		_show_simple_message("No player army is present in this region.")
		prompt_shown=false
		return
	var result:=world_state.start_siege(battle_settlement_id,army_id)
	if not result.get("ok",false):
		_show_simple_message("SIEGE FAILED • "+String(result.get("reason","unknown")))
		prompt_shown=false
		return
	siege_active=true
	if main_scene.has_method("create_siege_visual"):
		main_scene.create_siege_visual(String(world_state.settlements[battle_settlement_id]["name"]), int(world_state.settlements[battle_settlement_id].get("wall_level",1)))
	_show_siege_panel()

func _show_siege_panel()->void:
	_close_siege_panel()
	var layer:=_ensure_layer()
	siege_panel=Panel.new(); siege_panel.position=Vector2(300,90); siege_panel.size=Vector2(640,470); layer.add_child(siege_panel)
	var title:=Label.new(); title.text="SIEGE • "+String(world_state.settlements[battle_settlement_id]["name"]); title.position=Vector2(25,20); title.add_theme_font_size_override("font_size",26); siege_panel.add_child(title)
	var s:=world_state.settlements[battle_settlement_id]; var data:=world_state.sieges.get(battle_settlement_id,{})
	var info:=Label.new(); info.text="Wall: %d\nGarrison: %d\nSiege progress: %d%%\nPhase: %s\nGate: %d HP\nWall integrity: %d HP\nBreach: %s" % [int(s.get("wall_level",1)),int(s["garrison"]),int(data.get("progress",0)),String(data.get("phase","approach")),int(data.get("gate_hp",120)),int(data.get("wall_hp",int(s.get("wall_level",1))*100)),("YES" if bool(data.get("breach",false)) else "NO")]; info.position=Vector2(25,75); info.add_theme_font_size_override("font_size",18); siege_panel.add_child(info)
	var assault:=Button.new(); assault.text="ASSAULT THE WALLS"; assault.position=Vector2(25,285); assault.size=Vector2(275,60); assault.pressed.connect(_assault_siege); siege_panel.add_child(assault)
	var wait:=Button.new(); wait.text="WAIT • +1 DAY"; wait.position=Vector2(325,285); wait.size=Vector2(275,60); wait.pressed.connect(_wait_siege); siege_panel.add_child(wait)
	var end:=Button.new(); end.text="END SIEGE"; end.position=Vector2(220,385); end.size=Vector2(200,45); end.pressed.connect(_end_siege); siege_panel.add_child(end)

func _assault_siege()->void:
	var result:=world_state.assault_siege(battle_settlement_id)
	var siege_data:Dictionary=world_state.sieges.get(battle_settlement_id,{})
	if main_scene.has_method("update_siege_visual"):
		main_scene.update_siege_visual(int(result.get("progress",0)),bool(result.get("gate_breached",siege_data.get("gate_breached",false))),int(result.get("gate_hp",siege_data.get("gate_hp",120))),int(result.get("wall_hp",siege_data.get("wall_hp",500))))
	if bool(result.get("captured",false)):
		siege_active=false
		if main_scene.has_method("clear_siege_visual"): main_scene.clear_siege_visual()
		_close_siege_panel(); _show_result({"attacker_won":true,"captured":true,"attacker_losses":result["attacker_losses"],"defender_losses":result["defender_losses"],"rounds":["The walls were breached.","The garrison was defeated.","The settlement was captured."],"settlement":String(world_state.settlements[battle_settlement_id]["name"])}); prompt_shown=false
	else:
		_show_siege_panel()

func _wait_siege()->void:
	world_state.advance_day()
	var data:Dictionary=world_state.sieges.get(battle_settlement_id,{})
	if main_scene.has_method("update_siege_visual") and not data.is_empty():
		main_scene.update_siege_visual(int(data.get("progress",0)),bool(data.get("gate_breached",false)),int(data.get("gate_hp",120)),int(data.get("wall_hp",500)))
	_show_siege_panel()

func _end_siege()->void:
	if main_scene.has_method("clear_siege_visual"): main_scene.clear_siege_visual()
	if world_state.sieges.has(battle_settlement_id):
		world_state.sieges.erase(battle_settlement_id)
	world_state.settlements[battle_settlement_id]["siege"]=false
	siege_active=false; _close_siege_panel(); prompt_shown=false

func _close_siege_panel()->void:
	if is_instance_valid(siege_panel): siege_panel.queue_free()
	siege_panel=null

func _show_simple_message(message:String)->void:
	var layer:=_ensure_layer(); var p:=Panel.new(); p.position=Vector2(350,220); p.size=Vector2(540,180); layer.add_child(p)
	var l:=Label.new(); l.text=message; l.position=Vector2(25,25); l.size=Vector2(490,80); l.add_theme_font_size_override("font_size",20); p.add_child(l)
	var b:=Button.new(); b.text="OK"; b.position=Vector2(210,120); b.size=Vector2(120,35); b.pressed.connect(p.queue_free); p.add_child(b)

func _leave_prompt() -> void:
	if is_instance_valid(prompt):
		prompt.queue_free()
	prompt = null
	prompt_shown = false

func _start_manual(use_first_person: bool) -> void:
	if is_instance_valid(prompt):
		prompt.queue_free()
	prompt = null
	battle_active = true
	first_person = use_first_person
	var attacker := world_state.get_player_battle_force()
	var defender := world_state.get_settlement_defender(battle_settlement_id)
	if main_scene.has_method("prepare_battle"):
		main_scene.prepare_battle(attacker, defender)
	main_scene.set("camera_first_person", first_person)
	mode_label = Label.new()
	mode_label.text = "MANUAL BATTLE • %s" % ("FIRST PERSON" if first_person else "THIRD PERSON")
	mode_label.position = Vector2(28, 140)
	mode_label.add_theme_font_size_override("font_size", 20)
	_ensure_layer().add_child(mode_label)
	var finish := Button.new()
	finish.name = "FinishBattle"
	finish.text = "BATTLE RESULT"
	finish.position = Vector2(1020, 600)
	finish.size = Vector2(210, 60)
	finish.pressed.connect(_finish_manual)
	_ensure_layer().add_child(finish)
	_set_camera_mode(first_person)

func _set_camera_mode(use_first: bool) -> void:
	var camera := main_scene.get("camera") as Camera3D
	if not camera:
		return
	main_scene.set("camera_first_person", use_first)
	if use_first:
		camera.position = Vector3(0, 1.55, 0.15)
		camera.rotation_degrees = Vector3(0, 0, 0)
	else:
		camera.position = Vector3(0, 4.2, 7.5)
		camera.rotation_degrees = Vector3(-12, 0, 0)

func _start_auto() -> void:
	var attacker := world_state.get_player_battle_force()
	var defender := world_state.get_settlement_defender(battle_settlement_id)
	var result: Dictionary = world_state.resolve_auto_battle(battle_settlement_id, attacker, defender)
	if is_instance_valid(prompt):
		prompt.queue_free()
	prompt = null
	battle_active = false
	_show_result(result)
	prompt_shown = false

func _finish_manual() -> void:
	# The live troop combat in main.gd is the manual simulation. This commits
	# the outcome to the same world-state conquest path used by auto battle.
	var casualties := {"attacker": 0, "defender": 0, "attacker_types": {}, "defender_types": {}}
	if main_scene.has_method("get_battle_casualties"):
		casualties = main_scene.get_battle_casualties()
	var remaining := {"attacker": 0, "defender": 0}
	if main_scene.has_method("get_battle_remaining"):
		remaining = main_scene.get_battle_remaining()
	var won := int(remaining.get("defender", 0)) <= 0 and int(remaining.get("attacker", 0)) > 0
	var attacker_losses := int(casualties.get("attacker", 0))
	var defender_losses := int(casualties.get("defender", 0))
	var result: Dictionary
	if main_scene.has_method("get_battle_remaining") and int(remaining.get("attacker", 0)) <= 0:
		won = false
	if won:
		result = world_state.apply_manual_battle_result(battle_settlement_id, attacker_losses, defender_losses, casualties.get("attacker_types", {}), casualties.get("defender_types", {}), true)
		result["attacker_won"] = true
		result["rounds"] = ["Your troops broke the enemy line.","The remaining defenders abandoned the position.","The settlement was secured."]
	else:
		result = world_state.apply_manual_battle_result(battle_settlement_id, attacker_losses, defender_losses, casualties.get("attacker_types", {}), casualties.get("defender_types", {}), false)
		result["attacker_won"] = false
		result["captured"] = false
		result["rounds"] = ["Your forces could not clear the defenders.","The battle was halted before a decisive breakthrough.","The settlement remains in enemy hands."]
	battle_active = false
	_set_camera_mode(false)
	_show_result(result)
	var finish := _ensure_layer().get_node_or_null("FinishBattle")
	if finish:
		finish.queue_free()
	if mode_label:
		mode_label.queue_free()
	mode_label = null
	prompt_shown = false

func _show_result(result: Dictionary) -> void:
	var layer := _ensure_layer()
	result_panel = Panel.new()
	result_panel.position = Vector2(270, 100)
	result_panel.size = Vector2(740, 520)
	layer.add_child(result_panel)
	title_label = Label.new()
	title_label.text = ("VICTORY" if bool(result.get("attacker_won",false)) else "DEFEAT") + " • " + String(result.get("settlement","Battle"))
	title_label.position = Vector2(30, 25)
	title_label.add_theme_font_size_override("font_size", 30)
	result_panel.add_child(title_label)
	report_label = Label.new()
	report_label.position = Vector2(32, 85)
	report_label.size = Vector2(675, 330)
	report_label.add_theme_font_size_override("font_size", 18)
	var lines: Array[String] = []
	lines.append("Attacker losses: %d" % int(result.get("attacker_losses",0)))
	lines.append("Defender losses: %d" % int(result.get("defender_losses",0)))
	lines.append("Settlement captured: %s" % ("YES" if bool(result.get("captured",false)) else "NO"))
	lines.append("")
	for event in result.get("rounds",[]):
		lines.append("• " + String(event))
	report_label.text = "\n".join(lines)
	result_panel.add_child(report_label)
	var close := Button.new()
	close.text = "CONTINUE"
	close.position = Vector2(260, 445)
	close.size = Vector2(220, 48)
	close.pressed.connect(_close_result)
	result_panel.add_child(close)

func _close_result() -> void:
	if is_instance_valid(result_panel):
		result_panel.queue_free()
	result_panel = null
	prompt_shown = false
