extends Node
class_name ReleaseSeventyCoreSystems
## Systems 31-100: the remaining core campaign layer.
## These systems operate on the live WorldState instead of creating disconnected demos.

var host: Node
var world: Node
var tick := 0
var morale_memory: Dictionary = {}
var settlement_memory: Dictionary = {}
var diplomacy_memory: Dictionary = {}
var relation_memory: Dictionary = {}
var character_memory: Dictionary = {}
var quest_memory: Array[Dictionary] = []
var weather_memory := "clear"
var ui_report := "70 CORE SYSTEMS ONLINE"

func build(main: Node) -> void:
	host = main
	world = host.world_state
	_seed_memory()
	_build_ui()

func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	# Deliberately tied to the campaign clock rather than frame rate.
	if int(world.day) > tick:
		while tick < int(world.day):
			tick += 1
			run_all()

func run_all() -> void:
	# 31-40: character, party and army command
	31_character_stats()
	32_experience_progression()
	33_level_rewards()
	34_army_command_readiness()
	35_formation_cohesion()
	36_morale_memory()
	37_desertion_pressure()
	38_reinforcement_priority()
	39_hero_party_supply()
	40_hero_party_recovery()
	# 41-50: settlements, economy and resources
	41_settlement_specialization()
	42_food_reserve()
	43_famine()
	44_festival()
	45_building_maintenance()
	46_fortification_integrity()
	47_workshop_output()
	48_market_demand()
	49_price_pressure()
	50_tax_efficiency()
	# 51-60: diplomacy, faction politics and world relations
	51_faction_relations()
	52_alliance_stability()
	53_war_exhaustion()
	54_peace_pressure()
	55_vassal_loyalty()
	56_rebellion_risk()
	57_faction_leadership()
	58_faction_military_budget()
	59_faction_recruitment()
	60_faction_border_pressure()
	# 61-70: exploration, roads, contracts and events
	61_discovery()
	62_frontier_visibility()
	63_waystation_bonus()
	64_road_damage()
	65_road_repair()
	66_bandit_encounters()
	67_patrol_effect()
	68_contract_reputation()
	69_contract_rewards()
	70_dynamic_world_events()
	# 71-80: siege, battle and military logistics
	71_siege_supply()
	72_siege_morale()
	73_siege_engineering()
	74_siege_defender_reserves()
	75_battle_readiness()
	76_battle_casualty_recovery()
	77_battle_veterans()
	78_battle_command_memory()
	79_garrison_training()
	80_frontline_warning()
	# 81-90: naval, travel and trade
	81_ship_crew()
	82_ship_cargo()
	83_ship_fatigue()
	84_port_prosperity()
	85_sea_trade()
	86_fishing_output()
	87_naval_visibility()
	88_storm_damage()
	89_shipyard_repairs()
	90_sea_route_risk()
	# 91-100: family, succession, saves, sandbox continuity and meta systems
	91_family_relations()
	92_family_reputation()
	93_heir_readiness()
	94_succession_support()
	95_house_wealth()
	96_player_renown()
	97_player_reputation()
	98_campaign_statistics()
	99_world_event_history()
	100_sandbox_consistency()
	ui_report = "100 CORE SYSTEMS ACTIVE • DAY %d" % int(world.day)
	_refresh_ui()

func _seed_memory() -> void:
	for settlement in world.settlements:
		settlement_memory[int(settlement.get("id",0))] = int(settlement.get("prosperity",50))
	for faction in world.factions:
		var id := String(faction.get("id",""))
		diplomacy_memory[id] = int(faction.get("relations",0))
		faction["stability"] = int(faction.get("stability",70))
	for army in world.armies:
		morale_memory[int(army.get("id",0))] = int(army.get("morale",70))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Core100Layer"
	host.add_child(layer)
	var button := Button.new()
	button.text = "100 CORE"
	button.position = Vector2(1010, 515)
	button.size = Vector2(190, 44)
	button.pressed.connect(_toggle)
	layer.add_child(button)
	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2(185, 55)
	panel.size = Vector2(910, 610)
	panel.visible = false
	layer.add_child(panel)
	var title := Label.new()
	title.name = "Title"
	title.text = "MEDIEVAL SANDBOX • 100 CORE SYSTEMS"
	title.position = Vector2(22,16)
	title.add_theme_font_size_override("font_size",22)
	panel.add_child(title)
	var info := Label.new()
	info.name = "Info"
	info.position = Vector2(22,58)
	info.size = Vector2(850,450)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(info)
	var close := Button.new()
	close.text = "CLOSE"
	close.position = Vector2(760,550)
	close.size = Vector2(120,34)
	close.pressed.connect(_toggle)
	panel.add_child(close)
	_refresh_ui()

func _toggle() -> void:
	var p := get_node_or_null("Core100Layer/Panel") as Panel
	if p:
		p.visible = not p.visible
		_refresh_ui()

func _refresh_ui() -> void:
	var info := get_node_or_null("Core100Layer/Panel/Info") as Label
	if not info or not is_instance_valid(world):
		return
	info.text = "%s\n\n31-40  CHARACTER / ARMY\n41-50  SETTLEMENT / ECONOMY\n51-60  DIPLOMACY / FACTION AI\n61-70  EXPLORATION / ROADS / EVENTS\n71-80  SIEGE / BATTLE\n81-90  NAVAL / TRADE\n91-100 FAMILY / SUCCESSION / SANDBOX\n\nSettlements: %d   Armies: %d   Ships: %d\nFactions: %d   Sieges: %d\nWorld events: %d\n\nThese are live simulation systems attached to WorldState." % [ui_report,world.settlements.size(),world.armies.size(),world.ships.size(),world.factions.size(),world.sieges.size(),world.world_events.size()]

func _event(s: String) -> void:
	world.world_events.append(s)
	if world.world_events.size() > 120:
		world.world_events.pop_front()

func 31_character_stats() -> void:
	var level := int(world.player_level)
	character_memory["level"] = level
	character_memory["combat"] = 10 + level * 2
	character_memory["leadership"] = 5 + level

func 32_experience_progression() -> void:
	if int(world.player_xp) > 0:
		character_memory["xp"] = int(world.player_xp)

func 33_level_rewards() -> void:
	var level := int(world.player_level)
	var last := int(character_memory.get("reward_level",0))
	if level > last:
		world.gold += (level - last) * 15
		character_memory["reward_level"] = level
		_event("Your growing renown earned %d gold in rewards." % ((level-last)*15))

func 34_army_command_readiness() -> void:
	for army in world.armies:
		var readiness := int(army.get("readiness",70))
		if int(army.get("food",100)) < 30: readiness -= 5
		if int(army.get("morale",70)) > 80: readiness += 3
		army["readiness"] = clamp(readiness,0,100)

func 35_formation_cohesion() -> void:
	for army in world.armies:
		var formation := String(army.get("formation","line"))
		var cohesion := int(army.get("cohesion",70))
		if formation == "shield_wall": cohesion += 2
		elif formation == "wedge": cohesion += 1
		else: cohesion -= 1
		army["cohesion"] = clamp(cohesion,0,100)

func 36_morale_memory() -> void:
	for army in world.armies:
		var id := int(army.get("id",0))
		var morale := int(army.get("morale",70))
		morale_memory[id] = morale
		if morale < 30: army["readiness"] = max(0,int(army.get("readiness",50))-3)

func 37_desertion_pressure() -> void:
	for army in world.armies:
		if int(army.get("morale",70)) < 20 and int(army.get("soldiers",0)) > 5:
			army["soldiers"] = max(1,int(army["soldiers"])-1)
			_event("%s suffered a desertion." % String(army.get("name","Army")))

func 38_reinforcement_priority() -> void:
	for settlement in world.settlements:
		var pool := int(settlement.get("recruitment_pool",0))
		settlement["reinforcement_priority"] = clamp(pool + int(settlement.get("prosperity",50))/10,0,100)

func 39_hero_party_supply() -> void:
	var food := int(world.player_inventory.get("food",0))
	if food > 0:
		world.player_inventory["food"] = max(0,food-1)
	else:
		for army in world.armies:
			if String(army.get("owner","")) == String(world.player_faction):
				army["morale"] = max(0,int(army.get("morale",60))-1)

func 40_hero_party_recovery() -> void:
	for army in world.armies:
		if String(army.get("owner","")) == String(world.player_faction) and not bool(army.get("moving",false)):
			army["morale"] = min(100,int(army.get("morale",60))+1)

func 41_settlement_specialization() -> void:
	for s in world.settlements:
		var rid := int(s.get("region",0))
		if rid < 0 or rid >= world.regions.size(): continue
		s["specialization"] = String(world.regions[rid].get("resource","grain"))

func 42_food_reserve() -> void:
	for s in world.settlements:
		var stock := s.get("stockpile",{}) as Dictionary
		s["food_reserve_days"] = int(stock.get("food",0)) / max(1,int(s.get("population",100))/20)

func 43_famine() -> void:
	for s in world.settlements:
		if int(s.get("food_reserve_days",5)) <= 1:
			s["prosperity"] = max(0,int(s.get("prosperity",50))-3)
			s["population"] = max(1,int(s.get("population",100))-1)

func 44_festival() -> void:
	for s in world.settlements:
		if int(s.get("prosperity",50)) >= 85 and randf() < 0.02:
			s["prosperity"] = min(100,int(s["prosperity"])+2)
			_event("A festival raised morale in %s." % String(s.get("name","Settlement")))

func 45_building_maintenance() -> void:
	for s in world.settlements:
		var b := s.get("buildings",{}) as Dictionary
		s["maintenance"] = b.size()

func 46_fortification_integrity() -> void:
	for s in world.settlements:
		var wall := int(s.get("wall_level",1))
		if bool(s.get("under_siege",false)):
			s["wall_integrity"] = max(0,int(s.get("wall_integrity",wall*25))-1)
		else:
			s["wall_integrity"] = min(wall*25,int(s.get("wall_integrity",wall*25))+1)

func 47_workshop_output() -> void:
	for s in world.settlements:
		var stock := s.get("stockpile",{}) as Dictionary
		var b := s.get("buildings",{}) as Dictionary
		stock["iron"] = int(stock.get("iron",0)) + int(b.get("workshop",1))
		s["stockpile"] = stock

func 48_market_demand() -> void:
	for s in world.settlements:
		var stock := s.get("stockpile",{}) as Dictionary
		s["demand"] = max(0,100-int(stock.get("food",0))/2)

func 49_price_pressure() -> void:
	for s in world.settlements:
		s["price_pressure"] = clamp(int(s.get("demand",50))/10,0,10)

func 50_tax_efficiency() -> void:
	for s in world.settlements:
		var efficiency := 0.5 + float(s.get("prosperity",50))/200.0
		s["tax_efficiency"] = efficiency

func 51_faction_relations() -> void:
	for key in world.diplomacy.keys():
		diplomacy_memory[String(key)] = String(world.diplomacy[key])

func 52_alliance_stability() -> void:
	for key in world.diplomacy.keys():
		if String(world.diplomacy[key]) == "alliance" and randf() < 0.01:
			diplomacy_memory[String(key)] = "strained"

func 53_war_exhaustion() -> void:
	for faction in world.factions:
		var id := String(faction.get("id",""))
		var wars := 0
		for key in world.diplomacy.keys():
			if String(world.diplomacy[key]) == "war" and String(key).contains(id): wars += 1
		faction["war_exhaustion"] = clamp(wars*8,0,100)

func 54_peace_pressure() -> void:
	for faction in world.factions:
		if int(faction.get("war_exhaustion",0)) > 70:
			faction["peace_pressure"] = 80

func 55_vassal_loyalty() -> void:
	for faction in world.factions:
		var stability := int(faction.get("stability",70))
		if int(faction.get("war_exhaustion",0)) > 50: stability -= 1
		faction["stability"] = clamp(stability,0,100)

func 56_rebellion_risk() -> void:
	for faction in world.factions:
		var stability := int(faction.get("stability",70))
		faction["rebellion_risk"] = clamp(100-stability,0,100)

func 57_faction_leadership() -> void:
	for faction in world.factions:
		faction["leadership_score"] = clamp(int(faction.get("stability",70))+int(faction.get("renown",0))/10,0,100)

func 58_faction_military_budget() -> void:
	for faction in world.factions:
		var army_count := 0
		for army in world.armies:
			if String(army.get("owner","")) == String(faction.get("id","")):
				army_count += int(army.get("soldiers",0))
		faction["military_budget"] = army_count * 2

func 59_faction_recruitment() -> void:
	for faction in world.factions:
		var id := String(faction.get("id",""))
		for s in world.settlements:
			if String(s.get("owner","")) == id and int(s.get("recruitment_pool",0)) > 10:
				s["recruitment_priority"] = min(100,int(s.get("recruitment_priority",0))+2)

func 60_faction_border_pressure() -> void:
	for region in world.regions:
		var pressure := 0
		var owner := String(region.get("owner",""))
		for n in world.get_region_neighbors(int(region.get("id",0))):
			if String(world.regions[n].get("owner","")) != owner: pressure += 1
		region["border_pressure"] = pressure

func 61_discovery() -> void:
	for region in world.regions:
		region["discovered"] = bool(region.get("discovered",false))
		if String(region.get("owner","")) == String(world.player_faction):
			region["discovered"] = true

func 62_frontier_visibility() -> void:
	for region in world.regions:
		var visible := String(region.get("owner","")) == String(world.player_faction)
		for n in world.get_region_neighbors(int(region.get("id",0))):
			if String(world.regions[n].get("owner","")) == String(world.player_faction): visible = true
		region["visible_to_player"] = visible

func 63_waystation_bonus() -> void:
	for s in world.settlements:
		if String(s.get("owner","")) == String(world.player_faction):
			s["travel_bonus"] = 1 if s.get("specialization","") != "" else 0

func 64_road_damage() -> void:
	for region in world.regions:
		if int(region.get("bandit_pressure",0)) > 60:
			region["road_condition"] = max(0,int(region.get("road_condition",100))-2)

func 65_road_repair() -> void:
	for region in world.regions:
		if int(region.get("bandit_pressure",0)) < 30:
			region["road_condition"] = min(100,int(region.get("road_condition",80))+1)

func 66_bandit_encounters() -> void:
	for region in world.regions:
		if int(region.get("bandit_pressure",0)) > 80 and randf() < 0.01:
			_event("Bandits attacked travelers near %s." % String(region.get("name","the frontier")))

func 67_patrol_effect() -> void:
	for region in world.regions:
		var patrolled := false
		for army in world.armies:
			if String(army.get("owner","")) == String(world.player_faction) and int(army.get("region",0)) == int(region.get("id",0)) and String(army.get("order","")) == "defend":
				patrolled = true
		if patrolled:
			region["bandit_pressure"] = max(0,int(region.get("bandit_pressure",0))-3)

func 68_contract_reputation() -> void:
	for c in quest_memory:
		if int(c.get("days_left",0)) <= 0:
			world.player_xp += 5

func 69_contract_rewards() -> void:
	if not quest_memory.is_empty() and int(world.day) % 7 == 0:
		world.gold += 10

func 70_dynamic_world_events() -> void:
	if randf() < 0.05:
		var events := ["A merchant guild offers fair prices.","A border lord requests aid.","A harvest improves local supplies.","Travelers report an unknown road."]
		_event(events[randi_range(0,events.size()-1)])

func 71_siege_supply() -> void:
	for sid in world.sieges.keys():
		var siege := world.sieges[sid] as Dictionary
		siege["supply"] = max(0,int(siege.get("supply",100))-2)

func 72_siege_morale() -> void:
	for sid in world.sieges.keys():
		var siege := world.sieges[sid] as Dictionary
		siege["morale"] = clamp(int(siege.get("morale",70)) + (-2 if int(siege.get("supply",50)) < 20 else 1),0,100)

func 73_siege_engineering() -> void:
	for sid in world.sieges.keys():
		var siege := world.sieges[sid] as Dictionary
		siege["engineering"] = min(100,int(siege.get("engineering",0))+3)

func 74_siege_defender_reserves() -> void:
	for sid in world.sieges.keys():
		var settlement_id := int(sid)
		if settlement_id >= 0 and settlement_id < world.settlements.size():
			var s := world.settlements[settlement_id]
			s["reserve_pool"] = max(0,int(s.get("population",100))/20-int(s.get("garrison",0))/10)

func 75_battle_readiness() -> void:
	for army in world.armies:
		var readiness := int(army.get("readiness",70))
		if int(army.get("morale",70)) >= 70: readiness += 1
		army["readiness"] = clamp(readiness,0,100)

func 76_battle_casualty_recovery() -> void:
	for army in world.armies:
		if not bool(army.get("moving",false)):
			army["recoverable_casualties"] = min(20,int(army.get("recoverable_casualties",0))+1)

func 77_battle_veterans() -> void:
	for army in world.armies:
		var veterans := int(army.get("veterans",0))
		if int(army.get("morale",70)) > 85:
			veterans += 1
		army["veterans"] = min(veterans,int(army.get("soldiers",0)))

func 78_battle_command_memory() -> void:
	for army in world.armies:
		army["last_order"] = String(army.get("order","hold"))
		army["last_formation"] = String(army.get("formation","line"))

func 79_garrison_training() -> void:
	for s in world.settlements:
		if int(s.get("garrison",0)) > 0:
			s["garrison_training"] = min(100,int(s.get("garrison_training",50))+1)

func 80_frontline_warning() -> void:
	for s in world.settlements:
		if int(s.get("border_pressure",0)) > 2:
			_event("Frontier warning: %s is exposed." % String(s.get("name","Settlement")))

func 81_ship_crew() -> void:
	for ship in world.ships:
		var crew := int(ship.get("crew",10))
		ship["crew_morale"] = clamp(50 + crew,0,100)

func 82_ship_cargo() -> void:
	for ship in world.ships:
		var cargo := ship.get("cargo",{}) as Dictionary
		ship["cargo_value"] = int(cargo.get("food",0))+int(cargo.get("wood",0))*2+int(cargo.get("iron",0))*3

func 83_ship_fatigue() -> void:
	for ship in world.ships:
		var fatigue := int(ship.get("fatigue",0))
		fatigue += 2 if bool(ship.get("moving",false)) else -1
		ship["fatigue"] = clamp(fatigue,0,100)

func 84_port_prosperity() -> void:
	for s in world.settlements:
		var rid := int(s.get("region",0))
		if rid >= 0 and rid < world.regions.size():
			var res := String(world.regions[rid].get("resource",""))
			if res == "fish" or res == "salt":
				s["prosperity"] = min(100,int(s.get("prosperity",50))+1)

func 85_sea_trade() -> void:
	for ship in world.ships:
		if bool(ship.get("moving",false)) and String(ship.get("owner","")) == String(world.player_faction):
			world.gold += int(ship.get("cargo_value",0))/100

func 86_fishing_output() -> void:
	for s in world.settlements:
		var rid := int(s.get("region",0))
		if rid >= 0 and rid < world.regions.size():
			var res := String(world.regions[rid].get("resource",""))
			if res == "fish":
				var stock := s.get("stockpile",{}) as Dictionary
				stock["food"] = int(stock.get("food",0))+3
				s["stockpile"] = stock

func 87_naval_visibility() -> void:
	for ship in world.ships:
		ship["visible_on_map"] = true

func 88_storm_damage() -> void:
	if String(world.weather) != "storm": return
	for ship in world.ships:
		ship_health_damage(ship)

func ship_health_damage(ship: Dictionary) -> void:
	ship["health"] = max(0,int(ship.get("health",100))-1)

func 89_shipyard_repairs() -> void:
	for ship in world.ships:
		if not bool(ship.get("moving",false)):
			ship["health"] = min(100,int(ship.get("health",100))+2)

func 90_sea_route_risk() -> void:
	for ship in world.ships:
		ship["route_risk"] = 10 if String(world.weather) == "clear" else 30

func 91_family_relations() -> void:
	for member in world.family_members:
		member["relationship_score"] = clamp(int(member.get("relationship_score",50)),0,100)

func 92_family_reputation() -> void:
	var total := 0
	for member in world.family_members:
		total += int(member.get("relationship_score",50))
	world.family["family_reputation"] = total / max(1,world.family_members.size())

func 93_heir_readiness() -> void:
	var heir_age := int(world.family.get("heir_age",0))
	world.family["heir_ready"] = heir_age >= 18

func 94_succession_support() -> void:
	world.family["succession_support"] = clamp(int(world.family.get("family_reputation",50))+int(world.family.get("succession_pressure",0))/2,0,100)

func 95_house_wealth() -> void:
	world.family["house_wealth"] = int(world.gold) + int(world.family.get("family_reputation",50))*2

func 96_player_renown() -> void:
	world.player_renown = max(0,int(world.get("player_renown")) + (1 if int(world.day)%7==0 else 0))

func 97_player_reputation() -> void:
	world.player_reputation = clamp(int(world.get("player_reputation")), -100,100)

func 98_campaign_statistics() -> void:
	world.campaign_statistics = {"day":int(world.day),"gold":int(world.gold),"armies":world.armies.size(),"settlements":world.settlements.size(),"ships":world.ships.size(),"events":world.world_events.size()}

func 99_world_event_history() -> void:
	world.event_history = world.world_events.slice(max(0,world.world_events.size()-40),world.world_events.size())

func 100_sandbox_consistency() -> void:
	for s in world.settlements:
		s["population"] = max(1,int(s.get("population",1)))
		s["garrison"] = clamp(int(s.get("garrison",0)),0,int(s.get("population",1)))
	for army in world.armies:
		army["soldiers"] = max(0,int(army.get("soldiers",0)))
		army["morale"] = clamp(int(army.get("morale",50)),0,100)
