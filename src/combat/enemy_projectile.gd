extends Area3D

@export var speed: float = 13.0
@export var damage: float = 10.0
@export var lifetime: float = 4.0
var direction := Vector3.FORWARD


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(origin: Vector3, aim: Vector3, configured_damage: float, configured_speed: float) -> void:
	global_position = origin
	direction = Vector3(aim.x, 0.0, aim.z).normalized()
	damage = configured_damage
	speed = configured_speed


func _physics_process(delta: float) -> void:
	var start := global_position
	var destination := start + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(start, destination, collision_mask, [get_rid()])
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"] as Vector3
		_on_body_entered(hit["collider"] as Node3D)
		return
	global_position = destination
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if is_queued_for_deletion():
		return
	if body is WastelandPlayer:
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody3D:
		queue_free()
