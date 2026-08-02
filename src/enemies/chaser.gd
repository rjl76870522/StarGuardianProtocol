class_name ScrapChaser
extends CharacterBody3D

signal died(enemy: ScrapChaser)
signal hit_player
signal state_changed(state_name: String)

enum State { SPAWN, IDLE, SEARCH, CHASE, ATTACK, CONTROLLED, HURT, DEAD }

const ENEMY_PROJECTILE := preload("res://scenes/enemy_projectile.tscn")

@export var enemy_data: EnemyData
@export var move_speed: float = 2.4
@export var max_health: float = 24.0
@export var contact_damage: float = 8.0
@export var attack_interval: float = 0.95
@export var attack_range: float = 1.55
@export var decision_interval: float = 0.18

var target: WastelandPlayer
var health: float
var state: State = State.SPAWN
var _attack_cooldown: float = 0.0
var _decision_cooldown: float = 0.0
var _spawn_remaining: float = 0.22
var _hurt_remaining: float = 0.0
var _dead: bool = false
var _knockback_velocity := Vector3.ZERO
var _desired_direction := Vector3.ZERO
var _hazard_cooldown: float = 1.0
var _last_position := Vector3.ZERO
var _last_clear_position := Vector3.ZERO
var _stuck_time: float = 0.0
var _reroute_remaining: float = 0.0
var _reroute_direction := Vector3.ZERO
var _slow_multiplier := 1.0
var _slow_remaining := 0.0

@onready var hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var status_effects: StatusEffectController = $StatusEffects
@onready var telemetry: Label3D = $Telemetry


func _ready() -> void:
	_apply_data()
	_build_archetype_visual()
	health = max_health
	hit_audio.stream = SoundSynth.tone(105.0, 0.075, 0.18)
	_decision_cooldown = fmod(float(get_instance_id()) * 0.037, decision_interval)
	_last_position = global_position
	_last_clear_position = global_position
	call_deferred("_recover_from_terrain")
	_set_state(State.SPAWN)
	_update_telemetry()


func _apply_data() -> void:
	if enemy_data == null or not enemy_data.is_valid():
		return
	move_speed = enemy_data.move_speed
	max_health = enemy_data.max_health
	contact_damage = enemy_data.contact_damage
	attack_interval = enemy_data.attack_interval
	attack_range = enemy_data.attack_range
	scale = Vector3.ONE * enemy_data.scale_multiplier
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = enemy_data.body_color
	body_material.metallic = 0.88
	body_material.roughness = 0.24
	$Body.material_override = body_material
	$LeftBlade.visible = false
	$RightBlade.visible = false
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = enemy_data.core_color
	core_material.emission_enabled = true
	core_material.emission = enemy_data.core_color
	core_material.emission_energy_multiplier = 3.5 if enemy_data.elite else 2.2
	$Core.material_override = core_material
	var hull: PrimitiveMesh
	match enemy_data.archetype:
		EnemyData.Archetype.CHASER:
			var chaser_hull := BoxMesh.new()
			chaser_hull.size = Vector3(0.72, 0.68, 0.92)
			hull = chaser_hull
		EnemyData.Archetype.SHOOTER:
			var shooter_hull := BoxMesh.new()
			shooter_hull.size = Vector3(0.9, 0.38, 1.05)
			hull = shooter_hull
		EnemyData.Archetype.BOMBER:
			var bomber_hull := SphereMesh.new()
			bomber_hull.radius = 0.52
			bomber_hull.height = 0.9
			hull = bomber_hull
		EnemyData.Archetype.HEAVY:
			var heavy_hull := BoxMesh.new()
			heavy_hull.size = Vector3(1.28, 0.8, 1.1)
			hull = heavy_hull
		EnemyData.Archetype.REPAIR:
			var repair_hull := CylinderMesh.new()
			repair_hull.top_radius = 0.58
			repair_hull.bottom_radius = 0.64
			repair_hull.height = 0.34
			repair_hull.radial_segments = 12
			hull = repair_hull
		EnemyData.Archetype.MAGE:
			var mage_hull := CylinderMesh.new()
			mage_hull.top_radius = 0.36
			mage_hull.bottom_radius = 0.55
			mage_hull.height = 1.05
			mage_hull.radial_segments = 6
			hull = mage_hull
	$Body.mesh = hull
	$Body.scale = Vector3.ONE


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	_update_telemetry()
	_hazard_cooldown = maxf(_hazard_cooldown - delta, 0.0)
	_slow_remaining = maxf(_slow_remaining - delta, 0.0)
	if _slow_remaining <= 0.0:
		_slow_multiplier = 1.0
	if _spawn_remaining > 0.0:
		_spawn_remaining -= delta
		velocity = Vector3.ZERO
		if _spawn_remaining <= 0.0:
			_set_state(State.SEARCH)
		return
	if _hurt_remaining > 0.0:
		_hurt_remaining -= delta
		if _hurt_remaining <= 0.0:
			_set_state(State.SEARCH)
	if status_effects.movement_multiplier() <= 0.0:
		_set_state(State.CONTROLLED)
		velocity = Vector3.ZERO
		return
	elif state == State.CONTROLLED:
		_set_state(State.SEARCH)
	if _knockback_velocity.length_squared() > 0.05:
		velocity = _knockback_velocity
		move_and_slide()
		_confine_to_combat_sector()
		_recover_from_terrain()
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 24.0 * delta)
		return
	if not is_instance_valid(target) or target.is_dead:
		_set_state(State.IDLE)
		velocity = Vector3.ZERO
		return
	_decision_cooldown -= delta
	if _decision_cooldown <= 0.0:
		_decision_cooldown = decision_interval
		_update_decision()
	_execute_behavior(delta)


func _update_decision() -> void:
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if _reroute_remaining > 0.0:
		_reroute_remaining = maxf(_reroute_remaining - decision_interval, 0.0)
		_set_state(State.CHASE)
		_desired_direction = _reroute_direction
		return
	if distance > (enemy_data.detection_range if enemy_data != null else 24.0):
		_set_state(State.SEARCH)
		_desired_direction = offset.normalized()
	elif distance <= attack_range:
		_set_state(State.ATTACK)
	else:
		_set_state(State.CHASE)
		_desired_direction = offset.normalized()
	if global_position.distance_to(_last_position) < 0.08 and state == State.CHASE:
		_stuck_time += decision_interval
	else:
		_stuck_time = 0.0
	_last_position = global_position
	if _stuck_time > 0.7:
		_set_reroute_direction()
		_stuck_time = 0.0


func _execute_behavior(delta: float) -> void:
	if state == State.CHASE or state == State.SEARCH:
		velocity = _desired_direction * move_speed * status_effects.movement_multiplier() * _slow_multiplier
		if _desired_direction.length_squared() > 0.01:
			look_at(global_position + _desired_direction, Vector3.UP)
		move_and_slide()
		_confine_to_combat_sector()
		_register_slide_reroute()
		_recover_from_terrain()
		return
	velocity = Vector3.ZERO
	if state != State.ATTACK or _attack_cooldown > 0.0:
		return
	_attack_cooldown = attack_interval
	var archetype := enemy_data.archetype if enemy_data != null else EnemyData.Archetype.CHASER
	match archetype:
		EnemyData.Archetype.SHOOTER:
			_fire_at_player()
		EnemyData.Archetype.BOMBER:
			_explode()
		EnemyData.Archetype.REPAIR:
			_repair_nearest_ally()
		EnemyData.Archetype.MAGE:
			_fire_radial(3, contact_damage * 0.72)
		_:
			target.take_damage(contact_damage)
			hit_player.emit()
	if enemy_data != null and enemy_data.leaves_hazard and _hazard_cooldown <= 0.0:
		_hazard_cooldown = 1.2
		_fire_radial(6, contact_damage * 0.45)


func _fire_at_player() -> void:
	var projectile = ENEMY_PROJECTILE.instantiate()
	get_tree().current_scene.add_child(projectile)
	projectile.launch(global_position + Vector3.UP * 0.4, target.global_position - global_position, contact_damage, enemy_data.projectile_speed)


func _fire_radial(count: int, projectile_damage: float) -> void:
	for index in count:
		var projectile = ENEMY_PROJECTILE.instantiate()
		get_tree().current_scene.add_child(projectile)
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(index) / float(count))
		projectile.launch(global_position + Vector3.UP * 0.4, direction, projectile_damage, 9.0)


func _explode() -> void:
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range + 0.5:
		target.take_damage(contact_damage)
		hit_player.emit()
	take_damage(health + 1.0)


func _repair_nearest_ally() -> void:
	var best: ScrapChaser
	var best_distance := attack_range
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if candidate == self or not candidate is ScrapChaser:
			continue
		var ally := candidate as ScrapChaser
		var distance := global_position.distance_to(ally.global_position)
		if distance < best_distance and ally.health < ally.max_health:
			best = ally
			best_distance = distance
	if best != null:
		best.heal(enemy_data.repair_amount)
		best.apply_support_boost(1.28, 3.5)
	else:
		_summon_support_guard()


func heal(amount: float) -> void:
	if not _dead:
		health = minf(health + maxf(amount, 0.0), max_health)


func apply_support_boost(multiplier: float, duration: float) -> void:
	var safe_multiplier := clampf(multiplier, 0.35, 2.5)
	contact_damage *= safe_multiplier
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not _dead:
			contact_damage /= safe_multiplier
	)


func _summon_support_guard() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= 18:
		_fire_at_player()
		return
	var guard := preload("res://scenes/chaser.tscn").instantiate() as ScrapChaser
	guard.enemy_data = preload("res://assets/data/enemies/chaser.tres") as EnemyData
	guard.target = target
	guard.global_position = global_position + Vector3(0.9, 0.0, 0.9)
	guard.add_to_group("enemies")
	get_parent().add_child(guard)
	var game := get_tree().current_scene
	if game != null and game.has_method("_on_enemy_died"):
		guard.died.connect(Callable(game, "_on_enemy_died"))
	if game != null and game.has_method("_on_player_hit"):
		guard.hit_player.connect(Callable(game, "_on_player_hit"))


func _update_telemetry() -> void:
	if telemetry == null:
		return
	var state := get_node_or_null("/root/GameState")
	telemetry.visible = state == null or bool(state.show_combat_telemetry)
	if not telemetry.visible:
		return
	var blocks := clampi(int(round((health / maxf(max_health, 1.0)) * 8.0)), 0, 8)
	telemetry.text = "█".repeat(blocks) + "░".repeat(8 - blocks)


func apply_difficulty(multiplier: float) -> void:
	# Base enemies must stay threatening even before the endless curve accelerates.
	var safe_multiplier := maxf(multiplier, 1.0) * 1.22
	max_health *= safe_multiplier
	health = max_health
	contact_damage *= 1.14 + (safe_multiplier - 1.0) * 0.62


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	health -= amount
	_set_state(State.HURT)
	_hurt_remaining = 0.08
	hit_audio.play()
	$Core.scale = Vector3.ONE * 1.7
	create_tween().tween_property($Core, "scale", Vector3.ONE, 0.1)
	if health <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	_set_state(State.DEAD)
	collision_layer = 0
	collision_mask = 0
	died.emit(self)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3(1.5, 0.05, 1.5), 0.18)
	tween.tween_property(self, "rotation:y", rotation.y + PI, 0.18)
	tween.chain().tween_callback(queue_free)


func apply_status_effect(effect: StatusEffectData, source_direction: Vector3 = Vector3.ZERO) -> bool:
	return status_effects.apply_effect(effect, source_direction)


func apply_knockback(force: Vector3) -> void:
	_knockback_velocity += Vector3(force.x, 0.0, force.z)


func apply_slow(multiplier: float, duration: float) -> void:
	_slow_multiplier = minf(_slow_multiplier, clampf(multiplier, 0.18, 1.0))
	_slow_remaining = maxf(_slow_remaining, duration)


func get_state_name() -> String:
	return State.keys()[state]


func _set_state(next_state: State) -> void:
	if state == next_state:
		return
	state = next_state
	state_changed.emit(get_state_name())


func _confine_to_combat_sector() -> void:
	var game := get_tree().current_scene
	if game == null:
		return
	var arena := game.get_node_or_null("Arena")
	if arena != null and arena.has_method("confine_to_combat_area"):
		global_position = arena.confine_to_combat_area(global_position, 0.58 * maxf(scale.x, 0.8))


func _register_slide_reroute() -> void:
	if get_slide_collision_count() <= 0:
		return
	var collision := get_slide_collision(0)
	var normal := collision.get_normal()
	var tangent := Vector3(-normal.z, 0.0, normal.x).normalized()
	if tangent.length_squared() <= 0.001:
		return
	if is_instance_valid(target):
		var toward_target := target.global_position - global_position
		toward_target.y = 0.0
		if tangent.dot(toward_target) < 0.0:
			tangent *= -1.0
	_reroute_direction = tangent
	_reroute_remaining = maxf(_reroute_remaining, 0.55)


func _set_reroute_direction() -> void:
	var base := _desired_direction
	if base.length_squared() <= 0.001 and is_instance_valid(target):
		base = target.global_position - global_position
		base.y = 0.0
	if base.length_squared() <= 0.001:
		base = Vector3.FORWARD
	var sign := -1.0 if get_instance_id() % 2 == 0 else 1.0
	_reroute_direction = base.normalized().rotated(Vector3.UP, sign * PI * 0.5)
	_reroute_remaining = 0.8


func _recover_from_terrain() -> void:
	var game := get_tree().current_scene
	if game == null:
		return
	var arena := game.get_node_or_null("Arena")
	if arena == null or not arena.has_method("is_clear_for_actor"):
		return
	var clearance := 0.58 * maxf(scale.x, 0.8)
	if arena.is_clear_for_actor(global_position, clearance):
		_last_clear_position = global_position
		return
	var recovered := _last_clear_position
	if not arena.is_clear_for_actor(recovered, clearance):
		recovered = arena.nearest_clear_actor_position(global_position, clearance)
	global_position = recovered
	velocity = Vector3.ZERO
	_set_reroute_direction()


func _build_archetype_visual() -> void:
	if enemy_data == null:
		return
	var details := Node3D.new()
	details.name = "ArchetypeDetails"
	details.set_meta("profile", enemy_data.enemy_id)
	add_child(details)
	var accent := enemy_data.core_color
	match enemy_data.archetype:
		EnemyData.Archetype.CHASER:
			# Forward-leaning blades and a narrow head make the fast melee unit readable.
			_add_box(details, Vector3(0.0, 1.05, 0.0), Vector3(0.48, 0.32, 0.42), enemy_data.body_color.lightened(0.16))
			_add_box(details, Vector3(0.0, 0.72, -0.62), Vector3(0.16, 0.16, 0.45), accent, 0.0)
			for side in [-1.0, 1.0]:
				_add_box(details, Vector3(side * 0.32, 0.25, 0.18), Vector3(0.18, 0.32, 0.55), enemy_data.body_color.darkened(0.15), side * 0.12)
		EnemyData.Archetype.SHOOTER:
			# Wide stabilizers plus a long barrel read as a ranged artillery silhouette.
			_add_box(details, Vector3(-0.62, 0.67, 0.0), Vector3(0.5, 0.08, 0.75), enemy_data.body_color.lightened(0.15), -0.16)
			_add_box(details, Vector3(0.62, 0.67, 0.0), Vector3(0.5, 0.08, 0.75), enemy_data.body_color.lightened(0.15), 0.16)
			_add_box(details, Vector3(0.0, 0.7, -0.72), Vector3(0.15, 0.15, 0.85), accent)
			_add_cylinder(details, Vector3(0.0, 0.72, -1.05), 0.13, 0.34, accent)
		EnemyData.Archetype.BOMBER:
			# A spherical charge body with a bright fuse makes its self-destruct role obvious.
			for index in 4:
				var angle := TAU * float(index) / 4.0
				_add_box(details, Vector3(cos(angle) * 0.62, 0.68, sin(angle) * 0.62), Vector3(0.12, 0.16, 0.65), accent, angle)
			_add_cylinder(details, Vector3(0.0, 1.0, 0.0), 0.28, 0.08, accent)
			_add_sphere(details, Vector3(0.0, 1.23, 0.0), 0.16, Color("fff1a6"), true)
		EnemyData.Archetype.HEAVY:
			# Heavy armor plates and a raised command block distinguish the tank unit.
			_add_box(details, Vector3(-0.48, 0.72, 0.0), Vector3(0.32, 0.72, 1.0), enemy_data.body_color.lightened(0.16))
			_add_box(details, Vector3(0.48, 0.72, 0.0), Vector3(0.32, 0.72, 1.0), enemy_data.body_color.lightened(0.16))
			_add_box(details, Vector3(0.0, 1.02, 0.18), Vector3(0.72, 0.24, 0.62), accent.darkened(0.25))
			_add_box(details, Vector3(0.0, 1.18, -0.28), Vector3(0.38, 0.26, 0.3), enemy_data.body_color.lightened(0.22))
		EnemyData.Archetype.REPAIR:
			# A hovering repair halo and cross-shaped emitter identify the support unit.
			_add_cylinder(details, Vector3(0.0, 0.92, 0.0), 0.68, 0.08, accent)
			_add_box(details, Vector3(0.0, 1.18, 0.0), Vector3(0.12, 0.42, 0.12), accent)
			_add_box(details, Vector3(0.0, 1.18, 0.0), Vector3(0.42, 0.12, 0.12), accent)
		EnemyData.Archetype.MAGE:
			# Tall spire, floating crown and side pylons signal area-control attacks.
			_add_cylinder(details, Vector3(0.0, 1.28, 0.0), 0.62, 0.08, accent)
			_add_box(details, Vector3(0.0, 1.52, 0.0), Vector3(0.16, 0.65, 0.16), accent)
			_add_box(details, Vector3(-0.42, 1.04, 0.0), Vector3(0.12, 0.45, 0.12), accent, 0.25)
			_add_box(details, Vector3(0.42, 1.04, 0.0), Vector3(0.12, 0.45, 0.12), accent, -0.25)
			_add_sphere(details, Vector3(0.0, 1.76, 0.0), 0.14, accent, true)
	if enemy_data.elite:
		_add_cylinder(details, Vector3(0.0, 1.2, 0.0), 0.68, 0.08, accent)


func _add_box(parent: Node3D, at: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.rotation.y = yaw
	visual.material_override = _detail_material(color)
	parent.add_child(visual)


func _add_cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	visual.mesh = mesh
	visual.position = at
	visual.material_override = _detail_material(color, true)
	parent.add_child(visual)


func _add_sphere(parent: Node3D, at: Vector3, radius: float, color: Color, emissive: bool = false) -> void:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	visual.mesh = mesh
	visual.position = at
	visual.material_override = _detail_material(color, emissive)
	parent.add_child(visual)


func _detail_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.82
	material.roughness = 0.32
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material
