extends Node
class_name ReleaseStages20to29

# 20-24 Core character/combat pass; 25-29 living-world simulation pass.
var game:Node3D
var world:Node
var tick=0.0
var rider:Dictionary={"mounted":false,"mount_id":"","speed_bonus":0.0}
var combat:Dictionary={"weapon_class":"balanced","combo":0,"stamina":100,"block":false,"ranged_ready":true}
var units:Dictionary={}
var npc_life:Dictionary={}
var animals:Dictionary={}
var farms:Dictionary={}
var roads:Dictionary={}
var status:Label

func build(main_node:Node3D)->void:
    game=main_node
    world=game.get("world_state")
    _ui()
    set_process(true)

func _process(delta:float)->void:
    if world==null:
        world=game.get("world_state")
        return
    tick+=delta
    if tick>=4.0:
        tick=0.0
        _combat_tick()
        _world_life_tick()
        _farm_tick()
        _road_tick()
        _update_ui()

# 20 Character control / animation state
func set_character_state(state:String)->void:
    game.set_meta("character_state",state)

func get_character_state()->String:
    return String(game.get_meta("character_state","idle"))

# 21 Mount
func mount(mount_id:String)->Dictionary:
    rider={"mounted":true,"mount_id":mount_id,"speed_bonus":2.0}
    game.set_meta("player_mounted",true)
    return rider.duplicate(true)

func dismount()->void:
    rider={"mounted":false,"mount_id":"","speed_bonus":0.0}
    game.set_meta("player_mounted",false)

# 22 Deep combat state
func set_weapon_class(value:String)->void:
    combat["weapon_class"]=value
func set_blocking(value:bool)->void:
    combat["block"]=value
func combat_action(action:String)->Dictionary:
    if action=="attack":
        combat["combo"]=mini(3,int(combat["combo"])+1)
        combat["stamina"]=max(0,int(combat["stamina"])-8)
    elif action=="block":
        combat["block"]=true
        combat["stamina"]=max(0,int(combat["stamina"])-3)
    elif action=="ranged":
        combat["ranged_ready"]=false
    return combat.duplicate(true)

func _combat_tick()->void:
    combat["stamina"]=min(100,int(combat["stamina"])+4)
    if not bool(combat.get("block",false)) and int(combat.get("stamina",0))>80:
        combat["combo"]=0
    combat["ranged_ready"]=true

# 23 Unit roles / command
func register_unit_role(unit_id:String,role:String)->void:
    units[unit_id]={"role":role,"formation":"line","order":"hold","morale":70}
func command_unit(unit_id:String,formation:String,order:String)->void:
    if units.has(unit_id):
        units[unit_id]["formation"]=formation
        units[unit_id]["order"]=order

# 24 Battle command readiness
func battle_readiness(unit_ids:Array)->int:
    if unit_ids.is_empty(): return 0
    var total=0
    for id in unit_ids:
        if units.has(id): total+=int(units[id].get("morale",50))
    return int(total/max(1,unit_ids.size()))

# 25 Population life
func register_npc(npc_id:String,job:String,settlement_id:int)->void:
    npc_life[npc_id]={"job":job,"settlement":settlement_id,"state":"work","hunger":0,"morale":70}

func _world_life_tick()->void:
    for id in npc_life.keys():
        var n:Dictionary=npc_life[id]
        n["hunger"]=mini(100,int(n.get("hunger",0))+2)
        if int(n["hunger"])>80: n["morale"]=max(0,int(n.get("morale",70))-1)
        if int(world.get("day"))%3==0: n["state"]="rest" if n["state"]=="work" else "work"
        npc_life[id]=n

# 26 Animals
func register_animal(animal_id:String,species:String,settlement_id:int)->void:
    animals[animal_id]={"species":species,"settlement":settlement_id,"state":"roaming"}

# 27 Farming
func register_farm(farm_id:String,settlement_id:int,output:int)->void:
    farms[farm_id]={"settlement":settlement_id,"output":max(1,output),"condition":100}

func _farm_tick()->void:
    for id in farms.keys():
        var f:Dictionary=farms[id]
        if int(f.get("condition",100))>0:
            var sid=int(f.get("settlement",-1))
            if sid>=0 and sid<world.settlements.size():
                var s:Dictionary=world.settlements[sid]
                var r:Dictionary=s.get("resources",{})
                r["food"]=int(r.get("food",0))+int(f.get("output",1))
                s["resources"]=r

# 28 Roads / caravans
func register_road(road_id:String,a:int,b:int)->void:
    roads[road_id]={"a":a,"b":b,"condition":100,"traffic":0}
func _road_tick()->void:
    for id in roads.keys():
        var r:Dictionary=roads[id]
        r["traffic"]=max(0,int(r.get("traffic",0))-1)
        if int(r.get("traffic",0))>50: r["condition"]=max(0,int(r.get("condition",100))-1)
        roads[id]=r

# 29 Living world events
func trigger_life_event(kind:String,settlement_id:int)->void:
    if settlement_id<0 or settlement_id>=world.settlements.size(): return
    var s:Dictionary=world.settlements[settlement_id]
    match kind:
        "festival": s["prosperity"]=min(100,int(s.get("prosperity",50))+5)
        "market_day": s["prosperity"]=min(100,int(s.get("prosperity",50))+3)
        "accident": s["prosperity"]=max(0,int(s.get("prosperity",50))-2)

func _ui()->void:
    var layer=CanvasLayer.new()
    layer.name="Stages20to29UI"
    game.add_child(layer)
    var p=Panel.new()
    p.position=Vector2(18,585)
    p.size=Vector2(380,72)
    p.modulate.a=0.86
    layer.add_child(p)
    status=Label.new()
    status.position=Vector2(10,7)
    status.size=Vector2(360,58)
    status.text="20-29 • CHARACTER / COMBAT / LIVING WORLD"
    p.add_child(status)

func _update_ui()->void:
    if is_instance_valid(status):
        status.text="20-29 • Mount:%s  Stamina:%d  NPC:%d  Animals:%d  Farms:%d  Roads:%d" % [str(rider.get("mounted",false)),int(combat.get("stamina",100)),npc_life.size(),animals.size(),farms.size(),roads.size()]

func get_save_state()->Dictionary:
    return {"rider":rider.duplicate(true),"combat":combat.duplicate(true),"units":units.duplicate(true),"npc_life":npc_life.duplicate(true),"animals":animals.duplicate(true),"farms":farms.duplicate(true),"roads":roads.duplicate(true)}

func load_save_state(data:Dictionary)->void:
    rider=data.get("rider",rider).duplicate(true)
    combat=data.get("combat",combat).duplicate(true)
    units=data.get("units",{}).duplicate(true)
    npc_life=data.get("npc_life",{}).duplicate(true)
    animals=data.get("animals",{}).duplicate(true)
    farms=data.get("farms",{}).duplicate(true)
    roads=data.get("roads",{}).duplicate(true)
