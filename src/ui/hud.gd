class_name WastelandHUD
extends CanvasLayer

var _salvage_hint_tween: Tween
var _combat_dock: Control
var _dock_header: Label
var _status_cards: Array[Panel] = []
var _weapon_status: Label
var _gadget_status: Label
var _skill_status: Label
var _upgrade_status: Label
var _dash_status: Label
var _controls_status: Label
var _interaction_banner: Label


func _ready() -> void:
	# The original bottom bar was a child of Margin. Some desktop backends lay
	# out its bottom anchor before the first usable viewport size, leaving all
	# tactical information outside the visible screen. The combat dock is a
	# direct CanvasLayer child and is sized after every viewport change.
	_create_combat_dock()
	get_viewport().size_changed.connect(_layout_tactical_bar)
	call_deferred("_layout_tactical_bar")


func _layout_tactical_bar() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var dock_width := maxf(720.0, viewport_size.x - 40.0)
	_combat_dock.position = Vector2(20.0, viewport_size.y - 142.0)
	_combat_dock.size = Vector2(dock_width, 126.0)
	_layout_status_cards()
	_interaction_banner.position = Vector2(0.0, viewport_size.y - 177.0)
	_interaction_banner.size = Vector2(viewport_size.x, 30.0)


func _create_combat_dock() -> void:
	$Margin/BottomPanel.hide()
	$Margin/BottomBar.hide()
	_combat_dock = Control.new()
	_combat_dock.name = "CombatDock"
	_combat_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_dock.z_index = 100
	add_child(_combat_dock)

	var backdrop := Panel.new()
	backdrop.name = "Backdrop"
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_theme_stylebox_override("panel", _panel_style(Color(0.006, 0.026, 0.075, 0.96), Color(0.2, 0.72, 1.0, 0.95), 10))
	_combat_dock.add_child(backdrop)

	_dock_header = Label.new()
	_dock_header.name = "DockHeader"
	_dock_header.text = "战术终端  ·  武器与行动状态"
	_dock_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_header.add_theme_font_size_override("font_size", 13)
	_dock_header.add_theme_color_override("font_color", Color("9ce8ff"))
	_combat_dock.add_child(_dock_header)

	_weapon_status = _add_status_card("WeaponCard", "当前武器", "1  等待武器数据")
	_gadget_status = _add_status_card("GadgetCard", "投掷装备", "6 震爆  ·  7 燃烧  ·  8 电磁")
	_skill_status = _add_status_card("SkillCard", "人物技能", "T 暴怒  ·  G 修复\nY 反弹  ·  H 锁定")
	_upgrade_status = _add_status_card("UpgradeCard", "武器强化", "击毁敌人后\n按 E 选择强化")
	_dash_status = _add_status_card("DashCard", "机动", "空格  闪避就绪")

	_controls_status = Label.new()
	_controls_status.name = "ControlsStatus"
	_controls_status.text = "1-5 切换武器  ·  F 交互  ·  鼠标瞄准与攻击"
	_controls_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls_status.add_theme_font_size_override("font_size", 12)
	_controls_status.add_theme_color_override("font_color", Color(0.62, 0.82, 0.98, 1.0))
	_combat_dock.add_child(_controls_status)

	_interaction_banner = Label.new()
	_interaction_banner.name = "InteractionBanner"
	_interaction_banner.visible = false
	_interaction_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_interaction_banner.add_theme_font_size_override("font_size", 16)
	_interaction_banner.add_theme_color_override("font_color", Color("c4f4ff"))
	_interaction_banner.add_theme_color_override("font_outline_color", Color(0.0, 0.05, 0.12, 0.95))
	_interaction_banner.add_theme_constant_override("outline_size", 6)
	_interaction_banner.z_index = 101
	add_child(_interaction_banner)
	call_deferred("_layout_tactical_bar")


func _add_status_card(node_name: String, title: String, value: String) -> Label:
	var card := Panel.new()
	card.name = node_name
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.09, 0.17, 0.9), Color(0.16, 0.48, 0.78, 0.82), 6))
	_combat_dock.add_child(card)
	_status_cards.append(card)
	var title_label := Label.new()
	title_label.name = "Title"
	title_label.text = title
	title_label.position = Vector2(9.0, 5.0)
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", Color(0.43, 0.72, 0.94, 1.0))
	card.add_child(title_label)
	var value_label := Label.new()
	value_label.name = "Value"
	value_label.text = value
	value_label.position = Vector2(9.0, 24.0)
	value_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	value_label.clip_text = true
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color(0.86, 0.95, 1.0, 1.0))
	card.add_child(value_label)
	return value_label


func _layout_status_cards() -> void:
	if _combat_dock == null:
		return
	_dock_header.position = Vector2(10.0, 4.0)
	_dock_header.size = Vector2(_combat_dock.size.x - 20.0, 19.0)
	var gap := 8.0
	var side_margin := 10.0
	var card_width := maxf(130.0, (_combat_dock.size.x - side_margin * 2.0 - gap * 4.0) / 5.0)
	for index in _status_cards.size():
		var card := _status_cards[index]
		card.position = Vector2(side_margin + index * (card_width + gap), 27.0)
		card.size = Vector2(card_width, 70.0)
		var title := card.get_node("Title") as Label
		var value := card.get_node("Value") as Label
		title.size = Vector2(card_width - 18.0, 17.0)
		value.size = Vector2(card_width - 18.0, 42.0)
	_controls_status.position = Vector2(12.0, 101.0)
	_controls_status.size = Vector2(_combat_dock.size.x - 24.0, 19.0)


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.content_margin_left = 10.0
	style.content_margin_top = 5.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 5.0
	return style


func set_health(current: float, maximum: float) -> void:
	$Margin/TopBar/HealthPanel/HealthContent/HealthBar.max_value = maximum
	$Margin/TopBar/HealthPanel/HealthContent/HealthBar.value = current
	$Margin/TopBar/HealthPanel/HealthContent/HealthText.text = "%03d / %03d" % [current, maximum]


func set_time(seconds_left: float) -> void:
	var total := maxi(0, int(ceil(seconds_left)))
	$Margin/TopBar/TimerPanel/Timer.text = "%02d:%02d" % [total / 60, total % 60]


func set_stage(stage: int, map_name: String = "") -> void:
	$Margin/TopBar/StagePanel/Stage.text = "第 %d 关\n%s" % [stage, map_name] if not map_name.is_empty() else "第 %d 关" % stage


func set_kills(value: int, target: int = 0) -> void:
	if target > 0:
		$Margin/TopBar/KillPanel/Kills.text = "击毁  %03d / %03d" % [value, target]
	else:
		$Margin/TopBar/KillPanel/Kills.text = "击毁  %03d" % value


func set_dash_ready(ready: bool) -> void:
	_dash_status.text = "空格  闪避就绪" if ready else "空格  闪避充能中"
	_dash_status.modulate = Color("8edfff") if ready else Color("6689a8")


func set_weapon(weapon: WeaponData, index: int) -> void:
	if weapon == null:
		return
	var state := get_node_or_null("/root/GameState")
	var level := int(state.weapon_level(weapon.weapon_id)) if state != null else 1
	_weapon_status.text = "%d  %s\n%d级  ·  单发 %d" % [index + 1, weapon.display_name, level, weapon.damage]


func set_skill(skill: SkillData, level: int) -> void:
	var suffix := "  已满级" if level >= skill.max_level else "  等级 %d" % level
	_upgrade_status.text = skill.display_name + suffix


func show_all_skills_maxed() -> void:
	_upgrade_status.text = "全部强化已满级"
	_upgrade_status.modulate = Color.WHITE


func show_upgrade_ready() -> void:
	_upgrade_status.text = "强化模块就绪\n按 E 选择"
	_upgrade_status.modulate = Color("9ce8ff")


func clear_upgrade_ready() -> void:
	_upgrade_status.text = "强化模块待获取\n击毁敌人充能"
	_upgrade_status.modulate = Color.WHITE


func show_boss(current: float, maximum: float, phase_name: String = "") -> void:
	$Margin/BossBar.visible = true
	$Margin/BossBar/Health.max_value = maximum
	$Margin/BossBar/Health.value = current
	if not phase_name.is_empty():
		$Margin/BossBar/BossName.text = "异星母舰  |  %s" % phase_name


func hide_boss() -> void:
	$Margin/BossBar.visible = false


func show_message(title: String, subtitle: String) -> void:
	# Combat notices must never cover the action. Route all transient notices to
	# the small edge toast and keep the former center overlay disabled.
	$CenterMessage.visible = false
	show_salvage_hint("%s  ·  %s" % [title, subtitle.replace("\n", "  ")])


func hide_message() -> void:
	$CenterMessage.visible = false


func set_active_skill_levels(fury: int, recovery: int, bounce: int, tracking: int) -> void:
	_skill_status.text = "T 暴怒 L%d  ·  G 修复 L%d\nY 反弹 L%d  ·  H 锁定 L%d" % [fury, recovery, bounce, tracking]


func set_interaction_hint(message: String) -> void:
	_interaction_banner.text = message
	_interaction_banner.visible = not message.is_empty()


func show_salvage_hint(message: String) -> void:
	var label: Label = $Margin/SalvageHint
	if is_instance_valid(_salvage_hint_tween):
		_salvage_hint_tween.kill()
	label.text = message
	label.modulate = Color(0.65, 0.88, 1.0, 0.92)
	label.visible = true
	_salvage_hint_tween = create_tween()
	_salvage_hint_tween.tween_interval(0.72)
	_salvage_hint_tween.tween_property(label, "modulate:a", 0.0, 0.22)
	_salvage_hint_tween.tween_callback(func() -> void: label.visible = false)
