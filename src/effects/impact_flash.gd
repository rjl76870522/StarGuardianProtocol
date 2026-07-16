extends MeshInstance3D

@export var lifetime: float = 0.12


func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 2.6, lifetime)
	tween.tween_property(self, "transparency", 1.0, lifetime)
	tween.chain().tween_callback(queue_free)

