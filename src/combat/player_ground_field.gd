class_name PlayerGroundField
extends Node3D

var _gadget_id: StringName
var _radius := 4.0
var _damage := 20.0
var _color := Color.WHITE
var _label := ""
var _remaining := 5.0
var _tick_remaining := 0.0


func configure(gadget_id: StringName, at: Vector3, radius: float, damage: float, color: Color, label: String) -> void:
	_gadget_id = gadget_id
	_radius = radius
	_damage = damage
	_color = color
	_label = label
	_remaining = 6.0 if gadget_id == &"fire" else 5.0
	# configure() may run before this node is attached to the scene tree.
	position = at + Vector3.UP * 0.035


func _ready() -> void:
	var field := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = _radius
	mesh.bottom_radius = _radius * 0.84
	mesh.height = 0.06
	mesh.radial_segments = 40
	field.mesh = mesh
	field.material_override = _material(_color, 0.38)
	add_child(field)
	var label := Label3D.new()
	label.text = _label
	label.position = Vector3(0.0, 0.28, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.005
	label.font_size = 24
	label.outline_size = 6
	label.outline_modulate = Color(0.01, 0.015, 0.02, 0.9)
	label.modulate = _color.lightened(0.35)
	add_child(label)
	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 1.2
	light.omni_range = _radius * 1.7
	light.position.y = 0.4
	add_child(light)


func _process(delta: float) -> void:
	_remaining -= delta
	_tick_remaining -= delta
	if _tick_remaining <= 0.0:
		_tick_remaining = 0.55
		_apply_tick()
	if _remaining <= 0.0:
		queue_free()


func _apply_tick() -> void:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D:
			continue
		var enemy := candidate as Node3D
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		var distance := offset.length()
		if distance > _radius:
			continue
		var falloff := clampf(1.0 - distance / maxf(_radius * 1.2, 1.0), 0.3, 1.0)
		if enemy.has_method("take_damage"):
			enemy.take_damage(_damage * falloff)
		if _gadget_id == &"emp" and enemy.has_method("apply_slow"):
			enemy.apply_slow(0.48, 0.9)


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.6
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
