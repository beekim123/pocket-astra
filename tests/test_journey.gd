extends SceneTree
## Runs the real scene coordinator through the complete first chapter.
const DB = preload("res://scripts/creature_db.gd")
var checks: int = 0
var failures: int = 0

class Harness extends "res://scripts/main.gd":
	func _preferences_path() -> String:
		return "user://journey_test_preferences_%d.cfg" % OS.get_process_id()

	func _save(_show_message: bool) -> void:
		state.position = world.player_position
		state.save_game("user://journey_test_only.json")

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)

func drain_dialogue(game: Node) -> void:
	for i in range(12):
		if game.mode != "dialogue":
			break
		game._advance_dialogue()

func drain_battle(game: Node) -> void:
	for i in range(20):
		if game.battle_queue.is_empty():
			break
		game._advance_battle_line()
	game.battle_timer = 0

func win_battle(game: Node) -> void:
	for i in range(100):
		drain_battle(game)
		if game.battle.finished:
			break
		var p: Dictionary = game.battle.player()
		var action: String = "skill"
		if DB.effectiveness(DB.species(int(p.id)).element, DB.species(int(game.battle.enemy.id)).element) < 1:
			action = "strike"
		if float(p.hp) / float(p.max_hp) < 0.4 and game.state.tonics > 0:
			action = "tonic"
		game.handle_action(action)
	drain_battle(game)
	check(game.battle.outcome == "won", "battle is won through coordinator")
	game._finish_battle()

func _run() -> void:
	var game := Harness.new()
	root.add_child(game)
	await process_frame
	check(game.mode == "title", "opens on title")
	check(GameLocale.chinese(), "a clean start displays Chinese")
	game.handle_action("language")
	check(GameLocale.language == "en", "language toggles without leaving title")
	game.handle_action("language")
	check(GameLocale.chinese(), "language toggles back to Chinese")
	var language: String = "en" if OS.get_cmdline_user_args().has("en") else "zh_CN"
	GameLocale.set_language(language)
	game.has_save = false
	game.handle_action("new")
	drain_dialogue(game)
	check(game.mode == "starter", "intro leads to starter choice")
	game.handle_action("starter:0")
	drain_dialogue(game)
	check(game.mode == "explore" and game.state.party.size() == 1, "starter leads to exploration")
	game.mode = "title"
	check(not game.can_save_current_scene(), "closing title cannot overwrite saved map position")
	game.mode = "explore"
	game.menu_return = "battle"
	check(game.can_save_current_scene(), "stale battle menu history does not suppress exploration save")
	game.mode = "menu"
	check(not game.can_save_current_scene(), "combat menu cannot save an unfinished battle")
	game.mode = "explore"
	game.menu_return = "explore"
	# Real movement/collision checks along the route to the first encounter.
	game.world.player_position = Vector3(-7, 0, 4.1)
	for i in range(220):
		game.world.walk(Vector2.RIGHT, 1.0/60.0, false)
	check(game.world.player_position.x > 4.0, "bridge is walkable across the river")
	check(not game.world.can_walk(Vector3(0, 0, 0)), "river banks block walking into water")
	check(not game.world.can_walk(Vector3(-11, 0, -1.2)), "houses block movement")
	game.world.player_position = Vector3(6, 0, 2)
	check(game.world.is_grass(), "reeds are an encounter zone")
	game._wild_encounter()
	drain_battle(game)
	check(game.mode == "battle" and game.battle.kind == "wild", "wild encounter opens real battle")
	game.battle.rng.seed = 50
	for i in range(3):
		if float(game.battle.enemy.hp) / float(game.battle.enemy.max_hp) <= 0.5:
			break
		game.handle_action("strike")
		drain_battle(game)
	game.handle_action("capture")
	drain_battle(game)
	check(game.battle.outcome == "captured", "weakened first encounter captured")
	game._finish_battle()
	check(game.state.flags.captured and game.state.party.size() == 2, "capture advances quest")
	game.world.player_position = Vector3(3.3, 0, 4.4)
	game.interact()
	drain_dialogue(game)
	check(game.mode == "battle" and game.battle.kind == "trainer", "Ivo launches trainer battle")
	game.battle.rng.seed = 51
	win_battle(game)
	drain_dialogue(game)
	check(game.state.flags.rival and game.mode == "explore", "trainer victory opens lighthouse quest")
	# Rest and free supplies are a repeatable no-softlock recovery path.
	game.world.player_position = Vector3(-11.4, 0, 4.2)
	game.state.orbs = 0
	game.state.tonics = 0
	game.interact()
	drain_dialogue(game)
	check(game.state.orbs >= 12 and game.state.tonics >= 5, "Mira refills supplies")
	game.world.player_position = Vector3(9, 0, -4.8)
	game.interact()
	drain_dialogue(game)
	check(game.mode == "battle" and game.battle.kind == "gym", "Soren launches gym battle")
	game.battle.rng.seed = 52
	win_battle(game)
	drain_dialogue(game)
	check(game.mode == "ending" and game.state.flags.gym, "full journey reaches ending")
	game.handle_action("ending_continue")
	check(game.mode == "explore", "postgame remains playable")
	game.handle_action("menu")
	game.handle_action("tab:journal")
	check(game.mode == "menu" and game.menu_tab == "journal", "journal can be opened")
	game.handle_action("close")
	var saved := GameState.new()
	check(saved.load_game("user://journey_test_only.json") and saved.flags.gym, "ending persists in save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://journey_test_only.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game._preferences_path()))
	game.queue_free()
	await process_frame
	print("JOURNEY TESTS [%s]: %d checks, %d failures" % [language, checks, failures])
	quit(0 if failures == 0 else 1)
