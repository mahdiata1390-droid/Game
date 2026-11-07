extends Node
class_name ReleaseThirtySystems
## Thirty connected campaign systems. These are gameplay logic, not placeholder files.
## The manager intentionally works against the existing WorldState dictionaries so the
## systems remain compatible with the current campaign without replacing its core data.

var host: Node
var world: Node
var day_timer = 0.0
var sim_interval = 18.0
var last_report = "30 systems online"
var reputation = 0
var renown = 0
var player_food_stock = 30
var active_contracts: Array[Dictionary] = []
var contract_serial = 1
var siege_progress: Dictionary = {}
var ship_health: Dictionary = {}
var army_supply: Dictionary = {}
var settlement_alerts: Array[String] = []
var faction_stability: Dictionary = {}
var patrol_routes: Dictionary = {}
var scout_reports: Array[String] = []
var system_stats: Dictionary = {}

func build(main: Node) -> void:
	host = main
	world = host.world_state
	for faction in world.factions:
		faction_stability[String(faction.get("id",""))] = 70
	_create_initial_contracts()
	_create_ui()
	_refresh_stats()

func _process(delta: float) -> void:
	if not is_instance_valid(world):
		return
	day_timer += delta
	if day_timer >= sim_interval:
		day_timer = 0.0
		run_campaign_tick()

func _create_ui() -> void:
	var layer = CanvasLayer.new()
	layer.name = "ThirtySystemsLayer"
	host.add_child(layer)
	var open = Button.new()
	open.text = "30 SYSTEMS"
	open.position = Vector2(1010, 465)
	open.size = Vector2(190, 46)
	open.pressed.connect(_toggle_panel)
	layer.add_child(open)

	var panel = Panel.new()
	panel.name = "SystemsPanel"
	panel.position = Vector2(245, 70)
	panel.size = Vector2(790, 580)
	panel.visible = false
	layer.add_child(panel)
	var title = Label.new()
	title.text = "CAMPAIGN CORE • 30 ACTIVE SYSTEMS"
	title.position = Vector2(24, 18)
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)

	var list = Label.new()
	list.name = "SystemList"
	list.position = Vector2(24, 62)
	list.size = Vector2(360, 430)
	list.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(list)

	var report = Label.new()
	report.name = "Report"
	report.position = Vector2(410, 62)
	report.size = Vector2(350, 250)
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(report)

	var tick = Button.new()
	tick.text = "RUN CAMPAIGN DAY"
	tick.position = Vector2(410, 330)
	tick.size = Vector2(300, 52)
	tick.pressed.connect(run_campaign_tick)
	panel.add_child(tick)

	var contract = Button.new()
	contract.text = "GENERATE CONTRACT"
	contract.position = Vector2(410, 395)
	contract.size = Vector2(300, 52)
	contract.pressed.connect(_generate_contract)
	panel.add_child(contract)

	var scout = Button.new()
	scout.text = "SCOUT FRONTIER"
	scout.position = Vector2(410, 460)
	scout.size = Vector2(300, 52)
	scout.pressed.connect(_scout_frontier)
	panel.add_child(scout)

	var close = Button.new()
	close.text = "CLOSE"
	close.position = Vector2(410, 525)
	close.size = Vector2(300, 36)
	close.pressed.connect(_toggle_panel)
	panel.add_child(close)

func _toggle_panel() -> void:
	var panel = get_node_or_null("ThirtySystemsLayer/SystemsPanel") as Panel
	if panel:
		panel.visible = not panel.visible
		_refresh_stats()

func _refresh_stats() -> void:
	var panel = get_node_or_null("ThirtySystemsLayer/SystemsPanel") as Panel
	if not panel:
		return
	var list = panel.get_node_or_null("SystemList") as Label
	var report = panel.get_node_or_null("Report") as Label
	if list:
		list.text = "01 Weather modifiers\n02 Food & hunger\n03 Army morale\n04 Army supply\n05 Garrison recovery\n06 Settlement prosperity\n07 Population growth\n08 Resource production\n09 Dynamic market\n10 Tax collection\n11 Caravan risk\n12 Road safety\n13 Bandit pressure\n14 Diplomacy drift\n15 Faction treasury\n16 Recruitment pool\n17 Army movement\n18 Scouting\n19 Patrol routes\n20 Siege attrition\n21 Siege progress\n22 Siege breach\n23 Naval supply\n24 Naval trade\n25 Ship repairs\n26 Family aging\n27 Succession pressure\n28 Dynamic contracts\n29 World events\n30 Reputation & renown"
	if report:
		report.text = "STATUS: %s\n\nDay: %d\nGold: %d\nReputation: %d\nRenown: %d\nContracts: %d\nScout reports: %d\n\n%s" % [last_report, int(world.day), int(world.gold), reputation, renown, active_contracts.size(), scout_reports.size(), _stats_line()]

func _stats_line() -> String:
	return "Systems processed: %d\nPopulation: %d\nArmies: %d\nSettlements: %d\nShips: %d\nActive sieges: %d" % [int(system_stats.get("ticks",0)), _total_population(), world.armies.size(), world.settlements.size(), world.ships.size(), world.sieges.size()]

func run_campaign_tick() -> void:
	if not is_instance_valid(world) or bool(world.get("simulation_paused")):
		return
	# One tick represents one campaign day. The core WorldState remains authoritative.
	system_stats["ticks"] = int(system_stats.get("ticks",0)) + 1
	_system_01_weather_modifiers()
	_system_02_food_hunger()
	_system_03_army_morale()
	_system_04_army_supply()
	_system_05_garrison_recovery()
	_system_06_settlement_prosperity()
	_system_07_population_growth()
	_system_08_resource_production()
	_system_09_dynamic_market()
	_system_10_tax_collection()
	_system_11_caravan_risk()
	_system_12_road_safety()
	_system_13_bandit_pressure()
	_system_14_diplomacy_drift()
	_system_15_faction_treasury()
	_system_16_recruitment_pool()
	_system_17_army_movement()
	_system_18_scouting()
	_system_19_patrol_routes()
	_system_20_siege_attrition()
	_system_21_siege_progress()
	_system_22_siege_breach()
	_system_23_naval_supply()
	_system_24_naval_trade()
	_system_25_ship_repairs()
	_system_26_family_aging()
	_system_27_succession_pressure()
	_system_28_dynamic_contracts()
	_system_29_world_events()
	_system_30_reputation_renown()
	last_report = "Campaign day %d processed successfully." % int(world.day)
	_refresh_stats()

func _system_01_weather_modifiers() -> void:
	var weather = String(world.weather)
	var modifier = 1.0
	if weather == "storm": modifier = 0.72
	elif weather == "snow": modifier = 0.78
	elif weather == "rain": modifier = 0.88
	elif weather == "fog": modifier = 0.92
	system_stats["weather_modifier"] = modifier

func _system_02_food_hunger() -> void:
	for army in world.armies:
		var soldiers = int(army.get("soldiers",0))
		var food = int(army.get("food",100))
		food -= max(1, int(ceil(float(soldiers) / 100.0)))
		army["food"] = max(0, food)
		if food <= 0:
			army["morale"] = max(0, int(army.get("morale",50)) - 4)
			army["soldiers"] = max(0, soldiers - 1)

func _system_03_army_morale() -> void:
	for army in world.armies:
		var morale = int(army.get("morale",70))
		var soldiers = int(army.get("soldiers",0))
		var target = 70
		if soldiers < 20: target -= 20
		if int(army.get("food",100)) <= 0: target -= 25
		if String(army.get("order","hold")) == "attack": target += 3
		army["morale"] = clamp(morale + sign(target - morale), 0, 100)

func _system_04_army_supply() -> void:
	for army in world.armies:
		var id = int(army.get("id",-1))
		var supply = int(army_supply.get(id,100))
		supply -= 3 if bool(army.get("moving",false)) else 1
		if int(army.get("food",100)) > 70: supply += 2
		if supply <= 20:
			army["morale"] = max(0, int(army.get("morale",60)) - 2)
		army_supply[id] = clamp(supply,0,100)

func _system_05_garrison_recovery() -> void:
	for settlement in world.settlements:
		var max_garrison = max(20, int(settlement.get("population",100)) / 12)
		var garrison = int(settlement.get("garrison",0))
		if garrison < max_garrison and int(settlement.get("prosperity",50)) > 35:
			settlement["garrison"] = min(max_garrison, garrison + 2)

func _system_06_settlement_prosperity() -> void:
	for settlement in world.settlements:
		var prosperity = int(settlement.get("prosperity",50))
		var stock = settlement.get("stockpile",{}) as Dictionary
		if int(stock.get("food",0)) > 50: prosperity += 1
		if int(settlement.get("garrison",0)) <= 0: prosperity -= 2
		if bool(settlement.get("siege",false)): prosperity -= 5
		settlement["prosperity"] = clamp(prosperity,0,100)

func _system_07_population_growth() -> void:
	for region in world.regions:
		var population = int(region.get("population",1000))
		var prosperity = int(region.get("prosperity",50))
		var growth = max(0, int(float(population) * (0.001 + float(prosperity) / 100000.0)))
		region["population"] = population + growth
	for settlement in world.settlements:
		var population = int(settlement.get("population",100))
		var prosperity = int(settlement.get("prosperity",50))
		settlement["population"] = population + (1 if prosperity >= 50 else 0)

func _system_08_resource_production() -> void:
	for settlement in world.settlements:
		var stock = settlement.get("stockpile",{}) as Dictionary
		var buildings = settlement.get("buildings",{}) as Dictionary
		var farm = int(buildings.get("farm",1))
		var workshop = int(buildings.get("workshop",1))
		var resource = String(world.regions[int(settlement.get("region",0))].get("resource","grain"))
		stock["food"] = int(stock.get("food",0)) + farm * (2 if resource == "grain" else 1)
		stock["wood"] = int(stock.get("wood",0)) + (2 if resource == "wood" else 1)
		stock["iron"] = int(stock.get("iron",0)) + workshop
		settlement["stockpile"] = stock

func _system_09_dynamic_market() -> void:
	for settlement in world.settlements:
		var prosperity = int(settlement.get("prosperity",50))
		var stock = settlement.get("stockpile",{}) as Dictionary
		var scarcity = 0
		for key in ["food","wood","iron"]:
			if int(stock.get(key,0)) < 20: scarcity += 1
		settlement["market_pressure"] = clamp(scarcity + int((50 - prosperity) / 20), 0, 6)

func _system_10_tax_collection() -> void:
	var total = 0
	for faction in world.factions:
		var faction_total = 0
		for settlement in world.settlements:
			if String(settlement.get("owner","")) != String(faction.get("id","")): continue
			var tax = int(float(settlement.get("population",0)) * float(settlement.get("tax_rate",0.10)) / 30.0)
			faction_total += max(0,tax)
		faction["treasury"] = int(faction.get("treasury",0)) + faction_total
		if String(faction.get("id","")) == String(world.player_faction):
			world.gold += faction_total
			total += faction_total
	world.yearly_tax += total

func _system_11_caravan_risk() -> void:
	for caravan in world.caravans:
		var risk = 0.05
		if String(world.weather) == "storm": risk += 0.08
		var origin = int(caravan.get("origin",0))
		if origin >= 0 and origin < world.settlements.size() and int(world.settlements[origin].get("prosperity",50)) < 30:
			risk += 0.05
		caravan["risk"] = risk
		if randf() < risk * 0.05:
			caravan["profit"] = max(0,int(caravan.get("profit",0)) - 5)
			world.world_events.append("A caravan lost cargo on the road.")

func _system_12_road_safety() -> void:
	for region in world.regions:
		var owner = String(region.get("owner",""))
		var hostile_neighbors = 0
		for n in world.get_region_neighbors(int(region.get("id",0))):
			if String(world.regions[n].get("owner","")) != owner:
				hostile_neighbors += 1
		region["road_safety"] = clamp(100 - hostile_neighbors * 18, 10, 100)

func _system_13_bandit_pressure() -> void:
	for region in world.regions:
		var safety = int(region.get("road_safety",70))
		var pressure = int(region.get("bandit_pressure",10))
		pressure += 2 if safety < 40 else -1
		region["bandit_pressure"] = clamp(pressure,0,100)
		if pressure > 70:
			world.world_events.append("Bandits are disrupting roads in %s." % String(region.get("name","region")))

func _system_14_diplomacy_drift() -> void:
	for key in world.diplomacy.keys():
		var state = String(world.diplomacy[key])
		if state == "peace" and randf() < 0.03:
			world.world_events.append("Diplomatic tension is rising: %s." % String(key))
		elif state == "war" and randf() < 0.02:
			world.world_events.append("Envoys discuss a possible truce: %s." % String(key))

func _system_15_faction_treasury() -> void:
	for faction in world.factions:
		var id = String(faction.get("id",""))
		if id == "Free Company": continue
		var treasury = int(faction.get("treasury",0))
		var army_count = 0
		for army in world.armies:
			if String(army.get("owner","")) == id: army_count += int(army.get("soldiers",0))
		treasury -= int(army_count / 80)
		faction["treasury"] = max(0,treasury)

func _system_16_recruitment_pool() -> void:
	for settlement in world.settlements:
		var pool = max(0,int(settlement.get("population",0)) / 15 - int(settlement.get("garrison",0)))
		settlement["recruitment_pool"] = pool

func _system_17_army_movement() -> void:
	for army in world.armies:
		if not bool(army.get("moving",false)): continue
		var current = int(army.get("region",0))
		var target = int(army.get("target_region",current))
		if target in world.get_region_neighbors(current):
			army["region"] = target
			army["moving"] = false
			world.world_events.append("%s reached %s." % [String(army.get("name","Army")),String(world.regions[target].get("name","region"))])

func _system_18_scouting() -> void:
	for army in world.armies:
		if String(army.get("owner","")) != String(world.player_faction): continue
		var region_id = int(army.get("region",0))
		var enemies = 0
		for other in world.armies:
			if String(other.get("owner","")) != String(world.player_faction) and int(other.get("region",0)) == region_id:
				enemies += 1
		army["scouted_enemy_count"] = enemies

func _system_19_patrol_routes() -> void:
	for region in world.regions:
		var rid = int(region.get("id",0))
		if not patrol_routes.has(rid):
			patrol_routes[rid] = {"days":0,"safety_bonus":0}
		var patrol = patrol_routes[rid] as Dictionary
		patrol["days"] = int(patrol.get("days",0)) + 1
		patrol["safety_bonus"] = 5 if int(patrol["days"]) % 3 == 0 else 0
		region["road_safety"] = clamp(int(region.get("road_safety",50)) + int(patrol["safety_bonus"]),0,100)

func _system_20_siege_attrition() -> void:
	for sid in world.sieges.keys():
		var siege = world.sieges[sid] as Dictionary
		var settlement_id = int(sid)
		if settlement_id < 0 or settlement_id >= world.settlements.size(): continue
		var settlement = world.settlements[settlement_id] as Dictionary
		settlement["prosperity"] = max(0,int(settlement.get("prosperity",50)) - 1)
		settlement["garrison"] = max(0,int(settlement.get("garrison",0)) - 1)
		siege["days"] = int(siege.get("days",0)) + 1

func _system_21_siege_progress() -> void:
	for sid in world.sieges.keys():
		var key = String(sid)
		siege_progress[key] = int(siege_progress.get(key,0)) + 4
		var siege = world.sieges[sid] as Dictionary
		siege["progress"] = clamp(int(siege_progress[key]),0,100)

func _system_22_siege_breach() -> void:
	for sid in world.sieges.keys():
		var siege = world.sieges[sid] as Dictionary
		var settlement_id = int(sid)
		if int(siege.get("progress",0)) >= 60:
			if not bool(siege.get("breached",false)):
				siege["breached"] = true
				if settlement_id >= 0 and settlement_id < world.settlements.size():
					world.settlements[settlement_id]["wall_level"] = max(0,int(world.settlements[settlement_id].get("wall_level",1))-1)
					world.world_events.append("%s has suffered a siege breach." % String(world.settlements[settlement_id].get("name","Settlement")))

func _system_23_naval_supply() -> void:
	for ship in world.ships:
		var id = int(ship.get("id",0))
		var supply = int(ship.get("supply",100))
		supply -= 2 if bool(ship.get("moving",false)) else 1
		ship["supply"] = clamp(supply,0,100)
		if supply <= 15:
			ship["crew"] = max(1,int(ship.get("crew",1))-1)
		ship_health[id] = int(ship_health.get(id,100))

func _system_24_naval_trade() -> void:
	for ship in world.ships:
		if not bool(ship.get("moving",false)): continue
		if String(ship.get("owner","")) == String(world.player_faction):
			var cargo = ship.get("cargo",{}) as Dictionary
			var cargo_value = int(cargo.get("food",0)) + int(cargo.get("wood",0))*2 + int(cargo.get("iron",0))*3
			ship["trade_value"] = cargo_value
			if cargo_value > 80:
				world.gold += 2

func _system_25_ship_repairs() -> void:
	for ship in world.ships:
		var id = int(ship.get("id",0))
		var hp = int(ship_health.get(id,100))
		if not bool(ship.get("moving",false)):
			ship_health[id] = min(100,hp+3)
		ship["health"] = int(ship_health.get(id,100))

func _system_26_family_aging() -> void:
	if world.family.is_empty(): return
	if int(world.day) % 30 == 0:
		world.family["age"] = int(world.family.get("age",18)) + 1
		for member in world.family_members:
			member["age"] = int(member.get("age",18)) + 1

func _system_27_succession_pressure() -> void:
	var age = int(world.family.get("age",18))
	var pressure = clamp(int((age - 45) * 2),0,100)
	world.family["succession_pressure"] = pressure
	if pressure >= 70:
		world.family["heir_name"] = "Designated Heir"
		world.family["heir_age"] = max(0,int(world.family.get("heir_age",0)))

func _system_28_dynamic_contracts() -> void:
	for i in range(active_contracts.size() - 1, -1, -1):
		var contract: Dictionary = active_contracts[i]
		contract["days_left"] = int(contract.get("days_left",1)) - 1
		if int(contract["days_left"]) <= 0:
			if String(contract.get("type","")) == "patrol":
				reputation += 3
				renown += 2
			active_contracts.remove_at(i)
	if active_contracts.size() < 3:
		_generate_contract()

func _system_29_world_events() -> void:
	if randf() < 0.12:
		var events = ["A market festival increases prosperity.","A caravan arrives early.","A local lord requests more patrols.","A harsh season reduces production."]
		var event = events[randi_range(0,events.size()-1)]
		world.world_events.append(event)
		if event.contains("festival"):
			for settlement in world.settlements:
				settlement["prosperity"] = min(100,int(settlement.get("prosperity",50))+2)

func _system_30_reputation_renown() -> void:
	var level = int(world.player_level)
	reputation = clamp(reputation + (1 if level >= 5 else 0), -100, 100)
	renown = max(0,renown + (1 if world.armies.size() > 0 and world.day % 7 == 0 else 0))

func _generate_contract() -> void:
	var types = ["patrol","trade","escort","recruit"]
	var typ = types[randi_range(0,types.size()-1)]
	var target = "the frontier"
	if not world.settlements.is_empty():
		target = String(world.settlements[randi_range(0,world.settlements.size()-1)].get("name","settlement"))
	var reward = 30 + randi_range(0,70)
	active_contracts.append({"id":contract_serial,"type":typ,"target":target,"reward":reward,"days_left":randi_range(3,7)})
	contract_serial += 1

func _create_initial_contracts() -> void:
	for i in range(3):
		_generate_contract()

func _scout_frontier() -> void:
	var best = ""
	var best_pressure = -1
	for region in world.regions:
		var pressure = int(region.get("bandit_pressure",0))
		if pressure > best_pressure:
			best_pressure = pressure
			best = String(region.get("name","region"))
	if best != "":
		var report = "Scout report: %s has bandit pressure %d/100." % [best,best_pressure]
		scout_reports.append(report)
		last_report = report
		_refresh_stats()

func _total_population() -> int:
	var total = 0
	for region in world.regions:
		total += int(region.get("population",0))
	return total
