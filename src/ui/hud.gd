class_name WastelandHUD
extends CanvasLayer


func set_health(current: float, maximum: float) -> void:
	$Margin/TopBar/HealthPanel/HealthContent/HealthBar.max_value = maximum
	$Margin/TopBar/HealthPanel/HealthContent/HealthBar.value = current
	$Margin/TopBar/HealthPanel/HealthContent/HealthText.text = "%03d / %03d" % [current, maximum]


func set_time(seconds_left: float) -> void:
	var total := maxi(0, int(ceil(seconds_left)))
	$Margin/TopBar/TimerPanel/Timer.text = "%02d:%02d" % [total / 60, total % 60]


func set_stage(stage: int) -> void:
	$Margin/TopBar/StagePanel/Stage.text = "第 %d 关" % stage


func set_kills(value: int, target: int = 0) -> void:
	if target > 0:
		$Margin/TopBar/KillPanel/Kills.text = "击毁  %03d / %03d" % [value, target]
	else:
		$Margin/TopBar/KillPanel/Kills.text = "击毁  %03d" % value


func set_dash_ready(ready: bool) -> void:
	$Margin/BottomBar/DashStatus.text = "闪避  就绪" if ready else "闪避  充能中"
	$Margin/BottomBar/DashStatus.modulate = Color("35e6b2") if ready else Color("7b8c88")


func set_weapon(weapon: WeaponData, index: int) -> void:
	if weapon == null:
		return
	$Margin/BottomBar/WeaponIcon.texture = weapon.icon
	$Margin/BottomBar/WeaponStatus.text = "%d  %s" % [index + 1, weapon.display_name]


func set_skill(skill: SkillData, level: int) -> void:
	var suffix := "  已满级" if level >= skill.max_level else "  等级 %d" % level
	$Margin/BottomBar/UpgradeStatus.text = skill.display_name + suffix


func show_all_skills_maxed() -> void:
	$Margin/BottomBar/UpgradeStatus.text = "全部强化已满级"


func show_boss(current: float, maximum: float, phase_name: String = "") -> void:
	$Margin/BossBar.visible = true
	$Margin/BossBar/Health.max_value = maximum
	$Margin/BossBar/Health.value = current
	if not phase_name.is_empty():
		$Margin/BossBar/BossName.text = "废土监管者  |  %s" % phase_name


func hide_boss() -> void:
	$Margin/BossBar.visible = false


func show_message(title: String, subtitle: String) -> void:
	$CenterMessage/Content/Title.text = title
	$CenterMessage/Content/Subtitle.text = subtitle
	$CenterMessage.visible = true


func hide_message() -> void:
	$CenterMessage.visible = false
