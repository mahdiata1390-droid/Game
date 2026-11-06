extends Node
var game:Node3D
var world:Node
var map_panel:Panel
var info:Label
var target_label:Label
var mounted:=false
var map_open:=false
var selected_settlement:Dictionary={}
var sim_timer:=0.0
var battle_fx:Node3D
var rng:=RandomNumberGenerator.new()

func _build_interaction_fx() -> void:
	battle_fx = Node3D.new()
	battle_fx.name = "CampaignInteractionFX"
	game.add_child(battle_fx)
	game.set_meta("campaign_interaction_fx_ready", true)

func build(main_node:Node3D)->void:
    game=main_node
    world=game.get("world_state")
    rng.seed=912734
    _build_campaign_hud()
    _build_world_map()
    _build_interaction_fx()
    _ensure_mount_visual()
    _run_world_simulation()
    set_process(true)

func _process(delta:float)->void:
    if world==null:
        world=game.get("world_state")
        return
    sim_timer+=delta
    if sim_timer>=5.0:
        sim_timer=0.0
        _simulate_factions()
        _update_hud()

func _build_campaign_hud()->void:
    var layer:=CanvasLayer.new()
    layer.name="PlayableWorldHUD"
    game.add_child(layer)
    var bar:=Panel.new()
    bar.position=Vector2(18,80)
    bar.size=Vector2(500,86)
    bar.modulate.a=0.9
    layer.add_child(bar)
    info=Label.new()
    info.position=Vector2(12,8)
    info.size=Vector2(475,65)
    info.text="CAMPAIGN • loading"
    bar.add_child(info)
    var map_btn:=Button.new()
    map_btn.text="WORLD MAP"
    map_btn.position=Vector2(350,45)
    map_btn.size=Vector2(130,32)
    map_btn.pressed.connect(toggle_map)
    bar.add_child(map_btn)
    var mount_btn:=Button.new()
    mount_btn.text="MOUNT"
    mount_btn.position=Vector2(215,45)
    mount_btn.size=Vector2(125,32)
    mount_btn.pressed.connect(toggle_mount)
    bar.add_child(mount_btn)

func _build_world_map()->void:
    var layer:=CanvasLayer.new()
    layer.name="PlayableWorldMap"
    game.add_child(layer)
    map_panel=Panel.new()
    map_panel.position=Vector2(70,95)
    map_panel.size=Vector2(860,560)
    map_panel.visible=false
    layer.add_child(map_panel)
    var title:=Label.new()
    title.text="CONTINENT • STRATEGIC MAP"
    title.position=Vector2(22,16)
    title.add_theme_font_size_override("font_size",22)
    map_panel.add_child(title)
    var close:=Button.new()
    close.text="CLOSE"
    close.position=Vector2(765,15)
    close.size=Vector2(75,32)
    close.pressed.connect(toggle_map)
    map_panel.add_child(close)
    target_label=Label.new()
    target_label.position=Vector2(22,505)
    target_label.size=Vector2(810,35)
    map_panel.add_child(target_label)
    for i in range(world.settlements.size() if world else 0):
        _add_map_settlement(i)

func _add_map_settlement(id:int)->void:
    var s:Dictionary=world.settlements[id]
    var b:=Button.new()
    b.text=String(s["name"])
    var p:Vector2=s["position"]
    var x=35.0+(p.x+22.0)*18.0
    var y=65.0+(p.y+17.0)*20.0
    b.position=Vector2(clamp(x,15.0,720.0),clamp(y,55.0,445.0))
    b.size=Vector2(115,30)
    b.pressed.connect(_select_settlement.bind(id))
    map_panel.add_child(b)

func _select_settlement(id:int)->void:
    if id<0 or id>=world.settlements.size(): return
    selected_settlement=world.settlements[id]
    target_label.text="%s • %s • Owner: %s • Pop: %d • Prosperity: %d" % [
        String(selected_settlement["name"]),String(selected_settlement["type"]),
        String(selected_settlement["owner"]),int(selected_settlement["population"]),int(selected_settlement["prosperity"])]
    world.set_meta("selected_settlement_id",id)

func toggle_map()->void:
    map_open=not map_open
    if is_instance_valid(map_panel): map_panel.visible=map_open
    game.set_meta("strategic_map_open",map_open)

func toggle_mount()->void:
    mounted=not mounted
    game.set_meta("player_mounted",mounted)
    game.set_meta("movement_speed_bonus",2.2 if mounted else 0.0)
    _ensure_mount_visual()
    _update_hud()

func _ensure_mount_visual()->void:
    var player=game.get("player")
    if not is_instance_valid(player): return
    var old=player.get_node_or_null("CampaignMount")
    if mounted and old==null:
        var horse:=Node3D.new()
        horse.name="CampaignMount"
        var body:=MeshInstance3D.new()
        var mesh:=CapsuleMesh.new()
        mesh.height=1.7
        mesh.radius=0.38
        body.mesh=mesh
        body.position=Vector3(0,-0.15,-0.35)
        horse.add_child(body)
        var neck:=MeshInstance3D.new()
        var neck_mesh:=CapsuleMesh.new()
        neck_mesh.height=1.0
        neck_mesh.radius=0.18
        neck.mesh=neck_mesh
        neck.position=Vector3(0,0.55,-0.75)
        horse.add_child(neck)
        player.add_child(horse)
    elif not mounted and old:
        old.queue_free()

func _run_world_simulation()->void:
    world.set_meta("playable_world_pass",true)
    world.set_meta("faction_ai_enabled",true)
    world.set_meta("autonomous_campaign",true)

func _simulate_factions()->void:
    # Autonomous strategic movement: armies patrol, reinforce, or pressure hostile borders.
    for i in range(world.armies.size()):
        var army:Dictionary=world.armies[i]
        if String(army.get("owner",""))=="Free Company": continue
        var owner:=String(army.get("owner",""))
        var region_id:=int(army.get("region",0))
        var region:Dictionary=world.regions[region_id]
        var danger:=0
        for other in world.armies:
            if String(other.get("owner",""))!=owner and int(other.get("region",0))==region_id:
                danger+=int(other.get("soldiers",0))
        if danger>int(army.get("soldiers",0))*1.35:
            army["order"]="retreat"
            army["morale"]=max(20,int(army.get("morale",75))-1)
        elif danger==0 and int(army.get("morale",75))>45:
            army["order"]="patrol"
            army["morale"]=min(100,int(army.get("morale",75))+1)
        else:
            army["order"]="advance"
        world.armies[i]=army
    _apply_settlement_life()

func _apply_settlement_life()->void:
    for i in range(world.settlements.size()):
        var s:Dictionary=world.settlements[i]
        var pop:=int(s.get("population",100))
        var prosperity:=int(s.get("prosperity",50))
        var stock:Dictionary=s.get("stockpile",{})
        var food:=int(stock.get("food",0))
        food=max(0,food+4+int(prosperity/25)-int(pop/250))
        if food<25: prosperity=max(0,prosperity-2)
        elif food>100: prosperity=min(100,prosperity+1)
        if prosperity>65: pop+=max(1,int(pop/500))
        s["population"]=pop
        s["prosperity"]=prosperity
        stock["food"]=food
        s["stockpile"]=stock
        world.settlements[i]=s

func _update_hud()->void:
    if not is_instance_valid(info): return
    var player=game.get("player")
    var pos:=player.global_position if is_instance_valid(player) else Vector3.ZERO
    info.text="DAY %d • GOLD %d • REGION %s\nPosition %.0f, %.0f • Mounted %s • Factions autonomous" % [
        int(world.day),int(world.gold),String(world.player_region_id),pos.x,pos.z,str(mounted)]

func get_state()->Dictionary:
    return {"mounted":mounted,"map_open":map_open,"selected_settlement":selected_settlement.duplicate(true)}

func get_save_state()->Dictionary:
    return get_state()

func load_state(data:Dictionary)->void:
    mounted=bool(data.get("mounted",false))
    map_open=bool(data.get("map_open",false))
    selected_settlement=data.get("selected_settlement",{}).duplicate(true)
    if is_instance_valid(map_panel): map_panel.visible=map_open
    game.set_meta("strategic_map_open",map_open)
    game.set_meta("player_mounted",mounted)
    game.set_meta("movement_speed_bonus",2.2 if mounted else 0.0)
    _ensure_mount_visual()
    _update_hud()

func load_save_state(data:Dictionary)->void:
    load_state(data)
