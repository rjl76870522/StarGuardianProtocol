class_name MobileControls
extends CanvasLayer

const BUTTONS := [
	["上", &"move_forward", Vector2(92, -180)],
	["左", &"move_left", Vector2(22, -110)],
	["下", &"move_back", Vector2(92, -40)],
	["右", &"move_right", Vector2(162, -110)],
	["开火", &"shoot", Vector2(-160, -142)],
	["闪避", &"dash", Vector2(-252, -66)],
	["脉冲", &"pulse", Vector2(-68, -66)],
	["交互", &"interact", Vector2(-160, -48)],
	["强化", &"upgrade", Vector2(-252, -122)],
	["暂停", &"pause", Vector2(-78, -208), Vector2(68, 42)],
]

const REFERENCE_VIEWPORT := Vector2(1280, 720)
const CONTROL_TINT := Color(0.12, 0.64, 0.93, 0.9)


func _ready() -> void:
	if not OS.has_feature("mobile"):
		queue_free()
		return
	var root := Control.new()
	root.name = "MobileOverlay"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)
	var scale := _control_scale()
	for entry in BUTTONS:
		var size := entry[3] as Vector2 if entry.size() > 3 else Vector2(64, 54)
		_add_button(root, str(entry[0]), StringName(entry[1]), entry[2] as Vector2, size, scale)
	# Keep the five weapon slots separate on narrow phones. The previous 42px
	# spacing made their 64px buttons overlap and caused accidental switching.
	for index in 5:
		_add_button(root, str(index + 1), StringName("weapon_%d" % (index + 1)), Vector2(-276 + index * 56, -284), Vector2(52, 44), scale)
	_add_button(root, "震", &"weapon_6", Vector2(-344, -230), Vector2(58, 48), scale)
	_add_button(root, "燃", &"weapon_7", Vector2(-344, -174), Vector2(58, 48), scale)
	_add_button(root, "电", &"weapon_8", Vector2(-344, -118), Vector2(58, 48), scale)
	_add_button(root, "怒", &"active_fury", Vector2(-276, -338), Vector2(52, 42), scale)
	_add_button(root, "修", &"active_recovery", Vector2(-220, -338), Vector2(52, 42), scale)
	_add_button(root, "弹", &"active_bounce", Vector2(-164, -338), Vector2(52, 42), scale)
	_add_button(root, "锁", &"active_tracking", Vector2(-108, -338), Vector2(52, 42), scale)


func _control_scale() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return 1.0
	return clampf(minf(viewport_size.x / REFERENCE_VIEWPORT.x, viewport_size.y / REFERENCE_VIEWPORT.y), 0.82, 1.3)


func _add_button(root: Control, label: String, action: StringName, offset: Vector2, button_size: Vector2 = Vector2(64, 54), scale: float = 1.0) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = _action_hint(action)
	button.custom_minimum_size = button_size * scale
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT if offset.x < 0.0 else Control.PRESET_BOTTOM_LEFT)
	button.position = offset * scale
	button.modulate = CONTROL_TINT
	button.theme_override_font_sizes.font_size = roundi(15.0 * scale)
	button.focus_mode = Control.FOCUS_NONE
	button.button_down.connect(func() -> void: Input.action_press(action))
	button.button_up.connect(func() -> void: Input.action_release(action))
	button.tree_exiting.connect(func() -> void: Input.action_release(action))
	root.add_child(button)


func _action_hint(action: StringName) -> String:
	match action:
		&"weapon_6": return "震爆手雷"
		&"weapon_7": return "燃烧瓶"
		&"weapon_8": return "电磁脉冲"
		&"active_fury": return "暴怒回路"
		&"active_recovery": return "治疗协议"
		&"active_bounce": return "反弹校准"
		&"active_tracking": return "追踪校准"
		_: return str(action)
