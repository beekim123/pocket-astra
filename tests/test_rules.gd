extends SceneTree
## Headless behavior suite. Run: godot --headless --path . --script tests/test_rules.gd

var db: Script
var state_script: Script
var battle_script: Script
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	for path: String in ["res://scripts/creature_db.gd", "res://scripts/game_state.gd", "res://scripts/battle.gd"]:
		_check(ResourceLoader.exists(path), "Rules implementation exists: " + path)
	if failures > 0:
		_finish()
		return
	db = load("res://scripts/creature_db.gd")
	state_script = load("res://scripts/game_state.gd")
	battle_script = load("res://scripts/battle.gd")
	_test_starters_and_types()
	_test_capture_and_inventory()
	_test_turns_switches_and_recovery()
	_test_deterministic_battles()
	_test_save_round_trip_and_rejection()
	_test_journal_and_defeated_save_recovery()
	_test_all_starter_journeys()
	_finish()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _finish() -> void:
	print("RULES TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _team(id: int, level: int) -> Array[Dictionary]:
	return [db.make_creature(id, level)]


func _test_starters_and_types() -> void:
	for id: int in range(8):
		var info: Dictionary = db.species(id)
		_check(info.has_all(["name", "element", "color", "description", "move", "power", "hp", "attack", "defense", "speed"]), "Each species supports rendering and battle stats")
		var creature: Dictionary = db.make_creature(id, 3)
		_check(int(creature.hp) > 0 and creature.hp == creature.max_hp, "New creatures are healthy")
	_check(db.species(-1).is_empty() and db.make_creature(8, 3).is_empty(), "Invalid species do not create phantom creatures")
	_check(db.effectiveness("ember", "grove") > 1.0, "Ember beats grove")
	_check(db.effectiveness("grove", "tide") > 1.0, "Grove beats tide")
	_check(db.effectiveness("tide", "ember") > 1.0, "Tide beats ember")
	_check(db.effectiveness("ember", "tide") < 1.0, "A resisted skill is weaker")
	_check(db.effectiveness("normal", "stone") == 1.0, "Strikes have reliable neutral effectiveness")
	for id: int in range(3):
		var game = state_script.new()
		game.choose_starter(id)
		_check(game.party.size() == 1 and int(game.active().id) == id and bool(game.flags.starter), "Starter selection initializes a playable party")
		game.choose_starter((id + 1) % 3)
		_check(game.party.size() == 1 and int(game.active().id) == id, "Starter selection cannot duplicate or replace the starter")
	var invalid_game = state_script.new()
	invalid_game.choose_starter(7)
	_check(invalid_game.party.is_empty() and not bool(invalid_game.flags.starter), "Only the three offered starters can start a game")


func _test_capture_and_inventory() -> void:
	var game = state_script.new()
	game.choose_starter(0)
	var battle = battle_script.new()
	battle.begin(game, "wild", _team(3, 2), 17)
	battle.enemy.hp = 1
	var before_orbs: int = game.orbs
	var events: Array[String] = battle.act("capture")
	_check(battle.finished and battle.outcome == "captured", "A weakened first wild creature can be captured")
	_check(game.party.size() == 2 and game.collection.has(3) and game.flags.captured, "Capturing adds to party, journal, and quest")
	_check(game.orbs == before_orbs - 1 and not events.is_empty(), "Capturing consumes exactly one orb and reports events")
	while game.party.size() < 6:
		game.add_creature(4, 3)
	_check(not game.add_creature(7, 3) and game.party.size() == 6, "Party capacity is enforced")
	battle.begin(game, "wild", _team(7, 2), 17)
	before_orbs = game.orbs
	battle.act("capture")
	_check(game.orbs == before_orbs and battle.turn == 0 and not battle.finished, "A full party does not waste an orb or a turn")
	game = state_script.new()
	game.choose_starter(1)
	battle.begin(game, "trainer", _team(4, 3), 17)
	before_orbs = game.orbs
	battle.act("capture")
	_check(game.orbs == before_orbs and battle.turn == 0, "Trainer companions cannot be captured")
	battle.act("flee")
	_check(not battle.finished and battle.turn == 0, "Trainer challenges cannot be escaped")
	battle.begin(game, "wild", _team(4, 3), 17)
	game.orbs = 0
	battle.act("capture")
	_check(battle.turn == 0, "An empty inventory cannot spend a turn on capture")
	battle.act("flee")
	_check(battle.finished and battle.outcome == "fled", "Wild encounters can always be escaped")


func _test_turns_switches_and_recovery() -> void:
	var game = state_script.new()
	game.choose_starter(2)
	game.add_creature(0, 4)
	var battle = battle_script.new()
	battle.begin(game, "wild", _team(4, 2), 23)
	game.party[0].hp = 1
	var tonics_before: int = game.tonics
	battle.act("tonic")
	_check(game.tonics == tonics_before - 1 and int(game.party[0].hp) > 1, "Tonics heal before the opponent responds")
	var previous_turn: int = battle.turn
	battle.act("switch", 0)
	battle.act("switch", 99)
	_check(battle.turn == previous_turn, "Invalid party switches do not consume a turn")
	battle.act("switch", 1)
	_check(battle.active_index == 1 and battle.turn == previous_turn + 1, "A voluntary switch changes active creature and uses one turn")
	var opponents: Array[Dictionary] = [db.make_creature(3, 1), db.make_creature(4, 1)]
	battle.begin(game, "trainer", opponents, 31)
	battle.enemy.hp = 1
	battle.act("strike")
	_check(not battle.finished and int(battle.enemy.id) == 4, "An opponent's next companion enters after a knockout")
	_check(int(opponents[0].hp) > 1, "Battle opponents are copied so templates stay healthy")
	game.party[0].hp = 1
	battle.begin(game, "wild", _team(6, 12), 41)
	battle.act("strike")
	_check(not battle.finished and battle.active_index == 1, "A fainted ally automatically hands off to a healthy ally")
	game.party[1].hp = 1
	battle.act("strike")
	_check(battle.finished and battle.outcome == "lost", "A whole defeated party ends the battle")
	_check(int(game.party[0].hp) == int(game.party[0].max_hp) and int(game.party[1].hp) == int(game.party[1].max_hp), "Defeat restores the party to avoid a softlock")
	var final_turn: int = battle.turn
	battle.act("strike")
	_check(battle.turn == final_turn, "Finished battles cannot mutate the party again")


func _test_deterministic_battles() -> void:
	var first_game = state_script.new()
	var second_game = state_script.new()
	first_game.choose_starter(0)
	second_game.choose_starter(0)
	var first = battle_script.new()
	var second = battle_script.new()
	first.begin(first_game, "wild", _team(4, 4), 7501)
	second.begin(second_game, "wild", _team(4, 4), 7501)
	for action: String in ["guard", "skill", "strike", "skill"]:
		_check(first.act(action) == second.act(action), "A fixed seed reproduces battle events")
	_check(first_game.party == second_game.party and first.enemy == second.enemy, "A fixed seed reproduces HP and experience")


func _write_fixture(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()


func _test_save_round_trip_and_rejection() -> void:
	var path: String = "user://rules_test_%d.json" % OS.get_process_id()
	var game = state_script.new()
	game.choose_starter(1)
	game.add_creature(3, 4)
	game.party[0].hp = 13
	game.party[0].xp = 17
	game.flags.rival = true
	game.flags.captured = true
	game.flags.cache = true
	game.position = Vector3(2.5, 0.0, -4.25)
	game.play_seconds = 123.5
	game.orbs = 7
	game.tonics = 2
	_check(game.save_game(path), "Saving succeeds")
	var restored = state_script.new()
	_check(restored.load_game(path), "A saved journey can be loaded")
	_check(restored.party == game.party and restored.collection == game.collection and restored.flags == game.flags, "Save preserves party, XP, journal, and milestones")
	_check(bool(restored.flags.get("cache", false)), "The claimed supply cache stays claimed after reloading")
	_check(restored.position.is_equal_approx(game.position) and is_equal_approx(restored.play_seconds, 123.5) and restored.orbs == 7 and restored.tonics == 2, "Save preserves position, playtime, and inventory")
	var preserved_party: Array = restored.party.duplicate(true)
	_write_fixture(path, "{broken json")
	_check(not restored.load_game(path) and restored.party == preserved_party, "Corruption is rejected without erasing the current journey")
	_write_fixture(path, '{"version":999,"party":[]}')
	_check(not restored.load_game(path), "Unknown save versions are rejected safely")
	game.save_game(path)
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.party[0].id = 999
	_write_fixture(path, JSON.stringify(payload))
	_check(not restored.load_game(path) and restored.party == preserved_party, "Invalid saved species cannot enter the party")
	game.save_game(path)
	payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.orbs = -100
	_write_fixture(path, JSON.stringify(payload))
	_check(not restored.load_game(path), "Invalid inventory is rejected rather than trusted")
	game.save_game(path)
	payload = JSON.parse_string(FileAccess.get_file_as_string(path))
	payload.flags.cache = "true"
	_write_fixture(path, JSON.stringify(payload))
	_check(not restored.load_game(path), "Optional cache flags must be boolean")
	payload.flags.erase("cache")
	_write_fixture(path, JSON.stringify(payload))
	_check(restored.load_game(path) and not bool(restored.flags.get("cache", false)), "Older version-one saves without cache state remain loadable")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))


func _test_journal_and_defeated_save_recovery() -> void:
	var path: String = "user://rules_recovery_%d.json" % OS.get_process_id()
	var game = state_script.new()
	game.choose_starter(0)
	for id: int in range(1, 8):
		if game.party.size() == 6:
			game.party.remove_at(1)
		_check(game.add_creature(id, 3), "Releasing a companion makes room for another species")
	game.flags.captured = true
	_check(game.party.size() == 6 and game.collection.size() == 8, "All eight journal entries remain recorded with a six-companion party")
	game.position = Vector3(7.0, 0.0, -4.0)
	for creature: Dictionary in game.party:
		creature.hp = 0
	_check(game.save_game(path), "An interrupted journey with a defeated party can be persisted")
	var restored = state_script.new()
	_check(restored.load_game(path), "A saved defeated party is recovered on load")
	_check(restored.collection.size() == 8 and restored.party.size() == 6, "Journal entries for released companions survive loading")
	_check(restored.position.is_equal_approx(Vector3(-7, 0, 5)), "A saved defeated party returns home")
	for creature: Dictionary in restored.party:
		_check(int(creature.hp) == int(creature.max_hp), "Every saved defeated companion is fully healed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _win_with_strategy(game, opponents: Array[Dictionary], kind: String, seed_value: int) -> bool:
	var battle = battle_script.new()
	battle.begin(game, kind, opponents, seed_value)
	for unused: int in range(100):
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


func _test_all_starter_journeys() -> void:
	for starter: int in range(3):
		var game = state_script.new()
		game.choose_starter(starter)
		for wild_id: int in [3, 4, 5]:
			game.heal_all()
			_check(_win_with_strategy(game, _team(wild_id, 3), "wild", 100 + wild_id), "Starter %d can win early wild encounters" % starter)
		game.add_creature(3, 4)
		game.flags.captured = true
		game.heal_all()
		var rival_team: Array[Dictionary] = [db.make_creature(4, 4), db.make_creature((starter + 1) % 3, 5)]
		_check(_win_with_strategy(game, rival_team, "trainer", 200 + starter), "Starter %d can beat a two-companion rival" % starter)
		_check(bool(game.flags.rival), "Winning the rival challenge unlocks the milestone")
		game.heal_all()
		var gym_team: Array[Dictionary] = [db.make_creature(6, 6), db.make_creature(7, 7)]
		_check(_win_with_strategy(game, gym_team, "gym", 300 + starter), "Starter %d can complete the lantern trial" % starter)
		_check(bool(game.flags.gym), "Winning the trial records completion")
		_check(int(game.party[0].level) > 5, "The journey awards experience and levels")
