class_name WastelandPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
signal fired
signal dash_started

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

@export var move_speed: float = 8.0
@export var acceleration: float = 34.0
@export var max_health: float = 300.0
@export var fire_interval: float = 0.13
@export var dash_speed: float = 22.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.85
@export var invulnerability_duration: float = 0.24
@export var hit_invulnerability_duration: float = 0.85

var health: float
var is_dead: bool = false
var is_invulnerable: bool = false
var _fire_cooldown: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_remaining: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _invulnerability_generation: int = 0

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var muzzle: Marker3D = $Body/Muzzle
@onready var weapon_audio: AudioStreamPlayer = $WeaponAudio
@onready var dash_audio: AudioStreamPlayer = $DashAudio


func _ready() -> void:
	health = max_health
	weapon_audio.stream = SoundSynth.tone(520.0, 0.055, 0.18)
	dash_audio.stream = SoundSynth.tone(170.0, 0.13, 0.2)
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)

	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := Vector3(input_2d.x, 0.0, input_2d.y).normalized()
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and move_direction != Vector3.ZERO:
		_start_dash(move_direction)

	if _dash_remaining > 0.0:
		_dash_remaining -= delta
		velocity = _dash_direction * dash_speed
	else:
		velocity = velocity.move_toward(move_direction * move_speed, acceleration * delta)

	_update_aim()
	if Input.is_action_pressed("shoot"):
		_try_fire()
	move_and_slide()


func _update_aim() -> void:
	var mouse := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var floor_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = floor_plane.intersects_ray(ray_origin, ray_direction)
	if hit is Vector3:
		var target: Vector3 = hit
		var flat := target - global_position
		flat.y = 0.0
		if flat.length_squared() > 0.05:
			$Body.look_at(global_position + flat.normalized(), Vector3.UP)


func _try_fire() -> void:
	if _fire_cooldown > 0.0:
		return
	_fire_cooldown = fire_interval
	var projectile := PROJECTILE_SCENE.instantiate()
	get_tree().current_scene.add_child(projectile)
	var aim: Vector3 = -$Body.global_transform.basis.z
	projectile.launch(muzzle.global_position, Vector3(aim.x, 0.0, aim.z))
	weapon_audio.play()
	fired.emit()


func _start_dash(direction: Vector3) -> void:
	_dash_direction = direction
	_dash_remaining = dash_duration
	_dash_cooldown = dash_cooldown
	_set_invulnerable(invulnerability_duration)
	dash_audio.play()
	dash_started.emit()


func _set_invulnerable(duration: float) -> void:
	_invulnerability_generation += 1
	var generation := _invulnerability_generation
	is_invulnerable = true
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if generation == _invulnerability_generation:
			is_invulnerable = false
	)


func take_damage(amount: float) -> void:
	if is_dead or is_invulnerable or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_dead = true
		velocity = Vector3.ZERO
		died.emit()
	else:
		_set_invulnerable(hit_invulnerability_duration)
