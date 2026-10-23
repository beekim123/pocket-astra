extends SceneTree
## Windchart labels and every quest branch remain legible in both languages.

const Locale = preload("res://scripts/localization.gd")
const FontArt = preload("res://scripts/pixel_font.gd")
const Quest = preload("res://scripts/wind_quest.gd")
const State = preload("res://scripts/game_state.gd")
const WindWorld = preload("res://scripts/windchart_world.gd")
const MARKERS: Array[String] = ["wind_wind", "wind_tide", "wind_light"]

var checks: int = 0
var failures: int = 0
var checked_dialogue: Dictionary = {}


func _initialize() -> void:
	_test_labels()
	_test_dynamic_text()
	_test_travel_and_menu_text()
	_test_quest_branches()
	_test_layout()
	_test_internal_identifiers()
	Locale.set_language("zh_CN")
	print("WIND LOCALIZATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func _expect(source: String, expected: String) -> void:
	Locale.set_language("zh_CN")
	var actual: String = Locale.translate(source)
	_check(actual == expected, "Chinese translation: " + source)
	_check(Locale.translate(source.to_upper()) == expected, "Uppercase display source translates: " + source)
	_check(Locale.translate(source.to_lower()) == expected, "Lowercase display source translates: " + source)
	_check(FontArt.has_cjk_support(actual), "System font covers translated Windchart glyphs: " + source)
	_check(Locale.translate(actual) == actual, "Chinese rendering is idempotent: " + source)
	Locale.set_language("en")
	_check(Locale.translate(source) == source, "English preserves canonical text and case: " + source)
	Locale.set_language("zh_CN")


func _test_labels() -> void:
	for pair: Array in [
		["THREE SHORES  /  TWO LIGHTS", "三岸旅程 / 两盏航灯"],
		["A SMALL BOAT. A SONG BEYOND THE REEF.", "一叶小舟，礁岸之外的歌声。"],
		["WINDCHART QUAY", "风图埠"],
		["LEE BERTH", "背风泊位"],
		["WINDCHART / A SHORT CROSSING", "风图埠 / 一段短航"],
		["WINDCHART NOTES", "风图笔记"],
		["WINDCHART MAP", "风图地图"],
		["MAREN", "玛伦"],
		["SELA", "赛菈"],
		["MAREN / REST", "玛伦 / 休息"],
		["MAREN / FERRY TO WINDCHART", "玛伦 / 风图渡船"],
		["MAREN / FERRY TO RAINSTEP", "玛伦 / 雨阶渡船"],
		["SELA / SAILMAKER", "赛菈 / 制帆人"],
		["SKIFF TO WINDCHART QUAY", "乘小艇返回风图埠"],
		["WIND VANE", "风标"],
		["WIND PENNANT", "风标"],
		["TIDE GAUGE", "潮尺"],
		["PAIRED LIGHTS", "对灯"],
		["PAIRED LANTERNS", "对灯"],
		["WINDCHART TABLE", "航图台"],
		["CHART TABLE", "航图台"],
		["PASSAGE CHART", "航路图"],
		["SOUTHERN LEE", "南侧背风弯"],
		["FERRY TO WINDCHART", "乘船前往风图埠"],
		["CHOOSE A SHELTERED ROUTE", "选择背风航线"],
		["NORTH / MIDDLE SHOAL", "北侧 / 中央浅滩"],
		["EAST / EXPOSED REEF", "东侧 / 受风礁道"],
		["SOUTH / LEEWARD ARC", "南侧 / 背风弯"],
		["STAY AT THE QUAY", "留在码头"],
		["WIND / AVOID THE EAST REEF", "风标 / 避开东侧礁石"],
		["TIDE / DEEP WATER TO THE SOUTH", "潮尺 / 南侧水道足够深"],
		["LIGHT / ENTER FROM THE SOUTH", "对灯 / 从南侧驶入"],
		["UNREAD NAVIGATION MARKER", "尚未观察的航标"],
	]:
		_expect(str(pair[0]), str(pair[1]))
	for pair: Array in [
		["MAREN", "玛伦"],
		["MAREN / FERRY TO WINDCHART", "玛伦 / 风图渡船"],
		["MAREN / FERRY TO RAINSTEP", "玛伦 / 雨阶渡船"],
		["SELA / SAILMAKER", "赛菈 / 制帆人"],
		["SKIFF TO WINDCHART QUAY", "乘小艇返回风图埠"],
		["WINDCHART TABLE", "航图台"],
	]:
		_expect("E  " + str(pair[0]), "E  " + str(pair[1]))
	var marker_names: Array[String] = ["风标", "潮尺", "对灯"]
	for index: int in range(WindWorld.MARKERS.size()):
		var source: String = str(WindWorld.MARKERS[index].name)
		_expect(source, marker_names[index])
		_expect("E  " + source, "E  " + marker_names[index])


func _test_dynamic_text() -> void:
	for count: int in range(4):
		_expect("NAVIGATION MARKERS %d / 3" % count, "航标记录 %d / 3" % count)
		_expect("READ THE NAVIGATION MARKERS: %d / 3" % count, "观察三处航标：%d/3" % count)
	for quantities: Array in [[4, 2], [1, 0], [0, 0], [4, 1]]:
		_expect("Sela adds %d echo vessels and %d tonics to your bag." % quantities, "赛菈为行囊添了%d个回声瓶和%d瓶药剂。" % quantities)


func _test_travel_and_menu_text() -> void:
	for pair: Array in [
		["The new crossing needs both guiding lights. Complete Ilya's trial before we sail to Windchart Quay.", "新的航路需要两盏航灯指引。完成伊莱亚的试炼后，我们就能前往风图埠。"],
		["My ferry links Rainstep and Windchart Quay. The crossing is free, and I will always bring you back.", "我的渡船往返雨阶岛与风图埠。航程免费，想回来时随时来找我。"],
		["Read three markers at Windchart Quay, then choose a sheltered route. The ferry back to Rainstep is always free.", "在风图埠观察三处航标，再选择背风航线。返回雨阶岛的渡船始终免费。"],
		["Wind drives toward the eastern reef. The middle shoal is shallow. The berth opens to the deep southern channel.", "风吹向东侧礁石，中央浅滩水浅。泊位入口朝向水深足够的南侧航道。"],
		["Read all three markers, then use the chart table. Wrong choices cost nothing. Maren can take you back to Rainstep.", "观察三处航标，再使用航图台。选错不损失物资。玛伦可以送你回雨阶岛。"],
	]:
		_expect(str(pair[0]), str(pair[1]))
		for language: String in ["zh_CN", "en"]:
			Locale.set_language(language)
			_check_wrapping(str(pair[0]), 88, 3)
	Locale.set_language("zh_CN")


func _check_wrapping(source: String, columns: int, maximum_lines: int) -> void:
	var lines: Array[String] = FontArt.wrap(source, columns, 2)
	_check(lines.size() <= maximum_lines, "Wrapped text fits its panel in " + Locale.language + ": " + source)
	_check("".join(lines).replace(" ", "") == Locale.translate(source).replace(" ", ""), "Wrapping preserves every character in " + Locale.language + ": " + source)
	for line: String in lines:
		_check(FontArt.width(line, 2) <= float(columns * 12), "Wrapped line fits its width in " + Locale.language + ": " + source)


func _check_dialogue(reply: Dictionary) -> void:
	var sources: Array[String] = [str(reply.speaker)]
	for line: String in reply.lines:
		sources.append(line)
	for source: String in sources:
		if checked_dialogue.has(source):
			continue
		checked_dialogue[source] = true
		Locale.set_language("zh_CN")
		var translated: String = Locale.translate(source)
		_check(translated != source and translated != source.to_upper(), "Actual Windchart quest text has a Chinese display value: " + source)
		_check(FontArt.has_cjk_support(translated), "System font covers actual Windchart dialogue: " + source)
		_check(Locale.translate(source.to_lower()) == translated, "Actual quest text also translates in lowercase: " + source)
		_check(Locale.translate(translated) == translated, "Actual quest text remains translated when redrawn: " + source)
		Locale.set_language("en")
		_check(Locale.translate(source) == source, "Actual quest text retains canonical English: " + source)
		for language: String in ["zh_CN", "en"]:
			Locale.set_language(language)
			_check_wrapping(source, 88, 3)
	Locale.set_language("zh_CN")


func _new_trial_game() -> GameState:
	var game: GameState = State.new()
	game.choose_starter(1)
	for flag: String in ["captured", "rival", "gym", "rain_arrived", "rain_started", "rain_upper", "rain_middle", "rain_lower", "rain_rewarded", "rain_trial", "rain_gym"]:
		game.flags[flag] = true
	game.island_id = "rainstep"
	return game


func _expect_objective(game: GameState, expected: String) -> void:
	var source: String = Quest.objective(game)
	_expect(source, expected)
	for language: String in ["zh_CN", "en"]:
		Locale.set_language(language)
		_check_wrapping(source, 35, 2)
		_check_wrapping(source, 32, 3)
	Locale.set_language("zh_CN")


func _test_quest_branches() -> void:
	var fresh: GameState = State.new()
	_check(Quest.objective(fresh).is_empty(), "Windchart objective waits until the second trial is complete")
	for role: String in ["wind_keeper", "wind_chart", "wind_wind", "wind_tide", "wind_light", "wind_berth", "unknown"]:
		_check_dialogue(Quest.interact(fresh, role))
	_check_dialogue(Quest.choose_route(fresh, "south"))
	fresh.choose_starter(1)
	_check(Quest.objective(fresh).is_empty(), "A starter alone does not open the Windchart objective")
	var game: GameState = _new_trial_game()
	_expect_objective(game, "到雨阶岛东侧码头，乘船前往风图埠")
	_check_dialogue(Quest.interact(game, "wind_keeper"))
	_check(Quest.travel(game, "windchart"), "Localization test reaches Windchart by the real ferry API")
	_check_dialogue(Quest.interact(game, "unknown"))
	_check_dialogue(Quest.interact(game, "wind_keeper"))
	_check_dialogue(Quest.interact(game, "wind_keeper"))
	_check_dialogue(Quest.interact(game, "wind_berth"))
	for index: int in range(MARKERS.size()):
		_expect_objective(game, "观察三处航标：%d/3" % index)
		_expect("NAVIGATION MARKERS %d / 3" % Quest.marker_count(game), "航标记录 %d / 3" % index)
		_check_dialogue(Quest.interact(game, "wind_chart"))
		_check_dialogue(Quest.choose_route(game, "south"))
		_check_dialogue(Quest.interact(game, MARKERS[index]))
		_check_dialogue(Quest.interact(game, MARKERS[index]))
	_expect_objective(game, "到航图台选择安全航线")
	_expect("NAVIGATION MARKERS %d / 3" % Quest.marker_count(game), "航标记录 3 / 3")
	_check_dialogue(Quest.interact(game, "wind_chart"))
	for route: String in ["north", "east", "unknown", "south", "south"]:
		_check_dialogue(Quest.choose_route(game, route))
	_expect_objective(game, "到南侧泊位与赛菈交谈")
	_check_dialogue(Quest.interact(game, "wind_berth"))
	_expect_objective(game, "背风航路已畅通，继续探索各岛吧")
	_check_dialogue(Quest.interact(game, "wind_berth"))
	_check(Quest.return_to_quay(game), "Completed journey returns to the quay through the real boat API")
	_expect_objective(game, "背风航路已畅通，继续探索各岛吧")
	_check(Quest.travel(game, "rainstep"), "Completed journey returns to Rainstep through the real ferry API")
	_expect_objective(game, "背风航路已畅通，继续探索各岛吧")
	var paused: GameState = _new_trial_game()
	Quest.travel(paused, "windchart")
	Quest.interact(paused, "wind_wind")
	Quest.travel(paused, "rainstep")
	_expect_objective(paused, "到雨阶岛东侧码头，乘船前往风图埠")
	Quest.travel(paused, "windchart")
	_expect_objective(paused, "观察三处航标：1/3")
	# Each real marker can be last; the shared completion sentence must translate too.
	for order: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var early: GameState = _new_trial_game()
		Quest.travel(early, "windchart")
		for marker_index: int in order:
			_check_dialogue(Quest.interact(early, MARKERS[marker_index]))
			_check_dialogue(Quest.interact(early, MARKERS[marker_index]))
		_expect_objective(early, "到航图台选择安全航线")
	# Exercise actual inventory caps instead of checking only invented reward strings.
	for quantities: Array in [[0, 0], [998, 999], [999, 999], [0, 998]]:
		var capped: GameState = _new_trial_game()
		Quest.travel(capped, "windchart")
		for role: String in MARKERS:
			Quest.interact(capped, role)
		Quest.choose_route(capped, "south")
		capped.orbs = int(quantities[0])
		capped.tonics = int(quantities[1])
		_check_dialogue(Quest.interact(capped, "wind_berth"))
	_check(checked_dialogue.size() >= 33, "Localization visited all distinct Windchart dialogue branches")


func _test_layout() -> void:
	for language: String in ["zh_CN", "en"]:
		Locale.set_language(language)
		_check(FontArt.width("THREE SHORES  /  TWO LIGHTS", 2) <= 1120.0, "Title journey label stays within screen in " + language)
		_check(FontArt.width("A SMALL BOAT. A SONG BEYOND THE REEF.", 2) <= 1120.0, "Title subtitle stays within screen in " + language)
		for source: String in ["WINDCHART QUAY", "LEE BERTH"]:
			_check(FontArt.width(source, 2) <= 300.0, "Area title fits its HUD panel in " + language + ": " + source)
		for source: String in ["WINDCHART / A SHORT CROSSING", "WINDCHART NOTES", "NAVIGATION MARKERS 3 / 3"]:
			_check(FontArt.width(source, 1) <= 300.0, "HUD progress fits its panel in " + language + ": " + source)
		_check(FontArt.width("WINDCHART MAP", 1) <= 143.0, "Map tab fits its button in " + language)
		_check(FontArt.width("FERRY TO WINDCHART", 3) <= 592.0, "Ferry title fits its panel in " + language)
		_check(FontArt.width("CHOOSE A SHELTERED ROUTE", 3) <= 732.0, "Route title fits its panel in " + language)
		for source: String in ["NORTH / MIDDLE SHOAL", "EAST / EXPOSED REEF", "SOUTH / LEEWARD ARC"]:
			_check(FontArt.width(source, 2) <= 660.0, "Route choice fits its button in " + language + ": " + source)
		_check(FontArt.width("STAY AT THE QUAY", 2) <= 380.0, "Cancel choice fits its button in " + language)
		for source: String in ["MAREN", "MAREN / FERRY TO WINDCHART", "MAREN / FERRY TO RAINSTEP", "SELA / SAILMAKER", "SKIFF TO WINDCHART QUAY", "WINDCHART TABLE", "WIND VANE", "TIDE GAUGE", "PAIRED LIGHTS"]:
			_check(FontArt.width("E  " + source, 1) <= 500.0, "Interaction prompt fits its button in " + language + ": " + source)
			_check(FontArt.width(source, 2) <= 1100.0, "Speaker name fits its dialogue panel in " + language + ": " + source)
		for source: String in ["WIND / AVOID THE EAST REEF", "TIDE / DEEP WATER TO THE SOUTH", "LIGHT / ENTER FROM THE SOUTH", "UNREAD NAVIGATION MARKER"]:
			_check(FontArt.width(source, 1) <= 380.0, "Map note fits its column in " + language + ": " + source)
		for source: String in ["WINDCHART NOTES", "NAVIGATION MARKERS 3 / 3"]:
			_check(FontArt.width(source, 2) <= 400.0, "Map progress fits its column in " + language + ": " + source)
		_check_wrapping("Read three markers at Windchart Quay, then choose a sheltered route. The ferry back to Rainstep is always free.", 45, 4)
		_check_wrapping("Wind drives toward the eastern reef. The middle shoal is shallow. The berth opens to the deep southern channel.", 58, 4)
		_check_wrapping("Read all three markers, then use the chart table. Wrong choices cost nothing. Maren can take you back to Rainstep.", 32, 4)
	Locale.set_language("zh_CN")


func _test_internal_identifiers() -> void:
	for language: String in ["zh_CN", "en"]:
		Locale.set_language(language)
		for source: String in ["windchart", "lee_berth", "wind_arrived", "wind_wind", "wind_tide", "wind_light", "wind_sailed", "wind_rewarded", "wind_ferry_out", "wind_ferry_home", "wind_keeper", "wind_chart", "wind_berth", "wind_return", "north", "east", "south", "NAVIGATION MARKERS 2 / 4", "READ THE NAVIGATION MARKERS: 2 / 4", "Mira adds 4 echo vessels and 2 tonics to your bag.", "An unknown Windchart message."]:
			_check(Locale.translate(source) == source, "Internal identifiers and unknown text remain intact in " + language + ": " + source)
