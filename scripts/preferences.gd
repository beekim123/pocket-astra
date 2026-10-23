class_name GamePreferences
extends RefCounted
## Cosmetic settings are deliberately separate from the versioned adventure save.

var language: String = "zh_CN"

func load_settings(path: String = "user://preferences.cfg") -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	var stored: Variant = config.get_value("interface", "language", "zh_CN")
	if not stored is String or stored not in ["zh_CN", "en"]:
		return false
	language = stored
	return true

func save_settings(path: String = "user://preferences.cfg") -> bool:
	if language not in ["zh_CN", "en"]:
		return false
	var config := ConfigFile.new()
	config.set_value("interface", "language", language)
	var temporary := path + ".tmp"
	if config.save(temporary) != OK:
		return false
	var result: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if result != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
	return result == OK
