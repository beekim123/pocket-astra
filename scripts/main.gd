extends Node
## Scene coordinator: the journey is an explicit set of UI/gameplay states.

const DB = preload("res://scripts/creature_db.gd")
const State = preload("res://scripts/game_state.gd")
const Rules = preload("res://scripts/battle.gd")
const World = preload("res://scripts/world.gd")
const UI = preload("res://scripts/game_ui.gd")
const Music = preload("res://scripts/music.gd")
const Locale = preload("res://scripts/localization.gd")
const Preferences = preload("res://scripts/preferences.gd")

var state: GameState = State.new()
var world: LanternWorld
var hud: Control
var music: ProceduralMusic
var battle: Battle
var mode: String = "title"
var menu_tab: String = "party"
var menu_return: String = "explore"
var selection: int = 0
var chosen_creature: int = 0
var journal_id: int = 0
var release_pending: bool = false
var has_save: bool = false
var dialogue: Array[String] = []
var speaker: String = "EDDA"
var dialogue_after: Callable
var battle_queue: Array[String] = []
var battle_lines: Array[String] = []
var battle_timer: float = 0.0
var battle_effect: float = 0.0
var last_action: String = ""
var toast: String = ""
var toast_time: float = 0.0
var clock: float = 0.0
var encounter_distance: float = 0.0
var encounter_target: float = 6.0
var encounter_cooldown: float = 0.0
var area_text: String = "WAKEHARBOR"
var area_timer: float = 0.0
var save_timer: float = 0.0
var step_distance: float = 0.0
var reduced_effects: bool = false
var postprocess: ColorRect
var rng := RandomNumberGenerator.new()
var _quitting: bool = false
var preferences := Preferences.new()

func _ready() -> void:
	Engine.max_fps = 60
	preferences.load_settings(_preferences_path())
	Locale.set_language(preferences.language)
	rng.randomize()
	_setup_input()
	world = World.new()
	add_child(world)
	music = Music.new()
	add_child(music)
	var grade_layer := CanvasLayer.new()
	grade_layer.layer = 1
	add_child(grade_layer)
	postprocess = ColorRect.new()
	postprocess.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	postprocess.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grade := ShaderMaterial.new()
	grade.shader = preload("res://shaders/diorama.gdshader")
	postprocess.material = grade
	grade_layer.add_child(postprocess)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)
	hud = UI.new()
	hud.game = self
	ui_layer.add_child(hud)
	var saved := State.new()
	has_save = saved.load_game()
	if has_save:
		state = saved
	music.set_theme("title")
	get_tree().auto_accept_quit = false

func _setup_input() -> void:
	var mappings := {
		"walk_left": [KEY_A, KEY_LEFT], "walk_right": [KEY_D, KEY_RIGHT],
		"walk_up": [KEY_W, KEY_UP], "walk_down": [KEY_S, KEY_DOWN],
		"run": [KEY_SHIFT],
	}
	for action in mappings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in mappings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	clock += delta
	toast_time = maxf(0, toast_time - delta)
	area_timer = maxf(0, area_timer - delta)
	encounter_cooldown = maxf(0, encounter_cooldown - delta)
	battle_effect = maxf(0, battle_effect - delta)
	if mode != "title" and mode != "new_confirm":
		state.play_seconds += delta
	if mode == "explore":
		var input := Input.get_vector("walk_left", "walk_right", "walk_up", "walk_down")
		if input.length() < 0.1:
			input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var traveled: float = world.walk(input, delta, Input.is_action_pressed("run"))
		state.position = world.player_position
		step_distance += traveled
		if step_distance > 1.1:
			step_distance = 0
			music.sfx("step")
		var area: String = world.area_name()
		if area != area_text:
			area_text = area
			area_timer = 3.3
			music.set_theme("village" if world.player_position.x < 0 else "wild")
		if bool(state.flags.starter) and world.is_grass() and encounter_cooldown <= 0:
			encounter_distance += traveled
			if encounter_distance >= encounter_target:
				encounter_distance = 0
				encounter_target = rng.randf_range(5.5, 9)
				_wild_encounter()
		save_timer += delta
		if save_timer >= 35.0 and bool(state.flags.starter):
			save_timer = 0
			_save(false)
	else:
		world.moving = false
	if mode == "battle":
		battle_timer = maxf(0, battle_timer - delta)
		if battle_timer <= 0 and not battle_queue.is_empty():
			_advance_battle_line()
		if battle != null and not battle.player().is_empty():
			world.battle_ids = Vector2i(int(battle.player().id), int(battle.enemy.id))
	hud.queue_redraw()

func _input(event: InputEvent) -> void:
	if _quitting:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var action: String = hud.button_at(hud.get_local_mouse_position())
		if action != "":
			handle_action(action)
		return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			_confirm()
		elif event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START:
			_cancel()
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	if key == KEY_L:
		handle_action("language")
		return
	if key == KEY_F11:
		var fullscreen: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if key == KEY_M:
		music.set_muted(not music.muted)
		notify("SOUND OFF" if music.muted else "SOUND ON")
		return
	if key == KEY_ESCAPE or key == KEY_TAB:
		_cancel()
		return
	if key == KEY_ENTER or key == KEY_KP_ENTER or key == KEY_SPACE or key == KEY_E:
		_confirm()
		return
	if mode == "explore":
		if key == KEY_J:
			_open_menu("journal")
		if key == KEY_P:
			_open_menu("party")
		if key == KEY_F5:
			_save(true)
		return
	if mode == "starter" and key >= KEY_1 and key <= KEY_3:
		handle_action("starter:%d" % (key - KEY_1))
		return
	if mode == "battle" and battle_queue.is_empty() and battle_timer <= 0:
		var actions := ["strike", "skill", "capture", "tonic", "guard", "switch", "flee"]
		if key >= KEY_1 and key <= KEY_7:
			handle_action(actions[key - KEY_1])
			return
	if key in [KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S]:
		selection = posmod(selection + 1, maxi(1, hud.buttons.size()))
		music.sfx("confirm")
	elif key in [KEY_LEFT, KEY_UP, KEY_A, KEY_W]:
		selection = posmod(selection - 1, maxi(1, hud.buttons.size()))
		music.sfx("confirm")

func _confirm() -> void:
	match mode:
		"explore": interact()
		"dialogue": _advance_dialogue()
		"battle":
			if not battle_queue.is_empty():
				_advance_battle_line()
			elif battle_timer > 0:
				battle_timer = 0
			elif battle.finished:
				_finish_battle()
			elif not hud.buttons.is_empty():
				handle_action(hud.buttons[selection % hud.buttons.size()].action)
		_:
			if not hud.buttons.is_empty():
				handle_action(hud.buttons[selection % hud.buttons.size()].action)

func _cancel() -> void:
	if mode == "explore":
		_open_menu("party")
	elif mode == "menu":
		mode = menu_return
		release_pending = false
		selection = 0
	elif mode == "new_confirm":
		mode = "title"
		selection = 0
	elif mode == "dialogue":
		_advance_dialogue()

func handle_action(action: String) -> void:
	music.sfx("confirm")
	if action.begins_with("starter:"):
		_choose_starter(int(action.get_slice(":", 1)))
		return
	if action.begins_with("tab:"):
		menu_tab = action.get_slice(":", 1)
		release_pending = false
		selection = ["party", "journal", "map", "settings"].find(menu_tab)
		return
	if action.begins_with("party:"):
		chosen_creature = int(action.get_slice(":", 1))
		release_pending = false
		return
	if action.begins_with("journal:"):
		journal_id = int(action.get_slice(":", 1))
		return
	match action:
		"language":
			Locale.set_language("en" if Locale.chinese() else "zh_CN")
			preferences.language = Locale.language
			if not preferences.save_settings(_preferences_path()):
				notify("COULD NOT SAVE LANGUAGE PREFERENCE.")
			else:
				notify("LANGUAGE: SIMPLIFIED CHINESE" if Locale.chinese() else "LANGUAGE: ENGLISH")
		"new":
			if has_save:
				mode = "new_confirm"
				selection = 0
			else:
				_new_game()
		"new_yes": _new_game()
		"new_no":
			mode = "title"
			selection = 0
		"continue":
			world.player_position = state.position if world.can_walk(state.position) else State.HOME_POSITION
			world.companion_id = int(state.active().id) if not state.active().is_empty() else -1
			mode = "explore"
			selection = 0
			music.set_theme("village")
			area_timer = 3.0
		"interact": interact()
		"next": _advance_dialogue()
		"menu": _open_menu("party")
		"close": _cancel()
		"save": _save(true)
		"mute": music.set_muted(not music.muted)
		"effects":
			reduced_effects = not reduced_effects
			postprocess.visible = not reduced_effects
		"lead":
			if state.party.is_empty():
				return
			if menu_return == "battle":
				var index := chosen_creature
				mode = "battle"
				selection = 0
				_perform("switch", index)
			else:
				var chosen: Dictionary = state.party[chosen_creature]
				state.party.remove_at(chosen_creature)
				state.party.push_front(chosen)
				chosen_creature = 0
				world.companion_id = int(state.active().id)
				_save(false)
				notify("YOUR LEAD COMPANION IS READY.")
		"release":
			if state.party.size() <= 1 or menu_return == "battle":
				notify("KEEP AT LEAST ONE COMPANION WITH YOU.")
			elif not release_pending:
				release_pending = true
			else:
				state.party.remove_at(chosen_creature)
				chosen_creature = 0
				release_pending = false
				world.companion_id = int(state.active().id)
				_save(false)
				notify("RELEASED TO THE MEADOW. JOURNAL ENTRY KEPT.")
		"strike", "skill", "guard", "capture", "tonic", "flee": _perform(action)
		"switch":
			if mode == "battle" and not battle.finished and battle_queue.is_empty() and battle_timer <= 0:
				_open_menu("party")
		"battle_done": _finish_battle()
		"ending_continue":
			mode = "explore"
			music.set_theme("wild")
			notify("THE FIRST LIGHT IS YOURS. THE MEADOW IS STILL ALIVE.")
		"quit":
			_request_quit()

func _new_game() -> void:
	state = State.new()
	world.player_position = State.HOME_POSITION
	world.companion_id = -1
	selection = 0
	encounter_distance = 0
	area_timer = 3.0
	say("EDDA / LANTERN KEEPER", [
		"Every island has a song. Ours has been quiet since the great mist swallowed the sea-lanes.",
		"But the little creatures still remember. We call them resonants. They carry a spark of the old song.",
		"Find a companion. Listen to the meadow. Then bring your own light to Soren's lighthouse.",
	], func(): mode = "starter"; selection = 0)
	music.set_theme("village")

func _choose_starter(id: int) -> void:
	if mode != "starter":
		return
	state.choose_starter(id)
	world.companion_id = id
	_save(false)
	say("EDDA / A SMALL BEGINNING", [
		"%s chooses you, too. A partnership begins with a little trust." % DB.species(id).name,
		"Take 12 echo vessels and 5 tonics. Cross the wooden bridge, then step off the stone path into the reeds.",
		"Weaken a wild resonant, then use CAPTURE. Your first catch is certain below half health. Mira can heal and refill supplies for free.",
	], func(): mode = "explore"; selection = 0)

func say(who: String, lines: Array, after: Callable = Callable()) -> void:
	speaker = who
	dialogue.clear()
	for line in lines:
		dialogue.append(str(line))
	dialogue_after = after
	mode = "dialogue"
	selection = 0

func _advance_dialogue() -> void:
	if dialogue.size() > 1:
		dialogue.pop_front()
	else:
		dialogue.clear()
		mode = "explore"
		if dialogue_after.is_valid():
			var callback := dialogue_after
			dialogue_after = Callable()
			callback.call()
	music.sfx("confirm")

func interact() -> void:
	if mode != "explore":
		return
	var npc: Dictionary = world.nearby()
	if npc.is_empty():
		notify("WALK TO A PERSON OR SIGN, THEN PRESS E.")
		return
	match str(npc.role):
		"mentor":
			say(npc.name, ["The lighthouse is no place for a lonely hero. Catch a friend in Candle Reed, meet Ivo at the bridge, and listen to what Soren has to say.", "EMBER warms GROVE. GROVE drinks TIDE. TIDE cools EMBER. A plain Strike is useful when your own element is resisted."])
		"healer":
			state.heal_all()
			state.orbs = maxi(state.orbs, 12)
			state.tonics = maxi(state.tonics, 5)
			music.sfx("heal")
			_save(false)
			say(npc.name, ["A warm meal, a little quiet, and you're ready again. Your party is fully rested. Vessels and tonics have been refilled.", "Come back whenever you need. A journey should test your courage, not your purse."])
		"rival":
			if bool(state.flags.rival):
				say(npc.name, ["Your companions are singing in time now. Soren is waiting by the lighthouse to the north. I'll keep the bridge lit."])
			elif not bool(state.flags.captured):
				say(npc.name, ["Catch one wild resonant first! Step into the reeds beside this path. Weaken it with Strike, then throw an echo vessel."])
			else:
				say(npc.name, ["Two sparks already? Then let's see how they move together. I'll give your team a quick rest before we begin."], func(): state.heal_all(); start_battle("trainer", [DB.make_creature(4, 4), DB.make_creature(5, 5)]))
		"keeper":
			if bool(state.flags.gym):
				say(npc.name, ["Look beyond the mist. That is a sea-lane, shining again. The First Light crest belongs to you.", "There are eight resonants on this island. Your field journal remembers every friendship, even after a release."])
			elif not bool(state.flags.captured) or not bool(state.flags.rival):
				say(npc.name, ["The First Light trial asks for trust and practice. Befriend one wild resonant, then earn Ivo's respect at the bridge.", "Return with those two experiences, and we will wake this tower together."])
			else:
				say(npc.name, ["The first light is not a flame. It is the choice to care for something smaller than yourself.", "Your companions may rest here. When you are ready, face my Voltkite and Noctulume. Let us hear your song."], func(): state.heal_all(); start_battle("gym", [DB.make_creature(6, 6), DB.make_creature(7, 7)]))
		"sign":
			say(npc.name, ["CANDLE REED FIELD NOTES: Wild resonants hide away from the stone paths. Their outlines stir where the grass grows tall.", "Capture is certain at one-quarter health; your very first catch needs only half health. Strike is gentler than a signature move.", "P opens your party. J opens the journal. Set a new lead to train another friend. A full party can release a companion while keeping its journal entry."])
		"cache":
			if bool(state.flags.get("cache", false)):
				say(npc.name, ["An empty box. Beneath the lid: 'Leave a little light for the next traveller.'"])
			else:
				state.flags.cache = true
				state.orbs += 4
				state.tonics += 2
				_save(false)
				say(npc.name, ["You found 4 echo vessels and 2 tonics! A note reads: 'For whoever chooses the longer road.'"])

func _wild_encounter() -> void:
	var id: int = 3
	var level: int = 3
	if bool(state.flags.captured):
		var table := [3, 4, 5, 3, 4, 5, 0, 1, 2, 6, 7]
		id = table[rng.randi_range(0, table.size() - 1)]
		level = rng.randi_range(3, 5) + (1 if bool(state.flags.gym) else 0)
	start_battle("wild", [DB.make_creature(id, level)])

func start_battle(kind: String, enemies: Array[Dictionary]) -> void:
	battle = Rules.new()
	battle.begin(state, kind, enemies)
	mode = "battle"
	selection = 1
	battle_lines.clear()
	battle_queue.assign(battle.log)
	battle_timer = 0
	world.set_battle(true, int(battle.player().id), int(battle.enemy.id))
	music.set_theme("gym" if kind == "gym" else "battle")

func _perform(action: String, index: int = 0) -> void:
	if mode != "battle" or not battle_queue.is_empty() or battle_timer > 0 or battle.finished:
		return
	last_action = action
	var events: Array[String] = battle.act(action, index)
	battle_queue.assign(events)
	battle_timer = 0
	battle_effect = 1.0
	world.battle_pulse = 1.0
	if action == "capture":
		music.sfx("capture")
	elif action == "guard" or action == "tonic":
		music.sfx("heal")
	else:
		music.sfx("hit")
	if battle.finished:
		if battle.outcome in ["won", "captured"]:
			music.sfx("win")
		else:
			music.sfx("lose" if battle.outcome == "lost" else "confirm")

func _advance_battle_line() -> void:
	if battle_queue.is_empty():
		return
	battle_lines.append(battle_queue.pop_front())
	while battle_lines.size() > 2:
		battle_lines.pop_front()
	battle_timer = 0.75

func _finish_battle() -> void:
	if battle == null or not battle.finished or not battle_queue.is_empty() or battle_timer > 0:
		return
	world.set_battle(false)
	mode = "explore"
	menu_return = "explore"
	selection = 0
	encounter_distance = 0
	encounter_cooldown = 3.0
	if battle.outcome == "lost":
		world.player_position = state.position
	world.companion_id = int(state.active().id)
	_save(false)
	music.set_theme("village" if world.player_position.x < 0 else "wild")
	if battle.kind == "gym" and battle.outcome == "won":
		music.set_theme("victory")
		say("SOREN / THE FIRST LIGHT", [
			"There it is. Not the loudest song, but one that knows when to listen. The tower remembers.",
			"Take the First Light crest. Tonight, a fishing boat will find its way home because you and your companions came here.",
			"The mist is wide. But so is the world beyond it. Let this be the first small light of many.",
		], func(): mode = "ending"; selection = 0)
	elif battle.kind == "trainer" and battle.outcome == "won":
		say("IVO / A PROMISE KEPT", ["That was a real song! Take these supplies. The stone path north leads to the First Light Sanctum.", "Soren has two companions. Bring a friend, use tonics when you need them, and don't forget you can switch."])
	elif battle.outcome == "lost":
		say("MIRA / TRY AGAIN", ["I found you on the path. Everyone is safe and rested, and I packed a few spare supplies. Nothing important was lost."])

func _open_menu(tab: String) -> void:
	menu_return = mode
	mode = "menu"
	menu_tab = tab
	selection = ["party", "journal", "map", "settings"].find(tab)
	chosen_creature = 0
	release_pending = false

func _save(show_message: bool) -> void:
	if not bool(state.flags.starter):
		return
	state.position = world.player_position
	var success: bool = state.save_game()
	if success:
		has_save = true
	if show_message or not success:
		notify("JOURNEY SAVED." if success else "COULD NOT SAVE. CHECK DISK PERMISSIONS.")

func notify(message: String) -> void:
	toast = message
	toast_time = 3.2

func _preferences_path() -> String:
	return "user://preferences.cfg"

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()

func can_save_current_scene() -> bool:
	return bool(state.flags.starter) and mode not in ["title", "new_confirm", "battle", "starter"] and not (mode == "menu" and menu_return == "battle")

func _request_quit() -> void:
	if _quitting:
		return
	_quitting = true
	if can_save_current_scene():
		_save(false)
	if is_instance_valid(music):
		music.shutdown()
	# Let AudioServer release its mixing reference before process teardown.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()
