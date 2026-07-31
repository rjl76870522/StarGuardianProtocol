extends Node3D

const WIDTH := 34.0
const DEPTH := 22.0
const OBSTACLE_LAYER := 16

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


func _ready() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		map_seed = int(game_state.campaign_seed)
		stage = int(game_state.current_stage)
	_rng.seed = map_seed + stage * 104729
	variant = posmod(int(game_state.selected_zone) + stage - 1, MAP_NAMES.size()) if game_state != null else abs(map_seed + stage) % MAP_NAMES.size()
	map_display_name = MAP_NAMES[variant]
	_apply_palette()
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
	material.albedo_color = _floor_color
	material.metallic = 0.65
	material.roughness = 0.82
	mesh_instance.material_override = material
	floor_body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, 0.3, DEPTH)
	collision.shape = shape
	collision.position.y = -0.2
	floor_body.add_child(collision)
	add_child(floor_body)

	var spacing := 2 if variant % 2 == 0 else 3
	for x in range(-16, 17, spacing):
		_create_strip(Vector3(float(x), 0.005, 0.0), Vector3(0.025, 0.01, DEPTH - 0.5), _grid_color)
	for z in range(-10, 11, spacing):
		_create_strip(Vector3(0.0, 0.006, float(z)), Vector3(WIDTH - 0.5, 0.01, 0.025), _grid_color)
	var accent_size := Vector3(0.055, 0.015, DEPTH - 0.5) if variant % 4 < 2 else Vector3(WIDTH - 0.5, 0.015, 0.055)
	_create_strip(Vector3.ZERO, accent_size, _accent_color)


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
	material.emission_energy_multiplier = 0.35
	line.material_override = material
	add_child(line)


func _create_bounds() -> void:
	_create_wall(Vector3(0.0, 0.8, -DEPTH * 0.5), Vector3(WIDTH + 1.0, 1.6, 0.7))
	_create_wall(Vector3(0.0, 0.8, DEPTH * 0.5), Vector3(WIDTH + 1.0, 1.6, 0.7))
	_create_wall(Vector3(-WIDTH * 0.5, 0.8, 0.0), Vector3(0.7, 1.6, DEPTH + 1.0))
	_create_wall(Vector3(WIDTH * 0.5, 0.8, 0.0), Vector3(0.7, 1.6, DEPTH + 1.0))


func _create_wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = OBSTACLE_LAYER
	body.position = at
	body.add_to_group("obstacles")
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("25383a")
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
		var mesh := BoxMesh.new()
		mesh.size = size
		visual.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = _grid_color.lightened(0.18)
		material.metallic = 0.55
		material.roughness = 0.9
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
	for index in 8:
		var wreck := MeshInstance3D.new()
		var wreck_mesh := CylinderMesh.new()
		wreck_mesh.top_radius = 0.22
		wreck_mesh.bottom_radius = 0.45
		wreck_mesh.height = _rng.randf_range(1.2, 2.8)
		wreck.mesh = wreck_mesh
		wreck.position = Vector3(_rng.randf_range(-15.6, 15.6), 0.28, _rng.randf_range(-9.6, 9.6))
		wreck.rotation = Vector3(0.0, _rng.randf_range(0.0, TAU), _rng.randf_range(-0.55, 0.55))
		wreck.material_override = _tech_material(_grid_color.darkened(0.35), true)
		add_child(wreck)
	var tower := MeshInstance3D.new()
	var tower_mesh := CylinderMesh.new()
	tower_mesh.top_radius = 0.18
	tower_mesh.bottom_radius = 0.38
	tower_mesh.height = 8.5
	tower.mesh = tower_mesh
	tower.position = Vector3(-15.7, 4.25, -9.5)
	tower.material_override = _tech_material(_accent_color.darkened(0.35), true)
	add_child(tower)


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
	return Vector3(cos(angle) * (8.0 + float(index % 3) * 2.0), 0.02, sin(angle) * 5.8)


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
