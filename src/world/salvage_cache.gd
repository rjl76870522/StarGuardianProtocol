class_name SalvageCache
extends Area3D

signal collected(scrap_amount: int, heal_amount: float)

var scrap_amount: int = 2
var heal_amount: float = 14.0
var armor_charge: float = 0.0
var _collected := false
var _visual: Node3D
var _core: MeshInstance3D
var _beacon: OmniLight3D
var _elapsed := 0.0
var _recall_target: WastelandPlayer
var _recall_start := Vector3.ZERO
var _recall_elapsed := 0.0


func _ready() -> void:
	add_to_group("salvage_caches")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)

	_visual = Node3D.new()
	_visual.name = "RareSalvageCore"
	_visual.position.y = 0.18
	add_child(_visual)
	_build_resource_core()

	_beacon = OmniLight3D.new()
	_beacon.name = "Beacon"
	_beacon.light_color = Color("68eaff")
	_beacon.light_energy = 2.1
	_beacon.omni_range = 4.5
	_beacon.position.y = 0.8
	add_child(_beacon)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	collision.shape = shape
	collision.position.y = 0.62
	add_child(collision)


func _build_resource_core() -> void:
	_add_mesh(CylinderMesh.new(), Vector3(0.0, 0.08, 0.0), Vector3.ONE, Color("102c5d"), false, 0.0, Vector2(0.42, 0.5))
	_add_mesh(CylinderMesh.new(), Vector3(0.0, 0.18, 0.0), Vector3.ONE, Color("267fc1"), true, 1.1, Vector2(0.3, 0.4))
	_core = _add_mesh(SphereMesh.new(), Vector3(0.0, 0.47, 0.0), Vector3(0.25, 0.25, 0.25), Color("c6fbff"), true, 4.2)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var bracket := _add_mesh(BoxMesh.new(), Vector3(cos(angle) * 0.34, 0.38, sin(angle) * 0.34), Vector3(0.14, 0.22, 0.14), Color("49d7ff"), true, 1.8)
		bracket.rotation.y = angle
	for height in [0.28, 0.72]:
		var ring := _add_mesh(CylinderMesh.new(), Vector3(0.0, height, 0.0), Vector3.ONE, Color("61e8ff"), true, 2.4, Vector2(0.38, 0.055))
		ring.rotation.y = PI * 0.25
	var beam := _add_mesh(CylinderMesh.new(), Vector3(0.0, 1.05, 0.0), Vector3.ONE, Color(0.22, 0.9, 1.0, 0.32), true, 0.75, Vector2(0.055, 0.95))
	beam.name = "SignalBeam"
	var label := Label3D.new()
	label.text = "资源舱"
	label.position = Vector3(0.0, 1.58, 0.0)
	label.font_size = 40
	label.outline_size = 6
	label.modulate = Color("baf7ff")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visual.add_child(label)


func _add_mesh(mesh: PrimitiveMesh, position_value: Vector3, scale_value: Vector3, color: Color, emissive: bool, energy: float = 0.0, cylinder_shape: Vector2 = Vector2.ZERO) -> MeshInstance3D:
	if mesh is CylinderMesh and cylinder_shape != Vector2.ZERO:
		mesh.top_radius = cylinder_shape.x
		mesh.bottom_radius = cylinder_shape.x
		mesh.height = cylinder_shape.y
		mesh.radial_segments = 16
	if mesh is SphereMesh:
		mesh.radial_segments = 20
		mesh.rings = 12
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = position_value
	part.scale = scale_value
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.72
	material.roughness = 0.2
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = energy
	part.material_override = material
	_visual.add_child(part)
	return part


func _process(delta: float) -> void:
	if _collected:
		return
	if is_instance_valid(_recall_target):
		_recall_elapsed += delta
		var progress := clampf(_recall_elapsed / 0.62, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		global_position = _recall_start.lerp(_recall_target.global_position + Vector3.UP * 0.55, eased)
		_visual.scale = Vector3.ONE * lerpf(1.0, 0.28, eased)
		if progress >= 1.0:
			collect(_recall_target, false)
		return
	_elapsed += delta
	_visual.position.y = 0.18 + sin(_elapsed * 2.0) * 0.08
	_visual.rotation.y += delta * 0.7
	if _core != null:
		var pulse := 1.0 + sin(_elapsed * 4.0) * 0.14
		_core.scale = Vector3.ONE * 0.25 * pulse
	if _beacon != null:
		_beacon.light_energy = 1.8 + sin(_elapsed * 3.0) * 0.45


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body is WastelandPlayer:
		return
	collect(body as WastelandPlayer)


func collect(player: WastelandPlayer, restore_health: bool = true) -> bool:
	if _collected or player == null:
		return false
	_collected = true
	if restore_health:
		player.restore_health(heal_amount)
	if restore_health and armor_charge > 0.0:
		player.apply_zone_support(armor_charge, 0.0)
		player.action_message.emit("获得护甲芯片，最大生命 +%d" % int(armor_charge))
	collected.emit(scrap_amount, heal_amount if restore_health else 0.0)
	queue_free()
	return true


func recall_to(player: WastelandPlayer) -> void:
	if _collected or player == null:
		return
	_recall_target = player
	_recall_start = global_position
	_recall_elapsed = 0.0
	monitoring = false
	collision_layer = 0
	collision_mask = 0
