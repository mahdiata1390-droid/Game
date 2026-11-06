extends Node
class_name ReleasePopulationSimulation

var host:Node
var timer:=0.0

func build(main:Node)->void:
	host=main
	set_process(true)

func _process(delta:float)->void:
	timer+=delta
	if timer<6.0:return
	timer=0.0
	if not host or not host.world_state:return
	for s in host.world_state.settlements:
		var prosperity:=int(s.get("prosperity",50))
		var pop:=int(s.get("population",0))
		if prosperity>=70:
			s["population"]=pop+max(1,int(pop/700))
		elif prosperity<=25:
			s["population"]=max(50,pop-max(1,int(pop/1200)))
		if String(s.get("owner",""))==host.world_state.player_faction:
			s["stockpile"]["food"]=int(s["stockpile"].get("food",0))+max(0,int(s["buildings"].get("farm",1))-1)
