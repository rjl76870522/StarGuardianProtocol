extends Node3D

const ENEMY_SCENE := preload("res://scenes/chaser.tscn")
const IMPACT_SCENE := preload("res://scenes/impact_flash.tscn")

@export var round_duration: float = 60.0
@export var initial_spawn_interval: float = 2.4
@export var minimum_spawn_interval: float = 1.2
@export var max_active_enemies: int = 16
@export var required_kills: int = 8

var time_left: float
var kills: int = 0
var _spawn_cooldown: float = 0.5
var _round_finished: bool = false
var _paused: bool = false
var _rng := RandomNumberGenerator.new()
var _camera_shake: float = 0.0
var _camera_base_position: Vector3

@onready var player: WastelandPlayer = $Player
@onready var hud: WastelandHUD = $HUD
@onready var pause_panel: Control = $PauseLayer/PausePanel
@onready var result_panel: Control = $PauseLayer/ResultPanel
@onready var camera: Camera3D = $Player/CameraRig/Camera3D


func _ready() -> void:
	GameState.begin_run()
	time_left = round_duration
	_rng.randomize()
	_camera_base_position = camera.position
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	player.fired.connect(_on_player_fired)
	player.dash_started.connect(_on_dash_started)
	hud.set_health(player.health, player.max_health)
	hud.set_time(time_left)
	hud.set_kills(kills, required_kills)
	hud.show_message("ENGAGE", "Destroy %d hostiles and hold for sixty seconds" % required_kills)
	get_tree().create_timer(2.0).timeout.connect(hud.hide_message)
	$PauseLayer/PausePanel/Panel/Content/Buttons/ResumeButton.pressed.connect(_toggle_pause)
	$PauseLayer/PausePanel/Panel/Content/Buttons/RestartButton.pressed.connect(_restart)
	$PauseLayer/PausePanel/Panel/Content/Buttons/MenuButton.pressed.connect(_return_to_menu)
	$PauseLayer/ResultPanel/Panel/Content/Buttons/RestartButton.pressed.connect(_restart)
	$PauseLayer/ResultPanel/Panel/Content/Buttons/MenuButton.pressed.connect(_return_to_menu)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _round_finished:
		_toggle_pause()
	if _paused or _round_finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	_spawn_cooldown -= delta
	hud.set_time(time_left)
	if _spawn_cooldown <= 0.0:
		_spawn_enemy()
		var pressure := 1.0 - time_left / round_duration
		_spawn_cooldown = lerpf(initial_spawn_interval, minimum_spawn_interval, pressure)
	if time_left <= 0.0:
		if kills >= required_kills:
			_finish_round(true)
		else:
			_finish_round(false, "SECTOR OVERRUN")
	_update_camera_shake(delta)


func _spawn_enemy() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= max_active_enemies:
		return
	var enemy: ScrapChaser = ENEMY_SCENE.instantiate()
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
	enemy.died.connect(_on_enemy_died)
	enemy.hit_player.connect(_on_player_hit)


func _on_enemy_died(enemy: ScrapChaser) -> void:
	kills += 1
	hud.set_kills(kills, required_kills)
	_spawn_impact(enemy.global_position, Color("ffb340"))
	_camera_shake = maxf(_camera_shake, 0.12)


func _on_player_hit() -> void:
	_camera_shake = maxf(_camera_shake, 0.22)


func _on_player_fired() -> void:
	_spawn_impact(player.muzzle.global_position, Color("35e6b2"), 0.11)
	_camera_shake = maxf(_camera_shake, 0.035)


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


func _finish_round(victory: bool, failure_title: String = "UNIT DESTROYED") -> void:
	if _round_finished:
		return
	_round_finished = true
	GameState.finish_run(round_duration - time_left, kills)
	result_panel.visible = true
	result_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var title := "SECTOR SECURED" if victory else failure_title
	var detail := "Survived %02d:%02d   |   Scrap recovered %d" % [
		int(GameState.last_survival_time) / 60,
		int(GameState.last_survival_time) % 60,
		kills,
	]
	$PauseLayer/ResultPanel/Panel/Content/Title.text = title
	$PauseLayer/ResultPanel/Panel/Content/Detail.text = detail
	get_tree().paused = true
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


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
