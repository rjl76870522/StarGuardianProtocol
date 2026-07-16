class_name SkillData
extends Resource

@export var skill_id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(1, 10, 1) var max_level: int = 3
@export var level_values: PackedFloat32Array = PackedFloat32Array([1.0])
@export var accent_color: Color = Color.WHITE


func is_valid() -> bool:
	return (
		not skill_id.is_empty()
		and not display_name.is_empty()
		and max_level > 0
		and level_values.size() >= max_level
	)


func value_for_level(level: int) -> float:
	if not is_valid() or level <= 0:
		return 0.0
	return level_values[clampi(level - 1, 0, level_values.size() - 1)]

