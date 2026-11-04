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


func initialize_continent() -> void:
	regions.clear(); factions.clear(); settlements.clear(); armies.clear(); diplomacy.clear(); caravans.clear(); ships.clear(); battle_events.clear(); world_events.clear(); battle_cooldowns.clear(); day=1; gold=250; player_level=1; player_xp=0; player_mode="ordinary"; player_region_id=0; player_inventory={"food":30,"wood":10,"iron":5}; family={"age":18,"generation":1,"heir_name":"Unnamed Heir","heir_age":0}
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
	_add_army("Northwatch Host","north_kingdom",0,180); _add_army("Valoria Royal Army","river_kingdom",2,260); _add_army("Steppe Riders","eastern_tribes",3,210); _add_army("Sahr Expedition","southern_sultanate",10,240); _add_army("Western Warband","western_clans",8,150)
	ships.append({"id":0,"name":"Pearl Trader","owner":"southern_sultanate","region":11,"crew":35,"cargo":{"food":40,"wood":15,"iron":5},"moving":false,"target_region":11})
	ships.append({"id":1,"name":"Frost Cutter","owner":"north_kingdom","region":4,"crew":28,"cargo":{"food":25,"wood":25,"iron":3},"moving":false,"target_region":4})
	for a in factions:
		for b in factions:
			if a["id"] != b["id"]: a["relations"][b["id"]] = 0
	diplomacy["north_kingdom|river_kingdom"]="peace"; diplomacy["river_kingdom|eastern_tribes"]="war"; diplomacy["western_clans|river_kingdom"]="war"; diplomacy["southern_sultanate|river_kingdom"]="peace"

func _add_settlement(name:String,kind:String,region_id:int,position:Vector2,owner:String,population:int)->void:
	settlements.append({"id":settlements.size(),"name":name,"type":kind,"region":region_id,"position":position,"owner":owner,"population":population,"prosperity":50,"garrison":40 if kind=="village" else 100})

func _add_army(name:String,owner:String,region_id:int,soldiers:int)->void:
	armies.append({"id":armies.size(),"name":name,"owner":owner,"region":region_id,"soldiers":soldiers,"morale":75,"food":100,"moving":false,"target_region":region_id,"troops":{"levy":soldiers,"spearman":0,"archer":0,"horseman":0}})

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
	day+=1
	time_of_day=fmod(time_of_day+24.0,24.0)
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
		if not faction.is_empty(): faction["treasury"]=int(faction.get("treasury",0))+max(1,int(settlement["population"])/250)
	for army in armies:
		army["food"]=max(0,int(army["food"])-max(1,int(army["soldiers"])/80))
		if int(army["food"])==0: army["morale"]=max(0,int(army["morale"])-3)
	if day%30==0:
		family["age"]=int(family["age"])+1
		family["heir_age"]=int(family.get("heir_age",0))+1
		if int(family["age"])>=60:
			family["generation"]=int(family["generation"])+1
			family["age"]=18
			player_level=max(1,player_level)
	if day%7==0: _simulate_armies()
	_simulate_caravans()
	_simulate_world_events()
	if day%10==0: save_game()

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
	for army in armies:
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
func get_settlement_defender(settlement_id:int)->Dictionary:
	if settlement_id<0 or settlement_id>=settlements.size(): return {}
	var s:Dictionary=settlements[settlement_id]
	return {"owner":String(s["owner"]),"soldiers":int(s["garrison"]),"morale":65+int(s["prosperity"])/5}

func get_player_battle_force()->Dictionary:
	var soldiers:=80; var troops={"levy":50,"spearman":15,"archer":10,"horseman":5}
	for army in armies:
		if int(army["region"])==player_region_id and String(army["owner"])==player_faction:
			soldiers=int(army["soldiers"]); troops=army.get("troops",troops); break
	return {"soldiers":soldiers,"morale":78,"troops":troops}

func resolve_auto_battle(settlement_id:int,attacker:Dictionary,defender:Dictionary)->Dictionary:
	var attack_count:=max(1,int(attacker.get("soldiers",1))); var defend_count:=max(1,int(defender.get("soldiers",1))); var attack_morale:=float(attacker.get("morale",70)); var defend_morale:=float(defender.get("morale",65))
	var attack_score:=float(attack_count)*(0.72+_battle_quality(attacker.get("troops",{})))*(0.75+attack_morale/200.0); var defend_score:=float(defend_count)*(0.72+_battle_quality(defender.get("troops",{})))*(0.75+defend_morale/200.0)
	var attacker_won:=attack_score>=defend_score; var ratio:=clamp(max(attack_score,defend_score)/max(1.0,min(attack_score,defend_score)),1.0,3.0); var attacker_losses:int; var defender_losses:int; var rounds:Array[String]=[]
	if attacker_won:
		attacker_losses=clamp(int(defend_count*(0.18+0.10/ratio)),1,attack_count); defender_losses=clamp(int(attack_count*(0.55+0.12*ratio)),1,defend_count); rounds=["Attackers gained the first advantage.","Defensive lines began to collapse.","The garrison withdrew after sustained pressure."]
	else:
		attacker_losses=clamp(int(defend_count*(0.52+0.12*ratio)),1,attack_count); defender_losses=clamp(int(attack_count*(0.20+0.08/ratio)),1,defend_count); rounds=["Defenders held the first assault.","The attackers lost momentum.","The assault was broken and the attackers retreated."]
	var captured:=false
	if attacker_won: captured=capture_settlement(settlement_id)
	return {"attacker_won":attacker_won,"attacker_losses":attacker_losses,"defender_losses":defender_losses,"rounds":rounds,"captured":captured,"settlement":String(settlements[settlement_id]["name"])}

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
	return transfer_region(region_id,player_faction)

func apply_manual_victory(settlement_id:int,attacker_losses:int,defender_losses:int)->Dictionary:
	var player_army_id:=-1
	for army in armies:
		if String(army["owner"])==player_faction and int(army["region"])==player_region_id: player_army_id=int(army["id"]); break
	if player_army_id>=0: _apply_army_losses(player_army_id,attacker_losses)
	settlements[settlement_id]["garrison"]=max(0,int(settlements[settlement_id]["garrison"])-defender_losses)
	var captured:=false
	if int(settlements[settlement_id]["garrison"])<=0: captured=capture_settlement(settlement_id)
	add_player_xp(max(10,defender_losses))
	return {"captured":captured,"attacker_losses":max(0,attacker_losses),"defender_losses":max(0,defender_losses),"settlement":String(settlements[settlement_id]["name"])}

	return {"captured":captured,"attacker_losses":max(0,attacker_losses),"defender_losses":max(0,defender_losses),"settlement":String(settlements[settlement_id]["name"])}

func _apply_army_losses(army_id:int,losses:int)->void:
	if army_id<0 or army_id>=armies.size(): return
	var army:Dictionary=armies[army_id]
	var old:=max(1,int(army["soldiers"])); var remaining:=max(0,old-losses); var ratio:=float(remaining)/float(old)
	army["soldiers"]=remaining
	for kind in army["troops"].keys(): army["troops"][kind]=int(round(int(army["troops"][kind])*ratio))
	army["morale"]=max(0,int(army["morale"])-min(30,losses/3))
	if remaining<=0: armies.remove_at(army_id)

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

func save_game()->bool:
	var data={"day":day,"gold":gold,"player_region_id":player_region_id,"player_mode":player_mode,"player_level":player_level,"player_xp":player_xp,"player_inventory":player_inventory,"family":family,"weather":weather,"time_of_day":time_of_day,"regions":regions,"factions":factions,"settlements":settlements,"armies":armies,"diplomacy":diplomacy,"caravans":caravans,"ships":ships}
	var file:=FileAccess.open(save_path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(data)); file.close(); return true

func load_game()->bool:
	if not FileAccess.file_exists(save_path): return false
	var file:=FileAccess.open(save_path,FileAccess.READ)
	if file==null: return false
	var parsed=JSON.parse_string(file.get_as_text()); file.close()
	if typeof(parsed)!=TYPE_DICTIONARY: return false
	for key in ["day","gold","player_region_id","player_mode","player_level","player_xp","player_inventory","family","weather","time_of_day","regions","factions","settlements","armies","diplomacy","caravans","ships"]:
		if parsed.has(key): set(key,parsed[key])
	return true

func get_faction_color(id:String)->Color: return _get_faction(id).get("color",Color.WHITE)
func get_faction_name(id:String)->String: return String(_get_faction(id).get("name",id))
func get_faction_banner(id:String)->Color: return _get_faction(id).get("banner",_get_faction(id).get("color",Color.WHITE))
func get_faction_accent(id:String)->Color: return _get_faction(id).get("accent",Color.WHITE)
func get_faction_emblem(id:String)->String: return String(_get_faction(id).get("emblem","cross"))
func get_faction_culture(id:String)->String: return String(_get_faction(id).get("culture","Unknown"))

