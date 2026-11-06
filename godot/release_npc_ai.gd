extends Node
class_name ReleaseNpcAiSystem

const MAX_ACTIVE_NPCS := 72
const NPC_UPDATE := 0.25
const STRATEGIC_UPDATE := 5.0

var game: Node3D
var world: Node
var production: Node
var rng := RandomNumberGenerator.new()
var npcs: Array[Dictionary] = []
var ai_memory: Dictionary = {}
var npc_tick := 0.0
var strategic_tick := 0.0
var status_label: Label
var jobs := ["farmer","merchant","craftsman","guard","innkeeper","traveler"]

func build(main_node: Node3D) -> void:
    game = main_node
    world = game.get("world_state")
    production = game.get_node_or_null("ProductionAssetIntegration")
    rng.seed = 739201
    _create_status_ui()
    call_deferred("_spawn_npcs")
    set_process(true)

func _process(delta: float) -> void:
    if world == null:
        world = game.get("world_state")
        return
    npc_tick += delta
    strategic_tick += delta
    if npc_tick >= NPC_UPDATE:
        npc_tick = 0.0
        _update_npcs()
    if strategic_tick >= STRATEGIC_UPDATE:
        strategic_tick = 0.0
        _update_commanders()
        _update_status()

func _spawn_npcs() -> void:
    if not is_instance_valid(game) or world == null:
        return
    var settlements: Array = world.get("settlements")
    if settlements.is_empty():
        return
    var sources: Array[Node3D] = []
    if is_instance_valid(production) and production.has_method("get_role_nodes"):
        for role in ["characters_extra","character"]:
            for node in production.call("get_role_nodes", role):
                if node is Node3D:
                    sources.append(node)
    if sources.is_empty():
        return
    for source in sources:
        source.visible = false

    var count := 0
    for sid in range(settlements.size()):
        if count >= MAX_ACTIVE_NPCS:
            break
        var settlement: Dictionary = settlements[sid]
        var center := _settlement_center(settlement)
        var desired := _population_target(settlement)
        for local_i in range(desired):
            if count >= MAX_ACTIVE_NPCS:
                break
            var job := _pick_job(settlement, local_i)
            var source: Node3D = sources[count % sources.size()]
            var visual := source.duplicate() as Node3D
            if visual == null:
                continue
            visual.name = "NPC_%03d_%s" % [count, job]
            game.add_child(visual)
            visual.visible = true
            visual.position = center + _spawn_offset(local_i, desired)
            visual.scale = Vector3.ONE * (0.82 + float((count + local_i) % 4) * 0.045)
            visual.set_meta("npc_id", count)
            visual.set_meta("npc_job", job)
            visual.set_meta("npc_settlement", sid)
            npcs.append({
                "id": count, "node": visual, "settlement": sid, "job": job,
                "state": "work", "target": visual.position,
                "speed": 0.65 + float(count % 5) * 0.08,
                "hunger": 0.0, "morale": 70, "alert": false,
                "shift": local_i % 3
            })
            count += 1

func _population_target(s: Dictionary) -> int:
    var kind := String(s.get("type", "village"))
    var base: int = {"village":4, "town":7, "city":10, "castle":5}.get(kind, 4)
    return clampi(base + int(int(s.get("prosperity", 50)) / 35), 2, 12)

func _pick_job(s: Dictionary, i: int) -> String:
    var kind := String(s.get("type", "village"))
    var prosperity := int(s.get("prosperity", 50))
    if kind == "castle":
        return "guard" if i % 2 == 0 else "craftsman"
    if prosperity < 30:
        return "farmer" if i % 3 != 2 else "guard"
    return jobs[i % jobs.size()]

func _spawn_offset(i: int, total: int) -> Vector3:
    var angle := TAU * float(i) / float(maxi(total, 1))
    var radius := 2.4 + float(i % 3) * 1.15
    return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

func _update_npcs() -> void:
    var time := _world_hour()
    for i in range(npcs.size()):
        var npc: Dictionary = npcs[i]
        var node := npc.get("node") as Node3D
        if not is_instance_valid(node):
            continue
        var sid := int(npc.get("settlement", -1))
        if sid < 0 or sid >= world.settlements.size():
            continue
        var s: Dictionary = world.settlements[sid]
        var danger := _settlement_danger(sid, s)
        var job := String(npc.get("job", "traveler"))
        var state := "work"
        if danger:
            if job == "guard":
                state = "defend"
            elif job == "traveler" or job == "merchant":
                state = "leave"
            else:
                state = "shelter"
        elif time < 6 or time >= 21:
            state = "rest"
        elif job == "traveler":
            state = "travel"
        npc["state"] = state
        npc["alert"] = danger
        npc["hunger"] = min(100.0, float(npc.get("hunger", 0.0)) + 0.008)
        var target := _job_target(s, job, state, npc)
        npc["target"] = target
        var speed := float(npc.get("speed", 0.7))
        if state == "defend":
            speed *= 1.25
        node.position = node.position.move_toward(target, speed * NPC_UPDATE)
        npcs[i] = npc

func _job_target(s: Dictionary, job: String, state: String, npc: Dictionary) -> Vector3:
    var center := _settlement_center(s)
    if state == "rest" or state == "shelter":
        return center + Vector3(0, 0, 2.0 + float(int(npc.get("id", 0)) % 3))
    if state == "leave":
        var angle := float(int(npc.get("id", 0))) * 0.73
        return center + Vector3(cos(angle), 0, sin(angle)) * 14.0
    if state == "defend":
        var angle2 := float(int(npc.get("id", 0)) % 8) * TAU / 8.0
        return center + Vector3(cos(angle2), 0, sin(angle2)) * 8.0
    var offsets := {
        "farmer": Vector3(-6,0,4), "merchant": Vector3(4,0,-2),
        "craftsman": Vector3(5,0,4), "guard": Vector3(0,0,-6),
        "innkeeper": Vector3(-3,0,-3), "traveler": Vector3(9,0,0)
    }
    return center + offsets.get(job, Vector3.ZERO)

func _settlement_center(s: Dictionary) -> Vector3:
    var p: Vector2 = s.get("position", Vector2.ZERO)
    return Vector3(p.x, 0.0, p.y)

func _settlement_danger(sid: int, s: Dictionary) -> bool:
    if bool(s.get("under_siege", false)) or bool(s.get("besieged", false)):
        return true
    var owner := String(s.get("owner", ""))
    var settlement_region := int(s.get("region", sid))
    for army in world.armies:
        if String(army.get("owner", "")) == owner:
            continue
        if int(army.get("region", -1)) == settlement_region:
            var order := String(army.get("order", ""))
            if order == "attack" or order == "assault":
                return true
    return false

func _world_hour() -> int:
    for key in ["world_hour", "hour", "time_hour", "campaign_hour"]:
        var value = world.get(key)
        if value != null:
            return int(value) % 24
    return int(world.get("day")) * 6 % 24

func _update_commanders() -> void:
    if world == null or world.armies.is_empty():
        return
    for i in range(world.armies.size()):
        var army: Dictionary = world.armies[i]
        var owner := String(army.get("owner", ""))
        var morale := int(army.get("morale", 50))
        var food := int(army.get("food", 0))
        var soldiers := int(army.get("soldiers", 0))
        var region := int(army.get("region", 0))
        if morale < 30 or food < 15:
            army["order"] = "retreat"
            army["ai_stance"] = "survival"
            army["ai_memory"] = "Low supply/morale: seeking friendly settlement"
            _move_toward_friendly_army(army, owner, region)
        else:
            var target := _find_hostile_region(owner, region)
            if target >= 0 and soldiers >= 55:
                army["order"] = "attack"
                army["ai_stance"] = "aggressive"
                army["target_region"] = target
                army["ai_memory"] = "Pressing the strongest hostile nearby region"
            else:
                army["order"] = "patrol"
                army["ai_stance"] = "cautious"
                army["ai_memory"] = "Patrolling friendly territory"
        world.armies[i] = army

func _find_hostile_region(owner: String, region: int) -> int:
    if not world.has_method("get_region_neighbors"):
        return -1
    var best := -1
    var score := -999999
    for rid in world.get_region_neighbors(region):
        if rid < 0 or rid >= world.regions.size():
            continue
        var other := String(world.regions[rid].get("owner", ""))
        if other == owner or other == "":
            continue
        if _faction_relation(owner, other) >= 0:
            continue
        var value := int(world.regions[rid].get("prosperity", 0)) + int(world.regions[rid].get("population", 0)) / 100
        if value > score:
            score = value
            best = rid
    return best

func _faction_relation(a: String, b: String) -> int:
    if a == b:
        return 100
    if world.has_method("_get_faction"):
        var f = world.call("_get_faction", a)
        if f is Dictionary:
            return int(f.get("relations", {}).get(b, 0))
    return 0

func _move_toward_friendly_army(army: Dictionary, owner: String, region: int) -> void:
    if not world.has_method("get_region_neighbors"):
        return
    for rid in world.get_region_neighbors(region):
        for other in world.armies:
            if String(other.get("owner", "")) == owner and int(other.get("region", -1)) == rid:
                army["region"] = rid
                return
    for settlement in world.settlements:
        if String(settlement.get("owner", "")) == owner:
            army["region"] = int(settlement.get("region", region))
            return

func _create_status_ui() -> void:
    var layer := CanvasLayer.new()
    layer.name = "NPCStatusLayer"
    game.add_child(layer)
    var panel := Panel.new()
    panel.position = Vector2(18, 110)
    panel.size = Vector2(260, 72)
    panel.modulate.a = 0.88
    layer.add_child(panel)
    status_label = Label.new()
    status_label.position = Vector2(12, 8)
    status_label.size = Vector2(240, 56)
    status_label.text = "NPC LIFE\nLoading population…"
    panel.add_child(status_label)

func _update_status() -> void:
    if not is_instance_valid(status_label):
        return
    var counts := {}
    var alerts := 0
    for npc in npcs:
        var job := String(npc.get("job", "unknown"))
        counts[job] = int(counts.get(job, 0)) + 1
        if bool(npc.get("alert", false)):
            alerts += 1
    status_label.text = "NPC LIFE  •  %d active\nF:%d M:%d C:%d G:%d  •  ALERT:%d" % [
        npcs.size(), int(counts.get("farmer",0)), int(counts.get("merchant",0)),
        int(counts.get("craftsman",0)), int(counts.get("guard",0)), alerts
    ]

func get_save_state() -> Dictionary:
    var out := []
    for npc in npcs:
        var node := npc.get("node") as Node3D
        out.append({
            "id": npc.get("id",-1), "settlement": npc.get("settlement",-1),
            "job": npc.get("job","traveler"), "state": npc.get("state","work"),
            "hunger": npc.get("hunger",0), "morale": npc.get("morale",70),
            "alert": npc.get("alert",false),
            "position": node.position if is_instance_valid(node) else Vector3.ZERO
        })
    return {"npcs": out, "ai_memory": ai_memory}

func load_save_state(data: Dictionary) -> void:
    ai_memory = data.get("ai_memory", {})
    for item in data.get("npcs", []):
        var id := int(item.get("id",-1))
        for npc in npcs:
            if int(npc.get("id",-2)) == id:
                npc["state"] = item.get("state","work")
                npc["hunger"] = float(item.get("hunger",0))
                npc["morale"] = int(item.get("morale",70))
                npc["alert"] = bool(item.get("alert",false))
                var node := npc.get("node") as Node3D
                if is_instance_valid(node):
                    node.position = item.get("position", node.position)
                break
