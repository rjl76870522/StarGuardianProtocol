extends Control

const ZONES := ["近地轨道平台", "日冕能源环", "量子交叉港", "冷星观测站", "失重航站", "星云补给带", "月面通信阵", "深空采矿区", "红移中继站", "极光防卫塔", "磁暴前哨", "天穹研究站", "星环货运港", "彗尾观测站", "静海浮岛", "银河栖息区", "虚空接驳站", "蓝移船坞", "极夜补给站", "天琴防御链", "裂隙巡航区", "曙光通讯塔", "星尘反应堆", "终焉守望台"]
const START_WEAPONS: Array[Dictionary] = [
	{"id": &"flame_projector", "name": "喷火器"},
	{"id": &"auto_rifle", "name": "自动步枪"},
	{"id": &"scatter_cannon", "name": "霰弹炮"},
	{"id": &"rail_lance", "name": "轨道枪"},
	{"id": &"arc_blade", "name": "电弧刃"},
	{"id": &"sidearm", "name": "脉冲手枪"},
	{"id": &"sniper_rifle", "name": "狙击步枪"},
	{"id": &"siege_cannon", "name": "攻城火炮"},
]

var _archive_dialog: AcceptDialog
var _skill_dialog: AcceptDialog
var _statistics_dialog: AcceptDialog
var _audio_dialog: AcceptDialog
var _skill_status: Label
var _skill_buttons: Dictionary = {}
var _skill_notice := ""


func _ready() -> void:
	SaveManager.apply_profile(GameState)
	_build_starfield()
	$Layout/Panel/Buttons/StartButton.grab_focus()
	_refresh_continue_button()
	_refresh_camp()
	_create_archive_dialog()
	_create_skill_dialog()
	_create_statistics_dialog()
	_create_audio_dialog()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _on_continue_pressed() -> void:
	if GameState.continue_campaign():
		get_tree().change_scene_to_file("res://scenes/game.tscn")
	else:
		_refresh_continue_button()


func _on_zone_pressed() -> void:
	var selected_index := 0
	for index in START_WEAPONS.size():
		if START_WEAPONS[index]["id"] == GameState.selected_start_weapon_id:
			selected_index = index
			break
	GameState.selected_start_weapon_id = START_WEAPONS[posmod(selected_index + 1, START_WEAPONS.size())]["id"]
	GameState._autosave()
	_refresh_camp()


func _on_upgrade_pressed() -> void:
	if GameState.upgrade_starter_weapon():
		_refresh_camp("初始武器已升级")
	else:
		_refresh_camp("合金不足")


func _on_garden_pressed() -> void:
	if GameState.upgrade_health_system():
		_refresh_camp("初始生命已提升")
	else:
		_refresh_camp("合金不足")


func _on_skin_pressed() -> void:
	var skins: Array = GameState.PLAYABLE_SKINS
	var current := skins.find(GameState.equipped_skin)
	GameState.equipped_skin = skins[posmod(current + 1, skins.size())]
	GameState.unlock_achievement(&"first_skin_change")
	GameState._autosave()
	_refresh_camp("外观已切换")


func _on_archive_pressed() -> void:
	if _archive_dialog == null:
		_create_archive_dialog()
	_archive_dialog.popup_centered(Vector2i(820, 590))


func _on_skills_pressed() -> void:
	if _skill_dialog == null:
		_create_skill_dialog()
	_refresh_skill_dialog()
	_skill_dialog.popup_centered(Vector2i(720, 610))


func _on_statistics_pressed() -> void:
	if _statistics_dialog == null:
		_create_statistics_dialog()
	_refresh_statistics_dialog()
	_statistics_dialog.popup_centered(Vector2i(560, 430))


func _on_audio_pressed() -> void:
	if _audio_dialog == null:
		_create_audio_dialog()
	_refresh_audio_dialog()
	_audio_dialog.popup_centered(Vector2i(520, 320))


func _dialog_style(dialog: AcceptDialog) -> void:
	dialog.add_theme_color_override("title_color", Color("9eeaff"))
	dialog.add_theme_color_override("font_color", Color("d9f4ff"))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("06172d")
	panel_style.border_color = Color("2fb9ed")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	dialog.add_theme_stylebox_override("panel", panel_style)
	dialog.ok_button_text = "关闭"


func _create_statistics_dialog() -> void:
	if _statistics_dialog != null:
		return
	_statistics_dialog = AcceptDialog.new()
	_statistics_dialog.title = "本地作战统计"
	_dialog_style(_statistics_dialog)
	_statistics_dialog.min_size = Vector2i(520, 390)
	add_child(_statistics_dialog)
	var contents := RichTextLabel.new()
	contents.name = "Contents"
	contents.bbcode_enabled = true
	contents.fit_content = false
	contents.scroll_active = false
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.offset_left = 28.0
	contents.offset_top = 20.0
	contents.offset_right = -28.0
	contents.offset_bottom = -58.0
	_statistics_dialog.add_child(contents)


func _refresh_statistics_dialog() -> void:
	if _statistics_dialog == null:
		return
	var contents := _statistics_dialog.get_node_or_null("Contents") as RichTextLabel
	if contents == null:
		return
	var completed := GameState.achievement_count()
	var total := GameState.ACHIEVEMENT_IDS.size()
	var progress := int(round(float(completed) / float(maxi(total, 1)) * 100.0))
	var favorite := _start_weapon_name(GameState.favorite_weapon_id())
	var favorite_uses := GameState.favorite_weapon_uses()
	contents.clear()
	contents.append_text("[center][font_size=24][color=#55dfff]本地作战统计[/color][/font_size]\n[color=#8edfff]数据仅保存在当前电脑，不会上传网络[/color][/center]\n\n[font_size=20]最高关卡[/font_size]  [color=#d9f4ff]第 %d / %d 关[/color]\n\n[font_size=20]总击毁[/font_size]  [color=#d9f4ff]%d[/color]\n\n[font_size=20]常用武器[/font_size]  [color=#d9f4ff]%s[/color]  [color=#8edfff]累计开火 %d 次[/color]\n\n[font_size=20]成就完成度[/font_size]  [color=#d9f4ff]%d / %d[/color]  [color=#8edfff]%d%%[/color]\n\n[color=#6fa9c9]累计部署 %d 次[/color]" % [GameState.highest_stage, GameState.MAX_STAGE, GameState.total_kills, favorite, favorite_uses, completed, total, progress, GameState.total_runs])


func _create_audio_dialog() -> void:
	if _audio_dialog != null:
		return
	_audio_dialog = AcceptDialog.new()
	_audio_dialog.title = "声音设置"
	_dialog_style(_audio_dialog)
	_audio_dialog.min_size = Vector2i(480, 280)
	add_child(_audio_dialog)
	var layout := VBoxContainer.new()
	layout.name = "AudioLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 28.0
	layout.offset_top = 18.0
	layout.offset_right = -28.0
	layout.offset_bottom = -58.0
	layout.add_theme_constant_override("separation", 14)
	_audio_dialog.add_child(layout)
	var title := Label.new()
	title.text = "主音量"
	title.add_theme_color_override("font_color", Color("bcefff"))
	layout.add_child(title)
	var volume := HSlider.new()
	volume.name = "VolumeSlider"
	volume.min_value = 0.0
	volume.max_value = 100.0
	volume.step = 1.0
	volume.custom_minimum_size = Vector2(0.0, 30.0)
	volume.value_changed.connect(_on_volume_changed)
	layout.add_child(volume)
	var value_label := Label.new()
	value_label.name = "VolumeValue"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", Color("8edfff"))
	layout.add_child(value_label)
	var mute := CheckBox.new()
	mute.name = "MuteToggle"
	mute.text = "静音"
	mute.add_theme_color_override("font_color", Color("d9f4ff"))
	mute.toggled.connect(_on_audio_muted)
	layout.add_child(mute)
	var hint := Label.new()
	hint.text = "此设置会控制战斗音效，并自动保存到本机"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color("6fa9c9"))
	layout.add_child(hint)


func _refresh_audio_dialog() -> void:
	if _audio_dialog == null:
		return
	var slider := _audio_dialog.get_node_or_null("AudioLayout/VolumeSlider") as HSlider
	var value_label := _audio_dialog.get_node_or_null("AudioLayout/VolumeValue") as Label
	var mute := _audio_dialog.get_node_or_null("AudioLayout/MuteToggle") as CheckBox
	if slider != null:
		slider.set_value_no_signal(GameState.master_volume * 100.0)
	if value_label != null:
		value_label.text = "%d%%" % int(round(GameState.master_volume * 100.0))
	if mute != null:
		mute.set_pressed_no_signal(GameState.audio_muted)


func _on_volume_changed(value: float) -> void:
	GameState.set_master_volume(value / 100.0)
	var value_label := _audio_dialog.get_node_or_null("AudioLayout/VolumeValue") as Label if _audio_dialog != null else null
	if value_label != null:
		value_label.text = "%d%%" % int(round(value))


func _on_audio_muted(value: bool) -> void:
	GameState.set_audio_muted(value)


func _create_skill_dialog() -> void:
	if _skill_dialog != null:
		return
	_skill_dialog = AcceptDialog.new()
	_skill_dialog.title = "人物技能矩阵"
	_skill_dialog.add_theme_color_override("title_color", Color("9eeaff"))
	_skill_dialog.add_theme_color_override("font_color", Color("d9f4ff"))
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("06172d")
	panel_style.border_color = Color("2fb9ed")
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	_skill_dialog.add_theme_stylebox_override("panel", panel_style)
	_skill_dialog.ok_button_text = "关闭"
	_skill_dialog.min_size = Vector2i(640, 560)
	add_child(_skill_dialog)
	var layout := VBoxContainer.new()
	layout.name = "SkillLayout"
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 24.0
	layout.offset_top = 18.0
	layout.offset_right = -24.0
	layout.offset_bottom = -56.0
	layout.add_theme_constant_override("separation", 9)
	_skill_dialog.add_child(layout)
	var contents := RichTextLabel.new()
	contents.name = "Contents"
	contents.bbcode_enabled = true
	contents.custom_minimum_size = Vector2(0.0, 180.0)
	contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.scroll_active = true
	layout.add_child(contents)
	_skill_status = Label.new()
	_skill_status.name = "SkillStatus"
	_skill_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_status.add_theme_color_override("font_color", Color("8edfff"))
	layout.add_child(_skill_status)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	layout.add_child(grid)
	for spec in _skill_specs():
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 54.0)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_learn_skill_from_menu.bind(spec["id"]))
		grid.add_child(button)
		_skill_buttons[spec["id"]] = button
	var reset := Button.new()
	reset.name = "ResetSkills"
	reset.custom_minimum_size = Vector2(0.0, 38.0)
	reset.add_theme_color_override("font_color", Color("bcefff"))
	reset.pressed.connect(_reset_skills_from_menu)
	layout.add_child(reset)


func _refresh_skill_dialog() -> void:
	if _skill_dialog == null:
		return
	var contents := _skill_dialog.get_node_or_null("SkillLayout/Contents") as RichTextLabel
	if contents == null:
		return
	var text := "[font_size=23][color=#55dfff]局内人物技能[/color][/font_size]\n在首页直接训练，进入战斗后按对应按键启动\n\n"
	for spec in _skill_specs():
		var level := GameState.home_skill_level(spec["id"] as StringName)
		text += "[font_size=18][color=#9eeaff]%s  %d/%d级[/color][/font_size]\n按 %s  ·  %s\n\n" % [spec["name"], level, spec["max"], spec["key"], spec["effect"]]
		var button := _skill_buttons.get(spec["id"]) as Button
		if button != null:
			var cost := 5 + level * 4
			button.text = "%s  %d/%d级\n%s" % [spec["name"], level, spec["max"], "已满级" if level >= int(spec["max"]) else "升级  ·  %d 合金" % cost]
			button.disabled = level >= int(spec["max"])
	contents.clear()
	contents.append_text(text)
	if _skill_status != null:
		_skill_status.text = _skill_notice if not _skill_notice.is_empty() else "当前合金：%d  ·  所有技能初始为 1 级" % GameState.scrap
	var reset := _skill_dialog.get_node_or_null("SkillLayout/ResetSkills") as Button
	if reset != null:
		var refund := GameState.home_skill_reset_refund()
		reset.text = "重置人物技能  ·  返还 %d 合金" % refund
		reset.disabled = refund <= 0


func _skill_specs() -> Array[Dictionary]:
	return [
		{"id": &"fury", "name": "暴怒回路", "key": "T", "effect": "短时间提升射速", "max": 5},
		{"id": &"recovery", "name": "治疗协议", "key": "G", "effect": "即时修复生命", "max": 5},
		{"id": &"bounce", "name": "反弹校准", "key": "Y", "effect": "子弹额外反弹", "max": 4},
		{"id": &"tracking", "name": "追踪校准", "key": "H", "effect": "子弹锁定附近目标", "max": 4},
	]


func _learn_skill_from_menu(skill_id: StringName) -> void:
	var result := GameState.learn_home_skill(skill_id)
	if _skill_status != null:
		_skill_notice = "%s" % ("%s 已升级至 %d 级" % [result["name"], result["level"]] if bool(result.get("ok", false)) else str(result.get("reason", "训练失败")))
	_refresh_skill_dialog()
	_refresh_camp()


func _reset_skills_from_menu() -> void:
	var refund := GameState.reset_home_skills()
	if _skill_status != null:
		_skill_notice = "人物技能已重置，返还 %d 合金" % refund
	_refresh_skill_dialog()
	_refresh_camp()


func _create_archive_dialog() -> void:
	if _archive_dialog != null:
		return
	_archive_dialog = AcceptDialog.new()
	_archive_dialog.title = "星港档案"
	_archive_dialog.add_theme_color_override("title_color", Color("9eeaff"))
	_archive_dialog.add_theme_color_override("font_color", Color("d9f4ff"))
	var dialog_panel := StyleBoxFlat.new()
	dialog_panel.bg_color = Color("06172d")
	dialog_panel.border_width_left = 2
	dialog_panel.border_width_top = 2
	dialog_panel.border_width_right = 2
	dialog_panel.border_width_bottom = 2
	dialog_panel.border_color = Color("2fb9ed")
	dialog_panel.corner_radius_top_left = 12
	dialog_panel.corner_radius_top_right = 12
	dialog_panel.corner_radius_bottom_left = 12
	dialog_panel.corner_radius_bottom_right = 12
	_archive_dialog.add_theme_stylebox_override("panel", dialog_panel)
	_archive_dialog.min_size = Vector2i(700, 500)
	_archive_dialog.ok_button_text = "关闭"
	add_child(_archive_dialog)
	var tabs := TabContainer.new()
	tabs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tabs.offset_left = 18.0
	tabs.offset_top = 16.0
	tabs.offset_right = -18.0
	tabs.offset_bottom = -58.0
	_archive_dialog.add_child(tabs)
	_add_archive_page(tabs, "武器与技能", _equipment_archive_text())
	_add_archive_page(tabs, "怪物档案", _enemy_archive_text())


func _add_archive_page(tabs: TabContainer, page_name: String, contents: String) -> void:
	var page := RichTextLabel.new()
	page.name = page_name
	page.bbcode_enabled = true
	page.fit_content = false
	page.scroll_active = true
	page.append_text(contents)
	tabs.add_child(page)


func _equipment_archive_text() -> String:
	return """[font_size=22][color=#55dfff]武器档案[/color][/font_size]
喷火器  ·  近距离持续灼烧，压制成群目标
自动步枪  ·  稳定连射，适合持续推进
霰弹炮  ·  近距离多弹丸爆发，贴近重装目标时效果显著
轨道枪  ·  高穿透直线打击，适合清理狭窄通道
电弧刃  ·  近战挥砍，命中核心时爆发更高
脉冲手枪  ·  机动轻便，适合精确补刀
狙击步枪  ·  远距离高伤害，优先处理精英单位
攻城火炮  ·  慢射速大范围爆破，适合高密度敌群

[font_size=22][color=#55dfff]武器模块[/color][/font_size]
超频射速  ·  缩短射击间隔
冲击增幅  ·  提升单发伤害
偏转反弹  ·  子弹命中敌人或墙体后继续折返
追踪锁定  ·  子弹会修正方向追踪附近目标
超距聚焦  ·  增加有效射程与存续时间

[font_size=22][color=#55dfff]人物主动技能[/color][/font_size]
T 暴怒回路  ·  短时间提升射速
G 治疗协议  ·  消耗冷却恢复生命
Y 反弹校准  ·  临时提高子弹反弹次数
H 追踪校准  ·  临时获得更强的目标锁定

局内强化还可获得移动加速、护甲、暴击矩阵、击毁修复、分裂弹、相位弹、轨道无人机与战斗核心等能力"""


func _enemy_archive_text() -> String:
	return """[font_size=22][color=#55dfff]颜色与职责[/color][/font_size]
[color=#ff7a59]橙红[/color] 战士  ·  攻防均衡，主动贴近作战
[color=#55aaff]蓝色[/color] 射手  ·  保持距离持续射击
[color=#ffcf4a]黄色[/color] 爆破者  ·  靠近后自毁，需优先处理
[color=#d94f56]深红[/color] 重装  ·  生命高、推进稳，适合用高伤害武器对付
[color=#65cf88]绿色[/color] 辅助  ·  为同伴修复、强化或召唤支援
[color=#bc7cff]紫色[/color] 法师  ·  施放远程范围能量攻击

[font_size=22][color=#55dfff]精英单位[/color][/font_size]
危险精英  ·  布设高伤害区域，避免停留
哨卫精英  ·  远距离火力压制，需要利用掩体接近

[font_size=22][color=#55dfff]关底目标[/color][/font_size]
异星母舰  ·  每关都会在战斗中段进入星区。拥有多阶段攻击、召唤支援与高额核心生命。战胜母舰后才能完成该关任务"""


func _refresh_camp(message: String = "") -> void:
	var cost_weapon := 4 + GameState.weapon_level(GameState.selected_start_weapon_id) * 2
	var cost_health := 4 + GameState.garden_level * 3
	$Layout/Panel/Buttons/CampStatus.text = "%s\n合金 %d  |  初始生命 %d  |  当前开局武器 %s" % [message if not message.is_empty() else "星港中枢补给", GameState.scrap, 160 + GameState.garden_level * 18, _start_weapon_name(GameState.selected_start_weapon_id)]
	$Layout/Panel/Buttons/ZoneButton.text = "初始武器：%s  ‹ 点击切换 ›" % _start_weapon_name(GameState.selected_start_weapon_id)
	$Layout/Panel/Buttons/UpgradeButton.text = "升级当前初始武器  ·  消耗 %d 合金" % cost_weapon
	$Layout/Panel/Buttons/GardenButton.text = "升级初始生命  ·  消耗 %d 合金" % cost_health
	$Layout/Panel/Buttons/SkillButton.text = "人物技能矩阵  ·  已训练 %d 项" % GameState.home_skill_levels.size()
	$Layout/Panel/Buttons/SkinButton.text = "作战皮肤：%s  ‹ 点击切换 ›" % _skin_name(GameState.equipped_skin)
	var final_status := "已完成" if GameState.has_achievement(&"campaign_complete") else "待部署"
	$Layout/Panel/Buttons/AchievementStatus.text = "成就档案  ·  已解锁 %d 项  ·  二十四区战役：%s" % [GameState.achievements.size(), final_status]
	$Layout/IdentityCard/Identity/Subtitle.text = "二十四区星域战役  //  第 %d 关待命\n%s" % [GameState.current_stage, "终焉记录已归档" if GameState.has_achievement(&"campaign_complete") else "完成第二十四关即可解锁终焉记录"]


func _build_starfield() -> void:
	var starfield := preload("res://src/ui/menu_particle_display.gd").new()
	starfield.name = "BlueSignalField"
	add_child(starfield)
	move_child(starfield, 1)


func _saved_stage() -> int:
	var data := SaveManager.load_campaign()
	return int(data.get("stage", 1)) if not data.is_empty() else 1


func _refresh_continue_button() -> void:
	var continue_button: Button = $Layout/Panel/Buttons/ContinueButton
	var has_campaign := SaveManager.has_campaign()
	continue_button.disabled = not has_campaign
	continue_button.text = "继续战役  第 %d 关重新部署" % _saved_stage() if has_campaign else "开始新的战役"


func _skin_name(skin_id: StringName) -> String:
	match skin_id:
		&"prism_guardian": return "七彩棱镜"
		&"red_guardian": return "赤红守望"
		&"orange_guardian": return "橙焰守望"
		&"yellow_guardian": return "曜黄守望"
		&"green_guardian": return "翠绿守望"
		&"cyan_guardian": return "青辉守望"
		&"blue_guardian": return "深蓝守望"
		&"violet_guardian": return "紫晶守望"
		_: return "七彩棱镜"


func _start_weapon_name(weapon_id: StringName) -> String:
	for entry in START_WEAPONS:
		if entry["id"] == weapon_id:
			return str(entry["name"])
	return "喷火器"


func _on_quit_pressed() -> void:
	get_tree().quit()
