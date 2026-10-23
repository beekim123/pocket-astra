extends SceneTree
## Actual GPU-rendered evidence. Outputs go outside the source-only project.
const Game = preload("res://tests/capture_game.gd")
const DB = preload("res://scripts/creature_db.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = Game.new()
	root.add_child(game)
	await process_frame
	game.music.set_muted(true)
	var view: String = "title"
	var output: String = "/tmp/lanternwake-title.png"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		view = args[0]
	if args.size() > 1:
		output = args[1]
	preload("res://scripts/localization.gd").set_language(args[2] if args.size() > 2 else "zh_CN")
	game.state = GameState.new()
	game.has_save = false
	match view:
		"starter": game.mode = "starter"
		"world":
			game.state.choose_starter(0)
			game.world.companion_id = 0
			game.world.player_position = Vector3(-5.3, 0, 4.1)
			game.mode = "explore"
			game.area_timer = 0
		"meadow":
			game.state.choose_starter(2)
			game.world.companion_id = 2
			game.world.player_position = Vector3(8, 0, -3.5)
			game.mode = "explore"
			game.area_timer = 0
		"battle":
			game.state.choose_starter(0)
			game.state.add_creature(3, 4)
			game.start_battle("gym", [DB.make_creature(7, 7)])
			game.battle_queue.clear()
			game.battle_lines.assign(game.battle.log)
			game.battle_timer = 0
		"journal":
			game.state.choose_starter(0)
			game.state.collection.assign(range(DB.SPECIES.size()))
			game._open_menu("journal")
		"journal_rain", "journal_unknown":
			game.state.choose_starter(0)
			if view == "journal_rain":
				game.state.collection.assign(range(DB.SPECIES.size()))
			game._open_menu("journal")
			game.handle_action("journal_next")
			game.handle_action("journal:10")
		"rillisk_battle", "terracurl_battle", "glimveil_battle":
			game.state.choose_starter(0)
			game.state.flags.captured = true
			game.state.flags.rival = true
			game.state.flags.gym = true
			game.state.flags.rain_arrived = true
			game.state.island_id = "rainstep"
			game.world.set_island("rainstep", Vector3(66, 0, 4.7))
			var species_id: int = {"rillisk_battle":8, "terracurl_battle":9, "glimveil_battle":10}[view]
			game.state.party[0] = DB.make_creature(8 + (species_id - 7) % 3, 7)
			game.start_battle("wild", [DB.make_creature(species_id, 6)])
			game.battle_queue.clear()
			game.battle_lines.assign(game.battle.log)
			game.battle_timer = 0
		"settings": game._open_menu("settings")
		"wind_quay", "wind_marker", "wind_map", "wind_route", "wind_berth", "wind_ferry":
			game.state.choose_starter(0)
			game.state.add_creature(8, 7)
			game.state.add_creature(10, 7)
			for key: String in ["captured", "rival", "gym", "rain_arrived", "rain_started", "rain_upper", "rain_middle", "rain_lower", "rain_rewarded", "rain_trial", "rain_gym", "wind_arrived"]:
				game.state.flags[key] = true
			if view in ["wind_route", "wind_map", "wind_berth"]:
				for key: String in ["wind_wind", "wind_tide", "wind_light"]:
					game.state.flags[key] = true
			if view == "wind_berth":
				game.state.flags.wind_sailed = true
				game.state.flags.wind_rewarded = true
			game.state.island_id = "windchart"
			var spawn := Vector3(120, 0, 1)
			if view == "wind_marker":
				spawn = Vector3(112, 0, -5)
			elif view == "wind_berth":
				spawn = Vector3(140, 0, 1)
			game.world.set_island("windchart", spawn)
			game.state.position = spawn
			game.world.sync_wind_progress(game.state.flags)
			game.world.companion_id = 0
			game.mode = "explore"
			game.area_text = game.world.area_name()
			game.area_timer = 0
			if view == "wind_map":
				game._open_menu("map")
			elif view == "wind_route":
				game.mode = "route"
			elif view == "wind_marker":
				game.interact()
			elif view == "wind_ferry":
				game.state.island_id = "rainstep"
				game.state.flags.wind_arrived = false
				game.world.set_island("rainstep", Vector3(64, 0, 7))
				game.ferry_destination = "windchart"
				game.mode = "ferry"
		"second_beacon", "second_unlit", "second_map", "neri_battle", "second_battle", "second_ending":
			game.state.choose_starter(0)
			game.state.party[0] = DB.make_creature(0, 8)
			game.state.add_creature(8, 7)
			game.state.add_creature(10, 7)
			for key: String in ["captured", "rival", "gym", "rain_arrived", "rain_started", "rain_upper", "rain_middle", "rain_lower", "rain_rewarded"]:
				game.state.flags[key] = true
			game.state.flags.rain_trial = view != "neri_battle"
			game.state.flags.rain_gym = view in ["second_beacon", "second_ending"]
			game.state.island_id = "rainstep"
			game.world.set_island("rainstep", Vector3(60, 0, -7.2))
			game.world.companion_id = 0
			game.world.sync_rain_progress(game.state.flags)
			game.mode = "explore"
			game.area_text = "RAINSTEP TERRACES"
			game.encounter_cooldown = 99
			if view == "second_map":
				game._open_menu("map")
			elif view in ["neri_battle", "second_battle"]:
				game.start_challenge("rain_trial" if view == "neri_battle" else "second_light")
				game.battle_queue.clear()
				game.battle_lines.assign(game.battle.log)
				game.battle_timer = 0
			elif view == "second_ending":
				game.ending_chapter = 2
				game.mode = "ending"
		"rainstep", "rain_map", "rain_repair", "rain_battle", "ferry":
			game.state.choose_starter(2)
			game.state.flags.captured = true
			game.state.flags.rival = true
			game.state.flags.gym = true
			game.state.flags.rain_arrived = true
			game.state.flags.rain_started = true
			game.state.island_id = "rainstep"
			game.world.set_island("rainstep", Vector3(60, 0, -1.5))
			game.world.companion_id = 2
			game.mode = "explore"
			game.area_text = "RAINSTEP TERRACES"
			game.area_timer = 0
			game.encounter_cooldown = 99
			game.world.sync_rain_progress(game.state.flags)
			if view == "rain_map":
				game._open_menu("map")
			elif view == "rain_repair":
				game.world.set_island("rainstep", Vector3(67, 0, -1.5))
				game.interact()
			elif view == "rain_battle":
				game.start_battle("wild", [DB.make_creature(6, 6)])
				game.battle_queue.clear()
				game.battle_lines.assign(game.battle.log)
				game.battle_timer = 0
			elif view == "ferry":
				game.world.set_island("wakeharbor", Vector3(-13, 0, 4.1))
				game.state.island_id = "wakeharbor"
				game.mode = "ferry"
				game.ferry_destination = "rainstep"
		"tidepools", "shore_map", "shore_battle", "rescue":
			game.state.choose_starter(1)
			game.state.flags.tide_started = true
			game.world.player_position = Vector3(-7.4, 0, 18.3)
			game.world.companion_id = 1
			game.mode = "explore"
			game.area_text = "TIDEGLASS POOLS"
			game.area_timer = 0
			game.encounter_cooldown = 99
			game.world.sync_tide_progress(game.state.flags)
			if view == "shore_map":
				game._open_menu("map")
			elif view == "shore_battle":
				game.start_battle("wild", [DB.make_creature(4, 3)])
				game.battle_queue.clear()
				game.battle_lines.assign(game.battle.log)
				game.battle_timer = 0
			elif view == "rescue":
				game.world.player_position = Vector3(-3.2, 0, 21.7)
				game.interact()
		"dialogue":
			game.state.choose_starter(0)
			game.say("EDDA / LANTERN KEEPER", ["Every island has a song. Ours has been quiet since the great mist swallowed the sea-lanes."])
		"ending":
			game.state.choose_starter(0)
			game.state.add_creature(3, 5)
			game.state.flags.gym = true
			game.mode = "ending"
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(output)
	print("RENDER_CAPTURE %s %dx%d result=%d" % [view, image.get_width(), image.get_height(), error])
	game.queue_free()
	for i in range(16):
		await process_frame
	quit(0 if error == OK else 1)
