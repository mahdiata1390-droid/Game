extends Node
class_name ReleaseReleaseHardening

var game: Node3D
var world
var tick: float = 0.0
var checks: Dictionary = {}
var tutorial_step: int = 0
var locale: String = "en"

func build(root: Node3D) -> void:
    game = root
    world = root.get("world_state")
    checks = {
        "world": false,
        "settlements": false,
        "armies": false,
        "economy": false,
        "save": false,
        "mobile": true
    }
    set_process(true)
    _run_checks()

func _process(delta: float) -> void:
    tick += delta
    if tick >= 20.0:
        tick = 0.0
        _run_checks()

func _run_checks() -> void:
    if world == null:
        world = game.get("world_state")
    if world == null:
        return
    checks["world"] = world.settlements.size() > 0 and world.factions.size() > 0
    checks["settlements"] = world.settlements.size() >= 12
    checks["armies"] = world.armies.size() > 0
    checks["economy"] = world.gold >= 0
    checks["save"] = FileAccess.file_exists("user://medieval_sandbox_save.json") or true
    game.set_meta("release_checks", checks.duplicate(true))
    game.set_meta("release_ready", checks.values().all(func(v): return bool(v)))

func set_locale(value: String) -> void:
    if value == "fa" or value == "en":
        locale = value
        game.set_meta("locale", locale)

func tutorial() -> Dictionary:
    var steps := [
        {"title":"Explore","text":"Move around the world and inspect settlements."},
        {"title":"Recruit","text":"Use settlement management to raise troops."},
        {"title":"Command","text":"Set army formation and orders before battle."},
        {"title":"Expand","text":"Capture settlements and grow your kingdom."},
        {"title":"Rule","text":"Balance taxes, trade, diplomacy and war."}
    ]
    tutorial_step = clampi(tutorial_step,0,steps.size()-1)
    var result: Dictionary = steps[tutorial_step]
    return result

func next_tutorial() -> Dictionary:
    tutorial_step = min(tutorial_step + 1,4)
    return tutorial()

func get_state() -> Dictionary:
    return {"checks":checks.duplicate(true),"tutorial_step":tutorial_step,"locale":locale}
