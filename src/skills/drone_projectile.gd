class_name DroneProjectile
extends Node3D

@export var speed: float = 25.0
@export var max_lifetime: float = 0.65

var damage: float = 7.0
var direction := Vector3.FORWARD
var _lifetime: float = 0.0


func launch(origin: Vector3, target_position: Vector3, configured_damage: float) -> void:
	global_position = origin
	damage = maxf(configured_damage, 0.0)
	direction = (target_position - origin).normalized()
	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	_lifetime += delta
	if _lifetime >= max_lifetime:
		queue_free()
		return
	var start := global_position
	var destination := start + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(start, destination, 20)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"] as Vector3
		var collider := hit["collider"] as Node3D
		if collider != null and collider.has_method("take_damage"):
			collider.take_damage(damage)
		queue_free()
		return
	global_position = destination
