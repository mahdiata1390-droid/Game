extends Node
class_name ReleaseAftermathRecovery

var host: Node3D
var world
var timer: float = 0.0
var recovered_wounded: int = 0
var released_prisoners: int = 0

func build(root: Node3D) -> void:
	host = root
	world = root.get("world_state")
	set_process(true)

func _process(delta: float) -> void:
	timer += delta
	if timer < 16.0:
		return
	timer = 0.0
	_recover()

func _recover() -> void:
	if world == null:
		return
	for army in world.armies:
		if String(army.get("owner","")) != String(world.player_faction):
			continue
		var wounded := int(army.get("wounded",0))
		if wounded > 0:
			var healed := min(5, wounded)
			army["wounded"] = wounded - healed
			army["soldiers"] = int(army.get("soldiers",0)) + healed
			recovered_wounded += healed
		var prisoners := int(army.get("prisoners",0))
		if prisoners > 0 and int(army.get("morale",75)) >= 70:
			var released := min(2, prisoners)
			army["prisoners"] = prisoners - released
			released_prisoners += released
		if int(army.get("morale",75)) < 70 and int(army.get("soldiers",0)) > 0:
			army["morale"] = min(70, int(army.get("morale",75)) + 1)

func get_state() -> Dictionary:
	return {"recovered_wounded": recovered_wounded, "released_prisoners": released_prisoners}
