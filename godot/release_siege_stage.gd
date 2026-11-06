extends Node
class_name ReleaseSiegeStage

# Stage 5: complete siege gameplay loop.
# Connects the existing WorldState siege data to a visible, autonomous
# siege state machine: approach -> bombard -> breach -> assault -> capture.

var game: Node3D
var world: Node
var active = false
var settlement_id = -1
var attacker_id = -1
var phase = "idle"
var wall_hp = 0
var gate_hp = 0
var progress = 0.0
var attacker_morale = 70.0
var defender_morale = 70.0
var supply = 100.0
var tick = 0.0
var phase_tick = 0.0
var siege_root: Node3D
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
    if not active:
        _update_idle()
        return
    tick += delta
    phase_tick += delta
    if tick < 1.0:
        return
    tick = 0.0
    _advance_siege()

func start(settlement: int = -1) -> Dictionary:
    if world == null or world.settlements.is_empty():
        return {"ok":false,"reason":"world_not_ready"}
    var sid = settlement
    if sid < 0:
        sid = _nearest_hostile_settlement()
    if sid < 0 or sid >= world.settlements.size():
        return {"ok":false,"reason":"no_target"}
    var army = _player_army_id()
    if army < 0:
        return {"ok":false,"reason":"no_player_army"}
    if not world.has_method("start_siege"):
        return {"ok":false,"reason":"world_siege_api_missing"}
    var result = world.start_siege(sid, army)
    if result is Dictionary and not bool(result.get("ok",false)):
        return result
    _begin(sid,army)
    return {"ok":true,"settlement":world.settlements[sid].get("name","Settlement"),"phase":phase}

func _begin(sid:int, army:int) -> void:
    settlement_id = sid
    attacker_id = army
    active = true
    phase = "approach"
    phase_tick = 0.0
    progress = 0.0
    supply = 100.0
    attacker_morale = 75.0
    defender_morale = 72.0
    var s: Dictionary = world.settlements[sid]
    wall_hp = max(160,int(s.get("wall_level",1))*220)
    gate_hp = max(120,int(s.get("wall_level",1))*150)
    _spawn_siege_scene()
    _sync_world()
    _update_ui()

func _advance_siege() -> void:
    if settlement_id < 0 or settlement_id >= world.settlements.size():
        _finish(false)
        return
    var s: Dictionary = world.settlements[settlement_id]
    var army: Dictionary = world.armies[attacker_id] if attacker_id >= 0 and attacker_id < world.armies.size() else {}
    var soldiers = int(army.get("soldiers",0))
    if soldiers <= 0:
        _finish(false)
        return

    supply = max(0.0,supply - 0.45)
    if supply < 20.0:
        attacker_morale = max(0.0,attacker_morale - 1.2)
    else:
        attacker_morale = min(100.0,attacker_morale + 0.15)

    if phase == "approach":
        if phase_tick >= 4.0:
            phase = "bombard"
            phase_tick = 0.0
    elif phase == "bombard":
        wall_hp = max(0,wall_hp - max(7,soldiers/18))
        gate_hp = max(0,gate_hp - max(4,soldiers/30))
        defender_morale = max(0.0,defender_morale - 1.0)
        if wall_hp <= int(max(40,wall_hp*0.42)) or gate_hp <= 45:
            phase = "breach"
            phase_tick = 0.0
    elif phase == "breach":
        wall_hp = max(0,wall_hp - max(10,soldiers/14))
        gate_hp = max(0,gate_hp - max(8,soldiers/18))
        defender_morale = max(0.0,defender_morale - 1.8)
        if wall_hp <= 25 or gate_hp <= 0:
            phase = "assault"
            phase_tick = 0.0
            progress = 10.0
    elif phase == "assault":
        var assault_power = clamp(float(soldiers) / 120.0,0.15,1.8)
        progress += assault_power * (1.0 + max(0.0,(70.0-defender_morale)/100.0))
        defender_morale = max(0.0,defender_morale - 1.5)
        attacker_morale = max(0.0,attacker_morale - 0.35)
        if progress >= 100.0 or defender_morale <= 5.0:
            phase = "capture"
            phase_tick = 0.0
    elif phase == "capture":
        _capture_settlement()
        return
    _sync_world()
    _update_visuals()
    _update_ui()

func _sync_world() -> void:
    if settlement_id < 0 or settlement_id >= world.settlements.size():
        return
    var s: Dictionary = world.settlements[settlement_id]
    s["siege_phase"] = phase
    s["wall_integrity"] = wall_hp
    s["gate_integrity"] = gate_hp
    s["siege_progress"] = progress
    s["attacker_morale"] = attacker_morale
    s["defender_morale"] = defender_morale
    s["siege_supply"] = supply
    s["breached"] = phase == "assault" or phase == "capture"

func _capture_settlement() -> void:
    if settlement_id < 0 or settlement_id >= world.settlements.size():
        _finish(false)
        return
    var s: Dictionary = world.settlements[settlement_id]
    var old_owner = String(s.get("owner",""))
    var player_faction = String(world.get("player_faction"))
    if player_faction != "":
        s["owner"] = player_faction
    s["siege_phase"] = "captured"
    s["wall_integrity"] = max(20,int(wall_hp * 0.25))
    s["gate_integrity"] = max(20,int(gate_hp * 0.2))
    s["prosperity"] = max(0,int(s.get("prosperity",50))-12)
    s["garrison"] = max(0,int(s.get("garrison",0))-max(5,int(progress/8.0)))
    if world.has_method("add_world_event"):
        world.add_world_event("Settlement captured: %s" % s.get("name","Settlement"))
    _finish(true)
    status_label.text = "SIEGE WON  •  %s" % s.get("name","Settlement")

func _finish(won:bool) -> void:
    active = false
    if siege_root != null and is_instance_valid(siege_root):
        siege_root.queue_free()
    if not won:
        status_label.text = "SIEGE FAILED"
    phase = "idle"
    settlement_id = -1
    attacker_id = -1

func _spawn_siege_scene() -> void:
    if siege_root != null and is_instance_valid(siege_root):
        siege_root.queue_free()
    siege_root = Node3D.new()
    siege_root.name = "Stage5SiegeScene"
    game.add_child(siege_root)
    var center = _settlement_center(world.settlements[settlement_id])
    siege_root.position = center
    _make_marker(Vector3(0,0,9),Vector3(7,0.5,1.2))
    _make_marker(Vector3(0,0,-9),Vector3(7,0.5,1.2))
    _make_marker(Vector3(-9,0,0),Vector3(1.2,0.5,7))
    _make_marker(Vector3(9,0,0),Vector3(1.2,0.5,7))
    _make_marker(Vector3(0,0,5),Vector3(2.0,1.0,1.0))

func _make_marker(pos:Vector3,size:Vector3) -> void:
    var n = MeshInstance3D.new()
    var mesh = BoxMesh.new()
    mesh.size = size
    n.mesh = mesh
    n.position = pos
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.30,0.22,0.15)
    n.material_override = mat
    siege_root.add_child(n)

func _update_visuals() -> void:
    if not is_instance_valid(siege_root):
        return
    var marker = siege_root.get_node_or_null("Node3D")
    if marker != null:
        marker.scale.x = 1.0 + progress/100.0

func _settlement_center(s:Dictionary) -> Vector3:
    var p:Vector2 = s.get("position",Vector2.ZERO)
    return Vector3(p.x,0,p.y)

func _nearest_hostile_settlement() -> int:
    if world.settlements.is_empty():
        return -1
    var player_faction = String(world.get("player_faction"))
    var best = -1
    var best_d = INF
    var player_pos = Vector3.ZERO
    var p = game.get("player") as Node3D
    if p != null:
        player_pos = p.global_position
    for i in range(world.settlements.size()):
        var s:Dictionary = world.settlements[i]
        if String(s.get("owner","")) == player_faction:
            continue
        var d = player_pos.distance_to(_settlement_center(s))
        if d < best_d:
            best_d = d
            best = i
    return best

func _player_army_id() -> int:
    var faction = String(world.get("player_faction"))
    for i in range(world.armies.size()):
        if String(world.armies[i].get("owner","")) == faction:
            return i
    return -1

func _create_ui() -> void:
    var layer = CanvasLayer.new()
    layer.name = "Stage5SiegeUI"
    game.add_child(layer)
    var panel = Panel.new()
    panel.position = Vector2(18,195)
    panel.size = Vector2(300,116)
    panel.modulate.a = 0.9
    layer.add_child(panel)
    status_label = Label.new()
    status_label.position = Vector2(12,10)
    status_label.size = Vector2(276,96)
    status_label.text = "SIEGE\nNo active siege"
    panel.add_child(status_label)

func _update_idle() -> void:
    if is_instance_valid(status_label) and phase == "idle":
        status_label.text = "SIEGE\nReady • select a hostile settlement"

func _update_ui() -> void:
    if not is_instance_valid(status_label):
        return
    var name = "Settlement"
    if settlement_id >= 0 and settlement_id < world.settlements.size():
        name = String(world.settlements[settlement_id].get("name","Settlement"))
    status_label.text = "SIEGE  •  %s\n%s  | Progress %d%%\nWall %d  Gate %d  Supply %d%%" % [
        name, phase.to_upper(), int(progress), wall_hp, gate_hp, int(supply)
    ]

func get_save_state() -> Dictionary:
    return {
        "active":active, "settlement_id":settlement_id, "attacker_id":attacker_id,
        "phase":phase, "wall_hp":wall_hp, "gate_hp":gate_hp, "progress":progress,
        "attacker_morale":attacker_morale, "defender_morale":defender_morale, "supply":supply
    }

func load_save_state(data:Dictionary) -> void:
    if not bool(data.get("active",false)):
        return
    var sid = int(data.get("settlement_id",-1))
    var aid = int(data.get("attacker_id",-1))
    if sid < 0 or aid < 0 or sid >= world.settlements.size() or aid >= world.armies.size():
        return
    _begin(sid,aid)
    phase = String(data.get("phase","approach"))
    wall_hp = int(data.get("wall_hp",wall_hp))
    gate_hp = int(data.get("gate_hp",gate_hp))
    progress = float(data.get("progress",progress))
    attacker_morale = float(data.get("attacker_morale",attacker_morale))
    defender_morale = float(data.get("defender_morale",defender_morale))
    supply = float(data.get("supply",supply))
    _sync_world()
    _update_ui()
