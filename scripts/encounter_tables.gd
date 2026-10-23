class_name EncounterTables
extends RefCounted
## Stable regional species weights; the first-capture tutorial remains shared.

const MEADOW: Array[int] = [3, 4, 5, 3, 4, 5, 0, 1, 2, 6, 7]
const SHORE: Array[int] = [1, 1, 1, 1, 4, 4, 4, 3, 3]


static func roll(region: String, rng: RandomNumberGenerator, first_capture: bool = false, postgame: bool = false) -> Dictionary:
	if first_capture:
		return {"id": 3, "level": 3}
	var species: Array[int] = species_for(region)
	var id: int = species[rng.randi_range(0, species.size() - 1)]
	var level: int = rng.randi_range(2, 4) if region == "tidepools" else rng.randi_range(3, 5) + (1 if postgame else 0)
	return {"id": id, "level": level}


static func species_for(region: String) -> Array[int]:
	return SHORE.duplicate() if region == "tidepools" else MEADOW.duplicate()
