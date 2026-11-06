extends Node
class_name ReleaseStages30to39

# 30-39 governance, economy and large-scale war simulation.
var game:Node3D
var world:Node
var tick=0.0
var ministers:Dictionary={}
var governors:Dictionary={}
var houses:Dictionary={}
var economy:Dictionary={"prices":{},"trade_routes":{}}
var wars:Dictionary={}
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
    if tick>=7.0:
        tick=0.0
        _governance_tick()
        _economy_tick()
        _war_tick()
        _update_ui()

# 30-34 Government and dynasty
func appoint_minister(id:String,portfolio:String)->void:
    ministers[id]={"portfolio":portfolio,"loyalty":70,"skill":50}
func appoint_governor(settlement_id:int,character_id:String)->void:
    governors[str(settlement_id)]={"character":character_id,"loyalty":70}
func register_house(house_id:String,wealth:int,renown:int)->void:
    houses[house_id]={"wealth":wealth,"renown":renown,"members":0,"alive":true}
func advance_house(house_id:String,wealth_change:int,renown_change:int)->void:
    if houses.has(house_id):
        houses[house_id]["wealth"]=max(0,int(houses[house_id].get("wealth",0))+wealth_change)
        houses[house_id]["renown"]=max(0,int(houses[house_id].get("renown",0))+renown_change)
func succession_candidate(house_id:String)->Dictionary:
    return houses.get(house_id,{}).duplicate(true)

func _governance_tick()->void:
    for id in ministers.keys():
        ministers[id]["loyalty"]=clampi(int(ministers[id].get("loyalty",70)),0,100)
    for id in governors.keys():
        governors[id]["loyalty"]=clampi(int(governors[id].get("loyalty",70)),0,100)

# 35-37 Regional economy
func set_price(resource:String,value:float)->void:
    economy["prices"][resource]=max(0.1,value)
func get_price(resource:String)->float:
    return float(economy["prices"].get(resource,1.0))
func create_trade_route(route_id:String,from_settlement:int,to_settlement:int,resource:String,volume:int)->void:
    economy["trade_routes"][route_id]={"from":from_settlement,"to":to_settlement,"resource":resource,"volume":max(1,volume),"active":true}
func _economy_tick()->void:
    for id in economy["trade_routes"].keys():
        var route:Dictionary=economy["trade_routes"][id]
        if not bool(route.get("active",true)): continue
        var from=int(route.get("from",-1))
        var to=int(route.get("to",-1))
        if from<0 or to<0 or from>=world.settlements.size() or to>=world.settlements.size(): continue
        var resource=String(route.get("resource","food"))
        var amount=int(route.get("volume",1))
        var src:Dictionary=world.settlements[from]
        var dst:Dictionary=world.settlements[to]
        var sr:Dictionary=src.get("resources",{})
        var dr:Dictionary=dst.get("resources",{})
        var available=int(sr.get(resource,0))
        var moved=mini(amount,available)
        sr[resource]=available-moved
        dr[resource]=int(dr.get(resource,0))+moved
        src["resources"]=sr
        dst["resources"]=dr

# 38-39 Large-scale wars
func start_war(war_id:String,attacker:String,defender:String)->void:
    wars[war_id]={"attacker":attacker,"defender":defender,"war_score":0,"active":true,"days":0}
func update_war_score(war_id:String,delta:int)->void:
    if wars.has(war_id):
        wars[war_id]["war_score"]=clampi(int(wars[war_id].get("war_score",0))+delta,-100,100)
func _war_tick()->void:
    for id in wars.keys():
        var w:Dictionary=wars[id]
        if not bool(w.get("active",true)): continue
        w["days"]=int(w.get("days",0))+1
        if abs(int(w.get("war_score",0)))>=100 or int(w.get("days",0))>=90:
            w["active"]=false
        wars[id]=w

func _ui()->void:
    var layer=CanvasLayer.new()
    layer.name="Stages30to39UI"
    game.add_child(layer)
    var p=Panel.new()
    p.position=Vector2(410,410)
    p.size=Vector2(350,72)
    p.modulate.a=0.86
    layer.add_child(p)
    status=Label.new()
    status.position=Vector2(10,7)
    status.size=Vector2(330,58)
    status.text="30-39 • GOVERNMENT / ECONOMY / WAR"
    p.add_child(status)

func _update_ui()->void:
    if is_instance_valid(status):
        status.text="30-39 • Ministers:%d  Houses:%d  Trade:%d  Wars:%d" % [ministers.size(),houses.size(),economy["trade_routes"].size(),wars.size()]

func get_save_state()->Dictionary:
    return {"ministers":ministers.duplicate(true),"governors":governors.duplicate(true),"houses":houses.duplicate(true),"economy":economy.duplicate(true),"wars":wars.duplicate(true)}
func load_save_state(data:Dictionary)->void:
    ministers=data.get("ministers",{}).duplicate(true)
    governors=data.get("governors",{}).duplicate(true)
    houses=data.get("houses",{}).duplicate(true)
    economy=data.get("economy",{"prices":{},"trade_routes":{}}).duplicate(true)
    wars=data.get("wars",{}).duplicate(true)
