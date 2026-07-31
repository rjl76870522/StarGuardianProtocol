class_name WeaponRewardPanel
extends CanvasLayer

signal weapon_selected(weapon: WeaponData)

var _choices: Array[WeaponData] = []
@onready var overlay: Control = $Overlay
@onready var buttons: Array[Button] = [
	$Overlay/Panel/Content/Choices/Choice1,
	$Overlay/Panel/Content/Choices/Choice2,
	$Overlay/Panel/Content/Choices/Choice3,
]


func _ready() -> void:
	overlay.visible = false
	for index in buttons.size():
		buttons[index].pressed.connect(_choose.bind(index))


func show_rewards(weapons: Array[WeaponData]) -> void:
	_choices = weapons
	if _choices.size() < buttons.size():
		push_error("Weapon reward panel requires three weapon choices")
		return
	var state := get_node_or_null("/root/GameState")
	if state != null:
		$Overlay/Panel/Content/Subtitle.text = "选择后将随机进入第 %d 关战区。第一项强化当前武器，后两项可换取新武器类别" % (int(state.current_stage) + 1)
	for index in buttons.size():
		var weapon := _choices[index]
		var level := int(state.weapon_level(weapon.weapon_id)) if state != null else 0
		var unlocked := bool(state.is_weapon_unlocked(weapon.weapon_id)) if state != null else false
		var equipped := bool(state.has_weapon_in_loadout(weapon.weapon_id)) if state != null else false
		var action := "强化当前武器至 %d 级" % mini(level + 1, 20) if index == 0 else ("拾取后加入武器栏" if unlocked else "解锁并在下一关拾取")
		var bonus := int(maxi(level, 0) * 18)
		buttons[index].text = "%d   %s\n\n%s\n\n当前等级 %d  |  伤害加成 +%d%%\n%s" % [
			index + 1, weapon.display_name, weapon.description, level, bonus, action,
		]
	overlay.visible = true
	buttons[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not overlay.visible or not event.is_pressed():
		return
	if event.is_action("weapon_1"):
		_choose(0)
	elif event.is_action("weapon_2"):
		_choose(1)
	elif event.is_action("weapon_3"):
		_choose(2)


func _choose(index: int) -> void:
	if not overlay.visible or index < 0 or index >= _choices.size():
		return
	overlay.visible = false
	weapon_selected.emit(_choices[index])
