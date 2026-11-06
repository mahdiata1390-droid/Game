extends Node
class_name WorldState

var day: int = 1
var gold: int = 250
var player_faction: String = "Free Company"
var player_start: String = "ordinary"
var player_region_id: int = 0
var regions: Array[Dictionary] = []
var factions: Array[Dictionary] = []
var settlements: Array[Dictionary] = []
var armies: Array[Dictionary] = []
var player_mode:String = "ordinary"
var player_level:int = 1
var player_xp:int = 0
var player_inventory:Dictionary = {"food":30,"wood":10,"iron":5}
var diplomacy: Dictionary = {}
var battle_events: Array[Dictionary] = []
var world_events: Array[String] = []
var battle_cooldowns: Dictionary = {}
var caravans:Array[Dictionary] = []
var ships:Array[Dictionary] = []
var family:Dictionary = {"age":18,"generation":1,"heir_name":"Unnamed Heir","heir_age":0}
var weather:String = "clear"
var time_of_day:float = 8.0
var yearly_tax:int = 0
var player_income:int = 0
var save_path:String = "user://one_continent_save.json"
var sieges:Dictionary = {}
var player_equipment:Dictionary = {"weapon":"iron_sword","armor":"leather_armor","horse":"none","shield":"wooden_shield"}
var family_members:Array[Dictionary] = []
var player_buildings:Dictionary = {}
var production_stock:Dictionary = {"food":30,"wood":10,"iron":5}
var faction_ai_state:Dictionary = {}
var simulation_paused: bool = false
var complete_gameplay_state: Dictionary = {}


func initialize_continent() -> void:
	regions.clear(); factions.clear(); settlements.clear(); armies.clear(); diplomacy.clear(); caravans.clear(); ships.clear(); battle_events.clear(); world_events.clear(); battle_cooldowns.clear(); sieges.clear(); family_members.clear(); player_buildings.clear(); faction_ai_state.clear(); day=1; gold=250; player_level=1; player_xp=0; player_mode="ordinary"; player_region_id=0; player_inventory={"food":30,"wood":10,"iron":5}; production_stock={"food":30,"wood":10,"iron":5}; player_equipment={"weapon":"iron_sword","armor":"leather_armor","horse":"none","shield":"wooden_shield"}; family={"age":18,"generation":1,"heir_name":"Unnamed Heir","heir_age":0}
	var faction_defs := [
		{"id":"Free Company","name":"Free Company","type":"player","culture":"Free Company","color":Color(0.28,0.31,0.34),"banner":Color(0.08,0.09,0.11),"accent":Color(0.78,0.68,0.38),"emblem":"cross"},
		{"id":"north_kingdom","name":"Kingdom of Nordmark","type":"kingdom","culture":"Nordmarki","color":Color(0.10,0.20,0.42),"banner":Color(0.055,0.11,0.25),"accent":Color(0.86,0.88,0.90),"emblem":"wolf"},
		{"id":"river_kingdom","name":"Kingdom of Valoria","type":"kingdom","culture":"Valorian","color":Color(0.58,0.38,0.12),"banner":Color(0.13,0.09,0.06),"accent":Color(0.92,0.72,0.22),"emblem":"stag"},
		{"id":"eastern_tribes","name":"Eastern Tribes","type":"tribe","culture":"Steppe Clans","color":Color(0.72,0.18,0.10),"banner":Color(0.34,0.055,0.035),"accent":Color(0.90,0.74,0.36),"emblem":"falcon"},
		{"id":"southern_sultanate","name":"Sultanate of Sahr","type":"kingdom","culture":"Sahrian","color":Color(0.72,0.48,0.08),"banner":Color(0.16,0.10,0.045),"accent":Color(0.95,0.78,0.28),"emblem":"sun"},
		{"id":"western_clans","name":"Western Clans","type":"tribe","culture":"Western Clans","color":Color(0.30,0.18,0.42),"banner":Color(0.10,0.075,0.13),"accent":Color(0.72,0.78,0.76),"emblem":"raven"}]
	for f in faction_defs:
		f["relations"] = {}; f["territory"] = []; f["treasury"] = 1000 if f["id"] != "Free Company" else 250; factions.append(f)
	var region_defs := [
		["Highlands",Vector2(-18,-13),"iron","north_kingdom"],["Pine March",Vector2(-6,-15),"wood","north_kingdom"],["Kingsroad",Vector2(7,-14),"grain","river_kingdom"],["Eastern Steppe",Vector2(19,-9),"horses","eastern_tribes"],["Frost Coast",Vector2(-20,0),"fish","north_kingdom"],["Heartland",Vector2(-5,-1),"grain","river_kingdom"],["Golden Fields",Vector2(8,-1),"grain","river_kingdom"],["Red Frontier",Vector2(19,2),"salt","eastern_tribes"],["Western Forest",Vector2(-17,12),"wood","western_clans"],["Central Basin",Vector2(-3,11),"stone","river_kingdom"],["Sahr Desert",Vector2(10,12),"spice","southern_sultanate"],["Southern Coast",Vector2(20,15),"fish","southern_sultanate"]]
	for i in range(region_defs.size()):
		var d = region_defs[i]
		regions.append({"id":i,"name":d[0],"owner":d[3],"position":d[1],"resource":d[2],"population":1200+i*180,"prosperity":45+(i*7)%40})
		_get_faction(d[3])["territory"].append(i)
	_add_settlement("Northwatch","castle",0,Vector2(-18,-13),"north_kingdom",720); _add_settlement("Pinehaven","village",1,Vector2(-6,-15),"north_kingdom",260); _add_settlement("Valoria","city",2,Vector2(7,-14),"river_kingdom",1450); _add_settlement("Steppe Camp","village",3,Vector2(19,-9),"eastern_tribes",310); _add_settlement("Frostport","town",4,Vector2(-20,0),"north_kingdom",610); _add_settlement("Kingsbridge","city",5,Vector2(-5,-1),"river_kingdom",1300); _add_settlement("Goldford","town",6,Vector2(8,-1),"river_kingdom",820); _add_settlement("Redstone","castle",7,Vector2(19,2),"eastern_tribes",540); _add_settlement("Clanhold","castle",8,Vector2(-17,12),"western_clans",490); _add_settlement("Basinfield","village",9,Vector2(-3,11),"river_kingdom",280); _add_settlement("Sahr","city",10,Vector2(10,12),"southern_sultanate",1600); _add_settlement("Pearl Bay","town",11,Vector2(20,15),"southern_sultanate",730)
	_populate_minor_settlements()
	_add_army("Northwatch Host","north_kingdom",0,180); _add_army("Valoria Royal Army","river_kingdom",2,260); _add_army("Steppe Riders","eastern_tribes",3,210); _add_army("Sahr Expedition","southern_sultanate",10,240); _add_army("Western Warband","western_clans",8,150); _add_army("Frost Patrol","north_kingdom",4,95); _add_army("Heartland Guard","river_kingdom",5,120); _add_army("Red Frontier Riders","eastern_tribes",7,130); _add_army("Sahr Coast Guard","southern_sultanate",11,105); _add_army("Forest Raiders","western_clans",9,85); _add_army("Kingsroad Escort","river_kingdom",6,110)
	_add_army("Free Company Host","Free Company",0,90)
	ships.append({"id":0,"name":"Pearl Trader","owner":"southern_sultanate","region":11,"crew":35,"cargo":{"food":40,"wood":15,"iron":5},"moving":false,"target_region":11})
	ships.append({"id":1,"name":"Frost Cutter","owner":"north_kingdom","region":4,"crew":28,"cargo":{"food":25,"wood":25,"iron":3},"moving":false,"target_region":4})
	for a in factions:
		for b in factions:
			if a["id"] != b["id"]: a["relations"][b["id"]] = 0
	diplomacy["north_kingdom|river_kingdom"]="peace"; diplomacy["river_kingdom|eastern_tribes"]="war"; diplomacy["western_clans|river_kingdom"]="war"; diplomacy["southern_sultanate|river_kingdom"]="peace"

func _populate_minor_settlements() -> void:
	# Fill the continent with deterministic hamlets, farms and small market villages.
	# These are real campaign settlements: they produce resources, collect taxes,
	# can be conquered, and appear on the strategic map.
	var suffixes := ["Ash", "Brook", "Cross", "Dale", "Field", "Glen", "Hill", "Mead", "Oak", "Pine", "Stone", "Vale"]
	for region_id in range(regions.size()):
		var region: Dictionary = regions[region_id]
		var center: Vector2 = region["position"]
		var owner := String(region["owner"])
		for slot in range(3):
			var angle := deg_to_rad(float((region_id * 97 + slot * 121) % 360))
			var radius := 2.2 + float(slot) * 1.15
			var pos := center + Vector2(cos(angle), sin(angle)) * radius
			var name := "%s %s" % [String(suffixes[(region_id * 3 + slot) % suffixes.size()]), String(suffixes[(region_id + slot * 2 + 3) % suffixes.size()])]
			var population := 120 + ((region_id * 83 + slot * 47) % 260)
			_add_settlement(name, "village", region_id, pos, owner, population)


func _add_settlement(name:String,kind:String,region_id:int,position:Vector2,owner:String,population:int)->void:
	var garrison_count := 40 if kind=="village" else 100
	var garrison_troops := {"levy":int(garrison_count*0.55),"spearman":int(garrison_count*0.20),"archer":int(garrison_count*0.20),"horseman":max(0,garrison_count-int(garrison_count*0.55)-int(garrison_count*0.20)-int(garrison_count*0.20))}
	settlements.append({"id":settlements.size(),"name":name,"type":kind,"region":region_id,"position":position,"owner":owner,"population":population,"prosperity":50,"garrison":garrison_count,"garrison_troops":garrison_troops,"wall_level":1 if kind=="village" else (3 if kind=="town" else (5 if kind=="castle" else 2)),"buildings":{"farm":1,"workshop":1,"market":1,"barracks":1},"stockpile":{"food":80,"wood":30,"iron":15},"tax_rate":0.10,"siege":false})

func _add_army(name:String,owner:String,region_id:int,soldiers:int)->void:
	armies.append({"id":armies.size(),"name":name,"owner":owner,"region":region_id,"soldiers":soldiers,"morale":75,"food":100,"moving":false,"target_region":region_id,"formation":"line","order":"hold","commander":"Captain","equipment":{"weapons":1,"armor":1,"mounts":0},"troops":{"levy":soldiers,"spearman":0,"archer":0,"horseman":0}})

func _get_faction(id:String)->Dictionary:
	for f in factions:
		if f["id"]==id: return f
	return {}

func recruit_from_settlement(settlement_id:int,troop_type:String,count:int)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size(): return {"ok":false,"reason":"invalid_settlement"}
	if count<=0: return {"ok":false,"reason":"invalid_count"}
	var settlement:Dictionary=settlements[settlement_id]; var available:=max(0,int(settlement["population"])/12-int(settlement["garrison"])); var recruit_count:=min(count,available)
	if recruit_count<=0: return {"ok":false,"reason":"no_recruits"}
	var costs={"levy":5,"spearman":9,"archer":11,"horseman":18}
	if not costs.has(troop_type): return {"ok":false,"reason":"invalid_troop_type"}
	var total_cost:=recruit_count*int(costs[troop_type])
	if gold<total_cost: return {"ok":false,"reason":"not_enough_gold"}
	gold-=total_cost; settlement["garrison"]=int(settlement["garrison"])+recruit_count
	for army in armies:
		if int(army["region"])==int(settlement["region"]) and String(army["owner"])==String(settlement["owner"]):
			army["soldiers"]=int(army["soldiers"])+recruit_count
			army["troops"][troop_type]=int(army["troops"].get(troop_type,0))+recruit_count
			return {"ok":true,"count":recruit_count,"cost":total_cost,"army":String(army["name"])}
	var owner:=String(settlement["owner"]); _add_army("%s Muster"%settlement["name"],owner,int(settlement["region"]),recruit_count); var new_army:Dictionary=armies.back(); new_army["troops"]={"levy":0,"spearman":0,"archer":0,"horseman":0}; new_army["troops"][troop_type]=recruit_count
	return {"ok":true,"count":recruit_count,"cost":total_cost,"army":String(new_army["name"])}

func travel_to_settlement(settlement_id:int)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size(): return {"ok":false,"days":0,"reason":"invalid_settlement"}
	var settlement:Dictionary=settlements[settlement_id]; var target_region:int=int(settlement["region"]); var distance_regions:=abs(target_region-player_region_id); var travel_days:=max(1,int(ceil(float(distance_regions)/2.0))); player_region_id=target_region
	for i in range(travel_days): advance_day()
	return {"ok":true,"days":travel_days,"settlement":String(settlement["name"])}

func advance_day()->void:
	if simulation_paused:
		return
	day+=1
	time_of_day=fmod(time_of_day+6.0,24.0)
	var weather_roll:=randi_range(0,99)
	weather="rain" if weather_roll<18 else ("storm" if weather_roll<24 else ("snow" if weather_roll<34 else ("clear" if weather_roll<82 else "fog")))
	player_inventory["food"]=max(0,int(player_inventory.get("food",0))-1)
	if int(player_inventory["food"])==0: gold=max(0,gold-2)
	for settlement_id in battle_cooldowns.keys():
		battle_cooldowns[settlement_id]=max(0,int(battle_cooldowns[settlement_id])-1)
	for region in regions:
		region["prosperity"]=clamp(int(region["prosperity"])+randi_range(-2,2),0,100)
		region["population"]=int(region["population"])+max(1,int(region["population"])/500)
	for settlement in settlements:
		settlement["prosperity"]=clamp(int(settlement["prosperity"])+randi_range(-1,2),0,100)
		var owner:=String(settlement["owner"])
		var faction:=_get_faction(owner)
		var tax_income:=max(1,int(settlement["population"]*float(settlement.get("tax_rate",0.10))/100))
		if not faction.is_empty(): faction["treasury"]=int(faction.get("treasury",0))+tax_income
		_simulate_settlement_production(settlement)
	for army in armies:
		army["food"]=max(0,int(army["food"])-max(1,int(army["soldiers"])/80))
		if int(army["food"])==0: army["morale"]=max(0,int(army["morale"])-3)
		elif int(army["morale"])<80: army["morale"]=min(80,int(army["morale"])+1)
	_simulate_sieges()
	_simulate_ship_movement()
	_simulate_faction_ai()
	_simulate_family()
	if day%7==0: _simulate_armies()
	_simulate_caravans()
	_simulate_world_events()
	if day%10==0: save_game()

func _simulate_settlement_production(settlement:Dictionary)->void:
	var resource:=String(regions[int(settlement["region"])]["resource"])
	var buildings:Dictionary=settlement["buildings"]
	var stock:Dictionary=settlement["stockpile"]
	var output:=max(1,int(settlement["prosperity"])/25)
	if resource=="grain": stock["food"]=int(stock.get("food",0))+output+int(buildings.get("farm",1))
	elif resource=="wood": stock["wood"]=int(stock.get("wood",0))+output+int(buildings.get("workshop",1))
	elif resource=="iron": stock["iron"]=int(stock.get("iron",0))+output+int(buildings.get("workshop",1))
	elif resource=="fish": stock["food"]=int(stock.get("food",0))+output
	settlement["stockpile"]=stock

func _simulate_family()->void:
	# CampaignSystems owns family aging and succession. WorldState only keeps the
	# family clock initialized so the two systems never advance it twice.
	family["age"]=int(family.get("age",18))

func _simulate_ship_movement()->void:
	for ship in ships:
		if not bool(ship.get("moving",false)): continue
		var target:=int(ship.get("target_region",ship["region"]))
		if target in get_region_neighbors(int(ship["region"])) or target==int(ship["region"]):
			ship["region"]=target; ship["moving"]=false
			world_events.append("%s reached %s."%[ship["name"],regions[target]["name"]])

func _simulate_faction_ai()->void:
	if day%5!=0: return
	for faction in factions:
		var id:=String(faction["id"])
		if id=="Free Company": continue
		var treasury:=int(faction.get("treasury",0))
		var owned:=faction.get("territory",[])
		if treasury>150 and not owned.is_empty():
			var region_id:=int(owned[randi_range(0,owned.size()-1)])
			for settlement in settlements:
				if int(settlement["region"])==region_id and String(settlement["owner"])==id and int(settlement["population"])>int(settlement["garrison"])*10:
					var recruit:=min(12,int(settlement["population"])/30)
					faction["treasury"]=treasury-recruit*5
					for army in armies:
						if String(army["owner"])==id and int(army["region"])==region_id:
							army["soldiers"]=int(army["soldiers"])+recruit; army["troops"]["levy"]=int(army["troops"].get("levy",0))+recruit; break
					break
		for army in armies:
				if String(army["owner"])!=id: continue
				var neighbors:=get_region_neighbors(int(army["region"]))
				var hostile:Array[int]=[]
				for n in neighbors:
					if _are_at_war(id,String(regions[n]["owner"])): hostile.append(n)
				if not hostile.is_empty():
					army["target_region"]=hostile[randi_range(0,hostile.size()-1)]; army["moving"]=true

func _simulate_caravans()->void:
	for i in range(caravans.size()-1,-1,-1):
		caravans[i]["days_left"]=int(caravans[i].get("days_left",1))-1
		if int(caravans[i]["days_left"])<=0:
			resolve_caravan(caravans[i])
			caravans.remove_at(i)

func get_region_neighbors(region_id:int)->Array[int]:
	var result:Array[int]=[]; if region_id<0 or region_id>=regions.size(): return result
	var origin:Vector2=regions[region_id]["position"]; var distances:Array[Dictionary]=[]
	for i in range(regions.size()):
		if i==region_id: continue
		distances.append({"id":i,"distance":origin.distance_to(regions[i]["position"])})
	distances.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a["distance"]<b["distance"])
	for item in distances.slice(0,min(3,distances.size())): result.append(int(item["id"]))
	return result

func transfer_region(region_id:int,new_owner:String)->bool:
	if region_id<0 or region_id>=regions.size() or _get_faction(new_owner).is_empty(): return false
	var old_owner:=String(regions[region_id]["owner"]); if old_owner==new_owner: return true
	var old_faction:=_get_faction(old_owner); var new_faction:=_get_faction(new_owner); regions[region_id]["owner"]=new_owner; old_faction["territory"].erase(region_id); new_faction["territory"].append(region_id)
	for settlement in settlements:
		if int(settlement["region"])==region_id: settlement["owner"]=new_owner
	return true

func create_trade_caravan(origin_id:int,destination_id:int)->Dictionary:
	if origin_id<0 or origin_id>=settlements.size() or destination_id<0 or destination_id>=settlements.size() or origin_id==destination_id:
		return {"ok":false,"reason":"invalid_route"}
	var origin:Dictionary=settlements[origin_id]; var destination:Dictionary=settlements[destination_id]
	var caravan:Dictionary={"name":"Caravan %s → %s"%[origin["name"],destination["name"]],"origin":origin_id,"destination":destination_id,"days_left":max(2,abs(int(origin["region"])-int(destination["region"]))+1),"cargo":{"food":20,"wood":10,"iron":5},"profit":0}
	var origin_prices:=get_market_prices(origin_id); var dest_prices:=get_market_prices(destination_id)
	for item in caravan["cargo"].keys():
		var qty:=int(caravan["cargo"][item]); caravan["profit"]+=max(0,int(dest_prices[item])-int(origin_prices[item]))*qty
	world_events.append("A trade caravan departed from %s to %s."%[origin["name"],destination["name"]])
	return {"ok":true,"caravan":caravan}

func resolve_caravan(caravan:Dictionary)->Dictionary:
	var profit:=max(0,int(caravan.get("profit",0)))
	gold+=profit
	world_events.append("Trade caravan arrived with %d gold profit."%profit)
	return {"ok":true,"profit":profit}

func get_market_prices(settlement_id:int)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size(): return {}
	var s:Dictionary=settlements[settlement_id]
	var prosperity:=int(s.get("prosperity",50))
	var resource:=String(regions[int(s["region"])].get("resource","grain"))
	var prices:Dictionary={"food":max(2,10-int(prosperity/20)),"wood":max(3,12-int(prosperity/25)),"iron":max(5,18-int(prosperity/30))}
	if resource=="grain": prices["food"]=max(2,int(prices["food"]*0.75))
	elif resource=="timber": prices["wood"]=max(2,int(prices["wood"]*0.7))
	elif resource=="iron": prices["iron"]=max(3,int(prices["iron"]*0.7))
	return prices

func trade_resource(settlement_id:int,resource:String,amount:int,buy:bool)->Dictionary:
	if amount<=0 or not ["food","wood","iron"].has(resource): return {"ok":false,"reason":"invalid_trade"}
	var prices:=get_market_prices(settlement_id)
	if prices.is_empty(): return {"ok":false,"reason":"invalid_settlement"}
	var total:=int(prices[resource])*amount
	if buy:
		if gold<total: return {"ok":false,"reason":"not_enough_gold"}
		gold-=total
		player_inventory[resource]=int(player_inventory.get(resource,0))+amount
	else:
		var owned:=int(player_inventory.get(resource,0))
		if owned<amount: return {"ok":false,"reason":"not_enough_resource"}
		player_inventory[resource]=owned-amount
		gold+=total
	return {"ok":true,"resource":resource,"amount":amount,"total":total,"gold":gold}

func set_player_mode(mode:String)->Dictionary:

	if mode not in ["ordinary","king","tribal_leader"]: return {"ok":false,"reason":"invalid_mode"}
	player_mode=mode
	if mode=="king": gold=1000
	elif mode=="tribal_leader": gold=500
	return {"ok":true,"mode":player_mode}

func add_player_xp(amount:int)->void:
	player_xp=max(0,player_xp+amount)
	while player_xp>=player_level*100:
		player_xp-=player_level*100
		player_level+=1

func get_player_summary()->Dictionary:
	return {"mode":player_mode,"level":player_level,"xp":player_xp,"gold":gold,"food":player_inventory.get("food",0)}

# ---------------- ARMY MOVEMENT + AI ----------------
func issue_army_move(army_id:int,target_region:int)->Dictionary:
	if army_id<0 or army_id>=armies.size() or target_region<0 or target_region>=regions.size(): return {"ok":false,"reason":"invalid_target"}
	var army:Dictionary=armies[army_id]
	if target_region not in get_region_neighbors(int(army["region"])): return {"ok":false,"reason":"not_adjacent"}
	army["target_region"]=target_region; army["moving"]=true
	return {"ok":true,"army":String(army["name"]),"target":String(regions[target_region]["name"])}

func _simulate_armies()->void:
	for army in armies:
		var current:=int(army["region"]); var target:=int(army.get("target_region",current))
		if bool(army.get("moving",false)) and current!=target:
			var neighbors:=get_region_neighbors(current)
			if target in neighbors: army["region"]=target; army["moving"]=false
	for army in armies:
		var owner:=String(army["owner"]); var neighbors:=get_region_neighbors(int(army["region"]))
		var enemies:Array[int]=[]
		for r in neighbors:
			if String(regions[r]["owner"])!=owner and _are_at_war(owner,String(regions[r]["owner"])): enemies.append(r)
		if not enemies.is_empty(): army["target_region"]=enemies[randi_range(0,enemies.size()-1)]; army["moving"]=true

func _are_at_war(a:String,b:String)->bool:
	return diplomacy.get("%s|%s"%[a,b],"")=="war" or diplomacy.get("%s|%s"%[b,a],"")=="war"

func _simulate_world_events()->void:
	# Iterate from the end because AI battles can remove an army and reindex the array.
	# Descending indices keep all not-yet-processed indices valid.
	for army_index in range(armies.size()-1,-1,-1):
		if army_index<0 or army_index>=armies.size(): continue
		var army:Dictionary=armies[army_index]
		var region_id:=int(army["region"]); var owner:=String(army["owner"])
		for settlement in settlements:
			if int(settlement["region"])!=region_id or String(settlement["owner"])==owner: continue
			if not _are_at_war(owner,String(settlement["owner"])): continue
			var result:=resolve_ai_battle(int(settlement["id"]),{"army_id":int(army["id"]),"soldiers":int(army["soldiers"]),"morale":int(army["morale"]),"troops":army.get("troops",{})},get_settlement_defender(int(settlement["id"])),owner)
			world_events.append("%s attacked %s."%[String(army["name"]),String(settlement["name"])])
			battle_events.append(result); break

func resolve_ai_battle(settlement_id:int,attacker:Dictionary,defender:Dictionary,attacker_owner:String)->Dictionary:
	var attack_score:=float(attacker.get("soldiers",1))*(0.72+_battle_quality(attacker.get("troops",{})))*(0.75+float(attacker.get("morale",70))/200.0)
	var defend_score:=float(defender.get("soldiers",1))*(0.72+_battle_quality(defender.get("troops",{})))*(0.75+float(defender.get("morale",65))/200.0)
	var attacker_id:=int(attacker.get("army_id",-1))
	if attacker_id>=0 and attacker_id<armies.size():
		attack_score*=_army_tactical_bonus(armies[attacker_id])
	var won:=attack_score>=defend_score
	var attacker_losses:=clamp(int(defender.get("soldiers",1)*(0.20 if won else 0.48)),1,int(attacker.get("soldiers",1)))
	var defender_losses:=clamp(int(attacker.get("soldiers",1)*(0.52 if won else 0.20)),1,int(defender.get("soldiers",1)))
	var army_id:=int(attacker.get("army_id",-1))
	if army_id>=0 and army_id<armies.size():
		_apply_army_losses(army_id,attacker_losses)
	settlements[settlement_id]["garrison"]=max(0,int(settlements[settlement_id]["garrison"])-defender_losses)
	var captured:=false
	if won and int(settlements[settlement_id]["garrison"])<=0: captured=transfer_region(int(settlements[settlement_id]["region"]),attacker_owner)
	return {"type":"ai_battle","attacker":attacker_owner,"settlement":String(settlements[settlement_id]["name"]),"attacker_won":won,"attacker_losses":attacker_losses,"defender_losses":defender_losses,"captured":captured}

# Shared battle engine. Manual and auto battles use the same army-quality model.
func _sum_troop_counts(troops:Dictionary)->int:
	var total := 0
	for value in troops.values():
		total += int(value)
	return total

func get_settlement_defender(settlement_id:int)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size(): return {}
	var s:Dictionary=settlements[settlement_id]
	var garrison := int(s.get("garrison", 0))
	var troops:Dictionary = s.get("garrison_troops", {})
	if troops.is_empty() or _sum_troop_counts(troops) != garrison:
		var levy := int(garrison * 0.55)
		var spearman := int(garrison * 0.20)
		var archer := int(garrison * 0.20)
		troops = {"levy":levy,"spearman":spearman,"archer":archer,"horseman":max(0,garrison-levy-spearman-archer)}
		s["garrison_troops"] = troops
	return {"owner":String(s["owner"]),"soldiers":garrison,"morale":65+int(s["prosperity"])/5,"troops":troops.duplicate(true)}

func get_player_battle_force()->Dictionary:
	var soldiers:=80; var troops={"levy":50,"spearman":15,"archer":10,"horseman":5}
	for army in armies:
		if int(army["region"])==player_region_id and String(army["owner"])==player_faction:
			soldiers=int(army["soldiers"]); troops=army.get("troops",troops); break
	var formation:="line"
	var order:="hold"
	for army in armies:
		if int(army["region"])==player_region_id and String(army["owner"])==player_faction:
			formation=String(army.get("formation","line")); order=String(army.get("order","hold")); break
	return {"owner":player_faction,"soldiers":soldiers,"morale":78,"troops":troops,"formation":formation,"order":order}

func resolve_auto_battle(settlement_id:int,attacker:Dictionary,defender:Dictionary)->Dictionary:
	var attack_count:=max(1,int(attacker.get("soldiers",1))); var defend_count:=max(1,int(defender.get("soldiers",1))); var attack_morale:=float(attacker.get("morale",70)); var defend_morale:=float(defender.get("morale",65))
	var attack_score:=float(attack_count)*(0.72+_battle_quality(attacker.get("troops",{})))*(0.75+attack_morale/200.0)*(1.0+get_player_combat_bonus())
	if player_army_tactical_bonus() > 0.0: attack_score*=(1.0+player_army_tactical_bonus())
	var defend_score:=float(defend_count)*(0.72+_battle_quality(defender.get("troops",{})))*(0.75+defend_morale/200.0)
	var attacker_won:=attack_score>=defend_score; var ratio:=clamp(max(attack_score,defend_score)/max(1.0,min(attack_score,defend_score)),1.0,3.0); var attacker_losses:int; var defender_losses:int; var rounds:Array[String]=[]
	if attacker_won:
		attacker_losses=clamp(int(defend_count*(0.18+0.10/ratio)),1,attack_count); defender_losses=clamp(int(attack_count*(0.55+0.12*ratio)),1,defend_count); rounds=["Attackers gained the first advantage.","Defensive lines began to collapse.","The garrison withdrew after sustained pressure."]
	else:
		attacker_losses=clamp(int(defend_count*(0.52+0.12*ratio)),1,attack_count); defender_losses=clamp(int(attack_count*(0.20+0.08/ratio)),1,defend_count); rounds=["Defenders held the first assault.","The attackers lost momentum.","The assault was broken and the attackers retreated."]
	var player_army_id:=-1
	for army in armies:
		if String(army["owner"])==player_faction and int(army["region"])==player_region_id:
			player_army_id=int(army["id"])
			break
	if player_army_id>=0:
		_apply_army_losses(player_army_id,attacker_losses)
	settlements[settlement_id]["garrison"]=max(0,int(settlements[settlement_id]["garrison"])-defender_losses)
	var captured:=false
	if attacker_won and int(settlements[settlement_id]["garrison"])<=0:
		captured=capture_settlement(settlement_id)
	add_player_xp(max(10,defender_losses))
	return {"attacker_won":attacker_won,"attacker_losses":attacker_losses,"defender_losses":defender_losses,"rounds":rounds,"captured":captured,"settlement":String(settlements[settlement_id]["name"])}

func player_army_tactical_bonus()->float:
	for army in armies:
		if String(army["owner"])==player_faction and int(army["region"])==player_region_id:
			return _army_tactical_bonus(army)-1.0
	return 0.0

func _army_tactical_bonus(army:Dictionary)->float:
	var bonus:=1.0
	match String(army.get("formation","line")):
		"shield_wall": bonus+=0.08
		"wedge": bonus+=0.10
		"skirmish": bonus+=0.06
	match String(army.get("order","hold")):
		"attack": bonus+=0.08
		"defend": bonus+=0.06
		"raid": bonus+=0.05
	return bonus

func _battle_quality(troops:Dictionary)->float:
	var total:=0; var weighted:=0.0
	for kind in ["levy","spearman","archer","horseman"]:
		var amount:=int(troops.get(kind,0)); total+=amount; weighted+=float(amount)*float({"levy":0.05,"spearman":0.16,"archer":0.20,"horseman":0.27}.get(kind,0.05))
	if total<=0: return 0.05
	return weighted/float(total)

func capture_settlement(settlement_id:int)->bool:
	if settlement_id<0 or settlement_id>=settlements.size(): return false
	var s:Dictionary=settlements[settlement_id]; var region_id:=int(s["region"]); var old_owner:=String(s["owner"])
	if old_owner==player_faction: return false
	s["owner"]=player_faction; s["garrison"]=max(20,int(s["garrison"])/3)
	var new_garrison := int(s["garrison"]); s["garrison_troops"]={"levy":int(new_garrison*0.55),"spearman":int(new_garrison*0.20),"archer":int(new_garrison*0.20),"horseman":max(0,new_garrison-int(new_garrison*0.95))}
	return transfer_region(region_id,player_faction)

func apply_manual_battle_result(settlement_id:int,attacker_losses:int,defender_losses:int,attacker_types:Dictionary,defender_types:Dictionary,allow_capture:bool=true)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size():
		return {"captured":false,"attacker_losses":0,"defender_losses":0,"settlement":"Unknown"}
	var player_army_id := -1
	for army in armies:
		if String(army["owner"])==player_faction and int(army["region"])==player_region_id:
			player_army_id=int(army["id"])
			break
	var applied_attacker := 0
	if player_army_id>=0:
		applied_attacker = _apply_army_troop_losses(player_army_id, attacker_types)
		if applied_attacker < attacker_losses:
			_apply_army_losses(player_army_id, attacker_losses-applied_attacker)
			applied_attacker = attacker_losses
	var settlement:Dictionary = settlements[settlement_id]
	var garrison_troops:Dictionary = settlement.get("garrison_troops", {})
	var applied_defender := 0
	for kind in defender_types.keys():
		var loss := max(0, int(defender_types[kind]))
		var available := int(garrison_troops.get(kind, 0))
		var actual := min(loss, available)
		garrison_troops[kind] = available-actual
		applied_defender += actual
	if applied_defender < defender_losses:
		var fallback := defender_losses-applied_defender
		for kind in garrison_troops.keys():
			if fallback<=0: break
			var available := int(garrison_troops[kind])
			var actual := min(available,fallback)
			garrison_troops[kind]=available-actual
			fallback-=actual
			applied_defender += actual
	settlement["garrison_troops"] = garrison_troops
	settlement["garrison"] = max(0, _sum_troop_counts(garrison_troops))
	var captured := false
	if allow_capture and settlement["garrison"] <= 0:
		captured = capture_settlement(settlement_id)
	add_player_xp(max(10, applied_defender))
	return {"captured":captured,"attacker_losses":max(0,applied_attacker),"defender_losses":max(0,applied_defender),"settlement":String(settlement["name"])}

func _apply_army_troop_losses(army_id:int,losses:Dictionary)->int:
	if army_id<0 or army_id>=armies.size(): return 0
	var army:Dictionary=armies[army_id]
	var applied := 0
	for kind in losses.keys():
		var requested := max(0,int(losses[kind]))
		var available := int(army["troops"].get(kind,0))
		var actual := min(requested,available)
		army["troops"][kind]=available-actual
		applied += actual
	# Apply the accumulated losses exactly once; applying inside the loop
	# would double-count mixed troop-type casualties.
	army["soldiers"]=max(0,int(army["soldiers"])-applied)
	army["morale"]=max(0,int(army["morale"])-min(30,int(applied/3)))
	if int(army["soldiers"])<=0: _remove_army_at(army_id)
	return applied

func apply_manual_victory(settlement_id:int,attacker_losses:int,defender_losses:int)->Dictionary:
	# Legacy compatibility path: keep it capture-safe and route through the typed battle engine.
	return apply_manual_battle_result(settlement_id,attacker_losses,defender_losses,{}, {}, true)

func _apply_army_losses(army_id:int,losses:int)->void:
	if army_id<0 or army_id>=armies.size(): return
	var army:Dictionary=armies[army_id]
	var old:=max(1,int(army["soldiers"])); var remaining:=max(0,old-losses); var ratio:=float(remaining)/float(old)
	army["soldiers"]=remaining
	for kind in army["troops"].keys(): army["troops"][kind]=int(round(int(army["troops"][kind])*ratio))
	army["morale"]=max(0,int(army["morale"])-min(30,losses/3))
	if remaining<=0: _remove_army_at(army_id)

func _remove_army_at(index:int)->void:
	if index<0 or index>=armies.size(): return
	armies.remove_at(index)
	for i in range(armies.size()):
		armies[i]["id"]=i
	for sid in sieges.keys():
		var siege:Dictionary=sieges[sid]
		var stored:=int(siege.get("army_id",-1))
		if stored==index: siege["army_id"]=-1
		elif stored>index: siege["army_id"]=stored-1
		sieges[sid]=siege

func issue_ship_move(ship_id:int,target_region:int)->Dictionary:
	if ship_id<0 or ship_id>=ships.size() or target_region<0 or target_region>=regions.size(): return {"ok":false,"reason":"invalid_target"}
	if String(regions[target_region]["resource"])!="fish" and String(regions[target_region]["resource"])!="salt": return {"ok":false,"reason":"not_a_port"}
	ships[ship_id]["target_region"]=target_region; ships[ship_id]["moving"]=true
	return {"ok":true,"ship":ships[ship_id]["name"],"target":regions[target_region]["name"]}

func naval_battle(ship_a_id:int,ship_b_id:int)->Dictionary:
	if ship_a_id<0 or ship_a_id>=ships.size() or ship_b_id<0 or ship_b_id>=ships.size(): return {"ok":false}
	var a:=ships[ship_a_id]; var b:=ships[ship_b_id]
	var ascore:=int(a["crew"])+int(a["cargo"].get("iron",0))*2; var bscore:=int(b["crew"])+int(b["cargo"].get("iron",0))*2
	var winner:=ship_a_id if ascore>=bscore else ship_b_id
	var loser:=ship_b_id if winner==ship_a_id else ship_a_id
	ships[winner]["crew"]=max(1,int(ships[winner]["crew"])-randi_range(3,10))
	world_events.append("%s defeated %s at sea."%[ships[winner]["name"],ships[loser]["name"]])
	ships.remove_at(loser)
	return {"ok":true,"winner":winner,"loser":loser}

func set_diplomacy(a:String,b:String,state:String)->Dictionary:
	if _get_faction(a).is_empty() or _get_faction(b).is_empty() or a==b or not ["war","peace","alliance","trade"].has(state): return {"ok":false}
	diplomacy["%s|%s"%[a,b]]=state; diplomacy["%s|%s"%[b,a]]=state
	world_events.append("%s and %s are now %s."%[get_faction_name(a),get_faction_name(b),state])
	return {"ok":true,"state":state}

func raid_settlement(settlement_id:int)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size(): return {"ok":false,"reason":"invalid_settlement"}
	var s:=settlements[settlement_id]; var owner:=String(s["owner"])
	if not _are_at_war(player_faction,owner): return {"ok":false,"reason":"not_at_war"}
	var loot:=max(10,int(s["prosperity"])*2); gold+=loot; s["prosperity"]=max(0,int(s["prosperity"])-12); s["garrison"]=max(0,int(s["garrison"])-10)
	world_events.append("Free Company raided %s for %d gold."%[s["name"],loot])
	return {"ok":true,"loot":loot}

func create_caravan(origin_id:int,destination_id:int)->Dictionary:
	var result:=create_trade_caravan(origin_id,destination_id)
	if result.get("ok",false): caravans.append(result["caravan"])
	return result

func _get_depth_state() -> Dictionary:
	var n := get_node_or_null("../ReleaseDepthSystems")
	if n and n.has_method("get_state"):
		return n.get_state()
	return {}

func save_game()->bool:
	var campaign_state:Dictionary = {}
	var campaign_node := get_node_or_null("/root/CampaignSystems")
	if campaign_node and campaign_node.has_method("get_save_state"):
		campaign_state = campaign_node.get_save_state()
	var final_state:Dictionary = {}
	var final_node := get_node_or_null("/root/FinalGameSystems")
	if final_node and final_node.has_method("get_save_state"):
		final_state = final_node.get_save_state()
	var complete_node := get_node_or_null("../ReleaseCompleteGameplay")
	if complete_node and complete_node.has_method("get_save_state"):
		complete_gameplay_state = complete_node.get_save_state()
	var data={"save_version":4,"day":day,"gold":gold,"player_faction":player_faction,"player_start":player_start,"player_region_id":player_region_id,"player_mode":player_mode,"player_level":player_level,"player_xp":player_xp,"player_inventory":player_inventory,"family":family,"weather":weather,"time_of_day":time_of_day,"yearly_tax":yearly_tax,"player_income":player_income,"battle_events":battle_events,"world_events":world_events,"battle_cooldowns":battle_cooldowns,"regions":regions,"factions":factions,"settlements":settlements,"armies":armies,"diplomacy":diplomacy,"caravans":caravans,"ships":ships,"sieges":sieges,"player_equipment":player_equipment,"family_members":family_members,"player_buildings":player_buildings,"production_stock":production_stock,"faction_ai_state":faction_ai_state,"simulation_paused":simulation_paused,"campaign_state":campaign_state,"final_state":final_state,"complete_gameplay_state":complete_gameplay_state,"depth_systems_state":_get_depth_state()}
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(data)); file.close(); return true

func load_game()->bool:
	if not FileAccess.file_exists(save_path): return false
	var file:=FileAccess.open(save_path,FileAccess.READ)
	if file==null: return false
	var parsed=JSON.parse_string(file.get_as_text()); file.close()
	if typeof(parsed)!=TYPE_DICTIONARY: return false
	if int(parsed.get("save_version",1)) > 4: return false
	for key in ["day","gold","player_faction","player_start","player_region_id","player_mode","player_level","player_xp","player_inventory","family","weather","time_of_day","yearly_tax","player_income","battle_events","world_events","battle_cooldowns","regions","factions","settlements","armies","diplomacy","caravans","ships","sieges","player_equipment","family_members","player_buildings","production_stock","faction_ai_state","simulation_paused"]:
		if parsed.has(key): set(key,parsed[key])
	var campaign_node := get_node_or_null("/root/CampaignSystems")
	if campaign_node and campaign_node.has_method("load_save_state") and parsed.has("campaign_state"):
		campaign_node.load_save_state(parsed["campaign_state"])
	var final_node := get_node_or_null("/root/FinalGameSystems")
	if final_node and final_node.has_method("load_save_state") and parsed.has("final_state"):
		final_node.load_save_state(parsed["final_state"])
	var complete_node := get_node_or_null("../ReleaseCompleteGameplay")
	if complete_node and complete_node.has_method("load_save_state") and parsed.has("complete_gameplay_state"):
		complete_node.load_save_state(parsed["complete_gameplay_state"])
	var depth_node := get_node_or_null("../ReleaseDepthSystems")
	if depth_node and depth_node.has_method("load_state") and parsed.has("depth_systems_state"):
		depth_node.load_state(parsed["depth_systems_state"])
	return true

func upgrade_settlement_building(settlement_id:int,building:String)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size(): return {"ok":false,"reason":"invalid_settlement"}
	if not ["farm","workshop","market","barracks"].has(building): return {"ok":false,"reason":"invalid_building"}
	var s:Dictionary=settlements[settlement_id]
	if String(s["owner"])!=player_faction: return {"ok":false,"reason":"not_owned"}
	var level:=int(s["buildings"].get(building,1)); var cost:=100*level
	if gold<cost: return {"ok":false,"reason":"not_enough_gold"}
	gold-=cost; s["buildings"][building]=level+1
	if building=="barracks": s["garrison"]=int(s["garrison"])+15
	if building=="farm": s["stockpile"]["food"]=int(s["stockpile"].get("food",0))+25
	world_events.append("%s upgraded %s to level %d."%[s["name"],building,level+1])
	return {"ok":true,"building":building,"level":level+1,"cost":cost}

func garrison_army_in_settlement(army_id:int,settlement_id:int)->Dictionary:
	if army_id<0 or army_id>=armies.size() or settlement_id<0 or settlement_id>=settlements.size(): return {"ok":false,"reason":"invalid"}
	var army:=armies[army_id]; var s:=settlements[settlement_id]
	if String(army["owner"])!=player_faction or int(army["region"])!=int(s["region"]): return {"ok":false,"reason":"not_available"}
	var moved:=min(50,int(army["soldiers"])); s["garrison"]=int(s["garrison"])+moved; army["soldiers"]=int(army["soldiers"])-moved
	return {"ok":true,"garrison":s["garrison"],"army":army["soldiers"]}

func set_army_formation(army_id:int,formation:String)->Dictionary:
	if army_id<0 or army_id>=armies.size() or not ["line","shield_wall","wedge","skirmish"].has(formation): return {"ok":false,"reason":"invalid"}
	armies[army_id]["formation"]=formation
	return {"ok":true,"formation":formation}

func set_army_order(army_id:int,order:String)->Dictionary:
	if army_id<0 or army_id>=armies.size() or not ["hold","attack","defend","raid","escort"].has(order): return {"ok":false,"reason":"invalid"}
	armies[army_id]["order"]=order
	return {"ok":true,"order":order}

func start_siege(settlement_id:int,army_id:int)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size() or army_id<0 or army_id>=armies.size(): return {"ok":false,"reason":"invalid"}
	var s:=settlements[settlement_id]; var a:=armies[army_id]
	if String(a["owner"])!=player_faction or int(a["region"])!=int(s["region"]) or String(s["owner"])==player_faction: return {"ok":false,"reason":"invalid_siege"}
	if not _are_at_war(player_faction,String(s["owner"])): return {"ok":false,"reason":"not_at_war"}
	sieges[settlement_id]={"army_id":army_id,"progress":0,"days":0,"breach":false,"phase":"approach","wall_hp":int(s.get("wall_level",1))*100,"gate_hp":120,"gate_breached":false}; s["siege"]=true
	world_events.append("%s began a siege of %s."%[a["name"],s["name"]])
	return {"ok":true,"settlement":s["name"]}

func assault_siege(settlement_id:int)->Dictionary:
	if not sieges.has(settlement_id): return {"ok":false,"reason":"no_siege"}
	var siege:Dictionary=sieges[settlement_id]
	var s:Dictionary=settlements[settlement_id]
	var army_id:=int(siege["army_id"])
	if army_id<0 or army_id>=armies.size(): return {"ok":false,"reason":"army_missing"}
	var a:Dictionary=armies[army_id]
	var wall:=int(s.get("wall_level",1))
	var attack_power:=max(1,int(a["soldiers"])+int(a["troops"].get("horseman",0))*2)
	var defense_power:=max(1,int(s["garrison"])+wall*25)
	var ratio:=float(attack_power)/float(defense_power)
	var attacker_loss:=clamp(int(defense_power*(0.08 if ratio>=1.0 else 0.16)),1,max(1,int(a["soldiers"])))
	var defender_loss:=clamp(int(attack_power*(0.22 if ratio>=1.0 else 0.10)),1,max(1,int(s["garrison"])))
	_apply_army_losses(army_id,attacker_loss)
	if army_id>=armies.size():
		settlement_siege_end(settlement_id)
		return {"ok":true,"won":false,"attacker_losses":attacker_loss,"defender_losses":defender_loss,"captured":false,"progress":int(siege["progress"]),"phase":"repulsed"}
	var current_garrison:=int(s["garrison"])
	s["garrison"]=max(0,current_garrison-defender_loss)
	var gate_damage:=max(8,int(attack_power/12))
	var wall_damage:=max(5,int(attack_power/18))
	var gate_hp:=max(0,int(siege.get("gate_hp",120))-gate_damage)
	var wall_hp:=max(0,int(siege.get("wall_hp",wall*100))-wall_damage)
	siege["gate_hp"]=gate_hp
	siege["wall_hp"]=wall_hp
	var progress_gain:=15 if ratio>=1.0 else 8
	siege["progress"]=min(100,int(siege["progress"])+progress_gain)
	if gate_hp<=0 and not bool(siege.get("gate_breached",false)):
		siege["gate_breached"]=true
		siege["breach"]=true
		siege["phase"]="gate breached"
	elif wall_hp<=wall*35 and not bool(siege.get("breach",false)):
		siege["breach"]=true
		siege["phase"]="wall breached"
	elif ratio>=1.0:
		siege["phase"]="assaulting"
	else:
		siege["phase"]="repulsed assault"
	var captured:=false
	if int(s["garrison"])<=0 and bool(siege.get("breach",false)):
		s["wall_level"]=max(0,wall-1)
		s["siege"]=false
		captured=capture_settlement(settlement_id)
		sieges.erase(settlement_id)
		add_player_xp(defender_loss+50)
		return {"ok":true,"won":true,"attacker_losses":attacker_loss,"defender_losses":defender_loss,"captured":captured,"progress":100,"phase":"captured","gate_breached":true}
	sieges[settlement_id]=siege
	return {"ok":true,"won":ratio>=1.0,"attacker_losses":attacker_loss,"defender_losses":defender_loss,"captured":false,"progress":int(siege["progress"]),"phase":String(siege["phase"]),"gate_breached":bool(siege.get("gate_breached",false))}

func settlement_siege_end(settlement_id:int)->void:
	if settlement_id>=0 and settlement_id<settlements.size(): settlements[settlement_id]["siege"]=false
	sieges.erase(settlement_id)

func _simulate_sieges()->void:
	var finished:Array[int]=[]
	for settlement_id in sieges.keys():
		var sid:=int(settlement_id)
		if sid<0 or sid>=settlements.size(): finished.append(sid); continue
		var siege:Dictionary=sieges[sid]; var army_id:=int(siege["army_id"])
		if army_id<0 or army_id>=armies.size(): settlements[sid]["siege"]=false; finished.append(sid); continue
		var a:=armies[army_id]
		if int(a["soldiers"])<=0: settlements[sid]["siege"]=false; finished.append(sid); continue
		siege["days"]=int(siege["days"])+1; siege["progress"]=min(100,int(siege["progress"])+max(1,int(a["soldiers"])/150))
		if int(siege["progress"])>=100: settlements[sid]["garrison"]=max(0,int(settlements[sid]["garrison"])-20); siege["progress"]=80
		sieges[sid]=siege
	for sid in finished: sieges.erase(sid)

func upgrade_player_equipment(slot:String,item:String,cost:int)->Dictionary:
	if not ["weapon","armor","horse","shield"].has(slot) or cost<0: return {"ok":false,"reason":"invalid_equipment"}
	if gold<cost: return {"ok":false,"reason":"not_enough_gold"}
	gold-=cost; player_equipment[slot]=item
	return {"ok":true,"slot":slot,"item":item}

func get_player_combat_bonus()->float:
	var bonus:=0.0
	bonus+=0.10 if String(player_equipment.get("weapon",""))=="steel_sword" else 0.04
	bonus+=0.08 if String(player_equipment.get("armor",""))=="plate_armor" else 0.03
	bonus+=0.12 if String(player_equipment.get("horse",""))=="war_horse" else 0.0
	bonus+=0.05 if String(player_equipment.get("shield",""))=="steel_shield" else 0.02
	return bonus

func add_family_member(name:String,role:String,age:int)->Dictionary:
	if name.strip_edges().is_empty() or age<0: return {"ok":false}
	family_members.append({"name":name,"role":role,"age":age,"loyalty":75})
	if role=="heir": family["heir_name"]=name; family["heir_age"]=age
	return {"ok":true}

func recruit_guardian()->Dictionary:
	var cost:=75
	if gold<cost: return {"ok":false,"reason":"not_enough_gold"}
	gold-=cost; family_members.append({"name":"Household Guardian","role":"guardian","age":30,"loyalty":90})
	return {"ok":true}

func get_world_status()->Dictionary:
	return {"day":day,"weather":weather,"time":time_of_day,"gold":gold,"player_region":player_region_id,"armies":armies.size(),"settlements":settlements.size(),"sieges":sieges.size(),"caravans":caravans.size(),"ships":ships.size(),"level":player_level}

func get_faction_color(id:String)->Color: return _get_faction(id).get("color",Color.WHITE)
func get_faction_name(id:String)->String: return String(_get_faction(id).get("name",id))
func get_faction_banner(id:String)->Color: return _get_faction(id).get("banner",_get_faction(id).get("color",Color.WHITE))
func get_faction_accent(id:String)->Color: return _get_faction(id).get("accent",Color.WHITE)
func get_faction_emblem(id:String)->String: return String(_get_faction(id).get("emblem","cross"))
func get_faction_culture(id:String)->String: return String(_get_faction(id).get("culture","Unknown"))

