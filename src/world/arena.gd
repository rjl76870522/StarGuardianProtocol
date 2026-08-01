extends Node3D

const WIDTH := 40.0
const DEPTH := 26.0
const ARENA_SCALE := 1.15
const OBSTACLE_LAYER := 16
const BOUNDARY_LAYER := 32

const MAP_NAMES := [
	"近地轨道平台",
	"日冕能源环",
	"量子交叉港",
	"冷星观测站",
	"失重航站",
	"星云补给带",
	"月面通信阵",
	"深空采矿区",
	"红移中继站",
	"极光防卫塔",
]

var map_seed: int = 1
var stage: int = 1
var variant: int = 0
var layout_signature: String = ""
var map_display_name: String = "近地轨道平台"
var _rng := RandomNumberGenerator.new()
var _floor_color := Color("152326")
var _grid_color := Color("294144")
var _accent_color := Color("35e6b2")
var boundary_points: Array[Vector2] = []


func _ready() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		map_seed = int(game_state.campaign_seed)
		stage = int(game_state.current_stage)
	_rng.seed = map_seed + stage * 104729
	variant = posmod(int(game_state.selected_zone) + stage - 1, MAP_NAMES.size()) if game_state != null else abs(map_seed + stage) % MAP_NAMES.size()
	map_display_name = MAP_NAMES[variant]
	_apply_palette()
	boundary_points.clear()
	for point in _boundary_for_variant():
		boundary_points.append(point * ARENA_SCALE)
	_create_floor()
	_create_bounds()
	_create_debris()
	_create_space_backdrop()
	_create_combat_interactables()


func _apply_palette() -> void:
	var palettes := [
		[Color("152326"), Color("294144"), Color("35e6b2")],
		[Color("201d25"), Color("46364d"), Color("ff5b72")],
		[Color("252316"), Color("4b4829"), Color("e8cf45")],
		[Color("15202a"), Color("29455b"), Color("55aaff")],
		[Color("29221f"), Color("51433c"), Color("ffae58")],
		[Color("1e2a24"), Color("3f5744"), Color("8fd784")],
		[Color("292b27"), Color("58574d"), Color("d8dcc8")],
		[Color("16222a"), Color("2d4d57"), Color("68d7ec")],
		[Color("2a1915"), Color("5a3228"), Color("ff7f4d")],
		[Color("101d2b"), Color("203d5f"), Color("a1d5ff")],
	]
	_floor_color = palettes[variant][0]
	_grid_color = palettes[variant][1]
	_accent_color = palettes[variant][2]


func _create_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(WIDTH, 0.3, DEPTH)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.2
	var material := StandardMaterial3D.new()
	material.albedo_color = _floor_color.darkened(0.28)
	material.metallic = 0.65
	material.roughness = 0.82
	material.emission_enabled = true
	material.emission = _floor_color.lightened(0.08)
	material.emission_energy_multiplier = 0.32
	mesh_instance.material_override = material
	floor_body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 0.3, DEPTH)
	collision.shape = shape
	collision.position.y = -0.2
	floor_body.add_child(collision)
	add_child(floor_body)
	_create_deck_polygon()

	var spacing := 2 if variant % 2 == 0 else 3
	for x in range(-19, 20, spacing):
		_create_strip(Vector3(float(x), 0.005, 0.0), Vector3(0.025, 0.01, DEPTH - 0.5), _grid_color)
	for z in range(-12, 13, spacing):
		_create_strip(Vector3(0.0, 0.006, float(z)), Vector3(WIDTH - 0.5, 0.01, 0.025), _grid_color)
	var accent_size := Vector3(0.055, 0.015, DEPTH - 0.5) if variant % 4 < 2 else Vector3(WIDTH - 0.5, 0.015, 0.055)
	_create_strip(Vector3.ZERO, accent_size, _accent_color)
	for index in boundary_points.size():
		var start := boundary_points[index]
		var finish := boundary_points[(index + 1) % boundary_points.size()]
		_create_boundary_light(start, finish)


func _create_deck_polygon() -> void:
	var deck := MeshInstance3D.new()
	deck.name = "SectorDeck"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1, boundary_points.size() - 1):
		var first := boundary_points[0]
		var second := boundary_points[index]
		var third := boundary_points[index + 1]
		mesh.surface_add_vertex(Vector3(first.x, 0.012, first.y))
		mesh.surface_add_vertex(Vector3(second.x, 0.012, second.y))
		mesh.surface_add_vertex(Vector3(third.x, 0.012, third.y))
	mesh.surface_end()
	deck.mesh = mesh
	deck.material_override = _tech_material(_floor_color, true)
	add_child(deck)


func _create_boundary_light(start: Vector2, finish: Vector2) -> void:
	var segment := finish - start
	var light := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(segment.length(), 0.035, 0.075)
	light.mesh = mesh
	light.position = Vector3((start.x + finish.x) * 0.5, 0.04, (start.y + finish.y) * 0.5)
	light.rotation.y = -atan2(segment.y, segment.x)
	var material := StandardMaterial3D.new()
	material.albedo_color = _accent_color
	material.emission_enabled = true
	material.emission = _accent_color
	material.emission_energy_multiplier = 4.0
	light.material_override = material
	add_child(light)


func _create_strip(position_value: Vector3, size: Vector3, color: Color) -> void:
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	line.mesh = mesh
	line.position = position_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 1.05
	line.material_override = material
	add_child(line)


func _create_bounds() -> void:
	for index in boundary_points.size():
		var start := boundary_points[index]
		var finish := boundary_points[(index + 1) % boundary_points.size()]
		var segment := finish - start
		var center := (start + finish) * 0.5
		_create_wall(
			Vector3(center.x, 0.8, center.y),
			Vector3(segment.length() + 0.45, 1.6, 0.7),
			-atan2(segment.y, segment.x)
		)


func _create_wall(at: Vector3, size: Vector3, rotation_y: float = 0.0) -> void:
	var body := StaticBody3D.new()
	# Perimeter walls are deliberately separate from internal cover. Phase rounds
	# may bypass cover but must never leave an irregular combat sector.
	body.collision_layer = BOUNDARY_LAYER
	body.position = at
	body.rotation.y = rotation_y
	body.add_to_group("obstacles")
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = _grid_color.darkened(0.22)
	material.metallic = 0.8
	material.roughness = 0.45
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _create_debris() -> void:
	var specs := _base_obstacle_specs()
	var extra_count := mini(stage / 2, 3)
	for extra_index in extra_count:
		specs.append(_random_obstacle_spec(specs))
	layout_signature = "%d:" % variant
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var size := spec["size"] as Vector3
		var debris := StaticBody3D.new()
		debris.name = "Obstacle%d" % index
		debris.collision_layer = OBSTACLE_LAYER
		debris.position = spec["position"] as Vector3
		debris.rotation.y = float(spec["rotation"])
		debris.add_to_group("obstacles")

		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		# Internal cover is intentionally rectangular. The visual mesh and the
		# BoxShape3D beneath it have identical dimensions, so movement and
		# reflected shots always match what is visible on screen.
		var block := BoxMesh.new()
		block.size = size
		var mesh: PrimitiveMesh = block
		visual.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = _grid_color.lightened(0.32)
		material.metallic = 0.55
		material.roughness = 0.58
		material.emission_enabled = true
		material.emission = _grid_color.lightened(0.08)
		material.emission_energy_multiplier = 0.34
		visual.material_override = material
		debris.add_child(visual)

		var collision := CollisionShape3D.new()
		collision.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		debris.add_child(collision)
		add_child(debris)
		layout_signature += "%.1f,%.1f,%.1f;" % [debris.position.x, debris.position.z, debris.rotation.y]


func _create_space_backdrop() -> void:
	# Non-colliding structures make each sector read as an orbital defence zone.
	_create_starfield()
	for side in [-1.0, 1.0]:
		for index in 5:
			var module := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			var height := _rng.randf_range(2.8, 7.5)
			mesh.size = Vector3(_rng.randf_range(1.0, 2.6), height, _rng.randf_range(0.8, 1.8))
			module.mesh = mesh
			module.position = Vector3(side * _rng.randf_range(18.5, 24.0), height * 0.5 - 0.1, _rng.randf_range(-13.0, 13.0))
			module.rotation.y = _rng.randf_range(-0.28, 0.28)
			module.material_override = _tech_material(Color("111c28").lightened(_rng.randf_range(0.0, 0.12)), true)
			add_child(module)
	for index in 6:
		_create_orbital_relay(index)


func _create_starfield() -> void:
	for index in 54:
		var star := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var radius := _rng.randf_range(0.025, 0.085)
		mesh.radius = radius
		mesh.height = radius * 2.0
		star.mesh = mesh
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(18.0, 31.0)
		star.position = Vector3(cos(angle) * distance, _rng.randf_range(1.5, 8.0), sin(angle) * distance)
		var starlight := Color("a8ddff") if index % 3 else _accent_color.lightened(0.28)
		star.material_override = _tech_material(starlight, true)
		add_child(star)


func _create_orbital_relay(index: int) -> void:
	var relay := Node3D.new()
	var angle := TAU * float(index) / 6.0 + 0.18
	var radius := 18.0 + float(index % 2) * 2.2
	relay.position = Vector3(cos(angle) * radius, 0.8, sin(angle) * radius)
	relay.rotation.y = -angle
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.22
	core_mesh.bottom_radius = 0.42
	core_mesh.height = 2.2
	core_mesh.radial_segments = 8
	core.mesh = core_mesh
	core.position.y = 1.1
	core.material_override = _tech_material(Color("23374d"), true)
	relay.add_child(core)
	for side in [-1.0, 1.0]:
		var panel := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(1.35, 0.07, 0.62)
		panel.mesh = panel_mesh
		panel.position = Vector3(side * 1.0, 1.25, 0.0)
		panel.material_override = _tech_material(_accent_color.darkened(0.35), true)
		relay.add_child(panel)
	add_child(relay)


func _create_combat_interactables() -> void:
	var barrel_count := 5 if variant == 1 or variant == 4 else 3
	for index in barrel_count:
		var barrel := ExplosiveBarrel.new()
		barrel.position = _safe_interactable_position(index, 5.0)
		add_child(barrel)
	for index in 3:
		var trap := WastelandTrap.new()
		trap.position = _safe_interactable_position(index + 8, 4.0)
		add_child(trap)


func _safe_interactable_position(index: int, minimum_distance: float) -> Vector3:
	var angle := TAU * float(index) / 6.0 + 0.42
	var point := Vector2(cos(angle) * (8.0 + float(index % 3) * 2.0), sin(angle) * 5.8)
	if not _is_inside_boundary(point):
		point *= 0.64
	return Vector3(point.x, 0.02, point.y)


func _tech_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.78
	material.roughness = 0.78
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.6
	return material


func _base_obstacle_specs() -> Array[Dictionary]:
	match variant:
		0:
			return [
				_spec(-10.5, -4.8, 4.8, 1.0, 0.8, 0.0),
				_spec(10.5, 4.8, 4.8, 1.0, 0.8, 0.0),
				_spec(-7.0, 5.5, 1.4, 2.4, 0.9, 0.45),
				_spec(7.0, -5.5, 1.4, 2.4, 0.9, 0.45),
			]
		1:
			return [
				_spec(-6.0, -4.6, 1.0, 7.4, 0.9, 0.0),
				_spec(6.0, 4.6, 1.0, 7.4, 0.9, 0.0),
				_spec(-11.0, 4.8, 2.8, 1.0, 0.7, 0.0),
				_spec(11.0, -4.8, 2.8, 1.0, 0.7, 0.0),
			]
		2:
			return [
				_spec(-8.0, 0.0, 5.0, 0.9, 0.8, 0.0),
				_spec(8.0, 0.0, 5.0, 0.9, 0.8, 0.0),
				_spec(0.0, -5.4, 0.9, 4.2, 0.8, 0.0),
				_spec(0.0, 5.4, 0.9, 4.2, 0.8, 0.0),
			]
		_:
			if variant == 4:
				return [
					_spec(-9.5, -4.5, 7.0, 0.8, 1.1, 0.1),
					_spec(9.5, 4.5, 7.0, 0.8, 1.1, -0.1),
					_spec(0.0, 0.0, 2.4, 2.4, 1.1, 0.78),
				]
			if variant == 5:
				return [
					_spec(-11.5, 0.0, 2.0, 1.2, 0.7, 0.25),
					_spec(11.5, 0.0, 2.0, 1.2, 0.7, -0.25),
					_spec(-2.0, -6.2, 1.6, 1.6, 0.8, 0.55),
					_spec(2.0, 6.2, 1.6, 1.6, 0.8, 0.55),
				]
			if variant == 6:
				return [
					_spec(-8.5, -4.6, 1.1, 4.6, 0.8, 0.08),
					_spec(-2.8, 4.6, 1.1, 4.6, 0.8, -0.08),
					_spec(2.8, -4.6, 1.1, 4.6, 0.8, 0.08),
					_spec(8.5, 4.6, 1.1, 4.6, 0.8, -0.08),
				]
			if variant == 7:
				return [
					_spec(-6.0, -4.5, 2.1, 2.1, 1.0, 0.3),
					_spec(6.0, -4.5, 2.1, 2.1, 1.0, -0.3),
					_spec(-6.0, 4.5, 2.1, 2.1, 1.0, -0.3),
					_spec(6.0, 4.5, 2.1, 2.1, 1.0, 0.3),
					_spec(0.0, 0.0, 1.4, 5.5, 1.0, 0.0),
				]
			return [
				_spec(-9.5, -5.2, 1.8, 1.8, 1.0, 0.2),
				_spec(9.5, -5.2, 1.8, 1.8, 1.0, -0.2),
				_spec(-9.5, 5.2, 1.8, 1.8, 1.0, -0.2),
				_spec(9.5, 5.2, 1.8, 1.8, 1.0, 0.2),
			]


func _random_obstacle_spec(existing_specs: Array[Dictionary]) -> Dictionary:
	for attempt in 60:
		var position := Vector3(_rng.randf_range(-13.0, 13.0), 0.42, _rng.randf_range(-7.8, 7.8))
		if not _is_inside_boundary(Vector2(position.x, position.z)):
			continue
		if Vector2(position.x, position.z).length() < 4.4:
			continue
		var valid := true
		for spec in existing_specs:
			var existing := spec["position"] as Vector3
			if position.distance_to(existing) < 3.2:
				valid = false
				break
		if valid:
			return _spec(
				position.x,
				position.z,
				_rng.randf_range(1.4, 2.5),
				_rng.randf_range(0.8, 1.4),
				_rng.randf_range(0.55, 1.0),
				_rng.randf_range(0.0, PI)
			)
	return _spec(12.0, 7.0, 1.5, 1.0, 0.7, 0.0)


func _spec(x: float, z: float, width: float, depth: float, height: float, rotation_y: float) -> Dictionary:
	# Player and enemy muzzles sit about one metre above the floor.  Internal
	# cover must clear that line or it looks solid while shots fly straight over it.
	var cover_height := maxf(height, 1.8)
	return {
		"position": Vector3(x, cover_height * 0.5, z),
		"size": Vector3(width, cover_height, depth),
		"rotation": rotation_y,
	}


func _boundary_for_variant() -> Array[Vector2]:
	match variant:
		0:
			return [Vector2(-14.0, -9.5), Vector2(10.5, -9.5), Vector2(15.8, -5.8), Vector2(15.8, 5.8), Vector2(10.5, 9.5), Vector2(-14.0, 9.5), Vector2(-15.8, 5.8), Vector2(-15.8, -5.8)]
		1:
			return [Vector2(-10.0, -9.2), Vector2(9.0, -9.2), Vector2(15.8, 0.0), Vector2(9.0, 9.2), Vector2(-10.0, 9.2), Vector2(-15.8, 0.0)]
		2:
			return [Vector2(0.0, -10.0), Vector2(15.8, 0.0), Vector2(0.0, 10.0), Vector2(-15.8, 0.0)]
		3:
			return [Vector2(-11.0, -9.5), Vector2(15.8, -7.2), Vector2(12.8, 9.5), Vector2(-15.8, 7.2)]
		4:
			return [Vector2(-13.5, -7.4), Vector2(1.5, -10.0), Vector2(15.8, -2.2), Vector2(10.2, 9.8), Vector2(-13.8, 8.6)]
		5:
			return [Vector2(-15.8, -7.8), Vector2(-5.0, -10.0), Vector2(15.8, -5.2), Vector2(15.8, 7.8), Vector2(5.0, 10.0), Vector2(-15.8, 5.2)]
		6:
			return [Vector2(-15.8, -9.6), Vector2(-4.0, -9.6), Vector2(-4.0, -4.2), Vector2(5.0, -4.2), Vector2(5.0, -9.6), Vector2(15.8, -9.6), Vector2(15.8, 9.6), Vector2(4.0, 9.6), Vector2(4.0, 4.2), Vector2(-5.0, 4.2), Vector2(-5.0, 9.6), Vector2(-15.8, 9.6)]
		7:
			return [Vector2(-15.8, -7.0), Vector2(11.0, -10.0), Vector2(15.8, 7.0), Vector2(-11.0, 10.0)]
		8:
			return [Vector2(-12.0, -9.8), Vector2(8.0, -9.8), Vector2(15.8, -4.0), Vector2(15.8, 4.0), Vector2(8.0, 9.8), Vector2(-12.0, 9.8), Vector2(-15.8, 4.0), Vector2(-15.8, -4.0)]
		_:
			return [Vector2(-15.8, -9.8), Vector2(15.8, 0.0), Vector2(-15.8, 9.8)]


func _is_inside_boundary(point: Vector2) -> bool:
	var inside := false
	var previous := boundary_points.size() - 1
	for index in boundary_points.size():
		var a := boundary_points[index]
		var b := boundary_points[previous]
		var delta_y := b.y - a.y
		if absf(delta_y) > 0.00001 and (a.y > point.y) != (b.y > point.y) and point.x < (b.x - a.x) * (point.y - a.y) / delta_y + a.x:
			inside = not inside
		previous = index
	return inside


func combat_spawn_position(rng: RandomNumberGenerator) -> Vector3:
	var edge := rng.randi_range(0, boundary_points.size() - 1)
	var start := boundary_points[edge]
	var finish := boundary_points[(edge + 1) % boundary_points.size()]
	var point := start.lerp(finish, rng.randf_range(0.16, 0.84)) * 0.9
	return Vector3(point.x, 0.65, point.y)


func keep_inside_combat_area(position_value: Vector3) -> Vector3:
	return confine_to_combat_area(position_value, 0.18)


func confine_to_combat_area(position_value: Vector3, margin: float = 0.36) -> Vector3:
	var point := Vector2(position_value.x, position_value.z)
	if _is_inside_boundary(point):
		return position_value
	var nearest := Vector2.ZERO
	var nearest_distance := INF
	for index in boundary_points.size():
		var start := boundary_points[index]
		var finish := boundary_points[(index + 1) % boundary_points.size()]
		var segment := finish - start
		var length_squared := segment.length_squared()
		if length_squared <= 0.0001:
			continue
		var progress := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
		var candidate := start + segment * progress
		var distance := point.distance_squared_to(candidate)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = candidate
	var center := Vector2.ZERO
	for vertex in boundary_points:
		center += vertex
	center /= maxf(float(boundary_points.size()), 1.0)
	var inward := (center - nearest).normalized()
	var corrected := nearest + inward * maxf(margin, 0.08)
	# Concave sectors can require more than one inward step. Interpolate toward
	# the polygon center until the corrected point is safely valid.
	for _attempt in 8:
		if _is_inside_boundary(corrected):
			return Vector3(corrected.x, position_value.y, corrected.y)
		corrected = corrected.lerp(center, 0.35)
	return Vector3(center.x, position_value.y, center.y)
