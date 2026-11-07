extends Node
class_name ReleaseCampaignLoop

# Integration layer for the sandbox campaign.
# Connects the already-built economy, settlement, army, kingdom and world systems
# into one persistent gameplay loop without replacing their existing APIs.

var game: Node3D
var world: Node
var kingdom: Node
var command_center: Node
var army_manager: Node
var playable_world: Node
var final_pass: Node
var tick: float = 0.0
var sync_interval: float = 2.0
var campaign_state: Dictionary = {
    "started": false,
    "origin": "free_company",
    "phase": "survival",
    "owned_settlements": 0,
    "armies": 0,
    "treasury": 0,
    "power": 0,
    "tax_income": 0,
    "caravans": 0,
    "next_objective": "Secure your first settlement"
}

func build(root: Node3D) -> void:
    game = root
    world = root.get_node_or_null("WorldState")
    kingdom = root.get_node_or_null("KingdomSystems")
    command_center = root.get_node_or_null("ReleaseCampaignCommandCenter")
    army_manager = root.get_node_or_null("ReleaseArmyAndSettlementManager")
    playable_world = root.get_node_or_null("PlayableWorld")
    final_pass = root.get_node_or_null("FinalGamePass")
    if world == null:
        return
    campaign_state["started"] = true
    _sync_campaign_state()
    game.set_meta("campaign_loop_ready", true)
    set_process(true)

func _process(delta: float) -> void:
    if world == null:
        world = game.get("world_state")
        return
    tick += delta
    if tick >= sync_interval:
        tick = 0.0
        _sync_campaign_state()

func _sync_campaign_state() -> void:
    var faction := String(world.get("player_faction"))
    var owned := 0
    var settlements: Array = world.get("settlements")
    for settlement in settlements:
        if String(settlement.get("owner", "")) == faction:
            owned += 1

    var armies := 0
    var power := 0
    var army_list: Array = world.get("armies")
    for army in army_list:
        if String(army.get("owner", "")) == faction:
            armies += 1
            power += int(army.get("soldiers", 0)) + int(army.get("morale", 0))

    var treasury := 0
    var factions: Array = world.get("factions")
    for f in factions:
        if String(f.get("id", "")) == faction:
            treasury = int(f.get("treasury", 0))
            break

    campaign_state["owned_settlements"] = owned
    campaign_state["armies"] = armies
    campaign_state["treasury"] = treasury
    campaign_state["power"] = power
    campaign_state["tax_income"] = _estimate_tax_income(faction)
    campaign_state["caravans"] = world.caravans.size()
    campaign_state["phase"] = _get_phase(owned, armies, power)
    campaign_state["next_objective"] = _get_objective(owned, armies, power)

    game.set_meta("campaign_phase", campaign_state["phase"])
    game.set_meta("campaign_owned_settlements", owned)
    game.set_meta("campaign_armies", armies)
    game.set_meta("campaign_power", power)

func _get_phase(owned: int, armies: int, power: int) -> String:
    if owned >= 8 and armies >= 4:
        return "kingdom"
    if owned >= 3 and armies >= 2:
        return "warlord"
    if armies >= 1 or power >= 100:
        return "chieftain"
    return "survival"

func set_origin(origin: String) -> Dictionary:
    if world == null:
        return {"ok": false, "reason": "world_not_ready"}

    var presets := {
        "free_company": {"gold": 250, "food": 30, "wood": 10, "iron": 5, "region": 0},
        "merchant": {"gold": 450, "food": 45, "wood": 20, "iron": 8, "region": 2},
        "frontier": {"gold": 180, "food": 55, "wood": 25, "iron": 12, "region": 7},
        "noble_exile": {"gold": 600, "food": 35, "wood": 15, "iron": 10, "region": 5}
    }
    if not presets.has(origin):
        return {"ok": false, "reason": "invalid_origin"}

    var preset: Dictionary = presets[origin]
    world.set("gold", int(preset["gold"]))
    world.set("player_region_id", int(preset["region"]))
    world.set("player_start", origin)
    world.set("player_mode", origin)
    world.set("player_inventory", {
        "food": int(preset["food"]),
        "wood": int(preset["wood"]),
        "iron": int(preset["iron"])
    })
    campaign_state["origin"] = origin
    _sync_campaign_state()
    return {"ok": true, "origin": origin, "phase": campaign_state["phase"]}

func get_state() -> Dictionary:
    return campaign_state.duplicate(true)

func get_save_state() -> Dictionary:
    return get_state()

func load_save_state(data: Dictionary) -> void:
    campaign_state = data.duplicate(true)
    if world != null:
        _sync_campaign_state()


func _estimate_tax_income(faction: String) -> int:
    var income := 0
    var settlements: Array = world.get("settlements")
    for settlement in settlements:
        if String(settlement.get("owner", "")) == faction:
            var population := int(settlement.get("population", 0))
            var tax_rate := float(settlement.get("tax_rate", 0.10))
            income += max(1, int(population * tax_rate / 100.0))
    return income

func _get_objective(owned: int, armies: int, power: int) -> String:
    if owned <= 0:
        return "Secure your first settlement"
    if armies <= 0:
        return "Raise your first army"
    if owned < 3:
        return "Expand to 3 settlements"
    if armies < 2:
        return "Raise a second army"
    if owned < 8:
        return "Build a regional kingdom"
    return "Dominate the world through war, trade and diplomacy"

func advance_campaign_day() -> Dictionary:
    if world == null:
        return {"ok": false, "reason": "world_not_ready"}
    world.advance_day()
    _sync_campaign_state()
    return {"ok": true, "day": int(world.get("day")), "phase": campaign_state["phase"], "objective": campaign_state["next_objective"]}

func get_progress() -> Dictionary:
    _sync_campaign_state()
    return campaign_state.duplicate(true)
