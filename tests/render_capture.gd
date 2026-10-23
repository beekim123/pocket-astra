extends SceneTree
## Actual GPU-rendered evidence. Outputs go outside the source-only project.
const Game = preload("res://scripts/main.gd")
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
			game.state.collection.assign([0,1,2,3,4,5,6,7])
			game._open_menu("journal")
		"settings": game._open_menu("settings")
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
