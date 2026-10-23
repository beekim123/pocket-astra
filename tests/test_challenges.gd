extends SceneTree
## Independent challenge progression, once-only rewards, local recovery, and old saves.

const IDS: Array[String] = ["harbor_ivo", "first_light", "rain_trial", "second_light"]
const FLAGS: Array[String] = ["rival", "gym", "rain_trial", "rain_gym"]

var state_script: Script
var battle_script: Script
var challenge_script: Script
var rain_script: Script
var db: Script
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	state_script = load("res://scripts/game_state.gd")
	var fresh = state_script.new()
	_check(fresh.flags.has("rain_trial") and fresh.flags.has("rain_gym"), "New adventures expose independent second-island challenge milestones")
	_check(ResourceLoader.exists("res://scripts/challenge_db.gd"), "The challenge catalog exists")
	if failures > 0:
		_finish()
		return
	challenge_script = load("res://scripts/challenge_db.gd")
	battle_script = load("res://scripts/battle.gd")
	rain_script = load("res://scripts/rain_quest.gd")
	db = load("res://scripts/creature_db.gd")
	_test_gates_and_catalog_isolation()
	_test_invalid_start_stops_previous_battle()
	_test_challenge_wins_are_independent_and_once_only()
	_test_challenge_restrictions_and_local_defeat()
	_test_objective_progression()
	_test_save_compatibility_and_transactional_rejection()
	_test_starter_routes_and_full_party()
	_test_legacy_battles()
	_finish()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _finish() -> void:
	print("CHALLENGE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _ready_for(id: String, starter: int = 0):
	var game = state_script.new()
	game.choose_starter(starter)
	game.flags.captured = true
	if id != "harbor_ivo":
		game.flags.rival = true
	if id in ["rain_trial", "second_light"]:
		game.flags.gym = true
		game.flags.rain_arrived = true
		game.flags.rain_started = true
		game.flags.rain_upper = true
		game.flags.rain_middle = true
		game.flags.rain_lower = true
		game.flags.rain_rewarded = true
		game.island_id = "rainstep"
		game.position = Vector3(61, 0, -12)
	if id == "second_light":
		game.flags.rain_trial = true
	return game


func _snapshot(game) -> Dictionary:
	return {"party": game.party.duplicate(true), "collection": game.collection.duplicate(), "flags": game.flags.duplicate(), "orbs": game.orbs, "tonics": game.tonics, "position": game.position, "island_id": game.island_id, "play_seconds": game.play_seconds}


func _test_gates_and_catalog_isolation() -> void:
	var fresh = state_script.new()
	for index: int in range(IDS.size()):
		var id: String = IDS[index]
		var game = _ready_for(id)
		var before: Dictionary = _snapshot(game)
		_check(not challenge_script.can_start(fresh, id), "A new adventure cannot bypass prerequisites for " + id)
		_check(challenge_script.can_start(game, id) and _snapshot(game) == before, "Eligible challenge checks do not mutate the adventure: " + id)
		var data: Dictionary = challenge_script.data(id)
		_check(str(data.flag) == FLAGS[index], "Each catalog challenge has its own completion flag: " + id)
		var opponents: Array[Dictionary] = challenge_script.opponents(id)
		_check(opponents.size() == (3 if id == "second_light" else 2), "A challenge builds its complete opponent team: " + id)
		var first_hp: int = int(opponents[0].hp)
		opponents[0].hp = 0
		data.team.clear()
		data.requirements.clear()
		data.flag = "gym"
		_check(int(challenge_script.opponents(id)[0].hp) == first_hp and challenge_script.can_start(game, id), "Callers cannot damage catalog templates: " + id)
		game.island_id = "wakeharbor" if id in ["rain_trial", "second_light"] else "rainstep"
		_check(not challenge_script.can_start(game, id), "Challenges cannot start on the wrong island: " + id)
		game = _ready_for(id)
		game.flags[FLAGS[index]] = true
		_check(not challenge_script.can_start(game, id), "Cleared challenges refuse repeat entry: " + id)
		for requirement: String in challenge_script.data(id).requirements:
			game = _ready_for(id)
			game.flags[requirement] = false
			_check(not challenge_script.can_start(game, id), "A missing prerequisite locks " + id + ": " + requirement)
	_check(challenge_script.data("unknown").is_empty() and challenge_script.opponents("unknown").is_empty(), "Unknown IDs do not create phantom challenges")
	_check(not challenge_script.can_start(_ready_for("second_light"), "unknown") and not challenge_script.can_start(null, "harbor_ivo"), "Unknown or absent adventures cannot start a challenge")


func _test_invalid_start_stops_previous_battle() -> void:
	for id: String in ["unknown", "second_light"]:
		var game = _ready_for("harbor_ivo")
		var battle = battle_script.new()
		var opponents: Array[Dictionary] = [db.make_creature(3, 3)]
		battle.begin(game, "wild", opponents, 31)
		var before: Dictionary = _snapshot(game)
		_check(not battle.begin_challenge(game, id, 31), "An invalid or locked challenge reports refusal: " + id)
		_check(battle.finished and battle.outcome == "invalid" and battle.challenge_id.is_empty() and not battle.log.is_empty(), "A refused start replaces any earlier active encounter with visible feedback")
		battle.act("strike")
		battle.act("capture")
		_check(_snapshot(game) == before and battle.turn == 0, "Actions after a refused start cannot mutate the previous battle")


func _complete_quickly(battle) -> void:
	for unused: int in range(10):
		if battle.finished:
			break
		battle.enemy.hp = 1
		battle.act("strike")


func _test_challenge_wins_are_independent_and_once_only() -> void:
	for index: int in range(IDS.size()):
		var id: String = IDS[index]
		var game = _ready_for(id)
		game.party[0] = db.make_creature(0, 12)
		var before_flags: Dictionary = game.flags.duplicate()
		var battle = battle_script.new()
		_check(battle.begin_challenge(game, id, 53), "An eligible challenge starts: " + id)
		_check(battle.challenge_id == id, "The battle retains its explicit challenge identity: " + id)
		if id == "rain_trial":
			_check(str(battle.log[0]).begins_with("Neri sends out "), "The water-channel encounter names Neri at its opening")
		if id == "second_light":
			_check(str(battle.log[0]).begins_with("The Second Light Trial begins! "), "The second beacon opening names its own trial")
		_complete_quickly(battle)
		var expected_orbs: int = 18 if id in ["first_light", "second_light"] else 16
		var expected_tonics: int = 8 if id in ["first_light", "second_light"] else 7
		_check(battle.finished and battle.outcome == "won" and game.orbs == expected_orbs and game.tonics == expected_tonics, "Winning awards the challenge's own supplies: " + id)
		before_flags[FLAGS[index]] = true
		_check(game.flags == before_flags, "Winning changes only this challenge's milestone: " + id)
		var after: Dictionary = _snapshot(game)
		battle.act("strike")
		_check(not battle.begin_challenge(game, id, 53), "A won challenge cannot be replayed for its reward: " + id)
		battle.act("skill")
		_check(_snapshot(game) == after, "Post-win input and repeat entry cannot award twice: " + id)
		game = _ready_for(id)
		game.party[0] = db.make_creature(0, 12)
		game.orbs = 998
		game.tonics = 999
		battle.begin_challenge(game, id, 53)
		_complete_quickly(battle)
		_check(game.orbs == 999 and game.tonics == 999, "Challenge rewards respect the inventory cap: " + id)
		_check("\n".join(battle.log).contains("1 orbs and 0 tonics"), "Capped rewards report the amounts actually received: " + id)
	var shared = _ready_for("harbor_ivo")
	shared.party[0] = db.make_creature(0, 12)
	var first = battle_script.new()
	var pending = battle_script.new()
	first.begin_challenge(shared, "harbor_ivo", 53)
	pending.begin_challenge(shared, "harbor_ivo", 53)
	_complete_quickly(first)
	_complete_quickly(pending)
	_check(shared.orbs == 16 and shared.tonics == 7, "A second already-open resolver cannot award the same cleared milestone twice")


func _test_challenge_restrictions_and_local_defeat() -> void:
	for id: String in ["rain_trial", "second_light"]:
		var game = _ready_for(id)
		var battle = battle_script.new()
		_check(battle.begin_challenge(game, id, 71), "The local challenge is available before defeat: " + id)
		var before: Dictionary = _snapshot(game)
		battle.act("capture")
		battle.act("flee")
		_check(battle.turn == 0 and not battle.finished and _snapshot(game) == before, "Local trainer companions cannot be captured and trials cannot be escaped")
		game.party[0].hp = 1
		battle.act("strike")
		_check(battle.finished and battle.outcome == "lost", "A defeated party ends the local challenge")
		_check(game.island_id == "rainstep" and game.position == Vector3(60, 0, 8), "Local defeat returns to Orla without changing islands")
		_check(game.flags == before.flags and game.orbs == before.orbs and game.tonics == before.tonics, "Defeat grants no milestone or challenge reward")
		_check(int(game.party[0].hp) == int(game.party[0].max_hp) and challenge_script.can_start(game, id), "Local defeat heals the party and permits a fresh attempt")


func _test_objective_progression() -> void:
	var game = _ready_for("first_light")
	_check(str(challenge_script.objective(game)).is_empty(), "Challenge objectives leave first-chapter guidance intact")
	game.flags.gym = true
	_check(str(challenge_script.objective(game)).is_empty(), "Challenge objectives leave unfinished waterworks guidance intact")
	game = _ready_for("rain_trial")
	_check(challenge_script.objective(game) == "MEET NERI BY THE NORTHERN WATER CHANNEL", "Waterworks completion points to Neri")
	game.flags.rain_trial = true
	_check(challenge_script.objective(game) == "CHALLENGE ILYA AT THE SECOND LIGHT BEACON", "Neri's win points to Ilya")
	game.flags.rain_gym = true
	_check(challenge_script.objective(game) == "TWO LIGHTS NOW GUIDE THE SEA-LANES", "Second-beacon completion reports both lights")


func _test_save_compatibility_and_transactional_rejection() -> void:
	var path: String = "user://challenge_save_%d.json" % OS.get_process_id()
	var game = _ready_for("second_light")
	game.flags.rain_gym = true
	game.party[0].hp = 27
	game.party[0].xp = 15
	game.play_seconds = 88.5
	_check(game.save_game(path), "The second-beacon journey saves successfully")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(int(payload.version) == 1, "Independent challenge flags keep version-one saves")
	var restored = state_script.new()
	_check(restored.load_game(path) and _snapshot(restored) == _snapshot(game), "A save preserves both challenge milestones and the full adventure")
	var old: Dictionary = payload.duplicate(true)
	old.flags.erase("rain_trial")
	old.flags.erase("rain_gym")
	_write_fixture(path, old)
	_check(restored.load_game(path) and not restored.flags.rain_trial and not restored.flags.rain_gym, "Old version-one saves default only the new flags to false")
	_check(restored.flags.gym and restored.flags.rain_rewarded and restored.party == game.party, "Legacy loading preserves first light, waterworks, and party progress")
	var valid_snapshot: Dictionary = _snapshot(restored)
	for flag: String in ["rain_trial", "rain_gym"]:
		for invalid_value: Variant in ["true", 1, null, []]:
			var bad: Dictionary = payload.duplicate(true)
			bad.flags[flag] = invalid_value
			_write_fixture(path, bad)
			_check(not restored.load_game(path) and _snapshot(restored) == valid_snapshot, "Malformed challenge flag is rejected transactionally: " + flag)
	var inconsistent: Array[Dictionary] = []
	var missing_reward: Dictionary = payload.duplicate(true)
	missing_reward.flags.rain_rewarded = false
	inconsistent.append(missing_reward)
	var missing_trial: Dictionary = payload.duplicate(true)
	missing_trial.flags.rain_trial = false
	inconsistent.append(missing_trial)
	for prerequisite: String in ["rain_arrived", "rain_started", "rain_upper", "rain_middle", "rain_lower", "gym", "rival", "captured", "starter"]:
		var bad: Dictionary = payload.duplicate(true)
		bad.flags[prerequisite] = false
		inconsistent.append(bad)
	for bad: Dictionary in inconsistent:
		_write_fixture(path, bad)
		_check(not restored.load_game(path) and _snapshot(restored) == valid_snapshot, "An incoherent second-beacon prerequisite chain is rejected transactionally")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))


func _win_with_strategy(game, battle) -> bool:
	for unused: int in range(120):
		if battle.finished:
			break
		var ally: Dictionary = battle.player()
		var info: Dictionary = db.species(int(ally.id))
		var enemy_info: Dictionary = db.species(int(battle.enemy.id))
		if float(ally.hp) / float(ally.max_hp) < 0.4 and game.tonics > 0:
			battle.act("tonic")
		elif db.effectiveness(str(info.element), str(enemy_info.element)) < 1.0:
			battle.act("strike")
		else:
			battle.act("skill")
	return battle.finished and battle.outcome == "won"


func _test_starter_routes_and_full_party() -> void:
	for starter: int in range(3):
		for seed_value: int in [101, 509, 2027]:
			var game = _ready_for("rain_trial", starter)
			game.party[0] = db.make_creature(starter, 7)
			game.add_creature(3, 6)
			game.add_creature(8, 6)
			var battle = battle_script.new()
			_check(battle.begin_challenge(game, "rain_trial", seed_value) and _win_with_strategy(game, battle), "Starter %d can complete Neri's challenge at seed %d" % [starter, seed_value])
			rain_script.interact(game, "rain_keeper")
			_check(battle.begin_challenge(game, "second_light", seed_value) and _win_with_strategy(game, battle), "Starter %d can complete Ilya's three-companion trial at seed %d" % [starter, seed_value])
	var full = _ready_for("rain_trial", 0)
	full.party[0] = db.make_creature(0, 7)
	for id: int in [3, 4, 5, 8, 9]:
		full.add_creature(id, 6)
	full.orbs = 0
	full.tonics = 0
	for creature: Dictionary in full.party:
		creature.hp = 1
	rain_script.interact(full, "rain_keeper")
	_check(full.party.size() == 6 and full.orbs >= 12 and full.tonics >= 5, "A full party with no supplies can recover at Orla without releasing a companion")
	var battle = battle_script.new()
	_check(battle.begin_challenge(full, "rain_trial", 307) and _win_with_strategy(full, battle), "The recovered full party can clear Neri without another capture")
	rain_script.interact(full, "rain_keeper")
	_check(battle.begin_challenge(full, "second_light", 307) and _win_with_strategy(full, battle), "The recovered full party can finish the second beacon without consuming capture capacity")


func _test_legacy_battles() -> void:
	for kind: String in ["trainer", "gym"]:
		var game = _ready_for("first_light")
		game.party[0] = db.make_creature(0, 12)
		var battle = battle_script.new()
		var opponents: Array[Dictionary] = [db.make_creature(3, 1)]
		battle.begin_challenge(game, "first_light", 19)
		battle.begin(game, kind, opponents, 19)
		_check(battle.challenge_id.is_empty(), "The legacy begin API clears explicit challenge identity")
		_complete_quickly(battle)
		_check(battle.outcome == "won" and game.flags["gym" if kind == "gym" else "rival"], "Legacy first-chapter battles retain their completion behavior")
		_check(not game.flags.rain_trial and not game.flags.rain_gym, "Legacy first-chapter wins never complete second-island challenges")


func _write_fixture(path: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
