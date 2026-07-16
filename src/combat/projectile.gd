extends Area3D

@export var speed: float = 30.0
@export var damage: float = 18.0
@export var max_distance: float = 32.0

var direction: Vector3 = Vector3.FORWARD
var traveled: float = 0.0
var _hit_ids: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func launch(origin: Vector3, aim_direction: Vector3) -> void:
	global_position = origin
	direction = aim_direction.normalized()
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var start := global_position
	var destination := start + direction * step
	var query := PhysicsRayQueryParameters3D.create(
		start,
		destination,
		collision_mask,
		[get_rid()]
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"] as Vector3
		var collider := hit["collider"] as Node3D
		if collider != null:
			_apply_hit(collider)
		else:
			queue_free()
		return
	global_position = destination
	traveled += step
	if traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	_apply_hit(body)


func _apply_hit(body: Node3D) -> void:
	var body_id := body.get_instance_id()
	if _hit_ids.has(body_id):
		return
	_hit_ids[body_id] = true
	if body.has_method("take_damage"):
		body.take_damage(DamageRules.calculate(damage))
	queue_free()
