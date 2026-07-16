extends Node3D

const WIDTH := 34.0
const DEPTH := 22.0

var map_seed: int = 1
var stage: int = 1
var variant: int = 0
var layout_signature: String = ""
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
	variant = abs(map_seed + stage) % 4
	_apply_palette()
	_create_floor()
	_create_bounds()
	_create_debris()


func _apply_palette() -> void:
	var palettes := [
		[Color("152326"), Color("294144"), Color("35e6b2")],
		[Color("201d25"), Color("46364d"), Color("ff5b72")],
		[Color("252316"), Color("4b4829"), Color("e8cf45")],
		[Color("15202a"), Color("29455b"), Color("55aaff")],
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
	var accent_size := Vector3(0.055, 0.015, DEPTH - 0.5) if variant < 2 else Vector3(WIDTH - 0.5, 0.015, 0.055)
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
	body.collision_layer = 1
	body.position = at
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
	var positions: Array[Vector3] = []
	var obstacle_count := 4 + mini(stage / 2, 3)
	var attempts := 0
	while positions.size() < obstacle_count and attempts < 100:
		attempts += 1
		var candidate := Vector3(_rng.randf_range(-14.0, 14.0), 0.3, _rng.randf_range(-8.0, 8.0))
		if Vector2(candidate.x, candidate.z).length() < 4.2:
			continue
		var valid := true
		for existing in positions:
			if candidate.distance_to(existing) < 3.2:
				valid = false
				break
		if valid:
			positions.append(candidate)
	layout_signature = "%d:" % variant
	for index in positions.size():
		var size := Vector3(_rng.randf_range(1.2, 2.4), _rng.randf_range(0.4, 0.9), _rng.randf_range(0.65, 1.25))
		var debris := StaticBody3D.new()
		debris.name = "Debris%d" % index
		debris.collision_layer = 1
		debris.position = positions[index]
		debris.rotation.y = _rng.randf_range(0.0, PI)
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
		layout_signature += "%.1f,%.1f;" % [debris.position.x, debris.position.z]
