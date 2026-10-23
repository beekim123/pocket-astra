class_name TideQuest
extends RefCounted
## Optional shore rescue and observations. No party or main-quest mutations.

const MARKER_FLAGS: Array[String] = ["tide_wind", "tide_water", "tide_brass"]
const SONG_LINES: Array[String] = [
	"Wind finds the hollow stone. Water answers through the narrow channel.",
	"The brass carries both notes toward the harbor lamps, a guide for wandering wings.",
	"Three sounds, one safe way home. The Tideglass song is complete.",
]


static func interact(state: GameState, role: String) -> Dictionary:
	if not bool(state.flags.starter):
		return _reply(_speaker(role), ["Choose a companion with the Keeper before following the shore path."])
	match role:
		"tide_artisan":
			return _artisan(state)
		"tide_rescue":
			if bool(state.flags.tide_rescued):
				return _reply("WISPIP", ["The dry lamp rail is empty. A small light now circles the harbor lamp."])
			state.flags.tide_started = true
			state.flags.tide_rescued = true
			return _reply("WISPIP", [
				"The Wispip trembles above a wet stone. You offer a steady hand.",
				"It hops to the dry lamp rail, shakes its wings, and glides toward Wakeharbor.",
				"The way home is clear. Tell Tavi the little wanderer is safe.",
			], true, "heal")
		"tide_wind", "tide_water", "tide_brass":
			return _marker(state, role)
		_:
			return _reply("SHORE NOTES", ["The tide keeps its own quiet rhythm."])


static func objective(state: GameState) -> String:
	if not bool(state.flags.starter):
		return ""
	if not bool(state.flags.tide_started):
		return "TALK TO TAVI BY THE SOUTHERN SHORE"
	if not bool(state.flags.tide_rescued):
		return "FOLLOW THE CAUSEWAY. HELP THE STRANDED WISPIP."
	if not bool(state.flags.tide_rewarded):
		return "RETURN TO TAVI IN WAKEHARBOR"
	if not complete(state):
		return "LISTEN TO THREE SHORE MARKERS: %d / 3" % marker_count(state)
	return "THE TIDEGLASS SONG IS COMPLETE"


static func marker_count(state: GameState) -> int:
	var count: int = 0
	for flag: String in MARKER_FLAGS:
		if bool(state.flags.get(flag, false)):
			count += 1
	return count


static func complete(state: GameState) -> bool:
	return marker_count(state) == MARKER_FLAGS.size()


static func _artisan(state: GameState) -> Dictionary:
	if bool(state.flags.tide_rescued) and not bool(state.flags.tide_rewarded):
		state.flags.tide_rewarded = true
		state.orbs = mini(999, state.orbs + 4)
		state.tonics = mini(999, state.tonics + 2)
		return _reply("TAVI", [
			"There you are! Our little wanderer found the harbor lamp again.",
			"Take 4 echo vessels and 2 tonics. A kind detour deserves fresh supplies.",
			"The shore has three old sound markers. Listen in any order; their notes belong together.",
		], true, "win")
	if bool(state.flags.tide_rewarded):
		if complete(state):
			return _reply("TAVI", [
				"The lamp rail is warm with tiny wings again.",
				"Wind, water, and brass: the whole shore remembers your visit.",
			])
		return _reply("TAVI", [
			"Our wanderer is safe on the harbor lamp.",
			"Listen to the wind stone, water channel, and brass chimes when you have a quiet moment.",
		])
	if bool(state.flags.tide_started):
		return _reply("TAVI", [
			"Follow the southern causeway and stay on the dry rocks.",
			"The little light is waiting at the far end of the dry causeway.",
		])
	state.flags.tide_started = true
	return _reply("TAVI", [
		"A Wispip followed the lamp reflections into the tide pools.",
		"Take the southern causeway. The dry rocks lead around the shallow water.",
		"Help it onto the lamp rail, then meet me here. No vessel is needed.",
	], true)


static func _marker(state: GameState, role: String) -> Dictionary:
	if bool(state.flags[role]):
		if complete(state):
			return _reply(_speaker(role), SONG_LINES.duplicate(), false, "tide_song")
		match role:
			"tide_wind":
				return _reply(_speaker(role), ["The wind stone holds its low, patient note."], false, role)
			"tide_water":
				return _reply(_speaker(role), ["Water repeats the small rhythm you remember."], false, role)
			_:
				return _reply(_speaker(role), ["The brass keeps a bright space for the other notes."], false, role)
	state.flags[role] = true
	var lines: Array[String] = []
	match role:
		"tide_wind":
			lines.append("A breath of wind crosses the hollow stone. You remember its low note.")
		"tide_water":
			lines.append("A thread of water taps the channel's steps. You remember its gentle rhythm.")
		"tide_brass":
			lines.append("Three small brass pieces turn above the salt. You remember their clear reply.")
	if complete(state):
		lines.append_array(SONG_LINES)
		return _reply(_speaker(role), lines, true, "tide_song")
	return _reply(_speaker(role), lines, true, role)


static func _speaker(role: String) -> String:
	match role:
		"tide_artisan":
			return "TAVI"
		"tide_rescue":
			return "WISPIP"
		"tide_wind":
			return "WIND STONE"
		"tide_water":
			return "WATER CHANNEL"
		"tide_brass":
			return "BRASS CHIMES"
		_:
			return "SHORE NOTES"


static func _reply(speaker: String, lines: Array[String], changed: bool = false, sound: String = "confirm") -> Dictionary:
	return {"speaker": speaker, "lines": lines, "changed": changed, "sound": sound}
