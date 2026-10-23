class_name CreatureDB
extends RefCounted
## Immutable species data and the elemental rules shared by the world and combat.

const LEVEL_CAP: int = 12
const SPECIES: Array[Dictionary] = [
	{"name": "Cindermew", "element": "ember", "color": Color(1.0, 0.44, 0.24), "description": "A lantern-tailed wanderer that keeps lost travelers warm.", "move": "Lantern Flare", "power": 17, "hp": 27, "attack": 12, "defense": 9, "speed": 12},
	{"name": "Brookfin", "element": "tide", "color": Color(0.24, 0.77, 0.91), "description": "Its sail-like fins catch moonlit currents and distant songs.", "move": "Sailwater Rush", "power": 17, "hp": 30, "attack": 10, "defense": 12, "speed": 10},
	{"name": "Mossbell", "element": "grove", "color": Color(0.57, 0.81, 0.36), "description": "A gentle flower-antlered fawn whose bells wake the forest.", "move": "Petal Chime", "power": 17, "hp": 32, "attack": 10, "defense": 11, "speed": 9},
	{"name": "Wispip", "element": "glow", "color": Color(1.0, 0.84, 0.43), "description": "A tiny lantern moth that gathers around kind hearts.", "move": "Wishlight", "power": 16, "hp": 22, "attack": 10, "defense": 7, "speed": 15},
	{"name": "Pebblit", "element": "stone", "color": Color(0.65, 0.60, 0.56), "description": "A pebble-armored friend that naps beside ancient milestones.", "move": "Cobble Roll", "power": 16, "hp": 32, "attack": 11, "defense": 15, "speed": 6},
	{"name": "Reedrill", "element": "grove", "color": Color(0.32, 0.71, 0.59), "description": "A marsh heron that carves quiet paths through tall reeds.", "move": "Reed Lance", "power": 17, "hp": 25, "attack": 12, "defense": 9, "speed": 14},
	{"name": "Voltkite", "element": "storm", "color": Color(0.70, 0.62, 1.0), "description": "An airborne ray riding the sparks between passing clouds.", "move": "Cloudspark", "power": 18, "hp": 27, "attack": 13, "defense": 9, "speed": 16},
	{"name": "Noctulume", "element": "shade", "color": Color(0.48, 0.42, 0.69), "description": "A watchful night owl guarding the last light of the valley.", "move": "Velvet Eclipse", "power": 18, "hp": 31, "attack": 12, "defense": 12, "speed": 11},
]
const ADVANTAGES: Dictionary = {
	"ember": ["grove"],
	"tide": ["ember", "stone"],
	"grove": ["tide", "stone"],
	"glow": ["shade"],
	"stone": ["ember", "storm"],
	"storm": ["tide", "glow"],
	"shade": ["grove"],
}


static func species(id: int) -> Dictionary:
	if id < 0 or id >= SPECIES.size():
		return {}
	return SPECIES[id].duplicate(true)


static func make_creature(id: int, level: int) -> Dictionary:
	if id < 0 or id >= SPECIES.size():
		return {}
	var safe_level: int = clampi(level, 1, LEVEL_CAP)
	var health: int = int(SPECIES[id].hp) + safe_level * 7
	return {"id": id, "level": safe_level, "hp": health, "max_hp": health, "xp": 0}


static func effectiveness(attacking: String, defending: String) -> float:
	if attacking == "normal" or not ADVANTAGES.has(attacking) or not ADVANTAGES.has(defending):
		return 1.0
	if defending in ADVANTAGES[attacking]:
		return 1.5
	if attacking == defending or attacking in ADVANTAGES[defending]:
		return 0.7
	return 1.0


static func xp_to_next(level: int) -> int:
	return maxi(1, level) * 20
