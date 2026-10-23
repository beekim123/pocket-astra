extends SceneTree
## Tideglass labels, every quest branch and numeric progress work in both languages.

const Locale = preload("res://scripts/localization.gd")
const Quest = preload("res://scripts/tide_quest.gd")
const State = preload("res://scripts/game_state.gd")
const FontArt = preload("res://scripts/pixel_font.gd")
const MARKERS: Array[String] = ["tide_wind", "tide_water", "tide_brass"]

var checks: int = 0
var failures: int = 0
var checked_dialogue: Dictionary = {}


func _initialize() -> void:
	Locale.set_language("zh_CN")
	_test_labels()
	_test_progress()
	_test_quest_branches()
	Locale.set_language("zh_CN")
	print("TIDE LOCALIZATION TESTS: %d checks, %d failures" % [checks, failures])
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
	_check(Locale.translate(actual) == actual, "Chinese rendering is idempotent: " + source)
	Locale.set_language("en")
	_check(Locale.translate(source) == source, "English text remains unchanged: " + source)
	Locale.set_language("zh_CN")


func _test_labels() -> void:
	_expect("TIDEGLASS POOLS", "浅鸣潮池")
	_expect("TAVI / SHORE LANTERNWRIGHT", "塔薇 / 修灯匠")
	_expect("A STRANDED WISPIP", "搁浅的愿灯蛾")
	_expect("WIND-HOLE STONE", "风孔石")
	_expect("WATER CHANNEL", "流水槽")
	_expect("BRASS CHIMES", "铜片风铃")
	_expect("TIDEGLASS RESCUE", "潮池救援")
	_expect("OPTIONAL SHORE JOURNEY", "海岸支线")
	_expect("CAUSEWAY / SOUTH", "向南 / 沿石堤")
	_expect("RETURN TO THE VILLAGE", "返回醒潮港")
	_expect("RESCUE COMPLETE", "救援完成")
	_expect("HELP WISPIP", "救助愿灯蛾")
	_expect("TALK TO TAVI", "与塔薇交谈")
	_expect("TIDEGLASS SONG", "潮池之歌")
	_expect("WIND STONE", "风孔石")
	_expect("SHORE NOTES", "岸边记录")
	_expect("ISLAND MAP", "岛屿地图")
	_expect("SHORE MAP", "潮池地图")
	_expect("A SONG IN THE TIDEPOOLS", "潮池间的歌")
	_expect("THE SHORE PATH BEGINS SOUTH OF WAKEHARBOR.", "沿醒潮港南侧的小路前往潮池。")
	_expect("Follow the dry eastern bank to Wispip. The three markers can be heard in any order.", "沿东侧干燥的岩岸找到愿灯蛾。三处共鸣标记可按任意顺序聆听。")
	_expect("E  TAVI / SHORE LANTERNWRIGHT", "E  塔薇 / 修灯匠")
	_expect("E  A STRANDED WISPIP", "E  搁浅的愿灯蛾")
	_expect("E  WIND-HOLE STONE", "E  风孔石")
	_expect("E  WATER CHANNEL", "E  流水槽")
	_expect("E  BRASS CHIMES", "E  铜片风铃")


func _test_progress() -> void:
	for count: int in range(4):
		_expect("SHORE NOTES %d / 3" % count, "岸边记录 %d / 3" % count)
		_expect("LISTEN TO THREE SHORE MARKERS: %d / 3" % count, "聆听三处岸边共鸣：%d/3" % count)


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
		_check(FontArt.has_cjk_support(translated), "System font covers every translated shore dialogue glyph")
		_check(Locale.translate(translated) == translated, "Quest translation is idempotent: " + source)
		Locale.set_language("en")
		_check(Locale.translate(source) == source, "Quest retains canonical English: " + source)
		Locale.set_language("zh_CN")


func _test_quest_branches() -> void:
	var game: GameState = State.new()
	_check(Quest.objective(game).is_empty(), "No sidequest objective is shown before choosing a companion")
	for role: String in ["tide_artisan", "tide_rescue", "tide_wind", "tide_water", "tide_brass", "unknown"]:
		_check_dialogue(Quest.interact(game, role))
	game.choose_starter(1)
	_expect(Quest.objective(game), "前往南岸，与塔薇交谈")
	_check_dialogue(Quest.interact(game, "tide_artisan"))
	_expect(Quest.objective(game), "沿石堤前行，救助搁浅的愿灯蛾。")
	_check_dialogue(Quest.interact(game, "tide_artisan"))
	_check_dialogue(Quest.interact(game, "tide_rescue"))
	_expect(Quest.objective(game), "返回醒潮港，向塔薇报平安")
	_check_dialogue(Quest.interact(game, "tide_rescue"))
	_check_dialogue(Quest.interact(game, "tide_artisan"))
	_check_dialogue(Quest.interact(game, "tide_artisan"))
	for index: int in range(MARKERS.size()):
		_expect(Quest.objective(game), "聆听三处岸边共鸣：%d/3" % index)
		_check_dialogue(Quest.interact(game, MARKERS[index]))
		_check_dialogue(Quest.interact(game, MARKERS[index]))
	_expect(Quest.objective(game), "浅鸣潮池之歌已完整记录")
	_check_dialogue(Quest.interact(game, "tide_artisan"))
	_check_dialogue(Quest.interact(game, "unknown"))
	# Every marker can be the final note, before or after the rescue. Each
	# first/repeat response is checked using the actual quest API, not a copy.
	for order: Array in [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]:
		var early: GameState = State.new()
		early.choose_starter(0)
		for marker_index: int in order:
			_check_dialogue(Quest.interact(early, MARKERS[marker_index]))
			_check_dialogue(Quest.interact(early, MARKERS[marker_index]))
		_expect(Quest.objective(early), "前往南岸，与塔薇交谈")
		_check_dialogue(Quest.interact(early, "tide_rescue"))
		_expect(Quest.objective(early), "返回醒潮港，向塔薇报平安")
		_check_dialogue(Quest.interact(early, "tide_artisan"))
		_expect(Quest.objective(early), "浅鸣潮池之歌已完整记录")
		_check_dialogue(Quest.interact(early, "tide_artisan"))
