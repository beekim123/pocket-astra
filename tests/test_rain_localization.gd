extends SceneTree
## Rainstep travel, waterworks and progress remain readable in both languages.

const Locale = preload("res://scripts/localization.gd")
const FontArt = preload("res://scripts/pixel_font.gd")
const Quest = preload("res://scripts/rain_quest.gd")
const State = preload("res://scripts/game_state.gd")
const REPAIRS: Array[String] = ["rain_upper", "rain_middle", "rain_lower"]

var checks: int = 0
var failures: int = 0
var checked_dialogue: Dictionary = {}


func _initialize() -> void:
	Locale.set_language("zh_CN")
	_test_labels()
	_test_progress()
	_test_travel_dialogue()
	_test_quest_branches()
	_test_unknown_text()
	Locale.set_language("zh_CN")
	print("RAIN LOCALIZATION TESTS: %d checks, %d failures" % [checks, failures])
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
	_check(FontArt.has_cjk_support(actual), "System font covers translated Rainstep glyphs: " + source)
	_check(Locale.translate(actual) == actual, "Chinese rendering is idempotent: " + source)
	Locale.set_language("en")
	_check(Locale.translate(source) == source, "English text remains unchanged: " + source)
	Locale.set_language("zh_CN")


func _test_labels() -> void:
	_expect("RAINSTEP TERRACES", "雨阶岛")
	_expect("RAINSTEP WATERWORKS", "雨阶水路")
	_expect("RAINSTEP MAP", "雨阶地图")
	_expect("VENN", "维恩")
	_expect("ORLA", "奥菈")
	_expect("VENN / RAINSTEP FERRY", "维恩 / 雨阶渡船")
	_expect("ORLA / WATERWORKS KEEPER", "奥菈 / 水路守护人")
	_expect("ROOF INTAKE", "屋檐引水口")
	_expect("BRIDGE JUNCTION", "桥边接水槽")
	_expect("GARDEN OUTLET", "菜圃出水口")
	_expect("FERRY TO RAINSTEP", "乘船前往雨阶岛")
	_expect("FERRY TO WAKEHARBOR", "乘船返回醒潮港")
	_expect("BOARD FERRY", "登船")
	_expect("STAY HERE", "留在这里")
	_expect("THE OPEN SEA-LANE", "新开的航路")
	_expect("A SONG IN THE RAIN", "雨中的歌")
	_expect("WESTERN PIER", "西侧码头")
	_expect("THE WATER IS FLOWING", "水流重新连通")
	_expect("SAIL TO RAINSTEP FROM THE WESTERN PIER", "到西侧码头，乘船前往雨阶岛")
	_expect("MEET ORLA BY THE RAINSTEP LANDING", "到雨阶岛渡口，与奥菈交谈")
	_expect("RETURN TO ORLA WITH THE WATER FLOWING", "水路已连通，回去告诉奥菈")
	_expect("RAINSTEP FLOWS AGAIN", "雨阶岛的水声再次响起")
	_expect("E  VENN / RAINSTEP FERRY", "E  维恩 / 雨阶渡船")
	_expect("E  ORLA / WATERWORKS KEEPER", "E  奥菈 / 水路守护人")
	_expect("E  ROOF INTAKE", "E  屋檐引水口")
	_expect("E  BRIDGE JUNCTION", "E  桥边接水槽")
	_expect("E  GARDEN OUTLET", "E  菜圃出水口")


func _test_progress() -> void:
	for count: int in range(4):
		_expect("WATER CHANNELS %d / 3" % count, "水路修复 %d / 3" % count)
		_expect("REPAIR THE WATER CHANNELS: %d / 3" % count, "修复三处水路：%d/3" % count)
	_expect("Orla adds 4 echo vessels and 2 tonics to your bag.", "奥菈为行囊添了4个回声瓶和2瓶药剂。")
	_expect("Orla adds 1 echo vessels and 0 tonics to your bag.", "奥菈为行囊添了1个回声瓶和0瓶药剂。")
	_expect("Orla adds 0 echo vessels and 0 tonics to your bag.", "奥菈为行囊添了0个回声瓶和0瓶药剂。")


func _test_travel_dialogue() -> void:
	_expect_dialogue("The First Light has opened the sea-lane. My ferry can take you to Rainstep, where the roof gutters have fallen quiet.", "第一盏灯照亮了航路。我可以载你去雨阶岛，那里的檐沟已经很久没有水声了。")
	_expect_dialogue("The sea-lane is still hidden. Light the First Light tower before we sail.", "航路仍藏在雾中。先点亮初光灯塔，我们才能出发。")
	_expect_dialogue("The ferry is ready whenever you want to return to Wakeharbor.", "想回醒潮港时，随时来找我，渡船一直在这里等你。")
	_expect_dialogue("A quiet crossing brings you safely to the other island.", "渡船安静地穿过水面，平安将你送到了另一座岛。")
	_expect_dialogue("Follow the dry paths. Orla offers free rest by the landing, and Venn can always take you home.", "沿干燥的小路前行。渡口边的奥菈会免费提供休息，维恩随时都能送你回家。")
	_expect_dialogue("I brought everyone back to the landing. Your companions are rested, and your progress is safe.", "我把大家带回了渡口。伙伴们已经休息好了，旅程进度也都还在。")
	_expect_dialogue("Your companions need rest. Orla brings you to the landing.", "伙伴们需要休息，奥菈将你带回了渡口。")
	_expect_dialogue("Three channels carry roof water to the gardens. Repair them in any order, then return to Orla.", "三处水槽将屋檐的雨水引向菜圃。按任意顺序修好它们，再回来找奥菈。")


func _expect_dialogue(source: String, expected: String) -> void:
	_expect(source, expected)
	_check_dialogue_layout(source)


func _check_dialogue_layout(source: String) -> void:
	for language: String in ["zh_CN", "en"]:
		Locale.set_language(language)
		var lines: Array[String] = FontArt.wrap(source, 88, 2)
		_check(lines.size() <= 3, "Dialogue stays above its continue button in " + language + ": " + source)
		_check("".join(lines).replace(" ", "") == Locale.translate(source).replace(" ", ""), "Wrapping keeps all dialogue content in " + language + ": " + source)
		for line: String in lines:
			_check(FontArt.width(line, 2) <= 1056.0, "Dialogue stays within its text panel in " + language + ": " + source)
	Locale.set_language("zh_CN")


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
		_check(translated != source and translated != source.to_upper(), "Quest text has a Chinese display value: " + source)
		_check(FontArt.has_cjk_support(translated), "System font covers every translated waterworks dialogue glyph: " + source)
		_check(Locale.translate(translated) == translated, "Quest translation is idempotent: " + source)
		Locale.set_language("en")
		_check(Locale.translate(source) == source, "Quest retains canonical English: " + source)
		_check_dialogue_layout(source)


func _new_trial_game() -> GameState:
	var game: GameState = State.new()
	game.choose_starter(1)
	game.flags.captured = true
	game.flags.rival = true
	game.flags.gym = true
	return game


func _test_quest_branches() -> void:
	var fresh: GameState = State.new()
	_check(Quest.objective(fresh).is_empty(), "Rainstep objective waits until the first trial is complete")
	for role: String in ["rain_keeper", "rain_upper", "rain_middle", "rain_lower", "unknown"]:
		_check_dialogue(Quest.interact(fresh, role))
	fresh.choose_starter(1)
	_check(Quest.objective(fresh).is_empty(), "Choosing a companion alone does not open the sea-lane objective")
	var game: GameState = _new_trial_game()
	_expect(Quest.objective(game), "到西侧码头，乘船前往雨阶岛")
	_check_dialogue(Quest.interact(game, "rain_keeper"))
	_check(Quest.travel(game, "rainstep"), "Dialogue test reaches Rainstep by the real ferry API")
	_expect(Quest.objective(game), "到雨阶岛渡口，与奥菈交谈")
	_check_dialogue(Quest.interact(game, "unknown"))
	_check_dialogue(Quest.interact(game, "rain_keeper"))
	_check_dialogue(Quest.interact(game, "rain_keeper"))
	for index: int in range(REPAIRS.size()):
		_expect(Quest.objective(game), "修复三处水路：%d/3" % index)
		_check_dialogue(Quest.interact(game, REPAIRS[index]))
		_check_dialogue(Quest.interact(game, REPAIRS[index]))
	_expect(Quest.objective(game), "水路已连通，回去告诉奥菈")
	_check_dialogue(Quest.interact(game, "rain_keeper"))
	_expect(Quest.objective(game), "雨阶岛的水声再次响起")
	_check_dialogue(Quest.interact(game, "rain_keeper"))
	# Every repair can be the last one, including repairs before meeting Orla.
	for order: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var early: GameState = _new_trial_game()
		Quest.travel(early, "rainstep")
		for repair_index: int in order:
			_check_dialogue(Quest.interact(early, REPAIRS[repair_index]))
			_check_dialogue(Quest.interact(early, REPAIRS[repair_index]))
		_expect(Quest.objective(early), "水路已连通，回去告诉奥菈")
		_check_dialogue(Quest.interact(early, "rain_keeper"))
		_expect(Quest.objective(early), "雨阶岛的水声再次响起")
		_check_dialogue(Quest.interact(early, "rain_keeper"))
	for starting_orbs: int in [998, 999]:
		var capped: GameState = _new_trial_game()
		Quest.travel(capped, "rainstep")
		for role: String in REPAIRS:
			Quest.interact(capped, role)
		capped.orbs = starting_orbs
		capped.tonics = 999
		_check_dialogue(Quest.interact(capped, "rain_keeper"))


func _test_unknown_text() -> void:
	Locale.set_language("zh_CN")
	for source: String in ["An unknown Rainstep message.", "rain_roof", "WATER CHANNELS 2 / 4"]:
		_check(Locale.translate(source) == source, "Unknown text and internal IDs remain intact: " + source)
