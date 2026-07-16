class_name DamageRules
extends RefCounted


static func calculate(base_damage: float, multiplier: float = 1.0, armor: float = 0.0) -> float:
	if base_damage <= 0.0 or multiplier <= 0.0:
		return 0.0
	var mitigated := base_damage * multiplier - maxf(armor, 0.0)
	return maxf(mitigated, 1.0)


static func calculate_hit(
	base_damage: float,
	multiplier: float = 1.0,
	armor: float = 0.0,
	critical_chance: float = 0.0,
	critical_multiplier: float = 2.0,
	roll: float = 1.0
) -> Dictionary:
	if base_damage <= 0.0 or multiplier <= 0.0 or critical_multiplier < 1.0:
		return {"damage": 0.0, "critical": false}
	var critical := clampf(critical_chance, 0.0, 1.0) > clampf(roll, 0.0, 1.0)
	var hit_multiplier := multiplier * (critical_multiplier if critical else 1.0)
	return {
		"damage": calculate(base_damage, hit_multiplier, armor),
		"critical": critical,
	}
