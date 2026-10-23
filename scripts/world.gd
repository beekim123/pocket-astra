class_name LanternWorld
extends Node3D
## A miniature archipelago, built exclusively from meshes and code-painted pixels.

const Art = preload("res://scripts/art.gd")
var camera: Camera3D
var player: Sprite3D
var companion: Sprite3D
var player_position := Vector3(-7, 0, 5)
var direction: int = 0
var moving: bool = false
var in_battle: bool = false
var companion_id: int = -1
var clock: float = 0.0
var obstacles: Array[Rect2] = []
var npcs: Array[Dictionary] = []
var lamps: Array[OmniLight3D] = []
var motes: Array[MeshInstance3D] = []
var foliage: Array[Sprite3D] = []
var battle_player: Sprite3D
var battle_enemy: Sprite3D
var battle_ids := Vector2i(0, 3)
var battle_pulse: float = 0.0
var stage: Node3D
var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _last_frame: int = -1
var _last_art_key: String = ""
var _camera_target := Vector3(-6, 0, 2)

func _ready() -> void:
	_rng.seed = 78021
	_build_environment()
	_build_island()
	_build_village()
	_build_meadow()
	_build_stage()
	player = _person("player", player_position)
	companion = _sprite(Art.creature(0), player_position + Vector3(0.8, 0.55, 0.6), 0.017)
	companion.visible = false
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.6
	camera.far = 160.0
	camera.near = 0.1
	add_child(camera)
	camera.current = true
	camera.position = _camera_target + Vector3(0, 17, 20)
	camera.look_at(_camera_target)

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("76959d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("afc9d8")
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("97adb0")
	env.fog_light_energy = 0.7
	env.fog_density = 0.004
	var environment := WorldEnvironment.new()
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("ffe1a6")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65.0
	sun.shadow_bias = 0.05
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 150, 0)
	fill.light_color = Color("82afcc")
	fill.light_energy = 0.13
	add_child(fill)

func _mat(color: Color, texture_kind: String = "", emission: float = 0.0) -> StandardMaterial3D:
	var key := str(color) + texture_kind + str(emission)
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	if texture_kind != "":
		mat.albedo_texture = Art.ground(texture_kind)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.65, 0.65, 0.65)
	if emission > 0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	_materials[key] = mat
	return mat

func _box(pos: Vector3, size: Vector3, color: Color, texture_kind: String = "", parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _mat(color, texture_kind)
	node.position = pos
	parent.add_child(node)
	return node

func _cylinder(pos: Vector3, radius: float, height: float, color: Color, vertices: int = 10, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.05
	mesh.height = height
	mesh.radial_segments = vertices
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _sphere(pos: Vector3, radius: float, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.7
	mesh.radial_segments = 10
	mesh.rings = 5
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.material_override = _mat(color)
	parent.add_child(node)
	return node

func _build_island() -> void:
	var ocean := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(180, 160)
	plane.subdivide_width = 32
	plane.subdivide_depth = 32
	ocean.mesh = plane
	ocean.position = Vector3(0, -0.65, 25)
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/water.gdshader")
	ocean.material_override = water
	add_child(ocean)
	# Layered cutaway river banks emphasize the tabletop scale.
	for side in [-1, 1]:
		var x: float = side * 8.4
		_box(Vector3(x, -1.6, 0), Vector3(13.5, 3, 23), Color("4b6361"), "stone")
		_box(Vector3(x, -0.55, 0), Vector3(13.4, 1.0, 22.9), Color("9b8d65"), "stone")
		_box(Vector3(x, -0.08, 0), Vector3(13.4, 0.25, 22.8), Color("768b4d"), "grass")
		for i in range(24):
			var z: float = -11.0 + i * 0.94
			var rock := _box(Vector3(side * _rng.randf_range(1.5, 1.9), -0.55, z), Vector3(_rng.randf_range(0.4, 0.85), 0.9, 0.86), Color("798780"), "stone")
			rock.rotation.y = _rng.randf_range(-0.2, 0.2)
	# Broad cobblestone paths; small variations form hand-laid paving.
	_path(Rect2(-13.6, 3.1, 27.0, 2.0))
	_path(Rect2(-8.0, -7.5, 2.0, 12.6))
	_path(Rect2(7.9, -7.8, 2.2, 12.8))
	for i in range(15):
		_box(Vector3(-1.8 + i * 0.26, 0.1, 4.1), Vector3(0.235, 0.2, 2.15), Color("c79d65"), "wood")
	for z in [2.95, 5.25]:
		for x in [-1.8, -0.6, 0.6, 1.8]:
			_box(Vector3(x, 0.5, z), Vector3(0.13, 1.0, 0.13), Color("705845"))
		_box(Vector3(0, 0.85, z), Vector3(4, 0.13, 0.13), Color("b88d5b"))
	# Far islands create atmospheric parallax beyond the playable diorama.
	for i in range(8):
		var pos := Vector3(-32 + i * 10.0, -0.8, -28 - _rng.randf_range(0, 10))
		_cylinder(pos, _rng.randf_range(3, 5), 1.0, Color("688e86"), 9)
		for j in range(4):
			_tree(pos + Vector3(_rng.randf_range(-2, 2), 0.4, _rng.randf_range(-2, 2)), 1.0, false)

func _path(rect: Rect2) -> void:
	_box(Vector3(rect.get_center().x, 0.045, rect.get_center().y), Vector3(rect.size.x, 0.05, rect.size.y), Color("c0b18a"), "stone")
	var nx := int(rect.size.x / 0.65)
	var nz := int(rect.size.y / 0.62)
	for x in range(nx):
		for z in range(nz):
			var px: float = rect.position.x + 0.35 + x * 0.65
			if absf(px) < 1.85:
				continue
			var tile := _box(Vector3(px, 0.078, rect.position.y + 0.35 + z * 0.62), Vector3(0.58, 0.035, 0.54), Color("d7c8a4").darkened(_rng.randf_range(0, 0.15)))
			tile.rotation.y = _rng.randf_range(-0.06, 0.06)

func _build_village() -> void:
	_house(Vector3(-11, 0, -1.2), Vector3(3.5, 2.3, 3.2), Color("9e5d48"), false)
	_house(Vector3(-4.4, 0, -3.4), Vector3(3.8, 2.7, 3.3), Color("547f82"), true)
	_house(Vector3(-11.6, 0, -7.2), Vector3(3.0, 2.0, 2.8), Color("a97a46"), false)
	# Small shop awning, striped in mesh strips rather than an image.
	for i in range(8):
		var awning := _box(Vector3(-12.5 + i * 0.4, 1.8, 0.95), Vector3(0.4, 0.08, 1.05), Color("edcf91") if i % 2 == 0 else Color("567c73"))
		awning.rotation.x = -0.14
	for p in [Vector3(-13, 0, 1), Vector3(-9.5, 0, 1), Vector3(-3, 0, -1)]:
		_box(p + Vector3(0, 0.35, 0), Vector3(0.65, 0.7, 0.65), Color("9c734e"), "wood")
		for j in range(3):
			_sphere(p + Vector3(j * 0.16 - 0.16, 0.8, 0), 0.13, Color("cb8a55"))
	for p in [Vector3(-14, 0, 7.8), Vector3(-12.6, 0, 9.5), Vector3(-4, 0, 8.8), Vector3(-3, 0, 10.1), Vector3(-3, 0, -9.5), Vector3(-8.6, 0, -10), Vector3(-14, 0, -4.8)]:
		_tree(p, _rng.randf_range(0.9, 1.25))
	_lamp(Vector3(-8.2, 0, 3.0))
	_lamp(Vector3(-2.4, 0, 2.7))
	_lamp(Vector3(2.5, 0, 2.7))
	_lamp(Vector3(-7.9, 0, -5.8))
	add_npc("mentor", "EDDA / THE LANTERN KEEPER", Vector3(-6, 0, 1.1))
	add_npc("healer", "MIRA / REST & SUPPLIES", Vector3(-11.4, 0, 3.3))
	# Garden beds and a small fountain courtyard.
	_cylinder(Vector3(-4.4, 0.2, 1), 0.85, 0.35, Color("9caaa1"), 14)
	_cylinder(Vector3(-4.4, 0.4, 1), 0.65, 0.12, Color("83bbb3"), 14)
	_cylinder(Vector3(-4.4, 0.8, 1), 0.16, 0.8, Color("c5c4a7"), 8)
	obstacles.append(Rect2(-5.2, 0.2, 1.6, 1.6))
	for z in [6.3, 7.2]:
		_box(Vector3(-10, 0.12, z), Vector3(4, 0.2, 0.5), Color("685a41"))
		for i in range(13):
			_flower(Vector3(-11.8 + i * 0.3, 0.24, z), Color("ffd995") if i % 2 == 0 else Color("dba1a3"))
	# Cloth lines with warm floating pennants.
	_box(Vector3(-7, 3.1, -0.9), Vector3(7.5, 0.025, 0.025), Color("5b594b"))
	for i in range(9):
		_box(Vector3(-10.5 + i * 0.84, 2.95, -0.9), Vector3(0.28, 0.36, 0.025), Color("d5ad68") if i % 2 == 0 else Color("6baba8"))

func _house(pos: Vector3, size: Vector3, roof_color: Color, tower: bool) -> void:
	_box(pos + Vector3(0, 0.16, 0), Vector3(size.x + 0.3, 0.32, size.z + 0.3), Color("899089"), "stone")
	_box(pos + Vector3(0, size.y / 2, 0), size, Color("e1ce9e"), "stone")
	for x in [-size.x / 2 + 0.12, size.x / 2 - 0.12]:
		_box(pos + Vector3(x, size.y / 2, size.z / 2 + 0.02), Vector3(0.16, size.y, 0.12), Color("655d4d"))
	for y in [0.45, size.y - 0.2]:
		_box(pos + Vector3(0, y, size.z / 2 + 0.05), Vector3(size.x, 0.14, 0.1), Color("87745a"))
	# Each half roof is a thick sloped sheet with visible eaves and tile rows.
	for side in [-1, 1]:
		var roof := _box(pos + Vector3(side * size.x * 0.25, size.y + 0.45, 0), Vector3(size.x * 0.64, 0.15, size.z + 0.65), roof_color, "roof")
		roof.rotation.z = -side * 0.48
		for row in range(6):
			var xpos: float = side * (0.15 + row * size.x * 0.095)
			_box(pos + Vector3(xpos, size.y + 0.94 - absf(xpos) * 0.52, 0), Vector3(0.065, 0.07, size.z + 0.68), roof_color.lightened(0.12))
	_box(pos + Vector3(0, size.y + 0.96, 0), Vector3(0.18, 0.18, size.z + 0.75), roof_color.lightened(0.2))
	_box(pos + Vector3(-0.7, size.y + 0.9, -0.6), Vector3(0.45, 1.3, 0.5), Color("a99e86"), "stone")
	_box(pos + Vector3(0, 0.68, size.z / 2 + 0.06), Vector3(0.72, 1.35, 0.12), Color("4f6563"), "wood")
	for x in [-1.05, 1.05]:
		_box(pos + Vector3(x, 1.25, size.z / 2 + 0.08), Vector3(0.66, 0.78, 0.15), Color("5e6557"))
		var window := _box(pos + Vector3(x, 1.25, size.z / 2 + 0.17), Vector3(0.48, 0.59, 0.02), Color("ffd690"))
		window.material_override = _mat(Color("ffd690"), "", 0.7)
		_box(pos + Vector3(x, 1.25, size.z / 2 + 0.2), Vector3(0.045, 0.62, 0.03), Color("787056"))
		_box(pos + Vector3(x, 1.25, size.z / 2 + 0.2), Vector3(0.5, 0.045, 0.03), Color("787056"))
	if tower:
		_lamp(pos + Vector3(1.5, 0, size.z / 2 + 0.6))
	obstacles.append(Rect2(pos.x - size.x / 2 - 0.15, pos.z - size.z / 2 - 0.15, size.x + 0.3, size.z + 0.3))

func _build_meadow() -> void:
	for p in [Vector3(3.3, 0, 8.9), Vector3(5.2, 0, 10), Vector3(11, 0, 9.4), Vector3(13.7, 0, 6.4), Vector3(14, 0, 0), Vector3(12.5, 0, -2.2), Vector3(4.5, 0, -4.8), Vector3(3.1, 0, -8.5), Vector3(13.6, 0, -9.0)]:
		_tree(p, _rng.randf_range(0.95, 1.35))
	# Hand-composed reeds: stepped pixel planes, batched into a single mesh.
	var grass := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(560):
		var p := Vector3(_rng.randf_range(3.6, 13.5), 0.09, _rng.randf_range(-1.8, 8.5))
		if absf(p.z - 4.1) < 1.2 or absf(p.x - 9.0) < 1.3:
			continue
		var h := _rng.randf_range(0.17, 0.48)
		var c := Color("b4c47a").darkened(_rng.randf_range(0, 0.3))
		for offset in [-0.08, 0.08]:
			grass.set_color(c)
			grass.add_vertex(p + Vector3(offset - 0.06, 0, 0))
			grass.add_vertex(p + Vector3(offset + 0.06, h, 0))
			grass.add_vertex(p + Vector3(offset + 0.10, 0, 0))
	grass.generate_normals()
	var grass_node := MeshInstance3D.new()
	grass_node.mesh = grass.commit()
	var grass_mat := StandardMaterial3D.new()
	grass_mat.vertex_color_use_as_albedo = true
	grass_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_node.material_override = grass_mat
	add_child(grass_node)
	for i in range(55):
		var p := Vector3(_rng.randf_range(3.0, 13.4), 0.0, _rng.randf_range(-1.6, 9))
		if absf(p.z - 4.1) > 1.3 and absf(p.x - 9.0) > 1.2:
			_flower(p, Color("f2d39a") if i % 3 else Color("c8c0d9"))
	# Lighthouse gym on an old circular stone foundation.
	_cylinder(Vector3(9, 0.15, -7), 3.0, 0.3, Color("859c91"), 18)
	_cylinder(Vector3(9, 0.36, -8.2), 1.7, 0.5, Color("b6b69b"), 12)
	_cylinder(Vector3(9, 2.0, -8.2), 1.25, 3.6, Color("d6d3ae"), 12)
	for y in [0.65, 2.5, 3.55]:
		_cylinder(Vector3(9, y, -8.2), 1.32, 0.18, Color("7c9991"), 12)
	_cylinder(Vector3(9, 4.0, -8.2), 1.6, 0.22, Color("667a71"), 12)
	for i in range(8):
		var angle: float = i * TAU / 8
		_box(Vector3(9 + cos(angle) * 1.1, 4.6, -8.2 + sin(angle) * 1.1), Vector3(0.1, 1.2, 0.1), Color("51676c"))
	var glow := _sphere(Vector3(9, 4.7, -8.2), 0.6, Color("ffdfa0"))
	glow.material_override = _mat(Color("ffcf78"), "", 1.8)
	_cylinder(Vector3(9, 5.25, -8.2), 1.6, 0.25, Color("577d7c"), 10)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.08
	roof.bottom_radius = 1.7
	roof.height = 1.1
	roof.radial_segments = 10
	var roof_node := MeshInstance3D.new()
	roof_node.mesh = roof
	roof_node.material_override = _mat(Color("47706e"), "roof")
	roof_node.position = Vector3(9, 5.85, -8.2)
	add_child(roof_node)
	_box(Vector3(9, 0.9, -6.92), Vector3(0.7, 1.6, 0.08), Color("465e60"))
	obstacles.append(Rect2(7.6, -9.6, 2.8, 2.8))
	_lamp(Vector3(6.6, 0, -5.6))
	_lamp(Vector3(11.4, 0, -5.6))
	add_npc("rival", "IVO / BRIDGE CHALLENGER", Vector3(3.3, 0, 3.4))
	add_npc("keeper", "SOREN / FIRST LIGHT GYM", Vector3(9, 0, -5.8))
	# A sign and a cache are genuine world interactions.
	_box(Vector3(5.2, 0.55, 5.8), Vector3(0.13, 1.1, 0.13), Color("796647"))
	_box(Vector3(5.2, 1.0, 5.8), Vector3(0.85, 0.45, 0.12), Color("bd9c64"))
	npcs.append({"role":"sign", "name":"CANDLE REED / FIELD NOTES", "pos":Vector3(5.2, 0, 5.8)})
	_box(Vector3(-3.2, 0.3, -6.8), Vector3(0.6, 0.6, 0.6), Color("b58c4f"), "wood")
	_box(Vector3(-3.2, 0.32, -6.47), Vector3(0.1, 0.18, 0.05), Color("ebd397"))
	npcs.append({"role":"cache", "name":"A TRAVELLER'S CACHE", "pos":Vector3(-3.2, 0, -6.8)})
	for i in range(24):
		var mote := _sphere(Vector3(_rng.randf_range(-13, 13), _rng.randf_range(0.5, 3.8), _rng.randf_range(-8, 9)), 0.025, Color("ffdf9e"))
		mote.material_override = _mat(Color("ffdb8e"), "", 1.2)
		motes.append(mote)

func _tree(pos: Vector3, scale_value: float = 1.0, collide: bool = true) -> void:
	_cylinder(pos + Vector3(0, 0.9, 0) * scale_value, 0.17 * scale_value, 1.8 * scale_value, Color("6d604a"), 7)
	# Depth-separated pixel leaf planes preserve the 2D/3D material contrast.
	for j in range(6):
		var a: float = j * 2.4
		var p: Vector3 = pos + Vector3(cos(a) * 0.63, 2.0 + float(j % 3) * 0.45, sin(a) * 0.55) * scale_value
		var leaves := _sprite(Art.foliage(j + int(absf(pos.x))), p, 0.038 * scale_value)
		foliage.append(leaves)
	if collide:
		obstacles.append(Rect2(pos.x - 0.45, pos.z - 0.42, 0.9, 0.84))

func _flower(pos: Vector3, color: Color) -> void:
	_box(pos + Vector3(0, 0.14, 0), Vector3(0.035, 0.28, 0.035), Color("4d7958"))
	_box(pos + Vector3(0, 0.29, 0), Vector3(0.16, 0.08, 0.10), color)
	_box(pos + Vector3(0, 0.30, 0), Vector3(0.08, 0.06, 0.16), color.lightened(0.12))

func _lamp(pos: Vector3, parent: Node3D = self) -> void:
	_box(pos + Vector3(0, 0.9, 0), Vector3(0.09, 1.8, 0.09), Color("5b5f4f"), "", parent)
	_box(pos + Vector3(0, 1.65, 0), Vector3(0.42, 0.06, 0.42), Color("6f715b"), "", parent)
	var glow := _box(pos + Vector3(0, 1.86, 0), Vector3(0.27, 0.38, 0.27), Color("ffdda1"), "", parent)
	glow.material_override = _mat(Color("ffce7b"), "", 1.5)
	_box(pos + Vector3(0, 2.08, 0), Vector3(0.42, 0.10, 0.42), Color("526b60"), "", parent)
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.8, 0)
	light.light_color = Color("ffbf73")
	light.light_energy = 0.8
	light.omni_range = 4.5
	parent.add_child(light)
	lamps.append(light)

func _sprite(texture: Texture2D, pos: Vector3, pixel: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.pixel_size = pixel
	sprite.position = pos
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(sprite)
	return sprite

func _person(role: String, pos: Vector3) -> Sprite3D:
	return _sprite(Art.person(role), pos + Vector3(0, 0.81, 0), 0.038)

func add_npc(role: String, display_name: String, pos: Vector3) -> void:
	var sprite := _person(role, pos)
	npcs.append({"role":role, "name":display_name, "pos":pos, "sprite":sprite})

func _build_stage() -> void:
	stage = Node3D.new()
	stage.position = Vector3(0, 0, 55)
	add_child(stage)
	_cylinder(Vector3(0, -0.55, 0), 10, 1, Color("5e8074"), 24, stage)
	_cylinder(Vector3(0, 0.0, 0), 7.4, 0.2, Color("92a17f"), 24, stage)
	# Worn tiles and inset rings keep the arena rooted in a physical ruin.
	for ring in range(3):
		for i in range(28):
			var a: float = float(i) * TAU / 28.0
			var radius: float = 4.8 + ring * 0.55
			var tile := _box(Vector3(cos(a) * radius, 0.13, sin(a) * radius * 0.82), Vector3(0.76, 0.04, 0.42), Color("829687").lightened(_rng.randf_range(0, 0.18)), "stone", stage)
			tile.rotation.y = -a + PI / 2
	_cylinder(Vector3(-3.0, 0.16, 1.6), 2.2, 0.18, Color("c0b99a"), 24, stage)
	_cylinder(Vector3(3.0, 0.16, -1.4), 2.2, 0.18, Color("c0b99a"), 24, stage)
	for i in range(12):
		var a := float(i) * TAU / 12.0
		_box(Vector3(cos(a) * 6, 0.24, sin(a) * 5), Vector3(0.8, 0.12, 0.6), Color("b4bb9f"), "stone", stage)
	for x in [-6, 6]:
		for z in [-3.8, 3.8]:
			_cylinder(Vector3(x, 1.1, z), 0.45, 2.2, Color("9aa89a"), 8, stage)
			_cylinder(Vector3(x, 2.3, z), 0.65, 0.25, Color("bac0a2"), 8, stage)
			_lamp(Vector3(x, 2.42, z), stage)
	for i in range(8):
		var p := Vector3(-7.5 + i * 2.1, 0.0, 49.0 - absf(3.5 - i) * 0.18)
		_tree(p, 0.8, false)
	battle_player = _sprite(Art.creature(0), Vector3(-3.0, 1.9, 56.6), 0.052)
	battle_enemy = _sprite(Art.creature(3), Vector3(3.0, 1.9, 53.6), 0.047)
	battle_player.visible = false
	battle_enemy.visible = false

func can_walk(pos: Vector3) -> bool:
	if absf(pos.x) > 14.5 or absf(pos.z) > 10.6:
		return false
	if absf(pos.x) < 1.9 and (pos.z < 3.25 or pos.z > 4.95):
		return false
	for rect in obstacles:
		if rect.grow(0.18).has_point(Vector2(pos.x, pos.z)):
			return false
	return true

func walk(input: Vector2, delta: float, sprint: bool) -> float:
	moving = input.length() > 0.1
	if not moving:
		return 0.0
	input = input.normalized()
	if absf(input.x) > absf(input.y):
		direction = 3 if input.x > 0 else 2
	else:
		direction = 0 if input.y > 0 else 1
	var movement := Vector3(input.x, 0, input.y) * (4.6 if sprint else 3.1) * delta
	var old := player_position
	var attempt := player_position + Vector3(movement.x, 0, 0)
	if can_walk(attempt):
		player_position = attempt
	attempt = player_position + Vector3(0, 0, movement.z)
	if can_walk(attempt):
		player_position = attempt
	return old.distance_to(player_position)

func nearby() -> Dictionary:
	var nearest: Dictionary = {}
	var distance: float = 1.7
	for npc in npcs:
		var d: float = player_position.distance_to(npc.pos)
		if d < distance:
			distance = d
			nearest = npc
	return nearest

func is_grass() -> bool:
	return player_position.x > 3.6 and player_position.z > -1.8 and player_position.z < 8.5 and absf(player_position.z - 4.1) > 1.12 and absf(player_position.x - 9) > 1.3

func area_name() -> String:
	if player_position.x < 0:
		return "WAKEHARBOR"
	if player_position.z < -3.8:
		return "FIRST LIGHT SANCTUM"
	return "CANDLE REED MEADOW"

func set_battle(enabled: bool, player_id: int = 0, enemy_id: int = 3) -> void:
	in_battle = enabled
	battle_ids = Vector2i(player_id, enemy_id)
	battle_player.visible = enabled
	battle_enemy.visible = enabled
	_last_frame = -1
	if enabled:
		_camera_target = Vector3(0, 0, 55)
		camera.size = 12.8
	else:
		_camera_target = player_position
		camera.size = 15.6
	camera.position = _camera_target + (Vector3(0, 12, 22) if enabled else Vector3(0, 17, 20))
	camera.look_at(_camera_target)

func _process(delta: float) -> void:
	clock += delta
	var frame := int(clock * (7.0 if moving else 2.2)) % 3
	var art_key: String = str(direction) + str(companion_id) + str(battle_ids)
	if frame != _last_frame or art_key != _last_art_key:
		_last_frame = frame
		_last_art_key = art_key
		player.texture = Art.person("player", frame if moving else 0, direction)
		if companion_id >= 0:
			companion.texture = Art.creature(companion_id, frame)
		if in_battle:
			battle_player.texture = Art.creature(battle_ids.x, frame, true)
			battle_enemy.texture = Art.creature(battle_ids.y, frame)
	player.position = player_position + Vector3(0, 0.81 + (absf(sin(clock * 13)) * 0.045 if moving else 0), 0)
	companion.visible = companion_id >= 0 and not in_battle
	companion.position = companion.position.lerp(player_position + Vector3(0.65, 0.6 + sin(clock * 3) * 0.04, 0.65), minf(1, delta * 4))
	if not in_battle:
		var target := Vector3(clampf(player_position.x, -9, 9), 0, clampf(player_position.z, -6, 6))
		_camera_target = _camera_target.lerp(target, 1.0 - exp(-delta * 3.5))
		camera.position = _camera_target + Vector3(0, 17, 20)
		camera.look_at(_camera_target)
	else:
		battle_pulse = maxf(0, battle_pulse - delta * 2)
		battle_player.position.y = 1.9 + sin(clock * 2.2) * 0.06
		battle_enemy.position.y = 1.9 + sin(clock * 2.2 + 1.5) * 0.07
		battle_enemy.modulate = Color.WHITE.lerp(Color("ffc5a1"), battle_pulse)
		battle_player.position.x = -3.0 + sin(clock * 35) * battle_pulse * 0.09
	for i in range(lamps.size()):
		lamps[i].light_energy = 0.8 + sin(clock * 2.3 + i * 1.7) * 0.08
	for i in range(motes.size()):
		motes[i].position.y += sin(clock * 1.2 + i) * delta * 0.09
		motes[i].position.x += cos(clock * 0.6 + i) * delta * 0.04
	# Foreground leaves soften away when they would hide the traveller.
	if not in_battle:
		var screen_player: Vector2 = camera.unproject_position(player.position)
		var screen_scale: float = get_viewport().get_visible_rect().size.y / 720.0
		for leaves in foliage:
			var occluding: bool = leaves.position.z > player_position.z + 0.2 and camera.unproject_position(leaves.position).distance_to(screen_player) < 94 * screen_scale
			var alpha: float = lerpf(leaves.modulate.a, 0.24 if occluding else 1.0, minf(1, delta * 7))
			leaves.modulate.a = alpha
			leaves.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED if alpha < 0.98 else SpriteBase3D.ALPHA_CUT_DISCARD
