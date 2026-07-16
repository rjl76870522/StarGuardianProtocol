extends Node3D

const ENEMY_SCENE := preload("res://scenes/chaser.tscn")
const IMPACT_SCENE := preload("res://scenes/impact_flash.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const ENEMY_CATALOG: Array[EnemyData] = [
	preload("res://assets/data/enemies/chaser.tres"),
	preload("res://assets/data/enemies/shooter.tres"),
	preload("res://assets/data/enemies/bomber.tres"),
	preload("res://assets/data/enemies/heavy.tres"),
	preload("res://assets/data/enemies/repair.tres"),
	preload("res://assets/data/enemies/elite_blink.tres"),
	preload("res://assets/data/enemies/elite_hazard.tres"),
]
const SKILL_CATALOG: Array[SkillData] = [
	preload("res://assets/data/skills/rapid_fire.tres"),
	preload("res://assets/data/skills/move_speed.tres"),
	preload("res://assets/data/skills/ricochet.tres"),
	preload("res://assets/data/skills/penetration.tres"),
	preload("res://assets/data/skills/kill_heal.tres"),
	preload("res://assets/data/skills/orbit_drone.tres"),
]

@export var round_duration: float = 60.0
@export var initial_spawn_interval: float = 2.8
@export var minimum_spawn_interval: float = 1.5
@export var max_active_enemies: int = 16
@export var required_kills: int = 8
@export var upgrade_kill_interval: int = 2
@export var boss_spawn_elapsed: float = 30.0

var time_left: float
var kills: int = 0
var _spawn_cooldown: float = 0.5
var _round_finished: bool = false
var _paused: bool = false
var _rng := RandomNumberGenerator.new()
var _camera_shake: float = 0.0
var _camera_base_position: Vector3
var _next_upgrade_kills: int
var _boss_spawned: bool = false
var _boss_defeated: bool = false

@onready var player: WastelandPlayer = $Player
@onready var hud: WastelandHUD = $HUD
@onready var pause_panel: Control = $PauseLayer/PausePanel
@onready var result_panel: Control = $PauseLayer/ResultPanel
@onready var camera: Camera3D = $Player/CameraRig/Camera3D
@onready var upgrade_panel: UpgradePanel = $UpgradePanel
@onready var boss_debug_panel: BossDebugPanel = $BossDebugPanel


func _ready() -> void:
	GameState.begin_run()
	_apply_stage_difficulty()
	time_left = round_duration
	_rng.randomize()
	_camera_base_position = camera.position
	_next_upgrade_kills = upgrade_kill_interval
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	player.fired.connect(_on_player_fired)
	player.dash_started.connect(_on_dash_started)
	player.weapon_changed.connect(_on_weapon_changed)
	player.skill_upgraded.connect(_on_skill_upgraded)
	upgrade_panel.skill_selected.connect(_on_skill_selected)
	hud.set_health(player.health, player.max_health)
	hud.set_time(time_left)
	hud.set_kills(kills, required_kills)
	hud.set_stage(GameState.current_stage)
	hud.set_weapon(player.current_weapon, player.weapon_index)
	for skill in SKILL_CATALOG:
		var carried_level := player.skill_system.get_level(skill.skill_id)
		if carried_level > 0:
			hud.set_skill(skill, carried_level)
	hud.show_message("第 %d 关" % GameState.current_stage, "击毁 %d 个敌人并坚守六十秒" % required_kills)
	get_tree().create_timer(2.0).timeout.connect(hud.hide_message)
	$PauseLayer/PausePanel/Panel/Content/Buttons/ResumeButton.pressed.connect(_toggle_pause)
	$PauseLayer/PausePanel/Panel/Content/Buttons/RestartButton.pressed.connect(_restart)
	$PauseLayer/PausePanel/Panel/Content/Buttons/MenuButton.pressed.connect(_return_to_menu)
	$PauseLayer/ResultPanel/Panel/Content/Buttons/RestartButton.pressed.connect(_restart)
	$PauseLayer/ResultPanel/Panel/Content/Buttons/NextButton.pressed.connect(_next_stage)
	$PauseLayer/ResultPanel/Panel/Content/Buttons/MenuButton.pressed.connect(_return_to_menu)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _round_finished:
		_toggle_pause()
	if Input.is_action_just_pressed("boss_spawn_debug") and not _round_finished and not _boss_spawned:
		_spawn_boss()
	if Input.is_action_just_pressed("upgrade_debug") and not _round_finished and not upgrade_panel.overlay.visible:
		_offer_upgrade()
	if _paused or _round_finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	_spawn_cooldown -= delta
	hud.set_time(time_left)
	if _spawn_cooldown <= 0.0:
		_spawn_enemy()
		var pressure := 1.0 - time_left / round_duration
		_spawn_cooldown = lerpf(initial_spawn_interval, minimum_spawn_interval, pressure)
	if not _boss_spawned and round_duration - time_left >= boss_spawn_elapsed:
		_spawn_boss()
	if time_left <= 0.0:
		if kills >= required_kills and (not _boss_spawned or _boss_defeated):
			_finish_round(true)
		else:
			_finish_round(false, "区域失守")
	_update_camera_shake(delta)


func _spawn_enemy() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= max_active_enemies:
		return
	var enemy: ScrapChaser = ENEMY_SCENE.instantiate()
	enemy.enemy_data = _choose_enemy_data()
	enemy.target = player
	enemy.add_to_group("enemies")
	var side := _rng.randi_range(0, 3)
	var offset := _rng.randf_range(-13.0, 13.0)
	match side:
		0: enemy.position = Vector3(offset, 0.65, -9.5)
		1: enemy.position = Vector3(offset, 0.65, 9.5)
		2: enemy.position = Vector3(-15.5, 0.65, offset * 0.6)
		_: enemy.position = Vector3(15.5, 0.65, offset * 0.6)
	$Enemies.add_child(enemy)
	enemy.apply_difficulty(_stage_multiplier())
	enemy.died.connect(_on_enemy_died)
	enemy.hit_player.connect(_on_player_hit)


func _choose_enemy_data() -> EnemyData:
	var elapsed := round_duration - time_left
	var maximum_index := 0
	if elapsed >= 10.0:
		maximum_index = 2
	if elapsed >= 20.0:
		maximum_index = 4
	if elapsed >= 38.0:
		maximum_index = 6
	return ENEMY_CATALOG[_rng.randi_range(0, maximum_index)]


func _spawn_boss() -> void:
	_boss_spawned = true
	var boss := BOSS_SCENE.instantiate() as WastelandBoss
	boss.target = player
	boss.position = Vector3(0.0, 0.0, -7.5)
	$Enemies.add_child(boss)
	boss.apply_difficulty(_stage_multiplier())
	boss.health_changed.connect(func(current: float, maximum: float) -> void: hud.show_boss(current, maximum))
	boss.phase_changed.connect(func(_index: int, phase: BossPhaseData) -> void: hud.show_boss(boss.health, boss.max_health, phase.display_name))
	boss.summon_requested.connect(_summon_enemies)
	boss.died.connect(_on_boss_died)
	boss_debug_panel.bind_boss(boss)
	hud.show_boss(boss.health, boss.max_health, WastelandBoss.PHASES[0].display_name)
	hud.show_message("警告", "废土监管者已进入战场")
	get_tree().create_timer(2.0).timeout.connect(hud.hide_message)


func _summon_enemies(count: int) -> void:
	for index in count:
		_spawn_enemy()


func _on_boss_died() -> void:
	_boss_defeated = true
	kills += 3
	hud.set_kills(kills, required_kills)
	hud.hide_boss()
	hud.show_message("核心摧毁", "废土监管者已停止运行")
	get_tree().create_timer(2.0).timeout.connect(hud.hide_message)


func _on_enemy_died(enemy: ScrapChaser) -> void:
	kills += 1
	player.on_kill()
	hud.set_kills(kills, required_kills)
	_spawn_impact(enemy.global_position, Color("ffb340"))
	_camera_shake = maxf(_camera_shake, 0.12)
	if kills >= _next_upgrade_kills and not _round_finished:
		call_deferred("_offer_upgrade")


func _on_player_hit() -> void:
	_camera_shake = maxf(_camera_shake, 0.22)


func _on_player_fired(recoil: float) -> void:
	_spawn_impact(player.muzzle.global_position, Color("35e6b2"), 0.11)
	_camera_shake = maxf(_camera_shake, recoil * 0.06)


func _offer_upgrade() -> void:
	if _round_finished or upgrade_panel.overlay.visible:
		return
	var choices := player.skill_system.available_choices(SKILL_CATALOG, 3, _rng)
	if choices.is_empty():
		_next_upgrade_kills = 1 << 30
		hud.show_all_skills_maxed()
		return
	_paused = true
	get_tree().paused = true
	upgrade_panel.show_choices(choices, player.skill_system)


func _on_skill_selected(skill: SkillData) -> void:
	if not player.apply_skill(skill):
		return
	_next_upgrade_kills += upgrade_kill_interval
	_paused = false
	get_tree().paused = false


func _on_weapon_changed(weapon: WeaponData, index: int) -> void:
	hud.set_weapon(weapon, index)


func _on_skill_upgraded(skill: SkillData, level: int) -> void:
	hud.set_skill(skill, level)


func _on_dash_started() -> void:
	hud.set_dash_ready(false)
	get_tree().create_timer(player.dash_cooldown).timeout.connect(func() -> void: hud.set_dash_ready(true))


func _spawn_impact(at: Vector3, color: Color, size: float = 0.28) -> void:
	var effect: MeshInstance3D = IMPACT_SCENE.instantiate()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	effect.material_override = material
	effect.scale = Vector3.ONE * size
	add_child(effect)
	effect.global_position = at


func _update_camera_shake(delta: float) -> void:
	_camera_shake = move_toward(_camera_shake, 0.0, delta * 1.8)
	if _camera_shake > 0.0:
		camera.position = _camera_base_position + Vector3(
			_rng.randf_range(-_camera_shake, _camera_shake),
			_rng.randf_range(-_camera_shake, _camera_shake),
			0.0
		)
	else:
		camera.position = _camera_base_position


func _on_player_died() -> void:
	_finish_round(false)


func _finish_round(victory: bool, failure_title: String = "作战单元已损毁") -> void:
	if _round_finished:
		return
	_round_finished = true
	GameState.finish_run(round_duration - time_left, kills)
	result_panel.visible = true
	result_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var title := "区域已肃清" if victory else failure_title
	var detail := "第 %d 关   |   存活 %02d:%02d   |   击毁敌人 %d" % [
		GameState.current_stage,
		int(GameState.last_survival_time) / 60,
		int(GameState.last_survival_time) % 60,
		kills,
	]
	$PauseLayer/ResultPanel/Panel/Content/Title.text = title
	$PauseLayer/ResultPanel/Panel/Content/Detail.text = detail
	var next_button: Button = $PauseLayer/ResultPanel/Panel/Content/Buttons/NextButton
	next_button.visible = victory
	get_tree().paused = true
	if victory:
		next_button.grab_focus()
	else:
		$PauseLayer/ResultPanel/Panel/Content/Buttons/RestartButton.grab_focus()


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	pause_panel.visible = _paused
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	if _paused:
		$PauseLayer/PausePanel/Panel/Content/Buttons/ResumeButton.grab_focus()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _next_stage() -> void:
	GameState.advance_stage()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _stage_multiplier() -> float:
	return 1.0 + float(GameState.current_stage - 1) * 0.18


func _apply_stage_difficulty() -> void:
	var stage_offset := GameState.current_stage - 1
	required_kills += stage_offset * 2
	max_active_enemies += mini(stage_offset * 2, 10)
	initial_spawn_interval = maxf(initial_spawn_interval * pow(0.94, stage_offset), 1.7)
	minimum_spawn_interval = maxf(minimum_spawn_interval * pow(0.94, stage_offset), 0.85)


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
