extends Node
class_name ReleaseLordIntelligence

## Combined stage: NPC lords + army intelligence.
## Each non-player faction gets commanders with distinct personalities and
## armies receive defend/attack/raid/retreat decisions before marching.

var game: Node3D
var world
var tick = 0.0
var lords: Dictionary = {}
var last_decision = "LORD INTELLIGENCE READY"

const PERSONALITIES := ["aggressive","defensive","raider","balanced"]

func build(main_node:Node3D)->void:
	game=main_node
	world=game.get("world_state")
	_seed_lords()
	set_process(true)

func _seed_lords()->void:
	if world==null: return
	for faction in world.factions:
		var id =String(faction.get("id",""))
		if id=="" or id==String(world.get("player_faction")): continue
		if lords.has(id): continue
		var seed_value =abs(id.hash())
		lords[id]={
			"name":"Lord %s" % String(faction.get("name",id)),
			"personality":PERSONALITIES[seed_value%PERSONALITIES.size()],
			"aggression":45+(seed_value%46),
			"courage":40+(seed_value%56)
		}
	for army in world.armies:
		var owner =String(army.get("owner",""))
		if owner=="" or owner==String(world.get("player_faction")): continue
		if lords.has(owner):
			army["commander"]=String(lords[owner]["name"])
			army["lord_personality"]=String(lords[owner]["personality"])
			army["max_soldiers"]=max(int(army.get("soldiers",0)),int(army.get("max_soldiers",0)))

func _process(delta:float)->void:
	if world==null:
		world=game.get("world_state")
		return
	tick+=delta
	if tick<7.0: return
	tick=0.0
	_seed_lords()
	_decide_armies()

func _decide_armies()->void:
	for i in range(world.armies.size()):
		var army:Dictionary=world.armies[i]
		var owner =String(army.get("owner",""))
		if owner=="" or owner==String(world.get("player_faction")) or not lords.has(owner): continue
		var lord:Dictionary=lords[owner]
		var personality =String(lord["personality"])
		var soldiers =int(army.get("soldiers",0))
		var morale =int(army.get("morale",50))
		var target =_nearest_enemy_settlement(owner,int(army.get("region",0)))
		var own =_nearest_owned_settlement(owner,int(army.get("region",0)))
		if morale<30 or soldiers<35:
			army["order"]="retreat"
			if own>=0: army["target_region"]=int(world.settlements[own]["region"])
			last_decision="%s retreats to recover" % army.get("name","Army")
		elif target>=0:
			var target_owner =String(world.settlements[target].get("owner",""))
			var at_war =world.get_diplomacy(owner,target_owner)=="war"
			var strength =_army_strength(army)
			var defense =int(world.settlements[target].get("garrison",0))+int(world.settlements[target].get("wall_level",1))*25
			var commit =personality=="aggressive" or (personality=="balanced" and strength>=defense) or (personality=="raider" and strength>=int(defense*0.8))
			if at_war and commit:
				army["order"]="attack"
				army["target_region"]=int(world.settlements[target]["region"])
				last_decision="%s orders an attack on %s" % [lord["name"],world.settlements[target]["name"]]
			elif at_war:
				army["order"]="defend"
				if own>=0: army["target_region"]=int(world.settlements[own]["region"])
		world.armies[i]=army

func _nearest_enemy_settlement(faction:String,from_region:int)->int:
	var best =-1
	var best_distance =INF
	for i in range(world.settlements.size()):
		var s:Dictionary=world.settlements[i]
		var owner =String(s.get("owner",""))
		if owner=="" or owner==faction or world.get_diplomacy(faction,owner)!="war": continue
		var d =abs(int(s.get("region",0))-from_region)
		if d<best_distance: best_distance=d; best=i
	return best

func _nearest_owned_settlement(faction:String,from_region:int)->int:
	var best =-1
	var best_distance =INF
	for i in range(world.settlements.size()):
		var s:Dictionary=world.settlements[i]
		if String(s.get("owner",""))!=faction: continue
		var d =abs(int(s.get("region",0))-from_region)
		if d<best_distance: best_distance=d; best=i
	return best

func _army_strength(army:Dictionary)->int:
	return int(army.get("soldiers",0))+int(army.get("troops",{}).get("horseman",0))*2

func get_state()->Dictionary:
	return {"lords":lords.duplicate(true),"last_decision":last_decision}

func get_save_state()->Dictionary:
	return get_state()

func load_save_state(data:Dictionary)->void:
	lords=data.get("lords",{}).duplicate(true)
	last_decision=String(data.get("last_decision","LORD INTELLIGENCE READY"))
