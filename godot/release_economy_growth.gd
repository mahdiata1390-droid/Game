extends Node
class_name ReleaseEconomyGrowth

## Combined stage: settlement growth + deeper economy.
## Production, stockpiles, market pressure, prosperity and faction treasuries
## evolve automatically while the sandbox is running.

var game:Node3D
var world:Node
var tick:=0.0
var last_event:="ECONOMY ONLINE"

func build(main_node:Node3D)->void:
	game=main_node
	world=game.get("world_state")
	set_process(true)

func _process(delta:float)->void:
	if world==null:
		world=game.get("world_state")
		return
	tick+=delta
	if tick<12.0: return
	tick=0.0
	_simulate_economy()

func _simulate_economy()->void:
	for settlement in world.settlements:
		var prosperity:=int(settlement.get("prosperity",50))
		var buildings:Dictionary=settlement.get("buildings",{})
		var stock:Dictionary=settlement.get("stockpile",{})
		var region:=int(settlement.get("region",0))
		var resource:=String(world.regions[region].get("resource","grain"))
		var output:=max(1,int(prosperity/20))
		if resource=="grain": stock["food"]=int(stock.get("food",0))+output
		elif resource=="wood": stock["wood"]=int(stock.get("wood",0))+output
		elif resource=="iron": stock["iron"]=int(stock.get("iron",0))+output
		if int(stock.get("food",0))>140: prosperity+=1
		elif int(stock.get("food",0))<30: prosperity-=2
		if int(settlement.get("garrison",0))>40: prosperity+=1
		else: prosperity-=1
		if int(settlement.get("population",0))>500 and prosperity>70:
			_try_upgrade(settlement,buildings)
		settlement["prosperity"]=clampi(prosperity,0,100)
		settlement["stockpile"]=stock
		_update_prices(settlement)
	last_event="Markets, production and settlement growth updated"

func _try_upgrade(settlement:Dictionary,buildings:Dictionary)->void:
	var order:=["farm","workshop","market","barracks"]
	for building in order:
		var level:=int(buildings.get(building,1))
		if level<5:
			buildings[building]=level+1
			settlement["buildings"]=buildings
			return

func _update_prices(settlement:Dictionary)->void:
	var prosperity:=int(settlement.get("prosperity",50))
	var stock:Dictionary=settlement.get("stockpile",{})
	var prices:=settlement.get("dynamic_prices",{})
	prices["food"]=clampi(12+int((60-prosperity)/4)-int(stock.get("food",0)/50),2,30)
	prices["wood"]=clampi(14+int((60-prosperity)/5)-int(stock.get("wood",0)/35),3,35)
	prices["iron"]=clampi(20+int((60-prosperity)/6)-int(stock.get("iron",0)/25),5,45)
	settlement["dynamic_prices"]=prices

func get_state()->Dictionary:
	return {"last_event":last_event}
