extends Node
class_name ReleaseArmyTacticalAI

var host: Node
var timer := 0.0

func build(main: Node) -> void:
	host=main
	set_process(true)

func _process(delta: float) -> void:
	timer+=delta
	if timer<4.0:return
	timer=0.0
	if not host or not host.world_state:return
	for a in host.world_state.armies:
		var order:=String(a.get("order","hold"))
		var formation:=String(a.get("formation","line"))
		if order=="attack":
			a["morale"]=min(100,int(a.get("morale",70))+2)
		elif order=="defend":
			a["morale"]=min(100,int(a.get("morale",70))+1)
		elif order=="raid":
			a["morale"]=max(0,int(a.get("morale",70))-1)
		if formation=="shield_wall":
			a["morale"]=min(100,int(a.get("morale",70))+1)
