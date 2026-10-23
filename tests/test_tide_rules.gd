extends SceneTree
## Tide rescue, optional observations, save compatibility, and region encounters.

const TIDE_FLAGS: Array[String] = ["tide_started", "tide_rescued", "tide_rewarded", "tide_wind", "tide_water", "tide_brass"]
const MARKERS: Array[String] = ["tide_wind", "tide_water", "tide_brass"]

var state_script: Script
var quest_script: Script
var encounter_script: Script
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	for path: String in ["res://scripts/tide_quest.gd", "res://scripts/encounter_tables.gd"]:
		_check(ResourceLoader.exists(path), "Tide rules implementation exists: " + path)
	if failures > 0:
		_finish()
		return
	state_script = load("res://scripts/game_state.gd")
	quest_script = load("res://scripts/tide_quest.gd")
	encounter_script = load("res://scripts/encounter_tables.gd")
	_test_rescue_and_single_reward()
	_test_rescue_before_giver_and_full_party()
	_test_all_marker_orders()
	_test_persistence_and_old_saves()
	_test_invalid_flags_are_transactional()
	_test_encounter_regions()
	_finish()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _finish() -> void:
	print("TIDE RULES TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _new_game():
	var game = state_script.new()
	game.choose_starter(1)
	return game


func _snapshot(game) -> Dictionary:
	return {"party": game.party.duplicate(true), "collection": game.collection.duplicate(), "flags": game.flags.duplicate(), "orbs": game.orbs, "tonics": game.tonics, "position": game.position, "play_seconds": game.play_seconds}


func _check_dialogue(reply: Dictionary, message: String) -> void:
	_check(reply.has_all(["speaker", "lines", "changed", "sound"]), message + " exposes a complete dialogue result")
	if not reply.has_all(["speaker", "lines", "changed", "sound"]):
		return
	_check(reply.speaker is String and reply.lines is Array and reply.changed is bool and reply.sound is String, message + " uses stable result types")
	_check(not str(reply.speaker).is_empty() and not reply.lines.is_empty(), message + " gives visible feedback")
	for line: Variant in reply.lines:
		_check(line is String and not str(line).is_empty(), message + " has readable lines")


func _test_rescue_and_single_reward() -> void:
	var unready = state_script.new()
	var unready_before: Dictionary = _snapshot(unready)
	_check(str(quest_script.objective(unready)).is_empty(), "No sidequest objective appears before choosing a companion")
	for role: String in ["tide_artisan", "tide_rescue", "tide_wind", "tide_water", "tide_brass"]:
		var locked: Dictionary = quest_script.interact(unready, role)
		_check_dialogue(locked, "Pre-starter interaction")
		_check(not bool(locked.changed) and _snapshot(unready) == unready_before, "Pre-starter interactions cannot create incoherent quest progress")
	var game = _new_game()
	var main_quest: String = game.quest()
	var initial_party: Array = game.party.duplicate(true)
	var initial_collection: Array = game.collection.duplicate()
	var first: Dictionary = quest_script.interact(game, "tide_artisan")
	_check_dialogue(first, "Quest invitation")
	_check(bool(first.changed) and bool(game.flags.tide_started) and not bool(game.flags.tide_rescued), "Tavi starts the rescue without completing it")
	_check(not bool(quest_script.interact(game, "tide_artisan").changed), "Repeating the invitation does not claim a reward")
	var inventory_before: Vector2i = Vector2i(game.orbs, game.tonics)
	var rescue: Dictionary = quest_script.interact(game, "tide_rescue")
	_check_dialogue(rescue, "Rescue")
	_check(bool(rescue.changed) and bool(game.flags.tide_rescued) and not bool(game.flags.tide_rewarded), "Rescue records success and leaves the return reward unclaimed")
	_check(Vector2i(game.orbs, game.tonics) == inventory_before, "Helping the stranded Wispip consumes no supplies")
	_check(str(quest_script.objective(game)).contains("RETURN"), "After rescue the objective sends the player back to Tavi")
	_check(not bool(quest_script.interact(game, "tide_rescue").changed), "Repeated rescue cannot generate more progress")
	var reward: Dictionary = quest_script.interact(game, "tide_artisan")
	_check_dialogue(reward, "Return reward")
	_check(bool(reward.changed) and bool(game.flags.tide_rewarded), "Returning to Tavi records the single reward")
	_check(game.orbs == inventory_before.x + 4 and game.tonics == inventory_before.y + 2, "Tavi gives four orbs and two tonics")
	_check(not bool(quest_script.interact(game, "tide_artisan").changed), "Tavi cannot give the reward twice")
	_check(game.orbs == inventory_before.x + 4 and game.tonics == inventory_before.y + 2, "Repeat dialogue preserves the claimed inventory")
	_check(game.party == initial_party and game.collection == initial_collection, "Rescue does not capture or modify companions")
	_check(game.quest() == main_quest and not game.flags.captured and not game.flags.rival and not game.flags.gym, "The optional rescue leaves first-chapter objectives and battle milestones intact")
	var unchanged: Dictionary = _snapshot(game)
	var unknown: Dictionary = quest_script.interact(game, "unknown_role")
	_check(not bool(unknown.changed) and _snapshot(game) == unchanged, "Unknown roles cannot mutate the journey")


func _test_rescue_before_giver_and_full_party() -> void:
	var game = _new_game()
	while game.party.size() < 6:
		game.add_creature(4, 3)
	game.orbs = 0
	game.tonics = 0
	var party_before: Array = game.party.duplicate(true)
	quest_script.interact(game, "tide_rescue")
	_check(game.flags.tide_started and game.flags.tide_rescued, "Finding Wispip first accepts and resolves the rescue")
	_check(game.party == party_before and game.orbs == 0 and game.tonics == 0, "A full party and empty bag cannot block rescue")
	quest_script.interact(game, "tide_artisan")
	_check(game.flags.tide_rewarded and game.orbs == 4 and game.tonics == 2, "Rescue-first route can claim the same return reward")
	var capped = _new_game()
	capped.orbs = 998
	capped.tonics = 999
	quest_script.interact(capped, "tide_rescue")
	quest_script.interact(capped, "tide_artisan")
	_check(capped.orbs == 999 and capped.tonics == 999 and capped.flags.tide_rewarded, "Capped supplies still consume the reward exactly once")


func _test_all_marker_orders() -> void:
	var orders: Array = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	for order: Array in orders:
		var game = _new_game()
		var before: Dictionary = _snapshot(game)
		_check(quest_script.marker_count(game) == 0 and not quest_script.complete(game), "A new journal has no shore observations")
		for index: int in range(3):
			var role: String = MARKERS[int(order[index])]
			var reply: Dictionary = quest_script.interact(game, role)
			_check_dialogue(reply, "Shore marker")
			_check(reply.changed and game.flags[role], "Each first marker visit records its own observation")
			_check(quest_script.marker_count(game) == index + 1, "Any marker order advances the observation count once")
			_check(bool(quest_script.complete(game)) == (index == 2), "Song completion requires all three unique observations")
			if index == 2:
				_check(reply.lines.size() >= 3, "The third distinct marker gives the complete song's short story")
			var repeat_reply: Dictionary = quest_script.interact(game, role)
			_check_dialogue(repeat_reply, "Repeated shore marker")
			_check(not repeat_reply.changed and quest_script.marker_count(game) == index + 1, "Repeating a marker gives feedback without duplicate progress")
		_check(not game.flags.tide_started and not game.flags.tide_rescued and not game.flags.tide_rewarded, "All observations may precede accepting the rescue")
		_check(game.party == before.party and game.collection == before.collection and game.orbs == before.orbs and game.tonics == before.tonics, "Completing the song gives no combat or inventory power")
		for flag: String in ["starter", "captured", "rival", "gym", "cache"]:
			_check(game.flags[flag] == before.flags[flag], "Observation order leaves original milestone unchanged: " + flag)
		quest_script.interact(game, "tide_rescue")
		quest_script.interact(game, "tide_artisan")
		_check(str(quest_script.objective(game)).contains("COMPLETE"), "A completed rescue and all observations produce a completed sidequest objective")


func _test_persistence_and_old_saves() -> void:
	var path: String = "user://tide_save_%d.json" % OS.get_process_id()
	var early_observer = _new_game()
	quest_script.interact(early_observer, "tide_wind")
	_check(early_observer.save_game(path), "An observation before the rescue invitation can be saved")
	var early_restored = state_script.new()
	_check(early_restored.load_game(path) and early_restored.flags.tide_wind and not early_restored.flags.tide_started, "Loading accepts independent observations before the rescue begins")
	var game = _new_game()
	game.flags.captured = true
	game.flags.rival = true
	game.flags.gym = true
	game.flags.cache = true
	quest_script.interact(game, "tide_artisan")
	quest_script.interact(game, "tide_water")
	_check(game.save_game(path), "Mid-rescue save is written")
	var restored = state_script.new()
	_check(restored.load_game(path) and _snapshot(restored) == _snapshot(game), "Reload preserves a started rescue and one observation")
	quest_script.interact(restored, "tide_rescue")
	_check(restored.save_game(path), "Unclaimed rescue reward can be saved")
	var rescued = state_script.new()
	_check(rescued.load_game(path) and rescued.flags.tide_rescued and not rescued.flags.tide_rewarded, "Reload preserves rescued but unclaimed progress")
	quest_script.interact(rescued, "tide_artisan")
	quest_script.interact(rescued, "tide_wind")
	quest_script.interact(rescued, "tide_brass")
	_check(rescued.save_game(path), "Complete sidequest can be saved")
	var finished = state_script.new()
	_check(finished.load_game(path) and finished.flags.tide_rewarded and quest_script.complete(finished), "Reload keeps the reward claimed and song complete")
	var finished_before: Dictionary = _snapshot(finished)
	quest_script.interact(finished, "tide_artisan")
	for role: String in MARKERS:
		quest_script.interact(finished, role)
	_check(_snapshot(finished) == finished_before, "Reload cannot reopen any one-time reward or observation")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key: String in TIDE_FLAGS:
		payload.flags.erase(key)
	_write_fixture(path, payload)
	var old_save = state_script.new()
	_check(old_save.load_game(path), "Version-one files without tide fields remain loadable")
	for key: String in TIDE_FLAGS:
		_check(old_save.flags.has(key) and not old_save.flags[key], "Missing tide fields default to false: " + key)
	_check(old_save.flags.captured and old_save.flags.rival and old_save.flags.gym and old_save.flags.cache and old_save.party == finished.party, "Legacy loading preserves original milestones and companions")
	_cleanup(path)


func _test_invalid_flags_are_transactional() -> void:
	var path: String = "user://tide_invalid_%d.json" % OS.get_process_id()
	var game = _new_game()
	quest_script.interact(game, "tide_artisan")
	quest_script.interact(game, "tide_water")
	game.save_game(path)
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var before: Dictionary = _snapshot(game)
	for key: String in TIDE_FLAGS:
		var mistyped: Dictionary = valid.duplicate(true)
		mistyped.flags[key] = "true"
		_write_fixture(path, mistyped)
		_check(not game.load_game(path) and _snapshot(game) == before, "Mistyped tide flag is rejected transactionally: " + key)
	var impossible_reward: Dictionary = valid.duplicate(true)
	impossible_reward.flags.tide_rewarded = true
	_write_fixture(path, impossible_reward)
	_check(not game.load_game(path) and _snapshot(game) == before, "A reward without rescue is rejected without changing the active journey")
	var impossible_rescue: Dictionary = valid.duplicate(true)
	impossible_rescue.flags.tide_started = false
	impossible_rescue.flags.tide_rescued = true
	_write_fixture(path, impossible_rescue)
	_check(not game.load_game(path) and _snapshot(game) == before, "A rescue without an accepted quest is rejected transactionally")
	var fresh = state_script.new()
	fresh.save_game(path)
	var fresh_payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for key: String in TIDE_FLAGS:
		var premature: Dictionary = fresh_payload.duplicate(true)
		premature.flags[key] = true
		_write_fixture(path, premature)
		_check(not game.load_game(path) and _snapshot(game) == before, "Quest progress before starter selection is rejected: " + key)
	_cleanup(path)


func _test_encounter_regions() -> void:
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 7925
	second.seed = 7925
	var shore_species: Array[int] = encounter_script.species_for("tidepools")
	_check(shore_species.has(1) and shore_species.has(4) and shore_species.has(3), "The shore contains Brookfin, Pebblit, and Wispip")
	for id: int in shore_species:
		_check([1, 4, 3].has(id), "Shore encounters contain only shore species")
	var seen: Dictionary = {}
	var lowest: int = 99
	var highest: int = 0
	for unused: int in range(180):
		var encounter: Dictionary = encounter_script.roll("tidepools", first, false, false)
		_check(encounter == encounter_script.roll("tidepools", second, false, false), "Seeded shore encounters are deterministic")
		_check(encounter.has_all(["id", "level"]) and [1, 4, 3].has(int(encounter.id)) and int(encounter.level) >= 2 and int(encounter.level) <= 4, "Shore encounters stay inside the gentle region bounds")
		seen[int(encounter.id)] = true
		lowest = mini(lowest, int(encounter.level))
		highest = maxi(highest, int(encounter.level))
	_check(seen.size() == 3 and lowest == 2 and highest == 4, "A fixed shore sequence reaches each species and both level bounds")
	for region: String in ["meadow", "tidepools", "unknown"]:
		_check(encounter_script.roll(region, first, true, true) == {"id": 3, "level": 3}, "The first-catch tutorial remains Wispip level three in " + region)
	for unused: int in range(40):
		var meadow: Dictionary = encounter_script.roll("meadow", first, false, false)
		var postgame: Dictionary = encounter_script.roll("meadow", first, false, true)
		var shore_postgame: Dictionary = encounter_script.roll("tidepools", first, false, true)
		_check(int(meadow.level) >= 3 and int(meadow.level) <= 5 and int(postgame.level) >= 4 and int(postgame.level) <= 6, "Meadow progression retains its original level range")
		_check(int(shore_postgame.level) >= 2 and int(shore_postgame.level) <= 4, "Postgame does not raise the rescue region's gentle level range")
	first.seed = 451
	second.seed = 451
	_check(encounter_script.roll("unknown", first) == encounter_script.roll("meadow", second), "Unknown region IDs fall back to the established meadow table")


func _write_fixture(path: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload))
		file.close()


func _cleanup(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
