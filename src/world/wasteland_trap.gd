class_name WastelandTrap
extends Area3D

var cooldown := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.82
	mesh.bottom_radius = 0.9
	mesh.height = 0.05
	mesh.radial_segments = 6
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("162553")
	material.metallic = 0.85
	material.roughness = 0.2
	material.emission_enabled = true
	material.emission = Color("4f8cff")
	material.emission_energy_multiplier = 1.15
	visual.material_override = material
	add_child(visual)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.19
	core_mesh.height = 0.38
	core.mesh = core_mesh
	core.position.y = 0.11
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color("b4d8ff")
	core_material.emission_enabled = true
	core_material.emission = Color("5798ff")
	core_material.emission_energy_multiplier = 3.2
	core.material_override = core_material
	add_child(core)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.88
	shape.height = 0.2
	collision.shape = shape
	collision.position.y = 0.05
	add_child(collision)


func _physics_process(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)
	if cooldown > 0.0:
		return
	for body in get_overlapping_bodies():
		if body is WastelandPlayer:
			body.take_damage(8.0)
			cooldown = 0.75
			return
		if body is ScrapChaser:
			body.take_damage(6.0)
			cooldown = 0.75
			return
