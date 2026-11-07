extends Node
class_name ReleaseReinforcementSystem

var host: Node3D
var world
var timer: float = 0.0
var reinforcements: int = 0
var last_event: String = "REINFORCEMENT SYSTEM ONLINE"

func build(root: Node3D) -> void:
	host = root
	world = root.get("world_state")
	set_process(true)

func _process(delta: float) -> void:
	timer += delta
	if timer < 20.0:
		return
	timer = 0.0
	_run_reinforcement_pass()

func _run_reinforcement_pass() -> void:
	if world == null:
		return
	for army in world.armies:
		if String(army.get("owner","")) != String(world.player_faction):
			continue
		if int(army.get("soldiers",0)) <= 0:
			continue
		if int(army.get("soldiers",0)) >= 80:
			continue
		var settlement := _nearest_owned_settlement(int(army.get("region",0)))
		if settlement.is_empty():
			continue
		var available := max(0, int(settlement.get("garrison",0)) - 25)
		var amount := min(10, available)
		if amount <= 0:
			continue
		settlement["garrison"] = int(settlement.get("garrison",0)) - amount
		army["soldiers"] = int(army.get("soldiers",0)) + amount
		army["troops"]["levy"] = int(army["troops"].get("levy",0)) + amount
		army["morale"] = min(90, int(army.get("morale",75)) + 2)
		reinforcements += amount
		last_event = "%s reinforced by %d." % [String(army.get("name","Army")), amount]
		world.world_events.append(last_event)

func _nearest_owned_settlement(region_id: int) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 999
	for s in world.settlements:
		if String(s.get("owner","")) != String(world.player_faction):
			continue
		var d := abs(int(s.get("region",0)) - region_id)
		if d < best_distance:
			best_distance = d
			best = s
	return best

func get_state() -> Dictionary:
	return {"reinforcements": reinforcements, "last_event": last_event}
