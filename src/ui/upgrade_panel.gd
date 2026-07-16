class_name UpgradePanel
extends CanvasLayer

signal skill_selected(skill: SkillData)

var _choices: Array[SkillData] = []
var _skill_system: SkillSystem

@onready var overlay: Control = $Overlay
@onready var buttons: Array[Button] = [
	$Overlay/Panel/Content/Choices/Choice1,
	$Overlay/Panel/Content/Choices/Choice2,
	$Overlay/Panel/Content/Choices/Choice3,
]


func _ready() -> void:
	for index in buttons.size():
		buttons[index].pressed.connect(_choose.bind(index))
	overlay.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not overlay.visible or not event.is_pressed():
		return
	if event.is_action("weapon_1"):
		_choose(0)
	elif event.is_action("weapon_2"):
		_choose(1)
	elif event.is_action("weapon_3"):
		_choose(2)


func show_choices(choices: Array[SkillData], skill_system: SkillSystem) -> void:
	_choices = choices
	_skill_system = skill_system
	for index in buttons.size():
		var button := buttons[index]
		button.visible = index < _choices.size()
		if index >= _choices.size():
			continue
		var skill := _choices[index]
		var current_level := _skill_system.get_level(skill.skill_id)
		var next_level := current_level + 1
		var level_marks := ""
		for level in skill.max_level:
			level_marks += "■" if level < next_level else "□"
		button.text = "%d   %s\n%s  升级后等级 %d / %d\n\n%s\n\n%s  →  %s" % [
			index + 1,
			skill.display_name,
			level_marks,
			next_level,
			skill.max_level,
			skill.description,
			_format_value(skill, current_level),
			_format_value(skill, next_level),
		]
	overlay.visible = true
	if not _choices.is_empty():
		buttons[0].grab_focus()


func close() -> void:
	overlay.visible = false
	_choices.clear()


func _choose(index: int) -> void:
	if not overlay.visible or index < 0 or index >= _choices.size():
		return
	var skill := _choices[index]
	if not _skill_system.can_upgrade(skill):
		return
	close()
	skill_selected.emit(skill)


func _format_value(skill: SkillData, level: int) -> String:
	if level <= 0:
		return "未启用"
	var value := skill.value_for_level(level)
	match skill.skill_id:
		&"rapid_fire", &"move_speed":
			return "+%d%%" % int(round((value - 1.0) * 100.0))
		&"combat_core":
			return "+%d%% 伤害" % int(round((value - 1.0) * 100.0))
		&"critical_matrix":
			return "+%d%% 暴击" % int(round(value * 100.0))
		&"armor_plating":
			return "+%d 最大生命" % int(value)
		&"ricochet":
			return "弹射 %d 次" % int(value)
		&"penetration":
			return "穿透 %d 个" % int(value)
		&"kill_heal":
			return "每次恢复 %d" % int(value)
		&"orbit_drone":
			return "%d 台无人机" % int(value)
	return "%.2f" % value
