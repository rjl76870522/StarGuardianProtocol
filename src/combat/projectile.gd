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
	global_position += direction * step
	traveled += step
	if traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	var body_id := body.get_instance_id()
	if _hit_ids.has(body_id):
		return
	_hit_ids[body_id] = true
	if body.has_method("take_damage"):
		body.take_damage(DamageRules.calculate(damage))
	queue_free()

