extends SceneTree
## Actual ferry/repair journey with isolated test saves and real movement.
const World = preload("res://scripts/world.gd")
var checks: int = 0
var failures: int = 0

class Harness extends "res://scripts/main.gd":
	func _preferences_path() -> String:
		return "user://rain_journey_preferences_%d.cfg" % OS.get_process_id()
	func _save(_show: bool) -> void:
		state.position = world.player_position
		state.island_id = world.island_id
		state.save_game("user://rain_journey_%d.json" % OS.get_process_id())

func _initialize() -> void:
	var world = World.new()
	check(world.has_method("set_island"), "World supports explicit island transitions")
	check(world.has_method("sync_rain_progress"), "World supports rainwater visual updates")
	world.free()
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
	print("RAIN JOURNEY TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func drain(game: Node) -> void:
	for i in range(12):
		if game.mode != "dialogue":
			return
		game._advance_dialogue()

func walk_to(world: Node, target: Vector3) -> bool:
	for i in range(1200):
		var delta: Vector3 = target - world.player_position
		if delta.length() < 0.08:
			return true
		world.walk(Vector2(delta.x, delta.z).normalized(), 1.0 / 60, false)
	print("RAIN NAV STOP: ", world.player_position, " target ", target)
	return false

func run_journey() -> void:
	var game := Harness.new()
	root.add_child(game)
	await process_frame
	game.state = GameState.new()
	game.state.choose_starter(1)
	game.mode = "explore"
	game.world.set_island("wakeharbor", Vector3(-13, 0, 4.1))
	GameLocale.set_language("en" if OS.get_cmdline_user_args().has("en") else "zh_CN")
	game.interact()
	drain(game)
	check(game.mode == "explore" and game.world.island_id == "wakeharbor", "Ferry is locked before the First Light crest")
	game.state.flags.captured = true
	game.state.flags.rival = true
	game.state.flags.gym = true
	game.interact()
	drain(game)
	check(game.mode == "ferry", "Unlocked ferry offers a destination confirmation")
	game.handle_action("ferry_cancel")
	check(game.mode == "explore" and game.state.island_id == "wakeharbor", "Cancelling travel keeps the original island")
	game.handle_action("ferry_board")
	check(game.state.island_id == "wakeharbor", "Board action outside the confirmation cannot teleport")
	game.interact()
	drain(game)
	game.handle_action("ferry_board")
	check(game.mode == "explore" and game.state.island_id == "rainstep" and game.world.island_id == "rainstep", "Boarding synchronizes model and world island")
	check(game.world.player_position.distance_to(Vector3(60, 0, 8)) < 0.01, "Ferry arrives at a safe dock")
	check(not game.world.can_walk(Vector3(-7, 0, 5)), "Inactive island cannot be reached by direct walking")
	check(game.world.can_walk(game.world.player_position), "Rain arrival position is walkable")
	check(walk_to(game.world, Vector3(60, 0, 5.5)), "Landing leads to the rain village")
	check(walk_to(game.world, Vector3(56, 0, 5.5)), "Keeper is reachable from the dock")
	game.state.orbs = 0
	game.state.tonics = 0
	game.state.party[0].hp = 1
	game.interact()
	drain(game)
	check(game.state.party[0].hp == game.state.party[0].max_hp and game.state.orbs >= 12 and game.state.tonics >= 5, "Orla provides free local rest and supplies")
	var roles: Array[String] = ["rain_upper", "rain_middle", "rain_lower"]
	var paths: Array = [
		[Vector3(60, 0, 5.5), Vector3(60, 0, -6.5), Vector3(52, 0, -6.5)],
		[Vector3(60, 0, -6.5), Vector3(60, 0, -1.5), Vector3(67, 0, -1.5)],
		[Vector3(60, 0, -1.5), Vector3(60, 0, 3.8), Vector3(52, 0, 3.8)],
	]
	for i in range(3):
		for point: Vector3 in paths[i]:
			check(walk_to(game.world, point), "Dry paths and bridges lead to every channel")
		check(game.world.nearby().get("role", "") == roles[i], "Channel interaction is selected correctly")
		check(game.world.encounter_region().is_empty(), "Repairs have a safe encounter-free interaction space")
		game.interact()
		drain(game)
		check(game.state.flags.get(roles[i], false), "Repair progress is recorded by the coordinator")
		check(game.world.rainstep.marker_lights[roles[i]].visible, "Repaired channel has persistent visual feedback")
	game.world.player_position = Vector3(56, 0, 5.5)
	game.interact()
	drain(game)
	check(game.state.flags.rain_rewarded, "Completed waterworks can be reported to Orla")
	var reward_inventory := Vector2i(game.state.orbs, game.state.tonics)
	game.interact()
	drain(game)
	check(Vector2i(game.state.orbs, game.state.tonics) == reward_inventory, "Repeated report cannot farm the reward")
	game.world.player_position = Vector3(66, 0, 4.7)
	check(game.world.encounter_region() == "rainstep", "Rain vegetation has its own encounter region")
	game._wild_encounter()
	check(game.mode == "battle" and game.world.battle_biome == "rainstep", "Rain encounters use the rain diorama")
	game.battle_queue.clear()
	game.battle_timer = 0
	game.handle_action("flee")
	game.battle_queue.clear()
	game.battle_timer = 0
	game._finish_battle()
	check(game.world.area_id() == "rainstep", "Escaping returns to the same island")
	game.state.party[0].hp = 1
	game.start_battle("wild", [CreatureDB.make_creature(6, 12)])
	game.battle_queue.clear()
	game.battle_timer = 0
	game.handle_action("strike")
	check(game.battle.finished and game.battle.outcome == "lost", "Defeat fixture resolves through actual battle controls")
	game.battle_queue.clear()
	game.battle_timer = 0
	game._finish_battle()
	drain(game)
	check(game.world.island_id == "rainstep" and game.world.player_position.distance_to(Vector3(60, 0, 8)) < 0.01, "Defeat returns to the local landing without an island mismatch")
	check(game.state.active().hp == game.state.active().max_hp and game.state.flags.rain_rewarded, "Local recovery heals companions and retains completed waterworks")
	game._open_menu("map")
	check(game.map_rain, "Map opens on the current island")
	game.handle_action("close")
	game._save(false)
	var path: String = "user://rain_journey_%d.json" % OS.get_process_id()
	var loaded := GameState.new()
	check(loaded.load_game(path) and loaded.island_id == "rainstep" and loaded.flags.rain_rewarded, "Rain save reload preserves island and quest")
	game.state = loaded
	game.handle_action("continue")
	check(game.world.island_id == "rainstep" and game.world.rainstep.marker_lights.rain_upper.visible, "Continue restores active island and repaired visuals")
	game.world.player_position = Vector3(60, 0, 8)
	game.interact()
	drain(game)
	game.handle_action("ferry_board")
	check(game.world.island_id == "wakeharbor" and game.state.island_id == "wakeharbor", "Ferry returns to Wakeharbor without cost or new gating")
	check(game.world.player_position.distance_to(Vector3(-13, 0, 4.1)) < 0.01 and game.world.can_walk(game.world.player_position), "Return pier is safe")
	game._new_game()
	check(game.state.island_id == "wakeharbor" and game.world.island_id == "wakeharbor" and not game.state.flags.rain_rewarded, "A new game resets island and new quest together")
	check(not game.world.rainstep.root_node.visible and not game.world.rainstep.marker_lights.rain_upper.visible, "A new game also resets hidden island visuals")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free()
	await process_frame
	finish()
