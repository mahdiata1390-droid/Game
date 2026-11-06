extends Node
class_name ReleaseWorldLifeMobile

## Completion pass for systems 6-9:
## world/character content, player sandbox life, robust saves, and mobile UX/performance.
## Uses the existing campaign data and visuals instead of replacing them.

var host: Node
var world: WorldState
var layer: CanvasLayer
var panel: Panel
var label: Label
var slot_option: OptionButton
var autosave_clock := 0.0
var content_clock := 0.0
var autosave_enabled := true
var mobile_mode := true
var save_slot := 1
var state: Dictionary = {
	"world_content_pass": 1,
	"npc_refreshes": 0,
	"settlement_upgrades_applied": 0,
	"days_as_ruler": 0,
	"save_slots_used": 0,
	"autosaves": 0,
	"mobile_quality": "balanced"
}

func build(main: Node) -> void:
	host = main
	world = main.world_state
	_apply_world_content()
	_build_ui()
	_apply_mobile_profile()

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	autosave_clock += delta
	content_clock += delta
	if content_clock >= 8.0:
		content_clock = 0.0
		_apply_world_content()
	if autosave_enabled and autosave_clock >= 90.0:
		autosave_clock = 0.0
		_autosave()
	_update_label()

# ---------- 6. WORLD + CHARACTER CONTENT ----------

func _apply_world_content() -> void:
	if world.settlements.is_empty(): return
	for settlement in world.settlements:
		var kind := String(settlement.get("type","village"))
		var buildings: Dictionary = settlement.get("buildings",{})
		var level := int(settlement.get("wall_level",1))
		settlement["visual_tier"] = clamp(level + int(buildings.get("market",1))/2,1,8)
		settlement["interior_seed"] = int(settlement.get("id",0))*7919 + int(settlement.get("population",0))
		settlement["services"] = _services_for(kind,buildings)
		settlement["npc_capacity"] = clamp(int(settlement.get("population",100))/90,3,28)
		settlement["market_open"] = int(settlement.get("prosperity",50)) > 10
		settlement["training_available"] = int(buildings.get("barracks",1)) > 0
		state["settlement_upgrades_applied"] = int(state["settlement_upgrades_applied"]) + 1
	state["npc_refreshes"] = int(state["npc_refreshes"]) + 1
	_refresh_equipment_visuals()

func _services_for(kind:String, buildings:Dictionary) -> Array[String]:
	var result:Array[String] = ["well","inn"]
	if kind == "city": result += ["market","guild","tavern","blacksmith"]
	elif kind == "town": result += ["market","tavern","blacksmith"]
	elif kind == "castle": result += ["barracks","keep","armory"]
	else: result += ["farm","market"]
	if int(buildings.get("workshop",1)) >= 2: result.append("master_workshop")
	if int(buildings.get("barracks",1)) >= 2: result.append("training_yard")
	return result

func _refresh_equipment_visuals() -> void:
	if not is_instance_valid(host.player): return
	var eq:Dictionary = world.player_equipment
	var body:=host.player.get_node_or_null("Body") as MeshInstance3D
	if is_instance_valid(body):
		var material:=StandardMaterial3D.new()
		material.albedo_color = Color(0.18,0.28,0.42)
		if String(eq.get("armor","")) == "plate_armor":
			material.albedo_color = Color(0.48,0.50,0.54)
		elif String(eq.get("armor","")) == "chain_armor":
			material.albedo_color = Color(0.30,0.34,0.38)
		body.material_override=material
	_apply_weapon_visual(String(eq.get("weapon","iron_sword")))

func _apply_weapon_visual(weapon:String) -> void:
	var weapon_node:=host.player.get_node_or_null("Body/Sword") as Node3D
	if is_instance_valid(weapon_node):
		weapon_node.scale=Vector3(1.0,1.0,1.25 if weapon in ["steel_sword","spear","axe"] else 1.0)

# ---------- 7. PLAYER LIFE / SANDBOX CAREER ----------

func set_career(mode:String) -> Dictionary:
	var result:=world.set_player_mode(mode)
	if not bool(result.get("ok",false)): return result
	if mode=="ordinary":
		world.player_inventory["food"]=max(30,int(world.player_inventory.get("food",0)))
		world.world_events.append("The player lives as an independent adventurer.")
	elif mode=="king":
		world.world_events.append("The player now rules as a king.")
	elif mode=="tribal_leader":
		world.world_events.append("The player leads a nomadic tribal faction.")
	return result

func advance_campaign_day() -> void:
	var before:=world.day
	world.advance_day()
	var elapsed:=max(0,world.day-before)
	if world.player_mode in ["king","tribal_leader"]:
		state["days_as_ruler"]=int(state["days_as_ruler"])+elapsed
	_update_family_status()

func _update_family_status() -> void:
	if world.family_members.is_empty() and int(world.family.get("heir_age",0)) > 0:
		world.family_members.append({"name":String(world.family.get("heir_name","Unnamed Heir")),"age":int(world.family.get("heir_age",0)),"role":"heir","loyalty":60,"generation":int(world.family.get("generation",1))+1})
	if not world.family_members.is_empty():
		var best_index:=0
		for i in range(world.family_members.size()):
			var m:Dictionary=world.family_members[i]
			m["age"]=int(m.get("age",0))+1 if world.day%365==0 else int(m.get("age",0))
			m["loyalty"]=clamp(int(m.get("loyalty",60))+randi_range(-1,2),0,100)
			world.family_members[i]=m
			if String(m.get("role",""))=="heir": best_index=i
		world.family["heir_name"]=String(world.family_members[best_index].get("name","Unnamed Heir"))
		world.family["heir_age"]=int(world.family_members[best_index].get("age",0))

func recruit_and_upgrade(settlement_id:int, building:String) -> Dictionary:
	return world.upgrade_settlement_building(settlement_id,building)

func _career_text() -> String:
	var f:=world.family
	return "Career: %s\nLevel %d • XP %d\nGold %d • Day %d\nHeir: %s (age %d)\nFamily: %d" % [
		String(world.player_mode),int(world.player_level),int(world.player_xp),int(world.gold),int(world.day),
		String(f.get("heir_name","Unnamed Heir")),int(f.get("heir_age",0)),world.family_members.size()
	]

# ---------- 8. SAVE SLOTS / RECOVERY ----------

func _slot_path(slot:int) -> String:
	return "user://medieval_sandbox_slot_%d.json" % clamp(slot,1,3)

func save_slot_now(slot:int=save_slot) -> Dictionary:
	slot=clamp(slot,1,3)
	var old_path:=world.save_path
	world.save_path=_slot_path(slot)
	var ok:=world.save_game()
	world.save_path=old_path
	if ok:
		save_slot=slot
		state["save_slots_used"]=int(state["save_slots_used"])+1
	return {"ok":ok,"slot":slot,"path":_slot_path(slot)}

func load_slot_now(slot:int=save_slot) -> Dictionary:
	slot=clamp(slot,1,3)
	var path:=_slot_path(slot)
	if not FileAccess.file_exists(path):
		return {"ok":false,"reason":"empty_slot","slot":slot}
	var file:=FileAccess.open(path,FileAccess.READ)
	if file==null: return {"ok":false,"reason":"open_failed","slot":slot}
	var raw:=file.get_as_text()
	file.close()
	var parsed=JSON.parse_string(raw)
	if typeof(parsed)!=TYPE_DICTIONARY:
		# Keep the active campaign untouched if a slot is corrupted.
		world.world_events.append("Save slot %d is corrupted and was rejected." % slot)
		return {"ok":false,"reason":"corrupt_save","slot":slot}
	var old_path:=world.save_path
	world.save_path=path
	var ok:=world.load_game()
	world.save_path=old_path
	if ok:
		save_slot=slot
	return {"ok":ok,"slot":slot}

func _autosave() -> void:
	var result:=save_slot_now(save_slot)
	if bool(result.get("ok",false)):
		state["autosaves"]=int(state["autosaves"])+1

func toggle_autosave() -> void:
	autosave_enabled=not autosave_enabled
	_update_label()

# ---------- 9. MOBILE ----------

func _apply_mobile_profile() -> void:
	mobile_mode = OS.has_feature("mobile") or DisplayServer.window_get_size().x <= 1100
	# Keep a stable frame budget on phones without changing desktop quality.
	Engine.max_fps = 60
	state["mobile_quality"]="balanced"
	if mobile_mode:
		Engine.max_fps=45

func set_mobile_quality(profile:String) -> void:
	if profile not in ["battery","balanced","quality"]: return
	state["mobile_quality"]=profile
	match profile:
		"battery": Engine.max_fps=30
		"balanced": Engine.max_fps=45
		"quality": Engine.max_fps=60
	_apply_lod_profile(profile)

func _apply_lod_profile(profile:String) -> void:
	var distance:=70.0
	if profile=="battery": distance=48.0
	elif profile=="quality": distance=105.0
	if not is_instance_valid(host.player): return
	for node in host.get_tree().get_nodes_in_group("mobile_lod"):
		if not is_instance_valid(node): continue
		var n:=node as Node3D
		if is_instance_valid(n):
			n.visible=host.player.global_position.distance_to(n.global_position)<=distance

func _build_ui() -> void:
	layer=CanvasLayer.new()
	layer.name="WorldLifeSaveMobileUI"
	host.add_child(layer)
	var button:=Button.new()
	button.text="WORLD / SAVE"
	button.position=Vector2(1010,615)
	button.size=Vector2(190,42)
	button.pressed.connect(_toggle)
	layer.add_child(button)
	panel=Panel.new()
	panel.position=Vector2(250,70)
	panel.size=Vector2(740,590)
	panel.visible=false
	layer.add_child(panel)
	var title:=Label.new()
	title.text="WORLD • LIFE • SAVE • MOBILE"
	title.position=Vector2(24,18)
	title.add_theme_font_size_override("font_size",24)
	panel.add_child(title)
	label=Label.new()
	label.position=Vector2(24,58)
	label.size=Vector2(690,150)
	label.add_theme_font_size_override("font_size",17)
	panel.add_child(label)
	slot_option=OptionButton.new()
	for i in range(1,4): slot_option.add_item("SAVE SLOT %d"%i)
	slot_option.position=Vector2(24,220)
	slot_option.size=Vector2(210,44)
	panel.add_child(slot_option)
	var save:=Button.new()
	save.text="SAVE"
	save.position=Vector2(250,220)
	save.size=Vector2(120,44)
	save.pressed.connect(func(): save_slot_now(slot_option.selected+1))
	panel.add_child(save)
	var load:=Button.new()
	load.text="LOAD"
	load.position=Vector2(380,220)
	load.size=Vector2(120,44)
	load.pressed.connect(func(): load_slot_now(slot_option.selected+1))
	panel.add_child(load)
	var auto:=Button.new()
	auto.text="AUTOSAVE ON/OFF"
	auto.position=Vector2(510,220)
	auto.size=Vector2(180,44)
	auto.pressed.connect(toggle_autosave)
	panel.add_child(auto)
	var battery:=Button.new()
	battery.text="BATTERY"
	battery.position=Vector2(24,285)
	battery.size=Vector2(150,44)
	battery.pressed.connect(func(): set_mobile_quality("battery"))
	panel.add_child(battery)
	var balanced:=Button.new()
	balanced.text="BALANCED"
	balanced.position=Vector2(185,285)
	balanced.size=Vector2(150,44)
	balanced.pressed.connect(func(): set_mobile_quality("balanced"))
	panel.add_child(balanced)
	var quality:=Button.new()
	quality.text="QUALITY"
	quality.position=Vector2(346,285)
	quality.size=Vector2(150,44)
	quality.pressed.connect(func(): set_mobile_quality("quality"))
	panel.add_child(quality)
	var career:=Button.new()
	career.text="ORDINARY"
	career.position=Vector2(24,350)
	career.size=Vector2(150,44)
	career.pressed.connect(func(): set_career("ordinary"))
	panel.add_child(career)
	var king:=Button.new()
	king.text="KING"
	king.position=Vector2(185,350)
	king.size=Vector2(150,44)
	king.pressed.connect(func(): set_career("king"))
	panel.add_child(king)
	var tribal:=Button.new()
	tribal.text="TRIBAL LEADER"
	tribal.position=Vector2(346,350)
	tribal.size=Vector2(170,44)
	tribal.pressed.connect(func(): set_career("tribal_leader"))
	panel.add_child(tribal)
	var day:=Button.new()
	day.text="NEXT DAY"
	day.position=Vector2(24,420)
	day.size=Vector2(200,48)
	day.pressed.connect(advance_campaign_day)
	panel.add_child(day)
	var refresh:=Button.new()
	refresh.text="REFRESH WORLD"
	refresh.position=Vector2(240,420)
	refresh.size=Vector2(200,48)
	refresh.pressed.connect(_apply_world_content)
	panel.add_child(refresh)
	var close:=Button.new()
	close.text="CLOSE"
	close.position=Vector2(500,500)
	close.size=Vector2(190,42)
	close.pressed.connect(_toggle)
	panel.add_child(close)
	_update_label()

func _update_label() -> void:
	if not is_instance_valid(label) or not is_instance_valid(world): return
	label.text=_career_text()+"\n\nSettlements: %d • Armies: %d • Ships: %d\nWorld content tier: %d • Autosave: %s\nMobile profile: %s • FPS cap: %d" % [
		world.settlements.size(),world.armies.size(),world.ships.size(),int(state["world_content_pass"]),
		"ON" if autosave_enabled else "OFF",String(state["mobile_quality"]),Engine.max_fps
	]

func _toggle() -> void:
	panel.visible=not panel.visible
	_update_label()

func get_save_state() -> Dictionary:
	return {"state":state.duplicate(true),"autosave_enabled":autosave_enabled,"save_slot":save_slot,"mobile_mode":mobile_mode}

func load_save_state(data:Dictionary) -> void:
	state=data.get("state",state).duplicate(true)
	autosave_enabled=bool(data.get("autosave_enabled",true))
	save_slot=int(data.get("save_slot",1))
	mobile_mode=bool(data.get("mobile_mode",mobile_mode))
	_apply_mobile_profile()
	_update_label()
