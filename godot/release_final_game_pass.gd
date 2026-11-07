extends Node
class_name ReleaseFinalGamePass

# Final integration pass: turns the existing systems into a coherent playable loop.
var game:Node3D
var world:Node
var tick=0.0
var day_accumulator=0.0
var save_interval=90.0
var save_timer=0.0
var settings:Dictionary={"quality":"balanced","fps":60}
var qa:Dictionary={"checks":0,"errors":0,"last":"not_run"}
var mounted=false
var current_target:Dictionary={}
var status:Label

func build(main_node:Node3D)->void:
    game=main_node
    world=game.get("world_state")
    _load_settings()
    _build_ui()
    _run_runtime_checks()
    set_process(true)

func _process(delta:float)->void:
    if world==null:
        world=game.get("world_state")
        return
    save_timer+=delta
    day_accumulator+=delta
    if day_accumulator>=60.0:
        day_accumulator=0.0
        if world.has_method("advance_day"):
            world.advance_day()
    if save_timer>=save_interval:
        save_timer=0.0
        _autosave()
    if Engine.get_frames_per_second()>0:
        _apply_fps_cap()
    _update_status()

# Unified character loop
func toggle_mount()->void:
    mounted=not mounted
    game.set_meta("player_mounted",mounted)
    game.set_meta("movement_speed_bonus",2.0 if mounted else 0.0)

func select_target(target_id:String,target_type:String)->void:
    current_target={"id":target_id,"type":target_type}

# Unified world-map presentation
func get_world_snapshot()->Dictionary:
    var settlements_count=world.settlements.size() if world != null else 0
    var armies_count=world.armies.size() if world != null else 0
    var ships_count=world.ships.size() if world != null and world.get("ships") is Array else 0
    return {"day":int(world.get("day")),"settlements":settlements_count,"armies":armies_count,"ships":ships_count,
        "player_region":String(world.get("player_region_id"))}

# Save recovery
func save_now()->bool:
    if world==null: return false
    if world.has_method("save_game"):
        world.save_game()
        return true
    return false

func _autosave()->void:
    save_now()
    game.set_meta("last_autosave_ms",Time.get_ticks_msec())

# Mobile quality
func set_quality(preset:String)->void:
    var fps=60
    if preset=="performance": fps=30
    elif preset=="balanced": fps=45
    settings={"quality":preset,"fps":fps}
    game.set_meta("quality_preset",preset)
    game.set_meta("fps_cap",fps)
    _save_settings()

func _apply_fps_cap()->void:
    var cap=int(settings.get("fps",60))
    Engine.max_fps=cap

func _save_settings()->void:
    var file=FileAccess.open("user://final_game_settings.json",FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(settings))

func _load_settings()->void:
    if not FileAccess.file_exists("user://final_game_settings.json"): return
    var file=FileAccess.open("user://final_game_settings.json",FileAccess.READ)
    if file:
        var parsed=JSON.parse_string(file.get_as_text())
        if parsed is Dictionary:
            settings=parsed

# Runtime sanity checks; does not claim Android/device testing.
func _run_runtime_checks()->void:
    qa={"checks":0,"errors":0,"last":"running"}
    _check(world!=null,"WorldState")
    if world!=null:
        _check(world.settlements.size()>0,"Settlements")
        _check(world.armies.size()>0,"Armies")
        _check(world.regions.size()>0,"Regions")
        _check(world.get("day")!=null,"WorldClock")
        _check(world.get("gold")!=null,"PlayerGold")
    qa["last"]="PASS" if int(qa["errors"])==0 else "WARN"

func _check(value:bool,name:String)->void:
    qa["checks"]=int(qa["checks"])+1
    if not value:
        qa["errors"]=int(qa["errors"])+1
        qa["last"]=name

func _build_ui()->void:
    var layer=CanvasLayer.new()
    layer.name="FinalGamePassUI"
    game.add_child(layer)
    var panel=Panel.new()
    panel.position=Vector2(18,675)
    panel.size=Vector2(430,70)
    panel.modulate.a=0.88
    layer.add_child(panel)
    status=Label.new()
    status.position=Vector2(10,7)
    status.size=Vector2(410,55)
    status.text="FINAL PASS • initializing"
    panel.add_child(status)

func _update_status()->void:
    if not is_instance_valid(status): return
    var s=get_world_snapshot()
    status.text="WORLD DAY %d • S:%d A:%d • Mount:%s • QA:%s" % [int(s.get("day",0)),int(s.get("settlements",0)),int(s.get("armies",0)),str(mounted),String(qa.get("last",""))]

func get_save_state()->Dictionary:
    return {"mounted":mounted,"settings":settings.duplicate(true),"target":current_target.duplicate(true)}

func load_save_state(data:Dictionary)->void:
    mounted=bool(data.get("mounted",false))
    settings=data.get("settings",settings).duplicate(true)
    current_target=data.get("target",{}).duplicate(true)
