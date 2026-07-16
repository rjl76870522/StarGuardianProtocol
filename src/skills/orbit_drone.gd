class_name OrbitDrone
extends Node3D

@export var orbit_radius: float = 2.2
@export var orbit_speed: float = 1.8
@export var attack_interval: float = 0.9
@export var attack_range: float = 10.0
@export var damage: float = 7.0

var _angle: float = 0.0
var _slot: int = 0
var _total: int = 1
var _attack_cooldown: float = 0.2


func configure(slot: int, total: int, damage_multiplier: float = 1.0) -> void:
	_slot = maxi(slot, 0)
	_total = maxi(total, 1)
	_angle = TAU * float(_slot) / float(_total)
	damage = 7.0 * maxf(damage_multiplier, 1.0)


func _process(delta: float) -> void:
	_angle += orbit_speed * delta
	var phase := _angle + TAU * float(_slot) / float(_total)
	position = Vector3(cos(phase) * orbit_radius, 1.2, sin(phase) * orbit_radius)
	rotation.y = -phase
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	if _attack_cooldown <= 0.0:
		_attack_nearest()


func _attack_nearest() -> void:
	var target: Node3D
	var nearest_distance := attack_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D:
			continue
		var candidate_node := candidate as Node3D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance < nearest_distance:
			target = candidate_node
			nearest_distance = distance
	if target == null or not target.has_method("take_damage"):
		return
	_attack_cooldown = attack_interval
	target.take_damage(damage)
	var tween := create_tween()
	tween.tween_property($Core, "scale", Vector3.ONE * 1.8, 0.06)
	tween.tween_property($Core, "scale", Vector3.ONE, 0.12)
