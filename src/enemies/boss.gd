class_name WastelandBoss
extends CharacterBody3D

signal died
signal phase_changed(index: int, phase: BossPhaseData)
signal health_changed(current: float, maximum: float)
signal summon_requested(count: int)
signal state_changed(state_name: StringName)
signal hit_received(amount: float, critical: bool)

const ENEMY_PROJECTILE := preload("res://scenes/enemy_projectile.tscn")
const HAZARD := preload("res://scenes/ground_hazard.tscn")
const MIN_TARGET_DISTANCE := 3.1
const PHASES: Array[BossPhaseData] = [
	preload("res://assets/data/boss/phase_1.tres"),
	preload("res://assets/data/boss/phase_2.tres"),
	preload("res://assets/data/boss/phase_3.tres"),
]

enum State {
	ARRIVING,
	HUNTING,
	CHARGING,
	SWEEPING,
	TRANSITION,
	DEFEATED,
}

@export var max_health: float = 720.0
@export var arrival_duration: float = 0.42
@export var phase_transition_duration: float = 0.36

var health: float
var target: WastelandPlayer
var phase_index: int = 0
var current_state: StringName = &"登场"
var cooldowns: Dictionary = {}

var _state: State = State.ARRIVING
var _state_remaining: float = 0.0
var _attack_cooldown: float = 0.6
var _ability_cursor: int = 0
var _dead := false
var _charge_velocity := Vector3.ZERO
var _laser_angle := 0.0
var _laser_damage_cooldown := 0.0
var _contact_damage_cooldown := 0.0
var _hit_flash_generation := 0

@onready var core: MeshInstance3D = $Core
@onready var laser: MeshInstance3D = $Laser
@onready var phase_ring: MeshInstance3D = $PhaseRing
@onready var core_light: OmniLight3D = $CoreLight


func _ready() -> void:
	add_to_group("boss")
	health = max_health
	laser.visible = false
	_apply_phase_visuals(0, false)
	_enter_state(State.ARRIVING, arrival_duration)
	scale = Vector3.ONE * 0.62
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, arrival_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_update_cooldowns(delta)
	phase_ring.rotate_y(delta * (0.85 + float(phase_index) * 0.5))
	if not is_instance_valid(target):
		velocity = Vector3.ZERO
		return

	match _state:
		State.ARRIVING, State.TRANSITION:
			_state_remaining -= delta
			velocity = Vector3.ZERO
			if _state_remaining <= 0.0:
				_enter_state(State.HUNTING)
		State.CHARGING:
			_update_charge(delta)
		State.SWEEPING:
			_update_laser(delta)
		State.HUNTING:
			_update_hunting(delta)


func _update_cooldowns(delta: float) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_laser_damage_cooldown = maxf(_laser_damage_cooldown - delta, 0.0)
	_contact_damage_cooldown = maxf(_contact_damage_cooldown - delta, 0.0)
	for key in cooldowns.keys():
		cooldowns[key] = maxf(float(cooldowns[key]) - delta, 0.0)


func _update_hunting(_delta: float) -> void:
	var phase := PHASES[phase_index]
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > 5.2:
		var move_direction := offset.normalized()
		velocity = move_direction * phase.move_speed
		look_at(global_position + move_direction, Vector3.UP)
		move_and_slide()
		_confine_to_combat_sector()
		_recover_from_terrain()
	else:
		velocity = Vector3.ZERO
		_try_contact_damage(distance)
	if _attack_cooldown <= 0.0:
		_use_next_ability(phase)


func _try_contact_damage(distance: float) -> void:
	if distance > 1.65 or _contact_damage_cooldown > 0.0:
		return
	_contact_damage_cooldown = 0.75
	target.take_damage(7.0 + float(phase_index) * 2.0)


func _use_next_ability(phase: BossPhaseData) -> void:
	if phase.abilities.is_empty():
		_attack_cooldown = phase.attack_interval
		return
	var ability: StringName = phase.abilities[_ability_cursor % phase.abilities.size()]
	_ability_cursor += 1
	cooldowns[ability] = phase.attack_interval
	_attack_cooldown = phase.attack_interval
	match ability:
		&"aimed":
			current_state = &"定向齐射"
			state_changed.emit(current_state)
			_fire_aimed(phase.projectile_count, phase.projectile_damage)
		&"charge":
			_start_charge()
		&"summon":
			current_state = &"召唤护卫"
			state_changed.emit(current_state)
			summon_requested.emit(2 + phase_index)
		&"radial", &"shockwave":
			current_state = &"环形火力"
			state_changed.emit(current_state)
			var damage_multiplier := 1.15 if ability == &"shockwave" else 1.0
			_fire_radial(phase.projectile_count, phase.projectile_damage * damage_multiplier)
		&"hazard":
			current_state = &"地面封锁"
			state_changed.emit(current_state)
			_spawn_hazard()
		&"laser":
			_start_laser()


func _fire_aimed(count: int, damage: float) -> void:
	var base := target.global_position - global_position
	base.y = 0.0
	if base.length_squared() <= 0.001:
		base = Vector3.FORWARD
	base = base.normalized()
	for index in count:
		var ratio := 0.5 if count == 1 else float(index) / float(count - 1)
		_spawn_projectile(base.rotated(Vector3.UP, deg_to_rad(lerpf(-11.0, 11.0, ratio))), damage, 14.0)


func _fire_radial(count: int, damage: float) -> void:
	for index in count:
		_spawn_projectile(Vector3.FORWARD.rotated(Vector3.UP, TAU * float(index) / float(count)), damage, 10.5)


func _spawn_projectile(direction: Vector3, damage: float, speed: float) -> void:
	var projectile := ENEMY_PROJECTILE.instantiate()
	var scene_parent := get_tree().current_scene
	if scene_parent == null:
		scene_parent = get_tree().root
	if scene_parent == null:
		projectile.queue_free()
		return
	scene_parent.add_child(projectile)
	projectile.launch(global_position + Vector3.UP * 0.85, direction, damage, speed)


func _start_charge() -> void:
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	_charge_velocity = direction.normalized() * (11.0 + float(phase_index) * 1.25)
	_enter_state(State.CHARGING, 0.52)


func _update_charge(delta: float) -> void:
	_state_remaining -= delta
	velocity = _charge_velocity
	move_and_slide()
	_confine_to_combat_sector()
	_recover_from_terrain()
	if global_position.distance_to(target.global_position) < MIN_TARGET_DISTANCE:
		target.take_damage(18.0 + float(phase_index) * 5.0)
		# The boss must damage by contact without ever occupying or physically
		# pushing the player model out of view.
		var retreat := global_position - target.global_position
		retreat.y = 0.0
		if retreat.length_squared() <= 0.001:
			retreat = Vector3.BACK
		global_position = target.global_position + retreat.normalized() * MIN_TARGET_DISTANCE
		_confine_to_combat_sector()
		velocity = Vector3.ZERO
		_state_remaining = 0.0
	if _state_remaining <= 0.0:
		_enter_state(State.HUNTING)


func _spawn_hazard() -> void:
	var hazard := HAZARD.instantiate()
	var scene_parent := get_tree().current_scene
	if scene_parent == null:
		scene_parent = get_tree().root
	if scene_parent == null:
		hazard.queue_free()
		return
	scene_parent.add_child(hazard)
	hazard.global_position = Vector3(target.global_position.x, 0.08, target.global_position.z)


func _start_laser() -> void:
	_laser_angle = atan2(target.global_position.x - global_position.x, target.global_position.z - global_position.z) - 0.7
	_laser_damage_cooldown = 0.0
	laser.visible = true
	_enter_state(State.SWEEPING, 1.55)


func _update_laser(delta: float) -> void:
	_state_remaining -= delta
	_laser_angle += delta * 0.82
	laser.rotation.y = _laser_angle
	var direction := Vector3(sin(_laser_angle), 0.0, cos(_laser_angle))
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	if to_player.length() < 13.0 and to_player.length_squared() > 0.001 and absf(direction.cross(to_player.normalized()).y) < 0.055 and _laser_damage_cooldown <= 0.0:
		_laser_damage_cooldown = 0.36
		target.take_damage(7.0 + float(phase_index) * 2.0)
	if _state_remaining <= 0.0:
		laser.visible = false
		_enter_state(State.HUNTING)


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	var applied := minf(amount, health)
	health = maxf(health - applied, 0.0)
	_hit_received(applied)
	health_changed.emit(health, max_health)
	_advance_phase_from_health()
	if health <= 0.0:
		_die()


func _hit_received(amount: float) -> void:
	hit_received.emit(amount, amount >= 30.0)
	_hit_flash_generation += 1
	var generation := _hit_flash_generation
	core.scale = Vector3.ONE * 1.34
	core_light.light_energy = 11.0 + float(phase_index) * 2.0
	get_tree().create_timer(0.10).timeout.connect(func() -> void:
		if not _dead and generation == _hit_flash_generation:
			core.scale = Vector3.ONE
			core_light.light_energy = 5.5 + float(phase_index) * 1.8
	)


func _advance_phase_from_health() -> void:
	var ratio := health / maxf(max_health, 1.0)
	var next_phase := phase_index + 1
	while next_phase < PHASES.size() and ratio <= PHASES[next_phase].health_threshold:
		_apply_phase_visuals(next_phase, true)
		next_phase += 1


func _apply_phase_visuals(index: int, announce: bool) -> void:
	phase_index = clampi(index, 0, PHASES.size() - 1)
	var phase := PHASES[phase_index]
	var material := StandardMaterial3D.new()
	material.albedo_color = phase.accent_color
	material.emission_enabled = true
	material.emission = phase.accent_color
	material.emission_energy_multiplier = 4.4
	core.material_override = material
	core_light.light_color = phase.accent_color
	core_light.light_energy = 5.5 + float(phase_index) * 1.8
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = phase.accent_color.darkened(0.18)
	ring_material.emission_enabled = true
	ring_material.emission = phase.accent_color
	ring_material.emission_energy_multiplier = 2.4 + float(phase_index)
	phase_ring.material_override = ring_material
	phase_ring.scale = Vector3.ONE * (1.0 + float(phase_index) * 0.14)
	_attack_cooldown = 0.35
	phase_changed.emit(phase_index, phase)
	if announce and not _dead:
		_enter_state(State.TRANSITION, phase_transition_duration)


func _die() -> void:
	if _dead:
		return
	_dead = true
	laser.visible = false
	collision_layer = 0
	collision_mask = 0
	_enter_state(State.DEFEATED)
	died.emit()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.65).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "rotation:y", rotation.y + PI * 0.7, 0.65)
	tween.chain().tween_callback(queue_free)


func _enter_state(next_state: State, duration: float = 0.0) -> void:
	_state = next_state
	_state_remaining = maxf(duration, 0.0)
	match next_state:
		State.ARRIVING:
			current_state = &"登场"
		State.HUNTING:
			current_state = &"追击"
		State.CHARGING:
			current_state = &"突进"
		State.SWEEPING:
			current_state = &"核心光束"
		State.TRANSITION:
			current_state = &"阶段切换"
		State.DEFEATED:
			current_state = &"核心摧毁"
	state_changed.emit(current_state)


func debug_set_phase(index: int) -> void:
	_apply_phase_visuals(index, false)
	health = max_health * PHASES[phase_index].health_threshold
	health_changed.emit(health, max_health)


func debug_set_health_ratio(ratio: float) -> void:
	health = clampf(ratio, 0.01, 1.0) * max_health
	_advance_phase_from_health()
	health_changed.emit(health, max_health)


func reset_battle() -> void:
	health = max_health
	_dead = false
	collision_layer = 4
	# Ignore the player collision layer.  Player movement still treats the boss
	# as solid, while the boss cannot shove the player below cover or off camera.
	collision_mask = 49
	laser.visible = false
	_apply_phase_visuals(0, false)
	_enter_state(State.HUNTING)
	health_changed.emit(health, max_health)


func apply_difficulty(multiplier: float) -> void:
	max_health *= maxf(multiplier, 1.0) * 1.12
	health = max_health
	health_changed.emit(health, max_health)


func _confine_to_combat_sector() -> void:
	var game := get_tree().current_scene
	if game == null:
		return
	var arena := game.get_node_or_null("Arena")
	if arena != null and arena.has_method("confine_to_combat_area"):
		global_position = arena.confine_to_combat_area(global_position, 1.65)


func _recover_from_terrain() -> void:
	var game := get_tree().current_scene
	if game == null:
		return
	var arena := game.get_node_or_null("Arena")
	if arena != null and arena.has_method("is_clear_for_boss") and not arena.is_clear_for_boss(global_position, 1.65):
		global_position = arena.nearest_clear_actor_position(global_position, 1.65)
		velocity = Vector3.ZERO
