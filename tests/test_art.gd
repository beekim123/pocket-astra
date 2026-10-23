extends SceneTree
## Source-art contract checks; no files are exported and no scene is rendered.
## Run centrally: godot --headless --path . --script tests/test_art.gd

const Art = preload("res://scripts/art.gd")
const FontArt = preload("res://scripts/pixel_font.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_test_creatures()
	_test_people()
	_test_ground()
	_test_foliage()
	_test_font()
	print("ART TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)


func _signature(texture: Texture2D, expected: Vector2i, label: String) -> String:
	_check(texture != null, label + " has a texture")
	if texture == null:
		return ""
	_check(texture.get_size() == Vector2(expected), label + " has the intended canvas size")
	var image: Image = texture.get_image()
	_check(image != null and not image.is_empty(), label + " exposes pixel data")
	if image == null or image.is_empty():
		return ""
	var bounds: Rect2i = image.get_used_rect()
	_check(bounds.has_area() and bounds.size.x > 8 and bounds.size.y > 8, label + " contains visible artwork")
	return image.get_data().hex_encode().sha256_text()


func _test_creatures() -> void:
	var signatures: Dictionary = {}
	for id: int in range(8):
		for frame: int in range(3):
			for back: bool in [false, true]:
				var label: String = "Creature %d frame %d rear %s" % [id, frame, back]
				var texture: Texture2D = Art.creature(id, frame, back)
				var signature: String = _signature(texture, Vector2i(80, 80), label)
				_check(texture == Art.creature(id, frame, back), label + " reuses its cached resource")
				_check(texture == Art.creature(id, frame + 3, back), label + " loops after three frames")
				if not signature.is_empty():
					_check(not signatures.has(signature), label + " differs from every other species, frame, and direction")
					signatures[signature] = label
	_check(signatures.size() == 48, "All eight species have three distinct front and rear views")


func _test_people() -> void:
	var role_signatures: Dictionary = {}
	for role: String in ["player", "mentor", "rival", "keeper", "healer"]:
		var directions: Dictionary = {}
		for direction: int in range(4):
			var frame_signatures: Dictionary = {}
			for frame: int in range(3):
				var label: String = "%s direction %d frame %d" % [role, direction, frame]
				var texture: Texture2D = Art.person(role, frame, direction)
				var signature: String = _signature(texture, Vector2i(32, 48), label)
				_check(texture == Art.person(role, frame, direction), label + " reuses its cached resource")
				_check(not frame_signatures.has(signature), label + " has a distinct walk pose")
				frame_signatures[signature] = true
				if frame == 0:
					_check(not directions.has(signature), label + " visibly faces its own direction")
					directions[signature] = true
					if direction == 0:
						_check(not role_signatures.has(signature), label + " has a distinct outfit")
						role_signatures[signature] = true


func _test_ground() -> void:
	var signatures: Dictionary = {}
	for kind: String in ["grass", "stone", "roof", "wood"]:
		var texture: Texture2D = Art.ground(kind)
		var signature: String = _signature(texture, Vector2i(64, 64), kind)
		_check(texture == Art.ground(kind), kind + " uses a shared deterministic tile")
		_check(not signatures.has(signature), kind + " has its own surface pattern")
		signatures[signature] = true


func _test_foliage() -> void:
	var signatures: Dictionary = {}
	for variant: int in range(8):
		var texture: Texture2D = Art.foliage(variant)
		var signature: String = _signature(texture, Vector2i(64, 64), "Foliage %d" % variant)
		_check(texture == Art.foliage(variant), "Foliage variant is cached")
		_check(not signatures.has(signature), "Foliage variants have distinct leaf clusters")
		signatures[signature] = true


func _test_font() -> void:
	for codepoint: int in range(32, 127):
		var character: String = String.chr(codepoint)
		var uppercase: String = character.to_upper()
		_check(FontArt.GLYPHS.has(uppercase), "ASCII glyph is available: " + character)
		_check(FontArt.width(character, 2) == 12.0, "ASCII glyph occupies one six-pixel advance: " + character)
		if not FontArt.GLYPHS.has(uppercase):
			continue
		var rows: Array = FontArt.GLYPHS[uppercase]
		_check(rows.size() == 7, "Glyph has seven rows: " + character)
		var lit_pixels: bool = false
		for row: int in rows:
			_check(row >= 0 and row <= 31, "Glyph remains within five columns: " + character)
			lit_pixels = lit_pixels or row != 0
		_check(lit_pixels or character == " ", "Non-space glyph has visible pixels: " + character)
	_check(FontArt.width("AB\nC", 2) == 24.0, "Multiline width measures the longest line")
	_check(FontArt.width("", 2) == 0.0, "Empty text has zero width")
	_check(FontArt.wrap("A LONG WORD", 6) == ["A LONG", "WORD"], "Wrapping preserves whole words when possible")
	_check(FontArt.wrap("LANTERNWAKE", 4) == ["LANT", "ERNW", "AKE"], "Oversized words cannot escape the requested width")
	_check(FontArt.wrap("A\n\nB", 6) == ["A", "", "B"], "Explicit blank lines survive wrapping")
	_check(FontArt.wrap("", 6) == [""], "Empty text produces one empty line")
