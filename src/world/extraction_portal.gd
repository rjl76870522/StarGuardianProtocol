class_name ExtractionPortal
extends Area3D

signal entered(player: WastelandPlayer)

var _elapsed := 0.0
var _used := false


func _ready() -> void:
	name = "ExtractionPortal"
	add_to_group("combat_interactables")
	collision_layer = 0
	collision_mask = 0
	_build_visuals()


func _process(delta: float) -> void:
	_elapsed += delta
	rotation.y += delta * 0.7
	var beacon := get_node_or_null("Beacon") as OmniLight3D
	if beacon != null:
		beacon.light_energy = 2.4 + sin(_elapsed * 4.0) * 0.75


func interaction_text(_inventory_full: bool = false) -> String:
	return "F  穿过螺旋撤离门，进入下一关"


func interact(player: WastelandPlayer) -> void:
	if _used or player == null:
		return
	_used = true
	entered.emit(player)


func _build_visuals() -> void:
	for index in 3:
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.68 + index * 0.11
		mesh.outer_radius = 0.77 + index * 0.11
		mesh.rings = 24
		mesh.ring_segments = 10
		ring.mesh = mesh
		ring.position = Vector3(0.0, 1.05, 0.0)
		ring.rotation = Vector3(PI * 0.5 + index * 0.18, index * 0.8, 0.0)
		var material := StandardMaterial3D.new()
		var tint: Color = [Color("68eaff"), Color("8f7bff"), Color("c9f8ff")][index]
		material.albedo_color = tint
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 3.6
		ring.material_override = material
		add_child(ring)
	var core := MeshInstance3D.new()
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.42
	core_mesh.bottom_radius = 0.42
	core_mesh.height = 2.15
	core.mesh = core_mesh
	core.position.y = 1.05
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(0.28, 0.82, 1.0, 0.16)
	core_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_material.emission_enabled = true
	core_material.emission = Color("54dfff")
	core_material.emission_energy_multiplier = 1.6
	core.material_override = core_material
	add_child(core)
	var label := Label3D.new()
	label.text = "撤离门\n按 F 进入下一关"
	label.position = Vector3(0.0, 2.55, 0.0)
	label.font_size = 38
	label.outline_size = 7
	label.modulate = Color("d4fbff")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	var beacon := OmniLight3D.new()
	beacon.name = "Beacon"
	beacon.light_color = Color("5ee8ff")
	beacon.light_energy = 2.8
	beacon.omni_range = 7.5
	beacon.position.y = 1.1
	add_child(beacon)
