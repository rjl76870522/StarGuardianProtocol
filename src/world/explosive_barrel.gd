class_name ExplosiveBarrel
extends Area3D

var health := 18.0
var detonated := false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.34
	mesh.bottom_radius = 0.42
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("102842")
	material.metallic = 0.9
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = Color("28c8ff")
	material.emission_energy_multiplier = 1.45
	mesh_instance.material_override = material
	add_child(mesh_instance)
	for height in [0.24, 0.76]:
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.46
		ring_mesh.bottom_radius = 0.46
		ring_mesh.height = 0.055
		ring_mesh.radial_segments = 16
		ring.mesh = ring_mesh
		ring.position.y = height
		var ring_material := StandardMaterial3D.new()
		ring_material.albedo_color = Color("7cecff")
		ring_material.emission_enabled = true
		ring_material.emission = Color("26b9ff")
		ring_material.emission_energy_multiplier = 3.1
		ring.material_override = ring_material
		add_child(ring)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.43
	shape.height = 1.0
	collision.shape = shape
	collision.position.y = 0.5
	add_child(collision)


func take_damage(amount: float) -> void:
	if detonated or amount <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		detonate()


func detonate() -> void:
	if detonated:
		return
	detonated = true
	for target in get_tree().get_nodes_in_group("enemies"):
		if target is Node3D and global_position.distance_to((target as Node3D).global_position) <= 4.2 and target.has_method("take_damage"):
			target.take_damage(46.0)
	var player := get_tree().get_first_node_in_group("player") as WastelandPlayer
	if player != null and global_position.distance_to(player.global_position) <= 3.6:
		player.take_damage(22.0)
	queue_free()
