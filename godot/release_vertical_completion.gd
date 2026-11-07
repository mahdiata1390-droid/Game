extends Node
class_name ReleaseVerticalGameplay

## Vertical completion pass for the first five core areas:
## combat/battles, siege, naval, autonomous AI, and character/content depth.
## This layer intentionally uses the existing WorldState and troop visuals so
## every result feeds back into the real campaign rather than a disconnected demo.

var host: Node
var world: WorldState
var attack_clock = 0.0
var ai_clock = 0.0
var battle_clock = 0.0
var naval_clock = 0.0
var state: Dictionary = {
	"combat_hits": 0,
	"ranged_shots": 0,
	"battles_resolved": 0,
	"sieges_resolved": 0,
	"naval_encounters": 0,
	"ai_decisions": 0,
	"equipment_refreshes": 0
}
var active_battle: Dictionary = {}
var active_siege: Dictionary = {}
var projectiles: Array[Dictionary] = []
var panel: Panel
var info: Label

func build(main: Node) -> void:
	host = main
	world = main.world_state
	_build_ui()
	_apply_character_content()

func _process(delta: float) -> void:
	if not is_instance_valid(world) or bool(world.simulation_paused):
		return
	attack_clock += delta
	ai_clock += delta
	battle_clock += delta
	naval_clock += delta
	_update_projectiles(delta)
	if attack_clock >= 0.25:
		attack_clock = 0.0
	_update_battle_ai()
	if ai_clock >= 1.5:
		ai_clock = 0.0
	_update_campaign_ai()
	if naval_clock >= 2.0:
		naval_clock = 0.0
	_update_naval_campaign()
	if battle_clock >= 1.0:
		battle_clock = 0.0
	_update_active_siege()
	_update_panel()

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	layer.name = "VerticalCompletionLayer"
	host.add_child(layer)
	var button = Button.new()
	button.text = "CORE DEPTH"
	button.position = Vector2(1010, 565)
	button.size = Vector2(190, 42)
	button.pressed.connect(_toggle)
	layer.add_child(button)
	panel = Panel.new()
	panel.position = Vector2(290, 95)
	panel.size = Vector2(680, 500)
	panel.visible = false
	layer.add_child(panel)
	info = Label.new()
	info.position = Vector2(20, 20)
	info.size = Vector2(640, 400)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("font_size", 17)
	panel.add_child(info)
	var close = Button.new()
	close.text = "CLOSE"
	close.position = Vector2(535, 440)
	close.size = Vector2(110, 34)
	close.pressed.connect(_toggle)
	panel.add_child(close)

func _toggle() -> void:
	panel.visible = not panel.visible
	_update_panel()

func _update_panel() -> void:
	if not is_instance_valid(info):
		return
	var battle = String(active_battle.get("phase","idle"))
	var siege = String(active_siege.get("phase","idle"))
	info.text = "CORE DEPTH • LIVE\n\n" + 		"Combat: hit detection + armor + ranged + mounted + reactions\n" + 		"Hits %d • Ranged %d\n" % [int(state["combat_hits"]),int(state["ranged_shots"])] + 		"Battle: %s • resolved %d\n" % [battle,int(state["battles_resolved"])] + 		"Siege: %s • resolved %d\n" % [siege,int(state["sieges_resolved"])] + 		"Naval encounters: %d\n" % int(state["naval_encounters"]) + 		"AI decisions: %d\n" % int(state["ai_decisions"]) + 		"Character/equipment refreshes: %d" % int(state["equipment_refreshes"])

# ---------- COMBAT + BATTLE ----------

func player_strike() -> Dictionary:
	if not is_instance_valid(host.player):
		return {"ok":false,"reason":"no_player"}
	var weapon = String(world.player_equipment.get("weapon","iron_sword"))
	var stats = _weapon_stats(weapon)
	var target = _find_cone_target(stats.range, 0.72)
	if target == null:
		return {"ok":false,"reason":"miss"}
	var target_data = _troop_data(target)
	if target_data.is_empty():
		return {"ok":false,"reason":"invalid_target"}
	var armor = _armor_value(String(target_data.get("armor","leather_armor")))
	var damage = max(1,int(stats.damage - armor))
	if String(stats.get("weapon_type","")) == "bow":
		return ranged_attack()
	host._damage_troop(target, damage)
	state["combat_hits"] = int(state["combat_hits"]) + 1
	_hit_reaction(target, stats.knockback)
	_apply_weapon_visual(stats.weapon_type)
	return {"ok":true,"damage":damage,"weapon":weapon}

func ranged_attack() -> Dictionary:
	var target = _find_cone_target(18.0, 0.82)
	if target == null:
		return {"ok":false,"reason":"no_target"}
	var arrow = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.06,0.06,0.55)
	arrow.mesh = mesh
	arrow.material_override = _material(Color(0.42,0.25,0.10))
	arrow.global_position = host.player.global_position + Vector3.UP * 1.2
	host.add_child(arrow)
	var destination = target.global_position + Vector3.UP * 1.0
	projectiles.append({"node":arrow,"target":target,"destination":destination,"speed":28.0,"damage":16})
	state["ranged_shots"] = int(state["ranged_shots"]) + 1
	return {"ok":true}

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p: Dictionary = projectiles[i]
		var node = p.get("node") as Node3D
		var target = p.get("target") as Node3D
		if not is_instance_valid(node) or not is_instance_valid(target):
			if is_instance_valid(node): node.queue_free()
			projectiles.remove_at(i)
			continue
		var destination = target.global_position + Vector3.UP * 1.0
		var distance = node.global_position.distance_to(destination)
		if distance <= 0.7:
			var data = _troop_data(target)
			var armor = _armor_value(String(data.get("armor","leather_armor")))
			host._damage_troop(target,max(1,int(p["damage"])-armor))
			node.queue_free()
			projectiles.remove_at(i)
		else:
			node.look_at(destination,Vector3.UP)
			node.global_position = node.global_position.move_toward(destination,float(p["speed"])*delta)

func _weapon_stats(name: String) -> Dictionary:
	match name:
		"axe": return {"damage":32.0,"range":2.1,"knockback":0.30,"weapon_type":"axe"}
		"mace": return {"damage":29.0,"range":1.9,"knockback":0.40,"weapon_type":"mace"}
		"spear": return {"damage":24.0,"range":2.7,"knockback":0.16,"weapon_type":"spear"}
		"steel_sword": return {"damage":29.0,"range":2.2,"knockback":0.20,"weapon_type":"sword"}
		"bow": return {"damage":18.0,"range":18.0,"knockback":0.04,"weapon_type":"bow"}
		_: return {"damage":21.0,"range":2.0,"knockback":0.12,"weapon_type":"sword"}

func _find_cone_target(max_range: float, facing_threshold: float) -> Node3D:
	if not is_instance_valid(host.player):
		return null
	var forward = -host.player.global_transform.basis.z
	forward.y = 0
	forward = forward.normalized()
	var best: Node3D = null
	var best_distance = max_range
	for data in host.troops:
		if String(data.get("team","")) != "ENEMY":
			continue
		var node = data.get("node") as Node3D
		if not is_instance_valid(node): continue
		var offset = node.global_position - host.player.global_position
		offset.y = 0
		var distance = offset.length()
		if distance > max_range or distance < 0.1: continue
		var dot = forward.dot(offset.normalized())
		if dot >= facing_threshold and distance < best_distance:
			best_distance = distance
			best = node
	return best

func _troop_data(node: Node3D) -> Dictionary:
	for data in host.troops:
		if data.get("node") == node:
			return data
	return {}

func _armor_value(armor: String) -> int:
	match armor:
		"plate_armor": return 8
		"chain_armor": return 5
		"leather_armor": return 2
		_: return 0

func _hit_reaction(target: Node3D, amount: float) -> void:
	var start = target.position
	var tween = create_tween()
	tween.tween_property(target,"position",start + Vector3(0,0,amount),0.07)
	tween.tween_property(target,"position",start,0.11)

func _apply_weapon_visual(weapon_type: String) -> void:
	if not is_instance_valid(host.player): return
	var sword = host.player.get_node_or_null("Body/Sword") as Node3D
	if is_instance_valid(sword):
		sword.rotation_degrees.z = -70.0 if weapon_type != "bow" else 0.0
		var tween = create_tween()
		tween.tween_property(sword,"rotation_degrees:z",-18.0,0.18)

func _update_battle_ai() -> void:
	if not host.battle_in_progress:
		return
	var ally = _count_team("ALLY")
	var enemy = _count_team("ENEMY")
	if ally <= 0 or enemy <= 0:
		_resolve_battle(ally > enemy)
		return
	for data in host.troops:
		var node = data.get("node") as CharacterBody3D
		if not is_instance_valid(node): continue
		var target = host._nearest_enemy(node,String(data.get("team","")))
		if target == null: continue
		var distance = node.global_position.distance_to(target.global_position)
		if distance > 1.8:
			var direction = (target.global_position-node.global_position)
			direction.y = 0
			if direction.length() > 0.1:
				node.velocity = direction.normalized() * 1.7
				node.move_and_slide()
		elif float(data.get("cooldown",0.0)) <= 0.0:
			var damage = int(data.get("attack_damage",10))
			var target_data = _troop_data(target)
			damage = max(1,damage-_armor_value(String(target_data.get("armor","leather_armor"))))
			host._damage_troop(target,damage)
			data["cooldown"] = 0.9
			_hit_reaction(target,0.05)

func _count_team(team: String) -> int:
	var total = 0
	for data in host.troops:
		if String(data.get("team","")) == team:
			total += int(data.get("represented_count",1))
	return total

func _resolve_battle(player_won: bool) -> void:
	if not host.battle_in_progress:
		return
	var casualties = host.get_battle_casualties()
	var settlement_id = int(active_battle.get("settlement_id",-1))
	if settlement_id >= 0 and settlement_id < world.settlements.size():
		world.apply_manual_battle_result(settlement_id,int(casualties.get("attacker",0)),int(casualties.get("defender",0)),casualties.get("attacker_types",{}),casualties.get("defender_types",{}),player_won)
	host.battle_in_progress = false
	state["battles_resolved"] = int(state["battles_resolved"]) + 1
	active_battle["phase"] = "victory" if player_won else "defeat"
	host._show_status("BATTLE %s • campaign updated" % ("WON" if player_won else "LOST"),3.0)
	host.battle_time = 0.0
	host._clear_battlefield()

func start_battle(attacker: Dictionary, defender: Dictionary, settlement_id: int=-1) -> Dictionary:
	host.prepare_battle(attacker,defender)
	active_battle = {"phase":"active","settlement_id":settlement_id,"attacker":attacker.get("name","Attacker"),"defender":defender.get("name","Defender")}
	return {"ok":true}

# ---------- SIEGE ----------

func begin_siege(settlement_id: int, army_id: int) -> Dictionary:
	var result = world.start_siege(settlement_id,army_id)
	if not bool(result.get("ok",false)):
		return result
	active_siege = {"settlement_id":settlement_id,"army_id":army_id,"phase":"bombardment","equipment":"ram"}
	state["sieges_resolved"] = int(state["sieges_resolved"])
	_spawn_siege_equipment()
	return result

func use_siege_equipment(kind: String) -> Dictionary:
	if active_siege.is_empty():
		return {"ok":false,"reason":"no_siege"}
	var sid = int(active_siege.get("settlement_id",-1))
	if sid < 0 or sid >= world.settlements.size(): return {"ok":false}
	var siege_data: Dictionary = world.sieges.get(sid,{})
	if siege_data.is_empty(): return {"ok":false,"reason":"siege_missing"}
	var damage_gate = {"ram":24,"catapult":14,"tower":8,"ladder":5}.get(kind,10)
	var damage_wall = {"ram":4,"catapult":28,"tower":8,"ladder":3}.get(kind,5)
	siege_data["gate_hp"] = max(0,int(siege_data.get("gate_hp",120))-damage_gate)
	siege_data["wall_hp"] = max(0,int(siege_data.get("wall_hp",500))-damage_wall)
	if int(siege_data["gate_hp"]) <= 0:
		siege_data["gate_breached"] = true
		siege_data["breach"] = true
		siege_data["phase"] = "gate breached"
	elif int(siege_data["wall_hp"]) <= int(world.settlements[sid].get("wall_level",1))*35:
		siege_data["breach"] = true
		siege_data["phase"] = "wall breached"
	world.sieges[sid] = siege_data
	active_siege["phase"] = String(siege_data.get("phase","bombardment"))
	_refresh_siege_visual(sid)
	return {"ok":true,"gate_hp":siege_data["gate_hp"],"wall_hp":siege_data["wall_hp"]}

func assault_siege() -> Dictionary:
	if active_siege.is_empty(): return {"ok":false,"reason":"no_siege"}
	var sid = int(active_siege.get("settlement_id",-1))
	var result = world.assault_siege(sid)
	if bool(result.get("captured",false)):
		state["sieges_resolved"] = int(state["sieges_resolved"])+1
		active_siege["phase"] = "captured"
	else:
		active_siege["phase"] = String(result.get("phase","assault"))
	_refresh_siege_visual(sid)
	return result

func _update_active_siege() -> void:
	if active_siege.is_empty(): return
	var sid = int(active_siege.get("settlement_id",-1))
	if sid < 0 or sid >= world.settlements.size(): return
	if not world.sieges.has(sid):
		if String(active_siege.get("phase","")) != "captured":
			active_siege["phase"] = "ended"
		return
	var s: Dictionary = world.sieges[sid]
	active_siege["phase"] = String(s.get("phase","approach"))
	_refresh_siege_visual(sid)

func _refresh_siege_visual(sid: int) -> void:
	if not is_instance_valid(host.siege_visual_root): return
	var data: Dictionary = world.sieges.get(sid,{})
	if data.is_empty(): return
	host.update_siege_visual(int(data.get("progress",0)),bool(data.get("gate_breached",false)),int(data.get("gate_hp",120)),int(data.get("wall_hp",500)))

func _spawn_siege_equipment() -> void:
	if not is_instance_valid(host.siege_visual_root): return
	var root = host.siege_visual_root
	var equipment = Node3D.new()
	equipment.name = "SiegeEquipment"
	root.add_child(equipment)
	for i in range(3):
		var ram = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(2.6,0.45,0.55)
		ram.mesh = mesh
		ram.position = Vector3(-5.0+i*5.0,0.55,4.5)
		ram.material_override = _material(Color(0.28,0.15,0.07))
		equipment.add_child(ram)

# ---------- NAVAL ----------

func naval_attack(attacker_id: int, defender_id: int) -> Dictionary:
	var result = world.naval_battle(attacker_id,defender_id)
	if bool(result.get("ok",false)):
		state["naval_encounters"] = int(state["naval_encounters"])+1
	return result

func transport_army(ship_id: int, army_id: int, target_region: int) -> Dictionary:
	if ship_id < 0 or ship_id >= world.ships.size() or army_id < 0 or army_id >= world.armies.size():
		return {"ok":false,"reason":"invalid"}
	var ship: Dictionary = world.ships[ship_id]
	var army: Dictionary = world.armies[army_id]
	var capacity = int(ship.get("capacity",int(ship.get("crew",10))*3))
	if int(army.get("soldiers",0)) > capacity:
		return {"ok":false,"reason":"capacity"}
	if target_region < 0 or target_region >= world.regions.size():
		return {"ok":false,"reason":"target"}
	army["transported_by"] = ship_id
	army["transport_target_region"] = target_region
	army["moving"] = true
	ship["target_region"] = target_region
	ship["moving"] = true
	world.armies[army_id] = army
	world.ships[ship_id] = ship
	return {"ok":true}

func _update_naval_campaign() -> void:
	for ship in world.ships:
		if String(world.weather) == "storm":
			ship["health"] = max(0,int(ship.get("health",100))-1)
			ship["fatigue"] = min(100,int(ship.get("fatigue",0))+2)
		else:
			ship["fatigue"] = max(0,int(ship.get("fatigue",0))-1)
		if bool(ship.get("moving",false)):
			var current = int(ship.get("region",0))
			var target = int(ship.get("target_region",current))
			if current != target:
				var next = _next_region(current,target)
				ship["region"] = next
				if next == target:
					ship["moving"] = false
					for army in world.armies:
						if int(army.get("transported_by",-1)) == int(ship.get("id",-1)):
							army["region"] = target
							army["moving"] = false
							army.erase("transported_by")
							army.erase("transport_target_region")
							world.world_events.append("%s landed at %s." % [army.get("name","Army"),world.regions[target]["name"]])

func _next_region(start: int, goal: int) -> int:
	if start == goal: return goal
	var queue: Array[int] = [start]
	var previous = {start:-1}
	while not queue.is_empty():
		var current = queue.pop_front()
		for n in world.get_region_neighbors(current):
			if previous.has(n): continue
			previous[n] = current
			if n == goal:
				var step = n
				while int(previous[step]) != start and int(previous[step]) != -1:
					step = int(previous[step])
				return step
			queue.append(n)
	return start

# ---------- AUTONOMOUS AI ----------

func _update_campaign_ai() -> void:
	for army in world.armies:
		if int(army.get("soldiers",0)) <= 0: continue
		var owner = String(army.get("owner",""))
		if owner == world.player_faction: continue
		var region = int(army.get("region",0))
		var morale = int(army.get("morale",70))
		var food = int(army.get("food",100))
		if food < 20 or morale < 25:
			army["order"] = "retreat"
			army["target_region"] = _nearest_friendly_region(region,owner)
			army["moving"] = true
			state["ai_decisions"] = int(state["ai_decisions"])+1
			continue
		var hostile = _hostile_neighbors(region,owner)
		if not hostile.is_empty():
			var target = hostile[0]
			army["target_region"] = target
			army["moving"] = true
			army["order"] = "attack"
			army["formation"] = "wedge" if int(army.get("soldiers",0)) > 180 else "line"
			state["ai_decisions"] = int(state["ai_decisions"])+1
		else:
			var friendly = _friendly_neighbors(region,owner)
			if not friendly.is_empty() and int(army.get("soldiers",0)) < 80:
				army["target_region"] = friendly[0]
				army["moving"] = true
				army["order"] = "defend"
		_tick_army_movement(army)

func _tick_army_movement(army: Dictionary) -> void:
	if not bool(army.get("moving",false)): return
	var current = int(army.get("region",0))
	var target = int(army.get("target_region",current))
	if current == target:
		army["moving"] = false
		return
	var next = _next_region(current,target)
	army["region"] = next
	if next == target:
		army["moving"] = false
		if String(army.get("order","")) == "attack":
			army["morale"] = max(0,int(army.get("morale",70))-2)
			_resolve_ai_region_attack(army,target)

func _resolve_ai_region_attack(army: Dictionary, region_id: int) -> void:
	var owner = String(army.get("owner",""))
	if region_id < 0 or region_id >= world.regions.size(): return
	var target_owner = String(world.regions[region_id].get("owner",""))
	if not _at_war(owner,target_owner): return
	var settlement_id = -1
	for i in range(world.settlements.size()):
		if int(world.settlements[i].get("region",-1)) == region_id and String(world.settlements[i].get("owner","")) == target_owner:
			settlement_id = i
			break
	if settlement_id < 0: return
	var settlement: Dictionary = world.settlements[settlement_id]
	var attack_power = max(1,int(army.get("soldiers",0)) + int(army.get("troops",{}).get("horseman",0))*2)
	var defense_power = max(1,int(settlement.get("garrison",0)) + int(settlement.get("wall_level",1))*18)
	var ratio = float(attack_power)/float(defense_power)
	var attacker_loss = max(1,int(defense_power*(0.05 if ratio >= 1.0 else 0.10)))
	var defender_loss = max(1,int(attack_power*(0.12 if ratio >= 1.0 else 0.06)))
	army["soldiers"] = max(0,int(army.get("soldiers",0))-attacker_loss)
	army["morale"] = max(0,int(army.get("morale",70))-min(20,int(attacker_loss/3)))
	settlement["garrison"] = max(0,int(settlement.get("garrison",0))-defender_loss)
	if ratio >= 1.0 and int(settlement["garrison"]) <= 0:
		settlement["owner"] = owner
		settlement["garrison"] = max(15,int(army.get("soldiers",0)/8))
		world.transfer_region(region_id,owner)
		world.world_events.append("%s captured %s." % [army.get("name","Army"),settlement.get("name","Settlement")])
	else:
		army["order"] = "defend" if ratio < 0.8 else "attack"

func _hostile_neighbors(region: int, owner: String) -> Array[int]:
	var result: Array[int] = []
	for n in world.get_region_neighbors(region):
		if n >= 0 and n < world.regions.size() and _at_war(owner,String(world.regions[n].get("owner",""))):
			result.append(n)
	return result

func _friendly_neighbors(region: int, owner: String) -> Array[int]:
	var result: Array[int] = []
	for n in world.get_region_neighbors(region):
		if n >= 0 and n < world.regions.size() and String(world.regions[n].get("owner","")) == owner:
			result.append(n)
	return result

func _nearest_friendly_region(region: int, owner: String) -> int:
	var best = region
	var distance = 999
	for i in range(world.regions.size()):
		if String(world.regions[i].get("owner","")) != owner: continue
		var d = abs(i-region)
		if d < distance:
			distance = d
			best = i
	return best

func _at_war(a: String,b: String) -> bool:
	if a == b or a == "" or b == "": return false
	var key = a + "|" + b
	var reverse = b + "|" + a
	return String(world.diplomacy.get(key,world.diplomacy.get(reverse,"peace"))) == "war"

# ---------- CHARACTER / CONTENT ----------

func _apply_character_content() -> void:
	if not is_instance_valid(host.player): return
	var eq: Dictionary = world.player_equipment
	_apply_player_equipment(eq)
	for data in host.troops:
		var node = data.get("node") as Node3D
		if is_instance_valid(node):
			data["armor"] = "leather_armor"
			data["mount"] = String(data.get("troop_type","")) == "horseman"

func refresh_equipment() -> void:
	_apply_player_equipment(world.player_equipment)
	state["equipment_refreshes"] = int(state["equipment_refreshes"])+1

func _apply_player_equipment(eq: Dictionary) -> void:
	if not is_instance_valid(host.player): return
	var body = host.player.get_node_or_null("Body") as MeshInstance3D
	if is_instance_valid(body):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.22,0.38,0.62)
		if String(eq.get("armor","")) == "plate_armor":
			mat.albedo_color = Color(0.48,0.50,0.54)
		elif String(eq.get("armor","")) == "chain_armor":
			mat.albedo_color = Color(0.30,0.34,0.38)
		body.material_override = mat
	var mount = host.player.get_node_or_null("MountVisual") as Node3D
	if String(eq.get("horse","none")) == "war_horse" and not is_instance_valid(mount):
		mount = Node3D.new()
		mount.name = "MountVisual"
		host.player.add_child(mount)
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(1.1,0.7,1.8)
		mesh.mesh = box
		mesh.material_override = _material(Color(0.16,0.11,0.07))
		mount.add_child(mesh)
		mount.position = Vector3(0,-0.35,0.55)
	elif String(eq.get("horse","none")) != "war_horse" and is_instance_valid(mount):
		mount.queue_free()

func _material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	return material

func _save_state() -> Dictionary:
	return {"state":state.duplicate(true),"active_battle":active_battle.duplicate(true),"active_siege":active_siege.duplicate(true)}

func get_save_state() -> Dictionary:
	return _save_state()

func load_save_state(data: Dictionary) -> void:
	state = data.get("state",state).duplicate(true)
	active_battle = data.get("active_battle",{}).duplicate(true)
	active_siege = data.get("active_siege",{}).duplicate(true)
