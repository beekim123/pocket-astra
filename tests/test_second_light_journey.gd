extends SceneTree
var checks: int = 0
var failures: int = 0

class Harness extends "res://scripts/main.gd":
	func _preferences_path() -> String:
		return "user://second_light_preferences_%d.cfg" % OS.get_process_id()
	func _save(_show: bool) -> void:
		state.position = world.player_position
		state.island_id = world.island_id
		state.save_game("user://second_light_%d.json" % OS.get_process_id())

func _initialize() -> void:
	check(ResourceLoader.exists("res://scripts/challenge_db.gd"), "Second chapter uses explicit challenge definitions")
	var source: GDScript = load("res://scripts/rainstep_world.gd")
	var rain = source.new()
	var found: bool = false
	for entry: Dictionary in rain.get_property_list():
		found = found or entry.name == "beacon_light"
	check(found, "Rainstep exposes the second beacon visual state")
	if failures:
		finish()
		return
	call_deferred("run_journey")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func finish() -> void:
	print("SECOND LIGHT JOURNEY TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func drain(game) -> void:
	for i in range(14):
		if game.mode != "dialogue":
			return
		var previous_language: String = GameLocale.language
		GameLocale.set_language("zh_CN")
		for source: String in [str(game.speaker), str(game.dialogue[0])]:
			var translated: String = GameLocale.translate(source)
			check(translated != source, "Actual second-chapter dialogue has a Chinese translation")
			check(PixelFont.has_cjk_support(translated), "Actual second-chapter dialogue has every required glyph")
		GameLocale.set_language(previous_language)
		game._advance_dialogue()

func messages(game) -> void:
	for i in range(24):
		if game.battle_queue.is_empty():
			break
		game._advance_battle_line()
	game.battle_timer = 0

func walk_to(world, target: Vector3) -> bool:
	for i in range(1200):
		var difference: Vector3 = target - world.player_position
		if difference.length() < 0.08:
			return true
		world.walk(Vector2(difference.x, difference.z).normalized(), 1.0 / 60, false)
	return false

func win(game) -> void:
	game.battle.rng.seed = 64
	for i in range(180):
		messages(game)
		if game.battle.finished:
			break
		var player: Dictionary = game.battle.player()
		var action: String = "strike" if CreatureDB.effectiveness(CreatureDB.species(int(player.id)).element, CreatureDB.species(int(game.battle.enemy.id)).element) < 1 else "skill"
		if float(player.hp) / float(player.max_hp) < 0.4 and game.state.tonics > 0:
			action = "tonic"
		game.handle_action(action)
	messages(game)
	check(game.battle.outcome == "won", "Challenge is winnable through real battle controls")
	game._finish_battle()

func run_journey() -> void:
	var game = Harness.new()
	root.add_child(game)
	await process_frame
	game.state = GameState.new()
	game.state.choose_starter(0)
	game.state.party[0] = CreatureDB.make_creature(0, 8)
	game.state.add_creature(8, 7)
	game.state.add_creature(10, 7)
	for key: String in ["captured", "rival", "gym", "rain_arrived"]:
		game.state.flags[key] = true
	game.state.island_id = "rainstep"
	game.mode = "explore"
	game.world.set_island("rainstep", Vector3(60, 0, 8))
	game.world.sync_rain_progress(game.state.flags)
	GameLocale.set_language("en" if OS.get_cmdline_user_args().has("en") else "zh_CN")
	check(not game.world.rainstep.beacon_light.visible, "Second beacon starts unlit")
	check(walk_to(game.world, Vector3(60, 0, -6.5)) and walk_to(game.world, Vector3(63.5, 0, -6.5)), "Existing roads reach Neri without new collision blockers")
	game.interact()
	drain(game)
	check(game.mode == "explore" and not game.state.flags.rain_trial, "Waterworks must be reported before the preparation challenge")
	for key: String in ["rain_started", "rain_upper", "rain_middle", "rain_lower", "rain_rewarded"]:
		game.state.flags[key] = true
	game.interact()
	drain(game)
	check(game.mode == "battle" and game.battle.challenge_id == "rain_trial", "Neri starts the correct independent trainer challenge")
	win(game)
	drain(game)
	check(game.state.flags.rain_trial and not game.state.flags.rain_gym and game.state.flags.gym, "Preparation victory preserves the first sigil and unlocks only the second trial")
	check(walk_to(game.world, Vector3(60, 0, -6.5)) and walk_to(game.world, Vector3(60, 0, -8.6)), "Beacon keeper is reachable along the existing central path")
	game.interact()
	drain(game)
	check(game.mode == "battle" and game.battle.challenge_id == "second_light", "Ilya starts the separate second gym")
	check(game.world.battle_biome == "beacon", "Second gym has an independent battle appearance")
	win(game)
	drain(game)
	check(game.mode == "ending" and game.ending_chapter == 2, "Second victory reaches the second chapter ending")
	check(game.state.flags.rain_gym and game.world.rainstep.beacon_light.visible, "Victory lights the world beacon and records the second sigil")
	var bag := Vector2i(game.state.orbs, game.state.tonics)
	game.handle_action("ending_continue")
	check(game.mode == "explore" and game.world.island_id == "rainstep", "Ending returns to free exploration on Rainstep")
	check(game.toast == "TWO LIGHTS ARE YOURS. RAINSTEP IS ALIVE WITH SONG.", "Second ending returns with a second-chapter exploration message")
	var previous_language: String = GameLocale.language
	GameLocale.set_language("zh_CN")
	check(GameLocale.translate(game.toast) != game.toast and PixelFont.has_cjk_support(GameLocale.translate(game.toast)), "Second ending return message is translated with complete glyphs")
	GameLocale.set_language(previous_language)
	game.interact()
	drain(game)
	check(game.mode == "ending" and game.ending_chapter == 2 and bag == Vector2i(game.state.orbs, game.state.tonics), "Revisiting Ilya replays the ending without duplicate rewards")
	game.handle_action("ending_continue")
	var path: String = "user://second_light_%d.json" % OS.get_process_id()
	var saved := GameState.new()
	check(saved.load_game(path) and saved.flags.rain_gym and saved.flags.gym, "Both chapter victories survive saving")
	game.state = saved
	game.handle_action("continue")
	check(game.world.rainstep.beacon_light.visible, "Continue restores the awakened beacon")
	game._new_game()
	check(not game.world.rainstep.beacon_light.visible and not game.state.flags.rain_gym and game.ending_chapter == 1, "A new adventure resets second-light visuals and ending chapter")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	finish()
