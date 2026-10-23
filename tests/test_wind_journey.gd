extends SceneTree
## Walk the actual new region, using only disposable save paths.
var checks: int = 0
var failures: int = 0

class Harness extends "res://scripts/main.gd":
	func _preferences_path() -> String:
		return "user://wind_preferences_%d.cfg" % OS.get_process_id()
	func _save(_show: bool) -> void:
		state.position = world.player_position
		state.island_id = world.island_id
		state.save_game("user://wind_journey_%d.json" % OS.get_process_id())

func _initialize() -> void:
	call_deferred("run_journey")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func drain(game) -> void:
	for i in range(14):
		if game.mode != "dialogue":
			return
		var previous: String = GameLocale.language
		GameLocale.set_language("zh_CN")
		for text: String in [str(game.speaker), str(game.dialogue[0])]:
			var translated: String = GameLocale.translate(text)
			check(translated != text and PixelFont.has_cjk_support(translated), "Actual Windchart dialogue has complete Chinese text and glyphs")
		GameLocale.set_language(previous)
		game._advance_dialogue()

func walk_to(game, point: Vector3) -> void:
	var reached: bool = false
	for i in range(1000):
		var delta: Vector3 = point - game.world.player_position
		if delta.length() < 0.08:
			reached = true
			break
		game.world.walk(Vector2(delta.x, delta.z).normalized(), 1.0 / 60, false)
	game.state.position = game.world.player_position
	check(reached, "Walkable route reaches " + str(point) + " from " + str(game.world.player_position))

func run_journey() -> void:
	var game := Harness.new()
	root.add_child(game)
	await process_frame
	game.music.set_muted(true)
	GameLocale.set_language("en" if OS.get_cmdline_user_args().has("en") else "zh_CN")
	game.state = GameState.new()
	game.state.choose_starter(0)
	for key: String in ["captured", "rival", "gym", "rain_arrived", "rain_started", "rain_upper", "rain_middle", "rain_lower", "rain_rewarded", "rain_trial"]:
		game.state.flags[key] = true
	game.state.island_id = "rainstep"
	game.world.set_island("rainstep", Vector3(64, 0, 8.2))
	game.mode = "explore"
	game.interact()
	drain(game)
	check(game.mode == "explore" and not game.state.flags.wind_arrived, "New crossing stays locked until second gym")
	game.state.flags.rain_gym = true
	game.interact()
	drain(game)
	check(game.mode == "ferry" and game.ferry_destination == "windchart", "New ferry offers correct destination")
	game._cancel()
	game.handle_action("ferry_board")
	check(game.mode == "explore" and game.state.island_id == "rainstep", "Cancel cannot accidentally board")
	game.interact()
	drain(game)
	game.handle_action("ferry_board")
	check(game.world.island_id == "windchart" and game.state.island_id == "windchart", "Boarding synchronizes region and model")
	check(game.world.windchart.root_node.visible and not game.world.rainstep.root_node.visible, "Only new region helper is visible")
	check(not game.world.can_walk(Vector3(134, 0, 1)), "Open sea between quay and berth is not walkable")
	check(game.world.encounter_region().is_empty(), "Navigation journey has no unplanned encounters")
	game._open_menu("map")
	check(game.map_wind, "Satchel opens current region map")
	game.handle_action("close")
	walk_to(game, Vector3(120, 0, 6))
	walk_to(game, Vector3(116, 0, 6))
	game.state.orbs = 0
	game.state.tonics = 0
	game.state.party[0].hp = 1
	game.interact()
	drain(game)
	check(game.state.party[0].hp == game.state.party[0].max_hp and game.state.orbs >= 12 and game.state.tonics >= 5, "Quay keeper provides free rest and supplies")
	walk_to(game, Vector3(120, 0, 6))
	walk_to(game, Vector3(120, 0, -3))
	game.interact()
	drain(game)
	check(game.mode == "explore" and not game.state.flags.wind_sailed, "Missing notes prevent chart selection")
	var paths: Array = [
		[Vector3(120, 0, -5), Vector3(112, 0, -5)],
		[Vector3(120, 0, -5), Vector3(120, 0, 3), Vector3(128, 0, 3)],
		[Vector3(120, 0, 3), Vector3(120, 0, -6), Vector3(127, 0, -6)],
	]
	for i in range(3):
		for point: Vector3 in paths[i]:
			walk_to(game, point)
		var role: String = game.world.windchart.MARKERS[i].role
		check(game.world.nearby().get("role", "") == role, "Each navigation marker can be selected from dry path")
		game.interact()
		drain(game)
		check(game.state.flags[role] and game.world.windchart.marker_lights[role].visible, "Observation persists and lights its marker")
		if i == 0:
			var partial := GameState.new()
			check(partial.load_game("user://wind_journey_%d.json" % OS.get_process_id()) and partial.flags.wind_wind and not partial.flags.wind_tide, "Partial route notes survive saving")
	walk_to(game, Vector3(120, 0, -6))
	walk_to(game, Vector3(120, 0, -3))
	game.interact()
	drain(game)
	check(game.mode == "route", "Three notes open the route choices")
	var departure: Vector3 = game.world.player_position
	var inventory := Vector2i(game.state.orbs, game.state.tonics)
	for route: String in ["north", "east"]:
		game.handle_action("route:" + route)
		drain(game)
		check(game.mode == "route" and not game.state.flags.wind_sailed and game.world.player_position == departure and inventory == Vector2i(game.state.orbs, game.state.tonics), "Incorrect route explains and retries with no loss")
	game._cancel()
	check(game.mode == "explore", "Route choices can be cancelled")
	game.handle_action("route:south")
	check(not game.state.flags.wind_sailed, "Route action outside selector cannot teleport")
	game.interact()
	drain(game)
	game.handle_action("route:south")
	drain(game)
	check(game.mode == "explore" and game.world.area_id() == "lee_berth" and game.state.flags.wind_sailed, "South route arrives at the separate sheltered berth")
	walk_to(game, Vector3(140, 0, -1))
	game.interact()
	drain(game)
	check(game.state.flags.wind_rewarded and game.world.windchart.berth_light.visible, "Sela completes story and awakens berth lamp")
	var prize := Vector2i(game.state.orbs, game.state.tonics)
	game.interact()
	drain(game)
	check(prize == Vector2i(game.state.orbs, game.state.tonics), "Revisiting Sela never repeats reward")
	var path: String = "user://wind_journey_%d.json" % OS.get_process_id()
	var loaded := GameState.new()
	check(loaded.load_game(path) and loaded.island_id == "windchart" and loaded.flags.wind_rewarded, "Completed berth save reloads")
	game.state = loaded
	game.handle_action("continue")
	check(game.world.area_id() == "lee_berth" and game.world.windchart.berth_light.visible, "Continue restores berth and progress visuals")
	walk_to(game, Vector3(140, 0, 3.7))
	game.interact()
	check(game.world.area_id() == "windchart" and game.world.player_position == Vector3(120, 0, 8), "Local skiff returns free to quay")
	game.interact()
	drain(game)
	game.handle_action("ferry_board")
	check(game.world.island_id == "rainstep" and game.world.can_walk(game.world.player_position), "Return ferry reaches safe Rainstep pier")
	walk_to(game, Vector3(60, 0, 7))
	walk_to(game, Vector3(60, 0, 8))
	game.interact()
	drain(game)
	game.handle_action("ferry_board")
	check(game.world.island_id == "wakeharbor" and game.state.flags.wind_rewarded, "Original ferry returns home with navigation progress intact")
	game._new_game()
	check(not game.world.windchart.root_node.visible and not game.world.windchart.berth_light.visible and not game.state.flags.wind_arrived, "New journey resets hidden port and all progress")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	print("WIND JOURNEY TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
