extends SceneTree
## Rainstep travel, waterworks, local recovery, and version-one save boundaries.

const RAIN_FLAGS: Array[String] = ["rain_arrived", "rain_started", "rain_upper", "rain_middle", "rain_lower", "rain_rewarded"]
const REPAIRS: Array[String] = ["rain_upper", "rain_middle", "rain_lower"]

var state_script: Script
var quest_script: Script
var encounter_script: Script
var battle_script: Script
var db: Script
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_check(ResourceLoader.exists("res://scripts/rain_quest.gd"), "Rainstep travel and waterworks implementation exists")
	if failures > 0:
		_finish()
		return
	state_script = load("res://scripts/game_state.gd")
	quest_script = load("res://scripts/rain_quest.gd")
	encounter_script = load("res://scripts/encounter_tables.gd")
	battle_script = load("res://scripts/battle.gd")
	db = load("res://scripts/creature_db.gd")
	_test_travel_gates_and_cost()
	_test_all_repair_orders()
	_test_keeper_recovery_and_reward()
	_test_persistence_and_legacy_defaults()
	_test_invalid_saves_are_transactional()
	_test_rain_arrival_chain_is_transactional()
	_test_local_defeat_and_reload_recovery()
	_test_regional_encounters()
	_finish()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _finish() -> void:
	print("RAIN RULES TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _new_game(completed_trial: bool = true):
	var game = state_script.new()
	game.choose_starter(1)
	if completed_trial:
		game.flags.captured = true
		game.flags.rival = true
		game.flags.gym = true
	return game


func _snapshot(game) -> Dictionary:
	return {"party": game.party.duplicate(true), "collection": game.collection.duplicate(), "flags": game.flags.duplicate(), "orbs": game.orbs, "tonics": game.tonics, "position": game.position, "island_id": game.island_id, "play_seconds": game.play_seconds}


func _check_dialogue(reply: Dictionary, message: String) -> void:
	_check(reply.has_all(["speaker", "lines", "changed", "sound"]), message + " has a complete dialogue result")
	if not reply.has_all(["speaker", "lines", "changed", "sound"]):
		return
	_check(reply.speaker is String and reply.lines is Array and reply.changed is bool and reply.sound is String, message + " uses stable result types")
	_check(not str(reply.speaker).is_empty() and not reply.lines.is_empty(), message + " supplies visible feedback")
	for line: Variant in reply.lines:
		_check(line is String and not str(line).is_empty(), message + " contains readable text")


func _test_travel_gates_and_cost() -> void:
	var fresh = state_script.new()
	var early = _new_game(false)
	for locked in [fresh, early]:
		var before: Dictionary = _snapshot(locked)
		_check(str(quest_script.objective(locked)).is_empty(), "The ferry objective waits until the trial is complete")
		_check(not quest_script.travel(locked, "rainstep") and _snapshot(locked) == before, "The outward ferry cannot bypass the Lantern Sigil")
		for role: String in ["rain_keeper", "rain_upper", "rain_middle", "rain_lower"]:
			var reply: Dictionary = quest_script.interact(locked, role)
			_check_dialogue(reply, "Locked waterworks")
			_check(not reply.changed and _snapshot(locked) == before, "Locked interactions leave the adventure unchanged")
	var game = _new_game()
	game.orbs = 0
	game.tonics = 0
	var before: Dictionary = _snapshot(game)
	_check(str(quest_script.objective(game)).contains("SAIL"), "The completed trial points toward the ferry")
	for destination: String in ["", "unknown", "Rainstep", "wakeharbor"]:
		_check(not quest_script.travel(game, destination) and _snapshot(game) == before, "Invalid and same-island destinations cannot teleport or mutate the journey")
	_check(quest_script.travel(game, "rainstep"), "The sigil unlocks outward travel with an empty bag")
	_check(game.island_id == "rainstep" and game.position == Vector3(60, 0, 8), "The outward ferry places the player on the Rainstep landing")
	_check(game.flags.rain_arrived and not game.flags.rain_started and game.orbs == 0 and game.tonics == 0, "Arrival costs nothing and does not accept the waterworks quest")
	_check(str(quest_script.objective(game)).contains("MEET ORLA"), "First arrival points to the local keeper")
	for key: String in before.flags:
		if key != "rain_arrived":
			_check(game.flags[key] == before.flags[key], "Travel preserves milestone " + key)
	before = _snapshot(game)
	_check(not quest_script.travel(game, "rainstep") and _snapshot(game) == before, "Repeating the same destination does not reset exploration position")
	_check(quest_script.travel(game, "wakeharbor"), "Return ferry is always available after departure")
	_check(game.island_id == "wakeharbor" and game.position.is_equal_approx(Vector3(-13, 0, 4.1)) and game.orbs == 0 and game.tonics == 0, "Returning places the player on the western pier without a fare")
	game.flags.gym = false
	before = _snapshot(game)
	_check(not quest_script.travel(game, "rainstep") and _snapshot(game) == before, "Previous arrival never bypasses the sigil gate on a later departure")
	game.island_id = "rainstep"
	_check(quest_script.travel(game, "wakeharbor"), "A starter can always return home even when the sigil is absent")


func _test_all_repair_orders() -> void:
	var orders: Array = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	for order: Array in orders:
		var game = _new_game()
		quest_script.travel(game, "rainstep")
		while game.party.size() < 6:
			game.add_creature(4, 3)
		game.orbs = 0
		game.tonics = 0
		var before: Dictionary = _snapshot(game)
		_check(quest_script.repaired_count(game) == 0 and not quest_script.complete(game), "Unvisited channels begin unrepaired")
		for index: int in range(3):
			var role: String = REPAIRS[int(order[index])]
			var reply: Dictionary = quest_script.interact(game, role)
			_check_dialogue(reply, "Water channel repair")
			_check(reply.changed and game.flags[role] and game.flags.rain_started, "A repair before meeting Orla starts the quest and records its channel")
			_check(quest_script.repaired_count(game) == index + 1 and bool(quest_script.complete(game)) == (index == 2), "Every repair order counts each unique channel once")
			var repeated: Dictionary = quest_script.interact(game, role)
			_check_dialogue(repeated, "Revisited water channel")
			_check(not repeated.changed and quest_script.repaired_count(game) == index + 1, "Repeated repairs cannot duplicate progress")
		_check(game.party == before.party and game.collection == before.collection and game.orbs == 0 and game.tonics == 0, "Full parties and empty bags cannot block the waterworks or lose companions")
		for key: String in ["starter", "rival", "captured", "gym", "cache", "tide_started", "tide_rescued", "tide_rewarded", "tide_wind", "tide_water", "tide_brass"]:
			_check(game.flags[key] == before.flags[key], "Repairs preserve existing milestone " + key)
		_check(not game.flags.rain_rewarded and str(quest_script.objective(game)).contains("RETURN TO ORLA"), "Completing the channels leaves a return visit to claim the reward")
		quest_script.interact(game, "rain_keeper")
		_check(game.flags.rain_rewarded and str(quest_script.objective(game)).contains("FLOWS AGAIN"), "Every repair order reaches the same completed objective")


func _test_keeper_recovery_and_reward() -> void:
	var game = _new_game()
	var before: Dictionary = _snapshot(game)
	var remote: Dictionary = quest_script.interact(game, "rain_keeper")
	_check(not remote.changed and _snapshot(game) == before, "Orla cannot heal or start a distant island quest from Wakeharbor")
	quest_script.travel(game, "rainstep")
	game.party[0].hp = 1
	game.orbs = 0
	game.tonics = 0
	var greeting: Dictionary = quest_script.interact(game, "rain_keeper")
	_check_dialogue(greeting, "Orla greeting")
	_check(greeting.changed and game.flags.rain_started and not game.flags.rain_rewarded, "Orla accepts the waterworks quest without granting its reward")
	_check(game.party[0].hp == game.party[0].max_hp and game.orbs == 12 and game.tonics == 5, "Orla heals and restores minimum supplies for further exploration")
	_check(str(quest_script.objective(game)).contains("0 / 3"), "The active objective displays channel progress")
	before = _snapshot(game)
	_check(not quest_script.interact(game, "rain_keeper").changed and _snapshot(game) == before, "A healthy repeated greeting causes no saved-state churn")
	game.party[0].hp = 1
	game.orbs = 1
	game.tonics = 1
	var healed: Dictionary = quest_script.interact(game, "rain_keeper")
	_check(healed.changed and game.party[0].hp == game.party[0].max_hp and game.orbs == 12 and game.tonics == 5, "Repeat healing and resupply remain available before the channels are repaired")
	for role: String in REPAIRS:
		quest_script.interact(game, role)
	var reward: Dictionary = quest_script.interact(game, "rain_keeper")
	_check_dialogue(reward, "Orla reward")
	_check(reward.changed and game.flags.rain_rewarded and game.orbs == 16 and game.tonics == 7, "The return visit grants four vessels and two tonics exactly once")
	before = _snapshot(game)
	_check(not quest_script.interact(game, "rain_keeper").changed and _snapshot(game) == before, "Repeating the completed dialogue cannot grant another reward")
	game.party[0].hp = 1
	game.orbs = 0
	game.tonics = 0
	quest_script.interact(game, "rain_keeper")
	_check(game.party[0].hp == game.party[0].max_hp and game.orbs == 12 and game.tonics == 5, "Recovery after completion restores supplies without reopening the reward")
	before = _snapshot(game)
	_check(not quest_script.interact(game, "unknown_role").changed and _snapshot(game) == before, "Unknown island roles cannot mutate progression")
	var capped = _new_game()
	quest_script.travel(capped, "rainstep")
	for role: String in REPAIRS:
		quest_script.interact(capped, role)
	capped.orbs = 998
	capped.tonics = 999
	var capped_reward: Dictionary = quest_script.interact(capped, "rain_keeper")
	_check(capped.orbs == 999 and capped.tonics == 999 and capped.flags.rain_rewarded, "Reward supply caps remain saveable and still consume the single reward")
	_check("Orla adds 1 echo vessels and 0 tonics to your bag." in capped_reward.lines, "Capped reward dialogue reports the supplies actually received")


func _test_persistence_and_legacy_defaults() -> void:
	var path: String = "user://rain_save_%d.json" % OS.get_process_id()
	var game = _new_game()
	quest_script.travel(game, "rainstep")
	quest_script.interact(game, "rain_middle")
	game.position = Vector3(62.5, 0, -3.25)
	game.play_seconds = 375.5
	_check(game.save_game(path), "Rainstep progress is saved")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(int(payload.version) == 1 and payload.island_id == "rainstep", "Island persistence remains a version-one optional extension")
	var restored = state_script.new()
	_check(restored.load_game(path) and _snapshot(restored) == _snapshot(game), "Reload preserves exact island, coordinates, and partial channel work")
	for role: String in REPAIRS:
		quest_script.interact(restored, role)
	quest_script.interact(restored, "rain_keeper")
	quest_script.travel(restored, "wakeharbor")
	restored.position = Vector3(60, 0, 8)
	restored.save_game(path)
	var at_home = state_script.new()
	_check(at_home.load_game(path) and at_home.island_id == "wakeharbor" and at_home.position == Vector3(60, 0, 8), "Island identity is never inferred from matching Rainstep coordinates")
	_check(at_home.flags.rain_rewarded and quest_script.complete(at_home), "Returning home and reloading preserves completed island work")
	payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.erase("island_id")
	for key: String in RAIN_FLAGS:
		payload.flags.erase(key)
	_write_fixture(path, payload)
	var legacy = state_script.new()
	_check(legacy.load_game(path) and legacy.island_id == "wakeharbor" and legacy.position == Vector3(60, 0, 8), "Missing optional island identity defaults to Wakeharbor regardless of coordinates")
	for key: String in RAIN_FLAGS:
		_check(legacy.flags.has(key) and not legacy.flags[key], "Old saves default the new flag to false: " + key)
	_check(legacy.flags.gym and legacy.party == at_home.party and legacy.collection == at_home.collection, "Legacy loading preserves the existing chapter and journal")
	_cleanup(path)


func _test_invalid_saves_are_transactional() -> void:
	var path: String = "user://rain_invalid_%d.json" % OS.get_process_id()
	var game = _new_game()
	quest_script.travel(game, "rainstep")
	quest_script.interact(game, "rain_keeper")
	game.save_game(path)
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var before: Dictionary = _snapshot(game)
	for bad_id: Variant in ["", "unknown", "Rainstep", 1, true, null, ["rainstep"]]:
		var bad: Dictionary = valid.duplicate(true)
		bad.island_id = bad_id
		_reject_fixture(game, path, bad, before, "Invalid island IDs are rejected transactionally")
	for key: String in RAIN_FLAGS:
		var mistyped: Dictionary = valid.duplicate(true)
		mistyped.flags[key] = "true"
		_reject_fixture(game, path, mistyped, before, "Mistyped rain flag is rejected: " + key)
	var unearned = _new_game(false)
	unearned.save_game(path)
	var early: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var island_before_trial: Dictionary = early.duplicate(true)
	island_before_trial.island_id = "rainstep"
	_reject_fixture(game, path, island_before_trial, before, "Rainstep presence requires the completed trial")
	for key: String in RAIN_FLAGS:
		var premature: Dictionary = early.duplicate(true)
		premature.flags[key] = true
		_reject_fixture(game, path, premature, before, "Rainstep milestones require the completed trial: " + key)
	for key: String in REPAIRS:
		var repair_without_quest: Dictionary = valid.duplicate(true)
		repair_without_quest.flags.rain_started = false
		repair_without_quest.flags[key] = true
		_reject_fixture(game, path, repair_without_quest, before, "A recorded repair requires the waterworks quest: " + key)
	for omitted: String in REPAIRS:
		var incomplete_reward: Dictionary = valid.duplicate(true)
		for key: String in REPAIRS:
			incomplete_reward.flags[key] = key != omitted
		incomplete_reward.flags.rain_rewarded = true
		_reject_fixture(game, path, incomplete_reward, before, "Reward requires every channel, including " + omitted)
	var reward_without_start: Dictionary = valid.duplicate(true)
	for key: String in REPAIRS:
		reward_without_start.flags[key] = true
	reward_without_start.flags.rain_started = false
	reward_without_start.flags.rain_rewarded = true
	_reject_fixture(game, path, reward_without_start, before, "Reward cannot bypass the started flag")
	_cleanup(path)


func _test_rain_arrival_chain_is_transactional() -> void:
	var path: String = "user://rain_arrival_chain_%d.json" % OS.get_process_id()
	var source = _new_game()
	quest_script.travel(source, "rainstep")
	source.save_game(path)
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for island: String in ["rainstep", "wakeharbor"]:
		for progress: String in ["none", "rain_started", "rain_upper", "rain_middle", "rain_lower", "rain_rewarded"]:
			if island == "wakeharbor" and progress == "none":
				continue
			for erase_arrival: bool in [false, true]:
				var broken_chain: Dictionary = valid.duplicate(true)
				broken_chain.island_id = island
				if progress != "none":
					broken_chain.flags.rain_started = true
					broken_chain.flags[progress] = true
				if progress == "rain_rewarded":
					for repair: String in REPAIRS:
						broken_chain.flags[repair] = true
				if erase_arrival:
					broken_chain.flags.erase("rain_arrived")
				else:
					broken_chain.flags.rain_arrived = false
				var recipient = _new_game()
				_reject_fixture(recipient, path, broken_chain, _snapshot(recipient), "Rainstep presence or progress requires a recorded arrival: %s / %s / erased=%s" % [island, progress, erase_arrival])
		for progress: String in RAIN_FLAGS:
			var empty_team: Dictionary = valid.duplicate(true)
			empty_team.island_id = island
			empty_team.flags.starter = false
			empty_team.party = []
			empty_team.collection = []
			empty_team.flags[progress] = true
			if progress != "rain_arrived":
				empty_team.flags.rain_started = true
			if progress == "rain_rewarded":
				for repair: String in REPAIRS:
					empty_team.flags[repair] = true
			var recipient = _new_game()
			_reject_fixture(recipient, path, empty_team, _snapshot(recipient), "Rainstep milestones require a starter party even with a forged sigil: " + island + " / " + progress)
	_cleanup(path)


func _test_local_defeat_and_reload_recovery() -> void:
	var path: String = "user://rain_recovery_%d.json" % OS.get_process_id()
	for island: String in ["wakeharbor", "rainstep"]:
		var game = _new_game()
		if island == "rainstep":
			quest_script.travel(game, island)
			quest_script.interact(game, "rain_upper")
		game.position = Vector3(68, 0, -8)
		game.party[0].hp = 1
		game.orbs = 0
		game.tonics = 0
		var flags_before: Dictionary = game.flags.duplicate()
		var battle = battle_script.new()
		var opponents: Array[Dictionary] = [db.make_creature(6, 12)]
		battle.begin(game, "wild", opponents, 41)
		battle.act("strike")
		var landing: Vector3 = Vector3(60, 0, 8) if island == "rainstep" else Vector3(-7, 0, 5)
		_check(battle.finished and battle.outcome == "lost" and game.island_id == island and game.position == landing, "Defeat recovers on the current island: " + island)
		_check(game.party[0].hp == game.party[0].max_hp and game.orbs >= 3 and game.tonics >= 2 and game.flags == flags_before, "Local defeat heals and preserves completed progress")
		var expected_log: String = "Your companions need rest. Orla brings you to the landing." if island == "rainstep" else "Your companions need rest. The Keeper brings you home."
		_check(expected_log in battle.log, "Defeat names the local recovery caretaker")
		game.party[0].hp = 0
		game.position = Vector3(67, 0, -6)
		game.save_game(path)
		var restored = state_script.new()
		_check(restored.load_game(path) and restored.island_id == island and restored.position == landing and restored.party[0].hp == restored.party[0].max_hp, "Loading a defeated party uses the saved island's recovery point")
		_check(restored.flags == flags_before, "Defeated-save recovery preserves island milestones")
	_cleanup(path)


func _test_regional_encounters() -> void:
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 32791
	second.seed = 32791
	var species: Array[int] = encounter_script.species_for("rainstep")
	for id: int in [1, 2, 5, 6, 7]:
		_check(species.has(id), "Rainstep uses the established species " + str(id))
	for id: int in species:
		_check([1, 2, 5, 6, 7].has(id), "The Rainstep table excludes unrelated meadow species")
	var seen: Dictionary = {}
	var lowest: int = 99
	var highest: int = 0
	for unused: int in range(180):
		var encounter: Dictionary = encounter_script.roll("rainstep", first, false, false)
		_check(encounter == encounter_script.roll("rainstep", second, false, false), "Seeded Rainstep encounters are deterministic")
		_check([1, 2, 5, 6, 7].has(int(encounter.id)) and int(encounter.level) >= 5 and int(encounter.level) <= 7, "Rainstep encounters stay within existing species and levels five to seven")
		seen[int(encounter.id)] = true
		lowest = mini(lowest, int(encounter.level))
		highest = maxi(highest, int(encounter.level))
	_check(seen.size() == 5 and lowest == 5 and highest == 7, "A fixed Rainstep route reaches every species and both level bounds")
	for region: String in ["rainstep", "meadow", "tidepools", "unknown"]:
		_check(encounter_script.roll(region, first, true, true) == {"id": 3, "level": 3}, "First-catch teaching is unchanged in " + region)
	first.seed = 879
	second.seed = 879
	for unused: int in range(40):
		_check(encounter_script.roll("rainstep", first, false, false) == encounter_script.roll("rainstep", second, false, true), "Rainstep's level range is independent of the meadow postgame modifier")


func _reject_fixture(game, path: String, payload: Dictionary, before: Dictionary, message: String) -> void:
	_write_fixture(path, payload)
	_check(not game.load_game(path) and _snapshot(game) == before, message)


func _write_fixture(path: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()


func _cleanup(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
