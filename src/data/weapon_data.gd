class_name WeaponData
extends Resource

@export var weapon_id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export_range(0.1, 500.0, 0.1) var damage: float = 10.0
@export_range(0.03, 5.0, 0.01) var fire_interval: float = 0.2
@export_range(1, 32, 1) var projectile_count: int = 1
@export_range(0.0, 90.0, 0.5) var spread_degrees: float = 0.0
@export_range(1.0, 100.0, 0.5) var projectile_speed: float = 30.0
@export_range(1.0, 100.0, 0.5) var projectile_range: float = 30.0
@export_range(0.0, 2.0, 0.01) var recoil: float = 0.05
@export_range(0.0, 1.0, 0.01) var critical_chance: float = 0.05
@export_range(1.0, 5.0, 0.1) var critical_multiplier: float = 2.0
@export_range(0, 10, 1) var base_penetration: int = 0
@export var status_effects: Array[StatusEffectData] = []
@export var vfx: WeaponVFXData
@export var sfx: WeaponAudioData


func is_valid() -> bool:
	if (
		weapon_id.is_empty()
		or display_name.is_empty()
		or damage <= 0.0
		or fire_interval <= 0.0
		or projectile_count <= 0
		or projectile_speed <= 0.0
		or projectile_range <= 0.0
		or critical_chance < 0.0
		or critical_chance > 1.0
		or critical_multiplier < 1.0
		or vfx == null
		or sfx == null
	):
		return false
	for effect in status_effects:
		if effect == null or not effect.is_valid():
			return false
	return true

