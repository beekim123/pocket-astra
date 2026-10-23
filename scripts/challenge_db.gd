class_name ChallengeDB
extends RefCounted
## Stable challenge IDs separate battle presentation from saved progression.

const DB = preload("res://scripts/creature_db.gd")
const CHALLENGES: Dictionary = {
	"harbor_ivo": {
		"kind": "trainer", "title": "IVO / BRIDGE CHALLENGE", "trainer": "Ivo", "flag": "rival",
		"reward_orbs": 4, "reward_tonics": 2, "island": "wakeharbor",
		"requirements": ["starter", "captured"],
		"team": [{"id": 4, "level": 4}, {"id": 5, "level": 5}],
		"opening": "Ivo sends out %s!", "victory_lines": [],
	},
	"first_light": {
		"kind": "gym", "title": "FIRST LIGHT TRIAL", "trainer": "Soren", "flag": "gym",
		"reward_orbs": 6, "reward_tonics": 3, "island": "wakeharbor",
		"requirements": ["starter", "captured", "rival"],
		"team": [{"id": 6, "level": 6}, {"id": 7, "level": 7}],
		"opening": "The Lantern Trial begins! %s enters.",
		"victory_lines": ["Trial complete! You earned the Lantern Sigil.", "The valley glows again. Your journey has only begun."],
	},
	"rain_trial": {
		"kind": "trainer", "title": "NERI / CHANNEL CHALLENGE", "trainer": "Neri", "flag": "rain_trial",
		"reward_orbs": 4, "reward_tonics": 2, "island": "rainstep",
		"requirements": ["starter", "gym", "rain_arrived", "rain_rewarded"],
		"team": [{"id": 8, "level": 7}, {"id": 9, "level": 7}],
		"opening": "Neri sends out %s!",
		"victory_lines": ["Neri's channel challenge is complete. The second beacon is ready."],
	},
	"second_light": {
		"kind": "gym", "title": "SECOND LIGHT TRIAL", "trainer": "Ilya", "flag": "rain_gym",
		"reward_orbs": 6, "reward_tonics": 3, "island": "rainstep",
		"requirements": ["starter", "gym", "rain_arrived", "rain_rewarded", "rain_trial"],
		"team": [{"id": 9, "level": 8}, {"id": 8, "level": 8}, {"id": 10, "level": 9}],
		"opening": "The Second Light Trial begins! %s enters.",
		"victory_lines": ["Trial complete! You earned the Rainlight Sigil.", "Two lights now guide the sea-lanes."],
	},
}


static func data(id: String) -> Dictionary:
	return CHALLENGES[id].duplicate(true) if CHALLENGES.has(id) else {}


static func opponents(id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var challenge: Dictionary = data(id)
	if challenge.is_empty():
		return result
	for entry: Dictionary in challenge.team:
		result.append(DB.make_creature(int(entry.id), int(entry.level)))
	return result


static func can_start(state: GameState, id: String) -> bool:
	var challenge: Dictionary = data(id)
	if state == null or challenge.is_empty() or state.party.is_empty():
		return false
	if state.island_id != str(challenge.island) or bool(state.flags.get(str(challenge.flag), false)):
		return false
	for requirement: String in challenge.requirements:
		if not bool(state.flags.get(requirement, false)):
			return false
	return true


static func objective(state: GameState) -> String:
	if state == null or not bool(state.flags.gym) or not bool(state.flags.rain_rewarded):
		return ""
	if not bool(state.flags.rain_trial):
		return "MEET NERI BY THE NORTHERN WATER CHANNEL"
	if not bool(state.flags.rain_gym):
		return "CHALLENGE ILYA AT THE SECOND LIGHT BEACON"
	return "TWO LIGHTS NOW GUIDE THE SEA-LANES"
