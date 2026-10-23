extends SceneTree
## Rendering fixtures must never alter the real player's save or preferences.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	check(ResourceLoader.exists("res://tests/capture_game.gd"), "Screenshot fixtures use a no-save coordinator")
	if failures:
		finish()
		return
	call_deferred("run_check")

func snapshot(path: String) -> Dictionary:
	return {"exists": FileAccess.file_exists(path), "bytes": FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()}

func run_check() -> void:
	var save_before: Dictionary = snapshot("user://lanternwake.json")
	var prefs_before: Dictionary = snapshot("user://preferences.cfg")
	var source: GDScript = load("res://tests/capture_game.gd")
	var game = source.new()
	root.add_child(game)
	await process_frame
	game.state = GameState.new()
	game.state.choose_starter(0)
	game.mode = "explore"
	game._save(false)
	game.handle_action("save")
	game._process(36.0)
	game.world.player_position = Vector3(-3.2, 0, 21.7)
	game.interact()
	check(game.state.flags.tide_rescued, "Screenshot still executes the actual rescue fixture")
	check(snapshot("user://lanternwake.json") == save_before, "Manual, automatic and interaction saves never touch player progress")
	check(snapshot("user://preferences.cfg") == prefs_before, "Screenshot setup never changes player language settings")
	game.queue_free()
	await process_frame
	finish()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FAIL: " + label)

func finish() -> void:
	print("CAPTURE ISOLATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
