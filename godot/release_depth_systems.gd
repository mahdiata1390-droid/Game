extends Node
class_name ReleaseDepthSystems

## Deep gameplay pass: combat, siege, naval, AI, world consequences and mobile optimization.

var host: Node
var world: Node
var combat: Dictionary = {}
var siege: Dictionary = {}
var naval: Dictionary = {}
var ai_clock := 0.0
var perf_clock := 0.0
var battle_clock := 0.0
var panel: Panel
var label: Label

func build(main: Node) -> void:
	host = main
	world = main.world_state
	_build_panel()

func _process(delta: float) -> void:
	if not is_instance_valid(world) or bool(world.simulation_paused):
		return
	ai_clock += delta
	perf_clock += delta
	battle_clock += delta
	if ai_clock >= 1.0:
		ai_clock = 0.0
	_tick_army_ai()
	_tick_sieges()
	_tick_naval()
	if perf_clock >= 2.0:
		perf_clock = 0.0
	_apply_mobile_lod()
	_update_panel()

func _build_panel() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DepthSystemsLayer"
	host.add_child(layer)
	var button := Button.new()
	button.text = "DEPTH SYSTEMS"
	button.position = Vector2(1010, 515)
	button.size = Vector2(190, 42)
	button.pressed.connect(_toggle)
	layer.add_child(button)
	panel = Panel.new()
	panel.position = Vector2(300, 90)
	panel.size = Vector2(650, 500)
	panel.visible = false
	layer.add_child(panel)
	label = Label.new()
	label.position = Vector2(20, 20)
	label.size = Vector2(610, 410)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 17)
	panel.add_child(label)
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(500, 445)
	close.size = Vector2(120, 36)
	close.pressed.connect(_toggle)
	panel.add_child(close)

func _toggle() -> void:
	panel.visible = not panel.visible
	_update_panel()

func _update_panel() -> void:
	if not is_instance_valid(label):
		return
	label.text = "DEEP GAMEPLAY\n\n" + 		"Combat: %s\n" % String(combat.get("weapon","iron_sword")) + 		"Stamina: %d • Combo: %d • Battle clock: %.1fs\n" % [int(combat.get("stamina",100)), int(combat.get("combo",0)), battle_clock] + 		"Siege: %s • Gate HP: %d • Wall HP: %d\n" % [String(siege.get("state","idle")), int(siege.get("gate_hp",0)), int(siege.get("wall_hp",0))] + 		"Naval encounters resolved: %d\n" % int(naval.get("encounters",0)) + 		"AI armies evaluated: %d\n" % int(combat.get("ai_ticks",0)) + 		"Mobile LOD pass: active"

func player_strike() -> Dictionary:
	if not is_instance_valid(host.player):
		return {"ok":false,"reason":"no_player"}
	var stamina := float(combat.get("stamina",100.0))
	if stamina < 12.0:
		return {"ok":false,"reason":"exhausted"}
	var weapon := String(host.world_state.player_equipment.get("weapon","iron_sword"))
	var stats := _weapon_stats(weapon)
	var combo := int(combat.get("combo",0))
	combo = (combo % 3) + 1
	combat["combo"] = combo
	combat["stamina"] = stamina - float(stats.stamina)
	combat["weapon"] = weapon
	var target := _nearest_enemy(stats.range)
	if target == null:
		return {"ok":false,"reason":"miss"}
	var damage := int(float(stats.damage) * (1.0 + float(combo-1) * 0.12))
	host._damage_troop(target, damage)
	_apply_hit_reaction(target, stats.knockback)
	return {"ok":true,"damage":damage,"combo":combo,"weapon":weapon}

func _weapon_stats(name: String) -> Dictionary:
	match name:
		"axe":
			return {"damage":30,"range":1.8,"stamina":17,"knockback":0.25}
		"mace":
			return {"damage":27,"range":1.7,"stamina":16,"knockback":0.35}
		"spear":
			return {"damage":23,"range":2.4,"stamina":14,"knockback":0.15}
		"steel_sword":
			return {"damage":26,"range":1.9,"stamina":13,"knockback":0.18}
		_:
			return {"damage":20,"range":1.8,"stamina":12,"knockback":0.12}

func _nearest_enemy(max_range: float) -> Node3D:
	var best: Node3D
	var best_d := max_range
	for data in host.troops:
		if String(data.get("team","")) != "ENEMY":
			continue
		var node := data.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		var d := host.player.global_position.distance_to(node.global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best

func _apply_hit_reaction(target: Node3D, amount: float) -> void:
	if not is_instance_valid(target):
		return
	var start := target.position
	var tween := create_tween()
	tween.tween_property(target,"position",start + Vector3(0,0,amount),0.08)
	tween.tween_property(target,"position",start,0.12)

func _tick_army_ai() -> void:
	combat["ai_ticks"] = int(combat.get("ai_ticks",0)) + 1
	for army in world.armies:
		if int(army.get("soldiers",0)) <= 0:
			continue
		var owner := String(army.get("owner",""))
		var region := int(army.get("region",0))
		var order := String(army.get("order","hold"))
		var morale := int(army.get("morale",70))
		var food := int(army.get("food",100))
		if food < 15:
			army["order"] = "retreat"
			continue
		if morale < 25:
			army["order"] = "retreat"
			continue
		var enemies: Array[int] = []
		for n in world.get_region_neighbors(region):
			if n < 0 or n >= world.regions.size():
				continue
			var target_owner := String(world.regions[n].get("owner",""))
			if _is_war(owner,target_owner):
				enemies.append(n)
		if not enemies.is_empty() and order == "hold":
			army["order"] = "attack"
			army["target_region"] = enemies[0]
			army["moving"] = true
		elif enemies.is_empty() and order == "attack":
			army["order"] = "patrol"

func _is_war(a: String,b: String) -> bool:
	if a == b or a == "" or b == "":
		return false
	var k := a + "|" + b
	var r := b + "|" + a
	return String(world.diplomacy.get(k,world.diplomacy.get(r,"peace"))) == "war"

func start_siege(settlement_id: int) -> Dictionary:
	if settlement_id < 0 or settlement_id >= world.settlements.size():
		return {"ok":false,"reason":"invalid_settlement"}
	var s: Dictionary = world.settlements[settlement_id]
	siege = {
		"settlement_id":settlement_id,
		"state":"bombardment",
		"gate_hp":120 + int(s.get("wall_level",1))*30,
		"wall_hp":400 + int(s.get("wall_level",1))*100,
		"progress":0,
		"attacker_supply":100,
		"defender_morale":100
	}
	world.settlements[settlement_id] = s
	return {"ok":true}

func damage_siege_gate(amount: int) -> Dictionary:
	if String(siege.get("state","idle")) == "idle":
		return {"ok":false}
	siege["gate_hp"] = max(0,int(siege.get("gate_hp",0))-max(1,amount))
	if int(siege["gate_hp"]) <= 0:
		siege["state"] = "breach"
		siege["progress"] = min(100,int(siege.get("progress",0))+20)
	return {"ok":true,"gate_hp":siege["gate_hp"],"state":siege["state"]}

func damage_siege_wall(amount: int) -> Dictionary:
	if String(siege.get("state","idle")) == "idle":
		return {"ok":false}
	siege["wall_hp"] = max(0,int(siege.get("wall_hp",0))-max(1,amount))
	if int(siege["wall_hp"]) <= 0:
		siege["state"] = "breach"
		siege["progress"] = min(100,int(siege.get("progress",0))+35)
	return {"ok":true,"wall_hp":siege["wall_hp"],"state":siege["state"]}

func _tick_sieges() -> void:
	if String(siege.get("state","idle")) == "idle":
		return
	var supply := int(siege.get("attacker_supply",100))
	var morale := int(siege.get("defender_morale",100))
	supply = max(0,supply-1)
	if supply < 25:
		siege["state"] = "starving"
		siege["progress"] = max(0,int(siege.get("progress",0))-1)
	else:
		siege["progress"] = min(100,int(siege.get("progress",0))+1)
	if String(siege.get("state","")) == "breach":
		siege["progress"] = min(100,int(siege["progress"])+2)
	morale = max(0,morale-1 if String(siege.get("state","")) == "breach" else 0)
	siege["attacker_supply"] = supply
	siege["defender_morale"] = morale
	if int(siege.get("progress",0)) >= 100:
		siege["state"] = "captured"

func naval_attack(ship_id: int, target_id: int) -> Dictionary:
	if ship_id < 0 or target_id < 0 or ship_id >= world.ships.size() or target_id >= world.ships.size() or ship_id == target_id:
		return {"ok":false,"reason":"invalid_ship"}
	var a: Dictionary = world.ships[ship_id]
	var b: Dictionary = world.ships[target_id]
	var ap := int(a.get("combat_power",int(a.get("crew",10))*2))
	var bp := int(b.get("combat_power",int(b.get("crew",10))*2))
	var damage := randi_range(8,20) + int(ap/10)
	b["health"] = max(0,int(b.get("health",100))-damage)
	b["fatigue"] = min(100,int(b.get("fatigue",0))+8)
	world.ships[target_id] = b
	naval["encounters"] = int(naval.get("encounters",0))+1
	if int(b["health"]) <= 0:
		world.ships.remove_at(target_id)
	return {"ok":true,"damage":damage,"target_sunk":int(b.get("health",0))<=0}

func transport_army(ship_id: int, army_id: int) -> Dictionary:
	if ship_id < 0 or army_id < 0 or ship_id >= world.ships.size() or army_id >= world.armies.size():
		return {"ok":false}
	var ship: Dictionary = world.ships[ship_id]
	var army: Dictionary = world.armies[army_id]
	var capacity := int(ship.get("capacity",ship.get("crew",20)*3))
	var soldiers := int(army.get("soldiers",0))
	if soldiers > capacity:
		return {"ok":false,"reason":"capacity"}
	army["transported_by"] = ship_id
	army["moving"] = true
	world.armies[army_id] = army
	return {"ok":true,"capacity":capacity}

func _tick_naval() -> void:
	for ship in world.ships:
		var fatigue := int(ship.get("fatigue",0))
		var health := int(ship.get("health",100))
		if String(world.weather) == "storm":
			fatigue = min(100,fatigue+2)
			health = max(0,health-1)
		else:
			fatigue = max(0,fatigue-1)
		ship["fatigue"] = fatigue
		ship["health"] = health
		if health <= 0:
			ship["moving"] = false

func _apply_mobile_lod() -> void:
	if not is_instance_valid(host.player):
		return
	var p := host.player.global_position
	for child in host.get_children():
		if child is MeshInstance3D:
			var d := p.distance_to(child.global_position)
			child.visible = d < 85.0

func get_state() -> Dictionary:
	return {"combat":combat.duplicate(true),"siege":siege.duplicate(true),"naval":naval.duplicate(true)}

func load_state(data: Dictionary) -> void:
	combat = data.get("combat",{}).duplicate(true)
	siege = data.get("siege",{}).duplicate(true)
	naval = data.get("naval",{}).duplicate(true)
