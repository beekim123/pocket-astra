extends SceneTree
## Display localization keeps rules/save identifiers intact and preserves numbers.

var locale: Script
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_check(ResourceLoader.exists("res://scripts/localization.gd"), "Localization implementation exists")
	if failures > 0:
		_finish()
		return
	locale = load("res://scripts/localization.gd")
	_check(locale.language == "zh_CN" and locale.chinese(), "Fresh game defaults to Simplified Chinese")
	_test_labels_and_story()
	_test_dynamic_messages()
	_test_species()
	_test_language_switching_and_fallbacks()
	_finish()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", label)


func _finish() -> void:
	print("LOCALIZATION TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _expect(source: String, expected: String) -> void:
	var actual: String = locale.translate(source)
	_check(actual == expected, "Translation: " + source)
	_check(locale.translate(actual) == actual, "Chinese remains unchanged when rendered again: " + source)


func _test_labels_and_story() -> void:
	_expect("CONTINUE JOURNEY", "继续旅程")
	_expect("Begin a new journey", "开启新旅程")
	_expect("FIELD JOURNAL", "野外图鉴")
	_expect("SOUND: OFF", "声音：关")
	_expect("WAKEHARBOR", "醒潮港")
	_expect("CANDLE REED MEADOW", "烛苇原")
	_expect("FIRST LIGHT SANCTUM", "初光灯塔")
	_expect("EDDA / THE LANTERN KEEPER", "艾妲 / 守灯人")
	_expect("Every island has a song. Ours has been quiet since the great mist swallowed the sea-lanes.", "每座岛都有自己的歌。大雾吞没航道后，我们的岛便沉寂了。")
	_expect("Explore the meadow. Weaken and capture a wild companion.", "探索烛苇原，削弱并捕获一位野生伙伴。")
	_expect("Your party is full. Six companions travel together.", "队伍已满，最多可携带六位伙伴。")
	_expect("COULD NOT SAVE. CHECK DISK PERMISSIONS.", "保存失败，请检查磁盘权限。")
	_expect("WASD / ARROWS    WALK", "WASD / 方向键    移动")


func _test_dynamic_messages() -> void:
	_expect("A wild Wispip appeared!", "野生的愿灯蛾出现了！")
	_expect("The Lantern Trial begins! Voltkite enters.", "初光试炼开始！霆风鳐登场。")
	_expect("Ivo sends out Pebblit!", "伊沃派出了卵石甲！")
	_expect("Go, Cindermew!", "上吧，烛尾兽！")
	_expect("Cindermew uses Lantern Flare! 23 damage.", "烛尾兽使出灯尾焰！造成23点伤害。")
	_expect("BROOKFIN USES STRIKE. 9 DAMAGE.", "帆溪獭使出轻击，造成9点伤害。")
	_expect("Tonic restored 26 HP to Mossbell.", "药剂为苔铃鹿恢复了26点体力。")
	_expect("Mossbell guards and recovers 12 HP.", "苔铃鹿守护并恢复12点体力。")
	_expect("Noctulume is out of energy.", "夜辉鸮的体力耗尽了。")
	_expect("The challenger sends out Reedrill!", "挑战者派出了苇锋鹭！")
	_expect("Brookfin needs a rest.", "帆溪獭需要休息了。")
	_expect("Pebblit steps forward!", "卵石甲挺身上前！")
	_expect("The orb shines! Wispip joined your party.", "回声瓶亮了！愿灯蛾加入了队伍。")
	_expect("Voltkite slipped free! Lower its HP and try again.", "霆风鳐挣脱了！降低它的体力后再试试。")
	_expect("Cindermew gained 82 experience.", "烛尾兽获得82点经验。")
	_expect("Cindermew reached level 12!", "烛尾兽升到了12级！")
	_expect("Mossbell already has full HP.", "苔铃鹿的体力已经全满。")
	_expect("Brookfin chooses you, too. A partnership begins with a little trust.", "帆溪獭也选择了你。伙伴之间的羁绊，始于一点信任。")
	_expect("01  /  EMBER", "01 / 余烬")
	_expect("1  CHOOSE CINDERMEW", "1 选择烛尾兽")
	_expect("SIGNATURE / Petal Chime", "绝招 / 花铃音")
	_expect("TIDE  /  SAILWATER RUSH", "潮汐 / 帆水冲")
	_expect("E  MIRA / REST & SUPPLIES", "E  米拉 / 休息与补给")
	_expect("LV 05", "等级 05")
	_expect("HP  9 / 62", "体力 9 / 62")
	_expect("XP  17 / 100", "经验 17 / 100")
	_expect("LV 5   HP 9/62", "等级 5   体力 9/62")
	_expect("TURN 03   /   WILD", "第03回合 / 野外相遇")
	_expect("TURN 12   /   GYM", "第12回合 / 灯塔试炼")
	_expect("VESSELS 12  TONICS 05", "回声瓶 12  药剂 05")
	_expect("VESSELS  12     TONICS  05     JOURNAL  03 / 08", "回声瓶 12   药剂 05   图鉴 03 / 08")
	_expect("TIME  12:09", "时间 12:09")
	_expect("LANTERN FLARE  X1.50   /   GUARD RECOVERS HP", "灯尾焰 ×1.50 / 守护恢复体力")
	_expect("Petal Chime     X0.70 / GUARD RECOVERS HP", "花铃音 ×0.70 / 守护恢复体力")
	_expect("TIDE     /   SAILWATER RUSH", "潮汐 / 帆水冲")
	_expect("8 FRIENDSHIPS RECORDED  /  42 MINUTES UNDER THE LANTERNS", "记录了8份友谊 / 灯火下同行42分钟")


func _test_species() -> void:
	var db: Script = load("res://scripts/creature_db.gd")
	var names: Array[String] = ["烛尾兽", "帆溪獭", "苔铃鹿", "愿灯蛾", "卵石甲", "苇锋鹭", "霆风鳐", "夜辉鸮"]
	for id: int in range(8):
		var info: Dictionary = db.species(id)
		_expect(str(info.name), names[id])
		for key: String in ["description", "move", "element"]:
			var source: String = str(info[key])
			var translated: String = locale.translate(source)
			_check(translated != source and translated != source.to_upper(), "Species " + key + " has a Chinese display value")
			_check(locale.translate(translated) == translated, "Species " + key + " is idempotent")
		_check(db.species(id).name == info.name, "Translation does not mutate database names")


func _test_language_switching_and_fallbacks() -> void:
	locale.set_language("en")
	_check(locale.language == "en" and not locale.chinese(), "English can be selected")
	_check(locale.translate("Cindermew uses Strike! 12 damage.") == "Cindermew uses Strike! 12 damage.", "English mode preserves original casing and message")
	_check(locale.translate("CONTINUE JOURNEY") == "CONTINUE JOURNEY", "Language switch does not reuse Chinese cached result")
	locale.set_language("unsupported")
	_check(locale.language == "zh_CN" and locale.chinese(), "Unsupported language falls back to Simplified Chinese")
	_expect("CONTINUE JOURNEY", "继续旅程")
	_check(locale.translate("An unknown future message.") == "An unknown future message.", "Unknown messages preserve original text and casing")
	_check(locale.translate("未来的中文提示。") == "未来的中文提示。", "Already Chinese input is safe")
	_check(locale.translate("") == "", "Empty label is safe")
	locale.set_language("zh_CN")
