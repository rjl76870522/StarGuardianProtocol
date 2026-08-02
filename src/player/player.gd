class_name WastelandPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
signal fired(recoil: float)
signal dash_started
signal weapon_changed(weapon: WeaponData, index: int)
signal skill_upgraded(skill: SkillData, level: int)
signal action_message(message: String)
signal interaction_hint(message: String)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const DRONE_SCENE := preload("res://scenes/orbit_drone.tscn")
const WEAPON_PICKUP := preload("res://src/world/weapon_pickup.gd")
const PLAYER_GADGET := preload("res://src/combat/player_gadget.gd")
const WEAPON_CATALOG = [
	preload("res://assets/data/weapons/flame_projector.tres"),
	preload("res://assets/data/weapons/auto_rifle.tres"),
	preload("res://assets/data/weapons/scatter_cannon.tres"),
	preload("res://assets/data/weapons/rail_lance.tres"),
	preload("res://assets/data/weapons/arc_blade.tres"),
	preload("res://assets/data/weapons/sidearm.tres"),
	preload("res://assets/data/weapons/sniper_rifle.tres"),
	preload("res://assets/data/weapons/siege_cannon.tres"),
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
var weapon_loadout: Array[WeaponData] = []
var skill_system := SkillSystem.new()
var _fire_cooldown: float = 0.0
var _dash_cooldown: float = 0.0
var _dash_remaining: float = 0.0
var _dash_direction: Vector3 = Vector3.ZERO
var _invulnerability_generation: int = 0
var _rng := RandomNumberGenerator.new()
var _pulse_cooldown: float = 0.0
var _mounted: bool = false
var _mount_visual: Node3D
var _home_mode := false
var _last_interaction_hint := ""
var _touch_aim_position := Vector2.ZERO
var _gadget_cooldowns: Dictionary = {&"shock": 0.0, &"fire": 0.0, &"emp": 0.0}
var _active_skill_cooldowns: Dictionary = {&"fury": 0.0, &"recovery": 0.0, &"bounce": 0.0, &"tracking": 0.0}
var _active_fury_remaining := 0.0
var _active_bounce_remaining := 0.0
var _active_tracking_remaining := 0.0

@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var muzzle: Marker3D = $Body/Muzzle
@onready var weapon_audio: AudioStreamPlayer = $WeaponAudio
@onready var dash_audio: AudioStreamPlayer = $DashAudio


func _ready() -> void:
	health = max_health
	_rng.randomize()
	add_to_group("player")
	dash_audio.stream = SoundSynth.tone(170.0, 0.13, 0.2)
	_apply_skin()
	_restore_weapon_loadout()
	equip_weapon(0)
	_restore_campaign_skills()
	health_changed.emit(health, max_health)
	# The player is rebuilt when every stage scene loads.  Keep the generated
	# starfighter frame explicit so a deferred mesh cleanup can never leave the
	# controllable unit without a visible model on later stages.
	call_deferred("ensure_combat_presence")


func ensure_combat_presence() -> void:
	if is_dead:
		return
	visible = true
	$Body.visible = true
	var frame := $Body.get_node_or_null("StarfighterFrame") as Node3D
	if frame == null or not is_instance_valid(frame):
		_apply_skin()
		frame = $Body.get_node_or_null("StarfighterFrame") as Node3D
	if frame != null:
		frame.visible = true
		for child in frame.get_children():
			if child is VisualInstance3D:
				(child as VisualInstance3D).visible = true
	var accents := $Body.get_node_or_null("SkinAccents") as Node3D
	if accents != null:
		accents.visible = true


func _apply_skin() -> void:
	var state := get_node_or_null("/root/GameState")
	var skin_id: StringName = state.equipped_skin if state != null else &"prism_guardian"
	var colors := {
		&"prism_guardian": [Color("24365f"), Color("65e8ff")],
		&"red_guardian": [Color("4b1024"), Color("ff466b")],
		&"orange_guardian": [Color("4a2508"), Color("ff9f43")],
		&"yellow_guardian": [Color("453a06"), Color("ffe66d")],
		&"green_guardian": [Color("0d472f"), Color("55e69d")],
		&"cyan_guardian": [Color("084550"), Color("4dd7ff")],
		&"blue_guardian": [Color("142c64"), Color("628cff")],
		&"violet_guardian": [Color("35185f"), Color("c77dff")],
	}
	var palette: Array = colors.get(skin_id, colors[&"prism_guardian"])
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = palette[0]
	body_material.metallic = 0.88
	body_material.roughness = 0.22
	$Body/Chassis.material_override = body_material
	$Body/UpperArmor.material_override = body_material
	var glow_material := StandardMaterial3D.new()
	glow_material.albedo_color = palette[1]
	glow_material.emission_enabled = true
	glow_material.emission = palette[1]
	glow_material.emission_energy_multiplier = 3.6
	$Body/Core.material_override = glow_material
	$Body/Antenna.material_override = glow_material
	$Body/CoreLight.light_color = palette[1]
	var prism_colors: Array[Color] = []
	if skin_id == &"prism_guardian":
		for color in [Color("ff4d6d"), Color("ff9f43"), Color("ffe66d"), Color("52e08c"), Color("4dd7ff"), Color("6f7dff"), Color("c77dff")]:
			prism_colors.append(color)
	_build_starfighter_frame(palette[0], palette[1], prism_colors)
	_add_skin_accents(palette[1])


func _build_starfighter_frame(hull_color: Color, glow_color: Color, prism_colors: Array[Color] = []) -> void:
	var previous := $Body.get_node_or_null("StarfighterFrame")
	if previous != null:
		previous.queue_free()
	for node_name in ["Chassis", "UpperArmor", "Canopy", "LeftWheel", "RightWheel", "LeftTrackGuard", "RightTrackGuard", "LeftFin", "RightFin", "Antenna"]:
		var node := $Body.get_node_or_null(node_name)
		if node is VisualInstance3D:
			node.visible = false
	var frame := Node3D.new()
	frame.name = "StarfighterFrame"
	$Body.add_child(frame)
	_add_ship_box(frame, Vector3(0.0, 0.22, 0.02), Vector3(0.68, 0.38, 1.42), hull_color)
	_add_ship_box(frame, Vector3(0.0, 0.3, -0.76), Vector3(0.4, 0.22, 0.48), prism_colors[0] if not prism_colors.is_empty() else hull_color.lightened(0.1))
	_add_ship_box(frame, Vector3(0.0, 0.47, -0.12), Vector3(0.42, 0.22, 0.5), glow_color.darkened(0.5), true)
	for side in [-1.0, 1.0]:
		var wing_color := prism_colors[1] if side < 0.0 and not prism_colors.is_empty() else prism_colors[5] if not prism_colors.is_empty() else hull_color.lightened(0.06)
		_add_ship_box(frame, Vector3(side * 0.63, 0.2, 0.04), Vector3(0.72, 0.09, 0.72), wing_color, false, side * 0.18)
		_add_ship_engine(frame, Vector3(side * 0.24, 0.18, 0.73), prism_colors[4] if not prism_colors.is_empty() else glow_color)
	if not prism_colors.is_empty():
		for index in prism_colors.size():
			_add_ship_box(frame, Vector3(-0.27 + index * 0.09, 0.45, 0.2), Vector3(0.065, 0.035, 0.86), prism_colors[index], true)


func _add_ship_box(parent: Node3D, at: Vector3, size: Vector3, color: Color, emissive: bool = false, yaw: float = 0.0) -> void:
	var part := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	part.rotation.y = yaw
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.86
	material.roughness = 0.22
	if emissive:
		material.emission_enabled = true
		material.emission = color.lightened(0.2)
		material.emission_energy_multiplier = 1.8
	part.material_override = material
	parent.add_child(part)


func _add_ship_engine(parent: Node3D, at: Vector3, color: Color) -> void:
	var engine := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.13
	mesh.bottom_radius = 0.18
	mesh.height = 0.34
	mesh.radial_segments = 12
	engine.mesh = mesh
	engine.position = at
	engine.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	engine.material_override = material
	parent.add_child(engine)


func _add_skin_accents(color: Color) -> void:
	var existing := $Body.get_node_or_null("SkinAccents")
	if existing != null:
		existing.queue_free()
	var accents := Node3D.new()
	accents.name = "SkinAccents"
	for side in [-1.0, 1.0]:
		var fin := MeshInstance3D.new()
		# Use BoxMesh rather than a platform-sensitive custom primitive so player
		# initialization remains identical on every export target.
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.16, 0.34, 0.72)
		fin.mesh = mesh
		fin.position = Vector3(side * 0.63, 0.48, -0.14)
		fin.rotation.y = side * 0.42
		var material := StandardMaterial3D.new()
		material.albedo_color = color.darkened(0.22)
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.2
		fin.material_override = material
		accents.add_child(fin)
	$Body.add_child(accents)


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
		preload("res://assets/data/skills/split_rounds.tres"),
		preload("res://assets/data/skills/phase_rounds.tres"),
	]:
		var target_level := int(game_state.carried_skill_levels.get(skill.skill_id, 0))
		for level in target_level:
			skill_system.apply_upgrade(skill)
		if skill.skill_id == &"orbit_drone":
			_sync_drones(_companion_count())
		elif skill.skill_id == &"armor_plating" and target_level > 0:
			max_health = 160.0 + skill.value_for_level(target_level)
			health = max_health
	_apply_home_training()


func _apply_home_training() -> void:
	var state := get_node_or_null("/root/GameState")
	if state == null:
		return
	var recovery_level: int = state.home_skill_level(&"recovery")
	max_health += state.garden_level * 18.0
	health = max_health
	if recovery_level > 0:
		max_health += recovery_level * 10.0
		health = max_health


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_fire_cooldown = maxf(_fire_cooldown - delta, 0.0)
	_pulse_cooldown = maxf(_pulse_cooldown - delta, 0.0)
	for gadget_id in _gadget_cooldowns:
		_gadget_cooldowns[gadget_id] = maxf(float(_gadget_cooldowns[gadget_id]) - delta, 0.0)
	for skill_id in _active_skill_cooldowns:
		_active_skill_cooldowns[skill_id] = maxf(float(_active_skill_cooldowns[skill_id]) - delta, 0.0)
	_active_fury_remaining = maxf(_active_fury_remaining - delta, 0.0)
	_active_bounce_remaining = maxf(_active_bounce_remaining - delta, 0.0)
	_active_tracking_remaining = maxf(_active_tracking_remaining - delta, 0.0)
	_dash_cooldown = maxf(_dash_cooldown - delta, 0.0)
	if not _home_mode:
		_handle_weapon_input()
		_handle_gadget_input()
		_handle_weapon_interaction()
		_update_interaction_hint()
		if Input.is_action_just_pressed("mount"):
			_toggle_mount()
		_handle_active_skill_input()

	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := Vector3(input_2d.x, 0.0, input_2d.y).normalized()
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0 and move_direction != Vector3.ZERO:
		_start_dash(move_direction)

	if _dash_remaining > 0.0:
		_dash_remaining -= delta
		velocity = _dash_direction * dash_speed
	else:
		var speed_multiplier := skill_system.get_value(&"move_speed", 1.0) * (1.42 if _mounted else 1.0)
		velocity = velocity.move_toward(move_direction * move_speed * speed_multiplier, acceleration * delta)

	_update_aim()
	if not _home_mode and Input.is_action_pressed("shoot"):
		_try_fire()
	if not _home_mode and Input.is_action_just_pressed("pulse"):
		_try_pulse()
	move_and_slide()
	if not _home_mode:
		_confine_to_combat_sector()


func _confine_to_combat_sector() -> void:
	var game := get_tree().current_scene
	if game == null:
		return
	var arena := game.get_node_or_null("Arena")
	if arena != null and arena.has_method("confine_to_combat_area"):
		global_position = arena.confine_to_combat_area(global_position, 0.52)


func set_home_mode(enabled: bool) -> void:
	_home_mode = enabled
	if enabled:
		_set_interaction_hint("")
	if enabled and _mounted:
		_toggle_mount()


func _update_aim() -> void:
	if OS.has_feature("mobile") and _touch_aim_position == Vector2.ZERO:
		var nearest_enemy: Node3D
		var nearest_distance := INF
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if candidate is Node3D:
				var enemy := candidate as Node3D
				var distance := global_position.distance_squared_to(enemy.global_position)
				if distance < nearest_distance:
					nearest_enemy = enemy
					nearest_distance = distance
		if nearest_enemy != null:
			aim_at_world_point(nearest_enemy.global_position)
			return
	var aim_screen := _touch_aim_position if OS.has_feature("mobile") and _touch_aim_position != Vector2.ZERO else get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(aim_screen)
	var ray_direction := camera.project_ray_normal(aim_screen)
	var floor_plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = floor_plane.intersects_ray(ray_origin, ray_direction)
	if hit is Vector3:
		aim_at_world_point(hit as Vector3)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.has_feature("mobile"):
		return
	if event is InputEventScreenTouch and event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
		_touch_aim_position = event.position
	elif event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x * 0.42:
		_touch_aim_position = event.position


func aim_at_world_point(target: Vector3) -> void:
	var flat := target - global_position
	flat.y = 0.0
	if flat.length_squared() <= 0.05:
		return
	var body_origin: Vector3 = $Body.global_position
	$Body.look_at(Vector3(target.x, body_origin.y, target.z), Vector3.UP)


func _handle_weapon_input() -> void:
	for index in mini(weapon_loadout.size(), 5):
		if Input.is_action_just_pressed("weapon_%d" % (index + 1)):
			equip_weapon(index)
			return


func _handle_active_skill_input() -> void:
	if Input.is_action_just_pressed("active_fury"):
		_activate_training_skill(&"fury")
	if Input.is_action_just_pressed("active_recovery"):
		_activate_training_skill(&"recovery")
	if Input.is_action_just_pressed("active_bounce"):
		_activate_training_skill(&"bounce")
	if Input.is_action_just_pressed("active_tracking"):
		_activate_training_skill(&"tracking")


func _activate_training_skill(skill_id: StringName) -> void:
	# The four tactical skills are part of the standard combat kit.  Base level
	# one is available in every new run; home research raises the same skill.
	var level := active_skill_level(skill_id)
	if level <= 0 or float(_active_skill_cooldowns.get(skill_id, 0.0)) > 0.0:
		return
	match skill_id:
		&"fury":
			_active_fury_remaining = 2.5 + level * 0.45
			_active_skill_cooldowns[skill_id] = maxf(18.0 - level, 10.0)
			action_message.emit("暴怒回路启动  ·  短时间射速大幅提升")
		&"recovery":
			var amount := 22.0 + level * 12.0
			health = minf(health + amount, max_health)
			health_changed.emit(health, max_health)
			_active_skill_cooldowns[skill_id] = maxf(28.0 - level * 2.0, 16.0)
			action_message.emit("纳米修复完成  ·  回复 %d 生命" % int(amount))
		&"bounce":
			_active_bounce_remaining = 3.5 + level * 0.35
			_active_skill_cooldowns[skill_id] = maxf(20.0 - level, 12.0)
			action_message.emit("反弹协议启动  ·  接下来子弹额外弹射 %d 次" % (level + 1))
		&"tracking":
			_active_tracking_remaining = 4.0 + level * 0.4
			_active_skill_cooldowns[skill_id] = maxf(20.0 - level, 12.0)
			action_message.emit("锁定协议启动  ·  接下来子弹主动追踪目标")


func equip_weapon(index: int) -> bool:
	if index < 0:
		return false
	if index >= weapon_loadout.size():
		# Compatibility path for scripted tests and developer tools.
		if index >= WEAPON_CATALOG.size() or weapon_loadout.size() >= 5:
			return false
		var catalog_weapon := WEAPON_CATALOG[index] as WeaponData
		var state := get_node_or_null("/root/GameState")
		if catalog_weapon == null or state == null or not state.is_weapon_unlocked(catalog_weapon.weapon_id):
			return false
		weapon_loadout.append(catalog_weapon)
		state.add_weapon_to_loadout(catalog_weapon.weapon_id)
		index = weapon_loadout.size() - 1
	var candidate := weapon_loadout[index]
	if candidate == null or not candidate.is_valid():
		push_warning("Rejected invalid weapon configuration at index %d" % index)
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
	var fire_rate_multiplier := skill_system.get_value(&"rapid_fire", 1.0) * (1.0 + _home_skill_level(&"fury") * 0.1) * (1.0 + _weapon_module_level(current_weapon.weapon_id, &"overdrive") * 0.08) * (1.65 if _active_fury_remaining > 0.0 else 1.0)
	_fire_cooldown = current_weapon.fire_interval / maxf(fire_rate_multiplier, 0.1)
	if current_weapon.is_melee:
		_perform_melee_attack()
		weapon_audio.play()
		fired.emit(current_weapon.recoil)
		return true
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
		var weapon_multiplier := (1.0 + float(maxi(weapon_level - 1, 0)) * 0.18) * (1.0 + _weapon_module_level(current_weapon.weapon_id, &"impact") * 0.12)
		var skill_damage_multiplier := skill_system.get_value(&"combat_core", 1.0)
		projectile.configure(
			current_weapon,
			weapon_multiplier * skill_damage_multiplier,
			int(skill_system.get_value(&"penetration", 0.0)),
			_ricochet_count_for_current_shot(),
			int(skill_system.get_value(&"split_rounds", 0.0)),
			skill_system.get_level(&"phase_rounds") > 0
		)
		projectile.critical_chance = clampf(
			projectile.critical_chance + skill_system.get_value(&"critical_matrix", 0.0),
			0.0,
			0.95
		)
		projectile.tracking_strength = float(_home_skill_level(&"tracking") + _weapon_module_level(current_weapon.weapon_id, &"seeker") + (4 if _active_tracking_remaining > 0.0 else 0)) * 1.5
		projectile.max_distance *= 1.0 + _weapon_module_level(current_weapon.weapon_id, &"range") * 0.16
		projectile.launch(_safe_muzzle_origin(base_direction), base_direction.rotated(Vector3.UP, spread_angle))
	weapon_audio.play()
	fired.emit(current_weapon.recoil)
	return true


func _ricochet_count_for_current_shot() -> int:
	# Three independent sources stack: level-up skill, weapon module, and the
	# short manual protocol. Home training only strengthens the manual protocol.
	var count := int(skill_system.get_value(&"ricochet", 0.0))
	count += _weapon_module_level(current_weapon.weapon_id, &"ricochet")
	if _active_bounce_remaining > 0.0:
		count += 1 + _home_skill_level(&"bounce")
	return clampi(count, 0, 12)


func _restore_weapon_loadout() -> void:
	weapon_loadout.clear()
	var state := get_node_or_null("/root/GameState")
	var requested: Array = [&"flame_projector"]
	if state != null:
		requested = state.loadout_weapon_ids
	for weapon_id in requested:
		var weapon := _weapon_by_id(StringName(weapon_id))
		if weapon != null:
			weapon_loadout.append(weapon)
	if weapon_loadout.is_empty():
		weapon_loadout.append(_weapon_by_id(&"flame_projector"))
		if state != null:
			state.loadout_weapon_ids = [&"flame_projector"]


func _weapon_by_id(weapon_id: StringName) -> WeaponData:
	for candidate in WEAPON_CATALOG:
		var weapon := candidate as WeaponData
		if weapon != null and weapon.weapon_id == weapon_id:
			return weapon
	return null


func _handle_weapon_interaction() -> void:
	if not Input.is_action_just_pressed("interact"):
		return
	var interactable := _nearest_combat_interactable()
	if interactable != null and interactable.has_method("interact"):
		interactable.interact(self)
		return
	_drop_current_weapon()


func _nearest_weapon_pickup() -> Node3D:
	var nearest: Node3D
	var nearest_distance := 2.2
	for candidate in get_tree().get_nodes_in_group("weapon_pickups"):
		if not candidate is Node3D:
			continue
		var pickup := candidate as Node3D
		var distance := global_position.distance_to(pickup.global_position)
		if distance < nearest_distance:
			nearest = pickup
			nearest_distance = distance
	return nearest


func _nearest_combat_interactable() -> Node3D:
	var nearest: Node3D
	var nearest_distance := 2.7
	# Extraction portals take precedence over dropped weapons at the same spot.
	for group_name in [&"combat_interactables", &"weapon_pickups"]:
		for candidate in get_tree().get_nodes_in_group(group_name):
			if not candidate is Node3D:
				continue
			var target := candidate as Node3D
			var distance := global_position.distance_to(target.global_position)
			if distance < nearest_distance:
				nearest = target
				nearest_distance = distance
	return nearest


func _update_interaction_hint() -> void:
	var interactable := _nearest_combat_interactable()
	if interactable != null and interactable.has_method("interaction_text"):
		_set_interaction_hint(str(interactable.interaction_text(weapon_loadout.size() >= 5)))
	elif weapon_loadout.size() > 1:
		_set_interaction_hint("F  丢下当前武器")
	else:
		_set_interaction_hint("")


func _set_interaction_hint(message: String) -> void:
	if _last_interaction_hint == message:
		return
	_last_interaction_hint = message
	interaction_hint.emit(message)


func try_pickup_weapon(weapon: WeaponData) -> bool:
	if weapon == null or not weapon.is_valid():
		return false
	var state := get_node_or_null("/root/GameState")
	if weapon_loadout.any(func(item: WeaponData) -> bool: return item.weapon_id == weapon.weapon_id):
		if state != null:
			state.clear_pending_weapon(weapon.weapon_id)
		action_message.emit("%s 已在武器栏中，已保留强化等级" % weapon.display_name)
		return true
	if weapon_loadout.size() >= 5:
		action_message.emit("武器栏已满，先按 F 丢下当前武器")
		return false
	weapon_loadout.append(weapon)
	if state != null:
		state.add_weapon_to_loadout(weapon.weapon_id)
		state.clear_pending_weapon(weapon.weapon_id)
	equip_weapon(weapon_loadout.size() - 1)
	action_message.emit("已拾取 %s  ·  按 %d 切换" % [weapon.display_name, weapon_loadout.size()])
	return true


func _handle_gadget_input() -> void:
	if Input.is_action_just_pressed("weapon_6"):
		_activate_gadget(&"shock", 3.8, 42.0, Color("68c8ff"), "震爆手雷")
	elif Input.is_action_just_pressed("weapon_7"):
		_activate_gadget(&"fire", 4.8, 28.0, Color("ff7038"), "燃烧瓶")
	elif Input.is_action_just_pressed("weapon_8"):
		_activate_gadget(&"emp", 6.2, 36.0, Color("9c72ff"), "电磁炸弹")


func _activate_gadget(gadget_id: StringName, radius: float, base_damage: float, color: Color, label: String) -> void:
	if float(_gadget_cooldowns.get(gadget_id, 0.0)) > 0.0:
		action_message.emit("%s 冷却中" % label)
		return
	_gadget_cooldowns[gadget_id] = 10.0 if gadget_id != &"emp" else 14.0
	var damage := base_damage * skill_system.get_value(&"combat_core", 1.0)
	var projectile := PLAYER_GADGET.new()
	projectile.configure(gadget_id, global_position, _gadget_target(), radius, damage, color, label)
	var parent := get_tree().current_scene
	if parent != null:
		parent.add_child(projectile)
	action_message.emit("%s 已投向准星位置" % label)


func _gadget_target() -> Vector3:
	if OS.has_feature("mobile"):
		var closest: Node3D
		var closest_distance := INF
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if candidate is Node3D:
				var enemy := candidate as Node3D
				var distance := global_position.distance_squared_to(enemy.global_position)
				if distance < closest_distance:
					closest = enemy
					closest_distance = distance
		if closest != null:
			return closest.global_position
	var screen_position := get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_direction := camera.project_ray_normal(screen_position)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(ray_origin, ray_direction)
	if hit is Vector3:
		var point := hit as Vector3
		var direction := point - global_position
		direction.y = 0.0
		if direction.length() > 18.0:
			return global_position + direction.normalized() * 18.0
		return point
	return global_position + -$Body.global_transform.basis.z * 10.0


func _show_gadget_wave(radius: float, color: Color) -> void:
	var wave := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.35
	mesh.outer_radius = 0.48
	wave.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, 0.75)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 4.2
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.material_override = material
	get_tree().current_scene.add_child(wave)
	wave.global_position = global_position + Vector3.UP * 0.14
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3.ONE * radius, 0.3)
	tween.tween_callback(wave.queue_free)


func _drop_current_weapon() -> void:
	if weapon_loadout.size() <= 1:
		action_message.emit("至少保留一把武器")
		return
	var dropped := current_weapon
	weapon_loadout.remove_at(weapon_index)
	var state := get_node_or_null("/root/GameState")
	if state != null:
		state.remove_weapon_from_loadout(dropped.weapon_id)
	weapon_index = clampi(weapon_index, 0, weapon_loadout.size() - 1)
	equip_weapon(weapon_index)
	var pickup := WEAPON_PICKUP.new()
	pickup.configure(dropped)
	pickup.global_position = global_position + -$Body.global_transform.basis.z * 1.6
	var parent := get_tree().current_scene
	if parent != null:
		parent.add_child(pickup)
	action_message.emit("已丢下 %s" % dropped.display_name)


func _perform_melee_attack() -> void:
	var aim: Vector3 = -$Body.global_transform.basis.z
	var forward := Vector3(aim.x, 0.0, aim.z).normalized()
	var weapon_level := _weapon_level(current_weapon.weapon_id)
	var multiplier := (1.0 + float(maxi(weapon_level - 1, 0)) * 0.18) * skill_system.get_value(&"combat_core", 1.0)
	var half_arc := deg_to_rad(current_weapon.melee_arc_degrees * 0.5)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D:
			continue
		var enemy := candidate as Node3D
		var offset := enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() > current_weapon.melee_range or offset.length_squared() <= 0.01:
			continue
		if forward.angle_to(offset.normalized()) > half_arc:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(current_weapon.damage * multiplier)
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(offset.normalized() * 12.0)
	_show_melee_arc(forward)


func _show_melee_arc(forward: Vector3) -> void:
	var slash := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.55
	mesh.outer_radius = current_weapon.melee_range
	mesh.rings = 16
	mesh.ring_segments = 24
	slash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.3, 0.52, 0.65)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.12, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	slash.material_override = material
	slash.global_position = global_position + forward * (current_weapon.melee_range * 0.45) + Vector3.UP * 0.08
	var parent := get_tree().current_scene
	if parent == null:
		return
	parent.add_child(slash)
	slash.scale = Vector3(0.25, 1.0, 0.25)
	var tween := create_tween()
	tween.tween_property(slash, "scale", Vector3.ONE, 0.11)
	tween.tween_interval(0.08)
	tween.tween_callback(slash.queue_free)


func _try_pulse() -> void:
	if _pulse_cooldown > 0.0:
		return
	_pulse_cooldown = 7.0
	var damage := 18.0 * skill_system.get_value(&"combat_core", 1.0)
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D:
			continue
		var enemy := candidate as Node3D
		var offset := enemy.global_position - global_position
		if offset.length() > 4.8:
			continue
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		if enemy.has_method("apply_knockback"):
			enemy.apply_knockback(offset.normalized() * 9.0)
	_show_pulse_wave()
	action_message.emit("震荡脉冲已释放，冷却 7 秒")


func restore_health(amount: float) -> void:
	if amount <= 0.0 or is_dead:
		return
	health = minf(health + amount, max_health)
	health_changed.emit(health, max_health)


func apply_zone_support(health_bonus: float, speed_bonus: float) -> void:
	if health_bonus > 0.0:
		max_health += health_bonus
		health = max_health
		health_changed.emit(health, max_health)
	if speed_bonus > 0.0:
		move_speed += speed_bonus


func _toggle_mount() -> void:
	_mounted = not _mounted
	if _mounted:
		_mount_visual = Node3D.new()
		_mount_visual.name = "ScrapHoverMount"
		var hull := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.radius = 0.42
		mesh.height = 1.7
		hull.mesh = mesh
		hull.rotation.z = PI * 0.5
		hull.position = Vector3(0.0, -0.62, 0.08)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("b37a25")
		material.metallic = 0.82
		material.roughness = 0.38
		hull.material_override = material
		_mount_visual.add_child(hull)
		add_child(_mount_visual)
		action_message.emit("星港悬浮坐骑启动，移动速度提升")
	else:
		if is_instance_valid(_mount_visual):
			_mount_visual.queue_free()
		action_message.emit("星港悬浮坐骑收纳")


func _show_pulse_wave() -> void:
	var wave := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.88
	mesh.outer_radius = 1.02
	wave.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.96, 0.86, 0.8)
	material.emission_enabled = true
	material.emission = Color(0.18, 0.9, 0.78, 1.0)
	material.emission_energy_multiplier = 3.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wave.material_override = material
	get_tree().current_scene.add_child(wave)
	wave.global_position = global_position + Vector3.UP * 0.08
	var tween := wave.create_tween()
	tween.tween_property(wave, "scale", Vector3.ONE * 4.8, 0.28)
	tween.tween_callback(wave.queue_free)


func apply_skill(skill: SkillData) -> bool:
	if not skill_system.apply_upgrade(skill):
		return false
	var level := skill_system.get_level(skill.skill_id)
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		game_state.record_skill(skill.skill_id, level)
	if skill.skill_id == &"orbit_drone":
		_sync_drones(_companion_count())
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


func _safe_muzzle_origin(direction: Vector3) -> Vector3:
	# A long weapon mesh can extend through a wall. Raycast from the chassis to
	# the muzzle, so the projectile always starts on the player's side of cover.
	var origin := global_position + Vector3.UP * 0.5
	var target := muzzle.global_position
	var query := PhysicsRayQueryParameters3D.create(origin, target, 16, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return (hit["position"] as Vector3) - direction.normalized() * 0.1
	return target


func _home_skill_level(skill_id: StringName) -> int:
	var state := get_node_or_null("/root/GameState")
	return state.home_skill_level(skill_id) if state != null else 0


func active_skill_level(skill_id: StringName) -> int:
	return _home_skill_level(skill_id)


func restore_carried_health(value: float) -> void:
	if value <= 0.0 or is_dead:
		return
	health = clampf(value, 1.0, max_health)
	health_changed.emit(health, max_health)


func _weapon_module_level(weapon_id: StringName, module_id: StringName) -> int:
	var state := get_node_or_null("/root/GameState")
	return state.weapon_module_level(weapon_id, module_id) if state != null else 0


func on_kill() -> void:
	var heal_amount := skill_system.get_value(&"kill_heal", 0.0) + _home_skill_level(&"recovery") * 1.2
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


func _companion_count() -> int:
	return clampi(
		int(skill_system.get_value(&"orbit_drone", 0.0)),
		0,
		12
	)


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
