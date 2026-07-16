extends Node3D

const WIDTH := 34.0
const DEPTH := 22.0


func _ready() -> void:
	_create_floor()
	_create_bounds()
	_create_debris()


func _create_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(WIDTH, 0.3, DEPTH)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = -0.2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("152326")
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

	for x in range(-16, 17, 2):
		_create_strip(Vector3(float(x), 0.005, 0.0), Vector3(0.025, 0.01, DEPTH - 0.5), Color("294144"))
	for z in range(-10, 11, 2):
		_create_strip(Vector3(0.0, 0.006, float(z)), Vector3(WIDTH - 0.5, 0.01, 0.025), Color("294144"))
	_create_strip(Vector3.ZERO, Vector3(0.055, 0.015, DEPTH - 0.5), Color("35e6b2"))


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
	var positions := [
		Vector3(-12.0, 0.35, -7.4), Vector3(11.5, 0.28, 7.6),
		Vector3(-13.5, 0.22, 6.8), Vector3(13.0, 0.3, -7.1),
	]
	for index in positions.size():
		var debris := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.4 + index * 0.12, 0.45, 0.75)
		debris.mesh = mesh
		debris.position = positions[index]
		debris.rotation.y = 0.35 + index * 0.7
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("5b4631")
		material.metallic = 0.55
		material.roughness = 0.9
		debris.material_override = material
		add_child(debris)

