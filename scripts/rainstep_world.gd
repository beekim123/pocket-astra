extends RefCounted
## A second island with a flat navigation shelf and layered, hand-built waterworks.
## The village is built once; restoring progress only swaps local visual states.

const BOUNDS := Rect2(48, -11, 24, 22)
const DOCK := Vector3(60, 0, 8)
const PATCHES: Array[Rect2] = [Rect2(64, 3, 4, 3), Rect2(50, -0.8, 3.5, 2.8)]
const MARKERS: Array[Dictionary] = [
	{"role":"rain_upper", "name":"ROOF INTAKE", "pos":Vector3(52, 0, -6.5), "island":"rainstep"},
	{"role":"rain_middle", "name":"BRIDGE JUNCTION", "pos":Vector3(67, 0, -1.5), "island":"rainstep"},
	{"role":"rain_lower", "name":"GARDEN OUTLET", "pos":Vector3(52, 0, 3.8), "island":"rainstep"},
]
const KEEPER_POSITION := Vector3(56, 0, 5.5)
const FERRY_POSITION := Vector3(60, 0, 9.4)
const NERI_POSITION := Vector3(63.5, 0, -6.5)
const ILYA_POSITION := Vector3(60, 0, -8.6)
const BEACON_POSITION := Vector3(60, 0, -9.7)
const SHORE_MARGIN: float = 0.18

var root_node: Node3D
var obstacles: Array[Rect2] = []
var channel_water: Dictionary = {}
var marker_gems: Dictionary = {}
var marker_lights: Dictionary = {}
var beacon_light: OmniLight3D
var beacon_flame: MeshInstance3D
var _trial_badge: MeshInstance3D
var _still_material: StandardMaterial3D
var _flow_materials: Dictionary = {}
var _world


func build(world: Node3D) -> void:
	_world = world
	root_node = Node3D.new()
	root_node.name = "RainstepTerraces"
	_world.add_child(root_node)
	_build_shelf()
	_build_paths()
	_build_cottages()
	_build_channels()
	_build_beacon()
	_build_plants()
	_build_ferries()
	_build_keeper()
	_build_challengers()
	_build_lights()
	sync_progress({})


func _box(pos: Vector3, size: Vector3, color: Color, texture_kind: String = "") -> MeshInstance3D:
	return _world._box(pos, size, color, texture_kind, root_node)


func _cylinder(pos: Vector3, radius: float, height: float, color: Color, vertices: int = 8) -> MeshInstance3D:
	return _world._cylinder(pos, radius, height, color, vertices, root_node)


func _build_shelf() -> void:
	_box(Vector3(60, -1.6, 0), Vector3(24, 3.0, 22), Color("414c69"), "stone")
	_box(Vector3(60, -0.55, 0), Vector3(23.95, 0.95, 21.95), Color("7a8290"), "stone")
	_box(Vector3(60, -0.04, 0), Vector3(23.9, 0.14, 21.9), Color("879b92"), "stone")
	# Uneven, low strata deepen the island edge without changing the walking height.
	for side in [-1, 1]:
		for i in range(12):
			var ledge := _box(Vector3(60 + side * 11.85, -0.58, -10.2 + i * 1.83), Vector3(0.65, 0.64, 1.46), Color("626d84"), "stone")
			ledge.rotation.y = side * (0.06 + float(i % 3) * 0.04)
		for i in range(13):
			_box(Vector3(49 + i * 1.82, -0.27, side * 10.9), Vector3(1.32, 0.48, 0.50), Color("a0a6a8"), "stone")
	# Retaining stones make the north gardens read as shallow steps, off the routes.
	for x in [55.0, 64.7, 69.5]:
		for tier in range(3):
			_box(Vector3(x, 0.10 + tier * 0.12, -10.25 - tier * 0.12), Vector3(2.0, 0.18, 0.55), Color("7a8093").lightened(tier * 0.06), "stone")
		obstacles.append(Rect2(x - 1.1, -10.8, 2.2, 1.0))


func _build_paths() -> void:
	_path(Rect2(59.1, -8.4, 1.8, 18.0))
	for z in [-6.5, -1.5, 4.0]:
		_path(Rect2(49.2, z - 0.65, 21.6, 1.3))
	_path(Rect2(55.3, 4.0, 1.4, 2.5))
	# Copper stitch plates mark the junctions without a sign blocking the traveller.
	for z in [-6.5, -1.5, 4.0, 8.0]:
		var tile := _box(Vector3(60, 0.086, z), Vector3(0.30, 0.025, 0.30), Color("d0ae7e"))
		tile.rotation.y = PI / 4


func _path(rect: Rect2) -> void:
	var center := rect.get_center()
	_box(Vector3(center.x, 0.043, center.y), Vector3(rect.size.x, 0.035, rect.size.y), Color("b1b7b8"), "stone")
	var across: bool = rect.size.x > rect.size.y
	var length: float = rect.size.x if across else rect.size.y
	for i in range(int(length / 0.82)):
		var p := Vector3(rect.position.x + 0.42 + i * 0.82, 0.071, center.y) if across else Vector3(center.x, 0.071, rect.position.y + 0.42 + i * 0.82)
		var size := Vector3(0.72, 0.025, rect.size.y * 0.86) if across else Vector3(rect.size.x * 0.86, 0.025, 0.72)
		var slab := _box(p, size, Color("cad0c8").darkened(float(i % 4) * 0.035))
		slab.rotation.y = 0.018 if i % 2 == 0 else -0.018


func _build_cottages() -> void:
	_cottage(Vector3(52.3, 0, -9.3), Vector3(4.3, 2.1, 2.4), Color("727e9c"))
	_cottage(Vector3(66.4, 0, -9.1), Vector3(4.6, 2.5, 2.7), Color("686f8b"))
	_cottage(Vector3(55.0, 0, -4.25), Vector3(4.0, 2.3, 2.9), Color("728b92"))
	_cottage(Vector3(50.0, 0, 8.0), Vector3(2.8, 2.0, 3.0), Color("737a95"))
	_cottage(Vector3(69.5, 0, 8.0), Vector3(3.0, 2.15, 2.8), Color("657f8b"))


func _cottage(pos: Vector3, size: Vector3, roof_color: Color) -> void:
	_box(pos + Vector3(0, 0.14, 0), Vector3(size.x + 0.35, 0.28, size.z + 0.3), Color("747b91"), "stone")
	_box(pos + Vector3(0, size.y * 0.5 + 0.13, 0), size, Color("c2bfb0"), "stone")
	for x in [-size.x * 0.5 + 0.12, size.x * 0.5 - 0.12]:
		_box(pos + Vector3(x, size.y * 0.5 + 0.15, size.z * 0.5 + 0.05), Vector3(0.17, size.y, 0.13), Color("596475"), "wood")
	for y in [0.45, size.y - 0.18]:
		_box(pos + Vector3(0, y, size.z * 0.5 + 0.07), Vector3(size.x, 0.12, 0.13), Color("889091"), "wood")
	for side in [-1, 1]:
		var roof := _box(pos + Vector3(0, size.y + 0.38, side * size.z * 0.28), Vector3(size.x + 0.64, 0.16, size.z * 0.68), roof_color, "wood")
		roof.rotation.x = side * 0.38
		for row in range(7):
			_box(pos + Vector3(-size.x * 0.5 + row * size.x / 6.0, size.y + 0.38, side * size.z * 0.28), Vector3(0.05, 0.09, size.z * 0.69), roof_color.lightened(0.15)).rotation.x = side * 0.38
		# Open roof gutters run along the eaves, with a dark inner trough.
		_box(pos + Vector3(0, size.y + 0.03, side * (size.z * 0.62)), Vector3(size.x + 0.76, 0.12, 0.24), Color("586678"), "wood")
		_box(pos + Vector3(0, size.y + 0.10, side * (size.z * 0.62)), Vector3(size.x + 0.56, 0.025, 0.12), Color("74aeb6"))
	_box(pos + Vector3(0, size.y + 0.75, 0), Vector3(size.x + 0.75, 0.13, 0.14), roof_color.lightened(0.2), "wood")
	_box(pos + Vector3(size.x * 0.48, size.y * 0.5 + 0.1, size.z * 0.63), Vector3(0.14, size.y, 0.16), Color("6d8391"))
	_box(pos + Vector3(0, 0.78, size.z * 0.5 + 0.09), Vector3(0.68, 1.30, 0.12), Color("556978"), "wood")
	for x in [-size.x * 0.29, size.x * 0.29]:
		_box(pos + Vector3(x, 1.25, size.z * 0.5 + 0.10), Vector3(0.64, 0.76, 0.14), Color("62687b"), "wood")
		var window := _box(pos + Vector3(x, 1.25, size.z * 0.5 + 0.18), Vector3(0.47, 0.57, 0.025), Color("f2ce91"))
		window.material_override = _world._mat(Color("f2ce91"), "", 0.5)
		_box(pos + Vector3(x, 1.25, size.z * 0.5 + 0.20), Vector3(0.045, 0.6, 0.03), Color("70768a"))
		_box(pos + Vector3(x, 1.25, size.z * 0.5 + 0.20), Vector3(0.5, 0.045, 0.03), Color("70768a"))
	obstacles.append(Rect2(pos.x - size.x * 0.5 - 0.2, pos.z - size.z * 0.5 - 0.2, size.x + 0.4, size.z + 0.4))


func _build_channels() -> void:
	_still_material = StandardMaterial3D.new()
	_still_material.albedo_color = Color("667383")
	_still_material.roughness = 0.95
	var channel_z: Array[float] = [-7.45, -2.5, 2.8]
	for i in range(MARKERS.size()):
		var marker: Dictionary = MARKERS[i]
		var role: String = marker.role
		var z: float = channel_z[i]
		_box(Vector3(60, 0.035, z), Vector3(21.4, 0.05, 0.55), Color("505c74"), "stone")
		for side in [-1, 1]:
			_box(Vector3(60, 0.14, z + side * 0.33), Vector3(21.4, 0.22, 0.12), Color("8792a6"), "stone")
		var water := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(21.2, 0.48)
		plane.subdivide_width = 8
		water.mesh = plane
		water.position = Vector3(60, 0.088, z)
		root_node.add_child(water)
		channel_water[role] = water
		var flow := ShaderMaterial.new()
		flow.shader = preload("res://shaders/water.gdshader")
		flow.set_shader_parameter("deep_color", Color("467caa"))
		_flow_materials[role] = flow
		# Each channel has a wide bridge on the main spine. The lips are blocked elsewhere.
		obstacles.append(Rect2(49.3, z - 0.38, 9.65, 0.76))
		obstacles.append(Rect2(61.05, z - 0.38, 9.65, 0.76))
		_bridge(Vector3(60, 0, z))
		_build_marker(marker)
	# The old cascade becomes the beacon's collection basin; its footprint stays fixed.
	_box(Vector3(60, 0.38, -9.9), Vector3(2.2, 0.7, 0.8), Color("69778d"), "stone")
	_box(Vector3(60, 0.77, -9.9), Vector3(1.75, 0.09, 0.65), Color("9bc8d5"))
	obstacles.append(Rect2(58.8, -10.4, 2.4, 1.0))


func _build_beacon() -> void:
	# Flush wet-stone rings are walkable; only the existing cascade blocks movement.
	for ring in range(2):
		for i in range(12):
			var angle: float = i * TAU / 12.0
			var radius: float = 0.79 + ring * 0.29
			var slab := _box(BEACON_POSITION + Vector3(cos(angle) * radius, 0.085, sin(angle) * radius), Vector3(0.32 + ring * 0.11, 0.055, 0.13), Color("a0adbb") if i % 2 else Color("71859b"), "stone")
			slab.rotation.y = -angle + PI / 2
	# A narrow six-sided rain collector fits inside the original basin collision.
	_cylinder(BEACON_POSITION + Vector3(0, 1.9, 0), 0.43, 2.7, Color("a6b4bd"), 6)
	for y in [0.7, 1.45, 2.2, 2.95]:
		_cylinder(BEACON_POSITION + Vector3(0, y, 0), 0.46, 0.13, Color("7786a0"), 6)
	for side in [-1, 1]:
		_box(BEACON_POSITION + Vector3(side * 0.31, 1.88, 0.20), Vector3(0.075, 2.55, 0.075), Color("b49a80"))
		for i in range(5):
			var louver := _box(BEACON_POSITION + Vector3(side * 0.25, 1.08 + i * 0.32, 0.35), Vector3(0.30, 0.055, 0.14), Color("6c7c91"))
			louver.rotation.x = -0.27
	_cylinder(BEACON_POSITION + Vector3(0, 3.25, 0), 0.78, 0.18, Color("7d8cab"), 6)
	_cylinder(BEACON_POSITION + Vector3(0, 3.35, 0), 0.66, 0.055, Color("a6c2cc"), 6)
	for i in range(6):
		var angle: float = i * TAU / 6.0
		_box(BEACON_POSITION + Vector3(cos(angle) * 0.59, 3.8, sin(angle) * 0.59), Vector3(0.085, 1.0, 0.085), Color("b59a81"))
	beacon_flame = _world._sphere(BEACON_POSITION + Vector3(0, 3.78, 0), 0.30, Color("596773"), root_node)
	_cylinder(BEACON_POSITION + Vector3(0, 4.28, 0), 0.78, 0.16, Color("8e95b7"), 6)
	var roof := CylinderMesh.new()
	roof.top_radius = 0.14
	roof.bottom_radius = 0.91
	roof.height = 0.70
	roof.radial_segments = 6
	var roof_node := MeshInstance3D.new()
	roof_node.mesh = roof
	roof_node.material_override = _world._mat(Color("7f89b0"), "roof")
	roof_node.position = BEACON_POSITION + Vector3(0, 4.66, 0)
	root_node.add_child(roof_node)
	_cylinder(BEACON_POSITION + Vector3(0, 5.07, 0), 0.17, 0.14, Color("cabba8"), 6)
	beacon_light = OmniLight3D.new()
	beacon_light.position = BEACON_POSITION + Vector3(0, 3.78, 0)
	beacon_light.light_color = Color("ffe4c3")
	beacon_light.light_energy = 0.8
	beacon_light.omni_range = 7.5
	root_node.add_child(beacon_light)
	# Reuse the world's existing lamp pulse; progress changes remain event-driven.
	_world.lamps.append(beacon_light)


func _bridge(pos: Vector3) -> void:
	for i in range(6):
		_box(pos + Vector3(0, 0.12, -0.65 + i * 0.26), Vector3(1.85, 0.13, 0.22), Color("9e9c9a"), "wood")
	for x in [-1.04, 1.04]:
		for z in [-0.72, 0.72]:
			_box(pos + Vector3(x, 0.40, z), Vector3(0.09, 0.75, 0.09), Color("637183"), "wood")
		_box(pos + Vector3(x, 0.68, 0), Vector3(0.09, 0.09, 1.6), Color("b9aaa0"), "wood")


func _build_marker(marker: Dictionary) -> void:
	var pos: Vector3 = marker.pos
	# A low pipe elbow keeps both the repair target and player sprite readable.
	_box(pos + Vector3(0, 0.12, 0), Vector3(0.85, 0.2, 0.65), Color("75849a"), "stone")
	for side in [-1, 1]:
		_box(pos + Vector3(side * 0.31, 0.39, 0), Vector3(0.20, 0.37, 0.55), Color("b1a28f"), "wood")
	_box(pos + Vector3(0, 0.28, 0), Vector3(0.52, 0.10, 0.55), Color("596e89"))
	var gem := _box(pos + Vector3(0, 0.46, 0.29), Vector3(0.18, 0.12, 0.18), Color("8b8290"))
	gem.rotation.y = PI / 4
	marker_gems[marker.role] = gem
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 0.70, 0)
	light.light_color = Color("9cdcea")
	light.light_energy = 0.55
	light.omni_range = 2.2
	root_node.add_child(light)
	marker_lights[marker.role] = light
	_world.npcs.append(marker.duplicate())


func _build_plants() -> void:
	for patch in PATCHES:
		var center := patch.get_center()
		_box(Vector3(center.x, 0.065, center.y), Vector3(patch.size.x, 0.035, patch.size.y), Color("597c83"), "grass")
		for x in range(int(patch.size.x / 0.38)):
			for z in range(int(patch.size.y / 0.40)):
				var pos := Vector3(patch.position.x + 0.20 + x * 0.38, 0.09, patch.position.y + 0.20 + z * 0.40)
				if not is_encounter_point(pos):
					continue
				var height: float = 0.18 + float((x * 3 + z) % 4) * 0.035
				_box(pos + Vector3(0, height * 0.5, 0), Vector3(0.055, height, 0.055), Color("4b6d75"))
				var leaf := _box(pos + Vector3(0, height, 0), Vector3(0.27, 0.045, 0.12), Color("99b8b5") if (x + z) % 3 else Color("b4acd0"))
				leaf.rotation.y = float((x + z) % 5) * 0.6
	# Decorative plant bowls never become invisible encounter ground.
	for pos in [Vector3(57.3, 0, 7.3), Vector3(69.9, 0, 0.4), Vector3(56.8, 0, -8.9), Vector3(49.5, 0, -4.8)]:
		_cylinder(pos + Vector3(0, 0.13, 0), 0.44, 0.25, Color("747c99"))
		for i in range(5):
			var leaf := _box(pos + Vector3(cos(i * 2.1) * 0.22, 0.36 + (i % 2) * 0.1, sin(i * 2.1) * 0.22), Vector3(0.42, 0.12, 0.16), Color("a5b5bf") if i % 2 else Color("7bafa5"))
			leaf.rotation.z = -0.3 + i * 0.13


func _build_ferries() -> void:
	# Both boats remain outboard, leaving the existing harbor approach untouched.
	for i in range(8):
		_world._box(Vector3(-14.6 - i * 0.29, 0.03, 3.9), Vector3(0.25, 0.15, 1.8), Color("aaa58d"), "wood")
	for x in [-14.7, -16.6]:
		_world._box(Vector3(x, 0.22, 4.85), Vector3(0.17, 0.85, 0.17), Color("62727c"), "wood")
	_boat(Vector3(-16.5, -0.30, 2.5), _world)
	var captain: Sprite3D = _world._person("rival", Vector3(-13.4, 0, 3))
	captain.modulate = Color("c0d7e1")
	_world.npcs.append({"role":"ferry_out", "name":"VENN / RAINSTEP FERRY", "pos":Vector3(-13.4, 0, 3), "sprite":captain, "island":"wakeharbor"})
	for i in range(9):
		_box(Vector3(60, 0.04, 9.6 + i * 0.36), Vector3(2.25, 0.17, 0.31), Color("949ca5"), "wood")
	for x in [58.85, 61.15]:
		for z in [10.2, 12.4]:
			_box(Vector3(x, 0.22, z), Vector3(0.15, 0.85, 0.15), Color("626d86"), "wood")
	_boat(Vector3(62.4, -0.30, 11.9), root_node)
	var rain_captain: Sprite3D = _world._person("rival", FERRY_POSITION)
	rain_captain.modulate = Color("c0d7e1")
	rain_captain.reparent(root_node)
	_world.npcs.append({"role":"ferry_home", "name":"VENN / RAINSTEP FERRY", "pos":FERRY_POSITION, "sprite":rain_captain, "island":"rainstep"})


func _boat(pos: Vector3, parent: Node3D) -> void:
	_world._box(pos, Vector3(1.35, 0.33, 2.55), Color("50677d"), "wood", parent)
	_world._box(pos + Vector3(0, 0.22, 0), Vector3(1.16, 0.12, 2.30), Color("b7aa89"), "wood", parent)
	for x in [-0.67, 0.67]:
		_world._box(pos + Vector3(x, 0.32, 0), Vector3(0.12, 0.37, 2.55), Color("798b97"), "wood", parent)
	for z in [-0.82, 0.65]:
		_world._box(pos + Vector3(0, 0.40, z), Vector3(1.24, 0.12, 0.31), Color("8c7564"), "wood", parent)
	var prow: MeshInstance3D = _world._box(pos + Vector3(0, 0.14, -1.32), Vector3(0.91, 0.29, 0.65), Color("657d91"), "wood", parent)
	prow.rotation.y = PI / 4
	var oar: MeshInstance3D = _world._box(pos + Vector3(0.95, 0.55, 0.3), Vector3(0.07, 0.07, 2.6), Color("c4b58d"), "wood", parent)
	oar.rotation.y = -0.35


func _build_keeper() -> void:
	var keeper: Sprite3D = _world._person("healer", KEEPER_POSITION)
	keeper.modulate = Color("d8d0e8")
	keeper.reparent(root_node)
	_world.npcs.append({"role":"rain_keeper", "name":"ORLA / WATERWORKS KEEPER", "pos":KEEPER_POSITION, "sprite":keeper, "island":"rainstep"})
	# A short workbench and spare slats establish a repair workshop beside Orla.
	_box(Vector3(54.8, 0.48, 6.25), Vector3(1.2, 0.15, 0.62), Color("aa9787"), "wood")
	for x in [54.35, 55.25]:
		_box(Vector3(x, 0.24, 6.25), Vector3(0.1, 0.48, 0.45), Color("657186"), "wood")
	for i in range(3):
		_box(Vector3(54.5 + i * 0.25, 0.59, 6.25), Vector3(0.14, 0.06, 0.50), Color("d2b893"))


func _build_challengers() -> void:
	var neri: Sprite3D = _world._person("rival", NERI_POSITION)
	neri.modulate = Color("e7c28e")
	neri.reparent(root_node)
	_world.npcs.append({"role":"challenge_rain_trial", "name":"NERI / CHANNEL CHALLENGER", "pos":NERI_POSITION, "sprite":neri, "island":"rainstep"})
	var ilya: Sprite3D = _world._person("keeper", ILYA_POSITION)
	ilya.modulate = Color("cfbee5")
	ilya.reparent(root_node)
	_world.npcs.append({"role":"challenge_second_light", "name":"ILYA / SECOND LIGHT KEEPER", "pos":ILYA_POSITION, "sprite":ilya, "island":"rainstep"})
	# A small badge beside Neri records the channel trial without obstructing the road.
	var post_position := NERI_POSITION + Vector3(0.65, 0, -0.35)
	_box(post_position + Vector3(0, 0.32, 0), Vector3(0.10, 0.64, 0.10), Color("7a8497"))
	_trial_badge = _box(post_position + Vector3(0, 0.68, 0), Vector3(0.24, 0.24, 0.12), Color("8b8290"))
	_trial_badge.rotation.z = PI / 4


func _build_lights() -> void:
	for pos in [Vector3(58.2, 0, 8.2), Vector3(61.7, 0, 4.1), Vector3(58.2, 0, -1.2), Vector3(61.7, 0, -6.3), Vector3(54.6, 0, 4.7)]:
		_world._lamp(pos, root_node)
	for light_data in [{"pos":Vector3(58, 3.5, -4.5), "color":Color("859bd9"), "range":12.0}, {"pos":Vector3(65, 2.8, 5.0), "color":Color("a798ca"), "range":10.0}]:
		var light := OmniLight3D.new()
		light.position = light_data.pos
		light.light_color = light_data.color
		light.light_energy = 0.48
		light.omni_range = light_data.range
		root_node.add_child(light)


func sync_progress(flags: Dictionary) -> void:
	for marker in MARKERS:
		var active: bool = bool(flags.get(marker.role, false))
		var water: MeshInstance3D = channel_water[marker.role]
		water.material_override = _flow_materials[marker.role] if active else _still_material
		var gem: MeshInstance3D = marker_gems[marker.role]
		gem.material_override = _world._mat(Color("a9dcea"), "", 0.85) if active else _world._mat(Color("8b8290"))
		var light: OmniLight3D = marker_lights[marker.role]
		light.visible = active
	var awakened: bool = bool(flags.get("rain_gym", false))
	beacon_light.visible = awakened
	beacon_flame.material_override = _world._mat(Color("ffe4c3"), "", 2.2) if awakened else _world._mat(Color("596773"))
	_trial_badge.material_override = _world._mat(Color("cde8f0"), "", 0.85) if bool(flags.get("rain_trial", false)) else _world._mat(Color("8b8290"))


func can_walk(pos: Vector3) -> bool:
	var point := Vector2(pos.x, pos.z)
	if not pos.is_finite() or not BOUNDS.grow(-SHORE_MARGIN).has_point(point):
		return false
	for rect in obstacles:
		if rect.grow(SHORE_MARGIN).has_point(point):
			return false
	return true


static func is_encounter_point(pos: Vector3) -> bool:
	var point := Vector2(pos.x, pos.z)
	var in_patch: bool = false
	for patch in PATCHES:
		if patch.has_point(point):
			in_patch = true
	if not in_patch:
		return false
	for marker in MARKERS:
		var marker_pos: Vector3 = marker.pos
		if point.distance_to(Vector2(marker_pos.x, marker_pos.z)) < 2.0:
			return false
	return point.distance_to(Vector2(KEEPER_POSITION.x, KEEPER_POSITION.z)) >= 2.0 and point.distance_to(Vector2(FERRY_POSITION.x, FERRY_POSITION.z)) >= 2.0
