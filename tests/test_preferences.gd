extends SceneTree
## Language preferences must never rewrite progress or accept arbitrary types.
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	check(ResourceLoader.exists("res://scripts/preferences.gd"), "Preference implementation exists")
	if failures > 0:
		finish()
		return
	var script: GDScript = load("res://scripts/preferences.gd")
	var preferences = script.new()
	var path: String = "user://preferences_test_%d.cfg" % OS.get_process_id()
	check(preferences.language == "zh_CN", "New players begin in simplified Chinese")
	check(not preferences.load_settings(path), "Missing settings retain defaults")
	preferences.language = "en"
	check(preferences.save_settings(path), "Language preference saves")
	var restored = script.new()
	check(restored.load_settings(path) and restored.language == "en", "English choice survives restart")
	var config := ConfigFile.new()
	config.set_value("interface", "language", 123)
	config.save(path)
	check(not restored.load_settings(path) and restored.language == "en", "Invalid types do not mutate preferences")
	config.set_value("interface", "language", "invalid")
	config.save(path)
	check(not restored.load_settings(path) and restored.language == "en", "Unknown language is rejected")
	preferences.language = "zh_CN"
	check(preferences.save_settings(path), "Chinese choice can replace English")
	check(restored.load_settings(path) and restored.language == "zh_CN", "Chinese choice survives restart")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	finish()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func finish() -> void:
	print("PREFERENCES TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
