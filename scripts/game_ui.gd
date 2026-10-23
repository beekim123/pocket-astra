extends Control
## All interface geometry and typography are drawn from code. No imported fonts.
const F = preload("res://scripts/pixel_font.gd")
const Art = preload("res://scripts/art.gd")
const DB = preload("res://scripts/creature_db.gd")
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
	for line in F.wrap(value, chars):
		_text(line, Vector2(pos.x, y), size, color)
		y += 7 * size + line_gap
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
	_center(label, rect.get_center() - Vector2(0, size * 3.5), size, color if enabled else Color("607775"))
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
	_text("LANTERN", Vector2(68, 206), 9, CREAM)
	_text("WAKE", Vector2(68, 283), 9, CREAM)
	_text("CHAPTER I  /  THE FIRST LIGHT", Vector2(74, 378), 2, GOLD)
	_text("A SMALL ISLAND. A SONG IN THE REEDS.", Vector2(74, 419), 2, MIST)
	_text("A LIGHT TO GUIDE YOU HOME.", Vector2(74, 446), 2, MIST)
	var y: float = 523
	if game.has_save:
		_button("continue", "CONTINUE JOURNEY", Rect2(73, y, 337, 47))
		y += 57
	_button("new", "BEGIN A NEW JOURNEY", Rect2(73, y, 337, 47))
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
	_text("THE FIRST LIGHT  /  CHAPTER I", Vector2(46, 35), 1, GOLD)
	_text(game.world.area_name(), Vector2(46, 55), 2)
	_panel(Rect2(790, 24, 462, 92), MIST, 0.91)
	_text("YOUR NEXT STEP", Vector2(811, 39), 1, GOLD)
	_paragraph(game.state.quest(), Vector2(811, 59), 35, 2, CREAM, 7)
	for i in range(game.state.party.size()):
		var c: Dictionary = game.state.party[i]
		var x: float = 32 + i * 51
		draw_circle(Vector2(x + 22, 123), 23, Color(0.06, 0.15, 0.18, 0.78))
		draw_texture_rect(Art.creature(int(c.id)), Rect2(x - 4, 96, 52, 52), false)
		draw_rect(Rect2(x + 5, 151, 34, 3), Color("3b514e"))
		draw_rect(Rect2(x + 5, 151, 34 * float(c.hp) / float(c.max_hp), 3), TEAL)
	if show_controls:
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
	_text("FIRST LIGHT TRIAL" if game.battle.kind == "gym" else ("IVO / BRIDGE CHALLENGE" if game.battle.kind == "trainer" else "A SONG IN THE REEDS"), Vector2(42, 37), 2, CREAM)
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
	_text("FIRST LIGHT CREST" if bool(game.state.flags.gym) else "ONE SMALL LIGHT AT A TIME", Vector2(774, 63), 1, GOLD)
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
	_text("VESSELS  %02d     TONICS  %02d     JOURNAL  %02d / 08" % [game.state.orbs, game.state.tonics, game.state.collection.size()], Vector2(71, 654), 1, GOLD)
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
	_text("RELEASING KEEPS ITS JOURNAL ENTRY. FIND IT AGAIN IN THE MEADOW.", Vector2(591, 622), 1, MIST)

func _journal_menu() -> void:
	_text("FIELD JOURNAL", Vector2(73, 166), 2, GOLD)
	for i in range(8):
		var x: float = 70 + (i % 4) * 133
		var y: float = 209 + (i / 4) * 173
		var known: bool = game.state.collection.has(i)
		_button("journal:%d" % i, "", Rect2(x, y, 120, 157))
		draw_texture_rect(Art.creature(i), Rect2(x + 5, y + 9, 110, 110), false, Color.WHITE if known else Color(0.15, 0.23, 0.25, 1))
		_center("%02d" % (i + 1), Vector2(x + 60, y + 125), 2, GOLD if known else MIST)
	var id: int = game.journal_id
	var known: bool = game.state.collection.has(id)
	var info: Dictionary = DB.species(id)
	draw_texture_rect(Art.creature(id, int(game.clock * 2) % 3), Rect2(795, 155, 224, 224), false, Color.WHITE if known else Color(0.15, 0.23, 0.25, 1))
	_center(info.name if known else "UNRECORDED SONG", Vector2(910, 399), 3, CREAM)
	_center(str(info.element).to_upper() if known else "A VOICE IN CANDLE REED", Vector2(910, 441), 1, GOLD)
	_paragraph(info.description if known else "Explore the tall reeds beyond the bridge. Every new friendship writes a page in this journal.", Vector2(660, 477), 43, 2, MIST)
	_text("RECORDED" if known else "NOT YET BEFRIENDED", Vector2(662, 594), 1, TEAL if known else GOLD)

func _map_menu() -> void:
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
	draw_circle(marker, 7, GOLD)
	draw_arc(marker, 12 + sin(game.clock * 3) * 2, 0, TAU, 24, CREAM, 1)
	_text("YOUR JOURNEY", Vector2(800, 184), 2, GOLD)
	var milestones := ["CHOOSE A COMPANION", "CATCH A WILD RESONANT", "DEFEAT IVO", "WIN THE FIRST LIGHT"]
	var keys := ["starter", "captured", "rival", "gym"]
	for i in range(4):
		var y: float = 241 + i * 66
		draw_circle(Vector2(810, y + 6), 5, TEAL if game.state.flags[keys[i]] else MIST)
		_text(milestones[i], Vector2(830, y), 1, CREAM)
	_paragraph("Paths are safe. Walk into the reeds to meet a wild resonant. Mira offers free rest and supplies in the village.", Vector2(800, 527), 32, 2, MIST)

func _settings_menu() -> void:
	_text("A COMFORTABLE JOURNEY", Vector2(82, 185), 2, GOLD)
	_button("save", "SAVE JOURNEY NOW", Rect2(82, 242, 430, 51), 2, game.menu_return != "battle")
	_button("mute", "SOUND: OFF" if game.music.muted else "SOUND: ON", Rect2(82, 313, 430, 51), 2)
	_button("effects", "SOFT FOCUS: OFF" if game.reduced_effects else "SOFT FOCUS: ON", Rect2(82, 384, 430, 51), 2)
	_text("CONTROLS", Vector2(612, 185), 2, GOLD)
	var controls := ["WASD / ARROWS    WALK", "SHIFT           RUN", "E / ENTER       TALK & CONFIRM", "TAB / ESC       SATCHEL & BACK", "J / P           JOURNAL / PARTY", "1-7             BATTLE ACTION", "M / F11         MUTE / FULLSCREEN", "F5              QUICK SAVE"]
	for i in range(controls.size()):
		_text(controls[i], Vector2(612, 238 + i * 34), 2, CREAM)
	_paragraph("Your journey saves after milestones and while exploring. Closing during a battle returns to the last safe save.", Vector2(83, 491), 36, 2, MIST)
	_text("ORIGINAL CODE ART / ORIGINAL SYNTH SCORE / GODOT 4.7.2", Vector2(612, 572), 1, GOLD)

func _ending() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.025, 0.08, 0.10, 0.9))
	_crest(Vector2(640, 155), 75)
	_center("THE FIRST LIGHT", Vector2(640, 270), 5, CREAM)
	_center("A SEA-LANE SHINES AGAIN.", Vector2(640, 332), 2, GOLD)
	_center("A SMALL JOURNEY. A REAL DIFFERENCE.", Vector2(640, 382), 2, MIST)
	for i in range(game.state.party.size()):
		var x: float = 640 - game.state.party.size() * 45 + i * 90
		draw_texture_rect(Art.creature(int(game.state.party[i].id), int(game.clock * 2) % 3), Rect2(x, 425, 90, 90), false)
	_center("%d FRIENDSHIPS RECORDED  /  %d MINUTES UNDER THE LANTERNS" % [game.state.collection.size(), int(game.state.play_seconds) / 60], Vector2(640, 541), 1, GOLD)
	_button("ending_continue", "RETURN TO THE ISLAND", Rect2(430, 590, 420, 50), 2)
	_center("LANTERNWAKE  /  END OF CHAPTER I", Vector2(640, 676), 1, MIST)
