extends Node
class_name ReleaseFinalCompletion

# Final integrated gameplay layer.
# It deepens the ten remaining pillars without replacing WorldState.
# WorldState stays authoritative; this node owns runtime controllers and
# deterministic presentation state.

var game: Node3D
var world: Node
var player: CharacterBody3D
var rng := RandomNumberGenerator.new()
var combat := {"cooldown":0.0,"parry_window":0.0,"stamina":100.0,"max_stamina":100.0,"combo":0,"weapon":"iron_sword"}
var projectiles:Array[Node3D] = []
var npc_jobs:Array[Dictionary] = []
var npc_visuals:Array[Node3D] = []
var settlement_runtime:Dictionary = {}
var animation_nodes:Array[Node] = []
var siege_runtime:Dictionary = {}
var naval_runtime:Dictionary = {}
var qa:Dictionary = {"checks":0,"warnings":0,"errors":0,"last":[]}
var tick:=0.0
var strategic_tick:=0.0
var life_tick:=0.0

func build(main_node:Node3D)->void:
	game=main_node
	world=game.get("world_state")
	player=game.get("player")
	rng.seed=918273
	_restore_state()
	_setup_runtime_animation()
	_setup_npc_jobs()
	_setup_settlement_runtime()
	set_process(true)

func _process(delta:float)->void:
	if world==null or player==null:
		return
	combat["cooldown"]=max(0.0,float(combat["cooldown"])-delta)
	combat["parry_window"]=max(0.0,float(combat["parry_window"])-delta)
	combat["stamina"]=min(float(combat["max_stamina"]),float(combat["stamina"])+18.0*delta)
	tick+=delta
	strategic_tick+=delta
	life_tick+=delta
	_update_projectiles(delta)
	_update_runtime_animation(delta)
	if npc_visuals.is_empty() and game.has_node("ProductionAssetIntegration"):
		var integration:Node = game.get_node("ProductionAssetIntegration")
		if integration.has_method("get_role_nodes"):
			bind_npc_visuals(integration.call("get_role_nodes","characters_extra"))
	if strategic_tick>=4.0:
		strategic_tick=0.0
		_strategic_ai_tick()
	if life_tick>=6.0:
		life_tick=0.0
		_life_world_tick()
		_update_npc_jobs()
		_update_settlement_runtime()
	if tick>=12.0:
		tick=0.0
		run_qa()

# ---------------------------------------------------------------------------
# 1) Combat + animation
# ---------------------------------------------------------------------------

func attack(weapon:String="")->Dictionary:
	if player==null or float(combat["cooldown"])>0.0:
		return {"ok":false,"reason":"cooldown"}
	if weapon!="":
		combat["weapon"]=weapon
	var stats={"iron_sword":[22.0,1.0,2.0],"steel_sword":[30.0,1.1,2.1],"axe":[34.0,1.35,1.7],"mace":[32.0,1.4,1.6],"spear":[26.0,1.15,2.8]}
	var w:Array=stats.get(String(combat["weapon"]),stats["iron_sword"])
	var cost=float(w[1])*10.0
	if float(combat["stamina"])<cost:
		return {"ok":false,"reason":"stamina"}
	combat["stamina"]-=cost
	combat["cooldown"]=0.42*float(w[1])
	combat["parry_window"]=0.16
	combat["combo"]=(int(combat["combo"])+1)%3
	var target:=_nearest_enemy(float(w[2])+0.8)
	var damage:=int(round(float(w[0])*(1.0+float(combat["combo"])*0.12)))
	if target!=null:
		play_attack_animation()
		if game.has_method("_damage_troop"):
			game.call("_damage_troop",target,damage)
		target.set_meta("hit_stun",0.22)
		_add_xp(max(2,damage/4))
	return {"ok":true,"hit":target!=null,"damage":damage,"combo":int(combat["combo"])}

func begin_block()->void:
	combat["parry_window"]=0.22
	combat["blocking"]=true

func end_block()->void:
	combat["blocking"]=false

func receive_attack(raw_damage:int)->int:
	var damage=max(0,raw_damage)
	if bool(combat.get("blocking",false)):
		if float(combat["parry_window"])>0.0:
			damage=0
			_add_xp(8)
		else:
			damage=int(round(float(damage)*0.35))
	if game!=null:
		var hp=int(game.get("player_hp"))
		game.set("player_hp",max(0,hp-damage))
	return damage

func ranged_attack()->Dictionary:
	if player==null or float(combat["stamina"])<18.0:
		return {"ok":false,"reason":"stamina"}
	var target:=_nearest_enemy(24.0)
	if target==null:
		return {"ok":true,"hit":false}
	combat["stamina"]-=18.0
	var p:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(0.06,0.06,0.42)
	p.mesh=mesh
	p.global_position=player.global_position+Vector3(0,1.25,0)
	p.look_at(target.global_position+Vector3(0,1.0,0),Vector3.UP)
	p.set_meta("target",target)
	p.set_meta("damage",24)
	game.add_child(p)
	projectiles.append(p)
	return {"ok":true,"hit":true}

func _update_projectiles(delta:float)->void:
	for i in range(projectiles.size()-1,-1,-1):
		var p:=projectiles[i]
		if not is_instance_valid(p):
			projectiles.remove_at(i)
			continue
		var target:=p.get_meta("target") as Node3D
		if not is_instance_valid(target):
			p.queue_free(); projectiles.remove_at(i); continue
		var dst:=target.global_position+Vector3(0,1.0,0)
		p.global_position=p.global_position.move_toward(dst,22.0*delta)
		if p.global_position.distance_to(dst)<0.35:
			if game.has_method("_damage_troop"):
				game.call("_damage_troop",target,int(p.get_meta("damage")))
			p.queue_free()
			projectiles.remove_at(i)

func _nearest_enemy(max_distance:float)->Node3D:
	var best:Node3D
	var best_distance:=max_distance
	var troops:Array=game.get("troops") if game.get("troops")!=null else []
	for entry in troops:
		if String(entry.get("team",""))!="ENEMY":
			continue
		var node:=entry.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		var d:=player.global_position.distance_to(node.global_position)
		if d<best_distance:
			best_distance=d
			best=node
	return best

func _setup_runtime_animation()->void:
	# Uses AnimationPlayer tracks on existing player children, so no external
	# asset is required and the character gets visible attack/hit locomotion.
	if player==null:
		return
	var ap:=player.get_node_or_null("FinalAnimationPlayer") as AnimationPlayer
	if ap==null:
		ap=AnimationPlayer.new()
		ap.name="FinalAnimationPlayer"
		player.add_child(ap)
	var lib:=AnimationLibrary.new()
	var attack_anim:=Animation.new()
	attack_anim.length=0.36
	var track:=attack_anim.add_track(Animation.TYPE_ROTATION_3D)
	attack_anim.track_set_path(track,NodePath("."))
	attack_anim.track_insert_key(track,0.0,Quaternion.from_euler(Vector3(0,0,0)))
	attack_anim.track_insert_key(track,0.12,Quaternion.from_euler(Vector3(-0.08,0.25,0)))
	attack_anim.track_insert_key(track,0.28,Quaternion.from_euler(Vector3(0.05,-0.18,0)))
	attack_anim.track_insert_key(track,0.36,Quaternion.IDENTITY)
	lib.add_animation("attack",attack_anim)
	ap.add_animation_library("",lib)
	animation_nodes.append(ap)

func play_attack_animation()->void:
	var ap:=player.get_node_or_null("FinalAnimationPlayer") as AnimationPlayer
	if ap!=null:
		ap.play("attack")

# ---------------------------------------------------------------------------
# 2) Siege
# ---------------------------------------------------------------------------

func start_siege(settlement_id:int)->Dictionary:
	if world==null or settlement_id<0 or settlement_id>=world.settlements.size():
		return {"ok":false,"reason":"invalid_settlement"}
	var army_id:=_player_army_id()
	if army_id<0 or not world.has_method("start_siege"):
		return {"ok":false,"reason":"no_army"}
	var result:Dictionary=world.start_siege(settlement_id,army_id)
	if not bool(result.get("ok",false)):
		return result
	var s:Dictionary=world.settlements[settlement_id]
	siege_runtime={"settlement":settlement_id,"wall_hp":max(100,int(s.get("wall_level",1))*180),"gate_hp":140,"breach":false,"equipment":{"ram":1,"catapult":1,"tower":1,"ladder":4}}
	_spawn_siege_equipment()
	return {"ok":true,"settlement":s.get("name","Settlement")}

func use_siege_equipment(kind:String)->Dictionary:
	if not siege_runtime.has("settlement"):
		return {"ok":false,"reason":"no_siege"}
	var damage={"ram":32,"catapult":48,"tower":18,"ladder":10}.get(kind,0)
	if damage==0:
		return {"ok":false,"reason":"invalid_equipment"}
	var equipment:Dictionary=siege_runtime["equipment"]
	if int(equipment.get(kind,0))<=0:
		return {"ok":false,"reason":"out_of_equipment"}
	equipment[kind]=int(equipment[kind])-1
	if kind=="ram":
		siege_runtime["gate_hp"]=max(0,int(siege_runtime["gate_hp"])-damage)
	else:
		siege_runtime["wall_hp"]=max(0,int(siege_runtime["wall_hp"])-damage)
	siege_runtime["breach"]=int(siege_runtime["gate_hp"])<=0 or int(siege_runtime["wall_hp"])<=40
	if siege_runtime["breach"]:
		_mark_siege_breach(int(siege_runtime["settlement"]))
	return {"ok":true,"breach":bool(siege_runtime["breach"]),"wall_hp":int(siege_runtime["wall_hp"]),"gate_hp":int(siege_runtime["gate_hp"])}

func _spawn_siege_equipment()->void:
	var root:=Node3D.new()
	root.name="FinalSiegeEquipment"
	game.add_child(root)
	for spec in [["Ram",Vector3(2,0.7,1),Vector3(-3,0.35,-2)],["Catapult",Vector3(1.5,1.0,1.2),Vector3(3,0.5,-2)],["Tower",Vector3(1.6,4.0,1.6),Vector3(0,2,-4)]]:
		var n:=MeshInstance3D.new()
		var m:=BoxMesh.new()
		m.size=spec[1]
		n.mesh=m
		n.position=spec[2]
		var mat:=StandardMaterial3D.new()
		mat.albedo_color=Color(0.28,0.18,0.10)
		n.material_override=mat
		root.add_child(n)

func _mark_siege_breach(settlement_id:int)->void:
	if settlement_id<0 or settlement_id>=world.settlements.size():
		return
	var s:Dictionary=world.settlements[settlement_id]
	s["breached"]=true
	s["wall_integrity"]=0
	s["siege_phase"]="breach"

func _player_army_id()->int:
	for i in range(world.armies.size()):
		if String(world.armies[i].get("owner",""))==String(world.player_faction):
			return i
	return -1

# ---------------------------------------------------------------------------
# 3) Strategic AI + diplomacy
# ---------------------------------------------------------------------------

func _strategic_ai_tick()->void:
	if world==null:
		return
	for i in range(world.armies.size()):
		var army:Dictionary=world.armies[i]
		var owner:=String(army.get("owner",""))
		if owner==String(world.player_faction):
			continue
		var morale:=int(army.get("morale",50))
		var food:=int(army.get("food",0))
		var region_id:=int(army.get("region",0))
		if morale<30 or food<15:
			army["order"]="retreat"
			var neighbors:Array=world.get_region_neighbors(region_id)
			if not neighbors.is_empty():
				army["region"]=neighbors[rng.randi_range(0,neighbors.size()-1)]
			continue
		var target:=_best_hostile_region(owner,region_id)
		if target>=0 and int(army.get("soldiers",0))>=70:
			army["order"]="attack"
			army["target_region"]=target
			army["region"]=target
			army["food"]=max(0,food-7)
		else:
			army["order"]="patrol"
	# Diplomatic drift makes the sandbox evolve even when the player does nothing.
	for key in world.diplomacy.keys():
		var state:=String(world.diplomacy[key])
		if state=="war" and rng.randf()<0.08:
			world.diplomacy[key]="peace"
		elif state=="peace" and rng.randf()<0.035:
			world.diplomacy[key]="war"

func _best_hostile_region(owner:String,region_id:int)->int:
	var best:=-1
	var best_score:=-99999
	for rid in world.get_region_neighbors(region_id):
		var other:=String(world.regions[rid].get("owner",""))
		if other==owner:
			continue
		var relation:=_relation(owner,other)
		if relation>=0:
			continue
		var score:=int(world.regions[rid].get("prosperity",0))+int(world.regions[rid].get("population",0))/100
		if score>best_score:
			best_score=score
			best=rid
	return best

func _relation(a:String,b:String)->int:
	if a==b:
		return 100
	var fa:=world._get_faction(a)
	if fa.is_empty():
		return 0
	return int(fa.get("relations",{}).get(b,0))

# ---------------------------------------------------------------------------
# 4) Economy + trade
# ---------------------------------------------------------------------------

func trade_with_settlement(settlement_id:int,resource:String,amount:int,buy:bool)->Dictionary:
	if settlement_id<0 or settlement_id>=world.settlements.size() or amount<=0:
		return {"ok":false}
	if not ["food","wood","iron","horses","spice"].has(resource):
		return {"ok":false}
	var s:Dictionary=world.settlements[settlement_id]
	var stock:Dictionary=s.get("stockpile",{})
	var prosperity:=int(s.get("prosperity",50))
	var base:=float({"food":1.0,"wood":1.4,"iron":2.2,"horses":4.0,"spice":3.0}.get(resource,1.0))
	var scarcity:=clamp(1.0+(float(60-int(stock.get(resource,0)))/100.0),0.65,2.2)
	var price:=max(1.0,base*scarcity*(1.0+(50.0-float(prosperity))/300.0))
	if buy:
		var available:=min(amount,int(stock.get(resource,0)))
		var cost:=int(ceil(price*available))
		if available<=0 or world.gold<cost:
			return {"ok":false,"reason":"unavailable","price":price}
		world.gold-=cost
		stock[resource]=int(stock.get(resource,0))-available
		world.player_inventory[resource]=int(world.player_inventory.get(resource,0))+available
		return {"ok":true,"amount":available,"cost":cost,"price":price}
	var owned:=min(amount,int(world.player_inventory.get(resource,0)))
	var gain:=int(floor(price*0.82*owned))
	if owned<=0:
		return {"ok":false,"reason":"no_stock"}
	world.player_inventory[resource]=int(world.player_inventory.get(resource,0))-owned
	stock[resource]=int(stock.get(resource,0))+owned
	world.gold+=gain
	return {"ok":true,"amount":owned,"gain":gain,"price":price}

# ---------------------------------------------------------------------------
# 5) Naval combat + boarding
# ---------------------------------------------------------------------------

func board_ship(attacker_id:int,target_id:int)->Dictionary:
	if attacker_id<0 or target_id<0 or attacker_id>=world.ships.size() or target_id>=world.ships.size():
		return {"ok":false}
	var a:Dictionary=world.ships[attacker_id]
	var b:Dictionary=world.ships[target_id]
	var attack_power:=int(a.get("crew",0))+int(a.get("cargo",{}).get("iron",0))*2
	var defense_power:=int(b.get("crew",0))+int(b.get("cargo",{}).get("iron",0))
	var win:=attack_power>=defense_power
	naval_runtime["boarding"]={"attacker":attacker_id,"target":target_id,"won":win}
	if win:
		var loot:Dictionary=b.get("cargo",{}).duplicate(true)
		world.gold+=int(loot.get("food",0))+int(loot.get("wood",0))*2+int(loot.get("iron",0))*3
		world.ships.remove_at(target_id)
		return {"ok":true,"won":true,"loot":loot}
	a["crew"]=max(0,int(a.get("crew",0))-max(1,int(defense_power/5)))
	return {"ok":true,"won":false}

func resolve_ship_travel(ship_id:int)->Dictionary:
	if ship_id<0 or ship_id>=world.ships.size():
		return {"ok":false}
	var ship:Dictionary=world.ships[ship_id]
	if not bool(ship.get("moving",false)):
		return {"ok":true,"moving":false}
	var target:=int(ship.get("target_region",ship.get("region",0)))
	ship["region"]=target
	ship["moving"]=false
	ship["fatigue"]=min(100,int(ship.get("fatigue",0))+12)
	if ship.has("cargo") and ship["cargo"].has("army"):
		var army_id:=int(ship["cargo"]["army"])
		if army_id>=0 and army_id<world.armies.size():
			world.armies[army_id]["region"]=target
			world.armies[army_id]["transported_by"]=-1
		ship["cargo"].erase("army")
	return {"ok":true,"region":target}

# ---------------------------------------------------------------------------
# 6) Family + generations
# ---------------------------------------------------------------------------

func advance_family_day()->void:
	var fam:Dictionary=world.family
	fam["age"]=int(fam.get("age",18))+1 if world.day%365==0 else int(fam.get("age",18))
	for member in world.family_members:
		member["age"]=int(member.get("age",0))+1 if world.day%365==0 else int(member.get("age",0))
		if int(member["age"])>=16 and String(member.get("role",""))=="child":
			member["role"]="adult"
		if int(member["age"])>=18:
			member["loyalty"]=clamp(int(member.get("loyalty",70))+rng.randi_range(-2,2),0,100)
	world.family=fam
	_update_heir()

func _update_heir()->void:
	var best_name:="Unnamed Heir"
	var best_age:=-1
	for member in world.family_members:
		if String(member.get("role",""))=="adult" and int(member.get("age",0))>best_age:
			best_age=int(member["age"])
			best_name=String(member.get("name","Heir"))
	world.family["heir_name"]=best_name
	world.family["heir_age"]=max(0,best_age)

func succession()->Dictionary:
	_update_heir()
	if int(world.family.get("heir_age",0))<16:
		return {"ok":false,"reason":"no_ready_heir"}
	world.player_level=max(1,world.player_level)
	world.player_faction=String(world.player_faction)
	world.family["generation"]=int(world.family.get("generation",1))+1
	return {"ok":true,"heir":world.family.get("heir_name","Heir"),"generation":world.family["generation"]}

# ---------------------------------------------------------------------------
# 7) Progression
# ---------------------------------------------------------------------------

func _add_xp(amount:int)->void:
	if amount<=0:
		return
	world.player_xp+=amount
	while world.player_xp>=world.player_level*120:
		world.player_xp-=world.player_level*120
		world.player_level+=1
		world.set_meta("final_skill_points",int(world.get_meta("final_skill_points",0))+2)

func spend_skill(skill:String)->Dictionary:
	if not ["combat","command","trade","diplomacy","survival"].has(skill):
		return {"ok":false}
	var points:=int(world.get_meta("final_skill_points",0))
	if points<=0:
		return {"ok":false,"reason":"no_points"}
	world.set_meta("final_skill_points",points-1)
	var levels:Dictionary=world.get_meta("final_skills") if world.has_meta("final_skills") else {}
	levels[skill]=int(levels.get(skill,0))+1
	world.set_meta("final_skills",levels)
	return {"ok":true,"skill":skill,"level":levels[skill]}

# ---------------------------------------------------------------------------
# 8) Living world
# ---------------------------------------------------------------------------

func _setup_npc_jobs()->void:
	npc_jobs.clear()
	npc_visuals.clear()
	if world==null:
		return
	for i in range(min(60,world.settlements.size()*3)):
		var s:Dictionary=world.settlements[i%world.settlements.size()]
		var job := ["farmer","merchant","guard","craftsman"][i%4]
		npc_jobs.append({"settlement":int(s["id"]),"job":job,"shift":i%3,"x":float(s["position"].x)+rng.randf_range(-3,3),"z":float(s["position"].y)+rng.randf_range(-3,3),"target":"farm" if job=="farmer" else ("market" if job=="merchant" else ("gate" if job=="guard" else "workshop"))})

func _update_npc_jobs()->void:
	for npc in npc_jobs:
		var sid:=int(npc["settlement"])
		if sid<0 or sid>=world.settlements.size():
			continue
		var s:Dictionary=world.settlements[sid]
		var center:Vector2=s.get("position",Vector2.ZERO)
		var target:=Vector3(center.x+float(npc["x"])-float(center.x),0,center.y+float(npc["z"])-float(center.y))
		npc["x"]=clamp(float(npc["x"])+rng.randf_range(-0.45,0.45),float(center.x)-3.5,float(center.x)+3.5)
		npc["z"]=clamp(float(npc["z"])+rng.randf_range(-0.45,0.45),float(center.y)-3.5,float(center.y)+3.5)
		var visual:Node3D = npc.get("visual") as Node3D
		if is_instance_valid(visual):
			visual.position = Vector3(float(npc["x"]), 0.0, float(npc["z"]))
			visual.rotation.y = atan2(float(npc["z"])-center.y, float(npc["x"])-center.x)
		# Jobs feed the real settlement economy.
		if String(npc["job"])=="farmer":
			s["stockpile"]["food"]=int(s["stockpile"].get("food",0))+1
		elif String(npc["job"])=="merchant":
			s["prosperity"]=clamp(int(s.get("prosperity",50))+1,0,100)
		elif String(npc["job"])=="craftsman":
			s["stockpile"]["wood"]=int(s["stockpile"].get("wood",0))+1

func _setup_settlement_runtime()->void:
	settlement_runtime.clear()
	for s in world.settlements:
		var sid:=int(s.get("id",settlement_runtime.size()))
		var kind:=String(s.get("type","village"))
		settlement_runtime[sid]={
			"services":["well","market","farm","workshop"] if kind=="village" else (["well","inn","market","guild","blacksmith","barracks"] if kind=="town" else (["market","guild","tavern","blacksmith","barracks","keep","armory","training_yard"] if kind=="castle" else ["market","guild","tavern","blacksmith","barracks","keep","armory","training_yard","farm","workshop"])),
			"port": kind=="town" and (sid%5==0 or sid==11),
			"fortification": int(s.get("wall_level",1))*100,
			"open": true
		}

func _update_settlement_runtime()->void:
	for sid in settlement_runtime.keys():
		if sid<0 or sid>=world.settlements.size():
			continue
		var s:Dictionary=world.settlements[int(sid)]
		var rt:Dictionary=settlement_runtime[sid]
		var night:=world.time_of_day>=22.0 or world.time_of_day<6.0
		rt["open"]=not night or rt["services"].has("tavern")
		if bool(rt["port"]):
			s["prosperity"]=clamp(int(s.get("prosperity",50))+(1 if world.weather!="storm" else -2),0,100)
		if int(s.get("wall_level",1))>1:
			rt["fortification"]=max(0,int(s.get("wall_level",1))*100-int(s.get("siege_damage",0)))

func bind_npc_visuals(nodes:Array)->void:
	npc_visuals.clear()
	for node in nodes:
		if node is Node3D and is_instance_valid(node):
			npc_visuals.append(node)
	for i in range(min(npc_visuals.size(),npc_jobs.size())):
		npc_jobs[i]["visual"]=npc_visuals[i]
		var s:=world.settlements[int(npc_jobs[i]["settlement"])]
		npc_visuals[i].position=Vector3(float(npc_jobs[i]["x"]),0.0,float(npc_jobs[i]["z"]))

func get_settlement_services(settlement_id:int)->Dictionary:
	return settlement_runtime.get(settlement_id,{}).duplicate(true)

func get_settlement_status(settlement_id:int)->Dictionary:
	if settlement_id<0 or settlement_id>=world.settlements.size():
		return {}
	var s:Dictionary=world.settlements[settlement_id]
	var rt:Dictionary=settlement_runtime.get(settlement_id,{})
	return {"name":s.get("name",""),"type":s.get("type","village"),"owner":s.get("owner",""),"population":s.get("population",0),"prosperity":s.get("prosperity",0),"garrison":s.get("garrison",0),"services":rt.get("services",[]),"port":rt.get("port",false),"open":rt.get("open",true),"fortification":rt.get("fortification",0)}

func _life_world_tick()->void:
	advance_family_day()
	for s in world.settlements:
		var pop:=int(s.get("population",100))
		var prosperity:=int(s.get("prosperity",50))
		s["population"]=pop+max(1,int(pop*0.0015*(0.5+float(prosperity)/100.0)))
		if prosperity<20:
			s["population"]=max(20,int(s["population"])-1)
	if rng.randf()<0.12 and not world.world_events.is_empty():
		world.world_events.append("A local festival, market day, or caravan changed settlement activity.")

# ---------------------------------------------------------------------------
# 9) World map + fog + route
# ---------------------------------------------------------------------------

func reveal_region(region_id:int)->void:
	var discovered:Array=world.get_meta("final_discovered",[]) 
	if not discovered.has(region_id):
		discovered.append(region_id)
	world.set_meta("final_discovered",discovered)

func route_to_region(from_id:int,to_id:int)->Array:
	if from_id<0 or to_id<0 or from_id>=world.regions.size() or to_id>=world.regions.size():
		return []
	if from_id==to_id:
		return [from_id]
	var queue:Array=[from_id]
	var previous:Dictionary={from_id:-1}
	while not queue.is_empty():
		var current:int=queue.pop_front()
		for n in world.get_region_neighbors(current):
			if previous.has(n):
				continue
			previous[n]=current
			if n==to_id:
				var path:Array=[to_id]
				var c:=to_id
				while int(previous[c])!=-1:
					c=int(previous[c])
					path.push_front(c)
				return path
			queue.append(n)
	return []

func travel_route(to_id:int)->Dictionary:
	var path:=route_to_region(int(world.player_region_id),to_id)
	if path.is_empty():
		return {"ok":false,"reason":"no_route"}
	for i in range(1,path.size()):
		world.player_region_id=int(path[i])
		world.advance_day()
		reveal_region(int(path[i]))
	return {"ok":true,"path":path,"days":max(0,path.size()-1)}

# ---------------------------------------------------------------------------
# 10) QA + save state
# ---------------------------------------------------------------------------

func run_qa()->Dictionary:
	qa["checks"]=0
	qa["warnings"]=0
	qa["errors"]=0
	var notes:Array=[]
	_check(world!=null,"WorldState connected",notes)
	_check(world!=null and world.regions.size()>0,"Regions populated",notes)
	_check(world!=null and world.settlements.size()>=12,"Settlements populated",notes)
	_check(world!=null and world.armies.size()>0,"Armies populated",notes)
	_check(world!=null and world.ships.size()>0,"Naval database populated",notes)
	_check(player!=null,"Player connected",notes)
	_check(float(combat["stamina"])>=0.0,"Combat stamina valid",notes)
	_check(float(combat["stamina"])<=float(combat["max_stamina"])+0.01,"Combat stamina bounded",notes)
	_check(world.settlements.all(func(x): return x.has("stockpile")),"Settlement stockpiles valid",notes)
	_check(world.armies.all(func(x): return x.has("morale") and x.has("soldiers")),"Army state valid",notes)
	_check(world.ships.all(func(x): return x.has("crew") and x.has("cargo")),"Ship state valid",notes)
	_check(settlement_runtime.size()==world.settlements.size(),"Settlement runtime services synchronized",notes)
	qa["last"]=notes
	return qa.duplicate(true)

func _check(condition:bool,label:String,notes:Array)->void:
	qa["checks"]=int(qa["checks"])+1
	if not condition:
		qa["errors"]=int(qa["errors"])+1
		notes.append("ERROR: "+label)
	else:
		notes.append("OK: "+label)

func get_save_state()->Dictionary:
	return {"combat":combat.duplicate(true),"siege":siege_runtime.duplicate(true),"naval":naval_runtime.duplicate(true),"qa":qa.duplicate(true),"skill_points":int(world.get_meta("final_skill_points",0)),"skills":world.get_meta("final_skills",{}).duplicate(true),"discovered":world.get_meta("final_discovered",[])}

func load_save_state(data:Dictionary)->void:
	if world==null or data.is_empty():
		return
	combat=data.get("combat",combat).duplicate(true)
	siege_runtime=data.get("siege",{}).duplicate(true)
	naval_runtime=data.get("naval",{}).duplicate(true)
	qa=data.get("qa",qa).duplicate(true)
	world.set_meta("final_skill_points",int(data.get("skill_points",0)))
	world.set_meta("final_skills",data.get("skills",{}).duplicate(true))
	world.set_meta("final_discovered",data.get("discovered",[]))
