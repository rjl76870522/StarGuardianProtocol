class_name StatusEffectData
extends Resource

enum EffectType { BURN, FREEZE, SLOW, KNOCKBACK }

@export var effect_id: StringName
@export var display_name: String
@export var effect_type: EffectType = EffectType.BURN
@export_range(0.0, 20.0, 0.05) var duration: float = 1.0
@export_range(0.0, 5.0, 0.05) var tick_interval: float = 0.5
@export_range(0.0, 100.0, 0.5) var damage_per_tick: float = 0.0
@export_range(0.0, 1.0, 0.05) var speed_multiplier: float = 1.0
@export_range(0.0, 40.0, 0.5) var knockback_strength: float = 0.0
@export_range(0.0, 1.0, 0.01) var proc_chance: float = 1.0
@export var tint: Color = Color.WHITE


func is_valid() -> bool:
	return (
		not effect_id.is_empty()
		and not display_name.is_empty()
		and duration >= 0.0
		and tick_interval >= 0.0
		and speed_multiplier >= 0.0
		and proc_chance >= 0.0
		and proc_chance <= 1.0
	)

