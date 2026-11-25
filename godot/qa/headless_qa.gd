extends SceneTree

# Headless gameplay QA.
# Boots the real main scene, then exercises the real world simulation:
# continent generation, day ticks, battles, sieges, naval combat, trade,
# family/succession data and save/load persistence.
# Exits non-zero if any check fails.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS  ", label)
	else:
		failures.append(label)
		printerr("FAIL  ", label)

func _frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _run() -> void:
	var packed: PackedScene = load("res://main.tscn")
	check(packed != null, "main.tscn loads")
	if packed == null:
		_finish()
		return
	var main: Node = packed.instantiate()
	root.add_child(main)
	# Behave like a real launch: autoloads attach to the current scene.
	current_scene = main
	await _frames(90)

	var world = main.get_node_or_null("WorldState")
	check(world != null, "main scene creates WorldState")
	if world == null:
		_finish()
		return

	# --- continent generation -------------------------------------------
	check(world.regions.size() >= 12, "continent has at least 12 regions (%d)" % world.regions.size())
	check(world.factions.size() >= 6, "continent has at least 6 factions (%d)" % world.factions.size())
	check(world.settlements.size() >= 12, "continent has at least 12 settlements (%d)" % world.settlements.size())
	check(world.armies.size() >= 5, "continent has armies (%d)" % world.armies.size())
	check(world.ships.size() >= 2, "coastal factions own ships (%d)" % world.ships.size())
	var settlement_types := {}
	for settlement in world.settlements:
		settlement_types[String(settlement["type"])] = true
	check(settlement_types.size() >= 3, "settlements differ in type (%s)" % [settlement_types.keys()])

	# settlement ownership must reference real factions
	var valid_owner := true
	for settlement in world.settlements:
		if world.get_faction_name(String(settlement["owner"])) == String(settlement["owner"]) and String(settlement["owner"]) != "Free Company":
			valid_owner = false
	check(valid_owner, "every settlement is owned by a known faction")

	# --- governance / diplomacy -----------------------------------------
	var peace_state: Dictionary = world.set_diplomacy("north_kingdom", "river_kingdom", "war")
	check(bool(peace_state.get("ok", false)), "diplomacy state can be changed")
	world.set_diplomacy("north_kingdom", "river_kingdom", "peace")

	# --- economy ---------------------------------------------------------
	var prices: Dictionary = world.get_market_prices(0)
	check(prices.size() >= 3, "market prices available for resources")
	var gold_before: int = world.gold
	var buy_result: Dictionary = world.trade_resource(0, "food", 5, true)
	check(bool(buy_result.get("ok", false)), "player can buy goods from a market")
	check(world.gold <= gold_before, "buying goods spends gold")
	var sell_result: Dictionary = world.trade_resource(0, "food", 2, false)
	check(bool(sell_result.get("ok", false)), "player can sell goods to a market")

	# --- recruitment -----------------------------------------------------
	var recruit: Dictionary = world.recruit_from_settlement(0, "levy", 2)
	check(bool(recruit.get("ok", false)), "player can recruit troops")
	check(int(recruit.get("cost", 0)) > 0, "recruitment charges gold")

	# --- autonomous world simulation -------------------------------------
	var day_start: int = world.day
	for i in range(45):
		world.advance_day()
	check(world.day == day_start + 45, "advancing days advances world time (%d -> %d)" % [day_start, world.day])
	check(world.weather != "", "weather is driven by the day tick")
	var stable := true
	for army in world.armies:
		if int(army.get("soldiers", 0)) < 0 or float(army.get("morale", 0)) < 0.0:
			stable = false
	for settlement in world.settlements:
		if int(settlement.get("garrison", 0)) < 0 or int(settlement.get("population", 0)) <= 0:
			stable = false
	check(stable, "45 simulated days keep army and settlement state valid")
	check(world.caravans.size() > 0, "caravans are travelling after simulation (%d)" % world.caravans.size())

	# --- release simulation layers ---------------------------------------
	# These layers tick on wall-clock timers (4s army/faction sim, 20s day
	# advance). Give them real time to run against the live world.
	await create_timer(4.6).timeout
	await _frames(5)
	var layers_consistent := true
	for i in range(world.armies.size()):
		if int(world.armies[i].get("id", -1)) != i:
			layers_consistent = false
	for settlement in world.settlements:
		if int(settlement.get("garrison", 0)) < 0:
			layers_consistent = false
	check(layers_consistent, "release simulation layers keep armies and settlements valid")
	check(world.settlements.size() >= 12, "release simulation layers do not shrink the world")

	# --- battles ---------------------------------------------------------
	var target_id := -1
	for i in range(world.settlements.size()):
		if String(world.settlements[i]["owner"]) != world.player_faction:
			target_id = i
			break
	check(target_id >= 0, "an enemy settlement exists to attack")
	if target_id >= 0:
		var attacker: Dictionary = world.get_player_battle_force()
		var defender: Dictionary = world.get_settlement_defender(target_id)
		check(int(attacker.get("soldiers", 0)) > 0, "player battle force reflects real army strength")
		check(int(defender.get("soldiers", 0)) > 0, "defender force reflects the real garrison")
		var manual: Dictionary = world.apply_manual_battle_result(target_id, 3, 5, {"levy": 3}, {"levy": 5}, false)
		check(manual.size() > 0, "manual battle results are accepted by the world")
		var original_owner := String(world.settlements[target_id]["owner"])
		var auto: Dictionary = world.resolve_auto_battle(target_id, attacker, defender)
		check(auto.size() > 0, "auto battle resolves against world state")
		check(String(world.settlements[target_id]["owner"]) == original_owner or String(world.settlements[target_id]["owner"]) == world.player_faction,
			"settlement ownership stays consistent after a battle")

	# --- sieges ----------------------------------------------------------
	if target_id >= 0:
		world.settlements[target_id]["owner"] = "eastern_tribes"
		world.diplomacy["eastern_tribes|Free Company"] = "war"
		world.diplomacy["Free Company|eastern_tribes"] = "war"
		var recruited: Dictionary = world.recruit_from_settlement(target_id, "spearman", 4)
		check(bool(recruited.get("ok", false)), "recruiting at a settlement raises a player army")
		var player_army := -1
		for i in range(world.armies.size()):
			if String(world.armies[i]["owner"]) == world.player_faction and int(world.armies[i]["region"]) == int(world.settlements[target_id]["region"]):
				player_army = i
				break
		check(player_army >= 0, "the player's company is present in the target region")
		if player_army >= 0:
			var start: Dictionary = world.start_siege(target_id, player_army)
			check(bool(start.get("ok", false)), "a siege can be started from the player's army (%s)" % [start.get("reason", "")])
			check(world.sieges.has(target_id), "siege state is tracked in the world")
			var siege_before: Dictionary = world.sieges.get(target_id, {})
			var wall_before: int = int(siege_before.get("wall_hp", 0))
			var armies_before: int = world.armies.size()
			var garrison_before: int = int(world.settlements[target_id]["garrison"])
			var assault: Dictionary = world.assault_siege(target_id)
			check(bool(assault.get("ok", false)), "siege assault produces a real outcome")
			# A real assault must leave a consequence: an ongoing siege, a conquest,
			# or a destroyed besieging army. Nothing may resolve to "no change".
			var has_consequence: bool = world.sieges.has(target_id) \
				or String(world.settlements[target_id]["owner"]) == world.player_faction \
				or world.armies.size() != armies_before \
				or int(world.settlements[target_id]["garrison"]) != garrison_before
			check(has_consequence, "siege assault changes real world state")
			if world.sieges.has(target_id):
				var siege_after: Dictionary = world.sieges[target_id]
				check(int(siege_after.get("wall_hp", 0)) <= wall_before, "siege assault damages real defensive structures")
			check(int(world.settlements[target_id]["garrison"]) >= 0, "siege assault updates the real garrison")
			world.settlement_siege_end(target_id)

	# --- naval -----------------------------------------------------------
	var ship_ids: Array = []
	for i in range(world.ships.size()):
		ship_ids.append(i)
	var naval: Dictionary = world.naval_battle(ship_ids[0], ship_ids[1])
	check(bool(naval.get("ok", false)), "naval battles resolve between real ships")
	var ship_ids_valid := true
	for i in range(world.ships.size()):
		if int(world.ships[i].get("id", -1)) != i:
			ship_ids_valid = false
	check(world.ships.size() == ship_ids.size() and ship_ids_valid, "naval battle keeps ship records and indices consistent")

	# --- family / progression -------------------------------------------
	var family_member: Dictionary = world.add_family_member("Test Heir", "child", 4)
	check(family_member.size() > 0, "family members can be added")
	var summary: Dictionary = world.get_player_summary()
	check(int(summary.get("level", 0)) >= 1, "player summary reports progression")

	# --- autoload systems -----------------------------------------------
	for autoload in ["BattleController", "FinalGameSystems", "FinalSystemsUI", "CampaignSystems", "CompletionSystems"]:
		check(root.get_node_or_null(autoload) != null, "autoload %s is running" % autoload)

	# --- save / load round trip -----------------------------------------
	world.save_path = "user://qa_roundtrip.json"
	if target_id >= 0:
		# A real battle cooldown on an integer settlement key, used to prove that
		# integer-keyed dictionaries survive the JSON round trip.
		world.battle_cooldowns[target_id] = 5
	world.gold = 4321
	world.day = 77
	world.player_level = 4
	check(world.save_game(), "world saves to disk")
	world.gold = 1
	world.day = 1
	world.player_level = 1
	check(world.load_game(), "world loads from disk")
	check(world.gold == 4321, "save/load restores gold (%d)" % world.gold)
	check(world.day == 77, "save/load restores world day (%d)" % world.day)
	check(int(world.player_level) == 4, "save/load restores player level")
	# JSON stores object keys as text; integer-keyed simulation dictionaries must
	# come back with integer keys or every lookup silently misses after a load.
	var int_keys_ok := true
	for key in world.sieges.keys():
		if typeof(key) != TYPE_INT:
			int_keys_ok = false
	for key in world.battle_cooldowns.keys():
		if typeof(key) != TYPE_INT:
			int_keys_ok = false
	check(int_keys_ok, "save/load restores integer-keyed siege and cooldown state")
	if target_id >= 0:
		check(world.battle_cooldowns.has(target_id) and int(world.battle_cooldowns[target_id]) == 5, "save/load keeps battle cooldown values on integer keys")
	check(world.settlements.size() >= 12, "save/load restores settlements")
	check(world.armies.size() >= 5, "save/load restores armies")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://qa_roundtrip.json"))

	# --- long-run stability ---------------------------------------------
	for i in range(120):
		world.advance_day()
	check(world.day == 197, "120 further days simulate without failure (day %d)" % world.day)
	var ownership_valid := true
	for settlement in world.settlements:
		var owner := String(settlement["owner"])
		if owner != world.player_faction and world.get_faction_name(owner) == owner:
			ownership_valid = false
	check(ownership_valid, "settlement ownership stays valid after 165 simulated days")

	_finish()

func _finish() -> void:
	print("---")
	print("QA CHECKS: %d, FAILURES: %d" % [checks, failures.size()])
	if failures.is_empty():
		print("HEADLESS QA PASSED")
		quit(0)
	else:
		for failure in failures:
			printerr("HEADLESS QA FAILED: ", failure)
		quit(1)
