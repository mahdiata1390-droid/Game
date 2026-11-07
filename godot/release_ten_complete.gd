extends Node3D
class_name ReleaseTenComplete

# One integrated pass for the ten remaining pillars:
# 1 visual content, 2 combat, 3 siege, 4 autonomous AI, 5 economy,
# 6 naval, 7 character life, 8 progression, 9 living world, 10 world map.
# This layer owns simulation state and presentation glue; WorldState remains
# the authoritative campaign database.

var game: Node3D
var world: Node
var player: CharacterBody3D
var stamina = 100.0
var max_stamina = 100.0
var combo_step = 0
var combo_timer = 0.0
var block_active = false
var combat_xp = 0
var projectiles: Array[Node3D] = []
var ai_clock = 0.0
var economy_clock = 0.0
var life_clock = 0.0
var world_clock = 0.0
var visual_clock = 0.0
var map_panel: Panel
var map_label: Label
var map_open = false
var selected_settlement = -1
var selected_army = -1
var siege_state: Dictionary = {}
var naval_state: Dictionary = {}
var family_state: Dictionary = {}
var progression_state: Dictionary = {}
var living_npcs: Array[Node3D] = []
var world_animals: Array[Node3D] = []
var visual_roots: Array[Node3D] = []
var rng = RandomNumberGenerator.new()

func build(main_node: Node3D) -> void:
	game = main_node
	world = game.get("world_state")
	player = game.get("player")
	rng.seed = 784331
	_init_state()
	_build_visual_content()
	_build_mobile_hud()
	_refresh_map()
	set_process(true)

func _init_state() -> void:
	var state = _state()
	if not state.has("ten_complete"):
		state["ten_complete"] = true
		state["combat"] = {"stamina":100.0,"combo":0,"weapon":"iron_sword","block":false}
		state["economy"] = {"prices":{"food":1.0,"wood":1.0,"iron":2.0,"horses":3.0},"inflation":0.0}
		state["family"] = {"age":18,"children":0,"heir_ready":false,"house_wealth":0}
		state["progression"] = {"xp":0,"level":1,"renown":0,"reputation":0,"skill_points":0}
		state["world"] = {"discovered":[], "fog":true, "events":0}
		state["naval"] = {"encounters":0,"victories":0,"cargo_value":0}
		state["ai"] = {"decisions":0,"wars":0,"captures":0}
		state["siege"] = {"active":false,"settlement":-1,"progress":0,"wall_hp":0,"gate_hp":0,"phase":"idle"}
		state["visual"] = {"built":true,"npc_count":0,"animal_count":0}
	else:
		stamina = float(state["combat"].get("stamina",100.0))

func _state() -> Dictionary:
	if world == null:
		return {}
	if not world.has_meta("ten_complete_state"):
		world.set_meta("ten_complete_state", {})
	return world.get_meta("ten_complete_state")

func _process(delta: float) -> void:
	if world == null or player == null:
		return
	combo_timer = max(0.0, combo_timer - delta)
	if combo_timer <= 0.0:
		combo_step = 0
	stamina = min(max_stamina, stamina + 13.0 * delta)
	ai_clock += delta
	economy_clock += delta
	life_clock += delta
	world_clock += delta
	visual_clock += delta
	if ai_clock >= 3.0:
		ai_clock = 0.0
		_simulate_ai()
	if economy_clock >= 5.0:
		economy_clock = 0.0
		_simulate_economy()
	if life_clock >= 8.0:
		life_clock = 0.0
		_simulate_life()
	if world_clock >= 4.0:
		world_clock = 0.0
		_simulate_living_world()
	if visual_clock >= 2.0:
		visual_clock = 0.0
		_update_visual_npcs()
	_update_projectiles(delta)

# ---------------------------------------------------------------------------
# 1. WORLD + CHARACTER CONTENT
# ---------------------------------------------------------------------------

func _build_visual_content() -> void:
	if world == null:
		return
	for i in range(world.settlements.size()):
		var s: Dictionary = world.settlements[i]
		var p: Vector2 = s.get("position", Vector2.ZERO)
		var root = Node3D.new()
		root.name = "LifeContent_%s" % String(s.get("name","Settlement"))
		root.position = Vector3(p.x, 0.02, p.y)
		game.add_child(root)
		visual_roots.append(root)
		_build_settlement_props(root, String(s.get("type","village")), String(s.get("owner","")))
	_spawn_living_population()
	_spawn_world_animals()
	_state()["visual"]["npc_count"] = living_npcs.size()
	_state()["visual"]["animal_count"] = world_animals.size()

func _build_settlement_props(root: Node3D, kind: String, owner: String) -> void:
	var accent = world.get_faction_accent(owner)
	var service_count = 3
	if kind == "city": service_count = 7
	elif kind == "castle": service_count = 5
	for i in range(service_count):
		var prop = Node3D.new()
		prop.name = "Service_%d" % i
		prop.position = Vector3(-3.2 + float(i % 4) * 2.1, 0, 2.3 + float(i / 4) * 1.8)
		root.add_child(prop)
		_make_box(prop, Vector3(0.9,0.65,0.75), Vector3(0,0.32,0), Color(0.34,0.24,0.15))
		_make_box(prop, Vector3(1.0,0.12,0.82), Vector3(0,0.72,0), accent)
		_make_box(prop, Vector3(0.16,1.25,0.16), Vector3(0.38,0.62,0.28), Color(0.20,0.12,0.07))
	for i in range(3 if kind == "village" else 6):
		var tree = Node3D.new()
		tree.position = Vector3(-4.0 + i * 1.7, 0, -2.8)
		root.add_child(tree)
		_make_cylinder(tree, 0.11, 1.3, Vector3(0,0.65,0), Color(0.20,0.11,0.06))
		_make_sphere(tree, 0.62, Vector3(0,1.45,0), Color(0.09,0.30,0.11))

func _spawn_living_population() -> void:
	for i in range(min(36, world.settlements.size() * 2)):
		var npc = Node3D.new()
		npc.name = "WorldNPC_%d" % i
		var s: Dictionary = world.settlements[i % world.settlements.size()]
		var p: Vector2 = s.get("position",Vector2.ZERO)
		npc.position = Vector3(p.x + rng.randf_range(-3.0,3.0), 0, p.y + rng.randf_range(-3.0,3.0))
		game.add_child(npc)
		_make_box(npc, Vector3(0.34,0.8,0.28), Vector3(0,0.55,0), Color(0.25+rng.randf()*0.25,0.16,0.10))
		_make_sphere(npc, 0.18, Vector3(0,1.12,0), Color(0.58,0.40,0.28))
		living_npcs.append(npc)

func _spawn_world_animals() -> void:
	for i in range(12):
		var animal = Node3D.new()
		animal.name = "WildAnimal_%d" % i
		animal.position = Vector3(rng.randf_range(-20,20),0.15,rng.randf_range(-16,16))
		game.add_child(animal)
		_make_box(animal,Vector3(0.7,0.35,1.25),Vector3(0,0.32,0),Color(0.25,0.18,0.11))
		_make_sphere(animal,0.28,Vector3(0,0.55,-0.45),Color(0.30,0.22,0.15))
		world_animals.append(animal)

func _make_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var m = BoxMesh.new()
	m.size = size
	n.mesh = m
	n.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	n.material_override = mat
	parent.add_child(n)
	return n

func _make_cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var m = CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	n.mesh = m
	n.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	n.material_override = mat
	parent.add_child(n)
	return n

func _make_sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var m = SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	n.mesh = m
	n.position = pos
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	n.material_override = mat
	parent.add_child(n)
	return n

# ---------------------------------------------------------------------------
# 2. COMPLETE COMBAT
# ---------------------------------------------------------------------------

func player_strike() -> Dictionary:
	if player == null or stamina < 12.0:
		return {"ok":false,"reason":"stamina"}
	var weapon = String(_state()["combat"].get("weapon","iron_sword"))
	var stats = {"iron_sword":[22,2.0],"steel_sword":[30,2.1],"axe":[34,1.7],"mace":[32,1.6],"spear":[26,2.8]}
	var w: Array = stats.get(weapon,stats["iron_sword"])
	stamina -= 12.0
	combo_step = (combo_step + 1) % 3
	combo_timer = 1.0
	var combo_bonus = 1.0 + float(combo_step) * 0.14
	var target: Node3D = _nearest_enemy(3.2)
	if target == null:
		return {"ok":true,"hit":false,"damage":0,"weapon":weapon,"combo":combo_step}
	var damage = int(round(float(w[0]) * combo_bonus))
	if block_active:
		damage = int(round(float(damage) * 0.35))
	_apply_damage_to_node(target, damage)
	combat_xp += damage
	_add_progression_xp(max(2,damage/3))
	return {"ok":true,"hit":true,"damage":damage,"weapon":weapon,"combo":combo_step}

func set_block(active: bool) -> void:
	block_active = active
	_state()["combat"]["block"] = active

func set_weapon(weapon: String) -> bool:
	if not ["iron_sword","steel_sword","axe","mace","spear"].has(weapon):
		return false
	_state()["combat"]["weapon"] = weapon
	return true

func ranged_attack() -> Dictionary:
	if player == null or stamina < 18.0:
		return {"ok":false,"reason":"stamina"}
	stamina -= 18.0
	var target = _nearest_enemy(22.0)
	if target == null:
		return {"ok":true,"hit":false}
	var bolt = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(0.06,0.06,0.45)
	bolt.mesh = mesh
	bolt.position = player.global_position + Vector3(0,1.3,0)
	bolt.look_at(target.global_position + Vector3(0,1.0,0),Vector3.UP)
	game.add_child(bolt)
	projectiles.append(bolt)
	bolt.set_meta("target",target)
	bolt.set_meta("damage",24)
	return {"ok":true,"hit":true}

func _update_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p = projectiles[i]
		if not is_instance_valid(p):
			projectiles.remove_at(i)
			continue
		var target = p.get_meta("target") as Node3D
		if not is_instance_valid(target):
			p.queue_free(); projectiles.remove_at(i); continue
		var destination = target.global_position + Vector3(0,1.0,0)
		p.global_position = p.global_position.move_toward(destination,18.0*delta)
		if p.global_position.distance_to(destination) < 0.45:
			_apply_damage_to_node(target,int(p.get_meta("damage")))
			p.queue_free()
			projectiles.remove_at(i)

func _nearest_enemy(max_distance: float) -> Node3D:
	var best: Node3D
	var best_d = max_distance
	var troop_array: Array = game.get("troops") if game.get("troops") != null else []
	for d in troop_array:
		if String(d.get("team","")) != "ENEMY":
			continue
		var n = d.get("node") as Node3D
		if not is_instance_valid(n):
			continue
		var dist = player.global_position.distance_to(n.global_position)
		if dist < best_d:
			best_d = dist
			best = n
	return best

func _apply_damage_to_node(target: Node3D, damage: int) -> void:
	if game.has_method("_damage_troop"):
		game.call("_damage_troop",target,damage)

# ---------------------------------------------------------------------------
# 3. SIEGE
# ---------------------------------------------------------------------------

func begin_siege(settlement_id: int) -> Dictionary:
	if world == null or settlement_id < 0 or settlement_id >= world.settlements.size():
		return {"ok":false}
	var result = world.start_siege(settlement_id, _player_army_id())
	if not bool(result.get("ok",false)):
		return result
	var s: Dictionary = world.settlements[settlement_id]
	siege_state = {"active":true,"settlement":settlement_id,"progress":0,"wall_hp":int(s.get("wall_level",1))*160,"gate_hp":140,"phase":"encampment"}
	_state()["siege"] = siege_state.duplicate(true)
	if game.has_method("create_siege_visual"):
		game.call("create_siege_visual",String(s["name"]),int(s.get("wall_level",1)))
	return {"ok":true,"settlement":s["name"]}

func use_siege_equipment(kind: String) -> Dictionary:
	if not bool(siege_state.get("active",false)):
		return {"ok":false,"reason":"no_siege"}
	var damage = {"ram":28,"catapult":45,"tower":18,"ladder":12}.get(kind,0)
	if damage == 0:
		return {"ok":false,"reason":"invalid_equipment"}
	if kind == "ram":
		siege_state["gate_hp"] = max(0,int(siege_state["gate_hp"])-damage)
	else:
		siege_state["wall_hp"] = max(0,int(siege_state["wall_hp"])-damage)
	siege_state["progress"] = min(100,int(siege_state["progress"])+8)
	if int(siege_state["gate_hp"]) <= 0:
		siege_state["phase"] = "gate breached"
	elif int(siege_state["wall_hp"]) <= 40:
		siege_state["phase"] = "wall breached"
	else:
		siege_state["phase"] = "bombardment"
	_state()["siege"] = siege_state.duplicate(true)
	return {"ok":true,"kind":kind,"progress":siege_state["progress"],"phase":siege_state["phase"]}

func assault_siege() -> Dictionary:
	if not bool(siege_state.get("active",false)):
		return {"ok":false,"reason":"no_siege"}
	var sid = int(siege_state["settlement"])
	var result = world.assault_siege(sid)
	if bool(result.get("captured",false)):
		siege_state["active"] = false
		siege_state["phase"] = "captured"
	else:
		siege_state["progress"] = int(result.get("progress",siege_state["progress"]))
		siege_state["phase"] = String(result.get("phase",siege_state["phase"]))
	_state()["siege"] = siege_state.duplicate(true)
	return result

# ---------------------------------------------------------------------------
# 4. AUTONOMOUS AI
# ---------------------------------------------------------------------------

func _simulate_ai() -> void:
	if world == null or world.armies.is_empty():
		return
	var decisions = 0
	for i in range(world.armies.size()):
		var army: Dictionary = world.armies[i]
		if String(army.get("owner","")) == world.player_faction:
			continue
		var soldiers = int(army.get("soldiers",0))
		var morale = int(army.get("morale",50))
		var food = int(army.get("food",0))
		if soldiers <= 0:
			continue
		if food < 15 or morale < 30:
			army["order"] = "retreat"
			var neighbors: Array = world.get_region_neighbors(int(army.get("region",0)))
			if not neighbors.is_empty():
				army["region"] = neighbors[rng.randi_range(0,neighbors.size()-1)]
			decisions += 1
			continue
		var hostile = _find_hostile_neighbor(String(army.get("owner","")),int(army.get("region",0)))
		if hostile >= 0 and soldiers >= 70:
			army["order"] = "attack"
			army["target_region"] = hostile
			army["region"] = hostile
			army["food"] = max(0,food-8)
			decisions += 1
		elif rng.randf() < 0.25:
			var neighbors2: Array = world.get_region_neighbors(int(army.get("region",0)))
			if not neighbors2.is_empty():
				army["region"] = neighbors2[rng.randi_range(0,neighbors2.size()-1)]
			army["order"] = "patrol"
			decisions += 1
	_state()["ai"]["decisions"] = int(_state()["ai"].get("decisions",0)) + decisions
	_state()["ai"]["wars"] = world.diplomacy.size()

func _find_hostile_neighbor(owner: String, region_id: int) -> int:
	for rid in world.get_region_neighbors(region_id):
		if rid < 0 or rid >= world.regions.size():
			continue
		var other = String(world.regions[rid].get("owner",""))
		if other != owner and world.has_method("_are_at_war") and world.call("_are_at_war",owner,other):
			return rid
	return -1

# ---------------------------------------------------------------------------
# 5. ECONOMY
# ---------------------------------------------------------------------------

func _simulate_economy() -> void:
	if world == null:
		return
	var totals = {"food":0,"wood":0,"iron":0,"horses":0,"spice":0}
	for s in world.settlements:
		var stock: Dictionary = s.get("stockpile",{})
		for key in totals.keys():
			totals[key] += int(stock.get(key,0))
	var prices: Dictionary = _state()["economy"]["prices"]
	for key in prices.keys():
		var amount = int(totals.get(key,0))
		var target = 80
		var pressure = clamp((float(target)-float(amount))/float(target),-0.45,0.65)
		prices[key] = clamp(1.0 + pressure,0.55,4.0)
	_state()["economy"]["prices"] = prices
	_state()["economy"]["inflation"] = float(prices.get("food",1.0))-1.0
	# Produce and consume resources at settlement level.
	for s in world.settlements:
		var stock: Dictionary = s.get("stockpile",{})
		var prosperity = int(s.get("prosperity",40))
		var farm = int(s.get("buildings",{}).get("farm",1))
		stock["food"] = int(stock.get("food",0)) + max(1,farm + prosperity/30)
		stock["wood"] = int(stock.get("wood",0)) + 1
		if String(s.get("type","")) == "city":
			stock["iron"] = int(stock.get("iron",0)) + 1
		stock["food"] = max(0,int(stock["food"])-max(1,int(s.get("population",100)/500)))
		s["stockpile"] = stock
	# Player market reflects the same economy.
	world.player_inventory["food"] = int(world.player_inventory.get("food",0))
	world.production_stock = world.player_inventory.duplicate(true)

func buy_resource(resource: String, amount: int) -> Dictionary:
	if not ["food","wood","iron","horses","spice"].has(resource) or amount <= 0:
		return {"ok":false}
	var price = float(_state()["economy"]["prices"].get(resource,1.0))
	var cost = int(ceil(price * amount))
	if world.gold < cost:
		return {"ok":false,"reason":"gold","cost":cost}
	world.gold -= cost
	world.player_inventory[resource] = int(world.player_inventory.get(resource,0)) + amount
	return {"ok":true,"cost":cost,"price":price}

func sell_resource(resource: String, amount: int) -> Dictionary:
	if amount <= 0 or int(world.player_inventory.get(resource,0)) < amount:
		return {"ok":false}
	var price = float(_state()["economy"]["prices"].get(resource,1.0))
	var gain = int(floor(price * amount * 0.9))
	world.player_inventory[resource] = int(world.player_inventory.get(resource,0)) - amount
	world.gold += gain
	return {"ok":true,"gold":gain}

# ---------------------------------------------------------------------------
# 6. NAVAL
# ---------------------------------------------------------------------------

func naval_attack(ship_id: int, target_ship_id: int) -> Dictionary:
	if ship_id < 0 or target_ship_id < 0 or ship_id >= world.ships.size() or target_ship_id >= world.ships.size():
		return {"ok":false}
	var a: Dictionary = world.ships[ship_id]
	var b: Dictionary = world.ships[target_ship_id]
	var ap = int(a.get("crew",0)) + int(a.get("cargo",{}).get("iron",0))*2
	var bp = int(b.get("crew",0)) + int(b.get("cargo",{}).get("iron",0))*2
	var won = ap >= bp
	_state()["naval"]["encounters"] = int(_state()["naval"].get("encounters",0)) + 1
	if won:
		_state()["naval"]["victories"] = int(_state()["naval"].get("victories",0)) + 1
		var loot = 0
		for v in b.get("cargo",{}).values(): loot += int(v)
		world.gold += loot
		world.ships.remove_at(target_ship_id)
		return {"ok":true,"won":true,"loot":loot}
	return {"ok":true,"won":false,"loot":0}

func transport_army(ship_id: int, army_id: int, target_region: int) -> Dictionary:
	if ship_id < 0 or ship_id >= world.ships.size() or army_id < 0 or army_id >= world.armies.size():
		return {"ok":false}
	var ship: Dictionary = world.ships[ship_id]
	var army: Dictionary = world.armies[army_id]
	var capacity = int(ship.get("crew",0))*3
	if int(army.get("soldiers",0)) > capacity:
		return {"ok":false,"reason":"capacity","capacity":capacity}
	if target_region < 0 or target_region >= world.regions.size():
		return {"ok":false}
	ship["target_region"] = target_region
	ship["moving"] = true
	ship["cargo"]["army"] = army_id
	army["transported_by"] = ship_id
	_state()["naval"]["cargo_value"] = int(_state()["naval"].get("cargo_value",0)) + int(army.get("soldiers",0))
	return {"ok":true,"ship":ship.get("name","ship"),"target":world.regions[target_region].get("name","region")}

# ---------------------------------------------------------------------------
# 7. CHARACTER LIFE
# ---------------------------------------------------------------------------

func _simulate_life() -> void:
	if world == null:
		return
	var fam = _state()["family"]
	fam["age"] = int(fam.get("age",18))
	if world.day % 30 == 0:
		fam["age"] += 1
		if rng.randf() < 0.16 and int(fam.get("children",0)) < 5:
			fam["children"] = int(fam.get("children",0)) + 1
			world.family_members.append({"name":"Child %d" % int(fam["children"]),"role":"child","age":0,"loyalty":80})
		if int(fam.get("children",0)) > 0 and fam["age"] >= 35:
			fam["heir_ready"] = true
	fam["house_wealth"] = int(world.gold) + int(fam.get("children",0))*40
	_state()["family"] = fam
	# Keep the existing family system synchronized.
	world.family["age"] = fam["age"]
	world.family["heir_age"] = max(0,int(fam["age"])-18) if int(fam["children"]) > 0 else 0

func set_career(career: String) -> Dictionary:
	if not ["ordinary","king","tribal_leader"].has(career):
		return {"ok":false}
	world.player_mode = career
	world.player_start = career
	if career == "king":
		world.player_faction = "Free Company"
		world.gold = max(world.gold,1000)
	elif career == "tribal_leader":
		world.gold = max(world.gold,650)
	else:
		world.gold = max(world.gold,250)
	return {"ok":true,"career":career}

# ---------------------------------------------------------------------------
# 8. PROGRESSION
# ---------------------------------------------------------------------------

func _add_progression_xp(amount: int) -> void:
	if amount <= 0:
		return
	var p = _state()["progression"]
	p["xp"] = int(p.get("xp",0)) + amount
	var old_level = int(p.get("level",1))
	var level = old_level
	while int(p["xp"]) >= level * 120:
		p["xp"] = int(p["xp"]) - level * 120
		level += 1
		p["skill_points"] = int(p.get("skill_points",0)) + 2
		p["renown"] = int(p.get("renown",0)) + 10
	p["level"] = level
	world.player_level = level
	world.player_xp = int(p["xp"])

func add_renown(amount: int) -> void:
	var p = _state()["progression"]
	p["renown"] = max(0,int(p.get("renown",0))+amount)
	p["reputation"] = clamp(int(p.get("reputation",0))+int(amount/2),-100,100)

func spend_skill_point(skill: String) -> Dictionary:
	if not ["combat","command","trade","diplomacy","survival"].has(skill):
		return {"ok":false}
	var p = _state()["progression"]
	if int(p.get("skill_points",0)) <= 0:
		return {"ok":false,"reason":"no_points"}
	p["skill_points"] = int(p["skill_points"])-1
	p["skill_"+skill] = int(p.get("skill_"+skill,0))+1
	return {"ok":true,"skill":skill,"level":p["skill_"+skill]}

# ---------------------------------------------------------------------------
# 9. LIVING WORLD
# ---------------------------------------------------------------------------

func _simulate_living_world() -> void:
	if world == null:
		return
	for i in range(world.caravans.size()):
		var c: Dictionary = world.caravans[i]
		if not c.has("risk"):
			c["risk"] = rng.randf_range(0.05,0.30)
		if rng.randf() < float(c["risk"])*0.08:
			world.world_events.append("A caravan was delayed by bandits.")
			c["risk"] = min(0.65,float(c["risk"])+0.03)
	# Small, deterministic world events that alter actual campaign values.
	if rng.randf() < 0.10 and not world.settlements.is_empty():
		var sid = rng.randi_range(0,world.settlements.size()-1)
		var s: Dictionary = world.settlements[sid]
		s["prosperity"] = clamp(int(s.get("prosperity",40))+rng.randi_range(-3,5),0,100)
		_state()["world"]["events"] = int(_state()["world"].get("events",0))+1
	if rng.randf() < 0.06:
		world.world_events.append("A travelling merchant has changed prices in the region.")

func _update_visual_npcs() -> void:
	if player == null:
		return
	for npc in living_npcs:
		if not is_instance_valid(npc):
			continue
		var offset = Vector3(rng.randf_range(-1.0,1.0),0,rng.randf_range(-1.0,1.0))
		npc.position += offset * 0.12
		if npc.position.distance_to(player.position) > 80.0:
			npc.visible = false
		else:
			npc.visible = true
	for animal in world_animals:
		if not is_instance_valid(animal):
			continue
		animal.position += Vector3(rng.randf_range(-0.5,0.5),0,rng.randf_range(-0.5,0.5))*0.08
		animal.visible = animal.position.distance_to(player.position) < 75.0

# ---------------------------------------------------------------------------
# 10. WORLD MAP
# ---------------------------------------------------------------------------

func _build_mobile_hud() -> void:
	var layer = CanvasLayer.new()
	layer.name = "TenCompleteHUD"
	game.add_child(layer)
	var toggle = Button.new()
	toggle.text = "WORLD MAP"
	toggle.position = Vector2(18,210)
	toggle.size = Vector2(150,48)
	toggle.pressed.connect(toggle_map)
	layer.add_child(toggle)
	var status = Label.new()
	status.name = "TenStatus"
	status.position = Vector2(18,265)
	status.size = Vector2(340,110)
	status.add_theme_font_size_override("font_size",13)
	layer.add_child(status)
	status.set_meta("owner_system",self)

func toggle_map() -> void:
	if map_open:
		if is_instance_valid(map_panel): map_panel.queue_free()
		map_panel = null
		map_open = false
		return
	map_panel = Panel.new()
	map_panel.position = Vector2(30,80)
	map_panel.size = Vector2(520,560)
	game.get_node("TenCompleteHUD").add_child(map_panel)
	map_open = true
	_refresh_map()

func _refresh_map() -> void:
	if not map_open or not is_instance_valid(map_panel):
		return
	for child in map_panel.get_children():
		child.queue_free()
	map_label = Label.new()
	map_label.position = Vector2(16,12)
	map_label.size = Vector2(480,70)
	map_label.text = "CONTINENT • DAY %d\nGold %d • Level %d • Renown %d" % [world.day,world.gold,world.player_level,int(_state()["progression"].get("renown",0))]
	map_label.add_theme_font_size_override("font_size",14)
	map_panel.add_child(map_label)
	for i in range(min(world.settlements.size(),18)):
		var s: Dictionary = world.settlements[i]
		var b = Button.new()
		b.text = "%s • %s • P%d" % [String(s.get("name","Settlement")),String(s.get("owner","")),int(s.get("prosperity",0))]
		b.position = Vector2(16 + (i%2)*245,88 + (i/2)*43)
		b.size = Vector2(235,38)
		b.pressed.connect(_select_settlement.bind(i))
		map_panel.add_child(b)
	var close = Button.new()
	close.text = "CLOSE"
	close.position = Vector2(410,515)
	close.size = Vector2(90,32)
	close.pressed.connect(toggle_map)
	map_panel.add_child(close)

func _select_settlement(id: int) -> void:
	selected_settlement = id
	if id < 0 or id >= world.settlements.size():
		return
	var s: Dictionary = world.settlements[id]
	if player != null:
		var p: Vector2 = s.get("position",Vector2.ZERO)
		player.position = Vector3(p.x,1.0,p.y+4.0)
	_add_progression_xp(5)
	_refresh_map()

func _player_army_id() -> int:
	for i in range(world.armies.size()):
		if String(world.armies[i].get("owner","")) == String(world.player_faction):
			return i
	return -1

func get_save_state() -> Dictionary:
	return _state().duplicate(true)

func load_save_state(data: Dictionary) -> void:
	if world == null or data.is_empty():
		return
	world.set_meta("ten_complete_state",data.duplicate(true))
	var loaded = _state()
	stamina = float(loaded.get("combat",{}).get("stamina",100.0))
	siege_state = loaded.get("siege",{}).duplicate(true)
