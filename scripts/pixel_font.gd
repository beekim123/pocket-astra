class_name PixelFont
extends RefCounted
## An original five-by-seven bitmap alphabet. No font files or system fonts.

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
	var scale_px: int = maxi(size, 1)
	var cursor: Vector2 = pos.round()
	for character: String in value.to_upper():
		if character == "\n":
			cursor.x = roundf(pos.x)
			cursor.y += 9 * scale_px
			continue
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


static func width(value: String, size: int = 2) -> float:
	var longest: int = 0
	for line: String in value.split("\n"):
		longest = maxi(longest, line.length())
	return float(longest * 6 * maxi(size, 1))


static func wrap(value: String, max_chars: int) -> Array[String]:
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
