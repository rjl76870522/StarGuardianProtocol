class_name StatusEffectController
extends Node

var _active: Dictionary = {}
var _host: Node


func _ready() -> void:
	_host = get_parent()


func apply_effect(effect: StatusEffectData, source_direction: Vector3 = Vector3.ZERO) -> bool:
	if effect == null or not effect.is_valid():
		return false
	if randf() > effect.proc_chance:
		return false
	if effect.effect_type == StatusEffectData.EffectType.KNOCKBACK and _host.has_method("apply_knockback"):
		_host.apply_knockback(source_direction.normalized() * effect.knockback_strength)
	_active[effect.effect_id] = {
		"data": effect,
		"remaining": effect.duration,
		"tick": effect.tick_interval,
	}
	return true


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	var expired: Array[StringName] = []
	for effect_id: StringName in _active:
		var state: Dictionary = _active[effect_id]
		var effect := state["data"] as StatusEffectData
		state["remaining"] = float(state["remaining"]) - delta
		if effect.damage_per_tick > 0.0 and effect.tick_interval > 0.0:
			state["tick"] = float(state["tick"]) - delta
			while float(state["tick"]) <= 0.0 and float(state["remaining"]) >= 0.0:
				if _host.has_method("take_damage"):
					_host.take_damage(effect.damage_per_tick)
				state["tick"] = float(state["tick"]) + effect.tick_interval
		_active[effect_id] = state
		if float(state["remaining"]) <= 0.0:
			expired.append(effect_id)
	for effect_id in expired:
		_active.erase(effect_id)


func movement_multiplier() -> float:
	var multiplier := 1.0
	for state: Dictionary in _active.values():
		var effect := state["data"] as StatusEffectData
		if effect.effect_type == StatusEffectData.EffectType.FREEZE:
			return 0.0
		if effect.effect_type == StatusEffectData.EffectType.SLOW:
			multiplier = minf(multiplier, effect.speed_multiplier)
	return multiplier


func has_effect(effect_id: StringName) -> bool:
	return _active.has(effect_id)

