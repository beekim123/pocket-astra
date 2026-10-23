class_name RainQuest
extends RefCounted
## Rainstep's ferry and waterworks. Travel and repairs never consume supplies.

const REPAIR_FLAGS: Array[String] = ["rain_upper", "rain_middle", "rain_lower"]


static func travel(state: GameState, destination: String) -> bool:
	if not bool(state.flags.starter) or destination not in ["wakeharbor", "rainstep"] or destination == state.island_id:
		return false
	if destination == "rainstep" and not bool(state.flags.gym):
		return false
	state.island_id = destination
	if destination == "rainstep":
		state.position = GameState.RAIN_POSITION
		state.flags.rain_arrived = true
	else:
		state.position = GameState.FERRY_HOME_POSITION
	return true


static func interact(state: GameState, role: String) -> Dictionary:
	if state.island_id != "rainstep" or not bool(state.flags.gym):
		return _reply(_speaker(role), ["Reach Rainstep by ferry after earning the Lantern Sigil."])
	match role:
		"rain_keeper":
			return _keeper(state)
		"rain_upper", "rain_middle", "rain_lower":
			return _repair(state, role)
		_:
			return _reply("RAINSTEP WATERWORKS", ["Rain taps the roofs and gathers in the stone channels."])


static func objective(state: GameState) -> String:
	if not bool(state.flags.gym):
		return ""
	if not bool(state.flags.rain_arrived):
		return "SAIL TO RAINSTEP FROM THE WESTERN PIER"
	if not bool(state.flags.rain_started):
		return "MEET ORLA BY THE RAINSTEP LANDING"
	if not complete(state):
		return "REPAIR THE WATER CHANNELS: %d / 3" % repaired_count(state)
	if not bool(state.flags.rain_rewarded):
		return "RETURN TO ORLA WITH THE WATER FLOWING"
	return "RAINSTEP FLOWS AGAIN"


static func repaired_count(state: GameState) -> int:
	var count: int = 0
	for flag: String in REPAIR_FLAGS:
		if bool(state.flags.get(flag, false)):
			count += 1
	return count


static func complete(state: GameState) -> bool:
	return repaired_count(state) == REPAIR_FLAGS.size()


static func _keeper(state: GameState) -> Dictionary:
	var changed: bool = state.orbs < 12 or state.tonics < 5
	for creature: Dictionary in state.party:
		if int(creature.hp) != int(creature.max_hp):
			changed = true
	state.heal_all()
	state.orbs = maxi(12, state.orbs)
	state.tonics = maxi(5, state.tonics)
	if complete(state) and not bool(state.flags.rain_rewarded):
		state.flags.rain_rewarded = true
		var added_orbs: int = mini(4, 999 - state.orbs)
		var added_tonics: int = mini(2, 999 - state.tonics)
		state.orbs += added_orbs
		state.tonics += added_tonics
		return _reply("ORLA", [
			"From roof to bridge to garden, Rainstep's water is moving again.",
			"Orla adds %d echo vessels and %d tonics to your bag." % [added_orbs, added_tonics],
			"Your companions are rested. The landing has supplies whenever you need them.",
		], true, "win")
	if bool(state.flags.rain_rewarded):
		return _reply("ORLA", [
			"The garden pools are filling. Thank you for giving the rain a clear path.",
			"Your companions are rested. The landing has supplies whenever you need them.",
		], changed, "heal")
	if bool(state.flags.rain_started):
		return _reply("ORLA", [
			"Follow the channels uphill. Each repair helps water reach the gardens.",
			"Your companions are rested. The landing has supplies whenever you need them.",
		], changed, "heal")
	state.flags.rain_started = true
	return _reply("ORLA", [
		"Welcome to Rainstep. I am Orla, the keeper of this landing.",
		"Rain feeds our roof intake, bridge junction, and garden outlet, but all three need a careful repair.",
		"Clear the roof grate, align the bridge trough, and open the garden gate in any order. No supplies are needed.",
		"Your companions are rested. The landing has supplies whenever you need them.",
	], true, "heal")


static func _repair(state: GameState, role: String) -> Dictionary:
	if bool(state.flags[role]):
		match role:
			"rain_upper":
				return _reply(_speaker(role), ["The clear roof grate catches rain without catching leaves."], false, "tide_water")
			"rain_middle":
				return _reply(_speaker(role), ["The bridge trough carries a steady stream across the gap."], false, "tide_water")
			_:
				return _reply(_speaker(role), ["The open garden gate lets water settle among the roots."], false, "tide_water")
	state.flags.rain_started = true
	state.flags[role] = true
	var lines: Array[String] = []
	match role:
		"rain_upper":
			lines.append("You lift the fallen leaves from the roof grate. Rain slips into the upper channel.")
		"rain_middle":
			lines.append("You turn the loose trough into place beneath the bridge. Its stream crosses the gap.")
		"rain_lower":
			lines.append("You ease the stuck garden gate open. Water spreads gently through the planting beds.")
	if complete(state):
		lines.append("All three channels are clear. The rain has a path from the roofs to the gardens.")
		lines.append("Return to Orla at the landing and share the good news.")
		return _reply(_speaker(role), lines, true, "tide_song")
	return _reply(_speaker(role), lines, true, "tide_water")


static func _speaker(role: String) -> String:
	match role:
		"rain_keeper":
			return "ORLA"
		"rain_upper":
			return "ROOF INTAKE"
		"rain_middle":
			return "BRIDGE JUNCTION"
		"rain_lower":
			return "GARDEN OUTLET"
		_:
			return "RAINSTEP WATERWORKS"


static func _reply(speaker: String, lines: Array[String], changed: bool = false, sound: String = "confirm") -> Dictionary:
	return {"speaker": speaker, "lines": lines, "changed": changed, "sound": sound}
