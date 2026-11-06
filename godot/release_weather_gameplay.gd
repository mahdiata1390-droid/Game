extends Node
class_name ReleaseWeatherGameplay

var host:Node
var last_weather:=""

func build(main:Node)->void:
	host=main
	set_process(true)

func _process(_delta:float)->void:
	if not host or not host.world_state:return
	var w:=String(host.world_state.weather)
	if w==last_weather:return
	last_weather=w
	if w=="storm":
		host.PLAYER_SPEED=3.2
	elif w=="snow":
		host.PLAYER_SPEED=3.6
	elif w=="rain":
		host.PLAYER_SPEED=4.0
	else:
		host.PLAYER_SPEED=4.5
