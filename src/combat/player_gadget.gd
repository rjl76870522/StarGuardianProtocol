class_name PlayerGadget
extends Node3D

const GROUND_FIELD := preload("res://src/combat/player_ground_field.gd")

var _gadget_id: StringName
var _origin := Vector3.ZERO
var _target := Vector3.ZERO
var _radius := 3.0
var _damage := 20.0
var _color := Color.WHITE
var _label := ""
var _travel_time := 0.34
var _elapsed := 0.0
var _resolved := false


func configure(gadget_id: StringName, origin: Vector3, target: Vector3, radius: float, damage: float, color: Color, label: String) -> void:
	_gadget_id = gadget_id
	_origin = origin
	_target = target
	_radius = radius
	_damage = damage
	_color = color
	_label = label
	# configure() is also used by tests before the node enters a scene tree.
	position = origin + Vector3.UP * 0.55


func _ready() -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22 if _gadget_id != &"fire" else 0.26
	mesh.height = mesh.radius * 2.0
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(_color, 3.0)
	add_child(mesh_node)
	var light := OmniLight3D.new()
	light.light_color = _color
	light.light_energy = 1.8
	light.omni_range = 3.2
	add_child(light)


func _process(delta: float) -> void:
	if _resolved:
		return
	_elapsed += delta
	var progress := clampf(_elapsed / _travel_time, 0.0, 1.0)
	var arc := sin(progress * PI) * 2.2
	global_position = _origin.lerp(_target, progress) + Vector3.UP * (0.55 + arc)
	rotation += Vector3(7.0, 10.0, 4.0) * delta
	if progress >= 1.0:
		_resolved = true
		_detonate()


func _detonate() -> void:
	global_position = _target + Vector3.UP * 0.08
	if _gadget_id == &"shock":
		_damage_enemies(_target, _radius, _damage, 15.0)
		_show_wave(_radius, 0.32)
		queue_free()
		return
	var scene_parent: Node = get_tree().current_scene
	if scene_parent == null:
		scene_parent = get_parent()
	if scene_parent == null:
		queue_free()
		return
	var field := GROUND_FIELD.new()
	field.configure(_gadget_id, _target, _radius, _damage, _color, _label)
	scene_parent.add_child(field)
	_show_wave(_radius, 0.24)
	queue_free()


func _damage_enemies(center: Vector3, radius: float, damage: float, knockback: float) -> void:
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D:
			continue
		var enemy := candidate as Node3D
		var offset := enemy.global_position - center
		offset.y = 0.0
		var distance := offset.length()
		if distance > radius:
			continue
		var falloff := clampf(1.0 - distance / maxf(radius * 1.15, 1.0), 0.35, 1.0)
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage * falloff)
		if knockback > 0.0 and enemy.has_method("apply_knockback") and distance > 0.04:
			enemy.apply_knockback(offset.normalized() * knockback * falloff)


func _show_wave(radius: float, lifetime: float) -> void:
	var wave := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.18
	mesh.outer_radius = 0.33
	wave.mesh = mesh
	wave.material_override = _material(_color, 4.0, 0.78)
	var scene_parent: Node = get_tree().current_scene
	if scene_parent == null:
		scene_parent = get_parent()
	if scene_parent == null:
		return
	scene_parent.add_child(wave)
	wave.global_position = _target + Vector3.UP * 0.12
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3.ONE * radius, lifetime)
	tween.tween_callback(wave.queue_free)


func _material(color: Color, emission: float, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	material.metallic = 0.5
	material.roughness = 0.25
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
