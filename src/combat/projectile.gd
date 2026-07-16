extends Area3D

@export var speed: float = 30.0
@export var damage: float = 18.0
@export var max_distance: float = 32.0

var critical_chance: float = 0.0
var critical_multiplier: float = 2.0
var penetration_remaining: int = 0
var ricochet_remaining: int = 0
var status_effects: Array[StatusEffectData] = []

var direction: Vector3 = Vector3.FORWARD
var traveled: float = 0.0
var _hit_ids: Dictionary = {}
var _excluded_rids: Array[RID] = []


func _ready() -> void:
	add_to_group("projectiles")
	body_entered.connect(_on_body_entered)


func launch(origin: Vector3, aim_direction: Vector3) -> void:
	global_position = origin
	direction = aim_direction.normalized()
	look_at(global_position + direction, Vector3.UP)


func configure(
	weapon: WeaponData,
	damage_multiplier: float = 1.0,
	bonus_penetration: int = 0,
	bonus_ricochet: int = 0
) -> bool:
	if weapon == null or not weapon.is_valid() or damage_multiplier <= 0.0:
		return false
	damage = weapon.damage * damage_multiplier
	speed = weapon.projectile_speed
	max_distance = weapon.projectile_range
	critical_chance = weapon.critical_chance
	critical_multiplier = weapon.critical_multiplier
	penetration_remaining = weapon.base_penetration + maxi(bonus_penetration, 0)
	ricochet_remaining = maxi(bonus_ricochet, 0)
	status_effects = weapon.status_effects.duplicate()
	if weapon.vfx != null:
		scale = Vector3.ONE * weapon.vfx.projectile_scale
		var material := StandardMaterial3D.new()
		material.albedo_color = weapon.vfx.projectile_color
		material.emission_enabled = true
		material.emission = weapon.vfx.projectile_color
		material.emission_energy_multiplier = 4.0
		$Mesh.material_override = material
		$Light.light_color = weapon.vfx.projectile_color
	return true


func _physics_process(delta: float) -> void:
	var step := speed * delta
	var start := global_position
	var destination := start + direction * step
	var exclude: Array[RID] = [get_rid()]
	exclude.append_array(_excluded_rids)
	var query := PhysicsRayQueryParameters3D.create(
		start,
		destination,
		collision_mask,
		exclude
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"] as Vector3
		var collider := hit["collider"] as Node3D
		if collider != null:
			_apply_hit(collider)
		else:
			queue_free()
		return
	global_position = destination
	traveled += step
	if traveled >= max_distance:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	_apply_hit(body)


func _apply_hit(body: Node3D) -> void:
	var body_id := body.get_instance_id()
	if _hit_ids.has(body_id):
		return
	_hit_ids[body_id] = true
	var damaged_enemy := body.has_method("take_damage")
	if body.has_method("take_damage"):
		var result := DamageRules.calculate_hit(
			damage,
			1.0,
			0.0,
			critical_chance,
			critical_multiplier,
			randf()
		)
		body.take_damage(float(result["damage"]))
		if body.has_method("apply_status_effect"):
			for effect in status_effects:
				body.apply_status_effect(effect, direction)
	if damaged_enemy and penetration_remaining > 0:
		penetration_remaining -= 1
		if body is CollisionObject3D:
			_excluded_rids.append((body as CollisionObject3D).get_rid())
		global_position += direction * 0.08
		return
	if damaged_enemy and ricochet_remaining > 0:
		var target := _find_ricochet_target(body)
		if target != null:
			ricochet_remaining -= 1
			direction = (target.global_position - global_position).normalized()
			direction.y = 0.0
			global_position += direction * 0.08
			return
	queue_free()


func _find_ricochet_target(current: Node3D) -> Node3D:
	var nearest: Node3D
	var nearest_distance := 12.0
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not candidate is Node3D or candidate == current or _hit_ids.has(candidate.get_instance_id()):
			continue
		var candidate_node := candidate as Node3D
		var distance := global_position.distance_to(candidate_node.global_position)
		if distance < nearest_distance:
			nearest = candidate_node
			nearest_distance = distance
	return nearest
