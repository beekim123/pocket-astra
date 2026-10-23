class_name PixelFont
extends RefCounted
## Original bitmap English plus readable Chinese from the host's installed fonts.
## No external font resource is imported, copied, generated, or distributed.

const Locale = preload("res://scripts/localization.gd")
const CLOSING_PUNCTUATION: String = "，。！？；：、）》】〕〉」』”’,.!?;:)]}"
const SYSTEM_FONT_NAMES: PackedStringArray = [
	"PingFang SC", "Noto Sans CJK SC", "Microsoft YaHei", "WenQuanYi Micro Hei"
]

static var _system_font: SystemFont
static var _checked_system_font: bool = false

const GLYPHS: Dictionary = {
	"A": [14, 17, 17, 31, 17, 17, 17],
	"B": [30, 17, 17, 30, 17, 17, 30],
	"C": [14, 17, 16, 16, 16, 17, 14],
	"D": [30, 17, 17, 17, 17, 17, 30],
	"E": [31, 16, 16, 30, 16, 16, 31],
	"F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 15],
	"H": [17, 17, 17, 31, 17, 17, 17],
	"I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 18, 18, 12],
	"K": [17, 18, 20, 24, 20, 18, 17],
	"L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17],
	"N": [17, 25, 25, 21, 19, 19, 17],
	"O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16],
	"Q": [14, 17, 17, 17, 21, 18, 13],
	"R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30],
	"T": [31, 4, 4, 4, 4, 4, 4],
	"U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4],
	"W": [17, 17, 17, 21, 21, 27, 17],
	"X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 10, 4, 4, 4, 4],
	"Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14],
	"1": [4, 12, 4, 4, 4, 4, 14],
	"2": [14, 17, 1, 2, 4, 8, 31],
	"3": [30, 1, 1, 14, 1, 1, 30],
	"4": [2, 6, 10, 18, 31, 2, 2],
	"5": [31, 16, 16, 30, 1, 1, 30],
	"6": [14, 16, 16, 30, 17, 17, 14],
	"7": [31, 1, 2, 4, 8, 8, 8],
	"8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 1, 14],
	" ": [0, 0, 0, 0, 0, 0, 0],
	".": [0, 0, 0, 0, 0, 6, 6],
	",": [0, 0, 0, 0, 0, 6, 4],
	":": [0, 6, 6, 0, 6, 6, 0],
	";": [0, 6, 6, 0, 6, 4, 8],
	"!": [4, 4, 4, 4, 4, 0, 4],
	"?": [14, 17, 1, 2, 4, 0, 4],
	"-": [0, 0, 0, 31, 0, 0, 0],
	"_": [0, 0, 0, 0, 0, 0, 31],
	"+": [0, 4, 4, 31, 4, 4, 0],
	"=": [0, 0, 31, 0, 31, 0, 0],
	"/": [1, 1, 2, 4, 8, 16, 16],
	"\\": [16, 16, 8, 4, 2, 1, 1],
	"(": [2, 4, 8, 8, 8, 4, 2],
	")": [8, 4, 2, 2, 2, 4, 8],
	"[": [14, 8, 8, 8, 8, 8, 14],
	"]": [14, 2, 2, 2, 2, 2, 14],
	"<": [1, 2, 4, 8, 4, 2, 1],
	">": [16, 8, 4, 2, 4, 8, 16],
	"'": [4, 4, 8, 0, 0, 0, 0],
	"\"": [10, 10, 20, 0, 0, 0, 0],
	"%": [25, 25, 2, 4, 8, 19, 19],
	"&": [12, 18, 20, 8, 21, 18, 13],
	"*": [0, 21, 14, 31, 14, 21, 0],
	"#": [10, 31, 10, 10, 31, 10, 0],
	"@": [14, 17, 23, 21, 23, 16, 14],
	"|": [4, 4, 4, 4, 4, 4, 4],
	"~": [0, 0, 9, 22, 0, 0, 0],
	"$": [4, 15, 20, 14, 5, 30, 4],
	"^": [4, 10, 17, 0, 0, 0, 0],
	"`": [8, 4, 2, 0, 0, 0, 0],
	"{": [2, 4, 4, 8, 4, 4, 2],
	"}": [8, 4, 4, 2, 4, 4, 8],
	"♥": [0, 10, 31, 31, 14, 4, 0],
	"★": [4, 4, 31, 14, 14, 17, 0],
	"→": [0, 4, 2, 31, 2, 4, 0],
	"←": [0, 4, 8, 31, 8, 4, 0],
	"↑": [4, 14, 21, 4, 4, 4, 0],
	"↓": [0, 4, 4, 4, 21, 14, 4],
}


static func text(canvas: CanvasItem, value: String, pos: Vector2, size: int = 2, color: Color = Color.WHITE) -> void:
	var translated: String = Locale.translate(value)
	var scale_px: int = maxi(size, 1)
	var cursor: Vector2 = pos.round()
	var step: int = _system_line_height(scale_px) if _needs_system_font(translated) else 9 * scale_px
	for line: String in translated.split("\n"):
		if _needs_system_font(line):
			var font: SystemFont = _font()
			var font_size: int = _font_size(scale_px)
			if not _checked_system_font:
				_checked_system_font = true
				if not has_cjk_support():
					push_warning("Chinese glyphs require an installed CJK font. Use English in Settings or install a system CJK font.")
			canvas.draw_string(font, cursor + Vector2(0, ceilf(font.get_ascent(font_size))), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		else:
			_bitmap_text(canvas, line, cursor, scale_px, color)
		cursor.y += step


static func width(value: String, size: int = 2) -> float:
	var longest: float = 0.0
	for line: String in Locale.translate(value).split("\n"):
		longest = maxf(longest, _line_width(line, size))
	return longest


static func line_height(size: int = 2) -> int:
	return _system_line_height(size) if Locale.chinese() else 9 * maxi(size, 1)


static func has_cjk_support(value: String = "星光旅程伙伴") -> bool:
	var font: SystemFont = _font()
	for character: String in value:
		if _needs_system_font(character) and not font.has_char(character.unicode_at(0)):
			return false
	return true


static func wrap(value: String, max_chars: int, size: int = 2) -> Array[String]:
	var translated: String = Locale.translate(value)
	if not _needs_system_font(translated):
		return _bitmap_wrap(translated, max_chars)
	var lines: Array[String] = []
	# Preserve the original UI's pixel budget instead of counting Han characters.
	var budget: float = float(maxi(max_chars, 1) * 6 * maxi(size, 1))
	for paragraph: String in translated.split("\n"):
		if paragraph.is_empty():
			lines.append("")
			continue
		var line: String = ""
		var pending_space: bool = false
		for token: String in _word_tokens(paragraph):
			if token == " ":
				pending_space = not line.is_empty()
				continue
			var gap: String = " " if pending_space and not line.is_empty() else ""
			pending_space = false
			if not line.is_empty():
				if _line_width(line + gap + token, size) <= budget:
					line += gap + token
					continue
				lines.append(line)
				line = ""
				gap = ""
			var remaining: String = token
			while remaining.length() > 1 and _line_width(remaining, size) > budget:
				var count: int = 1
				while count < remaining.length() and _line_width(remaining.left(count + 1), size) <= budget:
					count += 1
				# Keep final punctuation with its preceding character when it fits.
				if count > 1 and count < remaining.length() and CLOSING_PUNCTUATION.contains(remaining.substr(count, 1)):
					count -= 1
				lines.append(remaining.left(count))
				remaining = remaining.substr(count)
			line += gap + remaining
		if not line.is_empty():
			lines.append(line)
	if lines.is_empty():
		lines.append("")
	return lines


static func _font() -> SystemFont:
	if _system_font == null:
		_system_font = SystemFont.new()
		_system_font.font_names = SYSTEM_FONT_NAMES
		_system_font.allow_system_fallback = true
		_system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		# Keep a bounded shaping cache; gameplay text is not cached as image assets.
		_system_font.set_cache_capacity(128, 16)
	return _system_font


static func _font_size(size: int) -> int:
	match maxi(size, 1):
		1: return 12
		2: return 18
		3: return 24
		_: return maxi(size, 1) * 8


static func _system_line_height(size: int) -> int:
	return maxi(9 * maxi(size, 1), ceili(_font().get_height(_font_size(size))) + 2)


static func _needs_system_font(value: String) -> bool:
	for character: String in value:
		if character.unicode_at(0) > 127 and not GLYPHS.has(character):
			return true
	return false


static func _line_width(value: String, size: int) -> float:
	if _needs_system_font(value):
		return ceilf(_font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(size)).x)
	return float(value.length() * 6 * maxi(size, 1))


static func _word_tokens(value: String) -> Array[String]:
	var tokens: Array[String] = []
	var word: String = ""
	for character: String in value:
		var codepoint: int = character.unicode_at(0)
		var word_character: bool = (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122) or character in ["'", "-", "_"]
		if word_character:
			word += character
			continue
		if not word.is_empty():
			tokens.append(word)
			word = ""
		if CLOSING_PUNCTUATION.contains(character) and not tokens.is_empty() and tokens[-1] != " ":
			tokens[-1] += character
		else:
			tokens.append(" " if character in [" ", "\t", "\r"] else character)
	if not word.is_empty():
		tokens.append(word)
	return tokens


static func _bitmap_text(canvas: CanvasItem, value: String, pos: Vector2, scale_px: int, color: Color) -> void:
	var cursor: Vector2 = pos
	for character: String in value.to_upper():
		var rows: Array = GLYPHS.get(character, GLYPHS["?"])
		for y: int in range(7):
			# Merge adjacent lit pixels into one draw call without softening edges.
			var start: int = -1
			for x: int in range(6):
				var filled: bool = x < 5 and (int(rows[y]) & (1 << (4 - x))) != 0
				if filled and start < 0:
					start = x
				elif not filled and start >= 0:
					canvas.draw_rect(Rect2(cursor + Vector2(start, y) * scale_px, Vector2(x - start, 1) * scale_px), color)
					start = -1
		cursor.x += 6 * scale_px


static func _bitmap_wrap(value: String, max_chars: int) -> Array[String]:
	var lines: Array[String] = []
	var limit: int = maxi(max_chars, 1)
	for paragraph: String in value.split("\n"):
		var line: String = ""
		for raw_word: String in paragraph.split(" ", false):
			var word: String = raw_word
			if not line.is_empty() and line.length() + 1 + word.length() > limit:
				lines.append(line)
				line = ""
			while word.length() > limit:
				lines.append(word.substr(0, limit))
				word = word.substr(limit)
			if not word.is_empty():
				line += (" " if not line.is_empty() else "") + word
		if not line.is_empty() or paragraph.is_empty():
			lines.append(line)
	if lines.is_empty():
		lines.append("")
	return lines
