extends Node
class_name WorldState

var day: int = 1
var gold: int = 250
var player_faction: String = "Free Company"
var player_start: String = "ordinary"
var regions: Array[Dictionary] = []
var factions: Array[Dictionary] = []
var settlements: Array[Dictionary] = []
var armies: Array[Dictionary] = []
var diplomacy: Dictionary = {}

func initialize_continent() -> void:
	regions.clear()
	factions.clear()
	settlements.clear()
	armies.clear()
	diplomacy.clear()
	var faction_defs := [
		{"id":"north_kingdom","name":"Kingdom of Nordmark","type":"kingdom","color":Color(0.12,0.32,0.82)},
		{"id":"river_kingdom","name":"Kingdom of Valoria","type":"kingdom","color":Color(0.18,0.62,0.34)},
		{"id":"eastern_tribes","name":"Eastern Tribes","type":"tribe","color":Color(0.72,0.28,0.12)},
		{"id":"southern_sultanate","name":"Sultanate of Sahr","type":"kingdom","color":Color(0.72,0.56,0.14)},
		{"id":"western_clans","name":"Western Clans","type":"tribe","color":Color(0.42,0.20,0.62)}
	]
	for f in faction_defs:
		f["relations"] = {}
		f["territory"] = []
		factions.append(f)
	var region_defs := [
		["Highlands",Vector2(-18,-13),"iron","north_kingdom"],
		["Pine March",Vector2(-6,-15),"wood","north_kingdom"],
		["Kingsroad",Vector2(7,-14),"grain","river_kingdom"],
		["Eastern Steppe",Vector2(19,-9),"horses","eastern_tribes"],
		["Frost Coast",Vector2(-20,0),"fish","north_kingdom"],
		["Heartland",Vector2(-5,-1),"grain","river_kingdom"],
		["Golden Fields",Vector2(8,-1),"grain","river_kingdom"],
		["Red Frontier",Vector2(19,2),"salt","eastern_tribes"],
		["Western Forest",Vector2(-17,12),"wood","western_clans"],
		["Central Basin",Vector2(-3,11),"stone","river_kingdom"],
		["Sahr Desert",Vector2(10,12),"spice","southern_sultanate"],
		["Southern Coast",Vector2(20,15),"fish","southern_sultanate"]
	]
	for i in range(region_defs.size()):
		var d = region_defs[i]
		regions.append({"id":i,"name":d[0],"owner":d[3],"position":d[1],"resource":d[2],"population":1200 + i * 180,"prosperity":45 + (i * 7) % 40})
		_get_faction(d[3])["territory"].append(i)
	_add_settlement("Northwatch","castle",0,Vector2(-18,-13), "north_kingdom", 720)
	_add_settlement("Pinehaven","village",1,Vector2(-6,-15), "north_kingdom", 260)
	_add_settlement("Valoria","city",2,Vector2(7,-14), "river_kingdom", 1450)
	_add_settlement("Steppe Camp","village",3,Vector2(19,-9), "eastern_tribes", 310)
	_add_settlement("Frostport","town",4,Vector2(-20,0), "north_kingdom", 610)
	_add_settlement("Kingsbridge","city",5,Vector2(-5,-1), "river_kingdom", 1300)
	_add_settlement("Goldford","town",6,Vector2(8,-1), "river_kingdom", 820)
	_add_settlement("Redstone","castle",7,Vector2(19,2), "eastern_tribes", 540)
	_add_settlement("Clanhold","castle",8,Vector2(-17,12), "western_clans", 490)
	_add_settlement("Basinfield","village",9,Vector2(-3,11), "river_kingdom", 280)
	_add_settlement("Sahr","city",10,Vector2(10,12), "southern_sultanate", 1600)
	_add_settlement("Pearl Bay","town",11,Vector2(20,15), "southern_sultanate", 730)
	_add_army("Northwatch Host","north_kingdom",0,180)
	_add_army("Valoria Royal Army","river_kingdom",2,260)
	_add_army("Steppe Riders","eastern_tribes",3,210)
	_add_army("Sahr Expedition","southern_sultanate",10,240)
	_add_army("Western Warband","western_clans",8,150)
	for a in factions:
		for b in factions:
			if a["id"] != b["id"]:
				a["relations"][b["id"]] = 0
	diplomacy["north_kingdom|river_kingdom"] = "peace"
	diplomacy["river_kingdom|eastern_tribes"] = "war"
	diplomacy["western_clans|river_kingdom"] = "war"
	diplomacy["southern_sultanate|river_kingdom"] = "peace"

func _add_settlement(name: String, kind: String, region_id: int, position: Vector2, owner: String, population: int) -> void:
	settlements.append({"id":settlements.size(),"name":name,"type":kind,"region":region_id,"position":position,"owner":owner,"population":population,"prosperity":50,"garrison":40 if kind == "village" else 100})

func _add_army(name: String, owner: String, region_id: int, soldiers: int) -> void:
	armies.append({"id":armies.size(),"name":name,"owner":owner,"region":region_id,"soldiers":soldiers,"morale":75,"food":100,"moving":false,"target_region":region_id})

func _get_faction(id: String) -> Dictionary:
	for f in factions:
		if f["id"] == id:
			return f
	return {}

func advance_day() -> void:
	day += 1
	for region in regions:
		region["prosperity"] = clamp(int(region["prosperity"]) + randi_range(-2, 2), 0, 100)
		region["population"] = int(region["population"]) + max(1, int(region["population"]) / 500)
	for settlement in settlements:
		settlement["prosperity"] = clamp(int(settlement["prosperity"]) + randi_range(-1, 2), 0, 100)
	for army in armies:
		army["food"] = max(0, int(army["food"]) - max(1, int(army["soldiers"]) / 80))
		if int(army["food"]) == 0:
			army["morale"] = max(0, int(army["morale"]) - 3)

func get_faction_color(id: String) -> Color:
	var f := _get_faction(id)
	return f.get("color", Color.WHITE)
