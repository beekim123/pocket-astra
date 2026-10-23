extends RefCounted
## A working quay and a separate lee berth, joined only by the charted boat route.
## All surfaces, craft tools and landmarks are generated from small shared materials.

const BOUNDS := Rect2(108, -11, 24, 22)
const BERTH_BOUNDS := Rect2(136, -5, 8, 10)
const DOCK := Vector3(120, 0, 8)
const BERTH := Vector3(140, 0, 2)
const MARKERS: Array[Dictionary] = [
	{"role":"wind_wind", "name":"WIND VANE", "pos":Vector3(112, 0, -5), "island":"windchart"},
	{"role":"wind_tide", "name":"TIDE GAUGE", "pos":Vector3(128, 0, 3), "island":"windchart"},
	{"role":"wind_light", "name":"PAIRED LIGHTS", "pos":Vector3(127, 0, -6), "island":"windchart"},
]
const CHART_POSITION := Vector3(120, 0, -3)
const KEEPER_POSITION := Vector3(116, 0, 6)
const FERRY_POSITION := Vector3(120, 0, 9.4)
const RAIN_FERRY_POSITION := Vector3(64, 0, 8.2)
const SAILMAKER_POSITION := Vector3(140, 0, -1)
const RETURN_POSITION := Vector3(140, 0, 3.7)
const SHORE_MARGIN: float = 0.18

var root_node: Node3D
var obstacles: Array[Rect2] = []
var marker_lights: Dictionary = {}
var marker_gems: Dictionary = {}
var berth_light: OmniLight3D
var _berth_glass: MeshInstance3D
var _world


func build(world: Node3D) -> void:
	_world = world
	root_node = Node3D.new()
	root_node.name = "WindchartQuay"
	_world.add_child(root_node)
	_build_sea()
	_build_quay()
	_build_sheds()
	_build_boatyards()
	_build_chart()
	for marker in MARKERS:
		_build_marker(marker)
	_build_keeper()
	_build_berth()
	_build_ferries()
	for pos in [Vector3(118.2, 0, 7.4), Vector3(121.8, 0, 1.8), Vector3(124.3, 0, -5.5)]:
		_world._lamp(pos, root_node)
	sync_progress({})


func _box(pos: Vector3, size: Vector3, color: Color, texture_kind: String = "", parent: Node3D = null) -> MeshInstance3D:
	return _world._box(pos, size, color, texture_kind, root_node if parent == null else parent)


func _cylinder(pos: Vector3, radius: float, height: float, color: Color, vertices: int = 8) -> MeshInstance3D:
	return _world._cylinder(pos, radius, height, color, vertices, root_node)


func _build_sea() -> void:
	# The original sea ends west of this region; this patch belongs to its visibility root.
	var plane := PlaneMesh.new()
	plane.size = Vector2(110, 100)
	plane.subdivide_width = 12
	plane.subdivide_depth = 12
	var water := ShaderMaterial.new()
	water.shader = preload("res://shaders/water.gdshader")
	water.set_shader_parameter("deep_color", Color("225f69"))
	var ocean := MeshInstance3D.new()
	ocean.mesh = plane
	ocean.material_override = water
	ocean.position = Vector3(126, -0.65, 15)
	root_node.add_child(ocean)
	# Low offshore rocks give the eastward warning a visible counterpart.
	for i in range(5):
		var rock := _box(Vector3(134.5 + float(i % 2) * 1.1, -0.36, -10.5 + i * 1.05), Vector3(1.2, 0.8, 1.35), Color("455f67"), "stone")
		rock.rotation.y = i * 0.47
	for i in range(4):
		_cylinder(Vector3(115.5 + i * 2.7, -0.62, -14.4), 1.15, 0.12, Color("758f88"), 7)


func _build_quay() -> void:
	_box(Vector3(120, -1.5, 0), Vector3(24, 2.8, 22), Color("3e5961"), "stone")
	_box(Vector3(120, -0.43, 0), Vector3(23.95, 0.72, 21.95), Color("70858a"), "stone")
	_box(Vector3(120, -0.025, 0), Vector3(23.9, 0.15, 21.9), Color("a1aea7"), "stone")
	for side in [-1, 1]:
		for i in range(12):
			_box(Vector3(120 + side * 11.85, -0.18, -10.0 + i * 1.82), Vector3(0.45, 0.50, 1.50), Color("b6bbb0"), "stone")
		for i in range(13):
			_box(Vector3(109.0 + i * 1.82, -0.20, side * 10.87), Vector3(1.50, 0.46, 0.48), Color("82969a"), "stone")
	_path(Rect2(119.1, -6.8, 1.8, 16.8))
	_path(Rect2(111.0, -5.65, 17.4, 1.3))
	_path(Rect2(111.0, 2.35, 18.4, 1.3))
	_path(Rect2(111.35, -5.0, 1.3, 8.0))
	_path(Rect2(127.35, -5.0, 1.3, 8.0))
	_path(Rect2(115.4, 5.45, 4.6, 1.1))
	# Flat brass stitch plates echo the map table without blocking the walking surface.
	for z in [-5.0, 0.0, 3.0, 7.0]:
		var tile := _box(Vector3(120, 0.11, z), Vector3(0.28, 0.025, 0.28), Color("d4b77a"))
		tile.rotation.y = PI / 4
	for x in [109.0, 114.8, 125.0, 131.0]:
		_cylinder(Vector3(x, 0.27, 10.15), 0.19, 0.52, Color("546b71"), 6)
		_cylinder(Vector3(x, 0.55, 10.15), 0.25, 0.10, Color("cab07b"), 6)


func _path(rect: Rect2) -> void:
	var center := rect.get_center()
	_box(Vector3(center.x, 0.065, center.y), Vector3(rect.size.x, 0.035, rect.size.y), Color("66787a"), "wood")
	var across: bool = rect.size.x > rect.size.y
	var length: float = rect.size.x if across else rect.size.y
	for i in range(int(length / 0.62)):
		var pos := Vector3(rect.position.x + 0.31 + i * 0.62, 0.095, center.y) if across else Vector3(center.x, 0.095, rect.position.y + 0.31 + i * 0.62)
		var size := Vector3(0.55, 0.035, rect.size.y * 0.93) if across else Vector3(rect.size.x * 0.93, 0.035, 0.55)
		_box(pos, size, Color("b3aa8f").darkened(float(i % 3) * 0.055), "wood")


func _build_sheds() -> void:
	_shed(Vector3(113.2, 0, -8.7), Vector3(4.8, 1.65, 2.7))
	_shed(Vector3(122.5, 0, -8.9), Vector3(4.3, 1.45, 2.5))
	# Canvas is hung on a low drying frame, north of the keeper's approach.
	for x in [110.3, 114.6]:
		_box(Vector3(x, 0.73, 6.3), Vector3(0.10, 1.45, 0.10), Color("666f6b"), "wood")
	_box(Vector3(112.45, 1.40, 6.3), Vector3(4.4, 0.09, 0.09), Color("9b805f"), "wood")
	for i in range(5):
		var cloth := _box(Vector3(110.8 + i * 0.77, 1.02, 6.3), Vector3(0.60, 0.66, 0.035), Color("d7c9a6") if i % 2 else Color("bfad88"))
		cloth.rotation.z = -0.035 + i * 0.018
	# Low work crates are placed at the outer corners, away from all observation routes.
	for pos in [Vector3(109.5, 0, 8.6), Vector3(130.0, 0, 7.8)]:
		_box(pos + Vector3(0, 0.34, 0), Vector3(0.95, 0.68, 0.85), Color("996a50"), "wood")
		_box(pos + Vector3(0, 0.69, 0), Vector3(0.98, 0.07, 0.89), Color("bea47a"), "wood")
		obstacles.append(Rect2(pos.x - 0.50, pos.z - 0.45, 1.0, 0.90))


func _shed(pos: Vector3, size: Vector3) -> void:
	_box(pos + Vector3(0, 0.13, 0), Vector3(size.x + 0.3, 0.26, size.z + 0.3), Color("647a80"), "stone")
	_box(pos + Vector3(0, size.y * 0.5, 0), size, Color("9d6450"), "wood")
	for x in [-size.x * 0.5 + 0.1, size.x * 0.5 - 0.1]:
		_box(pos + Vector3(x, size.y * 0.5, size.z * 0.5 + 0.06), Vector3(0.14, size.y, 0.12), Color("d0b993"), "wood")
	for side in [-1, 1]:
		var roof := _box(pos + Vector3(0, size.y + 0.27, side * size.z * 0.27), Vector3(size.x + 0.45, 0.14, size.z * 0.66), Color("745950"), "wood")
		roof.rotation.x = side * 0.31
	_box(pos + Vector3(0, size.y + 0.50, 0), Vector3(size.x + 0.5, 0.14, 0.14), Color("bd9170"), "wood")
	_box(pos + Vector3(0, 0.63, size.z * 0.5 + 0.08), Vector3(1.6, 1.25, 0.12), Color("50686a"), "wood")
	for x in [-0.83, 0.83]:
		_box(pos + Vector3(x, 0.65, size.z * 0.5 + 0.16), Vector3(0.11, 1.35, 0.12), Color("cbb790"), "wood")
	_box(pos + Vector3(0, 1.31, size.z * 0.5 + 0.16), Vector3(1.78, 0.12, 0.12), Color("cbb790"), "wood")
	obstacles.append(Rect2(pos.x - size.x * 0.5 - 0.16, pos.z - size.z * 0.5 - 0.16, size.x + 0.32, size.z + 0.32))


func _build_boatyards() -> void:
	# Work stays inside the two courtyards, below waist height and clear of every road.
	_repair_hull(Vector3(114.4, 0, -0.8), false)
	_repair_hull(Vector3(124.9, 0, -1.0), true)
	for z in [-1.05, 0.35]:
		_box(Vector3(116.2, 0.16, z), Vector3(0.95, 0.24, 0.15), Color("6f776c"), "wood")
	for i in range(4):
		var timber := _box(Vector3(115.93 + float(i % 2) * 0.45, 0.32 + floorf(i / 2.0) * 0.14, -0.35), Vector3(0.35, 0.12, 2.05), Color("ba9670") if i % 2 else Color("d0b387"), "wood")
		timber.rotation.y = 0.015 if i % 2 else -0.015
	obstacles.append(Rect2(115.7, -1.42, 1.0, 2.16))
	# Bound rolls show cloth waiting for the sailmaker, with no tall mast or canopy.
	for i in range(2):
		var pos := Vector3(124.55, 0.25, 0.85 + i * 0.45)
		var roll := _cylinder(pos, 0.18, 1.35, Color("ddd0ac") if i == 0 else Color("c2b793"), 8)
		roll.rotation.z = PI / 2
		for x in [-0.40, 0.40]:
			var tie := _cylinder(pos + Vector3(x, 0, 0), 0.188, 0.07, Color("8a7556"), 8)
			tie.rotation.z = PI / 2
	obstacles.append(Rect2(123.84, 0.64, 1.42, 0.87))


func _repair_hull(pos: Vector3, sideways: bool) -> void:
	var frame := Node3D.new()
	frame.name = "OpenHullFrame" if sideways else "HullUnderRepair"
	frame.position = pos
	frame.rotation.y = PI / 2 if sideways else 0.0
	root_node.add_child(frame)
	for z in [-1.0, 1.0]:
		_box(Vector3(0, 0.27, z), Vector3(1.55, 0.12, 0.16), Color("758078"), "wood", frame)
		for side in [-1, 1]:
			var leg := _box(Vector3(side * 0.60, 0.16, z), Vector3(0.12, 0.30, 0.14), Color("756650"), "wood", frame)
			leg.rotation.z = -side * 0.20
	_box(Vector3(0, 0.37, 0), Vector3(0.15, 0.15, 3.55), Color("8e664e"), "wood", frame)
	# Exposed ribs distinguish a hull being built from the finished ferry beside the pier.
	for i in range(4):
		var z: float = -1.20 + i * 0.80
		var width: float = 0.80 if i in [0, 3] else 1.16
		_box(Vector3(0, 0.46, z), Vector3(width, 0.09, 0.12), Color("d1b383"), "wood", frame)
		for side in [-1, 1]:
			var rib := _box(Vector3(side * width * 0.48, 0.62, z), Vector3(0.10, 0.43, 0.12), Color("c2a074"), "wood", frame)
			rib.rotation.z = -side * 0.32
	for side in [-1, 1]:
		_box(Vector3(side * 0.67, 0.80, 0), Vector3(0.10, 0.10, 2.75), Color("b17c58"), "wood", frame)
		var bow := _box(Vector3(side * 0.32, 0.74, -1.60), Vector3(0.10, 0.17, 0.81), Color("b17c58"), "wood", frame)
		bow.rotation.y = side * 0.88
	if not sideways:
		for i in range(3):
			_box(Vector3(-0.48 + i * 0.28, 0.50, 0.16), Vector3(0.24, 0.06, 2.30), Color("9c6c51").lightened(i * 0.035), "wood", frame)
		_box(Vector3(0.69, 0.64, 0.28), Vector3(0.07, 0.26, 2.12), Color("a87555"), "wood", frame)
	var footprint := Vector2(3.7, 1.6) if sideways else Vector2(1.6, 3.7)
	obstacles.append(Rect2(Vector2(pos.x, pos.z) - footprint * 0.5, footprint))


func _build_chart() -> void:
	# The low tabletop remains reachable from every side and cannot cover the traveller.
	_box(CHART_POSITION + Vector3(0, 0.40, 0), Vector3(0.16, 0.8, 0.16), Color("665f53"), "wood")
	_box(CHART_POSITION + Vector3(0, 0.79, 0), Vector3(1.5, 0.12, 1.1), Color("a17d55"), "wood")
	_box(CHART_POSITION + Vector3(0, 0.86, 0), Vector3(1.30, 0.025, 0.90), Color("e0d1a7"))
	for i in range(3):
		var route := _box(CHART_POSITION + Vector3(-0.36 + i * 0.35, 0.88, -0.03), Vector3(0.055, 0.015, 0.62), Color("688b8b") if i != 2 else Color("ae7e4e"))
		route.rotation.y = -0.30 + i * 0.30
	_cylinder(CHART_POSITION + Vector3(0.43, 0.90, -0.26), 0.13, 0.045, Color("b99a5d"), 8)
	_world.npcs.append({"role":"wind_chart", "name":"WINDCHART TABLE", "pos":CHART_POSITION, "island":"windchart"})


func _build_marker(marker: Dictionary) -> void:
	var pos: Vector3 = marker.pos
	var role: String = marker.role
	_cylinder(pos + Vector3(0, 0.12, 0), 0.40, 0.20, Color("70898c"), 8)
	match role:
		"wind_wind":
			_box(pos + Vector3(0, 0.86, 0), Vector3(0.10, 1.55, 0.10), Color("b79a61"))
			_box(pos + Vector3(0, 1.55, 0), Vector3(1.1, 0.07, 0.07), Color("d2bb83"))
			var vane := _box(pos + Vector3(0.36, 1.42, 0), Vector3(0.59, 0.24, 0.035), Color("cc956c"))
			vane.rotation.z = -0.14
			_box(pos + Vector3(-0.52, 1.55, 0), Vector3(0.22, 0.14, 0.12), Color("d2bb83"))
		"wind_tide":
			_box(pos + Vector3(0, 0.68, 0), Vector3(0.25, 1.18, 0.16), Color("d7c8a7"))
			for i in range(5):
				_box(pos + Vector3(-0.035, 0.30 + i * 0.19, 0.095), Vector3(0.20 if i % 2 == 0 else 0.13, 0.035, 0.025), Color("5c7a7e"))
			_box(pos + Vector3(0.22, 0.36, 0), Vector3(0.34, 0.08, 0.26), Color("b89b66"))
		"wind_light":
			for side in [-1, 1]:
				_box(pos + Vector3(side * 0.33, 0.53, -0.18), Vector3(0.11, 0.9, 0.11), Color("ac8e5e"))
				var glass := _box(pos + Vector3(side * 0.33, 1.02, -0.18), Vector3(0.27, 0.28, 0.27), Color("d8ddc8"))
				glass.material_override = _world._mat(Color("d8ddc8"), "", 0.35)
				_box(pos + Vector3(side * 0.33, 1.20, -0.18), Vector3(0.36, 0.08, 0.36), Color("8d7958"))
	var gem := _box(pos + Vector3(0, 0.31, 0.34), Vector3(0.20, 0.12, 0.18), Color("777f79"))
	gem.rotation.y = PI / 4
	marker_gems[role] = gem
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 0.75, 0.2)
	light.light_color = Color("e7d697")
	light.light_energy = 0.55
	light.omni_range = 2.0
	root_node.add_child(light)
	marker_lights[role] = light
	_world.npcs.append(marker.duplicate())


func _build_keeper() -> void:
	_add_person("wind_keeper", "MAREN", KEEPER_POSITION, "keeper", Color("ecd1ae"), root_node, "windchart")
	# A brass divider and rolled canvas identify the keeper's chart-making craft.
	var pos := KEEPER_POSITION + Vector3(-1.5, 0, -0.1)
	_workbench(pos)
	_box(pos + Vector3(0, 0.69, 0), Vector3(0.78, 0.12, 0.30), Color("ded1ad"))
	for side in [-1, 1]:
		var divider := _box(pos + Vector3(side * 0.18, 0.78, 0.19), Vector3(0.035, 0.035, 0.36), Color("c6a66a"))
		divider.rotation.y = side * 0.45


func _workbench(pos: Vector3) -> void:
	_box(pos + Vector3(0, 0.55, 0), Vector3(1.30, 0.13, 0.66), Color("ab8160"), "wood")
	for x in [-0.48, 0.48]:
		_box(pos + Vector3(x, 0.27, 0), Vector3(0.11, 0.54, 0.52), Color("6d6b60"), "wood")


func _build_berth() -> void:
	_box(Vector3(140, -1.2, 0), Vector3(8, 2.2, 10), Color("3d5960"), "stone")
	_box(Vector3(140, -0.29, 0), Vector3(7.95, 0.52, 9.95), Color("8d9d99"), "stone")
	_box(Vector3(140, 0.015, 0), Vector3(7.9, 0.12, 9.9), Color("b0b6a4"), "stone")
	for x in [136.2, 143.8]:
		for i in range(6):
			_box(Vector3(x, -0.11, -4.3 + i * 1.70), Vector3(0.43, 0.40, 1.4), Color("7b9497"), "stone")
	_path(Rect2(139.25, -1.8, 1.5, 6.5))
	_shed(Vector3(139.0, 0, -3.6), Vector3(4.0, 1.3, 1.8))
	_workbench(Vector3(137.6, 0, -0.5))
	for i in range(3):
		var spool := _cylinder(Vector3(137.3 + i * 0.27, 0.71, -0.5), 0.095, 0.20, Color("d9c69a"), 6)
		spool.rotation.z = PI / 2
	_add_person("wind_berth", "SELA / SAILMAKER", SAILMAKER_POSITION, "healer", Color("e8cbb3"), root_node, "windchart")
	# The warm arrival light records the finished journey, independent of marker progress.
	var pos := Vector3(142.7, 0, 0.8)
	_cylinder(pos + Vector3(0, 0.15, 0), 0.37, 0.28, Color("7d9493"), 8)
	_box(pos + Vector3(0, 0.88, 0), Vector3(0.12, 1.45, 0.12), Color("a58b62"))
	_berth_glass = _box(pos + Vector3(0, 1.63, 0), Vector3(0.36, 0.48, 0.36), Color("687b78"))
	_box(pos + Vector3(0, 1.94, 0), Vector3(0.52, 0.12, 0.52), Color("9d7658"), "wood")
	berth_light = OmniLight3D.new()
	berth_light.position = pos + Vector3(0, 1.65, 0)
	berth_light.light_color = Color("ffdda1")
	berth_light.light_energy = 0.8
	berth_light.omni_range = 5.5
	root_node.add_child(berth_light)
	_world.lamps.append(berth_light)


func _build_ferries() -> void:
	_dock(Vector3(120, 0, 10), root_node)
	_boat(Vector3(122.3, -0.29, 11.6), root_node)
	_add_person("wind_ferry_home", "MAREN / FERRY TO RAINSTEP", FERRY_POSITION, "keeper", Color("ecd1ae"), root_node, "windchart")
	# Add only outboard visuals and a sprite: existing Rainstep collision stays untouched.
	var rain_root: Node3D = _world.rainstep.root_node
	_dock(Vector3(64, 0, 10), rain_root)
	_boat(Vector3(65.9, -0.29, 11.5), rain_root)
	_add_person("wind_ferry_out", "MAREN / FERRY TO WINDCHART", RAIN_FERRY_POSITION, "keeper", Color("ecd1ae"), rain_root, "rainstep")
	_dock(Vector3(140, 0, 4.6), root_node)
	_boat(Vector3(142.0, -0.29, 6.2), root_node)
	_world.npcs.append({"role":"wind_return", "name":"SKIFF TO WINDCHART QUAY", "pos":RETURN_POSITION, "island":"windchart"})
	_box(RETURN_POSITION + Vector3(-0.55, 0.35, 0.12), Vector3(0.10, 0.70, 0.10), Color("b69a6b"))
	_box(RETURN_POSITION + Vector3(-0.55, 0.69, 0.12), Vector3(0.50, 0.23, 0.05), Color("e1c994"))


func _dock(pos: Vector3, parent: Node3D) -> void:
	for i in range(7):
		_box(pos + Vector3(0, 0.06, i * 0.35), Vector3(1.9, 0.17, 0.30), Color("ae9577"), "wood", parent)
	for x in [-1.0, 1.0]:
		for z in [0.1, 2.1]:
			_box(pos + Vector3(x, 0.28, z), Vector3(0.15, 0.74, 0.15), Color("697876"), "wood", parent)
			_box(pos + Vector3(x, 0.68, z), Vector3(0.23, 0.08, 0.23), Color("c2a67b"), "", parent)


func _boat(pos: Vector3, parent: Node3D) -> void:
	_box(pos, Vector3(1.25, 0.33, 2.65), Color("825e50"), "wood", parent)
	_box(pos + Vector3(0, 0.20, 0), Vector3(1.04, 0.10, 2.35), Color("c1ad83"), "wood", parent)
	for x in [-0.63, 0.63]:
		_box(pos + Vector3(x, 0.32, 0), Vector3(0.11, 0.36, 2.65), Color("b77d5e"), "wood", parent)
	for z in [-0.78, 0.64]:
		_box(pos + Vector3(0, 0.41, z), Vector3(1.12, 0.10, 0.29), Color("7b8880"), "wood", parent)
	var prow := _box(pos + Vector3(0, 0.12, -1.38), Vector3(0.79, 0.27, 0.64), Color("a16d53"), "wood", parent)
	prow.rotation.y = PI / 4
	_box(pos + Vector3(0.08, 0.43, 0.10), Vector3(0.60, 0.17, 0.55), Color("e0cfaa"), "", parent)
	var oar := _box(pos + Vector3(0.87, 0.52, 0.17), Vector3(0.07, 0.07, 2.5), Color("d1b781"), "wood", parent)
	oar.rotation.y = -0.31


func _add_person(role: String, display_name: String, pos: Vector3, art_role: String, color: Color, parent: Node3D, island: String) -> void:
	var sprite: Sprite3D = _world._person(art_role, pos)
	sprite.modulate = color
	sprite.reparent(parent)
	_world.npcs.append({"role":role, "name":display_name, "pos":pos, "sprite":sprite, "island":island})


func sync_progress(flags: Dictionary) -> void:
	for marker in MARKERS:
		var active: bool = bool(flags.get(marker.role, false))
		var gem: MeshInstance3D = marker_gems[marker.role]
		gem.material_override = _world._mat(Color("f0d891"), "", 0.9) if active else _world._mat(Color("777f79"))
		var light: OmniLight3D = marker_lights[marker.role]
		light.visible = active
	var rewarded: bool = bool(flags.get("wind_rewarded", false))
	berth_light.visible = rewarded
	_berth_glass.material_override = _world._mat(Color("ffdda1"), "", 1.8) if rewarded else _world._mat(Color("687b78"))


func can_walk(pos: Vector3) -> bool:
	if not pos.is_finite():
		return false
	var point := Vector2(pos.x, pos.z)
	if not BOUNDS.grow(-SHORE_MARGIN).has_point(point) and not BERTH_BOUNDS.grow(-SHORE_MARGIN).has_point(point):
		return false
	for rect in obstacles:
		if rect.grow(SHORE_MARGIN).has_point(point):
			return false
	return true
