extends SceneTree
## Second Light labels, dynamic battle logs and progress preserve both languages.

const Locale = preload("res://scripts/localization.gd")
const FontArt = preload("res://scripts/pixel_font.gd")

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_labels()
	_test_dynamic_logs()
	_test_dialogue()
	_test_challenge_catalog()
	_test_layout()
	_test_internal_identifiers()
	Locale.set_language("zh_CN")
	print("SECOND LIGHT LOCALIZATION TESTS: %d checks, %d failures" % [checks, failures])
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
	_check(FontArt.has_cjk_support(actual), "System font covers translated Second Light glyphs: " + source)
	_check(Locale.translate(actual) == actual, "Repeated rendering preserves Chinese text: " + source)
	Locale.set_language("en")
	_check(Locale.translate(source) == source, "English preserves canonical text and case: " + source)
	Locale.set_language("zh_CN")


func _test_labels() -> void:
	_expect("NERI", "奈里")
	_expect("ILYA", "伊莱亚")
	_expect("NERI / CHANNEL CHALLENGER", "奈里 / 水渠挑战者")
	_expect("ILYA / SECOND LIGHT KEEPER", "伊莱亚 / 第二航灯守护人")
	_expect("E  NERI / CHANNEL CHALLENGER", "E  奈里 / 水渠挑战者")
	_expect("E  ILYA / SECOND LIGHT KEEPER", "E  伊莱亚 / 第二航灯守护人")
	_expect("NERI / CHANNEL CHALLENGE", "奈里 / 水渠对战")
	_expect("SECOND LIGHT TRIAL", "第二航灯试炼")
	_expect("THE SECOND LIGHT / CHAPTER II", "第二盏航灯 / 第二章")
	_expect("SECOND LIGHT BEACON", "第二航灯")
	_expect("THE SECOND LIGHT", "第二盏航灯")
	_expect("TWO SEA-LANES SHINE AGAIN.", "两条航路重新闪耀。")
	_expect("TWO LIGHTS, ONE SHARED HORIZON.", "两盏灯火，同一片远方。")
	_expect("LANTERNWAKE / END OF CHAPTER II", "灯潮纪 / 第二章结束")
	_expect("SECOND LIGHT CREST", "第二航灯徽章")
	_expect("MEET NERI BY THE NORTHERN WATER CHANNEL", "前往北侧水渠与奈里交谈")
	_expect("CHALLENGE ILYA AT THE SECOND LIGHT BEACON", "前往第二航灯挑战伊莱亚")
	_expect("TWO LIGHTS NOW GUIDE THE SEA-LANES", "两盏航灯照亮海上归途")
	_expect("DEFEAT NERI", "战胜奈里")
	_expect("WIN THE SECOND LIGHT", "赢得第二航灯试炼")
	for count: int in range(3):
		_expect("LIGHTS AWAKENED %d / 2" % count, "已点亮航灯%d/2" % count)


func _test_dynamic_logs() -> void:
	for companion: Array in [["Rillisk", "檐溪蜥"], ["Terracurl", "阶纹蜗"], ["Glimveil", "灯纱蝠"], ["Noctulume", "夜辉鸮"]]:
		_expect("Neri sends out %s!" % companion[0], "奈里派出了%s！" % companion[1])
		_expect("The Second Light Trial begins! %s enters." % companion[0], "第二航灯试炼开始！%s登场。" % companion[1])
	_expect("This challenge is not available yet. Check your route and milestones.", "这场挑战尚未开放，请确认所在路线和旅程进度。")
	_expect("This challenge is already complete.", "这场挑战已经完成。")
	_expect("Complete the current trial requirements first.", "先完成当前试炼前置。")
	_expect("Neri's channel challenge is complete. The second beacon is ready.", "奈里的水渠挑战完成了，可以前往第二航灯。")
	_expect("Trial complete! You earned the Rainlight Sigil.", "试炼完成！你获得了第二航灯徽章。")
	_expect("Two lights now guide the sea-lanes.", "两盏航灯照亮海上归途。")
	for trainer: Array in [["Ivo", "伊沃"], ["Soren", "索伦"], ["Neri", "奈里"], ["Ilya", "伊莱亚"]]:
		for counts: Array in [[4, 2], [1, 0], [0, 0]]:
			_expect("%s gives you %d orbs and %d tonics." % [trainer[0], counts[0], counts[1]], "%s送给你%d个回声瓶和%d瓶药剂。" % [trainer[1], counts[0], counts[1]])


func _check_wrapping(source: String, columns: int, maximum_lines: int) -> void:
	var lines: Array[String] = FontArt.wrap(source, columns, 2)
	_check(lines.size() <= maximum_lines, "Wrapped text fits its panel in " + Locale.language + ": " + source)
	_check("".join(lines).replace(" ", "") == Locale.translate(source).replace(" ", ""), "Wrapping preserves every character in " + Locale.language + ": " + source)
	for line: String in lines:
		_check(FontArt.width(line, 2) <= float(columns * 12), "Wrapped line fits its width in " + Locale.language + ": " + source)


func _test_challenge_catalog() -> void:
	_check(ResourceLoader.exists("res://scripts/challenge_db.gd"), "Challenge metadata is available for real-source translation coverage")
	if not ResourceLoader.exists("res://scripts/challenge_db.gd"):
		return
	var catalog: GDScript = load("res://scripts/challenge_db.gd")
	for id: String in ["harbor_ivo", "first_light", "rain_trial", "second_light"]:
		var definition: Dictionary = catalog.data(id)
		var sources: Array[String] = [str(definition.title), str(definition.trainer)]
		for name: String in ["Rillisk", "Terracurl", "Glimveil"]:
			sources.append(str(definition.opening) % name)
		for line: String in definition.victory_lines:
			sources.append(line)
		sources.append("%s gives you %d orbs and %d tonics." % [str(definition.trainer), int(definition.reward_orbs), int(definition.reward_tonics)])
		for source: String in sources:
			Locale.set_language("zh_CN")
			var translated: String = Locale.translate(source)
			_check(translated != source and translated != source.to_upper(), "Actual challenge metadata has a Chinese display value: " + source)
			_check(FontArt.has_cjk_support(translated), "System font covers actual challenge metadata: " + source)
			_check(Locale.translate(translated) == translated, "Actual challenge metadata remains translated on repeated rendering: " + source)
			Locale.set_language("en")
			_check(Locale.translate(source) == source, "Actual challenge metadata retains canonical English: " + source)
			for language: String in ["zh_CN", "en"]:
				Locale.set_language(language)
				_check_wrapping(source, 43, 2)
	Locale.set_language("zh_CN")


func _test_dialogue() -> void:
	var lines: Array = [
		["Your companions know how to listen to each other. Ilya is waiting at the beacon at the end of the northern path.", "你的伙伴已经懂得彼此倾听。沿北侧小路走到尽头，伊莱亚正在航灯旁等你。"],
		["First help the water find its way through all three channels, then report to Orla. A shared light begins with work that helps someone else.", "先疏通三处水路，再向奥菈报个平安。愿意为别人出一份力，才有大家共享的灯火。"],
		["The channels are singing again. Let us see how your companions answer one another. I will rest your team before we begin.", "水渠又唱起歌了。让我听听你的伙伴如何互相应和。开始前，先让大家休息一下。"],
		["My Rillisk moves quickly; my Terracurl stands firm. A plain Strike is useful when an element is resisted.", "我的檐溪蜥行动敏捷，阶纹蜗稳如磐石。属性受到抵抗时，不妨试试普通的轻击。"],
		["This beacon asks for two things: bring the rain back to the gardens, and learn to listen in Neri's channel challenge.", "这盏航灯有两个愿望：让雨水重回菜圃，并在奈里的水渠挑战中学会倾听。"],
		["Report the waterworks to Orla, then meet Neri on the northern crossing. I will be here when you are ready.", "先向奥菈报告水路已经修好，再去北侧岔路见奈里。准备好后，我会在这里等你。"],
		["A light carried alone is a spark. A light shared across the sea becomes a promise.", "独自捧着的光，是一点火花。越过海面与人分享的光，便成了一份约定。"],
		["Your team may rest here. Face my Terracurl, Rillisk, and Glimveil; use your whole party, and take time to recover when you need it.", "让伙伴们在这里歇一歇。接下来面对我的阶纹蜗、檐溪蜥与灯纱蝠吧。发挥全队的力量，需要时就恢复体力。"],
		["You gave every voice its moment. Take these supplies, and follow the central path north to Ilya's beacon.", "你给每个声音都留出了机会。收下这些补给，沿中央小路向北，去伊莱亚的航灯吧。"],
		["The Second Light trial has three companions. Switch when a matchup is difficult, and let Orla help whenever you need a rest.", "第二航灯试炼有三位对手。遇到难以应对的属性就换位，需要休息时，随时去找奥菈。"],
		["Listen. The water below and the light above are answering each other. Rainstep has found its voice again.", "听，脚下的流水与头顶的灯光正在彼此应和。雨阶岛又找回了自己的声音。"],
		["Take the Second Light crest. Tonight, our beacon and Wakeharbor's lamp will draw a path across the mist.", "收下第二航灯徽章吧。今夜，我们的航灯和醒潮港的灯火，会在雾中连成一条归途。"],
		["Two islands, two lights, and all the small companions who carried us here. Let the next traveller find a brighter shore.", "两座岛，两盏灯，还有一路陪我们走来的小小伙伴。愿下一位旅人，遇见更明亮的海岸。"],
	]
	for pair: Array in lines:
		var source: String = str(pair[0])
		_expect(source, str(pair[1]))
		for language: String in ["zh_CN", "en"]:
			Locale.set_language(language)
			_check_wrapping(source, 88, 3)
	Locale.set_language("zh_CN")


func _test_layout() -> void:
	for language: String in ["zh_CN", "en"]:
		Locale.set_language(language)
		for label: String in ["NERI / CHANNEL CHALLENGER", "ILYA / SECOND LIGHT KEEPER"]:
			_check(FontArt.width("E  " + label, 1) <= 500.0, "Interaction label fits its button in " + language + ": " + label)
			_check(FontArt.width(label, 2) <= 1100.0, "Speaker label fits its dialogue panel in " + language + ": " + label)
		for label: String in ["NERI / CHANNEL CHALLENGE", "SECOND LIGHT TRIAL"]:
			_check(FontArt.width(label, 2) <= 780.0, "Battle heading avoids opponent health panel in " + language + ": " + label)
		for label: String in ["MEET NERI BY THE NORTHERN WATER CHANNEL", "CHALLENGE ILYA AT THE SECOND LIGHT BEACON", "TWO LIGHTS NOW GUIDE THE SEA-LANES"]:
			_check_wrapping(label, 35, 2)
			_check_wrapping(label, 32, 3)
		for label: String in ["THE SECOND LIGHT / CHAPTER II", "SECOND LIGHT BEACON", "SECOND LIGHT CREST", "LIGHTS AWAKENED 2 / 2", "DEFEAT NERI", "WIN THE SECOND LIGHT"]:
			_check(FontArt.width(label, 1) <= 320.0, "Progress label fits its panel in " + language + ": " + label)
		_check(FontArt.width("THE SECOND LIGHT", 5) <= 1120.0, "Ending title stays within screen in " + language)
		for label: String in ["TWO SEA-LANES SHINE AGAIN.", "TWO LIGHTS, ONE SHARED HORIZON."]:
			_check(FontArt.width(label, 2) <= 1120.0, "Ending subtitle stays within screen in " + language + ": " + label)
		_check(FontArt.width("LANTERNWAKE / END OF CHAPTER II", 1) <= 1120.0, "Ending chapter label stays within screen in " + language)
		for source: String in ["Neri sends out Terracurl!", "The Second Light Trial begins! Glimveil enters.", "This challenge is not available yet. Check your route and milestones.", "This challenge is already complete.", "Neri's channel challenge is complete. The second beacon is ready.", "Trial complete! You earned the Rainlight Sigil.", "Two lights now guide the sea-lanes.", "Ilya gives you 4 orbs and 2 tonics."]:
			_check_wrapping(source, 43, 2)
	Locale.set_language("zh_CN")


func _test_internal_identifiers() -> void:
	for language: String in ["zh_CN", "en"]:
		Locale.set_language(language)
		for source: String in ["harbor_ivo", "first_light", "rain_trial", "rain_gym", "second_light", "rain_neri", "rain_ilya", "LIGHTS AWAKENED 2 / 3", "Mira gives you 4 orbs and 2 tonics.", "An unknown Second Light message."]:
			_check(Locale.translate(source) == source, "Internal identifiers and unknown text remain intact in " + language + ": " + source)
