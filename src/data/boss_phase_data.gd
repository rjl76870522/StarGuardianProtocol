class_name BossPhaseData
extends Resource

@export_range(0.0, 1.0, 0.01) var health_threshold: float = 1.0
@export var display_name: String
@export var move_speed: float = 2.0
@export var attack_interval: float = 1.5
@export var projectile_count: int = 1
@export var projectile_damage: float = 10.0
@export var abilities: Array[StringName] = []
@export var accent_color: Color = Color("ff5b2e")


func is_valid() -> bool:
	return health_threshold >= 0.0 and health_threshold <= 1.0 and not display_name.is_empty() and attack_interval > 0.0
