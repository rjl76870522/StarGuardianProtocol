class_name WastelandBoss
extends CharacterBody3D

signal died
signal phase_changed(index: int, phase: BossPhaseData)
signal health_changed(current: float, maximum: float)
signal summon_requested(count: int)

const ENEMY_PROJECTILE := preload("res://scenes/enemy_projectile.tscn")
const HAZARD := preload("res://scenes/ground_hazard.tscn")
const PHASES: Array[BossPhaseData] = [
	preload("res://assets/data/boss/phase_1.tres"),
	preload("res://assets/data/boss/phase_2.tres"),
	preload("res://assets/data/boss/phase_3.tres"),
]

@export var max_health: float = 720.0
var health: float
var target: WastelandPlayer
var phase_index: int = 0
var current_state: StringName = &"出生"
var cooldowns: Dictionary = {}
var _attack_cooldown: float = 1.0
var _ability_cursor: int = 0
var _dead := false
var _charge_velocity := Vector3.ZERO
var _charge_remaining := 0.0
var _laser_remaining := 0.0
var _laser_angle := 0.0

@onready var core: MeshInstance3D = $Core
@onready var laser: MeshInstance3D = $Laser


func _ready() -> void:
	health = max_health
	add_to_group("boss")
	_apply_phase(0)
	health_changed.emit(health, max_health)
	var tween := create_tween()
	scale = Vector3(0.1, 0.1, 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_BACK)
	tween.tween_callback(func() -> void: current_state = &"追击")


func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target):
		return
	_attack_cooldown -= delta
	for key in cooldowns.keys():
		cooldowns[key] = maxf(float(cooldowns[key]) - delta, 0.0)
	if _laser_remaining > 0.0:
		_update_laser(delta)
		return
	if _charge_remaining > 0.0:
		_charge_remaining -= delta
		velocity = _charge_velocity
		move_and_slide()
		if global_position.distance_to(target.global_position) < 1.8:
			target.take_damage(18.0 + phase_index * 5.0)
			_charge_remaining = 0.0
		return
	var phase := PHASES[phase_index]
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length() > 5.5:
		current_state = &"追击"
		velocity = offset.normalized() * phase.move_speed
		look_at(global_position + offset.normalized(), Vector3.UP)
		move_and_slide()
	else:
		velocity = Vector3.ZERO
	if _attack_cooldown <= 0.0:
		_attack_cooldown = phase.attack_interval
		_use_next_ability(phase)


func _use_next_ability(phase: BossPhaseData) -> void:
	if phase.abilities.is_empty():
		return
	var ability := phase.abilities[_ability_cursor % phase.abilities.size()]
	_ability_cursor += 1
	current_state = ability
	cooldowns[ability] = phase.attack_interval
	match ability:
		&"aimed": _fire_aimed(phase.projectile_count, phase.projectile_damage)
		&"charge": _start_charge()
		&"summon": summon_requested.emit(2)
		&"radial": _fire_radial(phase.projectile_count, phase.projectile_damage)
		&"hazard": _spawn_hazard()
		&"laser": _start_laser()
		&"shockwave": _fire_radial(phase.projectile_count, phase.projectile_damage * 1.15)


func _fire_aimed(count: int, damage: float) -> void:
	var base := (target.global_position - global_position).normalized()
	for index in count:
		var ratio := 0.5 if count == 1 else float(index) / float(count - 1)
		_spawn_projectile(base.rotated(Vector3.UP, deg_to_rad(lerpf(-10.0, 10.0, ratio))), damage, 14.0)


func _fire_radial(count: int, damage: float) -> void:
	for index in count:
		_spawn_projectile(Vector3.FORWARD.rotated(Vector3.UP, TAU * float(index) / float(count)), damage, 10.5)


func _spawn_projectile(direction: Vector3, damage: float, speed: float) -> void:
	var projectile = ENEMY_PROJECTILE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.launch(global_position + Vector3.UP, direction, damage, speed)


func _start_charge() -> void:
	_charge_velocity = (target.global_position - global_position).normalized() * 12.0
	_charge_velocity.y = 0.0
	_charge_remaining = 0.55


func _spawn_hazard() -> void:
	var hazard = HAZARD.instantiate()
	get_tree().current_scene.add_child(hazard)
	hazard.global_position = Vector3(target.global_position.x, 0.08, target.global_position.z)


func _start_laser() -> void:
	_laser_remaining = 1.8
	_laser_angle = atan2(target.global_position.x - global_position.x, target.global_position.z - global_position.z) - 0.7
	laser.visible = true


func _update_laser(delta: float) -> void:
	_laser_remaining -= delta
	_laser_angle += delta * 0.8
	laser.rotation.y = _laser_angle
	var direction := Vector3(sin(_laser_angle), 0.0, cos(_laser_angle))
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 13.0 and absf(direction.cross(to_player.normalized()).y) < 0.055:
		target.take_damage(7.0)
	if _laser_remaining <= 0.0:
		laser.visible = false
		current_state = &"追击"


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	health_changed.emit(health, max_health)
	var ratio := health / max_health
	var target_phase := 0
	if ratio <= PHASES[2].health_threshold:
		target_phase = 2
	elif ratio <= PHASES[1].health_threshold:
		target_phase = 1
	if target_phase > phase_index:
		_apply_phase(target_phase)
	if health <= 0.0:
		_dead = true
		current_state = &"死亡"
		laser.visible = false
		collision_layer = 0
		collision_mask = 0
		died.emit()
		create_tween().tween_property(self, "scale", Vector3.ZERO, 0.8).set_trans(Tween.TRANS_BACK).tween_callback(queue_free)


func _apply_phase(index: int) -> void:
	phase_index = clampi(index, 0, PHASES.size() - 1)
	var phase := PHASES[phase_index]
	var material := StandardMaterial3D.new()
	material.albedo_color = phase.accent_color
	material.emission_enabled = true
	material.emission = phase.accent_color
	material.emission_energy_multiplier = 4.0
	core.material_override = material
	_attack_cooldown = 0.35
	phase_changed.emit(phase_index, phase)


func debug_set_phase(index: int) -> void:
	_apply_phase(index)
	health = max_health * PHASES[phase_index].health_threshold
	health_changed.emit(health, max_health)


func debug_set_health_ratio(ratio: float) -> void:
	health = clampf(ratio, 0.01, 1.0) * max_health
	health_changed.emit(health, max_health)


func reset_battle() -> void:
	health = max_health
	_dead = false
	collision_layer = 4
	collision_mask = 3
	_apply_phase(0)
	health_changed.emit(health, max_health)


func apply_difficulty(multiplier: float) -> void:
	max_health *= maxf(multiplier, 1.0)
	health = max_health
	health_changed.emit(health, max_health)
