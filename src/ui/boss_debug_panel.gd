class_name BossDebugPanel
extends CanvasLayer

var boss: WastelandBoss
@onready var panel: Control = $Panel
@onready var health_slider: HSlider = $Panel/Content/HealthSlider
@onready var status_label: Label = $Panel/Content/Status


func _ready() -> void:
	panel.visible = false
	$Panel/Content/PhaseButtons/Phase1.pressed.connect(func() -> void: _set_phase(0))
	$Panel/Content/PhaseButtons/Phase2.pressed.connect(func() -> void: _set_phase(1))
	$Panel/Content/PhaseButtons/Phase3.pressed.connect(func() -> void: _set_phase(2))
	$Panel/Content/Reset.pressed.connect(_reset)
	health_slider.value_changed.connect(_set_health)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("boss_debug"):
		panel.visible = not panel.visible


func _process(_delta: float) -> void:
	if not panel.visible:
		return
	if not is_instance_valid(boss):
		status_label.text = "Boss 尚未出现"
		return
	var cooldown_text: Array[String] = []
	for ability in boss.cooldowns:
		cooldown_text.append("%s %.1f秒" % [_ability_name(ability), float(boss.cooldowns[ability])])
	status_label.text = "阶段 %d  |  状态 %s\n生命 %.0f / %.0f\n冷却 %s" % [
		boss.phase_index + 1,
		boss.current_state,
		boss.health,
		boss.max_health,
		"  ".join(cooldown_text),
	]


func bind_boss(value: WastelandBoss) -> void:
	boss = value


func _set_phase(index: int) -> void:
	if is_instance_valid(boss):
		boss.debug_set_phase(index)
		health_slider.set_value_no_signal(boss.health / boss.max_health * 100.0)


func _set_health(value: float) -> void:
	if is_instance_valid(boss):
		boss.debug_set_health_ratio(value / 100.0)


func _reset() -> void:
	if is_instance_valid(boss):
		boss.reset_battle()
		health_slider.set_value_no_signal(100.0)


func _ability_name(ability: StringName) -> String:
	return {
		&"aimed": "定向射击",
		&"charge": "冲撞",
		&"summon": "召唤",
		&"radial": "环形弹幕",
		&"hazard": "危险区域",
		&"laser": "激光扫射",
		&"shockwave": "冲击波",
	}.get(ability, str(ability))
