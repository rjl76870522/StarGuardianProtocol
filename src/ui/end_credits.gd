class_name EndCredits
extends Control

signal finished

var _elapsed := 0.0
var _can_skip := false
var _closing := false
var _scroll: ScrollContainer
var _scroll_contents: VBoxContainer
var _skip_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_view()


func _process(delta: float) -> void:
	if _closing:
		return
	_elapsed += delta
	if _elapsed >= 5.0 and not _can_skip:
		_can_skip = true
		_skip_label.text = "按任意键或点击跳过"
		_skip_label.modulate.a = 1.0
	if _elapsed >= 2.0 and _scroll != null:
		var distance := maxf(float(_scroll.get_v_scroll_bar().max_value), 0.0)
		_scroll.scroll_vertical = int(minf(distance, (_elapsed - 2.0) * 31.0))
	if _elapsed >= 25.0:
		_finish()


func _unhandled_input(event: InputEvent) -> void:
	if not _can_skip or _closing:
		return
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		_finish()
	elif event is InputEventMouseButton and event.is_pressed():
		_finish()


func _build_view() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("020716")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var scan_lines := ColorRect.new()
	scan_lines.color = Color(0.05, 0.45, 0.9, 0.14)
	scan_lines.set_anchors_preset(Control.PRESET_TOP_WIDE)
	scan_lines.offset_top = 84.0
	scan_lines.offset_bottom = 87.0
	add_child(scan_lines)

	var title := Label.new()
	title.text = "星 域 校 准 完 成"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 68.0
	title.offset_bottom = 108.0
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("a8eaff"))
	add_child(title)

	var emblem := Label.new()
	emblem.text = "◈"
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.set_anchors_preset(Control.PRESET_TOP_WIDE)
	emblem.offset_top = 112.0
	emblem.offset_bottom = 190.0
	emblem.add_theme_font_size_override("font_size", 72)
	emblem.add_theme_color_override("font_color", Color("47d7ff"))
	add_child(emblem)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(0.0, 210.0)
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 220.0
	_scroll.offset_right = -220.0
	_scroll.offset_bottom = -78.0
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll)
	_scroll_contents = VBoxContainer.new()
	_scroll_contents.custom_minimum_size = Vector2(0.0, 1260.0)
	_scroll_contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_contents.alignment = BoxContainer.ALIGNMENT_CENTER
	_scroll_contents.add_theme_constant_override("separation", 22)
	_scroll.add_child(_scroll_contents)
	_add_credit("FINAL MISSION LOG", 19, Color("55dfff"))
	_add_credit("第十星区已肃清\n轨道防线恢复稳定\n异星母舰核心已静默", 25, Color("e5f7ff"))
	_add_credit("", 12, Color.WHITE)
	_add_credit("致每一位守望者", 25, Color("75deff"))
	_add_credit("愿你在每一次混乱来临时\n仍然记得看见方向、保护同伴、完成自己的航程", 20, Color("b9d8e9"))
	_add_credit("", 12, Color.WHITE)
	_add_credit("CAMPAIGN RECORD", 19, Color("55dfff"))
	_add_credit("十个随机星区\n八种可部署武器\n多职业异星单位\n持续成长的守望者", 20, Color("e5f7ff"))
	_add_credit("", 12, Color.WHITE)
	_add_credit("感谢测试与支持", 25, Color("75deff"))
	_add_credit("每一次反馈都让防线更可靠\n每一次出击都值得被记录", 20, Color("b9d8e9"))
	_add_credit("", 12, Color.WHITE)
	_add_credit("STAR GUARDIAN PROTOCOL", 22, Color("a8eaff"))
	_add_credit("深空守望仍在继续", 18, Color("5ea7ca"))

	_skip_label = Label.new()
	_skip_label.text = "结局记录加载中"
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_skip_label.offset_top = -58.0
	_skip_label.offset_bottom = -30.0
	_skip_label.add_theme_font_size_override("font_size", 15)
	_skip_label.add_theme_color_override("font_color", Color("62b9da"))
	_skip_label.modulate.a = 0.74
	add_child(_skip_label)


func _add_credit(contents: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = contents
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_scroll_contents.add_child(label)


func _finish() -> void:
	if _closing:
		return
	_closing = true
	finished.emit()
