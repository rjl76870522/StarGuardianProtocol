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
		var next_level := _skill_system.get_level(skill.skill_id) + 1
		button.text = "%d   %s\nLEVEL %d / %d\n%s\nNEXT  %.2f" % [
			index + 1,
			skill.display_name,
			next_level,
			skill.max_level,
			skill.description,
			skill.value_for_level(next_level),
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
	close()
	skill_selected.emit(skill)

