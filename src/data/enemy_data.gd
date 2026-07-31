class_name EnemyData
extends Resource

enum Archetype { CHASER, SHOOTER, BOMBER, HEAVY, REPAIR, MAGE }

@export var enemy_id: StringName
@export var display_name: String
@export var archetype: Archetype = Archetype.CHASER
@export var max_health: float = 24.0
@export var move_speed: float = 2.4
@export var contact_damage: float = 8.0
@export var attack_range: float = 1.55
@export var attack_interval: float = 0.95
@export var projectile_speed: float = 13.0
@export var repair_amount: float = 8.0
@export var detection_range: float = 24.0
@export var body_color: Color = Color("853322")
@export var core_color: Color = Color("ff5b2e")
@export var scale_multiplier: float = 1.0
@export var elite: bool = false
@export var teleport_on_hit: bool = false
@export var leaves_hazard: bool = false
@export var role_summary: String = ""


func is_valid() -> bool:
	return (
		not enemy_id.is_empty()
		and not display_name.is_empty()
		and max_health > 0.0
		and move_speed >= 0.0
		and attack_range > 0.0
		and attack_interval > 0.0
	)
