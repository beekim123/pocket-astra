extends SceneTree
## Font boundary checks. Run centrally with the shared single-worker budget.

const FontArt = preload("res://scripts/pixel_font.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	# This catches the old one-bitmap-cell-per-Chinese-character layout.
	_check(FontArt.width("星", 2) >= 16.0, "Chinese uses a readable full-sized system glyph")
	_check(FontArt.width("星星", 2) > FontArt.width("星", 2), "Chinese string width includes every glyph")
	_check(FontArt.width("星星\n星", 2) == FontArt.width("星星", 2), "Chinese multiline width measures the widest line")
	_test_chinese_wrap()
	_test_language_switch()
	_test_catalog_glyphs()
	print("CHINESE FONT TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _test_chinese_wrap() -> void:
	var paragraph: String = "沿着星光前行，寻找迷路的伙伴。带上勇气，继续这段旅程！"
	var lines: Array[String] = FontArt.wrap(paragraph, 8)
	_check("".join(lines) == paragraph, "Chinese wrapping retains every character without question-mark substitution")
	for line: String in lines:
		_check(FontArt.width(line, 2) <= 96.0, "Chinese wrapping stays within the existing 96-pixel box: " + line)
		_check(not "，。！？；：、）》】”’".contains(line.left(1)), "Closing punctuation stays with the preceding word: " + line)
	_check(FontArt.wrap("星\n\n光", 8) == ["星", "", "光"], "Chinese wrapping preserves intentional blank lines")
	var mixed: String = "前往 Maple Harbor，获得 24 SP！"
	var mixed_lines: Array[String] = FontArt.wrap(mixed, 12)
	_check("".join(mixed_lines).replace(" ", "") == mixed.replace(" ", ""), "Mixed English and Chinese wrapping keeps all content")
	_check("\n".join(mixed_lines).contains("Maple"), "Mixed wrapping keeps an English word intact when it fits")
	for line: String in mixed_lines:
		_check(FontArt.width(line, 2) <= 144.0, "Mixed wrapping stays within its pixel budget: " + line)
	for size: int in [1, 2, 3, 4]:
		var sized_lines: Array[String] = FontArt.wrap(paragraph, 8, size)
		_check("".join(sized_lines) == paragraph, "Every UI font size retains the full Chinese paragraph")
		for line: String in sized_lines:
			_check(FontArt.width(line, size) <= 48.0 * size, "Chinese wrapping respects the chosen UI size")


func _test_language_switch() -> void:
	# Load dynamically so the red-stage test can run before localization is added.
	if not ResourceLoader.exists("res://scripts/localization.gd"):
		_check(false, "The language service is available")
		return
	var locale: GDScript = load("res://scripts/localization.gd")
	locale.set_language("en")
	for size: int in [1, 2, 3, 4]:
		_check(FontArt.width("Hello 123!", size) == 60.0 * size, "English keeps the original six-pixel bitmap advance")
	_check(FontArt.wrap("A LONG WORD", 6) == ["A LONG", "WORD"], "English keeps whole-word wrapping")
	_check(FontArt.wrap("LANTERNWAKE", 4) == ["LANT", "ERNW", "AKE"], "English keeps bounded long-word wrapping")
	locale.set_language("zh_CN")
	var translated: String = locale.translate("BEGIN A NEW JOURNEY")
	_check(translated != "BEGIN A NEW JOURNEY", "The title action is translated in Chinese mode")
	_check(FontArt.width("BEGIN A NEW JOURNEY", 2) == FontArt.width(translated, 2), "Font measurement translates the same text as rendering")
	_check(FontArt.wrap("BEGIN A NEW JOURNEY", 20) == [translated], "Wrapping translates before computing line breaks")
	var font_api: RefCounted = FontArt.new()
	_check(font_api.has_method("has_cjk_support"), "Font exposes missing-system-glyph detection")
	if font_api.has_method("has_cjk_support"):
		_check(font_api.call("has_cjk_support"), "This machine has a system font that supports Chinese")
	locale.set_language("en")
	_check(FontArt.width("BEGIN A NEW JOURNEY", 2) == 228.0, "Switching back restores the original English width")
	locale.set_language("zh_CN")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func _test_catalog_glyphs() -> void:
	var locale: GDScript = load("res://scripts/localization.gd")
	var seen: Dictionary = {}
	var texts: Array = locale.TEXT.values()
	for template: Array in locale.TEMPLATES:
		texts.append(str(template[1]))
	for translated: String in texts:
		for character: String in translated:
			if character.unicode_at(0) > 127 and not seen.has(character):
				seen[character] = true
				_check(FontArt.has_cjk_support(character), "System font covers catalog character: " + character)
