class_name WastelandPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
signal fired(recoil: float)
signal dash_started
signal weapon_changed(weapon: WeaponData, index: int)
signal skill_upgraded(skill: SkillData, level: int)
signal action_message(message: String)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const DRONE_SCENE := preload("res://scenes/orbit_drone.tscn")
const WEAPON_CATALOG = [
	preload("res://assets/data/weapons/auto_rifle.tres"),
	preload("res://assets/data/weapons/scatter_cannon.tres"),
	preload("res://assets/data/weapons/rail_lance.tres"),
]

@export var move_speed: float = 8.0
@export var acceleration: float = 34.0
@export var max_health: float = 160.0
@export var fire_interval: float = 0.13
@export var dash_speed: float = 22.0
@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.85
@export var invulnerability_duration: float = 0.24
@export var hit_invulnerability_duration: float = 0.65

var health: float
var is_dead: bool = false
var is_invulnerable: bool = false
var current_weapon: WeaponData
var weapon_index: int = 0
var skill_system := SkillSystem.new()
var _fire_cooldown: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_remaining: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _invulnerability_generation: int = 0
var _rng := RandomNumberGenerator.new()

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var muzzle: Marker3D = $Body/Muzzle
@onready var weapon_audio: AudioStreamPlayer = $WeaponAudio
@onready var dash_audio: AudioStreamPlayer = $DashAudio


func _ready() -> void:
	health = max_health
	_rng.randomize()
	dash_audio.stream = SoundSynth.tone(170.0, 0.13, 0.2)
	equip_weapon(0)
	_restore_campaign_skills()
	health_changed.emit(health, max_health)


func _restore_campaign_skills() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return
	for skill in [
		preload("res://assets/data/skills/rapid_fire.tres"),
		preload("res://assets/data/skills/move_speed.tres"),
		preload("res://assets/data/skills/ricochet.tres"),
		preload("res://assets/data/skills/penetration.tres"),
		preload("res://assets/data/skills/kill_heal.tres"),
		preload("res://assets/data/skills/orbit_drone.tres"),
		preload("res://assets/data/skills/combat_core.tres"),
		preload("res://assets/data/skills/critical_matrix.tres"),
		preload("res://assets/data/skills/armor_plating.tres"),
	]:
		var target_level := int(game_state.carried_skill_levels.get(skill.skill_id, 0))
		for level in target_level:
			skill_system.apply_upgrade(skill)
		if skill.skill_id == &"orbit_drone" and target_level > 0:
			_sync_drones(int(skill.value_for_level(target_level)))
		elif skill.skill_id == &"armor_plating" and target_level > 0:
			max_health = 160.0 + skill.value_for_level(target_level)
			health = max_health


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	_handle_weapon_input()

	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := Vector3(input_2d.x, 0.0, input_2d.y).normalized()
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and move_direction != Vector3.ZERO:
		_start_dash(move_direction)

	if _dash_remaining > 0.0:
		_dash_remaining -= delta
		velocity = _dash_direction * dash_speed
	else:
		var speed_multiplier := skill_system.get_value(&"move_speed", 1.0)
		velocity = velocity.move_toward(move_direction * move_speed * speed_multiplier, acceleration * delta)

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
		aim_at_world_point(hit as Vector3)


func aim_at_world_point(target: Vector3) -> void:
	var flat := target - global_position
	flat.y = 0.0
	if flat.length_squared() <= 0.05:
		return
	var body_origin: Vector3 = $Body.global_position
	$Body.look_at(Vector3(target.x, body_origin.y, target.z), Vector3.UP)


func _handle_weapon_input() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		equip_weapon(0)
	elif Input.is_action_just_pressed("weapon_2"):
		equip_weapon(1)
	elif Input.is_action_just_pressed("weapon_3"):
		equip_weapon(2)


func equip_weapon(index: int) -> bool:
	if index < 0 or index >= WEAPON_CATALOG.size():
		return false
	var candidate := WEAPON_CATALOG[index] as WeaponData
	if candidate == null or not candidate.is_valid():
		push_warning("Rejected invalid weapon configuration at index %d" % index)
		return false
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null and not game_state.is_weapon_unlocked(candidate.weapon_id):
		action_message.emit("%s 尚未解锁，请通过关卡奖励获得" % candidate.display_name)
		return false
	weapon_index = index
	current_weapon = candidate
	fire_interval = current_weapon.fire_interval
	weapon_audio.stream = SoundSynth.tone(
		current_weapon.sfx.frequency,
		current_weapon.sfx.duration,
		current_weapon.sfx.amplitude
	)
	weapon_changed.emit(current_weapon, weapon_index)
	return true


func _try_fire() -> bool:
	if _fire_cooldown > 0.0 or current_weapon == null or not current_weapon.is_valid():
		return false
	var fire_rate_multiplier := skill_system.get_value(&"rapid_fire", 1.0)
	_fire_cooldown = current_weapon.fire_interval / maxf(fire_rate_multiplier, 0.1)
	var projectile_parent := get_tree().current_scene
	if projectile_parent == null:
		projectile_parent = get_parent()
	var aim: Vector3 = -$Body.global_transform.basis.z
	var base_direction := Vector3(aim.x, 0.0, aim.z).normalized()
	for projectile_index in current_weapon.projectile_count:
		var projectile := PROJECTILE_SCENE.instantiate()
		projectile_parent.add_child(projectile)
		var spread_ratio := 0.5
		if current_weapon.projectile_count > 1:
			spread_ratio = float(projectile_index) / float(current_weapon.projectile_count - 1)
		var spread_angle := deg_to_rad(lerpf(
			-current_weapon.spread_degrees * 0.5,
			current_weapon.spread_degrees * 0.5,
			spread_ratio
		))
		if current_weapon.projectile_count == 1 and current_weapon.spread_degrees > 0.0:
			spread_angle = deg_to_rad(_rng.randf_range(
				-current_weapon.spread_degrees * 0.5,
				current_weapon.spread_degrees * 0.5
			))
		var weapon_level := _weapon_level(current_weapon.weapon_id)
		var weapon_multiplier := 1.0 + float(maxi(weapon_level - 1, 0)) * 0.18
		var skill_damage_multiplier := skill_system.get_value(&"combat_core", 1.0)
		projectile.configure(
			current_weapon,
			weapon_multiplier * skill_damage_multiplier,
			int(skill_system.get_value(&"penetration", 0.0)),
			int(skill_system.get_value(&"ricochet", 0.0))
		)
		projectile.critical_chance = clampf(
			projectile.critical_chance + skill_system.get_value(&"critical_matrix", 0.0),
			0.0,
			0.95
		)
		projectile.launch(muzzle.global_position, base_direction.rotated(Vector3.UP, spread_angle))
	weapon_audio.play()
	fired.emit(current_weapon.recoil)
	return true


func apply_skill(skill: SkillData) -> bool:
	if not skill_system.apply_upgrade(skill):
		return false
	var level := skill_system.get_level(skill.skill_id)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.record_skill(skill.skill_id, level)
	if skill.skill_id == &"orbit_drone":
		_sync_drones(int(skill.value_for_level(level)))
	elif skill.skill_id == &"combat_core":
		_sync_drones(int(skill_system.get_value(&"orbit_drone", 0.0)))
	elif skill.skill_id == &"armor_plating":
		var previous_max := max_health
		max_health = 160.0 + skill.value_for_level(level)
		health = minf(health + max_health - previous_max, max_health)
		health_changed.emit(health, max_health)
	skill_upgraded.emit(skill, level)
	return true


func _weapon_level(weapon_id: StringName) -> int:
	var game_state := get_node_or_null("/root/GameState")
	return int(game_state.weapon_level(weapon_id)) if game_state != null else 1


func on_kill() -> void:
	var heal_amount := skill_system.get_value(&"kill_heal", 0.0)
	if heal_amount <= 0.0 or is_dead:
		return
	health = minf(health + heal_amount, max_health)
	health_changed.emit(health, max_health)


func _sync_drones(target_count: int) -> void:
	var existing := get_tree().get_nodes_in_group("player_drones")
	while existing.size() < target_count:
		var drone = DRONE_SCENE.instantiate()
		add_child(drone)
		drone.add_to_group("player_drones")
		existing.append(drone)
	for index in existing.size():
		existing[index].configure(index, existing.size(), skill_system.get_value(&"combat_core", 1.0))


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
