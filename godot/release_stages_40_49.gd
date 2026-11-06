extends Node
class_name ReleaseStages40to49

# 40-49 naval/fantasy/content/quality foundation. Fantasy is optional sandbox content.
var game:Node3D
var world:Node
var tick=0.0
var ships:Dictionary={}
var ports:Dictionary={}
var fantasy:Dictionary={"enabled":true,"creatures":[],"magic":{}}
var audio:Dictionary={"master":1.0,"music":0.7,"sfx":1.0}
var quality:Dictionary={"preset":"balanced","fps_cap":60}
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
    if tick>=6.0:
        tick=0.0
        _naval_tick()
        _fantasy_tick()
        _update_ui()

# 40-43 Naval campaign
func register_ship(id:String,ship_type:String,cargo:int,crew:int)->void:
    ships[id]={"type":ship_type,"cargo":max(0,cargo),"crew":max(1,crew),"hull":100,"fatigue":0,"port":-1}
func register_port(id:String,settlement_id:int)->void:
    ports[id]={"settlement":settlement_id,"prosperity":50,"dock_level":1}
func naval_damage(id:String,amount:int)->void:
    if ships.has(id):
        ships[id]["hull"]=max(0,int(ships[id].get("hull",100))-max(0,amount))
func _naval_tick()->void:
    for id in ships.keys():
        var s:Dictionary=ships[id]
        s["fatigue"]=mini(100,int(s.get("fatigue",0))+1)
        if int(s.get("fatigue",0))>=100:
            s["hull"]=max(0,int(s.get("hull",100))-1)
        ships[id]=s

# 44-46 Optional fantasy layer
func spawn_fantasy_creature(kind:String,region:String)->void:
    if not bool(fantasy.get("enabled",true)): return
    fantasy["creatures"].append({"kind":kind,"region":region,"alive":true})
func set_magic_rule(rule:String,value:bool)->void:
    fantasy["magic"][rule]=value
func _fantasy_tick()->void:
    if fantasy["creatures"].size()>40:
        fantasy["creatures"].pop_front()

# 47 Audio
func set_audio(master:float,music:float,sfx:float)->void:
    audio={"master":clampf(master,0,1),"music":clampf(music,0,1),"sfx":clampf(sfx,0,1)}

# 48-49 Visual/mobile quality
func set_quality(preset:String,fps_cap:int)->void:
    quality["preset"]=preset
    quality["fps_cap"]=clampi(fps_cap,30,120)
    game.set_meta("quality_preset",preset)
    game.set_meta("fps_cap",quality["fps_cap"])

func _ui()->void:
    var layer=CanvasLayer.new()
    layer.name="Stages40to49UI"
    game.add_child(layer)
    var p=Panel.new()
    p.position=Vector2(410,490)
    p.size=Vector2(350,72)
    p.modulate.a=0.86
    layer.add_child(p)
    status=Label.new()
    status.position=Vector2(10,7)
    status.size=Vector2(330,58)
    status.text="40-49 • NAVAL / FANTASY / AUDIO / QUALITY"
    p.add_child(status)

func _update_ui()->void:
    if is_instance_valid(status):
        status.text="40-49 • Ships:%d  Creatures:%d  Quality:%s" % [ships.size(),fantasy["creatures"].size(),quality["preset"]]

func get_save_state()->Dictionary:
    return {"ships":ships.duplicate(true),"ports":ports.duplicate(true),"fantasy":fantasy.duplicate(true),"audio":audio.duplicate(true),"quality":quality.duplicate(true)}
func load_save_state(data:Dictionary)->void:
    ships=data.get("ships",{}).duplicate(true)
    ports=data.get("ports",{}).duplicate(true)
    fantasy=data.get("fantasy",fantasy).duplicate(true)
    audio=data.get("audio",audio).duplicate(true)
    quality=data.get("quality",quality).duplicate(true)
