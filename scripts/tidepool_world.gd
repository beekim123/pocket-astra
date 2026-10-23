extends RefCounted
## The tideglass shore is a small, fixed diorama, generated only once.
## Progress changes swap marker materials and move the rescued moth explicitly.

const Art = preload("res://scripts/art.gd")
const CAUSEWAY := Rect2(-8.3, 10.0, 2.7, 3.4)
const BOUNDS := Rect2(-13.4, 13.0, 10.8, 10.6)
const POOLS: Array[Rect2] = [Rect2(-11.5, 15.3, 4.0, 2.0), Rect2(-7.0, 18.0, 3.2, 2.6)]
const REEDS := Rect2(-12.8, 18.0, 2.8, 2.2)
const MARKERS: Array[Dictionary] = [
	{"role":"tide_wind", "name":"WIND-HOLE STONE", "pos":Vector3(-11.8, 0, 14.3)},
	{"role":"tide_water", "name":"WATER CHANNEL", "pos":Vector3(-12.0, 0, 21.4)},
	{"role":"tide_brass", "name":"BRASS CHIMES", "pos":Vector3(-3.5, 0, 16.2)},
]
const RESCUE_POSITION := Vector3(-4.5, 0, 21.7)
const HARBOR_PERCH := Vector3(-9.0, 0, 8.5)

var root_node: Node3D
var rescue: Sprite3D
var marker_lights: Dictionary = {}
var marker_gems: Dictionary = {}
var _world
var _rescue_entry: Dictionary


func build(world: Node3D) -> void:
	_world = world
	root_node = Node3D.new()
	root_node.name = "TideglassPools"
	_world.add_child(root_node)
	_build_rock_shelf()
	_build_causeway()
	for basin in POOLS:
		_build_pool(basin)
		_world.obstacles.append(basin)
	_build_reeds()
	_build_markers()
	_build_rescue_and_artisan()
	sync_progress({})


func _box(pos: Vector3, size: Vector3, color: Color, texture_kind: String = "") -> MeshInstance3D:
	return _world._box(pos, size, color, texture_kind, root_node)


func _cylinder(pos: Vector3, radius: float, height: float, color: Color, vertices: int = 8) -> MeshInstance3D:
	return _world._cylinder(pos, radius, height, color, vertices, root_node)


func _build_rock_shelf() -> void:
	var center := BOUNDS.get_center()
	_box(Vector3(center.x, -0.95, center.y), Vector3(10.8, 1.8, 10.6), Color("354f55"), "stone")
	_box(Vector3(center.x, -0.24, center.y), Vector3(10.8, 0.45, 10.6), Color("8a9c94"), "stone")
	_box(Vector3(center.x, -0.025, center.y), Vector3(10.8, 0.10, 10.6), Color("afc2b3"), "stone")
	# Broken, low ledges stay below the walkable shelf and give it a rocky silhouette.
	for side in [-1, 1]:
		for i in range(6):
			var ledge := _box(Vector3(center.x + side * 5.35, -0.35, 13.6 + i * 1.8), Vector3(0.8, 0.46, 1.25), Color("607d7b"), "stone")
			ledge.rotation.y = side * (0.09 + (i % 3) * 0.08)
	for i in range(7):
		_box(Vector3(-12.7 + i * 1.55, -0.27, 23.55), Vector3(1.0, 0.38, 0.55), Color("668682"), "stone")
	# Scattered pale slabs and small brass diamonds are an original wayfinding motif.
	for i in range(16):
		var pos := Vector3(-12.2 + (i % 4) * 2.8, 0.055, 14.0 + floori(i / 4.0) * 2.7)
		var wet: bool = false
		for basin in POOLS:
			if basin.grow(0.45).has_point(Vector2(pos.x, pos.z)):
				wet = true
		if wet or REEDS.grow(0.25).has_point(Vector2(pos.x, pos.z)):
			continue
		var tile := _box(pos, Vector3(0.82, 0.045, 0.65), Color("c9d4bf"))
		tile.rotation.y = 0.05 if i % 2 == 0 else -0.05
		var diamond := _box(pos + Vector3(0, 0.035, 0), Vector3(0.17, 0.022, 0.17), Color("c69b5c"))
		diamond.rotation.y = PI / 4
	# A clear dry route runs down the east side of both basins.
	for i in range(8):
		_box(Vector3(-3.05, 0.035, 14.0 + i * 1.18), Vector3(0.15, 0.025, 0.48), Color("e0c58f"))


func _build_causeway() -> void:
	_box(Vector3(-6.95, -0.25, 11.7), Vector3(2.7, 0.6, 3.4), Color("647c78"), "stone")
	for i in range(10):
		_box(Vector3(-6.95, 0.065, 10.15 + i * 0.34), Vector3(2.5, 0.10, 0.29), Color("c4aa78") if i % 2 == 0 else Color("b59f75"), "wood")
	for x in [-8.18, -5.72]:
		for z in [10.25, 13.1]:
			_box(Vector3(x, 0.34, z), Vector3(0.12, 0.66, 0.12), Color("697b6d"))
			_box(Vector3(x, 0.69, z), Vector3(0.19, 0.06, 0.19), Color("d3b777"))
	# An open shore workshop identifies the optional route from the village.
	_box(Vector3(-10.0, 0.50, 8.65), Vector3(1.3, 0.12, 0.65), Color("a58c65"), "wood")
	for x in [-10.52, -9.48]:
		_box(Vector3(x, 0.23, 8.65), Vector3(0.10, 0.46, 0.48), Color("62776c"))
	for i in range(3):
		_box(Vector3(-10.4 + i * 0.35, 0.60, 8.65), Vector3(0.22, 0.07, 0.25), Color("6caaa3") if i % 2 else Color("dbc08a"))
	# The moth's return perch is visible beside its lanternwright.
	_box(HARBOR_PERCH + Vector3(0, 0.24, 0), Vector3(0.08, 0.48, 0.08), Color("667f77"))
	_cylinder(HARBOR_PERCH + Vector3(0, 0.49, 0), 0.26, 0.08, Color("d4b779"))


func _build_pool(basin: Rect2) -> void:
	var center := basin.get_center()
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = basin.size
	plane.subdivide_width = 4
	plane.subdivide_depth = 4
	water.mesh = plane
	water.position = Vector3(center.x, 0.065, center.y)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water.gdshader")
	material.set_shader_parameter("deep_color", Color("3f8f91"))
	water.material_override = material
	root_node.add_child(water)
	# Raised lips make the pools legible as blocked water, with broad dry margins.
	for side in [-1, 1]:
		_box(Vector3(center.x, 0.09, center.y + side * basin.size.y * 0.5), Vector3(basin.size.x + 0.12, 0.16, 0.14), Color("587e7c"), "stone")
		_box(Vector3(center.x + side * basin.size.x * 0.5, 0.09, center.y), Vector3(0.14, 0.16, basin.size.y), Color("587e7c"), "stone")
	for i in range(3):
		_box(Vector3(basin.position.x + 0.48 + i * basin.size.x * 0.29, 0.105, center.y + (0.28 if i % 2 == 0 else -0.3)), Vector3(0.48, 0.022, 0.045), Color("a5d6c4"))


func _build_reeds() -> void:
	_box(Vector3(REEDS.get_center().x, 0.045, REEDS.get_center().y), Vector3(REEDS.size.x, 0.035, REEDS.size.y), Color("547e74"), "grass")
	var reeds := SurfaceTool.new()
	reeds.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(8):
		for z in range(7):
			var pos := Vector3(-12.65 + x * 0.34, 0.075, 18.15 + z * 0.29)
			if not is_encounter_point(pos):
				continue
			var height: float = 0.31 + float((x * 3 + z) % 4) * 0.055
			reeds.set_color(Color("73aa90") if (x + z) % 2 == 0 else Color("43796e"))
			for offset in [-0.07, 0.07]:
				reeds.add_vertex(pos + Vector3(offset - 0.05, 0, 0))
				reeds.add_vertex(pos + Vector3(offset + 0.05, height, 0.05))
				reeds.add_vertex(pos + Vector3(offset + 0.09, 0, 0))
	reeds.generate_normals()
	var reed_mesh := MeshInstance3D.new()
	reed_mesh.mesh = reeds.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	reed_mesh.material_override = material
	root_node.add_child(reed_mesh)


func _build_markers() -> void:
	for marker in MARKERS:
		var pos: Vector3 = marker.pos
		_cylinder(pos + Vector3(0, 0.08, 0), 0.52, 0.16, Color("6b8981"))
		match String(marker.role):
			"tide_wind":
				# Four blocks leave a real open wind hole through this low stone arch.
				for side in [-1, 1]:
					_box(pos + Vector3(side * 0.3, 0.61, 0), Vector3(0.22, 0.95, 0.34), Color("93b4ab"), "stone")
				_box(pos + Vector3(0, 1.12, 0), Vector3(0.88, 0.25, 0.40), Color("b3c9bc"), "stone")
				_box(pos + Vector3(0, 0.35, 0), Vector3(0.65, 0.13, 0.34), Color("839f96"))
			"tide_water":
				for side in [-1, 1]:
					_box(pos + Vector3(side * 0.31, 0.29, 0), Vector3(0.16, 0.40, 0.92), Color("a8c1b6"), "stone")
				_box(pos + Vector3(0, 0.21, 0), Vector3(0.48, 0.07, 0.92), Color("5cb1ae"))
				for i in range(3):
					_box(pos + Vector3(0, 0.26, -0.28 + i * 0.27), Vector3(0.31, 0.02, 0.06), Color("c2e3cb"))
			"tide_brass":
				for side in [-1, 1]:
					_box(pos + Vector3(side * 0.38, 0.65, 0), Vector3(0.09, 1.15, 0.10), Color("668c7e"))
				_box(pos + Vector3(0, 1.25, 0), Vector3(0.94, 0.10, 0.16), Color("d2b378"))
				for i in range(3):
					_box(pos + Vector3(-0.25 + i * 0.25, 1.03, 0), Vector3(0.02, 0.35, 0.02), Color("728e7f"))
					_box(pos + Vector3(-0.25 + i * 0.25, 0.68 + i * 0.09, 0), Vector3(0.14, 0.41 - i * 0.07, 0.05), Color("d8b365"))
		var gem := _box(pos + Vector3(0, 0.20, 0.43), Vector3(0.17, 0.10, 0.17), Color("657f79"))
		gem.rotation.y = PI / 4
		marker_gems[marker.role] = gem
		var light := OmniLight3D.new()
		light.position = pos + Vector3(0, 0.7, 0)
		light.light_color = Color("b9ead2")
		light.light_energy = 0.40
		light.omni_range = 1.7
		root_node.add_child(light)
		marker_lights[marker.role] = light
		_world.npcs.append(marker.duplicate())


func _build_rescue_and_artisan() -> void:
	var artisan: Sprite3D = _world._person("mentor", Vector3(-8.6, 0, 8.5))
	artisan.modulate = Color("d6efe0")
	_world.npcs.append({"role":"tide_artisan", "name":"TAVI / SHORE LANTERNWRIGHT", "pos":Vector3(-8.6, 0, 8.5), "sprite":artisan})
	_cylinder(RESCUE_POSITION + Vector3(0, 0.08, 0), 0.62, 0.16, Color("bed0bc"), 10)
	for side in [-1, 1]:
		_box(RESCUE_POSITION + Vector3(side * 0.43, 0.16, 0.28), Vector3(0.18, 0.12, 0.34), Color("d5bb83"))
	rescue = _world._sprite(Art.creature(3), RESCUE_POSITION + Vector3(0, 0.66, 0), 0.022)
	_rescue_entry = {"role":"tide_rescue", "name":"A STRANDED WISPIP", "pos":RESCUE_POSITION, "sprite":rescue, "active":true}
	_world.npcs.append(_rescue_entry)


func sync_progress(flags: Dictionary) -> void:
	var rescued: bool = bool(flags.get("tide_rescued", false))
	rescue.position = (HARBOR_PERCH if rescued else RESCUE_POSITION) + Vector3(0, 0.66, 0)
	_rescue_entry.active = not rescued
	for marker in MARKERS:
		var active: bool = bool(flags.get(marker.role, false))
		var gem: MeshInstance3D = marker_gems[marker.role]
		gem.material_override = _world._mat(Color("bce8bb"), "", 1.0) if active else _world._mat(Color("657f79"))
		var light: OmniLight3D = marker_lights[marker.role]
		light.visible = active


static func is_encounter_point(pos: Vector3) -> bool:
	if not REEDS.has_point(Vector2(pos.x, pos.z)):
		return false
	for marker in MARKERS:
		var marker_pos: Vector3 = marker.pos
		if Vector2(pos.x, pos.z).distance_to(Vector2(marker_pos.x, marker_pos.z)) < 2.0:
			return false
	return true
