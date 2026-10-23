extends Control
## All interface geometry and typography are drawn from code. No imported fonts.
const F = preload("res://scripts/pixel_font.gd")
const Art = preload("res://scripts/art.gd")
const DB = preload("res://scripts/creature_db.gd")
const Locale = preload("res://scripts/localization.gd")
const ShoreQuest = preload("res://scripts/tide_quest.gd")
const RainStory = preload("res://scripts/rain_quest.gd")
const Challenges = preload("res://scripts/challenge_db.gd")
const WindStory = preload("res://scripts/wind_quest.gd")
const INK := Color("142b34")
const PANEL := Color(0.045, 0.10, 0.14, 0.96)
const CREAM := Color("f1e4c5")
const GOLD := Color("dabb7b")
const MIST := Color("90aca9")
const TEAL := Color("70c2b0")
var game: Node
var buttons: Array[Dictionary] = []
var scale_factor := Vector2.ONE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	if game == null:
		return
	scale_factor = get_viewport_rect().size / Vector2(1280, 720)
	draw_set_transform(Vector2.ZERO, 0, scale_factor)
	buttons.clear()
	match game.mode:
		"title": _title()
		"new_confirm": _new_confirm()
		"starter": _starters()
		"explore": _exploration()
		"dialogue":
			_exploration(false)
			_dialogue()
		"battle": _battle()
		"menu": _menu()
		"ferry":
			_exploration(false)
			_ferry_dialogue()
		"route":
			_exploration(false)
			_route_dialogue()
		"ending": _ending()
	if game.toast_time > 0:
		var w: float = minf(1180, F.width(game.toast, 2) + 44)
		_panel(Rect2((1280 - w) / 2, 104, w, 40), GOLD, 0.96)
		_center(game.toast, Vector2(640, 117), 2, CREAM)

func _text(value: String, pos: Vector2, size: int = 2, color: Color = CREAM) -> void:
	F.text(self, value, pos, size, color)

func _center(value: String, pos: Vector2, size: int = 2, color: Color = CREAM) -> void:
	_text(value, pos - Vector2(F.width(value, size) / 2, 0), size, color)

func _paragraph(value: String, pos: Vector2, chars: int, size: int = 2, color: Color = CREAM, line_gap: int = 9) -> float:
	var y: float = pos.y
	for line in F.wrap(value, chars, size):
		_text(line, Vector2(pos.x, y), size, color)
		y += maxf(7 * size + line_gap, F.line_height(size))
	return y

func _panel(rect: Rect2, border: Color = MIST, alpha: float = 0.95) -> void:
	draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color(0, 0, 0, 0.22))
	draw_rect(rect, Color(PANEL.r, PANEL.g, PANEL.b, alpha))
	draw_rect(rect, Color(border.r, border.g, border.b, 0.55), false, 1)
	for p in [rect.position, rect.position + Vector2(rect.size.x - 4, 0), rect.end - Vector2(4, 4), rect.position + Vector2(0, rect.size.y - 4)]:
		draw_rect(Rect2(p, Vector2(4, 4)), border)

func _button(action: String, label: String, rect: Rect2, size: int = 2, enabled: bool = true) -> void:
	var index := buttons.size()
	var mouse := get_local_mouse_position() / scale_factor
	var active: bool = rect.has_point(mouse) or game.selection == index
	var color: Color = GOLD if active and enabled else MIST
	draw_rect(rect, Color("385b5a") if active and enabled else Color(0.08, 0.17, 0.20, 0.94))
	draw_rect(rect, Color(color.r, color.g, color.b, 0.9 if active else 0.4), false, 1)
	if active:
		draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), GOLD)
	var label_height: float = F.line_height(size) - 2 if Locale.chinese() else size * 7
	_center(label, rect.get_center() - Vector2(0, label_height * 0.5), size, color if enabled else Color("607775"))
	buttons.append({"action":action if enabled else "", "rect":rect})

func button_at(pos: Vector2) -> String:
	pos /= scale_factor
	for button in buttons:
		if button.rect.has_point(pos):
			return button.action
	return ""

func _crest(center: Vector2, radius: float, color: Color = GOLD) -> void:
	draw_arc(center, radius, 0, TAU, 48, Color(color.r, color.g, color.b, 0.55), 1, true)
	draw_arc(center, radius * 0.79, 0, TAU, 48, Color(color.r, color.g, color.b, 0.25), 1, true)
	for i in range(8):
		var a: float = i * TAU / 8.0
		var p := center + Vector2(cos(a), sin(a)) * radius
		draw_circle(p, 2.0, color)
	var r: float = radius * 0.40
	var points := PackedVector2Array([center + Vector2(0, -r * 1.6), center + Vector2(r * 0.6, 0), center + Vector2(0, r), center + Vector2(-r * 0.6, 0)])
	draw_colored_polygon(points, color)
	draw_line(center + Vector2(-r, r * 1.25), center + Vector2(r, r * 1.25), color, 2)

func _title() -> void:
	# A soft scrim leaves the diorama visible at the right of the title.
	for i in range(180):
		var alpha: float = 0.92 * (1.0 - pow(float(i) / 180.0, 2.8))
		draw_rect(Rect2(i * 4, 0, 4, 720), Color(0.035, 0.09, 0.12, alpha))
	draw_rect(Rect2(0, 0, 1280, 5), GOLD)
	_text("AN ORIGINAL CREATURE-KEEPING TALE", Vector2(72, 65), 2, MIST)
	_crest(Vector2(112, 147), 35)
	draw_line(Vector2(173, 146), Vector2(467, 146), Color(GOLD.r, GOLD.g, GOLD.b, 0.5), 1)
	if Locale.chinese():
		_text("灯潮纪", Vector2(65, 205), 9, CREAM)
		_text("L A N T E R N W A K E", Vector2(73, 319), 2, GOLD)
	else:
		_text("LANTERN", Vector2(68, 206), 9, CREAM)
		_text("WAKE", Vector2(68, 283), 9, CREAM)
	_text("THREE SHORES  /  TWO LIGHTS", Vector2(74, 378), 2, GOLD)
	_text("A SMALL BOAT. A SONG BEYOND THE REEF.", Vector2(74, 419), 2, MIST)
	_text("A LIGHT TO GUIDE YOU HOME.", Vector2(74, 446), 2, MIST)
	var y: float = 523
	if game.has_save:
		_button("continue", "CONTINUE JOURNEY", Rect2(73, y, 337, 47))
		y += 57
	_button("new", "BEGIN A NEW JOURNEY", Rect2(73, y, 337, 47))
	_button("language", "LANGUAGE: SIMPLIFIED CHINESE" if Locale.chinese() else "LANGUAGE: ENGLISH", Rect2(1040, 610, 213, 35), 1)
	_text("ENTER / SELECT    ARROWS / CHOOSE", Vector2(74, 666), 1, MIST)
	_text("EVERY PIXEL. EVERY NOTE. MADE OF CODE.", Vector2(801, 670), 1, CREAM)
	_text("WAKEHARBOR  /  AUTUMN TIDE", Vector2(868, 43), 2, CREAM)

func _new_confirm() -> void:
	_title()
	buttons.clear()
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.45))
	_panel(Rect2(330, 224, 620, 270), GOLD)
	_center("A NEW BEGINNING", Vector2(640, 260), 3)
	_paragraph("Your current saved journey will be replaced when you choose a new companion.", Vector2(370, 319), 44, 2, MIST)
	_button("new_no", "KEEP MY JOURNEY", Rect2(370, 411, 255, 45))
	_button("new_yes", "START AGAIN", Rect2(645, 411, 265, 45))

func _starters() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.075, 0.105, 0.89))
	_center("EVERY GREAT JOURNEY STARTS SMALL", Vector2(640, 49), 2, GOLD)
	_center("WHO WILL WALK BESIDE YOU?", Vector2(640, 90), 4)
	_center("THREE LITTLE SPARKS. THREE DIFFERENT SONGS.", Vector2(640, 143), 2, MIST)
	var subtitles := ["THE WARM-HEARTED WANDERER", "THE CURIOUS RIVER SAILOR", "THE GENTLE WOODLAND BELL"]
	for i in range(3):
		var x: float = 54 + i * 401
		var info: Dictionary = DB.species(i)
		_panel(Rect2(x, 193, 370, 408), info.color)
		_text("0%d  /  %s" % [i + 1, str(info.element).to_upper()], Vector2(x + 24, 215), 2, info.color)
		draw_arc(Vector2(x + 185, 332), 77, 0, TAU, 48, Color(0.7, 0.8, 0.6, 0.12), 1)
		draw_texture_rect(Art.creature(i, int(game.clock * 2) % 3), Rect2(x + 79, 230, 212, 212), false)
		_center(info.name, Vector2(x + 185, 451), 3, CREAM)
		_center(subtitles[i], Vector2(x + 185, 488), 1, MIST)
		_center("SIGNATURE / " + str(info.move), Vector2(x + 185, 516), 1, info.color)
		_button("starter:%d" % i, "%d  CHOOSE %s" % [i + 1, str(info.name).to_upper()], Rect2(x + 22, 552, 326, 37), 2)
	_center("EMBER > GROVE > TIDE > EMBER   /   ALL THREE CAN COMPLETE THE TRIAL", Vector2(640, 645), 1, MIST)
	_center("CLICK A COMPANION OR USE ARROWS + ENTER", Vector2(640, 677), 1, GOLD)

func _exploration(show_controls: bool = true) -> void:
	_panel(Rect2(28, 24, 338, 61), GOLD, 0.91)
	_text("WINDCHART / A SHORT CROSSING" if game.world.island_id == "windchart" else ("THE SECOND LIGHT / CHAPTER II" if game.world.island_id == "rainstep" else "THE FIRST LIGHT  /  CHAPTER I"), Vector2(46, 35), 1, GOLD)
	_text(game.world.area_name(), Vector2(46, 55), 2)
	_panel(Rect2(790, 24, 462, 92), MIST, 0.91)
	_text("YOUR NEXT STEP", Vector2(811, 39), 1, GOLD)
	_paragraph(game.objective_text(), Vector2(811, 59), 35, 2, CREAM, 7)
	for i in range(game.state.party.size()):
		var c: Dictionary = game.state.party[i]
		var x: float = 32 + i * 51
		draw_circle(Vector2(x + 22, 123), 23, Color(0.06, 0.15, 0.18, 0.78))
		draw_texture_rect(Art.creature(int(c.id)), Rect2(x - 4, 96, 52, 52), false)
		draw_rect(Rect2(x + 5, 151, 34, 3), Color("3b514e"))
		draw_rect(Rect2(x + 5, 151, 34 * float(c.hp) / float(c.max_hp), 3), TEAL)
	if show_controls:
		if bool(game.state.flags.starter):
			_panel(Rect2(28, 562, 338, 82), TEAL, 0.90)
			if game.world.island_id == "windchart":
				_text("WINDCHART NOTES", Vector2(45, 575), 1, TEAL)
				_text("NAVIGATION MARKERS %d / 3" % WindStory.marker_count(game.state), Vector2(45, 599), 1, CREAM)
			elif game.world.island_id == "rainstep":
				_text("RAINSTEP WATERWORKS", Vector2(45, 575), 1, TEAL)
				_text("WATER CHANNELS %d / 3" % RainStory.repaired_count(game.state), Vector2(45, 599), 1, CREAM)
			else:
				_text("OPTIONAL SHORE JOURNEY", Vector2(45, 575), 1, TEAL)
				_paragraph(ShoreQuest.objective(game.state), Vector2(45, 599), 48, 1, CREAM, 6)
		_panel(Rect2(28, 658, 1224, 37), MIST, 0.85)
		_text("WASD / MOVE    SHIFT / RUN    E / TALK    TAB / SATCHEL    J / JOURNAL    F5 / SAVE", Vector2(45, 672), 1, CREAM)
		_text("VESSELS %02d  TONICS %02d" % [game.state.orbs, game.state.tonics], Vector2(956, 672), 1, GOLD)
		var npc: Dictionary = game.world.nearby()
		if not npc.is_empty():
			_button("interact", "E  " + str(npc.name), Rect2(376, 602, 528, 38), 1)
		_button("menu", "TAB  SATCHEL", Rect2(1096, 607, 156, 35), 1)
	if game.area_timer > 0 and show_controls:
		var fade: float = minf(1, game.area_timer)
		_center(game.area_text, Vector2(640, 177), 3, Color(CREAM.r, CREAM.g, CREAM.b, fade))
		draw_line(Vector2(490, 211), Vector2(790, 211), Color(GOLD.r, GOLD.g, GOLD.b, fade * 0.7), 1)

func _dialogue() -> void:
	_panel(Rect2(48, 515, 1184, 175), GOLD, 0.98)
	_text(game.speaker, Vector2(78, 539), 2, GOLD)
	if not game.dialogue.is_empty():
		_paragraph(game.dialogue[0], Vector2(78, 577), 88, 2, CREAM, 10)
	_button("next", "E / CONTINUE", Rect2(1044, 649, 160, 26), 1)

func _ferry_dialogue() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.07, 0.10, 0.42))
	_panel(Rect2(320, 221, 640, 292), GOLD)
	_center("FERRY TO WINDCHART" if game.ferry_destination == "windchart" else ("FERRY TO RAINSTEP" if game.ferry_destination == "rainstep" else "FERRY TO WAKEHARBOR"), Vector2(640, 257), 3, CREAM)
	var crossing_text: String = "Read three markers at Windchart Quay, then choose a sheltered route. The ferry back to Rainstep is always free." if game.ferry_destination == "windchart" else "Follow the dry paths. Orla offers free rest by the landing, and Venn can always take you home."
	_paragraph(crossing_text, Vector2(360, 321), 45, 2, MIST)
	_button("ferry_board", "BOARD FERRY", Rect2(360, 435, 260, 43), 2)
	_button("ferry_cancel", "STAY HERE", Rect2(640, 435, 280, 43), 2)

func _route_dialogue() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.07, 0.10, 0.56))
	_panel(Rect2(250, 165, 780, 440), GOLD)
	_center("CHOOSE A SHELTERED ROUTE", Vector2(640, 192), 3, CREAM)
	_paragraph("Wind drives toward the eastern reef. The middle shoal is shallow. The berth opens to the deep southern channel.", Vector2(288, 245), 58, 2, MIST)
	_button("route:north", "NORTH / MIDDLE SHOAL", Rect2(290, 342, 700, 47), 2)
	_button("route:east", "EAST / EXPOSED REEF", Rect2(290, 400, 700, 47), 2)
	_button("route:south", "SOUTH / LEEWARD ARC", Rect2(290, 458, 700, 47), 2)
	_button("ferry_cancel", "STAY AT THE QUAY", Rect2(430, 538, 420, 40), 2)

func _health(creature: Dictionary, pos: Vector2, enemy_side: bool = false) -> void:
	var info: Dictionary = DB.species(int(creature.id))
	_panel(Rect2(pos, Vector2(360, 104)), info.color)
	_text(info.name, pos + Vector2(18, 17), 2)
	_text("LV %02d" % creature.level, pos + Vector2(278, 18), 2, GOLD)
	_text(str(info.element).to_upper(), pos + Vector2(18, 42), 1, info.color)
	var ratio: float = float(creature.hp) / float(creature.max_hp)
	draw_rect(Rect2(pos + Vector2(19, 62), Vector2(321, 9)), Color("30494a"))
	draw_rect(Rect2(pos + Vector2(19, 62), Vector2(321 * ratio, 9)), TEAL if ratio > 0.3 else Color("e6a06f"))
	_text("HP  %d / %d" % [creature.hp, creature.max_hp], pos + Vector2(19, 81), 1, MIST)
	if not enemy_side:
		_text("XP  %d / %d" % [creature.xp, DB.xp_to_next(int(creature.level))], pos + Vector2(204, 81), 1, MIST)

func _battle() -> void:
	draw_rect(Rect2(0, 0, 1280, 8), INK)
	var wild_heading: String = "A SONG IN THE TIDEPOOLS" if game.battle_region == "tidepools" else ("A SONG IN THE RAIN" if game.battle_region == "rainstep" else "A SONG IN THE REEDS")
	var title: String = "FIRST LIGHT TRIAL" if game.battle.kind == "gym" else ("IVO / BRIDGE CHALLENGE" if game.battle.kind == "trainer" else wild_heading)
	if not game.battle.challenge_id.is_empty():
		title = str(Challenges.data(game.battle.challenge_id).title)
	_text(title, Vector2(42, 37), 2, CREAM)
	_text("TURN %02d   /   %s" % [game.battle.turn + 1, str(game.battle.kind).to_upper()], Vector2(43, 64), 1, GOLD)
	_health(game.battle.enemy, Vector2(856, 34), true)
	_health(game.battle.player(), Vector2(45, 425))
	if game.battle_effect > 0 and not game.reduced_effects:
		var t: float = 1.0 - game.battle_effect
		if game.last_action == "capture":
			var p := Vector2(390, 420).lerp(Vector2(858, 310), t)
			p.y -= sin(t * PI) * 160
			draw_circle(p, 12, GOLD)
			draw_arc(p, 18 + t * 22, 0, TAU, 28, Color(1, 0.9, 0.65, 1-t), 3)
		else:
			for i in range(8):
				var a: float = i * TAU / 8
				var p := Vector2(842, 320) + Vector2(cos(a), sin(a)) * (20 + t * 90)
				draw_rect(Rect2(p, Vector2(5, 5)), Color(1, 0.87, 0.6, 1-t))
	_panel(Rect2(28, 542, 1224, 154), GOLD, 0.98)
	_text("THE RESONANCE", Vector2(49, 559), 1, GOLD)
	var line_y: float = 586
	for line in game.battle_lines:
		line_y = _paragraph(line, Vector2(49, line_y), 43, 2, CREAM, 7) + 7
	if not game.battle_queue.is_empty() or game.battle_timer > 0:
		_text("THE SONG UNFOLDS...", Vector2(745, 586), 2, MIST)
		_text("E / ENTER TO ADVANCE", Vector2(746, 623), 1, GOLD)
		return
	if game.battle.finished:
		var outcome: String = {"won":"VICTORY", "captured":"A NEW FRIEND", "lost":"REST AND RETURN", "fled":"SAFELY AWAY"}.get(game.battle.outcome, "ENCOUNTER ENDED")
		_text(outcome, Vector2(734, 565), 2, GOLD)
		_button("battle_done", "E / CONTINUE JOURNEY", Rect2(704, 608, 514, 55), 2)
		return
	var actions := ["strike", "skill", "capture", "tonic", "guard", "switch", "flee"]
	var labels := ["1 STRIKE", "2 SIGNATURE", "3 CAPTURE", "4 TONIC", "5 GUARD", "6 SWITCH", "7 FLEE"]
	for i in range(actions.size()):
		var x: float = 602 + (i % 4) * 153
		var y: float = 557 + (i / 4) * 52
		_button(actions[i], labels[i], Rect2(x, y, 143, 43), 1)
	_text("VESSELS %d   TONICS %d" % [game.state.orbs, game.state.tonics], Vector2(1063, 624), 1, MIST)
	var info: Dictionary = DB.species(int(game.battle.player().id))
	var foe: Dictionary = DB.species(int(game.battle.enemy.id))
	var multiplier: float = DB.effectiveness(info.element, foe.element)
	_text("%s  X%.2f   /   GUARD RECOVERS HP" % [str(info.move).to_upper(), multiplier], Vector2(604, 674), 1, GOLD)

func _menu() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.07, 0.10, 0.88))
	_panel(Rect2(40, 30, 1200, 660), GOLD)
	_text("THE WAYFARER'S SATCHEL", Vector2(70, 56), 3)
	var crest: String = "SECOND LIGHT CREST" if bool(game.state.flags.rain_gym) else ("FIRST LIGHT CREST" if bool(game.state.flags.gym) else "ONE SMALL LIGHT AT A TIME")
	_text(crest, Vector2(774, 63), 1, GOLD)
	_text("LIGHTS AWAKENED %d / 2" % (int(game.state.flags.gym) + int(game.state.flags.rain_gym)), Vector2(1020, 63), 1, TEAL)
	var tabs := ["party", "journal", "map", "settings"]
	for i in range(4):
		_button("tab:" + tabs[i], tabs[i].to_upper(), Rect2(70 + i * 185, 103, 173, 38), 2)
		if game.menu_tab == tabs[i]:
			draw_rect(Rect2(70 + i * 185, 145, 173, 2), GOLD)
	_button("close", "ESC / BACK", Rect2(1033, 103, 174, 38), 1)
	match game.menu_tab:
		"party": _party_menu()
		"journal": _journal_menu()
		"map": _map_menu()
		"settings": _settings_menu()
	_text("VESSELS  %02d     TONICS  %02d     JOURNAL  %02d / %02d" % [game.state.orbs, game.state.tonics, game.state.collection.size(), DB.SPECIES.size()], Vector2(71, 654), 1, GOLD)
	_text("TIME  %02d:%02d" % [int(game.state.play_seconds) / 60, int(game.state.play_seconds) % 60], Vector2(1077, 654), 1, MIST)

func _party_menu() -> void:
	if game.state.party.is_empty():
		_text("YOUR FIRST COMPANION IS WAITING.", Vector2(90, 240), 2, MIST)
		return
	game.chosen_creature = clampi(game.chosen_creature, 0, game.state.party.size() - 1)
	for i in range(game.state.party.size()):
		var c: Dictionary = game.state.party[i]
		var y: float = 166 + i * 70
		_button("party:%d" % i, "", Rect2(70, y, 445, 61))
		draw_texture_rect(Art.creature(int(c.id)), Rect2(73, y - 1, 64, 64), false)
		_text(DB.species(int(c.id)).name, Vector2(148, y + 12), 2, GOLD if i == game.chosen_creature else CREAM)
		_text("LV %d   HP %d/%d" % [c.level, c.hp, c.max_hp], Vector2(149, y + 38), 1, MIST)
		if i == 0:
			_text("LEAD", Vector2(462, y + 25), 1, GOLD)
	var selected: Dictionary = game.state.party[game.chosen_creature]
	var info: Dictionary = DB.species(int(selected.id))
	draw_texture_rect(Art.creature(int(selected.id), int(game.clock * 2) % 3), Rect2(724, 149, 248, 248), false)
	_center(info.name, Vector2(849, 404), 3)
	_center(str(info.element).to_upper() + "  /  " + str(info.move).to_upper(), Vector2(849, 444), 1, info.color)
	_paragraph(info.description, Vector2(591, 476), 48, 2, MIST)
	_button("lead", "SWITCH IN" if game.menu_return == "battle" else "MAKE LEAD COMPANION", Rect2(589, 561, 319, 43), 1)
	if game.menu_return != "battle":
		_button("release", "CONFIRM RELEASE" if game.release_pending else "RELEASE", Rect2(925, 561, 260, 43), 1, game.state.party.size() > 1)
	_text("RELEASING KEEPS ITS JOURNAL ENTRY. FIND IT AGAIN IN ITS HOME REGION.", Vector2(591, 622), 1, MIST)

func _journal_menu() -> void:
	_text("FIELD JOURNAL", Vector2(73, 166), 2, GOLD)
	if game.state.collection.size() == DB.SPECIES.size():
		_text("COLLECTION COMPLETE", Vector2(337, 169), 1, TEAL)
	var ids: Array[int] = game.journal_visible_ids()
	for slot: int in range(ids.size()):
		var i: int = ids[slot]
		var x: float = 70 + (slot % 4) * 133
		var y: float = 209 + (slot / 4) * 173
		var known: bool = game.state.collection.has(i)
		_button("journal:%d" % i, "", Rect2(x, y, 120, 157))
		draw_texture_rect(Art.creature(i), Rect2(x + 5, y + 9, 110, 110), false, Color.WHITE if known else Color(0.15, 0.23, 0.25, 1))
		_center("%02d" % (i + 1), Vector2(x + 60, y + 125), 2, GOLD if known else MIST)
	var id: int = game.journal_id
	var known: bool = game.state.collection.has(id)
	var info: Dictionary = DB.species(id)
	var rain_species: bool = info.get("habitat", "meadow") == "rainstep"
	var habitat: String = "FOUND IN RAINSTEP" if rain_species else "FOUND IN CANDLE REED"
	if rain_species:
		_text("RAINSTEP COMPANIONS", Vector2(73, 193), 1, MIST)
	draw_texture_rect(Art.creature(id, int(game.clock * 2) % 3), Rect2(795, 155, 224, 224), false, Color.WHITE if known else Color(0.15, 0.23, 0.25, 1))
	_center(info.name if known else "UNRECORDED SONG", Vector2(910, 399), 3, CREAM)
	_center(str(info.element).to_upper() if known else habitat, Vector2(910, 441), 1, GOLD)
	var discovery: String = "Three new resonants shelter by Rainstep's channels, warm stones, and roof eaves. Look among the pale plants, then weaken them before capture." if rain_species else "Explore the tall reeds beyond the bridge. Every new friendship writes a page in this journal."
	_paragraph(info.description if known else discovery, Vector2(660, 477), 43, 2, MIST)
	_text(habitat, Vector2(662, 588), 1, MIST)
	_text("RECORDED" if known else "NOT YET BEFRIENDED", Vector2(662, 613), 1, TEAL if known else GOLD)
	_button("journal_previous", "PREVIOUS PAGE", Rect2(70, 574, 144, 37), 1, game.journal_page > 0)
	_button("journal_next", "NEXT PAGE", Rect2(232, 574, 144, 37), 1, game.journal_page + 1 < game.journal_page_count())
	_center("PAGE %d / %d" % [game.journal_page + 1, game.journal_page_count()], Vector2(493, 587), 1, GOLD)

func _map_menu() -> void:
	_button("map_island", "ISLAND MAP", Rect2(74, 151, 155, 22), 1)
	_button("map_shore", "SHORE MAP", Rect2(238, 151, 155, 22), 1)
	if bool(game.state.flags.gym):
		_button("map_rain", "RAINSTEP MAP", Rect2(402, 151, 155, 22), 1)
	if bool(game.state.flags.rain_gym):
		_button("map_wind", "WINDCHART MAP", Rect2(566, 151, 155, 22), 1)
	if game.map_wind:
		_wind_map()
		return
	if game.map_rain:
		_rain_map()
		return
	if game.map_shore:
		_shore_map()
		return
	var map_rect := Rect2(74, 174, 681, 439)
	draw_rect(map_rect, Color("244849"))
	# Schematic cartography built from the same world-space landmarks.
	for x in [88, 442]:
		draw_rect(Rect2(x, 191, 297, 398), Color("57715b"))
		draw_rect(Rect2(x + 7, 196, 281, 386), Color("6d805c"), false, 2)
	draw_rect(Rect2(95, 438, 635, 25), Color("c3b285"))
	draw_rect(Rect2(225, 234, 22, 230), Color("c3b285"))
	draw_rect(Rect2(590, 235, 22, 229), Color("c3b285"))
	for p in [Vector2(136, 318), Vector2(286, 277), Vector2(126, 217)]:
		draw_rect(Rect2(p, Vector2(49, 38)), Color("d0bd92"))
		draw_rect(Rect2(p + Vector2(-4, -6), Vector2(57, 14)), Color("9c7563"))
	_crest(Vector2(600, 252), 27)
	_text("WAKEHARBOR", Vector2(135, 525), 2, CREAM)
	_text("CANDLE REED", Vector2(491, 525), 2, CREAM)
	_text("FIRST LIGHT", Vector2(534, 300), 1, GOLD)
	_text("MIRA", Vector2(135, 401), 1, CREAM)
	_text("IVO", Vector2(476, 420), 1, CREAM)
	var p: Vector3 = game.world.player_position
	var marker := Vector2(414 + p.x * 21, 389 + p.z * 17)
	if game.world.island_id == "wakeharbor" and game.world.area_id() != "tidepools":
		draw_circle(marker, 7, GOLD)
		draw_arc(marker, 12 + sin(game.clock * 3) * 2, 0, TAU, 24, CREAM, 1)
	_text("CAUSEWAY / SOUTH", Vector2(118, 580), 1, GOLD)
	_text("WESTERN PIER", Vector2(92, 469), 1, GOLD)
	_text("YOUR JOURNEY", Vector2(800, 184), 2, GOLD)
	var milestones := ["CHOOSE A COMPANION", "CATCH A WILD RESONANT", "DEFEAT IVO", "WIN THE FIRST LIGHT"]
	var keys := ["starter", "captured", "rival", "gym"]
	for i in range(4):
		var y: float = 241 + i * 66
		draw_circle(Vector2(810, y + 6), 5, TEAL if game.state.flags[keys[i]] else MIST)
		_text(milestones[i], Vector2(830, y), 1, CREAM)
	_paragraph("Paths are safe. Walk into the reeds to meet a wild resonant. Mira offers free rest and supplies in the village.", Vector2(800, 527), 32, 2, MIST)

func _shore_point(point: Vector2) -> Vector2:
	return Vector2(100 + (point.x + 13.4) * 52, 196 + (point.y - 10) * 28)

func _shore_rect(rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(_shore_point(rect.position), rect.size * Vector2(52, 28)), color)

func _shore_map() -> void:
	draw_rect(Rect2(74, 178, 681, 435), Color("244849"))
	_shore_rect(Rect2(-8.3, 10, 2.7, 3.4), Color("b4a47f"))
	_shore_rect(Rect2(-13.4, 13, 10.8, 10.6), Color("7c918b"))
	for pool in game.world.TIDE_POOLS:
		_shore_rect(pool, Color("356b73"))
	_shore_rect(game.world.TIDE_REEDS, Color("456e62"))
	var positions: Array[Vector2] = [Vector2(-11.8, 14.3), Vector2(-12, 21.4), Vector2(-3.5, 16.2)]
	var keys: Array[String] = ["tide_wind", "tide_water", "tide_brass"]
	for i in range(3):
		var p: Vector2 = _shore_point(positions[i])
		draw_circle(p, 9, TEAL if game.state.flags.get(keys[i], false) else INK)
		_center(str(i + 1), p - Vector2(0, 4), 1, CREAM)
	var rescue_pos := _shore_point(Vector2(-4.5, 21.7))
	draw_circle(rescue_pos, 11, GOLD)
	_center("RESCUE COMPLETE" if game.state.flags.get("tide_rescued", false) else "HELP WISPIP", rescue_pos + Vector2(-7, 20), 1, INK)
	_center("RETURN TO THE VILLAGE", Vector2(436, 208), 1, INK)
	_text("TIDEGLASS POOLS", Vector2(106, 589), 1, CREAM)
	if game.world.area_id() == "tidepools":
		var player: Vector3 = game.world.player_position
		var point := _shore_point(Vector2(player.x, player.z))
		draw_circle(point, 5, CREAM)
		draw_arc(point, 11 + sin(game.clock * 3) * 2, 0, TAU, 24, GOLD, 1)
	_text("TIDEGLASS RESCUE", Vector2(800, 184), 2, GOLD)
	_paragraph(ShoreQuest.objective(game.state), Vector2(800, 228), 32, 2, CREAM)
	_text("SHORE NOTES %d / 3" % ShoreQuest.marker_count(game.state), Vector2(800, 332), 2, TEAL)
	var names: Array[String] = ["WIND-HOLE STONE", "WATER CHANNEL", "BRASS CHIMES"]
	for i in range(3):
		var y: float = 376 + i * 43
		draw_circle(Vector2(810, y + 6), 5, TEAL if game.state.flags.get(keys[i], false) else MIST)
		_text("%d" % (i + 1), Vector2(827, y), 1, GOLD)
		_text(names[i], Vector2(849, y), 1, CREAM)
	_paragraph("Follow the dry eastern bank to Wispip. The three markers can be heard in any order.", Vector2(800, 527), 32, 2, MIST)

func _rain_point(point: Vector2) -> Vector2:
	return Vector2(100 + (point.x - 48) * 25, 200 + (point.y + 11) * 17.5)

func _rain_map() -> void:
	draw_rect(Rect2(74, 178, 681, 435), Color("253a50"))
	draw_rect(Rect2(100, 200, 600, 385), Color("81949c"))
	draw_rect(Rect2(_rain_point(Vector2(59.1, -8.4)), Vector2(45, 315)), Color("c4bd9e"))
	for z in [-6.5, -1.5, 3.8]:
		draw_rect(Rect2(_rain_point(Vector2(50, z - 0.45)), Vector2(500, 16)), Color("c4bd9e"))
	for house in game.world.rainstep.obstacles:
		var rect := Rect2(_rain_point(house.position), house.size * Vector2(25, 17.5))
		draw_rect(rect, Color("56667b"))
	var positions: Array[Vector2] = [Vector2(52, -6.5), Vector2(67, -1.5), Vector2(52, 3.8)]
	var keys: Array[String] = ["rain_upper", "rain_middle", "rain_lower"]
	for i in range(3):
		var p: Vector2 = _rain_point(positions[i])
		draw_circle(p, 10, TEAL if game.state.flags.get(keys[i], false) else INK)
		_center(str(i + 1), p - Vector2(0, 4), 1, CREAM)
	var dock := _rain_point(Vector2(60, 9.4))
	draw_circle(dock, 7, GOLD)
	_center("FERRY TO WAKEHARBOR", dock - Vector2(0, 25), 1, INK)
	var keeper := _rain_point(Vector2(56, 5.5))
	draw_circle(keeper, 5, TEAL)
	_text("ORLA", keeper + Vector2(12, -4), 1, INK)
	if game.world.island_id == "rainstep":
		var p: Vector3 = game.world.player_position
		var marker := _rain_point(Vector2(p.x, p.z))
		draw_circle(marker, 5, CREAM)
		draw_arc(marker, 12, 0, TAU, 32, GOLD, 1)
	_text("RAINSTEP TERRACES", Vector2(106, 592), 1, CREAM)
	_text("RAINSTEP WATERWORKS", Vector2(800, 184), 2, GOLD)
	_paragraph(game.objective_text(), Vector2(800, 228), 32, 2, CREAM)
	_text("WATER CHANNELS %d / 3" % RainStory.repaired_count(game.state), Vector2(800, 332), 2, TEAL)
	var names: Array[String] = ["ROOF INTAKE", "BRIDGE JUNCTION", "GARDEN OUTLET"]
	for i in range(3):
		var y: float = 376 + i * 43
		draw_circle(Vector2(810, y + 6), 5, TEAL if game.state.flags.get(keys[i], false) else MIST)
		_text(str(i + 1), Vector2(827, y), 1, GOLD)
		_text(names[i], Vector2(849, y), 1, CREAM)
	if bool(game.state.flags.rain_rewarded):
		for entry in [["rain_trial", "DEFEAT NERI"], ["rain_gym", "WIN THE SECOND LIGHT"]]:
			var y: float = 523 if entry[0] == "rain_trial" else 560
			draw_circle(Vector2(810, y + 6), 5, TEAL if game.state.flags[entry[0]] else MIST)
			_text(entry[1], Vector2(830, y), 1, CREAM)
	else:
		_paragraph("Three channels carry roof water to the gardens. Repair them in any order, then return to Orla.", Vector2(800, 527), 32, 2, MIST)
	var neri: Vector2 = _rain_point(Vector2(63.5, -6.5))
	draw_circle(neri, 6, GOLD)
	_text("NERI", neri + Vector2(9, -3), 1, INK)
	var beacon: Vector2 = _rain_point(Vector2(60, -8.6))
	draw_circle(beacon, 7, TEAL if game.state.flags.rain_gym else GOLD)
	_text("SECOND LIGHT BEACON", beacon + Vector2(12, -3), 1, CREAM)

func _wind_point(point: Vector2) -> Vector2:
	return Vector2(100 + (point.x - 108) * 15, 200 + (point.y + 11) * 17.5)

func _wind_map() -> void:
	draw_rect(Rect2(74, 178, 681, 435), Color("244b58"))
	for bounds: Rect2 in [game.world.windchart.BOUNDS, game.world.windchart.BERTH_BOUNDS]:
		draw_rect(Rect2(_wind_point(bounds.position), bounds.size * Vector2(15, 17.5)), Color("9ba393"))
	for endpoints: Array in [[Vector2(120, -6.8), Vector2(120, 9.4)], [Vector2(112, -5), Vector2(128, -5)], [Vector2(112, 3), Vector2(128, 3)], [Vector2(112, -5), Vector2(112, 3)], [Vector2(128, -5), Vector2(128, 3)], [Vector2(116, 6), Vector2(120, 6)], [Vector2(140, -1), Vector2(140, 4)]]:
		draw_line(_wind_point(endpoints[0]), _wind_point(endpoints[1]), Color("c3b58b"), 10)
	for obstacle: Rect2 in game.world.windchart.obstacles:
		draw_rect(Rect2(_wind_point(obstacle.position), obstacle.size * Vector2(15, 17.5)), Color("697c7e"))
	var dock: Vector2 = _wind_point(Vector2(120, 8))
	var berth: Vector2 = _wind_point(Vector2(140, 2))
	if game.state.flags.wind_sailed:
		draw_polyline(PackedVector2Array([dock, _wind_point(Vector2(126, 10)), _wind_point(Vector2(139, 8)), berth]), GOLD, 2, true)
	for i in range(game.world.windchart.MARKERS.size()):
		var marker: Dictionary = game.world.windchart.MARKERS[i]
		var point := _wind_point(Vector2(marker.pos.x, marker.pos.z))
		draw_circle(point, 10, TEAL if game.state.flags[marker.role] else INK)
		_center(str(i + 1), point - Vector2(0, 4), 1, CREAM)
	_text("WINDCHART QUAY", Vector2(132, 224), 1, INK)
	_center("LEE BERTH", Vector2(580, 320), 1, INK)
	_text("MAREN / REST", _wind_point(Vector2(112, 5)), 1, INK)
	draw_circle(_wind_point(Vector2(120, -3)), 5, GOLD)
	_center("CHART TABLE", _wind_point(Vector2(120, -2)), 1, INK)
	_center("FERRY TO RAINSTEP", dock + Vector2(0, 22), 1, INK)
	_text("SELA", berth + Vector2(-14, -40), 1, INK)
	draw_circle(berth, 6, TEAL if game.state.flags.wind_rewarded else GOLD)
	if game.world.island_id == "windchart":
		var player: Vector3 = game.world.player_position
		var position := _wind_point(Vector2(player.x, player.z))
		draw_circle(position, 5, CREAM)
		draw_arc(position, 12, 0, TAU, 24, GOLD, 1)
	_text("WINDCHART NOTES", Vector2(800, 184), 2, GOLD)
	_paragraph(WindStory.objective(game.state), Vector2(800, 225), 32, 2, CREAM)
	_text("NAVIGATION MARKERS %d / 3" % WindStory.marker_count(game.state), Vector2(800, 322), 2, TEAL)
	var notes: Array[String] = ["WIND / AVOID THE EAST REEF", "TIDE / DEEP WATER TO THE SOUTH", "LIGHT / ENTER FROM THE SOUTH"]
	for i in range(3):
		var known: bool = game.state.flags[game.world.windchart.MARKERS[i].role]
		draw_circle(Vector2(810, 376 + i * 47), 5, TEAL if known else MIST)
		_text(notes[i] if known else "UNREAD NAVIGATION MARKER", Vector2(828, 371 + i * 47), 1, CREAM)
	_paragraph("Read all three markers, then use the chart table. Wrong choices cost nothing. Maren can take you back to Rainstep.", Vector2(800, 527), 32, 2, MIST)

func _settings_menu() -> void:
	_text("A COMFORTABLE JOURNEY", Vector2(82, 185), 2, GOLD)
	_button("save", "SAVE JOURNEY NOW", Rect2(82, 242, 430, 51), 2, game.menu_return != "battle")
	_button("mute", "SOUND: OFF" if game.music.muted else "SOUND: ON", Rect2(82, 313, 430, 51), 2)
	_button("effects", "SOFT FOCUS: OFF" if game.reduced_effects else "SOFT FOCUS: ON", Rect2(82, 384, 430, 51), 2)
	_button("language", "LANGUAGE: SIMPLIFIED CHINESE" if Locale.chinese() else "LANGUAGE: ENGLISH", Rect2(82, 450, 430, 43), 2)
	_text("CONTROLS", Vector2(612, 185), 2, GOLD)
	var controls := ["WASD / ARROWS    WALK", "SHIFT           RUN", "E / ENTER       TALK & CONFIRM", "TAB / ESC       SATCHEL & BACK", "J / P           JOURNAL / PARTY", "1-7             BATTLE ACTION", "M / F11         MUTE / FULLSCREEN", "F5              QUICK SAVE"]
	for i in range(controls.size()):
		_text(controls[i], Vector2(612, 238 + i * 34), 2, CREAM)
	_paragraph("Your journey saves after milestones and while exploring. Closing during a battle returns to the last safe save.", Vector2(83, 519), 36, 2, MIST)
	_text("ORIGINAL CODE ART / ORIGINAL SYNTH SCORE / GODOT 4.7.2", Vector2(612, 572), 1, GOLD)

func _ending() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.08, 0.10, 0.9))
	var second: bool = game.ending_chapter == 2
	if second:
		_crest(Vector2(565, 155), 56, GOLD)
		_crest(Vector2(715, 155), 56, TEAL)
		draw_line(Vector2(621, 155), Vector2(659, 155), GOLD, 1)
	else:
		_crest(Vector2(640, 155), 75)
	_center("THE SECOND LIGHT" if second else "THE FIRST LIGHT", Vector2(640, 270), 5, CREAM)
	_center("TWO SEA-LANES SHINE AGAIN." if second else "A SEA-LANE SHINES AGAIN.", Vector2(640, 332), 2, GOLD)
	_center("TWO LIGHTS, ONE SHARED HORIZON." if second else "A SMALL JOURNEY. A REAL DIFFERENCE.", Vector2(640, 382), 2, MIST)
	for i in range(game.state.party.size()):
		var x: float = 640 - game.state.party.size() * 45 + i * 90
		draw_texture_rect(Art.creature(int(game.state.party[i].id), int(game.clock * 2) % 3), Rect2(x, 425, 90, 90), false)
	_center("%d FRIENDSHIPS RECORDED  /  %d MINUTES UNDER THE LANTERNS" % [game.state.collection.size(), int(game.state.play_seconds) / 60], Vector2(640, 541), 1, GOLD)
	_button("ending_continue", "RETURN TO THE ISLAND", Rect2(430, 590, 420, 50), 2)
	_center("LANTERNWAKE / END OF CHAPTER II" if second else "LANTERNWAKE  /  END OF CHAPTER I", Vector2(640, 676), 1, MIST)
