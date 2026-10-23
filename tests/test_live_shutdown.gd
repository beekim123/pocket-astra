extends SceneTree
## Optional real-device smoke: run without --headless to check graphics/audio exit.
const Game = preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game := Game.new()
	root.add_child(game)
	for i in range(90):
		await process_frame
	if DisplayServer.get_name() != "headless":
		if game.music._playback == null or not game.music._player.playing:
			printerr("FAIL: Live AudioStreamGenerator playback did not start")
			quit(1)
			return
		print("LIVE AUDIO: playback active; generator running on real render loop")
	print("LIVE SHUTDOWN: closing through application handler")
	game._request_quit()
