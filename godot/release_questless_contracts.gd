extends Node
class_name ReleaseContracts

var host:Node
var active:Dictionary={}
var timer=0.0

func build(main:Node)->void:
	host=main
	set_process(true)

func _process(delta:float)->void:
	timer+=delta
	if timer<8.0:return
	timer=0.0
	if not host or not host.world_state:return
	if active.is_empty():
		var options=["Trade convoy","Guard settlement","Scout frontier","Escort caravan"]
		var kind=options[randi()%options.size()]
		active={"type":kind,"reward":randi_range(60,180),"expires":host.world_state.day+3}
		host.world_state.world_events.append("New contract: %s. Reward %dg." % [kind,int(active["reward"])])

func accept()->Dictionary:
	if active.is_empty():return {"ok":false,"reason":"no_contract"}
	host.world_state.world_events.append("Contract accepted: %s." % String(active["type"]))
	return {"ok":true,"contract":active}

func clear()->void:
	active.clear()
