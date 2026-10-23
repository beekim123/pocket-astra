extends SceneTree
## Rainstep's three companions share the established battle and version-one save rules.

const LEGACY_NAMES: Array[String] = ["Cindermew", "Brookfin", "Mossbell", "Wispip", "Pebblit", "Reedrill", "Voltkite", "Noctulume"]
const LEGACY_LEVEL_FIVE_HP: Array[int] = [62, 65, 67, 57, 67, 60, 62, 66]
const NEW_SPECIES: Array[Dictionary] = [
	{"id": 8, "name": "Rillisk", "element": "tide", "move": "Gutter Glide", "level_five_hp": 61},
	{"id": 9, "name": "Terracurl", "element": "stone", "move": "Terrace Tumble", "level_five_hp": 69},
	{"id": 10, "name": "Glimveil", "element": "glow", "move": "Eaves Gleam", "level_five_hp": 60},
]

var db: Script
var state_script: Script
var battle_script: Script
var encounter_script: Script
var quest_script: Script
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	db = load("res://scripts/creature_db.gd")
	state_script = load("res://scripts/game_state.gd")
	battle_script = load("res://scripts/battle.gd")
	encounter_script = load("res://scripts/encounter_tables.gd")
	quest_script = load("res://scripts/rain_quest.gd")
	_check(db.SPECIES.size() == 11, "The existing eight species are extended by three Rainstep companions")
	_test_legacy_ids_and_saves()
	if db.SPECIES.size() != 11:
		_finish()
		return
	_test_new_species_and_factory()
	_test_regional_reachability()
	_test_capture_capacity_and_journal()
	_test_mixed_party_persistence()
	_test_signature_battles_and_growth()
	_finish()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _finish() -> void:
	print("RAIN SPECIES TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _new_arrival():
	var game = state_script.new()
	game.choose_starter(0)
	game.flags.captured = true
	game.flags.rival = true
	game.flags.gym = true
	_check(quest_script.travel(game, "rainstep"), "A completed first chapter reaches the new companions' island")
	return game


func _team(id: int, level: int) -> Array[Dictionary]:
	return [db.make_creature(id, level)]


func _snapshot(game) -> Dictionary:
	return {"party": game.party.duplicate(true), "collection": game.collection.duplicate(), "flags": game.flags.duplicate(), "orbs": game.orbs, "tonics": game.tonics, "position": game.position, "island_id": game.island_id, "play_seconds": game.play_seconds}


func _test_legacy_ids_and_saves() -> void:
	var path: String = "user://rain_species_legacy_%d.json" % OS.get_process_id()
	for id: int in range(8):
		_check(db.species(id).get("name", "") == LEGACY_NAMES[id], "Legacy species ID remains stable: " + str(id))
		var fixture: Dictionary = {
			"version": 1,
			"party": [{"id": id, "level": 5, "hp": 13, "max_hp": LEGACY_LEVEL_FIVE_HP[id], "xp": 17}],
			"collection": [0, 1, 2, 3, 4, 5, 6, 7],
			"flags": {"starter": true, "captured": true, "rival": false, "gym": false},
			"orbs": 7, "tonics": 2, "position": [2.5, 0, -4.25], "play_seconds": 123.5,
		}
		_write_fixture(path, fixture)
		var game = state_script.new()
		_check(game.load_game(path), "An original eight-species save still accepts ID " + str(id))
		_check(game.party == fixture.party and game.collection == fixture.collection, "Legacy companion HP, XP, and released journal entries stay intact")
		_check(game.island_id == "wakeharbor" and not game.flags.rain_arrived, "Original saves keep their home island and do not invent island progress")
	_cleanup(path)


func _test_new_species_and_factory() -> void:
	for expected: Dictionary in NEW_SPECIES:
		var info: Dictionary = db.species(int(expected.id))
		_check(info.has_all(["name", "element", "color", "description", "move", "power", "hp", "attack", "defense", "speed"]), "New species supplies every rendering and battle field")
		_check(info.name == expected.name and info.element == expected.element and info.move == expected.move, "New stable IDs expose their distinct names, existing elements, and signature skills")
		_check(info.color is Color and not str(info.description).is_empty(), "New species has a usable palette and journal description")
		_check(info.get("habitat", "") == "rainstep", "The field journal can identify each new companion's island from metadata")
		var creature: Dictionary = db.make_creature(int(expected.id), 5)
		_check(creature == {"id": expected.id, "level": 5, "hp": expected.level_five_hp, "max_hp": expected.level_five_hp, "xp": 0}, "A new companion begins healthy with the expected derived HP")
		_check(int(db.make_creature(int(expected.id), 0).level) == 1 and int(db.make_creature(int(expected.id), 99).level) == 12, "New species respects the existing level boundaries")
		info.name = "changed copy"
		_check(db.species(int(expected.id)).name == expected.name, "A journal caller cannot rewrite immutable species data")
	_check(db.species(db.SPECIES.size()).is_empty() and db.make_creature(db.SPECIES.size(), 5).is_empty(), "The first ID beyond the expanded catalog is still invalid")


func _test_regional_reachability() -> void:
	_check(encounter_script.species_for("meadow") == [3, 4, 5, 3, 4, 5, 0, 1, 2, 6, 7], "The original meadow keeps its encounter distribution")
	_check(encounter_script.species_for("tidepools") == [1, 1, 1, 1, 4, 4, 4, 3, 3], "Tidepools keeps its encounter distribution")
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 32791
	second.seed = 32791
	var seen: Dictionary = {}
	var new_encounters: int = 0
	for unused: int in range(180):
		var encounter: Dictionary = encounter_script.roll("rainstep", first, false, false)
		_check(encounter == encounter_script.roll("rainstep", second, false, false), "The same regional seed reproduces species and levels")
		_check(int(encounter.level) >= 5 and int(encounter.level) <= 7, "All rain companions remain in the existing island level band")
		seen[int(encounter.id)] = true
		if int(encounter.id) >= 8:
			new_encounters += 1
	for id: int in [8, 9, 10]:
		_check(seen.has(id), "A deterministic rain route can encounter new species " + str(id))
	_check(new_encounters > 90, "The new companions are the majority of encounters on the rain route")
	_check(encounter_script.roll("rainstep", first, true, true) == {"id": 3, "level": 3}, "The first-capture tutorial remains the shared Wispip encounter")


func _test_capture_capacity_and_journal() -> void:
	var game = _new_arrival()
	var flags_before: Dictionary = game.flags.duplicate()
	for expected: Dictionary in NEW_SPECIES:
		var battle = battle_script.new()
		battle.begin(game, "wild", _team(int(expected.id), 5), 17)
		battle.enemy.hp = 1
		var before_orbs: int = game.orbs
		battle.act("capture")
		_check(battle.finished and battle.outcome == "captured" and int(game.party.back().id) == int(expected.id), "A weakened new species joins the party before waterworks completion")
		_check(game.collection.has(int(expected.id)) and game.orbs == before_orbs - 1, "Capturing a rain species records its journal entry and spends one vessel")
	_check(game.flags == flags_before and not quest_script.complete(game), "Capturing all three new species neither requires nor changes waterworks progress")
	game.add_creature(3, 3)
	game.add_creature(4, 3)
	var full_before: Dictionary = _snapshot(game)
	var full_battle = battle_script.new()
	full_battle.begin(game, "wild", _team(8, 5), 17)
	full_battle.enemy.hp = 1
	full_battle.act("capture")
	_check(game.party.size() == 6 and _snapshot(game) == full_before and full_battle.turn == 0 and not full_battle.finished, "A full party refuses a rain capture without losing supplies, progress, or a turn")
	game.party.remove_at(1)
	_check(game.collection.has(8) and game.collection.has(9) and game.collection.has(10), "Releasing a rain companion retains all three journal discoveries")
	full_battle.act("capture")
	_check(full_battle.finished and full_battle.outcome == "captured" and game.party.size() == 6, "Releasing a companion immediately permits the pending rain capture")
	_check(game.collection.count(8) == 1, "Catching a released companion does not duplicate its journal entry")


func _test_mixed_party_persistence() -> void:
	var path: String = "user://rain_species_save_%d.json" % OS.get_process_id()
	var game = _new_arrival()
	for id: int in [8, 9, 10]:
		game.add_creature(id, 5)
	game.party[1].hp = 19
	game.party[2].xp = 27
	quest_script.interact(game, "rain_middle")
	game.position = Vector3(63, 0, -4)
	game.play_seconds = 367.5
	_check(game.save_game(path), "A mixed old and new companion party saves successfully")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(int(payload.version) == 1 and payload.island_id == "rainstep", "The expanded catalog retains the version-one island save format")
	var restored = state_script.new()
	_check(restored.load_game(path) and _snapshot(restored) == _snapshot(game), "Reload preserves old ID zero, new IDs eight through ten, HP, XP, journal, and partial island progress")
	for field: String in ["party", "collection"]:
		var invalid: Dictionary = payload.duplicate(true)
		if field == "party":
			invalid.party[1].id = db.SPECIES.size()
		else:
			invalid.collection.append(db.SPECIES.size())
		_write_fixture(path, invalid)
		_check(not restored.load_game(path) and _snapshot(restored) == _snapshot(game), "Out-of-range saved IDs are rejected transactionally in " + field)
	_cleanup(path)


func _test_signature_battles_and_growth() -> void:
	for expected: Dictionary in NEW_SPECIES:
		var game = state_script.new()
		game.choose_starter(0)
		game.add_creature(int(expected.id), 5)
		var battle = battle_script.new()
		battle.begin(game, "wild", _team(4, 1), 23)
		battle.act("switch", 1)
		game.party[1].xp = 99
		battle.enemy.hp = 1
		var events: Array[String] = battle.act("skill")
		_check("\n".join(events).contains("%s uses %s!" % [expected.name, expected.move]), "A new companion's skill produces its named battle event")
		_check(battle.finished and battle.outcome == "won", "Every rain companion can resolve a battle with its signature skill")
		_check(int(game.party[1].level) == 6 and int(game.party[1].xp) == 33 and int(game.party[1].max_hp) == int(expected.level_five_hp) + 7, "Victory awards XP and grows new-species HP with the established level rules")
		_check(int(game.party[1].hp) > 0 and int(game.party[1].hp) <= int(game.party[1].max_hp), "A rain companion stays healthy and within its new maximum after leveling")
		game.heal_all()
		battle.begin(game, "wild", _team(int(expected.id), 5), 23)
		battle.act("guard")
		events = battle.act("guard")
		_check("\n".join(events).contains("%s uses %s." % [expected.name, expected.move]), "A wild rain companion can also use its signature skill")


func _write_fixture(path: String, payload: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()


func _cleanup(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
