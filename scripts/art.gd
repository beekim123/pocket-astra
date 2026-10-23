class_name ProceduralArt
extends RefCounted
## Hand-painted pixel clusters generated once, then kept as shared textures.
## All artwork is original and lives in this source file.

const INK: Color = Color("202433")
const CREAM: Color = Color("fff1cf")
const GOLD: Color = Color("f5cf79")
static var _textures: Dictionary = {}


static func creature(id: int, frame: int = 0, back: bool = false) -> Texture2D:
	var species: int = posmod(id, 8)
	var pose: int = posmod(frame, 3)
	var key: String = "creature_%d_%d_%s" % [species, pose, back]
	if _textures.has(key):
		return _textures[key] as Texture2D
	var art: Image = Image.create(80, 80, false, Image.FORMAT_RGBA8)
	match species:
		0: _cindermew(art, pose, back)
		1: _brookfin(art, pose, back)
		2: _mossbell(art, pose, back)
		3: _wispip(art, pose, back)
		4: _pebblit(art, pose, back)
		5: _reedrill(art, pose, back)
		6: _voltkite(art, pose, back)
		7: _noctulume(art, pose, back)
	_outline(art)
	if back:
		art.flip_x()
	if pose == 1:
		var lifted: Image = Image.create(80, 80, false, Image.FORMAT_RGBA8)
		lifted.blit_rect(art, Rect2i(0, 1, 80, 79), Vector2i.ZERO)
		art = lifted
	var texture: ImageTexture = ImageTexture.create_from_image(art)
	_textures[key] = texture
	return texture


static func person(role: String = "player", frame: int = 0, direction: int = 0) -> Texture2D:
	var pose: int = posmod(frame, 3)
	var facing: int = posmod(direction, 4)
	var key: String = "person_%s_%d_%d" % [role, pose, facing]
	if _textures.has(key):
		return _textures[key] as Texture2D
	var art: Image = Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var coat: Color = Color("427b7a")
	var coat_shadow: Color = Color("2d4d62")
	var coat_light: Color = Color("77b0a0")
	var scarf: Color = Color("e78c66")
	var hair: Color = Color("523e42")
	var hat: Color = Color("d9bf80")
	match role:
		"mentor":
			coat = Color("79759c")
			coat_shadow = Color("474967")
			coat_light = Color("aba2bd")
			scarf = GOLD
			hair = Color("d4d0bb")
		"rival":
			coat = Color("bb665f")
			coat_shadow = Color("70425a")
			coat_light = Color("e49a79")
			scarf = Color("7bcecc")
			hair = Color("3a334a")
		"keeper":
			coat = Color("73966b")
			coat_shadow = Color("435d59")
			coat_light = Color("b4bf84")
			scarf = Color("dda866")
			hair = Color("704f45")
		"healer":
			coat = Color("d9d4b4")
			coat_shadow = Color("829b95")
			coat_light = CREAM
			scarf = Color("df8d97")
			hair = Color("776079")
			hat = Color("e7dbb9")
	var skin: Color = Color("eab88e")
	var skin_light: Color = Color("ffdab0")
	var step: int = 1 if pose == 1 else (-1 if pose == 2 else 0)
	var bob: int = -1 if pose == 1 else 0
	var side: bool = facing >= 2
	# Boots and separated legs provide a readable walk even at native size.
	_rect(art, 10, 33 + step, 5, 9, Color("344350"))
	_rect(art, 18, 33 - step, 5, 9, Color("344350"))
	_rect(art, 9, 40 + step, 7, 4, Color("493a3b"))
	_rect(art, 18, 40 - step, 7, 4, Color("493a3b"))
	_rect(art, 10, 40 + step, 5, 1, Color("947663"))
	_rect(art, 19, 40 - step, 4, 1, Color("947663"))
	_poly(art, [9, 23 + bob, 22, 23 + bob, 25, 35, 19, 37, 16, 35, 12, 37, 7, 35], coat_shadow)
	_poly(art, [10, 23 + bob, 21, 23 + bob, 22, 33, 18, 34, 16, 32, 12, 34, 9, 33], coat)
	_rect(art, 10, 25 + bob, 3, 7, coat_light)
	_rect(art, 6, 25 + bob - step, 4, 9, coat)
	_rect(art, 23, 25 + bob + step, 4, 9, coat_shadow)
	_rect(art, 6, 33 + bob - step, 4, 4, skin)
	_rect(art, 23, 33 + bob + step, 4, 4, skin)
	_rect(art, 9, 32, 14, 2, Color("705345"))
	_rect(art, 15, 32, 3, 2, GOLD)
	_rect(art, 11, 15 + bob, 12, 10, skin)
	_rect(art, 12, 15 + bob, 9, 7, skin_light)
	_rect(art, 9, 13 + bob, 15, 5, hair)
	_rect(art, 9, 16 + bob, 3, 6, hair)
	_rect(art, 22, 15 + bob, 2, 7, hair)
	if facing == 1:
		_rect(art, 10, 15 + bob, 13, 10, hair)
		_rect(art, 12, 18 + bob, 3, 5, hair.lightened(0.12))
		# The travelling satchel distinguishes the rear of the coat.
		_rect(art, 12, 26 + bob, 10, 9, Color("8c684d"))
		_rect(art, 12, 26 + bob, 10, 3, Color("c49b67"))
		_rect(art, 16, 28 + bob, 2, 3, GOLD)
	elif side:
		_rect(art, 10, 18 + bob, 2, 2, INK)
		_rect(art, 8, 20 + bob, 4, 2, skin_light)
		_rect(art, 16, 15 + bob, 8, 9, hair)
		_rect(art, 21, 26 + bob, 6, 8, Color("9b7958"))
		_rect(art, 22, 27 + bob, 4, 2, GOLD)
	else:
		_rect(art, 12, 18 + bob, 2, 2, INK)
		_rect(art, 20, 18 + bob, 2, 2, INK)
		_rect(art, 16, 22 + bob, 3, 1, Color("b87968"))
		_rect(art, 20, 29 + bob, 2, 2, GOLD)
	_rect(art, 10, 23 + bob, 14, 3, scarf)
	_poly(art, [20, 24 + bob, 25, 24 + bob, 28, 31 + bob + step, 23, 29 + bob], scarf)
	_rect(art, 11, 23 + bob, 7, 1, scarf.lightened(0.24))
	if role == "rival":
		_poly(art, [8, 14 + bob, 10, 8 + bob, 14, 10 + bob, 16, 6 + bob, 20, 10 + bob, 24, 9 + bob, 25, 16 + bob], hair)
		_rect(art, 9, 13 + bob, 15, 2, scarf)
	elif role == "mentor":
		_poly(art, [9, 14 + bob, 8, 10 + bob, 12, 8 + bob, 22, 9 + bob, 25, 14 + bob], hair)
		if facing == 0:
			_poly(art, [12, 21 + bob, 16, 23 + bob, 22, 21 + bob, 20, 26 + bob, 15, 26 + bob], hair)
			_rect(art, 12, 18 + bob, 4, 1, GOLD)
			_rect(art, 19, 18 + bob, 4, 1, GOLD)
	else:
		_poly(art, [8, 12 + bob, 11, 7 + bob, 20, 7 + bob, 24, 12 + bob], hat)
		_rect(art, 5, 12 + bob, 23, 3, hat)
		_rect(art, 8, 14 + bob, 18, 1, Color("947449"))
		_rect(art, 11, 10 + bob, 12, 2, scarf)
		_rect(art, 12, 8 + bob, 7, 1, CREAM)
		if role == "healer":
			_rect(art, 15, 8 + bob, 3, 5, scarf)
			_rect(art, 14, 9 + bob, 5, 2, scarf)
	_outline(art)
	if facing == 3:
		art.flip_x()
	var texture: ImageTexture = ImageTexture.create_from_image(art)
	_textures[key] = texture
	return texture


static func ground(kind: String) -> Texture2D:
	var key: String = "ground_" + kind
	if _textures.has(key):
		return _textures[key] as Texture2D
	var art: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var base: Color = Color("527c62")
	var dark: Color = Color("466b59")
	var light: Color = Color("699069")
	match kind:
		"stone":
			base = Color("b4b79c")
			dark = Color("929e90")
			light = Color("cbd0af")
		"roof":
			base = Color("7c595d")
			dark = Color("5c4554")
			light = Color("ae7568")
		"wood":
			base = Color("aa8059")
			dark = Color("80644c")
			light = Color("c29a6c")
	art.fill(base)
	for y: int in range(64):
		for x: int in range(64):
			var noise: int = posmod(x * 157 + y * 313 + x * y * 17, 251)
			if noise < 13:
				art.set_pixel(x, y, dark)
			elif noise > 241:
				art.set_pixel(x, y, light)
	if kind == "roof":
		for row: int in range(8):
			var offset: int = (row % 2) * 8
			_rect(art, 0, row * 8 + 7, 64, 1, dark)
			for col: int in range(-1, 5):
				_rect(art, col * 16 + offset, row * 8, 1, 7, dark)
				_rect(art, col * 16 + offset + 2, row * 8 + 1, 11, 1, light)
	elif kind == "wood":
		for row: int in range(8):
			_rect(art, 0, row * 8 + 7, 64, 1, dark)
			_rect(art, 0, row * 8, 64, 1, light)
			_rect(art, (row * 19) % 64, row * 8, 1, 8, dark)
			_rect(art, (row * 13 + 5) % 51, row * 8 + 3, 11, 1, light)
	elif kind == "stone":
		for row: int in range(4):
			var offset: int = (row % 2) * 16
			_rect(art, 0, row * 16 + 15, 64, 1, dark)
			for col: int in range(-1, 3):
				_rect(art, col * 32 + offset, row * 16, 1, 16, dark)
				_rect(art, col * 32 + offset + 2, row * 16 + 1, 27, 1, light)
	else:
		for patch: int in range(12):
			var x: int = posmod(patch * 23 + 7, 60)
			var y: int = posmod(patch * 31 + 13, 60)
			_rect(art, x, y, 1, 3, light)
			_rect(art, x + 2, y - 1, 1, 4, light)
			_rect(art, x + 1, y + 3, 3, 1, dark)
	var texture: ImageTexture = ImageTexture.create_from_image(art)
	_textures[key] = texture
	return texture


static func foliage(seed_value: int = 0) -> Texture2D:
	var variant: int = posmod(seed_value, 8)
	var key: String = "foliage_%d" % variant
	if _textures.has(key):
		return _textures[key] as Texture2D
	var art: Image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var shade: Color = Color("29463e")
	var dark: Color = Color("345444")
	var moss: Color = Color("496848")
	var jade: Color = Color("5c7850")
	var olive: Color = Color("748857")
	var leaf_light: Color = Color("8d9b64")
	var offset: int = variant % 3 - 1
	# The bottom edge hangs in separate leaf skirts. No smooth spherical rim.
	_poly(art, [4, 27, 7, 24, 6, 18, 11, 16, 14, 10, 20, 10,
		23, 6, 31, 7, 36, 5, 41, 9, 47, 10, 49, 15, 55, 17,
		56, 23, 60, 27, 58, 33, 61, 39, 58, 43, 58, 49, 53, 51,
		50, 56, 44, 54, 40, 59, 33, 57, 29, 59, 24, 56, 18, 57,
		15, 53, 10, 53, 9, 48, 5, 45, 6, 39, 3, 35], shade)
	_poly(art, [7, 27, 12, 19, 17, 12, 26, 10, 35, 8, 44, 12,
		51, 18, 56, 28, 55, 38, 50, 48, 43, 53, 33, 52, 26, 54,
		16, 50, 9, 42], dark)
	# Broad clusters establish directional volume before the individual leaves.
	_poly(art, [8, 27, 12, 20, 20, 15, 27, 17, 28, 25, 22, 33, 12, 34], moss)
	_poly(art, [17, 13, 24, 9, 31, 10, 36, 16, 32, 24, 22, 25, 15, 20], jade)
	_poly(art, [32, 12, 39, 10, 47, 15, 47, 24, 39, 30, 30, 26, 28, 19], moss)
	_poly(art, [43, 24, 50, 20, 55, 27, 55, 36, 50, 43, 42, 39, 39, 31], moss)
	_poly(art, [23, 28, 31, 24, 41, 28, 44, 35, 39, 44, 29, 43, 22, 37], jade)
	_poly(art, [9, 37, 16, 32, 23, 36, 23, 44, 18, 49, 11, 46], moss)
	_poly(art, [26, 44, 33, 39, 41, 42, 44, 50, 37, 55, 28, 52], moss)
	_poly(art, [18, 14, 25, 10, 30, 12, 31, 17, 26, 20, 19, 18], olive)
	_poly(art, [25, 29, 31, 26, 37, 29, 38, 34, 32, 37, 26, 34], olive)
	_poly(art, [44, 25, 49, 23, 53, 27, 51, 31, 46, 31], jade)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 39721 + variant * 887
	# Leaf marks are compact clusters, with large quiet areas between them.
	for index: int in range(83):
		var x: int = rng.randi_range(6, 56)
		var y: int = rng.randi_range(9, 53)
		if art.get_pixel(x, y).a == 0.0 or art.get_pixel(x + 3, y + 2).a == 0.0:
			continue
		var base: Color = moss if y > 35 else jade
		var light: Color = jade if y > 35 else olive
		if index % 4 == 0:
			base = dark
			light = moss
		elif y < 24 and index % 3 == 0:
			base = olive
			light = leaf_light
		_poly(art, [x, y + 1, x + 2, y - 1, x + 5, y, x + 4, y + 3, x + 1, y + 4], base)
		_rect(art, x + 1, y, 3, 1, light)
		_rect(art, x, y + 1, 2, 1, light)
		if index % 3 == 0:
			_rect(art, x + 2, y + 4, 3, 1, shade)
	# A few sprigs break the outline without adding isolated noisy pixels.
	for twig: Vector2i in [Vector2i(10 + offset, 18), Vector2i(22, 9), Vector2i(39 - offset, 10), Vector2i(52, 25), Vector2i(15, 46), Vector2i(44 + offset, 49)]:
		_poly(art, [twig.x, twig.y, twig.x + 3, twig.y - 2, twig.x + 6, twig.y - 1, twig.x + 3, twig.y + 2], olive if twig.y < 30 else moss)
		_rect(art, twig.x + 1, twig.y - 1, 3, 1, jade if twig.y > 30 else leaf_light)
	var texture: ImageTexture = ImageTexture.create_from_image(art)
	_textures[key] = texture
	return texture


static func _cindermew(art: Image, frame: int, back: bool) -> void:
	var dark: Color = Color("ae4b52")
	var fur: Color = Color("e68b59")
	var light: Color = Color("f8be78")
	var tail: int = frame - 1
	# A curling lantern tail, with its glass body hanging below the handle.
	_poly(art, [49, 53, 59, 50, 64, 40, 65, 31, 70, 32, 71, 43, 65, 55, 54, 61], dark)
	_poly(art, [50, 54, 59, 52, 65, 42, 66, 34, 68, 35, 68, 43, 62, 53, 54, 58], fur)
	_ellipse(art, 60 + tail, 20, 12, 14, Color("a36252"))
	_ellipse(art, 63 + tail, 22, 6, 9, Color.TRANSPARENT)
	_poly(art, [61 + tail, 30, 71 + tail, 30, 74 + tail, 35, 72 + tail, 44, 63 + tail, 46, 59 + tail, 39], GOLD)
	_poly(art, [64 + tail, 32, 69 + tail, 32, 72 + tail, 37, 69 + tail, 43, 64 + tail, 42, 62 + tail, 37], Color("fff5b6"))
	_rect(art, 62 + tail, 30, 9, 2, dark)
	_rect(art, 63 + tail, 44, 9, 2, dark)
	_rect(art, 66 + tail, 35, 2, 5, Color.WHITE)
	_poly(art, [21, 43, 32, 35, 46, 37, 56, 47, 56, 60, 50, 67, 29, 67, 18, 59], dark)
	_poly(art, [22, 42, 35, 37, 47, 41, 52, 50, 49, 61, 29, 63, 20, 56], fur)
	_poly(art, [25, 43, 35, 40, 43, 44, 42, 50, 31, 52, 22, 50], light)
	_poly(art, [22, 56, 31, 58, 31, 66, 27, 70, 17, 69, 17, 66], fur)
	_poly(art, [44, 58, 52, 58, 53, 65, 58, 67, 57, 70, 44, 70, 41, 66], fur)
	_rect(art, 19, 67, 9, 2, light)
	_rect(art, 46, 67, 9, 2, light)
	# Unequal soft ears create a distinctive folded silhouette.
	_poly(art, [22, 31, 13, 17, 13, 8, 18, 6, 24, 17, 27, 30], fur)
	_poly(art, [19, 24, 16, 15, 17, 10, 20, 16, 23, 28], Color("b85c65"))
	_poly(art, [34, 28, 34, 13, 40, 8, 47, 11, 44, 17, 40, 17, 40, 29], dark)
	_poly(art, [36, 25, 36, 15, 40, 11, 44, 12, 41, 15, 38, 15, 39, 26], light)
	_poly(art, [19, 27, 28, 23, 39, 24, 46, 31, 45, 42, 37, 49, 25, 48, 17, 40, 16, 32], fur)
	_poly(art, [19, 30, 25, 26, 35, 26, 39, 29, 32, 32, 22, 33], light)
	if back:
		_poly(art, [22, 32, 29, 29, 36, 32, 39, 40, 34, 45, 25, 43], dark)
		_poly(art, [28, 34, 32, 32, 35, 36, 31, 39], fur)
	else:
		_poly(art, [20, 39, 28, 38, 31, 40, 38, 38, 42, 41, 36, 46, 27, 46], CREAM)
		_eye(art, 23, 34, frame, Color("633a4b"))
		_eye(art, 37, 33, frame, Color("633a4b"))
		_rect(art, 30, 40, 3, 2, INK)
		_rect(art, 31, 42, 1, 2, Color("a86665"))
		_rect(art, 18, 39, 4, 2, Color("efaa8b"))
		_rect(art, 40, 38, 4, 2, Color("efaa8b"))
		_poly(art, [28, 49, 35, 50, 40, 48, 38, 57, 34, 59, 29, 56], CREAM)
	_rect(art, 50, 53, 2, 4, light)


static func _brookfin(art: Image, frame: int, back: bool) -> void:
	var deep: Color = Color("317f91")
	var blue: Color = Color("57b9c2")
	var light: Color = Color("a5dfd5")
	var sway: int = frame - 1
	_poly(art, [47, 56, 61, 58, 70, 53 + sway, 75, 43 + sway, 71, 39 + sway, 64, 47 + sway, 53, 45], deep)
	_poly(art, [52, 53, 63, 54, 70, 48 + sway, 73, 43 + sway, 69, 43 + sway, 62, 50, 54, 49], blue)
	_poly(art, [44, 39, 44, 22, 50, 14, 53, 29, 59, 26, 57, 43], deep)
	_poly(art, [46, 36, 47, 24, 50, 19, 52, 33, 57, 29, 54, 40], light)
	_line(art, 49, 25, 50, 39, Color("edf0c7"))
	_poly(art, [20, 45, 30, 37, 43, 37, 54, 46, 56, 58, 49, 66, 29, 67, 17, 58], deep)
	_poly(art, [22, 43, 34, 39, 45, 41, 50, 49, 49, 60, 39, 64, 23, 61, 19, 54], blue)
	_poly(art, [22, 49, 29, 46, 39, 48, 43, 55, 38, 63, 28, 62, 24, 57], Color("e5e6bf"))
	_poly(art, [20, 58, 28, 58, 29, 66, 23, 70, 14, 69, 13, 66], deep)
	_poly(art, [43, 58, 50, 58, 51, 65, 59, 66, 58, 70, 45, 70, 40, 66], deep)
	_rect(art, 16, 67, 10, 1, light)
	_rect(art, 46, 67, 10, 1, light)
	_ellipse(art, 13, 24, 11, 12, deep)
	_ellipse(art, 16, 26, 7, 7, Color("d9cfae"))
	_ellipse(art, 39, 23, 11, 11, deep)
	_ellipse(art, 41, 26, 6, 6, light)
	_poly(art, [20, 25, 32, 23, 43, 27, 47, 37, 43, 46, 34, 50, 22, 46, 15, 39, 15, 32], blue)
	_poly(art, [20, 27, 30, 25, 38, 28, 34, 31, 23, 32, 18, 35], light)
	if back:
		_poly(art, [24, 31, 32, 28, 40, 32, 42, 40, 36, 46, 26, 42], deep)
		_poly(art, [28, 34, 34, 32, 38, 35, 35, 39, 30, 39], blue)
	else:
		_ellipse(art, 18, 37, 25, 11, CREAM)
		_eye(art, 22, 33, frame, Color("305970"))
		_eye(art, 38, 32, frame, Color("305970"))
		_rect(art, 29, 39, 5, 3, INK)
		_rect(art, 31, 42, 1, 3, deep)
		_rect(art, 17, 40, 5, 1, deep)
		_rect(art, 40, 39, 6, 1, deep)
		_rect(art, 18, 43, 4, 1, deep)
		_rect(art, 40, 42, 5, 1, deep)
	_rect(art, 20, 52, 4, 7, light)
	_poly(art, [44, 47, 50, 49, 48, 56, 44, 58, 41, 54], deep)
	_rect(art, 44, 50, 2, 4, light)


static func _mossbell(art: Image, frame: int, back: bool) -> void:
	var shadow: Color = Color("3c7567")
	var jade: Color = Color("76ad7c")
	var light: Color = Color("b7cf8e")
	var bell: int = frame - 1
	_poly(art, [51, 44, 60, 39, 67, 41, 64, 48, 56, 52], shadow)
	_poly(art, [55, 44, 64, 42, 60, 47], light)
	_poly(art, [29, 41, 43, 37, 54, 43, 58, 54, 52, 62, 31, 61, 23, 53], shadow)
	_poly(art, [29, 41, 41, 39, 51, 43, 54, 52, 46, 58, 31, 57, 26, 51], jade)
	_poly(art, [34, 42, 44, 41, 50, 44, 49, 48, 38, 49, 31, 47], light)
	_poly(art, [28, 55, 35, 56, 33, 68, 30, 71, 24, 71, 27, 66], jade)
	_poly(art, [46, 56, 52, 55, 52, 66, 56, 70, 54, 72, 47, 71], jade)
	_rect(art, 24, 69, 8, 3, shadow)
	_rect(art, 48, 69, 8, 3, shadow)
	_poly(art, [23, 34, 32, 32, 36, 42, 34, 54, 26, 54, 20, 46], jade)
	if not back:
		_poly(art, [24, 42, 29, 41, 31, 47, 29, 54, 25, 51], CREAM)
	# Branches hold two downturned bell blossoms.
	_line(art, 25, 26, 22, 13, shadow, 2)
	_line(art, 22, 15, 15, 11, shadow, 2)
	_line(art, 22, 16, 29, 9, shadow, 2)
	_line(art, 37, 26, 41, 12, shadow, 2)
	_line(art, 41, 14, 49, 11, shadow, 2)
	_line(art, 41, 15, 36, 8, shadow, 2)
	_poly(art, [13, 10, 18, 8, 20, 12, 22, 17 + bell, 12, 17 + bell], GOLD)
	_poly(art, [45, 11, 51, 10, 54, 14, 55, 20 - bell, 44, 19 - bell], GOLD)
	_rect(art, 15, 11, 2, 4, CREAM)
	_rect(art, 47, 12, 2, 5, CREAM)
	_rect(art, 16, 18 + bell, 2, 2, Color("d89368"))
	_rect(art, 49, 20 - bell, 2, 2, Color("d89368"))
	_poly(art, [22, 29, 11, 24, 9, 28, 16, 36, 24, 35], jade)
	_poly(art, [21, 30, 12, 27, 18, 33], Color("d9c591"))
	_poly(art, [36, 29, 47, 24, 51, 27, 45, 35, 38, 36], jade)
	_poly(art, [40, 30, 47, 27, 44, 32], Color("d9c591"))
	_poly(art, [23, 25, 35, 24, 42, 30, 41, 40, 34, 47, 25, 46, 19, 39, 19, 31], jade)
	_poly(art, [24, 26, 33, 26, 36, 30, 31, 34, 23, 32], light)
	if back:
		_poly(art, [26, 31, 33, 29, 38, 34, 36, 41, 30, 44, 24, 39], shadow)
	else:
		_poly(art, [25, 37, 31, 35, 37, 38, 35, 44, 27, 44], CREAM)
		_eye(art, 22, 33, frame, shadow)
		_eye(art, 36, 32, frame, shadow)
		_rect(art, 29, 39, 4, 2, shadow)
		_rect(art, 30, 41, 1, 2, Color("b4856c"))
	for spot: Vector2i in [Vector2i(38, 45), Vector2i(46, 49), Vector2i(34, 51), Vector2i(43, 54)]:
		_rect(art, spot.x, spot.y, 3, 2, CREAM)


static func _wispip(art: Image, frame: int, back: bool) -> void:
	var shadow: Color = Color("b88f7d")
	var wing: Color = Color("eed9a1")
	var light: Color = Color("fff4d4")
	var lift: int = -3 if frame == 1 else (2 if frame == 2 else 0)
	# Four petal wings, each with a broad illuminated edge and an amber window.
	_poly(art, [37, 38, 27, 20 + lift, 13, 17 + lift, 7, 25 + lift, 10, 40, 25, 48, 37, 47], shadow)
	_poly(art, [35, 38, 25, 22 + lift, 14, 20 + lift, 10, 27 + lift, 13, 38, 25, 44, 35, 44], light)
	_poly(art, [29, 38, 24, 27 + lift, 15, 24 + lift, 13, 29 + lift, 18, 37, 27, 41], wing)
	_poly(art, [42, 38, 52, 20 + lift, 66, 17 + lift, 73, 25 + lift, 69, 40, 54, 48, 42, 47], shadow)
	_poly(art, [44, 38, 54, 22 + lift, 65, 20 + lift, 69, 27 + lift, 66, 38, 54, 44, 44, 44], light)
	_poly(art, [50, 38, 55, 27 + lift, 64, 24 + lift, 66, 29 + lift, 61, 37, 52, 41], wing)
	_poly(art, [36, 44, 22, 45, 15, 55 - lift, 19, 64 - lift, 29, 66 - lift, 37, 55], shadow)
	_poly(art, [35, 46, 24, 47, 19, 55 - lift, 22, 61 - lift, 28, 63 - lift, 35, 54], wing)
	_poly(art, [43, 44, 57, 45, 64, 55 - lift, 60, 64 - lift, 50, 66 - lift, 42, 55], shadow)
	_poly(art, [44, 46, 55, 47, 60, 55 - lift, 57, 61 - lift, 51, 63 - lift, 44, 54], wing)
	_ellipse(art, 18, 29 + lift, 8, 8, Color("dca76d"))
	_ellipse(art, 21, 30 + lift, 3, 4, light)
	_ellipse(art, 54, 29 + lift, 8, 8, Color("dca76d"))
	_ellipse(art, 56, 30 + lift, 3, 4, light)
	_line(art, 34, 30, 29, 17, shadow)
	_line(art, 45, 30, 50, 17, shadow)
	_rect(art, 27, 14, 4, 4, GOLD)
	_rect(art, 48, 14, 4, 4, GOLD)
	_poly(art, [35, 39, 44, 39, 47, 49, 44, 59, 39, 65, 35, 59, 32, 49], shadow)
	_poly(art, [35, 42, 42, 41, 44, 50, 42, 58, 39, 61, 36, 56, 34, 49], GOLD)
	_rect(art, 35, 49, 9, 2, light)
	_rect(art, 36, 56, 6, 2, light)
	_poly(art, [32, 29, 36, 25, 43, 25, 48, 30, 47, 39, 42, 44, 35, 43, 30, 37], light)
	_poly(art, [32, 39, 35, 43, 40, 44, 46, 40, 44, 47, 39, 49, 35, 47], wing)
	if back:
		_rect(art, 36, 30, 6, 7, GOLD)
	else:
		_eye(art, 33, 33, frame, shadow)
		_eye(art, 43, 33, frame, shadow)
		_rect(art, 38, 39, 3, 1, shadow)


static func _pebblit(art: Image, frame: int, back: bool) -> void:
	var slate: Color = Color("7c8f9d")
	var shadow: Color = Color("485d73")
	var light: Color = Color("adbac0")
	var skin: Color = Color("d49b9b")
	var sway: int = frame - 1
	_poly(art, [51, 56, 64, 56, 72, 51 + sway, 72, 56 + sway, 65, 61, 55, 63], shadow)
	_poly(art, [54, 57, 64, 58, 69, 55 + sway, 64, 60, 55, 60], slate)
	_poly(art, [19, 52, 22, 38, 31, 27, 46, 25, 58, 32, 65, 45, 62, 59, 51, 66, 29, 65], shadow)
	_poly(art, [22, 49, 25, 38, 33, 29, 45, 28, 55, 34, 61, 45, 58, 57, 48, 62, 30, 61], slate)
	_poly(art, [26, 39, 34, 31, 45, 30, 53, 34, 51, 40, 41, 42, 31, 42], light)
	# Large segmented plates are hand positioned, rather than random noise.
	_line(art, 31, 34, 27, 54, shadow, 2)
	_line(art, 42, 29, 38, 58, shadow, 2)
	_line(art, 53, 34, 49, 60, shadow, 2)
	_line(art, 25, 46, 59, 47, shadow)
	_line(art, 24, 52, 57, 54, shadow)
	_rect(art, 30, 38, 2, 7, Color("d2d5cb"))
	_rect(art, 41, 33, 2, 9, Color("d2d5cb"))
	_rect(art, 51, 38, 2, 6, Color("d2d5cb"))
	_poly(art, [23, 57, 31, 58, 31, 66, 26, 70, 17, 69, 17, 66], skin)
	_poly(art, [50, 59, 58, 58, 58, 66, 64, 68, 62, 71, 50, 70, 48, 66], skin)
	_rect(art, 19, 68, 2, 2, CREAM)
	_rect(art, 23, 68, 2, 2, CREAM)
	_rect(art, 54, 69, 2, 2, CREAM)
	_rect(art, 58, 69, 2, 2, CREAM)
	_poly(art, [14, 44, 11, 33, 13, 27, 18, 30, 21, 41], shadow)
	_poly(art, [14, 34, 14, 30, 17, 33, 18, 39], skin)
	_poly(art, [24, 42, 25, 30, 29, 27, 33, 31, 31, 44], shadow)
	_poly(art, [27, 40, 27, 32, 29, 31, 30, 35], skin)
	_poly(art, [13, 42, 25, 39, 33, 45, 35, 54, 30, 61, 19, 63, 10, 58, 8, 52], slate)
	_poly(art, [12, 45, 22, 42, 28, 46, 23, 49, 14, 48], light)
	if back:
		_poly(art, [15, 50, 23, 46, 30, 50, 27, 57, 18, 59], shadow)
	else:
		_poly(art, [10, 54, 18, 51, 27, 53, 30, 58, 23, 61, 15, 60], skin)
		_eye(art, 12, 49, frame, shadow)
		_eye(art, 25, 48, frame, shadow)
		_rect(art, 14, 55, 5, 3, INK)
		_rect(art, 22, 57, 4, 1, Color("9b657f"))


static func _reedrill(art: Image, frame: int, back: bool) -> void:
	var shadow: Color = Color("2b6970")
	var teal: Color = Color("56a499")
	var pale: Color = Color("b6d4ac")
	var lime: Color = Color("d0d886")
	var sway: int = frame - 1
	_poly(art, [48, 47, 60, 42 + sway, 72, 38 + sway, 67, 49, 57, 54], shadow)
	_poly(art, [52, 48, 61, 45 + sway, 68, 42 + sway, 62, 49], teal)
	_line(art, 37, 55, 34, 68, Color("bbaa6e"), 2)
	_line(art, 49, 56, 51, 67, Color("bbaa6e"), 2)
	_line(art, 34, 68, 27, 71, GOLD)
	_line(art, 34, 68, 39, 71, GOLD)
	_line(art, 51, 67, 45, 70, GOLD)
	_line(art, 51, 67, 57, 70, GOLD)
	_poly(art, [29, 38, 43, 35, 55, 40, 60, 48, 54, 57, 40, 60, 30, 53, 26, 45], shadow)
	_poly(art, [30, 39, 41, 37, 52, 41, 55, 47, 48, 55, 38, 55, 30, 49], teal)
	_poly(art, [38, 41, 48, 41, 54, 46, 48, 52, 39, 53, 35, 48], pale)
	_poly(art, [40, 44, 48, 43, 51, 46, 46, 49, 40, 50], lime)
	_line(art, 40, 49, 48, 46, shadow)
	_poly(art, [27, 24, 36, 25, 34, 36, 39, 43, 37, 49, 30, 46, 24, 37], teal)
	_poly(art, [26, 29, 30, 28, 29, 37, 33, 43, 32, 46, 27, 42, 24, 37], pale)
	_poly(art, [25, 24, 25, 15, 20, 7, 26, 10, 30, 17, 32, 7, 35, 4, 36, 17, 42, 11, 40, 21, 34, 28], lime)
	_poly(art, [23, 21, 32, 19, 39, 23, 40, 30, 35, 35, 25, 34, 20, 29], teal)
	_poly(art, [23, 23, 30, 21, 35, 23, 30, 26, 23, 26], pale)
	if back:
		_poly(art, [25, 26, 32, 23, 37, 27, 34, 32, 27, 32], shadow)
	else:
		_poly(art, [23, 29, 11, 29, 5, 33, 19, 35, 27, 33], GOLD)
		_line(art, 7, 33, 23, 32, Color("b59763"))
		_eye(art, 25, 26, frame, shadow)
		_rect(art, 32, 30, 3, 2, pale)


static func _voltkite(art: Image, frame: int, back: bool) -> void:
	var shadow: Color = Color("544873")
	var violet: Color = Color("9180bc")
	var light: Color = Color("b7a5d4")
	var lift: int = -3 if frame == 1 else (2 if frame == 2 else 0)
	_line(art, 40, 49, 42, 60, shadow, 3)
	_line(art, 42, 60, 50, 64, shadow, 3)
	_line(art, 50, 64, 46, 72, shadow, 2)
	_line(art, 41, 51, 43, 59, GOLD)
	_line(art, 43, 59, 51, 63, GOLD)
	_line(art, 51, 63, 47, 70, GOLD)
	_poly(art, [36, 29, 25, 26, 12, 21 + lift, 4, 24 + lift, 10, 40, 24, 50, 39, 55, 53, 50, 68, 40, 75, 24 + lift, 66, 21 + lift, 53, 26, 43, 29], shadow)
	_poly(art, [35, 31, 24, 29, 12, 25 + lift, 8, 26 + lift, 13, 38, 26, 46, 40, 51, 53, 46, 66, 38, 71, 26 + lift, 65, 25 + lift, 54, 29, 44, 31], violet)
	_poly(art, [35, 31, 26, 31, 15, 28 + lift, 18, 35, 30, 40, 38, 40], light)
	_poly(art, [43, 31, 53, 31, 64, 28 + lift, 60, 35, 49, 40, 41, 40], light)
	_poly(art, [13, 28 + lift, 25, 34, 23, 38, 34, 43, 29, 44, 17, 39, 20, 35], GOLD)
	_poly(art, [66, 28 + lift, 54, 34, 56, 38, 45, 43, 50, 44, 62, 39, 59, 35], GOLD)
	_poly(art, [33, 25, 38, 22, 44, 24, 49, 35, 46, 46, 40, 52, 33, 47, 29, 36], violet)
	_poly(art, [34, 27, 38, 25, 42, 27, 45, 34, 42, 39, 34, 37, 32, 33], light)
	_poly(art, [34, 27, 29, 20, 31, 16, 36, 23], shadow)
	_poly(art, [44, 26, 49, 20, 48, 16, 42, 22], shadow)
	_rect(art, 30, 16, 2, 3, GOLD)
	_rect(art, 47, 16, 2, 3, GOLD)
	if back:
		_poly(art, [38, 30, 43, 34, 40, 41, 35, 37], GOLD)
	else:
		_eye(art, 32, 33, frame, shadow)
		_eye(art, 43, 33, frame, shadow)
		_rect(art, 37, 39, 4, 1, shadow)
		_rect(art, 31, 39, 3, 2, Color("dba4bd"))
		_rect(art, 44, 39, 3, 2, Color("dba4bd"))
	_poly(art, [36, 44, 40, 42, 43, 45, 40, 49], Color("e5d9db"))


static func _noctulume(art: Image, frame: int, back: bool) -> void:
	var shadow: Color = Color("383957")
	var indigo: Color = Color("626990")
	var light: Color = Color("929bb8")
	var glow: Color = Color("a1e0dd")
	var wing: int = 1 if frame == 1 else (-1 if frame == 2 else 0)
	_poly(art, [31, 53, 29, 66, 35, 69, 39, 66, 44, 70, 50, 66, 47, 54], shadow)
	_poly(art, [25, 36, 39, 31, 54, 37, 59, 50, 54, 64, 41, 68, 27, 63, 21, 50], shadow)
	_poly(art, [27, 36, 40, 34, 51, 39, 55, 49, 50, 60, 39, 64, 29, 59, 25, 48], indigo)
	_poly(art, [31, 43, 39, 39, 49, 44, 50, 55, 42, 61, 32, 57], light)
	_poly(art, [26, 39, 19 - wing, 43, 17 - wing, 56, 23, 61, 31, 54, 32, 46], indigo)
	_poly(art, [52, 39, 59 + wing, 43, 62 + wing, 56, 56, 61, 48, 54, 47, 46], indigo)
	_line(art, 21 - wing, 46, 24, 55, light)
	_line(art, 56 + wing, 45, 55, 54, light)
	_rect(art, 28, 66, 10, 3, GOLD)
	_rect(art, 44, 66, 10, 3, GOLD)
	_rect(art, 30, 69, 2, 2, GOLD)
	_rect(art, 35, 69, 2, 2, GOLD)
	_rect(art, 46, 69, 2, 2, GOLD)
	_rect(art, 51, 69, 2, 2, GOLD)
	# Rounded feathery hood and long lantern-shaped brow plumes.
	_poly(art, [24, 28, 18, 18, 18, 11, 24, 14, 30, 23, 38, 22, 47, 23, 54, 13, 60, 10, 59, 20, 54, 29], shadow)
	_poly(art, [23, 25, 21, 17, 23, 17, 29, 25], glow)
	_poly(art, [50, 25, 56, 16, 57, 14, 56, 22, 53, 27], glow)
	_poly(art, [25, 23, 39, 19, 53, 23, 60, 32, 59, 43, 51, 51, 38, 54, 24, 49, 18, 40, 19, 31], indigo)
	_poly(art, [25, 24, 38, 21, 49, 24, 45, 28, 31, 29, 23, 33], light)
	if back:
		_poly(art, [27, 31, 39, 27, 52, 33, 52, 43, 40, 49, 28, 44], shadow)
		_poly(art, [34, 31, 39, 29, 45, 32, 42, 35, 37, 35], glow)
		_line(art, 30, 38, 35, 41, indigo)
		_line(art, 44, 41, 49, 38, indigo)
	else:
		_poly(art, [23, 31, 30, 28, 38, 33, 42, 32, 48, 28, 55, 31, 56, 40, 49, 47, 41, 46, 39, 44, 34, 47, 26, 44, 22, 39], Color("dce9d2"))
		_ellipse(art, 25, 32, 11, 11, shadow)
		_ellipse(art, 44, 32, 11, 11, shadow)
		if frame == 2:
			_rect(art, 27, 37, 7, 2, glow)
			_rect(art, 46, 37, 7, 2, glow)
		else:
			_ellipse(art, 27, 33, 7, 8, glow)
			_ellipse(art, 46, 33, 7, 8, glow)
			_rect(art, 29, 35, 3, 5, INK)
			_rect(art, 48, 35, 3, 5, INK)
			_rect(art, 28, 34, 2, 2, Color.WHITE)
			_rect(art, 47, 34, 2, 2, Color.WHITE)
		_poly(art, [37, 39, 42, 39, 40, 45], GOLD)
	for feather: Vector2i in [Vector2i(34, 49), Vector2i(43, 49), Vector2i(38, 55)]:
		_poly(art, [feather.x, feather.y, feather.x + 3, feather.y + 2, feather.x + 6, feather.y, feather.x + 3, feather.y + 5], glow)


static func _eye(art: Image, x: int, y: int, frame: int, iris: Color) -> void:
	if frame == 2:
		_rect(art, x, y + 2, 4, 1, INK)
		return
	_rect(art, x, y, 4, 5, INK)
	_rect(art, x + 1, y + 3, 2, 2, iris)
	_rect(art, x, y, 2, 2, CREAM)


static func _rect(art: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var clipped: Rect2i = Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, art.get_size()))
	if clipped.has_area():
		art.fill_rect(clipped, color)


static func _ellipse(art: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var center: Vector2 = Vector2(x + w * 0.5, y + h * 0.5)
	for py: int in range(maxi(y, 0), mini(y + h, art.get_height())):
		for px: int in range(maxi(x, 0), mini(x + w, art.get_width())):
			var delta: Vector2 = (Vector2(px + 0.5, py + 0.5) - center) / Vector2(w * 0.5, h * 0.5)
			if delta.length_squared() <= 1.0:
				art.set_pixel(px, py, color)


static func _poly(art: Image, coordinates: Array, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var min_x: int = art.get_width()
	var max_x: int = 0
	var min_y: int = art.get_height()
	var max_y: int = 0
	for index: int in range(0, coordinates.size(), 2):
		var point: Vector2 = Vector2(float(coordinates[index]), float(coordinates[index + 1]))
		points.append(point)
		min_x = mini(min_x, int(point.x))
		max_x = maxi(max_x, int(point.x))
		min_y = mini(min_y, int(point.y))
		max_y = maxi(max_y, int(point.y))
	for y: int in range(maxi(min_y, 0), mini(max_y + 1, art.get_height())):
		for x: int in range(maxi(min_x, 0), mini(max_x + 1, art.get_width())):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				art.set_pixel(x, y, color)


static func _line(art: Image, x0: int, y0: int, x1: int, y1: int, color: Color, thickness: int = 1) -> void:
	var start: Vector2 = Vector2(x0, y0)
	var finish: Vector2 = Vector2(x1, y1)
	var steps: int = maxi(absi(x1 - x0), absi(y1 - y0))
	for step: int in range(steps + 1):
		var position: Vector2 = start.lerp(finish, float(step) / float(maxi(steps, 1)))
		_rect(art, roundi(position.x), roundi(position.y), thickness, thickness, color)


static func _outline(art: Image) -> void:
	var original: Image = art.duplicate() as Image
	for y: int in range(art.get_height()):
		for x: int in range(art.get_width()):
			if original.get_pixel(x, y).a > 0.0:
				continue
			for neighbor: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var point: Vector2i = Vector2i(x, y) + neighbor
				if point.x >= 0 and point.y >= 0 and point.x < art.get_width() and point.y < art.get_height() and original.get_pixelv(point).a > 0.0:
					art.set_pixel(x, y, INK)
					break
