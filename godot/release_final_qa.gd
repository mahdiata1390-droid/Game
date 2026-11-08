extends Node
class_name ReleaseFinalQA

var game: Node3D
var world: Node
var results: Array[String] = []
var passed := 0
var failed := 0

func build(main_node: Node3D) -> void:
    game = main_node

func run_checks() -> Dictionary:
    results.clear()
    passed = 0
    failed = 0
    world = game.get("world_state") if is_instance_valid(game) else null
    _check(world != null, "WorldState exists")
    if world != null:
        _check(world.regions.size() >= 12, "Continent regions initialized")
        _check(world.settlements.size() >= 48, "Minor settlements populated")
        _check(world.factions.size() >= 6, "Factions initialized")
        _check(world.armies.size() >= 8, "Autonomous armies initialized")
        _check(world.ships.size() >= 2, "Naval layer initialized")
        _check(world.has_method("save_game"), "Save system available")
        _check(world.has_method("load_game"), "Load system available")
        _check(world.has_method("resolve_auto_battle"), "Auto battle engine connected")
        _check(world.has_method("apply_manual_battle_result"), "Manual battle engine connected")
        _check(world.has_method("start_siege"), "Siege engine connected")
        _check(world.has_method("issue_ship_move"), "Naval movement connected")
        _check(world.has_method("set_diplomacy"), "Diplomacy connected")
        _check(world.has_method("trade_resource"), "Economy connected")
    var required_nodes := [
        "CombatSystem", "NpcAiSystem", "SiegeStage", "ExpansionStages",
        "KingdomSystems", "Stages15to19", "Stages20to29", "Stages30to39",
        "Stages40to49", "FinalGamePass", "PlayableWorld",
        "VisualWorld"
    ]
    for node_name in required_nodes:
        _check(game.get_node_or_null(node_name) != null, "Connected: " + node_name)
    var visual = game.get_node_or_null("VisualWorld")
    _check(visual != null, "Authored visual world connected")
    return {
        "ok": failed == 0,
        "passed": passed,
        "failed": failed,
        "results": results.duplicate()
    }

func _check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
        results.append("PASS: " + label)
    else:
        failed += 1
        results.append("FAIL: " + label)
