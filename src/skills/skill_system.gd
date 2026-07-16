class_name SkillSystem
extends RefCounted

var _levels: Dictionary = {}
var _data: Dictionary = {}


func get_level(skill_id: StringName) -> int:
	return int(_levels.get(skill_id, 0))


func can_upgrade(skill: SkillData) -> bool:
	return skill != null and skill.is_valid() and get_level(skill.skill_id) < skill.max_level


func apply_upgrade(skill: SkillData) -> bool:
	if not can_upgrade(skill):
		return false
	var next_level := get_level(skill.skill_id) + 1
	_levels[skill.skill_id] = next_level
	_data[skill.skill_id] = skill
	return true


func get_value(skill_id: StringName, fallback: float = 0.0) -> float:
	var skill := _data.get(skill_id) as SkillData
	if skill == null:
		return fallback
	return skill.value_for_level(get_level(skill_id))


func available_choices(catalog: Array[SkillData], count: int, rng: RandomNumberGenerator) -> Array[SkillData]:
	var available: Array[SkillData] = []
	for skill in catalog:
		if can_upgrade(skill):
			available.append(skill)
	for index in range(available.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary := available[index]
		available[index] = available[swap_index]
		available[swap_index] = temporary
	return available.slice(0, mini(count, available.size()))

