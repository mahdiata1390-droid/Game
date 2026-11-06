extends Node
class_name ReleaseCombatSystem

# Stage 4: focused combat runtime. Adds readable combat states, guard/block,
# stagger, attack wind-up/recovery and lightweight combat AI on existing troops.

var game: Node3D
var world: Node
var player: CharacterBody3D
var rng = RandomNumberGenerator.new()
var states: Dictionary = {}
var fx_root: Node3D
var tick = 0.0

func build(main_node:Node3D)->void:
	game=main_node
	world=game.get("world_state")
	player=game.get("player")
	rng.seed=442211
	fx_root=Node3D.new()
	fx_root.name="CombatFeedback"
	game.add_child(fx_root)
	set_process(true)

func _process(delta:float)->void:
	if game==null:
		return
	tick+=delta
	var troops:Array=game.get("troops") if game.get("troops")!=null else []
	for entry in troops:
		var node=entry.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		var id=node.get_instance_id()
		if not states.has(id):
			states[id]={"phase":"idle","timer":0.0,"cooldown":rng.randf_range(0.1,0.8),"stagger":0.0,"blocking":false,"attack_id":0}
		var st:Dictionary=states[id]
		st["timer"]=max(0.0,float(st.get("timer",0.0))-delta)
		st["cooldown"]=max(0.0,float(st.get("cooldown",0.0))-delta)
		st["stagger"]=max(0.0,float(st.get("stagger",0.0))-delta)
		if float(st["stagger"])>0.0:
			st["phase"]="stagger"
			node.velocity=Vector3.ZERO
			states[id]=st
			continue
		var target=_nearest_enemy(node,String(entry.get("team","")))
		if target==null:
			st["phase"]="idle"
			states[id]=st
			continue
		var distance=node.global_position.distance_to(target.global_position)
		if distance>4.0:
			st["phase"]="advance"
			st["blocking"]=false
		elif float(st["cooldown"])<=0.0:
			if rng.randf()<0.18:
				st["phase"]="block"
				st["blocking"]=true
				st["timer"]=0.35
				st["cooldown"]=1.1
			else:
				st["phase"]="attack_windup"
				st["blocking"]=false
				st["timer"]=0.16
				st["attack_id"]=int(st["attack_id"])+1
				st["cooldown"]=0.9
		elif float(st["timer"])<=0.0 and String(st["phase"])=="attack_windup":
			_resolve_attack(node,target,entry)
			st["phase"]="recover"
			st["timer"]=0.28
		elif String(st["phase"])=="recover" and float(st["timer"])<=0.0:
			st["phase"]="idle"
		states[id]=st
		_animate_state(node,String(st["phase"]),delta)

func _nearest_enemy(from:Node3D,team:String)->Node3D:
	var best:Node3D
	var best_distance=4.2
	var troops:Array=game.get("troops") if game.get("troops")!=null else []
	for entry in troops:
		if String(entry.get("team",""))==team:
			continue
		var n=entry.get("node") as Node3D
		if not is_instance_valid(n):
			continue
		var d=from.global_position.distance_to(n.global_position)
		if d<best_distance:
			best_distance=d
			best=n
	return best

func _resolve_attack(attacker:Node3D,target:Node3D,entry:Dictionary)->void:
	if not is_instance_valid(target):
		return
	var damage=int(entry.get("attack_damage",18))
	var target_state:Dictionary=states.get(target.get_instance_id(),{})
	if bool(target_state.get("blocking",false)):
		damage=max(1,int(round(damage*0.35)))
		target_state["stagger"]=0.08
	else:
		target_state["stagger"]=0.22
	states[target.get_instance_id()]=target_state
	if game.has_method("_damage_troop"):
		game.call("_damage_troop",target,damage)
	_spawn_hit_feedback(target,damage)

func player_hit(target:Node3D,damage:int)->void:
	if not is_instance_valid(target):
		return
	var st:Dictionary=states.get(target.get_instance_id(),{})
	if String(st.get("phase",""))=="block" or bool(st.get("blocking",false)):
		damage=max(1,int(round(float(damage)*0.35)))
	st["stagger"]=0.18
	st["phase"]="stagger"
	states[target.get_instance_id()]=st
	_spawn_hit_feedback(target,damage)

func _animate_state(node:Node3D,phase:String,delta:float)->void:
	var t=tick
	if phase=="attack_windup":
		node.rotation.x=lerp(node.rotation.x,-0.18,0.25)
	elif phase=="recover":
		node.rotation.x=lerp(node.rotation.x,0.0,0.2)
	elif phase=="stagger":
		node.rotation.z=sin(t*35.0)*0.08
	elif phase=="block":
		node.rotation.z=lerp(node.rotation.z,0.12,0.2)
	else:
		node.rotation.x=lerp(node.rotation.x,0.0,0.12)
		node.rotation.z=lerp(node.rotation.z,0.0,0.12)

func _spawn_hit_feedback(target:Node3D,damage:int)->void:
	if not is_instance_valid(target):
		return
	var label=Label3D.new()
	label.text="-"+str(damage)
	label.font_size=22
	label.outline_size=5
	label.position=Vector3(0,2.4,0)
	target.add_child(label)
	var tween=create_tween()
	tween.tween_property(label,"position",Vector3(0,3.1,0),0.38)
	tween.parallel().tween_property(label,"modulate:a",0.0,0.38)
	tween.tween_callback(label.queue_free)

func get_combat_state(node:Node3D)->Dictionary:
	if not is_instance_valid(node):
		return {}
	return states.get(node.get_instance_id(),{}).duplicate(true)
