class_name MobileControls
extends CanvasLayer

const BUTTONS := [
	["▲", &"move_forward", Vector2(92, -180)],
	["◀", &"move_left", Vector2(22, -110)],
	["▼", &"move_back", Vector2(92, -40)],
	["▶", &"move_right", Vector2(162, -110)],
	["开火", &"shoot", Vector2(-160, -142)],
	["闪避", &"dash", Vector2(-252, -66)],
	["脉冲", &"pulse", Vector2(-68, -66)],
	["交互", &"interact", Vector2(-160, -48)],
	["强化", &"upgrade", Vector2(-252, -122)],
]


func _ready() -> void:
	if not OS.has_feature("mobile"):
		queue_free()
		return
	var root := Control.new()
	root.name = "MobileOverlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	for entry in BUTTONS:
		_add_button(root, str(entry[0]), StringName(entry[1]), entry[2] as Vector2)
	for index in 5:
		_add_button(root, str(index + 1), StringName("weapon_%d" % (index + 1)), Vector2(-140 + index * 42, -214))
	_add_button(root, "震", &"weapon_6", Vector2(-286, -192))
	_add_button(root, "燃", &"weapon_7", Vector2(-286, -132))
	_add_button(root, "电", &"weapon_8", Vector2(-286, -72))


func _add_button(root: Control, label: String, action: StringName, offset: Vector2) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(64, 54)
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if offset.x < 0.0 else Control.PRESET_BOTTOM_LEFT)
	button.position = offset
	button.modulate = Color(0.78, 0.98, 0.88, 0.86)
	button.theme_override_font_sizes.font_size = 15
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	button.tree_exiting.connect(func() -> void: Input.action_release(action))
	root.add_child(button)
