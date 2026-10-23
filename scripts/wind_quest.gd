class_name WindQuest
extends RefCounted
## Windchart's observation-led crossing. Every route and return is free.

const MARKER_FLAGS: Array[String] = ["wind_wind", "wind_tide", "wind_light"]


static func travel(state: GameState, destination: String) -> bool:
	if not bool(state.flags.starter) or state.party.is_empty():
		return false
	if state.island_id == "rainstep" and destination == "windchart":
		if not bool(state.flags.rain_gym):
			return false
		state.island_id = "windchart"
		state.position = GameState.WIND_POSITION
		state.flags.wind_arrived = true
		return true
	if state.island_id == "windchart" and destination == "rainstep":
		state.island_id = "rainstep"
		state.position = GameState.WIND_RAIN_POSITION
		return true
	return false


static func interact(state: GameState, role: String) -> Dictionary:
	if not _available(state):
		return _reply(_speaker(role), ["Reach Windchart from Rainstep after earning the Rainlight Sigil."])
	match role:
		"wind_keeper":
			return _keeper(state)
		"wind_wind", "wind_tide", "wind_light":
			return _observe(state, role)
		"wind_chart":
			if marker_count(state) < 3:
				return _reply("PASSAGE CHART", ["Read the wind pennant, tide gauge, and paired lanterns before choosing a passage."])
			return _reply("PASSAGE CHART", ["The eastern reef catches the wind. The northern shoal is too shallow. The southern lee leads to the berth."])
		"wind_berth":
			return _berth(state)
		_:
			return _reply("WINDCHART QUAY", ["Canvas pennants turn above the quiet stone quay."])


static func marker_count(state: GameState) -> int:
	var count: int = 0
	for flag: String in MARKER_FLAGS:
		if bool(state.flags.get(flag, false)):
			count += 1
	return count


static func can_sail(state: GameState) -> bool:
	return _available(state) and marker_count(state) == MARKER_FLAGS.size()


static func choose_route(state: GameState, route: String) -> Dictionary:
	if not _available(state):
		return _reply("PASSAGE CHART", ["Reach Windchart from Rainstep after earning the Rainlight Sigil."])
	if not can_sail(state):
		return _reply("PASSAGE CHART", ["Read all three navigation markers before sailing. No supplies are needed."])
	match route:
		"north":
			return _reply("PASSAGE CHART", ["The tide gauge marks the northern shoal as too shallow. Stay at the quay and choose again."])
		"east":
			return _reply("PASSAGE CHART", ["The pennant shows wind pressing against the eastern reef. Stay at the quay and choose again."])
		"south":
			var changed: bool = not bool(state.flags.wind_sailed) or state.position != GameState.WIND_BERTH_POSITION
			state.flags.wind_sailed = true
			state.position = GameState.WIND_BERTH_POSITION
			return _reply("SOUTHERN LEE", ["You follow the deep southern channel, sheltered from the wind. The paired lanterns guide you into the small berth.", "Meet Sela beside the sailmaker's shelter."], changed, "tide_song")
		_:
			return _reply("PASSAGE CHART", ["Choose a marked passage: the northern shoal, eastern reef, or southern lee."])


static func return_to_quay(state: GameState) -> bool:
	if state.island_id != "windchart" or not bool(state.flags.wind_sailed):
		return false
	state.position = GameState.WIND_POSITION
	return true


static func objective(state: GameState) -> String:
	if not bool(state.flags.rain_gym):
		return ""
	if not bool(state.flags.wind_arrived) or (state.island_id != "windchart" and not bool(state.flags.wind_rewarded)):
		return "SAIL TO WINDCHART FROM RAINSTEP'S EASTERN PIER"
	if marker_count(state) < 3:
		return "READ THE NAVIGATION MARKERS: %d / 3" % marker_count(state)
	if not bool(state.flags.wind_sailed):
		return "CHOOSE A SAFE PASSAGE AT THE CHART"
	if not bool(state.flags.wind_rewarded):
		return "MEET SELA AT THE SOUTHERN BERTH"
	return "THE SHELTERED ROUTE IS OPEN. EXPLORE THE ISLANDS"


static func _available(state: GameState) -> bool:
	return state.island_id == "windchart" and bool(state.flags.starter) and not state.party.is_empty() and bool(state.flags.rain_gym) and bool(state.flags.wind_arrived)


static func _keeper(state: GameState) -> Dictionary:
	var changed: bool = state.orbs < 12 or state.tonics < 5
	for creature: Dictionary in state.party:
		if int(creature.hp) != int(creature.max_hp):
			changed = true
	state.heal_all()
	state.orbs = maxi(12, state.orbs)
	state.tonics = maxi(5, state.tonics)
	return _reply("MAREN", [
		"Welcome to Windchart. I am Maren. Our little berth lies beyond the shoal and reef.",
		"Read the three navigation markers in any order. Their words are enough to find a safe passage.",
		"Your companions are rested. The quay has supplies whenever you need them.",
	], changed, "heal")


static func _observe(state: GameState, role: String) -> Dictionary:
	var changed: bool = not bool(state.flags[role])
	state.flags[role] = true
	var lines: Array[String] = []
	var sound: String = "confirm"
	match role:
		"wind_wind":
			lines.append("The canvas pennant pulls toward the eastern reef. The reef passage faces the wind; look for a sheltered way.")
			sound = "tide_wind"
		"wind_tide":
			lines.append("The tide gauge shows a shallow northern bar. Its south-channel mark stays below the water: the southern passage is deep enough.")
			sound = "tide_water"
		"wind_light":
			lines.append("The two lanterns line up beyond the southern bend. Their shared line leads into the berth on the sheltered side.")
			sound = "tide_brass"
	if marker_count(state) == MARKER_FLAGS.size():
		lines.append("All three clues are recorded. Choose a passage at the chart beside the quay.")
		if changed:
			sound = "tide_song"
	return _reply(_speaker(role), lines, changed, sound)


static func _berth(state: GameState) -> Dictionary:
	if not bool(state.flags.wind_sailed):
		return _reply("SELA", ["Use the navigation markers and chart to reach the southern berth first."])
	if bool(state.flags.wind_rewarded):
		return _reply("SELA", ["The berth lantern is burning steadily. Our repaired sails can travel home on the next calm tide.", "The small boat can take you back to Maren's quay for free."])
	state.flags.wind_rewarded = true
	var added_orbs: int = mini(4, 999 - state.orbs)
	var added_tonics: int = mini(2, 999 - state.tonics)
	state.orbs += added_orbs
	state.tonics += added_tonics
	return _reply("SELA", [
		"I am Sela. We mend the harbor's sails here, out of the reef wind.",
		"You read the water and brought our route back into use. I will light the berth lantern so the next small boat can follow.",
		"Sela adds %d echo vessels and %d tonics to your bag." % [added_orbs, added_tonics],
		"The small boat can take you back to Maren's quay for free.",
	], true, "win")


static func _speaker(role: String) -> String:
	match role:
		"wind_keeper":
			return "MAREN"
		"wind_wind":
			return "WIND PENNANT"
		"wind_tide":
			return "TIDE GAUGE"
		"wind_light":
			return "PAIRED LANTERNS"
		"wind_chart":
			return "PASSAGE CHART"
		"wind_berth":
			return "SELA"
		_:
			return "WINDCHART QUAY"


static func _reply(speaker: String, lines: Array[String], changed: bool = false, sound: String = "confirm") -> Dictionary:
	return {"speaker": speaker, "lines": lines, "changed": changed, "sound": sound}
