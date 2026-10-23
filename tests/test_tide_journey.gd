extends SceneTree
## Integration and navigation checks use the actual coordinator and world.
const World = preload("res://scripts/world.gd")
var checks: int = 0
var failures: int = 0

class Harness extends "res://scripts/main.gd":
	func _preferences_path() -> String:
		return "user://tide_journey_preferences_%d.cfg" % OS.get_process_id()
	func _save(_show: bool) -> void:
		state.position = world.player_position
		state.save_game("user://tide_journey_%d.json" % OS.get_process_id())

func _initialize() -> void:
	var world = World.new()
	check(world.has_method("area_id"), "World exposes stable region identifiers")
	check(world.has_method("encounter_region"), "World exposes region-specific encounter patches")
	check(world.has_method("sync_tide_progress"), "World exposes tide quest visual updates")
	world.free()
	if failures > 0:
		finish()
		return
	call_deferred("run_journey")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + message)

func finish() -> void:
	print("TIDE JOURNEY TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func drain(game: Node) -> void:
	for i in range(12):
		if game.mode != "dialogue":
			return
		game._advance_dialogue()

func walk_segment(world: Node, target: Vector3) -> bool:
	for i in range(1000):
		var difference: Vector3 = target - world.player_position
		if difference.length() < 0.08:
			return true
		# A held direction key has unit strength; don't enter analog input deadzone.
		world.walk(Vector2(difference.x, difference.z).normalized(), 1.0 / 60.0, false)
	print("NAVIGATION STOP: ", world.player_position, " target ", target)
	return false

func run_journey() -> void:
	var game := Harness.new()
	root.add_child(game)
	await process_frame
	game.state = GameState.new()
	game.state.choose_starter(1)
	game.world.sync_tide_progress(game.state.flags)
	GameLocale.set_language("en" if OS.get_cmdline_user_args().has("en") else "zh_CN")
	game.mode = "explore"
	game.world.player_position = Vector3(-7, 0, 7.5)
	check(walk_segment(game.world, Vector3(-7, 0, 13.7)), "Village connects continuously to causeway and shore")
	check(game.world.area_id() == "tidepools", "Causeway arrival is a distinct region")
	check(not game.world.can_walk(Vector3(-10, 0, 16)), "Shallow tide pool cannot be walked through")
	check(not game.world.can_walk(Vector3(-1, 0, 16)), "Open ocean remains blocked")
	check(walk_segment(game.world, Vector3(-3.2, 0, 13.7)), "Eastern shore path is clear")
	check(walk_segment(game.world, Vector3(-3.2, 0, 21.7)), "Dry eastern bank reaches rescue point")
	check(game.world.nearby().get("role", "") == "tide_rescue", "Rescue target is interactable from the dry path")
	while game.state.party.size() < 6:
		game.state.add_creature(4, 3)
	game.state.orbs = 0
	game.state.tonics = 0
	game.interact()
	drain(game)
	check(game.state.flags.get("tide_rescued", false), "Real interaction rescues Wispip without capture or a free party slot")
	check(game.state.party.size() == 6 and game.state.orbs == 0, "Rescue does not alter party or spend inventory")
	check(not game.state.flags.captured and not game.state.flags.rival and not game.state.flags.gym, "Optional rescue does not skip main story flags")
	var points: Array[Vector3] = [Vector3(-11.8, 0, 14.3), Vector3(-12, 0, 21.4), Vector3(-3.5, 0, 16.2)]
	var roles: Array[String] = ["tide_wind", "tide_water", "tide_brass"]
	var marker_routes: Array = [
		[Vector3(-3.2, 0, 13.7), Vector3(-11.8, 0, 13.7), points[0]],
		[Vector3(-12, 0, 14.3), points[1]],
		[Vector3(-3.2, 0, 21.4), Vector3(-3.2, 0, 16.2), points[2]],
	]
	for i in range(points.size()):
		check(game.world.can_walk(points[i]), "Each marker has walkable ground")
		for waypoint: Vector3 in marker_routes[i]:
			check(walk_segment(game.world, waypoint), "Every marker is reached by walking around the pools")
		check(game.world.nearby().get("role", "") == roles[i], "Each marker resolves the correct interaction")
		check(game.world.encounter_region() == "", "Marker interaction area is free of wild encounters")
		game.interact()
		drain(game)
		check(game.state.flags.get(roles[i], false), "Marker progress is recorded through coordinator")
		check(game.world.tidepools.marker_lights[roles[i]].visible, "Recorded marker has persistent visible feedback")
	game.world.player_position = Vector3(-8.6, 0, 8.5)
	check(game.world.nearby().get("role", "") == "tide_artisan", "Returned Wispip cannot block the artisan interaction")
	check(game.world.tidepools.rescue.position.distance_to(Vector3(-9, 0.66, 8.5)) < 0.01, "Rescued Wispip visibly returns to harbor")
	game.interact()
	drain(game)
	check(game.state.flags.get("tide_rewarded", false) and game.state.orbs == 4 and game.state.tonics == 2, "Artisan gives exactly one rescue reward")
	game.interact()
	drain(game)
	check(game.state.orbs == 4 and game.state.tonics == 2, "Repeat interaction cannot duplicate rewards")
	game.world.player_position = Vector3(-11.5, 0, 19.0)
	check(game.world.encounter_region() == "tidepools", "Seaweed patch uses the tidepool encounter table")
	game.state.flags.captured = true
	game._wild_encounter()
	check(game.mode == "battle" and int(game.battle.enemy.id) in [1, 3, 4], "Regional wild encounter is playable")
	check(game.world.battle_biome == "tidepools", "Shore battles receive their own diorama palette")
	game.battle_queue.clear()
	game.battle_timer = 0
	game.handle_action("flee")
	game.battle_queue.clear()
	game.battle_timer = 0
	game._finish_battle()
	check(game.mode == "explore" and game.world.area_id() == "tidepools", "Leaving a shore battle returns to the shore")
	var save_path: String = "user://tide_journey_%d.json" % OS.get_process_id()
	var restored := GameState.new()
	check(restored.load_game(save_path) and restored.flags.get("tide_rewarded", false), "Scene saves preserve completed rescue")
	game.state = restored
	game.handle_action("continue")
	check(game.world.area_id() == "tidepools" and game.world.tidepools.marker_lights.tide_brass.visible, "Continuing a shore save restores position and observations")
	game._open_menu("map")
	check(game.map_shore, "Map opens on current shore region")
	game.handle_action("map_island")
	check(not game.map_shore, "Map can show route back to main island")
	game.handle_action("map_shore")
	check(game.map_shore, "Map can return to shore details")
	game.handle_action("close")
	game.world.player_position = Vector3(-3.2, 0, 13.7)
	check(walk_segment(game.world, Vector3(-7, 0, 13.7)), "Return route crosses the dry upper shore")
	check(walk_segment(game.world, Vector3(-7, 0, 7.5)), "Return causeway leads safely to original village")
	game._new_game()
	check(not game.state.flags.tide_rescued and game.world.tidepools.rescue.position.distance_to(Vector3(-4.5, 0.66, 21.7)) < 0.01, "New journey resets both rescue rules and scene appearance")
	for role: String in roles:
		check(not game.world.tidepools.marker_lights[role].visible, "New journey clears marker illumination")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.queue_free()
	await process_frame
	finish()
