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
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is WastelandPlayer:
		body.take_damage(damage)
		queue_free()
	elif body is StaticBody3D:
		queue_free()
