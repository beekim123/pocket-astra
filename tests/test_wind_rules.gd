extends SceneTree
## Windchart travel, clue orders, safe routes, rewards, and transactional saves.

const WIND_FLAGS: Array[String] = ["wind_arrived", "wind_wind", "wind_tide", "wind_light", "wind_sailed", "wind_rewarded"]
const MARKERS: Array[String] = ["wind_wind", "wind_tide", "wind_light"]

var state_script: Script
var quest_script: Script
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_check(ResourceLoader.exists("res://scripts/wind_quest.gd"), "Windchart travel and navigation implementation exists")
	if failures > 0:
		_finish()
		return
	state_script = load("res://scripts/game_state.gd")
	quest_script = load("res://scripts/wind_quest.gd")
	_test_travel_gates_and_cost()
	_test_all_clue_orders_and_routes()
	_test_keeper_and_reward()
	_test_persistence_and_legacy_defaults()
	_test_invalid_saves_are_transactional()
	_test_berth_coordinates_require_sailing()
	_test_local_reload_recovery()
	_finish()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _finish() -> void:
	print("WIND RULES TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _new_game(completed_trial: bool = true):
	var game = state_script.new()
	game.choose_starter(1)
	for flag: String in ["captured", "rival", "gym", "rain_arrived", "rain_started", "rain_upper", "rain_middle", "rain_lower", "rain_rewarded", "rain_trial"]:
		game.flags[flag] = true
	game.flags.rain_gym = completed_trial
	game.island_id = "rainstep"
	game.position = Vector3(64, 0, 7)
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
	var empty = _new_game()
	empty.party.clear()
	var empty_at_quay = _new_game()
	empty_at_quay.party.clear()
	empty_at_quay.island_id = "windchart"
	empty_at_quay.flags.wind_arrived = true
	for locked in [fresh, early, empty, empty_at_quay]:
		var before: Dictionary = _snapshot(locked)
		_check(not quest_script.travel(locked, "windchart") and _snapshot(locked) == before, "Windchart departure requires the second trial and a companion")
		_check(not quest_script.return_to_quay(locked) and _snapshot(locked) == before, "Locked return travel cannot teleport to the quay")
		for role: String in ["wind_keeper", "wind_wind", "wind_tide", "wind_light", "wind_chart", "wind_berth"]:
			var reply: Dictionary = quest_script.interact(locked, role)
			_check_dialogue(reply, "Locked Windchart interaction")
			_check(not reply.changed and _snapshot(locked) == before, "Locked interactions cannot mutate the journey")
		for route: String in ["north", "east", "south"]:
			var reply: Dictionary = quest_script.choose_route(locked, route)
			_check_dialogue(reply, "Locked Windchart route")
			_check(not reply.changed and _snapshot(locked) == before, "Locked navigation cannot mutate the journey")
	_check(str(quest_script.objective(fresh)).is_empty() and str(quest_script.objective(early)).is_empty(), "Windchart objective waits for the second trial")
	var game = _new_game()
	game.orbs = 0
	game.tonics = 0
	var before: Dictionary = _snapshot(game)
	_check(not str(quest_script.objective(game)).is_empty(), "The second trial points toward the Windchart ship")
	for destination: String in ["", "unknown", "Windchart", "wakeharbor", "rainstep"]:
		_check(not quest_script.travel(game, destination) and _snapshot(game) == before, "Unsupported and same-island destinations do not teleport")
	game.island_id = "wakeharbor"
	before = _snapshot(game)
	_check(not quest_script.travel(game, "windchart") and _snapshot(game) == before, "Windchart is reached through Rainstep rather than bypassing the ferry chain")
	game.island_id = "rainstep"
	before = _snapshot(game)
	_check(quest_script.travel(game, "windchart"), "A completed second trial unlocks Windchart with an empty bag")
	_check(game.island_id == "windchart" and game.position == Vector3(120, 0, 8), "Windchart arrival uses the main quay safe point")
	_check(game.flags.wind_arrived and not game.flags.wind_sailed and game.orbs == 0 and game.tonics == 0, "Arrival records its milestone without supplies or route completion")
	for flag: String in before.flags:
		if flag != "wind_arrived":
			_check(game.flags[flag] == before.flags[flag], "Outward travel preserves milestone " + flag)
	before = _snapshot(game)
	_check(not quest_script.travel(game, "windchart") and _snapshot(game) == before, "A repeated outward request does not reset position")
	_check(quest_script.travel(game, "rainstep"), "The return ship works before any navigation clues")
	_check(game.island_id == "rainstep" and game.position == Vector3(64, 0, 7) and game.orbs == 0 and game.tonics == 0, "Return travel reaches the Rainstep ship without a fare")
	game.flags.rain_gym = false
	before = _snapshot(game)
	_check(not quest_script.travel(game, "windchart") and _snapshot(game) == before, "An earlier arrival cannot bypass the second trial on a later departure")
	game.island_id = "windchart"
	_check(quest_script.travel(game, "rainstep"), "A party can return to Rainstep even if its second sigil is absent")


func _test_all_clue_orders_and_routes() -> void:
	var orders: Array = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	for order: Array in orders:
		var game = _new_game()
		quest_script.travel(game, "windchart")
		while game.party.size() < 6:
			game.add_creature(4, 3)
		game.orbs = 0
		game.tonics = 0
		var before: Dictionary = _snapshot(game)
		_check(quest_script.marker_count(game) == 0 and not quest_script.can_sail(game), "Unobserved markers cannot unlock sailing")
		_check(not quest_script.return_to_quay(game) and _snapshot(game) == before, "The berth return requires a completed outward route")
		var premature: Dictionary = quest_script.interact(game, "wind_berth")
		_check(not premature.changed and _snapshot(game) == before, "The berth reward cannot be claimed before sailing")
		for index: int in range(3):
			var waiting: Dictionary = _snapshot(game)
			var blocked: Dictionary = quest_script.choose_route(game, "south")
			_check_dialogue(blocked, "Incomplete navigation chart")
			_check(not blocked.changed and _snapshot(game) == waiting, "Every incomplete clue count refuses even the correct route")
			var role: String = MARKERS[int(order[index])]
			var reply: Dictionary = quest_script.interact(game, role)
			_check_dialogue(reply, "Navigation marker")
			_check(reply.changed and game.flags[role], "Observation records its unique clue")
			_check(quest_script.marker_count(game) == index + 1 and bool(quest_script.can_sail(game)) == (index == 2), "All six observation orders require exactly three different clues")
			waiting = _snapshot(game)
			var repeated: Dictionary = quest_script.interact(game, role)
			_check_dialogue(repeated, "Revisited navigation marker")
			_check(not repeated.changed and _snapshot(game) == waiting, "Revisiting a marker is readable without duplicate progress")
		_check(game.party == before.party and game.collection == before.collection and game.orbs == 0 and game.tonics == 0, "A full team and empty bag can complete all observations without loss")
		for flag: String in before.flags:
			if flag not in MARKERS:
				_check(game.flags[flag] == before.flags[flag], "Observation preserves unrelated milestone " + flag)
		for route: String in ["north", "east", "north", "east", "unknown", "South", ""]:
			var waiting: Dictionary = _snapshot(game)
			var rejected: Dictionary = quest_script.choose_route(game, route)
			_check_dialogue(rejected, "Rejected navigation route")
			_check(not rejected.changed and _snapshot(game) == waiting, "Wrong or invalid routes remain free and immediately retryable")
		var sailed: Dictionary = quest_script.choose_route(game, "south")
		_check_dialogue(sailed, "Safe navigation route")
		_check(sailed.changed and game.flags.wind_sailed and game.position == Vector3(140, 0, 2) and game.island_id == "windchart", "The southern lee reaches the separate berth")
		_check(not game.flags.wind_rewarded and game.orbs == 0 and game.tonics == 0 and game.party == before.party, "Safe sailing preserves companions and leaves the reward for the local visit")
		var at_berth: Dictionary = _snapshot(game)
		_check(not quest_script.choose_route(game, "south").changed and _snapshot(game) == at_berth, "Repeating the same crossing at the berth does not churn saved state")
		_check(quest_script.return_to_quay(game) and game.position == Vector3(120, 0, 8) and game.flags.wind_sailed, "The free berth boat returns to the quay without losing navigation progress")
		_check(quest_script.choose_route(game, "south").changed and game.position == Vector3(140, 0, 2), "A return to the quay permits another safe crossing")
		var reward: Dictionary = quest_script.interact(game, "wind_berth")
		_check(reward.changed and game.flags.wind_rewarded and game.orbs == 4 and game.tonics == 2, "Every observation order reaches the same one-time berth reward")
		_check(not str(quest_script.objective(game)).is_empty(), "Completed navigation keeps a useful visible objective")


func _test_keeper_and_reward() -> void:
	var game = _new_game()
	quest_script.travel(game, "windchart")
	game.party[0].hp = 1
	game.orbs = 0
	game.tonics = 0
	var flags_before: Dictionary = game.flags.duplicate()
	var healed: Dictionary = quest_script.interact(game, "wind_keeper")
	_check_dialogue(healed, "Quay keeper healing")
	_check(healed.changed and game.party[0].hp == game.party[0].max_hp, "The quay keeper freely heals the current party")
	_check(game.flags == flags_before and game.orbs == 12 and game.tonics == 5, "The quay keeper restores minimum supplies without skipping observations")
	var before: Dictionary = _snapshot(game)
	_check(not quest_script.interact(game, "wind_keeper").changed and _snapshot(game) == before, "A healthy repeat keeper visit does not churn saved state")
	for role: String in ["wind_chart", "unknown_role"]:
		var reply: Dictionary = quest_script.interact(game, role)
		_check_dialogue(reply, "Informational Windchart interaction")
		_check(not reply.changed and _snapshot(game) == before, "Hints and unknown roles cannot grant progress")
	for marker: String in MARKERS:
		quest_script.interact(game, marker)
	quest_script.choose_route(game, "south")
	game.orbs = 998
	game.tonics = 999
	var reward: Dictionary = quest_script.interact(game, "wind_berth")
	_check_dialogue(reward, "Capped berth reward")
	_check(reward.changed and game.flags.wind_rewarded and game.orbs == 999 and game.tonics == 999, "The one-time reward obeys both inventory caps")
	_check("Sela adds 1 echo vessels and 0 tonics to your bag." in reward.lines, "Reward dialogue reports the actual capped supply amounts")
	before = _snapshot(game)
	var repeated: Dictionary = quest_script.interact(game, "wind_berth")
	_check_dialogue(repeated, "Completed berth story")
	_check(not repeated.changed and _snapshot(game) == before, "Repeating the berth story cannot duplicate its reward")
	quest_script.return_to_quay(game)
	quest_script.travel(game, "rainstep")
	before = _snapshot(game)
	_check(not quest_script.return_to_quay(game) and _snapshot(game) == before, "Recorded sailing cannot enable a remote return teleport")
	_check(not quest_script.can_sail(game), "A complete chart cannot sail from another island")
	_check(not quest_script.interact(game, "wind_berth").changed and _snapshot(game) == before, "A remote berth interaction cannot change completion")


func _test_persistence_and_legacy_defaults() -> void:
	var path: String = "user://wind_save_%d.json" % OS.get_process_id()
	var game = _new_game()
	quest_script.travel(game, "windchart")
	quest_script.interact(game, "wind_tide")
	game.position = Vector3(117.5, 0, -3.25)
	game.play_seconds = 812.5
	for stage: String in ["partial", "sailed", "rewarded", "returned"]:
		if stage == "sailed":
			quest_script.interact(game, "wind_wind")
			quest_script.interact(game, "wind_light")
			quest_script.choose_route(game, "south")
		elif stage == "rewarded":
			quest_script.interact(game, "wind_berth")
		elif stage == "returned":
			quest_script.return_to_quay(game)
			quest_script.travel(game, "rainstep")
		_check(game.save_game(path), "Windchart progress saves at stage " + stage)
		var restored = state_script.new()
		_check(restored.load_game(path) and _snapshot(restored) == _snapshot(game), "Reload preserves exact island, position and progress at stage " + stage)
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		_check(int(payload.version) == 1, "Windchart remains a version-one compatible extension")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for flag: String in WIND_FLAGS:
		payload.flags.erase(flag)
	_write_fixture(path, payload)
	var legacy = state_script.new()
	_check(legacy.load_game(path), "Version-one saves before Windchart remain readable")
	for flag: String in WIND_FLAGS:
		_check(legacy.flags.has(flag) and not legacy.flags[flag], "Legacy saves default the new milestone to false: " + flag)
	_check(legacy.party == game.party and legacy.collection == game.collection and legacy.flags.rain_gym and legacy.position == game.position, "Legacy migration preserves companions, second trial, and position")
	_cleanup(path)


func _test_invalid_saves_are_transactional() -> void:
	var path: String = "user://wind_invalid_%d.json" % OS.get_process_id()
	var game = _new_game()
	quest_script.travel(game, "windchart")
	for marker: String in MARKERS:
		quest_script.interact(game, marker)
	quest_script.choose_route(game, "south")
	quest_script.interact(game, "wind_berth")
	game.save_game(path)
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var before: Dictionary = _snapshot(game)
	for flag: String in WIND_FLAGS:
		var mistyped: Dictionary = valid.duplicate(true)
		mistyped.flags[flag] = "true"
		_reject_fixture(game, path, mistyped, before, "Mistyped Windchart flags are rejected transactionally: " + flag)
	for island: String in ["windchart", "rainstep", "wakeharbor"]:
		var no_sigil: Dictionary = valid.duplicate(true)
		no_sigil.island_id = island
		no_sigil.flags.rain_gym = false
		_reject_fixture(game, path, no_sigil, before, "Windchart progress requires the second trial even after leaving: " + island)
		for flag: String in WIND_FLAGS:
			var early: Dictionary = valid.duplicate(true)
			early.island_id = island
			for reset: String in WIND_FLAGS:
				early.flags[reset] = reset == flag
			early.flags.rain_gym = false
			_reject_fixture(game, path, early, before, "Every Windchart milestone requires the second trial: " + island + " / " + flag)
		for erased: bool in [false, true]:
			var missing_arrival: Dictionary = valid.duplicate(true)
			missing_arrival.island_id = island
			if erased:
				missing_arrival.flags.erase("wind_arrived")
			else:
				missing_arrival.flags.wind_arrived = false
			_reject_fixture(game, path, missing_arrival, before, "Windchart progress requires an explicit arrival: " + island)
		var empty_party: Dictionary = valid.duplicate(true)
		empty_party.island_id = island
		empty_party.party = []
		empty_party.collection = []
		empty_party.flags.starter = false
		_reject_fixture(game, path, empty_party, before, "Windchart cannot be loaded with a forged sigil and empty party: " + island)
	for missing: String in MARKERS:
		var incomplete: Dictionary = valid.duplicate(true)
		incomplete.flags[missing] = false
		_reject_fixture(game, path, incomplete, before, "Sailing requires every navigation clue: " + missing)
	var unsailed: Dictionary = valid.duplicate(true)
	unsailed.flags.wind_sailed = false
	_reject_fixture(game, path, unsailed, before, "The berth reward requires a successful crossing")
	var unvisited: Dictionary = valid.duplicate(true)
	for flag: String in WIND_FLAGS:
		unvisited.flags[flag] = false
	_reject_fixture(game, path, unvisited, before, "Windchart island presence requires its arrival milestone")
	for marker: String in MARKERS:
		var clue_without_arrival: Dictionary = unvisited.duplicate(true)
		clue_without_arrival.island_id = "rainstep"
		clue_without_arrival.flags[marker] = true
		_reject_fixture(game, path, clue_without_arrival, before, "Individual clues cannot bypass the arrival chain: " + marker)
	_cleanup(path)


func _test_berth_coordinates_require_sailing() -> void:
	var path: String = "user://wind_berth_boundary_%d.json" % OS.get_process_id()
	for berth_position: Vector3 in [Vector3(140, 0, 2), Vector3(136, 0, -5), Vector3(143.9, 0, 4.9)]:
		var game = _new_game()
		quest_script.travel(game, "windchart")
		game.save_game(path)
		var before: Dictionary = _snapshot(game)
		var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		payload.position = [berth_position.x, berth_position.y, berth_position.z]
		_reject_fixture(game, path, payload, before, "A healthy party cannot load inside the berth before sailing: " + str(berth_position))
	# Coordinates alone do not identify a region in legacy saves.
	for island: String in ["rainstep", "wakeharbor"]:
		var game = _new_game()
		game.island_id = island
		game.position = Vector3(140, 0, 2)
		game.save_game(path)
		var restored = state_script.new()
		_check(restored.load_game(path) and _snapshot(restored) == _snapshot(game), "Windchart berth validation does not reinterpret another island's coordinates: " + island)
	_cleanup(path)


func _test_local_reload_recovery() -> void:
	var path: String = "user://wind_recovery_%d.json" % OS.get_process_id()
	for sailed: bool in [false, true]:
		var game = _new_game()
		quest_script.travel(game, "windchart")
		quest_script.interact(game, "wind_wind")
		if sailed:
			quest_script.interact(game, "wind_tide")
			quest_script.interact(game, "wind_light")
			quest_script.choose_route(game, "south")
			quest_script.interact(game, "wind_berth")
		game.party[0].hp = 0
		game.orbs = 0
		game.tonics = 0
		game.position = Vector3(141, 0, -2) if sailed else Vector3(118, 0, -2)
		var flags_before: Dictionary = game.flags.duplicate()
		game.save_game(path)
		var restored = state_script.new()
		_check(restored.load_game(path) and restored.island_id == "windchart" and restored.position == Vector3(120, 0, 8), "A defeated save recovers at the local main quay regardless of crossing progress")
		_check(restored.party[0].hp == restored.party[0].max_hp and restored.flags == flags_before and restored.orbs == 0 and restored.tonics == 0, "Local reload recovery heals without changing progress or empty supplies")
	_cleanup(path)


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
