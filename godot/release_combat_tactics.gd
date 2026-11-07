extends Node
class_name ReleaseCombatTactics

## Combat deepening: formations, morale, commander tactics and battlefield roles.
## Keeps the existing battle/siege engine intact while giving armies a live
## tactical state that can be consumed by UI, AI and future real-time combat.

var game:Node3D
var world
var tick:=0.0
var last_event:="COMBAT TACTICS READY"

const FORMATIONS:=["line","shield_wall","wedge","skirmish"]
const ORDERS:=["hold","attack","defend","raid","escort"]

func build(main_node:Node3D)->void:
	game=main_node
	world=game.get("world_state")
	_refresh_all()
	set_process(true)

func _process(delta:float)->void:
	if world==null:
		world=game.get("world_state")
		return
	tick+=delta
	if tick<6.0: return
	tick=0.0
	_refresh_all()

func _refresh_all()->void:
	for i in range(world.armies.size()):
		var army:Dictionary=world.armies[i]
		var soldiers:=int(army.get("soldiers",0))
		if soldiers<=0: continue
		var troops:Dictionary=army.get("troops",{})
		var cavalry:=int(troops.get("horseman",0))
		var archers:=int(troops.get("archer",0))
		var spears:=int(troops.get("spearman",0))
		var morale:=clampi(int(army.get("morale",60)),0,100)
		var formation:=String(army.get("formation","line"))
		var order:=String(army.get("order","hold"))

		if morale<30:
			formation="shield_wall"
			order="defend"
		elif cavalry>max(10,int(soldiers*0.18)):
			formation="wedge"
			if morale>=70: order="attack"
		elif archers>max(10,int(soldiers*0.22)):
			formation="skirmish"
			if order=="hold": order="defend"
		elif spears>max(10,int(soldiers*0.25)):
			formation="shield_wall"

		if not FORMATIONS.has(formation): formation="line"
		if not ORDERS.has(order): order="hold"
		army["formation"]=formation
		army["order"]=order
		army["morale"]=morale
		army["combat_readiness"]=_readiness(army)
		army["flank_power"]=clampi(int(cavalry*1.5)+int(morale/10),0,200)
		army["ranged_power"]=clampi(archers*2+int(morale/8),0,250)
		army["defense_power"]=clampi(spears*2+int(soldiers*0.15)+int(morale/5),0,300)
		world.armies[i]=army
	last_event="Combat formations, morale and battlefield roles updated"

func _readiness(army:Dictionary)->int:
	var soldiers:=int(army.get("soldiers",0))
	var morale:=int(army.get("morale",60))
	if soldiers<=0: return 0
	var readiness:=morale
	if String(army.get("formation","line"))=="shield_wall": readiness+=10
	elif String(army.get("formation","line"))=="wedge": readiness+=8
	elif String(army.get("formation","line"))=="skirmish": readiness+=5
	if String(army.get("order","hold"))=="attack": readiness+=5
	return clampi(readiness,0,100)

func set_tactical_order(army_id:int,formation:String,order:String)->Dictionary:
	if world==null or army_id<0 or army_id>=world.armies.size(): return {"ok":false,"reason":"invalid_army"}
	if not FORMATIONS.has(formation) or not ORDERS.has(order): return {"ok":false,"reason":"invalid_tactics"}
	world.armies[army_id]["formation"]=formation
	world.armies[army_id]["order"]=order
	last_event="Army %d: %s / %s" % [army_id,formation,order]
	return {"ok":true,"formation":formation,"order":order}

func get_army_tactics(army_id:int)->Dictionary:
	if world==null or army_id<0 or army_id>=world.armies.size(): return {}
	var army:Dictionary=world.armies[army_id]
	return {
		"formation":String(army.get("formation","line")),
		"order":String(army.get("order","hold")),
		"morale":int(army.get("morale",60)),
		"combat_readiness":int(army.get("combat_readiness",0)),
		"flank_power":int(army.get("flank_power",0)),
		"ranged_power":int(army.get("ranged_power",0)),
		"defense_power":int(army.get("defense_power",0))
	}

func get_state()->Dictionary:
	return {"last_event":last_event}

func get_save_state()->Dictionary:
	return get_state()

func load_save_state(data:Dictionary)->void:
	last_event=String(data.get("last_event","COMBAT TACTICS READY"))
