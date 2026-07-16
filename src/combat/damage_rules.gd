class_name DamageRules
extends RefCounted


static func calculate(base_damage: float, multiplier: float = 1.0, armor: float = 0.0) -> float:
	if base_damage <= 0.0 or multiplier <= 0.0:
		return 0.0
	var mitigated := base_damage * multiplier - maxf(armor, 0.0)
	return maxf(mitigated, 1.0)

