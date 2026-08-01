class_name WastelandHUD
extends CanvasLayer

var _salvage_hint_tween: Tween


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
	$Margin/BottomBar/DashStatus.text = "闪避  就绪" if ready else "闪避  充能中"
	$Margin/BottomBar/DashStatus.modulate = Color("8edfff") if ready else Color("6689a8")


func set_weapon(weapon: WeaponData, index: int) -> void:
	if weapon == null:
		return
	$Margin/BottomBar/WeaponIcon.texture = weapon.icon
	var state := get_node_or_null("/root/GameState")
	var level := int(state.weapon_level(weapon.weapon_id)) if state != null else 1
	$Margin/BottomBar/WeaponStatus.text = "%d  %s  ·  %d级  ·  单发 %d  ·  6震爆 7燃烧 8电磁\nT暴怒  G修复  Y反弹  H锁定" % [index + 1, weapon.display_name, level, weapon.damage]


func set_skill(skill: SkillData, level: int) -> void:
	var suffix := "  已满级" if level >= skill.max_level else "  等级 %d" % level
	$Margin/BottomBar/UpgradeStatus.text = skill.display_name + suffix


func show_all_skills_maxed() -> void:
	$Margin/BottomBar/UpgradeStatus.text = "全部强化已满级"
	$Margin/BottomBar/UpgradeStatus.modulate = Color.WHITE


func show_upgrade_ready() -> void:
	$Margin/BottomBar/UpgradeStatus.text = "强化模块就绪  按 E 选择"
	$Margin/BottomBar/UpgradeStatus.modulate = Color("9ce8ff")


func clear_upgrade_ready() -> void:
	$Margin/BottomBar/UpgradeStatus.text = "强化模块待获取"
	$Margin/BottomBar/UpgradeStatus.modulate = Color.WHITE


func show_boss(current: float, maximum: float, phase_name: String = "") -> void:
	$Margin/BossBar.visible = true
	$Margin/BossBar/Health.max_value = maximum
	$Margin/BossBar/Health.value = current
	if not phase_name.is_empty():
		$Margin/BossBar/BossName.text = "异星母舰  |  %s" % phase_name


func hide_boss() -> void:
	$Margin/BossBar.visible = false


func show_message(title: String, subtitle: String) -> void:
	$CenterMessage/Content/Title.text = title
	$CenterMessage/Content/Subtitle.text = subtitle
	$CenterMessage.visible = true


func hide_message() -> void:
	$CenterMessage.visible = false


func set_interaction_hint(message: String) -> void:
	$Margin/InteractionHint.text = message
	$Margin/InteractionHint.visible = not message.is_empty()


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
