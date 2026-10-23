extends "res://scripts/main.gd"
## Visual fixtures must not persist gameplay or use the player's preferences.

func _save(_show_message: bool) -> void:
	pass

func _preferences_path() -> String:
	return "user://capture_preferences_%d.cfg" % OS.get_process_id()
