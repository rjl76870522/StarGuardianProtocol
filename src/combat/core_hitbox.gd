class_name EnemyCoreHitbox
extends Area3D

@export var damage_multiplier: float = 2.0


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	var enemy := get_parent()
	if enemy != null and enemy.has_method("take_damage"):
		enemy.take_damage(amount * damage_multiplier)


func apply_status_effect(effect: StatusEffectData, source_direction: Vector3 = Vector3.ZERO) -> bool:
	var enemy := get_parent()
	if enemy != null and enemy.has_method("apply_status_effect"):
		return enemy.apply_status_effect(effect, source_direction)
	return false
