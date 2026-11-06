extends Node
class_name ReleaseKingdomSystems

# Stages 10-14: diplomacy, factions, kingdom management, rebellion and world events.

var game: Node3D
var world: Node
var tick := 0.0
var relations: Dictionary = {}
var kingdom: Dictionary = {"laws":{}, "projects":{}, "treasury":0}
var rebellions: Dictionary = {}
var events: Array = []
var status_label: Label

func build(main_node: Node3D) -> void:
    game = main_node
    world = game.get("world_state")
    _create_ui()
    set_process(true)

func _process(delta: float) -> void:
    if world == null:
        world = game.get("world_state")
        return
    tick += delta
    if tick >= 8.0:
        tick = 0.0
        _diplomacy_tick()
        _kingdom_tick()
        _rebellion_tick()
        _world_event_tick()
        _update_status()

# Stage 10 — Diplomacy
func set_relation(faction_a:String, faction_b:String, value:int) -> void:
    var key := _relation_key(faction_a,faction_b)
    relations[key] = clampi(value,-100,100)

func get_relation(a:String,b:String) -> int:
    if a == b: return 100
    return int(relations.get(_relation_key(a,b),0))

func diplomacy_action(a:String,b:String,action:String) -> Dictionary:
    var change := {"peace":12,"alliance":20,"trade":8,"threat":-15,"war":-40}.get(action,0)
    set_relation(a,b,get_relation(a,b)+change)
    return {"ok":true,"relation":get_relation(a,b),"action":action}

func _relation_key(a:String,b:String) -> String:
    return (a+"|"+b) if a < b else (b+"|"+a)

func _diplomacy_tick() -> void:
    var factions := _faction_names()
    for i in range(factions.size()):
        for j in range(i+1,factions.size()):
            var a:String=factions[i]
            var b:String=factions[j]
            var r:=get_relation(a,b)
            if r < -65:
                _record_event("%s and %s are on the brink of war." % [a,b])
            elif r > 70:
                set_relation(a,b,r+1)

# Stage 11 — Faction simulation
func _faction_names() -> Array:
    var out:Array=[]
    if world.has("factions"):
        for f in world.factions:
            if f is Dictionary:
                var n:=String(f.get("id",f.get("name","")))
                if n!="": out.append(n)
    for s in world.settlements:
        var owner:=String(s.get("owner",""))
        if owner!="" and not out.has(owner): out.append(owner)
    return out

func faction_strength(faction:String) -> int:
    var score:=0
    for s in world.settlements:
        if String(s.get("owner",""))==faction:
            score += 50 + int(s.get("garrison",0))
    for a in world.armies:
        if String(a.get("owner",""))==faction:
            score += int(a.get("soldiers",0))
    return score

# Stage 12 — Kingdom management
func set_law(law:String,value:bool) -> void:
    kingdom["laws"][law]=value

func start_project(name:String,cost:int,days:int) -> Dictionary:
    var gold:=int(world.get("gold"))
    if gold<cost: return {"ok":false,"reason":"insufficient_gold"}
    world.set("gold",gold-cost)
    kingdom["projects"][name]={"remaining":max(1,days),"cost":cost}
    return {"ok":true,"project":name}

func _kingdom_tick() -> void:
    var treasury:=0
    for s in world.settlements:
        var owner:=String(s.get("owner",""))
        var prosperity:=int(s.get("prosperity",50))
        if owner==String(world.get("player_faction")):
            treasury += max(0,prosperity/10)
    kingdom["treasury"]=treasury
    for name in kingdom["projects"].keys():
        var p:Dictionary=kingdom["projects"][name]
        p["remaining"]=int(p.get("remaining",1))-1
        if p["remaining"]<=0:
            _record_event("Kingdom project completed: %s" % name)
            kingdom["projects"].erase(name)
        else:
            kingdom["projects"][name]=p

# Stage 13 — Rebellion
func _rebellion_tick() -> void:
    var player_faction:=String(world.get("player_faction"))
    for i in range(world.settlements.size()):
        var s:Dictionary=world.settlements[i]
        if String(s.get("owner",""))!=player_faction: continue
        var loyalty:=int(s.get("loyalty",70))
        var prosperity:=int(s.get("prosperity",50))
        var risk:=max(0,60-loyalty)+max(0,35-prosperity)
        rebellions[str(i)]=risk
        if risk>=55:
            s["rebellion_risk"]=risk
            if risk>=85:
                s["rebel_control"]=true
                s["prosperity"]=max(0,prosperity-8)
                _record_event("Rebellion erupts in %s" % s.get("name","settlement"))

# Stage 14 — Dynamic world events
func _world_event_tick() -> void:
    var options:=["Harvest festival","Bandit pressure","Merchant boom","Harsh winter","Road repairs","Border tension"]
    var event:String=options[int(Time.get_ticks_msec()/8000)%options.size()]
    var payload={"type":event,"day":int(world.get("day"))}
    events.push_back(payload)
    if events.size()>20: events.pop_front()
    match event:
        "Harvest festival":
            for s in world.settlements:
                s["prosperity"]=min(100,int(s.get("prosperity",50))+2)
        "Merchant boom":
            for s in world.settlements:
                s["prosperity"]=min(100,int(s.get("prosperity",50))+1)
        "Harsh winter":
            for s in world.settlements:
                var r:Dictionary=s.get("resources",{})
                r["food"]=max(0,int(r.get("food",20))-5)
                s["resources"]=r
        "Bandit pressure":
            for a in world.armies:
                a["morale"]=max(0,int(a.get("morale",50))-1)

func _record_event(message:String) -> void:
    events.push_back({"type":"faction_event","message":message,"day":int(world.get("day"))})
    if events.size()>20: events.pop_front()

func _create_ui() -> void:
    var layer:=CanvasLayer.new()
    layer.name="KingdomSystemsUI"
    game.add_child(layer)
    var panel:=Panel.new()
    panel.position=Vector2(18,410)
    panel.size=Vector2(350,82)
    panel.modulate.a=0.88
    layer.add_child(panel)
    status_label=Label.new()
    status_label.position=Vector2(10,8)
    status_label.size=Vector2(330,66)
    status_label.text="KINGDOM\nDiplomacy • Factions • Rebellion • Events"
    panel.add_child(status_label)

func _update_status() -> void:
    if not is_instance_valid(status_label): return
    var active_rebels:=0
    for v in rebellions.values():
        if int(v)>=55: active_rebels+=1
    status_label.text="KINGDOM SYSTEMS\nRelations:%d  Rebel risk:%d  Events:%d" % [relations.size(),active_rebels,events.size()]

func get_save_state()->Dictionary:
    return {"relations":relations.duplicate(true),"kingdom":kingdom.duplicate(true),"rebellions":rebellions.duplicate(true),"events":events.duplicate(true)}

func load_save_state(data:Dictionary)->void:
    relations=data.get("relations",{}).duplicate(true)
    kingdom=data.get("kingdom",{"laws":{},"projects":{},"treasury":0}).duplicate(true)
    rebellions=data.get("rebellions",{}).duplicate(true)
    events=data.get("events",[]).duplicate(true)
