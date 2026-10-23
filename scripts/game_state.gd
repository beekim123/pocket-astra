class_name GameState
extends RefCounted
## Plain saveable game state. Loading is transactional: invalid files change nothing.

const DB = preload("res://scripts/creature_db.gd")
const SAVE_VERSION: int = 1
const PARTY_LIMIT: int = 6
const HOME_POSITION: Vector3 = Vector3(-7.0, 0.0, 5.0)
const FLAG_KEYS: Array[String] = ["starter", "rival", "gym", "captured"]
const OPTIONAL_FLAG_KEYS: Array[String] = ["cache"]

var party: Array[Dictionary] = []
var collection: Array[int] = []
var flags: Dictionary = {"starter": false, "rival": false, "gym": false, "captured": false, "cache": false}
var orbs: int = 12
var tonics: int = 5
var position: Vector3 = HOME_POSITION
var play_seconds: float = 0.0


func choose_starter(id: int) -> void:
	if bool(flags.starter) or not party.is_empty() or id < 0 or id > 2:
		return
	if add_creature(id, 5):
		flags.starter = true


func heal_all() -> void:
	for creature: Dictionary in party:
		creature.hp = int(creature.max_hp)


func add_creature(id: int, level: int) -> bool:
	if party.size() >= PARTY_LIMIT:
		return false
	var creature: Dictionary = DB.make_creature(id, level)
	if creature.is_empty():
		return false
	party.append(creature)
	if not collection.has(id):
		collection.append(id)
	return true


func active() -> Dictionary:
	for creature: Dictionary in party:
		if int(creature.hp) > 0:
			return creature
	return party[0] if not party.is_empty() else {}


func quest() -> String:
	if not bool(flags.starter):
		return "Meet the Keeper. Choose your first companion."
	if not bool(flags.captured):
		return "Explore the meadow. Weaken and capture a wild companion."
	if not bool(flags.rival):
		return "Challenge Ivo on the eastern path."
	if not bool(flags.gym):
		return "Enter the First Light Sanctum. Complete Soren's trial."
	return "The lantern is awake. Explore and complete your field journal."


func save_game(path: String = "user://lanternwake.json") -> bool:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"party": party,
		"collection": collection,
		"flags": flags,
		"orbs": orbs,
		"tonics": tonics,
		"position": [position.x, position.y, position.z],
		"play_seconds": play_seconds,
	}
	var temporary_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return false
	var rename_error: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary_path))
		return false
	return true


func load_game(path: String = "user://lanternwake.json") -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() > 1048576:
		file.close()
		return false
	var contents: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(contents) != OK or not json.data is Dictionary:
		return false
	var data: Dictionary = json.data
	if not data.has_all(["version", "party", "collection", "flags", "orbs", "tonics", "position", "play_seconds"]):
		return false
	if not _valid_int(data.version, SAVE_VERSION, SAVE_VERSION):
		return false
	if not data.party is Array or not data.collection is Array or not data.flags is Dictionary:
		return false
	if data.party.size() > PARTY_LIMIT or data.collection.size() > DB.SPECIES.size():
		return false
	if not _valid_int(data.orbs, 0, 999) or not _valid_int(data.tonics, 0, 999):
		return false
	if not _valid_number(data.play_seconds, 0.0, 1000000000.0):
		return false
	if not data.position is Array or data.position.size() != 3:
		return false
	for component: Variant in data.position:
		if not _valid_number(component, -1000.0, 1000.0):
			return false
	var new_flags: Dictionary = {}
	for key: String in FLAG_KEYS:
		if not data.flags.has(key) or not data.flags[key] is bool:
			return false
		new_flags[key] = data.flags[key]
	# New optional milestones preserve compatibility with earlier version-one saves.
	for key: String in OPTIONAL_FLAG_KEYS:
		if data.flags.has(key) and not data.flags[key] is bool:
			return false
		new_flags[key] = data.flags.get(key, false)
	if bool(new_flags.starter) != (data.party.size() > 0):
		return false
	if bool(new_flags.gym) and (not bool(new_flags.rival) or not bool(new_flags.captured)):
		return false
	var new_collection: Array[int] = []
	for id: Variant in data.collection:
		if not _valid_int(id, 0, DB.SPECIES.size() - 1) or new_collection.has(int(id)):
			return false
		new_collection.append(int(id))
	var new_party: Array[Dictionary] = []
	for entry: Variant in data.party:
		if not entry is Dictionary or not entry.has_all(["id", "level", "hp", "max_hp", "xp"]):
			return false
		if not _valid_int(entry.id, 0, DB.SPECIES.size() - 1) or not _valid_int(entry.level, 1, DB.LEVEL_CAP):
			return false
		var creature: Dictionary = DB.make_creature(int(entry.id), int(entry.level))
		if not _valid_int(entry.max_hp, int(creature.max_hp), int(creature.max_hp)):
			return false
		if not _valid_int(entry.hp, 0, int(creature.max_hp)) or not _valid_int(entry.xp, 0, DB.xp_to_next(int(entry.level)) - 1):
			return false
		if not new_collection.has(int(entry.id)):
			return false
		creature.hp = int(entry.hp)
		creature.xp = int(entry.xp)
		new_party.append(creature)
	# Commit only after every field passed validation.
	party = new_party
	collection = new_collection
	flags = new_flags
	orbs = int(data.orbs)
	tonics = int(data.tonics)
	position = Vector3(float(data.position[0]), float(data.position[1]), float(data.position[2]))
	play_seconds = float(data.play_seconds)
	if not party.is_empty() and not _has_healthy_creature():
		heal_all()
		position = HOME_POSITION
	return true


static func _valid_number(value: Variant, low: float, high: float) -> bool:
	if not (value is int or value is float):
		return false
	var number: float = float(value)
	return is_finite(number) and number >= low and number <= high


static func _valid_int(value: Variant, low: int, high: int) -> bool:
	return _valid_number(value, float(low), float(high)) and float(value) == floorf(float(value))


func _has_healthy_creature() -> bool:
	for creature: Dictionary in party:
		if int(creature.hp) > 0:
			return true
	return false
