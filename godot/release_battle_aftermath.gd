extends Node
class_name ReleaseBattleAftermath

## Post-battle rewards: loot, prisoners, wounded recovery and morale.

var game: Node3D
var world
var processed_battles: int = 0
var total_loot: int = 0
var total_prisoners: int = 0
var total_wounded: int = 0
var last_event: String = "BATTLE AFTERMATH ONLINE"

func build(main_node: Node3D) -> void:
	game = main_node
	world = game.get("world_state")
	set_process(true)

func _process(_delta: float) -> void:
	if world == null:
		world = game.get("world_state")
		return
	var events: Array = world.battle_events
	while processed_battles < events.size():
		_process_battle(events[processed_battles])
		processed_battles += 1

func _process_battle(result: Dictionary) -> void:
	var attacker_won: bool = bool(result.get("attacker_won", false))
	var attacker: String = String(result.get("attacker", ""))
	var attacker_losses: int = max(0, int(result.get("attacker_losses", 0)))
	var defender_losses: int = max(0, int(result.get("defender_losses", 0)))
	var settlement_name: String = String(result.get("settlement", "Battlefield"))
	var victor_losses: int = attacker_losses if attacker_won else defender_losses
	var defeated_losses: int = defender_losses if attacker_won else attacker_losses
	var prisoners: int = max(0, int(defeated_losses * 0.12))
	var loot: int = max(5, int(defeated_losses * 2 + victor_losses))
	var wounded: int = max(0, int(victor_losses * 0.35))
	result["prisoners"] = prisoners
	result["loot"] = loot
	result["wounded"] = wounded
	result["aftermath"] = "Victory aftermath" if attacker_won else "Defeat aftermath"
	if attacker_won and attacker == String(world.player_faction):
		world.gold += loot
		total_loot += loot
		total_prisoners += prisoners
		total_wounded += wounded
		world.world_events.append("Victory at %s: %d gold, %d prisoners, %d wounded." % [settlement_name, loot, prisoners, wounded])
	else:
		world.world_events.append("Battle aftermath at %s: %d prisoners captured." % [settlement_name, prisoners])
	last_event = "%s • loot %d • prisoners %d • wounded %d" % [settlement_name, loot, prisoners, wounded]

func get_state() -> Dictionary:
	return {"processed_battles": processed_battles, "total_loot": total_loot, "total_prisoners": total_prisoners, "total_wounded": total_wounded, "last_event": last_event}
