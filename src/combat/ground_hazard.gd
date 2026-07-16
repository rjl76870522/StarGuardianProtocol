extends Area3D

@export var damage: float = 8.0
@export var duration: float = 4.0
@export var tick_interval: float = 0.6
var _tick := 0.0


func _ready() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property($Mesh, "scale", Vector3(1.12, 1.0, 1.12), 0.35)
	tween.tween_property($Mesh, "scale", Vector3.ONE, 0.35)


func _physics_process(delta: float) -> void:
	duration -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = tick_interval
		for body in get_overlapping_bodies():
			if body is WastelandPlayer:
				body.take_damage(damage)
	if duration <= 0.0:
		queue_free()
