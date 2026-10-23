extends SceneTree
## Rainstep companion labels, journal pages and battle logs use display-only translation.

const Locale = preload("res://scripts/localization.gd")
const FontArt = preload("res://scripts/pixel_font.gd")
const RAINSTEP_NOTE: String = "Three new resonants shelter by Rainstep's channels, warm stones, and roof eaves. Look among the pale plants, then weaken them before capture."

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_companion_text()
	_test_dynamic_battle_logs()
	_test_journal_pages()
	_test_discovery_dialogue()
	_test_layout()
	_test_internal_identifiers()
	Locale.set_language("zh_CN")
	print("SPECIES LOCALIZATION TESTS: %d checks, %d failures" % [checks, failures])
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
	_check(FontArt.has_cjk_support(actual), "System font covers translated companion glyphs: " + source)
	_check(Locale.translate(actual) == actual, "Repeated rendering preserves Chinese text: " + source)
	Locale.set_language("en")
	_check(Locale.translate(source) == source, "English display preserves original text and case: " + source)
	Locale.set_language("zh_CN")


func _test_companion_text() -> void:
	_expect("Rillisk", "檐溪蜥")
	_expect("Terracurl", "阶纹蜗")
	_expect("Glimveil", "灯纱蝠")
	_expect("Gutter Glide", "檐水滑行")
	_expect("Terrace Tumble", "阶壳翻滚")
	_expect("Eaves Gleam", "檐影微光")
	_expect("A nimble gutter lizard that guides stray drops toward thirsty roots.", "灵巧的檐沟小蜥，将零落雨滴引向干渴的根须。")
	_expect("Its stepped shell stores the warmth of old stone paths after the rain.", "层层石阶般的壳，留着雨后老石路的暖意。")
	_expect("It folds luminous wings like a curtain, guiding late walkers beneath the eaves.", "发光的双翼如帘幕轻叠，引领晚归的人走过屋檐下。")


func _test_dynamic_battle_logs() -> void:
	_expect("A wild Rillisk appeared!", "野生的檐溪蜥出现了！")
	_expect("Go, Terracurl!", "上吧，阶纹蜗！")
	_expect("Glimveil uses Eaves Gleam! 17 damage.", "灯纱蝠使出檐影微光！造成17点伤害。")
	_expect("Rillisk uses Gutter Glide. 9 damage.", "檐溪蜥使出檐水滑行，造成9点伤害。")
	_expect("Terracurl uses Terrace Tumble! 21 damage.", "阶纹蜗使出阶壳翻滚！造成21点伤害。")
	_expect("The orb shines! Glimveil joined your party.", "回声瓶亮了！灯纱蝠加入了队伍。")
	_expect("Rillisk reached level 12!", "檐溪蜥升到了12级！")
	_expect("Terracurl guards and recovers 12 HP.", "阶纹蜗守护并恢复12点体力。")
	_expect("SIGNATURE / Gutter Glide", "绝招 / 檐水滑行")
	_expect("STONE / Terrace Tumble", "岩石 / 阶壳翻滚")
	_expect("Eaves Gleam X1.50 / GUARD RECOVERS HP", "檐影微光 ×1.50 / 守护恢复体力")


func _test_journal_pages() -> void:
	_expect("PREVIOUS PAGE", "上一页")
	_expect("NEXT PAGE", "下一页")
	_expect("PAGE 1 / 2", "第1/2页")
	_expect("PAGE 2 / 2", "第2/2页")
	_expect("PAGE 10 / 12", "第10/12页")
	_expect("RAINSTEP COMPANIONS", "雨阶伙伴")
	_expect("FOUND IN RAINSTEP", "栖息于雨阶岛")
	_expect("FOUND IN CANDLE REED", "栖息于烛苇原")
	_expect("COLLECTION COMPLETE", "图鉴已集齐")
	_expect("RELEASING KEEPS ITS JOURNAL ENTRY. FIND IT AGAIN IN ITS HOME REGION.", "放归后图鉴仍会保留。可在原栖息地再次找到它。")
	_expect("RELEASED TO ITS HOME REGION. JOURNAL ENTRY KEPT.", "伙伴已回到原栖息地，图鉴记录仍然保留。")
	_expect("VESSELS  12     TONICS  05     JOURNAL  09 / 11", "回声瓶 12   药剂 05   图鉴 09 / 11")
	_expect("11 FRIENDSHIPS RECORDED  /  42 MINUTES UNDER THE LANTERNS", "记录了11份友谊 / 灯火下同行42分钟")


func _test_discovery_dialogue() -> void:
	_expect(RAINSTEP_NOTE, "三种新的共鸣兽栖身在雨阶岛的水槽、暖石与屋檐旁。到浅色草丛中找找，捕获前记得先削弱它们。")
	_expect("The world holds 11 kinds of resonants now. Your field journal remembers every friendship, even after a release.", "如今，世界里已有11种共鸣兽。即使伙伴回归原野，图鉴也会记得每一份友谊。")
	_expect("The world holds 24 kinds of resonants now. Your field journal remembers every friendship, even after a release.", "如今，世界里已有24种共鸣兽。即使伙伴回归原野，图鉴也会记得每一份友谊。")


func _check_wrapping(source: String, columns: int, maximum_lines: int) -> void:
	var lines: Array[String] = FontArt.wrap(source, columns, 2)
	_check(lines.size() <= maximum_lines, "Wrapped text fits its panel in " + Locale.language + ": " + source)
	_check("".join(lines).replace(" ", "") == Locale.translate(source).replace(" ", ""), "Wrapping preserves every character in " + Locale.language + ": " + source)
	for line: String in lines:
		_check(FontArt.width(line, 2) <= float(columns * 12), "Wrapped line fits its width in " + Locale.language + ": " + source)


func _test_layout() -> void:
	for language: String in ["zh_CN", "en"]:
		Locale.set_language(language)
		for name: String in ["Rillisk", "Terracurl", "Glimveil"]:
			_check(FontArt.width(name, 3) <= 500.0, "Companion name fits the journal detail panel in " + language)
		for label: String in ["PREVIOUS PAGE", "NEXT PAGE"]:
			_check(FontArt.width(label, 1) <= 140.0, "Page control fits its button in " + language)
		for label: String in ["RAINSTEP COMPANIONS", "FOUND IN RAINSTEP", "FOUND IN CANDLE REED", "COLLECTION COMPLETE"]:
			_check(FontArt.width(label, 1) <= 500.0, "Journal habitat and completion label fits in " + language)
		_check(FontArt.width("RELEASING KEEPS ITS JOURNAL ENTRY. FIND IT AGAIN IN ITS HOME REGION.", 1) <= 594.0, "Release guidance fits the party panel in " + language)
		for description: String in ["A nimble gutter lizard that guides stray drops toward thirsty roots.", "Its stepped shell stores the warmth of old stone paths after the rain.", "It folds luminous wings like a curtain, guiding late walkers beneath the eaves."]:
			_check_wrapping(description, 43, 3)
		_check_wrapping(RAINSTEP_NOTE, 88, 3)
		_check_wrapping("The world holds 11 kinds of resonants now. Your field journal remembers every friendship, even after a release.", 88, 3)
	Locale.set_language("zh_CN")


func _test_internal_identifiers() -> void:
	for language: String in ["zh_CN", "en"]:
		Locale.set_language(language)
		for source: String in ["rainstep", "journal:8", "journal:10", "journal_next", "journal_previous", "PAGE ???", "An unknown companion is nearby."]:
			_check(Locale.translate(source) == source, "Internal identifiers and unknown text remain intact in " + language + ": " + source)
