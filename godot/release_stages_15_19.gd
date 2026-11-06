extends Node
class_name ReleaseStages15to19

# Stages 15-19: world map, battles, siege depth, settlement gameplay, character life.
# Integrates with existing WorldState systems instead of replacing them.

var game:Node3D
var world:Node
var tick=0.0
var battle:Dictionary={}
var settlement_states:Dictionary={}
var character_states:Dictionary={}
var discovered:Dictionary={}
var map_status:Label
var life_status:Label

func build(main_node:Node3D)->void:
    game=main_node
    world=game.get("world_state")
    _build_ui()
    set_process(true)

func _process(delta:float)->void:
    if world==null:
        world=game.get("world_state")
        return
    tick+=delta
    if tick>=5.0:
        tick=0.0
        _map_tick()
        _battle_tick()
        _siege_tick()
        _settlement_tick()
        _character_tick()
        _update_ui()

# 15 — World map / strategic layer
func discover_region(region_id:String)->void:
    discovered[region_id]=true

func is_region_discovered(region_id:String)->bool:
    return bool(discovered.get(region_id,false))

func get_map_state()->Dictionary:
    return {"discovered":discovered.duplicate(true),"player_region":String(world.get("player_region_id"))}

func _map_tick()->void:
    var current=String(world.get("player_region_id"))
    if current!="":
        discovered[current]=true
    var route=world.get_meta("player_travel_route",[])
    if route is Array and not route.is_empty():
        for r in route:
            discovered[String(r)]=true

# 16 — Battle layer
func start_battle(attacker:String,defender:String,attacker_force:int,defender_force:int)->Dictionary:
    battle={"active":true,"attacker":attacker,"defender":defender,
        "attacker_force":max(1,attacker_force),"defender_force":max(1,defender_force),
        "attacker_casualties":0,"defender_casualties":0,"round":0}
    return battle.duplicate(true)

func resolve_battle()->Dictionary:
    if not battle.get("active",false):
        return {"ok":false}
    var af=int(battle["attacker_force"])
    var df=int(battle["defender_force"])
    var winner="attacker" if af>=df else "defender"
    var loss_a=clampi(int(af*0.18 if winner=="attacker" else af*0.30),0,af)
    var loss_d=clampi(int(df*0.30 if winner=="attacker" else df*0.18),0,df)
    battle["attacker_casualties"]=loss_a
    battle["defender_casualties"]=loss_d
    battle["winner"]=winner
    battle["active"]=false
    battle["round"]+=1
    return battle.duplicate(true)

func _battle_tick()->void:
    if battle.get("active",false):
        battle["round"]=int(battle.get("round",0))+1
        if int(battle["round"])>=6:
            resolve_battle()

# 17 — Siege depth
func reinforce_siege(siege_id:String,supply:int)->void:
    var s=world.get_meta("siege_"+siege_id,{})
    if s is Dictionary:
        s["attacker_supply"]=int(s.get("attacker_supply",0))+max(0,supply)
        world.set_meta("siege_"+siege_id,s)

func siege_pressure(siege_id:String)->int:
    var s=world.get_meta("siege_"+siege_id,{})
    if s is Dictionary:
        return clampi(int(s.get("progress",0))+int(s.get("attacker_supply",0))/10,0,100)
    return 0

func _siege_tick()->void:
    for s in world.settlements:
        if bool(s.get("under_siege",false)):
            var supply=int(s.get("siege_supply",100))
            s["siege_supply"]=max(0,supply-1)
            if s["siege_supply"]==0:
                s["prosperity"]=max(0,int(s.get("prosperity",50))-2)

# 18 — Settlement gameplay
func get_settlement_services(settlement_id:int)->Dictionary:
    if settlement_id<0 or settlement_id>=world.settlements.size(): return {}
    var s:Dictionary=world.settlements[settlement_id]
    var type=String(s.get("type","village")).to_lower()
    var services={"market":true,"farm":true,"inn":type!="village",
        "barracks":type=="town" or type=="city" or type=="castle",
        "keep":type=="castle","workshop":type!="village"}
    return services

func upgrade_settlement(settlement_id:int,service:String)->Dictionary:
    if settlement_id<0 or settlement_id>=world.settlements.size(): return {"ok":false}
    var s:Dictionary=world.settlements[settlement_id]
    var levels:Dictionary=s.get("service_levels",{})
    var old=int(levels.get(service,0))
    var cost=80+old*60
    var gold=int(world.get("gold"))
    if gold<cost: return {"ok":false,"reason":"insufficient_gold","cost":cost}
    world.set("gold",gold-cost)
    levels[service]=old+1
    s["service_levels"]=levels
    s["prosperity"]=min(100,int(s.get("prosperity",50))+3)
    return {"ok":true,"level":old+1,"cost":cost}

func _settlement_tick()->void:
    for i in range(world.settlements.size()):
        var s:Dictionary=world.settlements[i]
        var id=str(i)
        settlement_states[id]={"prosperity":int(s.get("prosperity",50)),
            "services":get_settlement_services(i)}
        if int(s.get("prosperity",50))>80:
            s["population"]=int(s.get("population",100))+1

# 19 — Character life
func register_character(id:String,name:String,role:String,age:int)->void:
    character_states[id]={"name":name,"role":role,"age":age,"health":100,"loyalty":70,"alive":true}

func get_character(id:String)->Dictionary:
    return character_states.get(id,{}).duplicate(true)

func _character_tick()->void:
    for id in character_states.keys():
        var c:Dictionary=character_states[id]
        if not bool(c.get("alive",true)): continue
        c["health"]=clampi(int(c.get("health",100)),0,100)
        c["loyalty"]=clampi(int(c.get("loyalty",70)),0,100)
        character_states[id]=c

func _build_ui()->void:
    var layer=CanvasLayer.new()
    layer.name="Stages15to19UI"
    game.add_child(layer)
    var panel=Panel.new()
    panel.position=Vector2(18,500)
    panel.size=Vector2(360,80)
    panel.modulate.a=0.86
    layer.add_child(panel)
    map_status=Label.new()
    map_status.position=Vector2(10,8)
    map_status.size=Vector2(340,60)
    map_status.text="STAGES 15-19 • MAP / BATTLE / SIEGE / SETTLEMENT / LIFE"
    panel.add_child(map_status)

func _update_ui()->void:
    if not is_instance_valid(map_status): return
    var active=bool(battle.get("active",false))
    map_status.text="MAP • discovered %d | battle %s | settlements %d | characters %d" % [discovered.size(),"ACTIVE" if active else "READY",settlement_states.size(),character_states.size()]

func get_save_state()->Dictionary:
    return {"battle":battle.duplicate(true),"settlement_states":settlement_states.duplicate(true),
        "character_states":character_states.duplicate(true),"discovered":discovered.duplicate(true)}

func load_save_state(data:Dictionary)->void:
    battle=data.get("battle",{}).duplicate(true)
    settlement_states=data.get("settlement_states",{}).duplicate(true)
    character_states=data.get("character_states",{}).duplicate(true)
    discovered=data.get("discovered",{}).duplicate(true)
