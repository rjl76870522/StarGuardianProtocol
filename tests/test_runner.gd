extends SceneTree

var _failures: Array[String] = []
var _checks: int = 0


class DamageTarget extends CharacterBody3D:
	var hits: int = 0
	var received: float = 0.0

	func take_damage(amount: float) -> void:
		hits += 1
		received += amount


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		printerr("FAIL: %s" % message)


func _run() -> void:
	var save_manager := root.get_node("SaveManager")
	save_manager.save_path = "user://campaign_save_test.json"
	save_manager.temp_path = "user://campaign_save_test.tmp"
	save_manager.backup_path = "user://campaign_save_test.backup.json"
	save_manager.delete_campaign()
	root.get_node("GameState").start_campaign()
	_test_save_round_trip_and_corruption()
	_test_damage_rules()
	_test_combat_data_resources()
	_test_critical_hits()
	_test_skill_stacking_and_choices()
	await _test_skin_roster_and_salvage_cache()
	await _test_upgrade_card_and_campaign_progression()
	await _test_weapon_reward_panel()
	_test_enemy_data_catalog()
	await _test_enemy_visual_profiles()
	await _test_scene_smoke()
	await _test_enemy_state_machine()
	await _test_repair_enemy()
	await _test_boss_phases_and_debug()
	await _test_stage_one_boss_spawn_and_hud()
	await _test_stage_two_boss_spawn()
	await _test_fire_rate_limit()
	await _test_penetration()
	await _test_status_duration_and_ticks()
	await _test_player_gadget_fields()
	await _test_player_damage_and_invulnerability()
	await _test_player_aim_stays_level()
	await _test_enemy_damage_once()
	await _test_core_hitbox_damage_bonus()
	await _test_projectile_does_not_hit_twice()
	await _test_projectile_physics_hit()
	await _test_debris_has_collision()
	await _test_obstacle_blocks_actors_and_projectiles()
	await _test_seeded_arena_variants()
	_test_generated_audio()
	await _test_repeated_game_cleanup()
	await _test_upgrade_offer_flow()
	await _test_campaign_ending()
	await _test_round_results()

	if _failures.is_empty():
		print("TEST_RESULT: PASS (%d checks)" % _checks)
		save_manager.delete_campaign()
		await process_frame
		quit(0)
	else:
		printerr("TEST_RESULT: FAIL (%d failures, %d checks)" % [_failures.size(), _checks])
		save_manager.delete_campaign()
		await process_frame
		quit(1)


func _test_damage_rules() -> void:
	_check(is_equal_approx(DamageRules.calculate(10.0), 10.0), "base damage")
	_check(is_equal_approx(DamageRules.calculate(10.0, 2.0, 3.0), 17.0), "multiplier and armor")
	_check(is_equal_approx(DamageRules.calculate(2.0, 1.0, 99.0), 1.0), "minimum positive damage")
	_check(is_zero_approx(DamageRules.calculate(-1.0)), "invalid damage is zero")


func _test_save_round_trip_and_corruption() -> void:
	var manager := root.get_node("SaveManager")
	var state := root.get_node("GameState")
	state.start_campaign()
	state.current_stage = 4
	state.campaign_seed = 24680
	state.carried_skill_levels = {&"rapid_fire": 3, &"armor_plating": 2}
	state.weapon_levels = {&"auto_rifle": 2, &"scatter_cannon": 1}
	state.unlocked_weapons = {&"auto_rifle": true, &"scatter_cannon": true}
	_check(manager.save_campaign(state), "campaign save is written")
	state.current_stage = 1
	state.campaign_seed = 1
	state.carried_skill_levels.clear()
	state.weapon_levels = {&"auto_rifle": 1}
	state.unlocked_weapons = {&"auto_rifle": true}
	_check(manager.apply_campaign(state), "campaign save can be restored")
	_check(state.current_stage == 4 and state.campaign_seed == 24680, "campaign restores stage and map seed")
	_check(state.carried_skill_levels.get(&"rapid_fire", 0) == 3, "campaign restores skill levels")
	_check(state.weapon_levels.get(&"scatter_cannon", 0) == 1, "campaign restores weapon rewards")

	var file := FileAccess.open(manager.save_path, FileAccess.WRITE)
	file.store_string("{broken json")
	file.close()
	_check(manager.load_campaign().is_empty(), "corrupted campaign save is rejected")
	file = FileAccess.open(manager.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 2, "stage": -5, "skills": {}, "weapons": {}}))
	file.close()
	_check(manager.load_campaign().is_empty(), "invalid campaign values are rejected")
	file = FileAccess.open(manager.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "stage": 3, "skills": {}, "weapons": {}}))
	file.close()
	_check(manager.load_campaign().is_empty(), "campaign saves from the previous version are discarded")
	state.start_campaign()


func _test_combat_data_resources() -> void:
	var weapon_paths := [
		"res://assets/data/weapons/auto_rifle.tres",
		"res://assets/data/weapons/scatter_cannon.tres",
		"res://assets/data/weapons/rail_lance.tres",
		"res://assets/data/weapons/arc_blade.tres",
		"res://assets/data/weapons/sidearm.tres",
		"res://assets/data/weapons/sniper_rifle.tres",
		"res://assets/data/weapons/siege_cannon.tres",
		"res://assets/data/weapons/flame_projector.tres",
	]
	for path in weapon_paths:
		var weapon := load(path) as WeaponData
		_check(weapon != null and weapon.is_valid(), "valid weapon resource: %s" % path)
		_check(weapon.icon != null, "weapon has an icon: %s" % path)
	var invalid_weapon := WeaponData.new()
	_check(not invalid_weapon.is_valid(), "invalid weapon configuration is rejected")
	for skill_id in ["rapid_fire", "move_speed", "ricochet", "penetration", "kill_heal", "orbit_drone", "combat_core", "critical_matrix", "armor_plating", "split_rounds", "phase_rounds"]:
		var skill := load("res://assets/data/skills/%s.tres" % skill_id) as SkillData
		_check(skill != null and skill.is_valid(), "valid skill resource: %s" % skill_id)


func _test_critical_hits() -> void:
	var critical := DamageRules.calculate_hit(10.0, 1.0, 0.0, 0.5, 2.0, 0.1)
	_check(bool(critical["critical"]), "critical roll is detected")
	_check(is_equal_approx(float(critical["damage"]), 20.0), "critical multiplier applies once")
	var normal := DamageRules.calculate_hit(10.0, 1.0, 0.0, 0.5, 2.0, 0.9)
	_check(not bool(normal["critical"]), "normal roll is not critical")
	_check(is_equal_approx(float(normal["damage"]), 10.0), "normal hit keeps base damage")


func _test_skill_stacking_and_choices() -> void:
	var system := SkillSystem.new()
	var rapid := load("res://assets/data/skills/rapid_fire.tres") as SkillData
	_check(system.apply_upgrade(rapid), "skill accepts first level")
	_check(system.apply_upgrade(rapid), "skill accepts second level")
	_check(system.apply_upgrade(rapid), "skill accepts third level")
	_check(system.apply_upgrade(rapid), "skill accepts fourth level")
	_check(system.apply_upgrade(rapid), "skill accepts fifth level")
	_check(system.get_level(&"rapid_fire") == 5, "skill levels stack to maximum")
	_check(is_equal_approx(system.get_value(&"rapid_fire"), 1.95), "stacked skill exposes final value")
	_check(not system.apply_upgrade(rapid), "skill rejects upgrades above maximum")
	var catalog: Array[SkillData] = []
	for skill_id in ["rapid_fire", "move_speed", "ricochet", "penetration", "kill_heal", "orbit_drone", "combat_core", "critical_matrix", "armor_plating", "split_rounds", "phase_rounds"]:
		catalog.append(load("res://assets/data/skills/%s.tres" % skill_id) as SkillData)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var choices := system.available_choices(catalog, 3, rng)
	_check(choices.size() == 3, "upgrade offer returns three choices")
	var ids: Dictionary = {}
	for skill in choices:
		ids[skill.skill_id] = true
	_check(ids.size() == 3, "upgrade offer has no duplicate skills")
	_check(not ids.has(&"rapid_fire"), "maxed skill is excluded from offers")


func _test_skin_roster_and_salvage_cache() -> void:
	var state := root.get_node("GameState")
	var expected_skins: Array[StringName] = [&"prism_guardian", &"red_guardian", &"orange_guardian", &"yellow_guardian", &"green_guardian", &"cyan_guardian", &"blue_guardian", &"violet_guardian"]
	_check(state.PLAYABLE_SKINS.size() == 8, "skin roster contains exactly eight skins")
	_check(state.PLAYABLE_SKINS == expected_skins, "skin roster keeps prism and seven spectrum colors")
	var cache := SalvageCache.new()
	root.add_child(cache)
	await process_frame
	_check(cache.get_node_or_null("RareSalvageCore") != null, "salvage pickup builds a rare resource core")
	_check(cache.get_node_or_null("Beacon") != null, "salvage pickup has a visible beacon")
	_check(cache.get_node_or_null("RareSalvageCore/SignalBeam") != null, "salvage pickup includes a signal beam")
	cache.queue_free()
	await process_frame


func _test_upgrade_card_and_campaign_progression() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_campaign()
	game_state.advance_stage()
	game_state.record_skill(&"rapid_fire", 4)
	_check(game_state.current_stage == 2, "campaign advances to the next stage")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as WastelandPlayer
	root.add_child(player)
	await process_frame
	_check(player.skill_system.get_level(&"rapid_fire") == 4, "next stage restores carried skill levels")
	var panel := (load("res://scenes/upgrade_panel.tscn") as PackedScene).instantiate() as UpgradePanel
	root.add_child(panel)
	await process_frame
	var rapid := load("res://assets/data/skills/rapid_fire.tres") as SkillData
	panel.show_choices([rapid], player.skill_system)
	var card_text: String = panel.buttons[0].text
	_check(card_text.contains("5 / 5"), "upgrade card clearly shows the target maximum level")
	_check(card_text.contains("+95%"), "upgrade card explains the resulting effect")
	player.apply_skill(rapid)
	_check(not player.skill_system.can_upgrade(rapid), "restored skill stops at maximum level")
	var rng := RandomNumberGenerator.new()
	var catalog: Array[SkillData] = [rapid]
	_check(player.skill_system.available_choices(catalog, 3, rng).is_empty(), "maxed carried skill never appears again")
	panel.close()
	panel.queue_free()
	player.queue_free()
	await process_frame
	game_state.start_campaign()
	_check(game_state.current_stage == 1 and game_state.carried_skill_levels.is_empty(), "new campaign clears stage and upgrades")


func _test_weapon_reward_panel() -> void:
	var game_state := root.get_node("GameState")
	game_state.start_campaign()
	var panel := (load("res://scenes/weapon_reward_panel.tscn") as PackedScene).instantiate()
	root.add_child(panel)
	await process_frame
	var rewards: Array[WeaponData] = []
	rewards.assign(WastelandPlayer.WEAPON_CATALOG)
	panel.show_rewards(rewards)
	_check(panel.visible, "weapon reward panel opens after a cleared stage")
	_check(panel.buttons[0].text.contains("强化"), "owned weapon reward is shown as an upgrade")
	_check(panel.buttons[1].text.contains("解锁"), "locked weapon reward is shown as an unlock")
	var selected: Array[WeaponData] = []
	panel.weapon_selected.connect(func(weapon: WeaponData) -> void: selected.append(weapon))
	panel._choose(2)
	_check(selected.size() == 1 and selected[0].weapon_id == &"scatter_cannon", "weapon reward emits the selected weapon")
	var selected_id := selected[0].weapon_id if not selected.is_empty() else &""
	_check(game_state.upgrade_weapon(selected_id), "selected weapon reward is applied")
	_check(game_state.is_weapon_unlocked(&"scatter_cannon"), "weapon reward unlocks a new weapon")
	_check(game_state.weapon_level(&"scatter_cannon") == 1, "new weapon begins at level one")
	_check(game_state.upgrade_weapon(&"scatter_cannon"), "unlocked weapon can be upgraded again")
	_check(game_state.weapon_level(&"scatter_cannon") == 2, "weapon level increases with later rewards")
	panel.queue_free()
	await process_frame
	game_state.start_campaign()


func _test_enemy_data_catalog() -> void:
	var ids: Dictionary = {}
	var archetypes: Dictionary = {}
	var elite_count := 0
	for enemy_id in ["chaser", "shooter", "bomber", "heavy", "repair", "mage", "elite_blink", "elite_hazard"]:
		var data := load("res://assets/data/enemies/%s.tres" % enemy_id) as EnemyData
		_check(data != null and data.is_valid(), "valid enemy data: %s" % enemy_id)
		ids[data.enemy_id] = true
		archetypes[data.archetype] = true
		if data.elite:
			elite_count += 1
	_check(ids.size() == 8, "enemy catalog has eight unique definitions")
	_check(archetypes.size() == 6, "enemy catalog covers six normal archetypes")
	_check(elite_count == 2, "enemy catalog contains two elite variants")
	var blink := load("res://assets/data/enemies/elite_blink.tres") as EnemyData
	var hazard := load("res://assets/data/enemies/elite_hazard.tres") as EnemyData
	_check(blink.teleport_on_hit, "phase elite changes position when hit")
	_check(hazard.leaves_hazard, "corrosion elite creates a projectile hazard pattern")
	_check(not EnemyData.new().is_valid(), "invalid enemy configuration is rejected")


func _test_enemy_visual_profiles() -> void:
	var profiles: Dictionary = {}
	for enemy_id in ["chaser", "shooter", "bomber", "heavy", "repair", "mage", "elite_blink", "elite_hazard"]:
		var enemy := (load("res://scenes/chaser.tscn") as PackedScene).instantiate() as ScrapChaser
		enemy.enemy_data = load("res://assets/data/enemies/%s.tres" % enemy_id) as EnemyData
		root.add_child(enemy)
		await process_frame
		var details := enemy.get_node_or_null("ArchetypeDetails")
		_check(details != null and details.get_child_count() > 0, "enemy has an archetype silhouette: %s" % enemy_id)
		profiles[enemy_id] = str(details.get_meta("profile", "")) if details != null else ""
		enemy.queue_free()
		await process_frame
	_check(profiles["shooter"] != profiles["heavy"], "shooter and heavy use separate visual profiles")
	_check(profiles["bomber"] != profiles["repair"], "bomber and repair use separate visual profiles")
	_check(profiles["mage"] != profiles["shooter"], "mage and shooter use separate visual profiles")


func _test_scene_smoke() -> void:
	for path in [
		"res://scenes/main_menu.tscn",
		"res://scenes/player.tscn",
		"res://scenes/chaser.tscn",
		"res://scenes/projectile.tscn",
		"res://scenes/hud.tscn",
		"res://scenes/orbit_drone.tscn",
		"res://scenes/drone_projectile.tscn",
		"res://scenes/upgrade_panel.tscn",
		"res://scenes/weapon_reward_panel.tscn",
		"res://scenes/route_panel.tscn",
		"res://scenes/enemy_projectile.tscn",
		"res://scenes/ground_hazard.tscn",
		"res://scenes/boss.tscn",
		"res://scenes/boss_debug_panel.tscn",
		"res://scenes/game.tscn",
	]:
		var packed := load(path) as PackedScene
		_check(packed != null, "scene loads: %s" % path)
		if packed == null:
			continue
		var instance := packed.instantiate()
		_check(instance != null, "scene instantiates: %s" % path)
		root.add_child(instance)
		await process_frame
		instance.queue_free()
		await process_frame


func _test_player_damage_and_invulnerability() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate() as WastelandPlayer
	root.add_child(player)
	await process_frame
	var initial := player.health
	player.take_damage(20.0)
	_check(is_equal_approx(player.health, initial - 20.0), "player receives damage")
	player.is_invulnerable = true
	player.take_damage(20.0)
	_check(is_equal_approx(player.health, initial - 20.0), "invulnerable player ignores damage")
	player.queue_free()
	await process_frame


func _test_player_aim_stays_level() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var player := player_scene.instantiate() as WastelandPlayer
	root.add_child(player)
	await process_frame
	player.aim_at_world_point(Vector3(8.0, 0.0, 3.0))
	var forward: Vector3 = -player.get_node("Body").global_transform.basis.z
	_check(absf(forward.y) < 0.001, "player aim keeps the weapon level")
	_check(player.muzzle.global_position.y > 0.75, "aimed muzzle remains above the floor")
	player.queue_free()
	await process_frame


func _test_enemy_damage_once() -> void:
	var enemy_scene := load("res://scenes/chaser.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as ScrapChaser
	root.add_child(enemy)
	await process_frame
	var initial := enemy.health
	enemy.take_damage(12.0)
	_check(is_equal_approx(enemy.health, initial - 12.0), "enemy receives exact damage once")
	enemy.queue_free()
	await process_frame


func _test_projectile_does_not_hit_twice() -> void:
	var projectile_scene := load("res://scenes/projectile.tscn") as PackedScene
	var projectile := projectile_scene.instantiate()
	var target := DamageTarget.new()
	root.add_child(target)
	root.add_child(projectile)
	await process_frame
	projectile._on_body_entered(target)
	projectile._on_body_entered(target)
	_check(target.hits == 1, "one projectile cannot damage the same target twice")
	_check(is_equal_approx(target.received, projectile.damage), "projectile applies configured damage")
	projectile.queue_free()
	target.queue_free()
	await process_frame


func _test_core_hitbox_damage_bonus() -> void:
	var enemy := (load("res://scenes/chaser.tscn") as PackedScene).instantiate() as ScrapChaser
	root.add_child(enemy)
	await process_frame
	var core := enemy.get_node_or_null("CoreHitbox") as EnemyCoreHitbox
	_check(core != null, "enemy has a dedicated core hitbox")
	if core != null:
		var initial := enemy.health
		core.take_damage(10.0)
		_check(is_equal_approx(enemy.health, initial - 20.0), "core hit deals double damage")
		enemy.queue_free()
	await process_frame


func _test_projectile_physics_hit() -> void:
	var enemy_scene := load("res://scenes/chaser.tscn") as PackedScene
	var projectile_scene := load("res://scenes/projectile.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as ScrapChaser
	var projectile := projectile_scene.instantiate()
	enemy.position = Vector3(3.0, 0.65, 0.0)
	root.add_child(enemy)
	root.add_child(projectile)
	projectile.launch(Vector3(0.0, 0.88, 0.0), Vector3.RIGHT)
	var initial := enemy.health
	for frame in 12:
		await physics_frame
		if enemy.health < initial:
			break
	_check(enemy.health < initial, "moving projectile physically damages an enemy")
	_check(is_equal_approx(enemy.health, initial - projectile.damage), "projectile sweep applies damage once")
	if is_instance_valid(projectile):
		projectile.queue_free()
	enemy.queue_free()
	await process_frame


func _test_debris_has_collision() -> void:
	var arena := Node3D.new()
	arena.set_script(load("res://src/world/arena.gd"))
	root.add_child(arena)
	await physics_frame
	var obstacles := get_nodes_in_group("obstacles")
	_check(obstacles.size() == arena.boundary_points.size() + 4, "arena creates internal cover plus the selected polygon boundary")
	var debris_blocks: Array[StaticBody3D] = []
	for obstacle in obstacles:
		_check(obstacle is StaticBody3D, "debris obstacle is a static body")
		if str(obstacle.name).begins_with("Obstacle"):
			var debris := obstacle as StaticBody3D
			debris_blocks.append(debris)
			_check(debris.get_node_or_null("CollisionShape3D") != null, "debris obstacle has a collision shape")
	_check(debris_blocks.size() == 4, "arena creates four internal cover blocks")
	if not debris_blocks.is_empty():
		var obstacle := debris_blocks[0]
		var start := obstacle.global_position + Vector3(-3.0, 0.14, 0.0)
		var finish := obstacle.global_position + Vector3(3.0, 0.14, 0.0)
		var query := PhysicsRayQueryParameters3D.create(start, finish, 16)
		var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty(), "physics ray cannot pass through debris")
		if not hit.is_empty():
			_check(hit["collider"] == obstacle, "physics ray hits the expected debris body")
		var muzzle_start := obstacle.global_position + Vector3(-3.0, 0.14, 0.0)
		var muzzle_finish := obstacle.global_position + Vector3(3.0, 0.14, 0.0)
		var muzzle_hit := arena.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(muzzle_start, muzzle_finish, 16)
		)
		_check(not muzzle_hit.is_empty(), "internal cover blocks shots at muzzle height")
		var player_scene := load("res://scenes/player.tscn") as PackedScene
		var player := player_scene.instantiate() as WastelandPlayer
		var approach := obstacle.global_transform.basis.x.normalized()
		var start_position := obstacle.global_position - approach * 3.0
		player.position = Vector3(start_position.x, 0.0, start_position.z)
		root.add_child(player)
		await physics_frame
		var collision := player.move_and_collide(approach * 6.0, true)
		_check(collision != null, "player cannot move through debris")
		if collision != null:
			_check(collision.get_collider() == obstacle, "player collides with the expected debris")
		player.queue_free()
	arena.queue_free()
	await process_frame


func _test_seeded_arena_variants() -> void:
	var state := root.get_node("GameState")
	state.campaign_seed = 13579
	state.current_stage = 1
	var first := Node3D.new()
	first.set_script(load("res://src/world/arena.gd"))
	root.add_child(first)
	await process_frame
	var first_signature: String = first.layout_signature
	var first_variant: int = first.variant
	first.queue_free()
	await process_frame

	var repeated := Node3D.new()
	repeated.set_script(load("res://src/world/arena.gd"))
	root.add_child(repeated)
	await process_frame
	_check(repeated.layout_signature == first_signature, "same campaign seed and stage reproduce the arena")
	_check(repeated.variant == first_variant, "same campaign seed reproduces the arena palette")
	repeated.queue_free()
	await process_frame

	state.current_stage = 3
	var later := Node3D.new()
	later.set_script(load("res://src/world/arena.gd"))
	root.add_child(later)
	await process_frame
	_check(later.layout_signature != first_signature, "later stages generate a different obstacle layout")
	_check(get_nodes_in_group("obstacles").size() == 9, "later stages add another physical obstacle")
	later.queue_free()
	await process_frame
	state.start_campaign()


func _test_obstacle_blocks_actors_and_projectiles() -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = 16
	wall.position = Vector3(3.0, 0.7, 0.0)
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(0.8, 1.4, 3.0)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	root.add_child(wall)
	await physics_frame

	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as WastelandPlayer
	player.position = Vector3.ZERO
	root.add_child(player)
	await physics_frame
	var player_collision := player.move_and_collide(Vector3(6.0, 0.0, 0.0), true)
	_check(player_collision != null and player_collision.get_collider() == wall, "player cannot pass through world obstacles")
	player.queue_free()

	var enemy := (load("res://scenes/chaser.tscn") as PackedScene).instantiate() as ScrapChaser
	enemy.position = Vector3.ZERO
	root.add_child(enemy)
	await physics_frame
	var enemy_collision := enemy.move_and_collide(Vector3(6.0, 0.0, 0.0), true)
	_check(enemy_collision != null and enemy_collision.get_collider() == wall, "enemy cannot pass through world obstacles")
	enemy.queue_free()

	var projectile := (load("res://scenes/projectile.tscn") as PackedScene).instantiate()
	root.add_child(projectile)
	projectile.launch(Vector3(0.0, 0.7, 0.0), Vector3.RIGHT)
	for frame in 12:
		await physics_frame
		if not is_instance_valid(projectile) or projectile.is_queued_for_deletion():
			break
	_check(not is_instance_valid(projectile) or projectile.is_queued_for_deletion(), "player projectile is destroyed by world obstacles")

	var enemy_projectile := (load("res://scenes/enemy_projectile.tscn") as PackedScene).instantiate()
	root.add_child(enemy_projectile)
	enemy_projectile.launch(Vector3(0.0, 0.7, 0.0), Vector3.RIGHT, 10.0, 80.0)
	for frame in 12:
		await physics_frame
		if not is_instance_valid(enemy_projectile) or enemy_projectile.is_queued_for_deletion():
			break
	_check(not is_instance_valid(enemy_projectile) or enemy_projectile.is_queued_for_deletion(), "enemy projectile is destroyed by world obstacles at high speed")

	wall.queue_free()
	await process_frame


func _test_fire_rate_limit() -> void:
	root.get_node("GameState").upgrade_weapon(&"scatter_cannon")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as WastelandPlayer
	root.add_child(player)
	await process_frame
	_check(player._try_fire(), "weapon fires when cooldown is ready")
	_check(not player._try_fire(), "weapon fire rate blocks immediate second shot")
	player._fire_cooldown = 0.0
	_check(player.equip_weapon(2), "shotgun can be equipped")
	_check(player._try_fire(), "shotgun fires through data-driven weapon path")
	_check(not player.equip_weapon(99), "invalid weapon index is rejected")
	player.queue_free()
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	await process_frame


func _test_enemy_state_machine() -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as WastelandPlayer
	var enemy := (load("res://scenes/chaser.tscn") as PackedScene).instantiate() as ScrapChaser
	enemy.enemy_data = load("res://assets/data/enemies/chaser.tres") as EnemyData
	enemy.target = player
	root.add_child(player)
	root.add_child(enemy)
	await process_frame
	_check(enemy.state == ScrapChaser.State.SPAWN, "enemy begins in spawn state")
	enemy._spawn_remaining = 0.0
	player.global_position = Vector3(7.0, 0.0, 0.0)
	enemy._update_decision()
	_check(enemy.state == ScrapChaser.State.CHASE, "enemy state machine enters chase")
	player.global_position = enemy.global_position + Vector3(0.5, 0.0, 0.0)
	enemy._update_decision()
	_check(enemy.state == ScrapChaser.State.ATTACK, "enemy state machine enters attack")
	var freeze := (load("res://assets/data/status/freeze.tres") as StatusEffectData).duplicate(true) as StatusEffectData
	freeze.proc_chance = 1.0
	enemy.apply_status_effect(freeze)
	enemy._physics_process(0.01)
	_check(enemy.state == ScrapChaser.State.CONTROLLED, "freeze enters controlled state")
	enemy.take_damage(enemy.health + 1.0)
	_check(enemy.state == ScrapChaser.State.DEAD, "fatal damage enters death state")
	player.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await process_frame


func _test_repair_enemy() -> void:
	var repair := (load("res://scenes/chaser.tscn") as PackedScene).instantiate() as ScrapChaser
	var ally := (load("res://scenes/chaser.tscn") as PackedScene).instantiate() as ScrapChaser
	repair.enemy_data = load("res://assets/data/enemies/repair.tres") as EnemyData
	ally.enemy_data = load("res://assets/data/enemies/heavy.tres") as EnemyData
	root.add_child(repair)
	root.add_child(ally)
	repair.add_to_group("enemies")
	ally.add_to_group("enemies")
	await process_frame
	ally.take_damage(20.0)
	var damaged_health := ally.health
	repair._repair_nearest_ally()
	_check(ally.health > damaged_health, "repair enemy restores nearby ally health")
	_check(ally.health <= ally.max_health, "repair does not exceed maximum health")
	repair.queue_free()
	ally.queue_free()
	await process_frame


func _test_boss_phases_and_debug() -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as WastelandPlayer
	var boss := (load("res://scenes/boss.tscn") as PackedScene).instantiate() as WastelandBoss
	boss.target = player
	root.add_child(player)
	root.add_child(boss)
	await process_frame


	_check(WastelandBoss.PHASES.size() == 3, "boss has three data-driven phases")
	for phase in WastelandBoss.PHASES:
		_check(phase.is_valid(), "boss phase resource is valid: %s" % phase.display_name)
	_check(boss.phase_index == 0, "boss begins in phase one")
	boss.take_damage(boss.max_health * 0.4)
	_check(boss.phase_index == 1, "boss health threshold enters phase two")
	boss.take_damage(boss.max_health * 0.35)
	_check(boss.phase_index == 2, "boss health threshold enters phase three")
	boss.debug_set_phase(0)
	_check(boss.phase_index == 0, "debug control directly switches boss phase")
	boss.debug_set_health_ratio(0.5)
	_check(is_equal_approx(boss.health, boss.max_health * 0.5), "debug control sets boss health")
	boss.reset_battle()
	_check(boss.phase_index == 0 and is_equal_approx(boss.health, boss.max_health), "debug reset restores boss battle")
	player.queue_free()
	boss.queue_free()
	await process_frame


func _test_stage_two_boss_spawn() -> void:
	var state := root.get_node("GameState")
	state.start_campaign()
	state.current_stage = 2
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.initial_spawn_interval = 99.0
	root.add_child(game)
	await process_frame
	# Stage two has tall internal cover.  Start away from the default centre so
	# this verifies the spawn selection rather than only the old fixed point.
	game.player.global_position = Vector3(7.4, 0.0, 3.8)
	game._process(12.1)
	await process_frame
	await process_frame
	var boss := game.get_node_or_null("Enemies/WastelandBoss") as WastelandBoss
	_check(boss != null, "stage two spawns a boss after twelve seconds")
	if boss != null:
		_check(boss.global_position.distance_to(game.player.global_position) <= 7.2, "stage two boss spawns in visible combat range")
		_check(game.get_node("Arena").is_clear_for_boss(boss.global_position, 2.05), "stage two boss never spawns inside cover")
		_check(not game.camera.is_position_behind(boss.global_position + Vector3.UP * 0.9), "stage two boss is in front of the combat camera")
		var screen_position: Vector2 = game.camera.unproject_position(boss.global_position + Vector3.UP * 0.9)
		var viewport_size: Vector2 = root.get_viewport().get_visible_rect().size
		_check(Rect2(Vector2(18.0, 72.0), viewport_size - Vector2(36.0, 150.0)).has_point(screen_position), "stage two boss appears inside the playable camera frame")
		_check(game.get_node("HUD/Margin/BossBar").visible, "stage two boss health bar is visible")
	game.queue_free()
	await process_frame
	state.start_campaign()


func _test_stage_one_boss_spawn_and_hud() -> void:
	var state := root.get_node("GameState")
	state.start_campaign()
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.initial_spawn_interval = 99.0
	root.add_child(game)
	await process_frame
	game._process(8.1)
	await process_frame
	var boss := game.get_node_or_null("Enemies/WastelandBoss") as WastelandBoss
	_check(boss != null, "stage one always spawns a boss after eight seconds")
	if boss != null:
		_check(boss.global_position.distance_to(game.player.global_position) <= 7.2, "stage one boss spawns in visible combat range")
	var hud := game.get_node("HUD") as WastelandHUD
	_check(hud.layer == 10 and hud.get_node("Margin").is_visible_in_tree(), "combat HUD remains on its dedicated visible layer")
	_check(hud.get_node("CombatDock").visible, "combat tactical dock is visible")
	_check(hud._weapon_status != null and hud._weapon_status.text.contains("单发"), "combat dock reports the equipped weapon and damage")
	_check(hud._gadget_status != null and hud._gadget_status.text.contains("震爆"), "combat dock reports grenade hotkeys")
	_check(hud._skill_status != null and hud._skill_status.text.contains("暴怒"), "combat dock reports active player skills")
	_check(hud._upgrade_status != null and hud._upgrade_status.text.contains("强化"), "combat dock reports upgrade availability")
	_check(hud._dash_status != null and hud._dash_status.text.contains("闪避"), "combat dock reports dash state")
	hud._layout_tactical_bar()
	_check((hud.get_node("CombatDock") as Control).size.y >= 120.0, "combat tactical dock keeps a readable fixed height")
	await process_frame
	_check(hud._weapon_status.is_visible_in_tree() and hud._weapon_status.get_global_rect().size.x >= 80.0 and hud._weapon_status.get_global_rect().size.y <= 44.0, "weapon status stays inside its card")
	_check(hud._gadget_status.is_visible_in_tree() and hud._gadget_status.get_global_rect().size.x >= 80.0 and hud._gadget_status.get_global_rect().size.y <= 44.0, "gadget status stays inside its card")
	_check(hud._skill_status.is_visible_in_tree() and hud._skill_status.get_global_rect().size.x >= 80.0 and hud._skill_status.get_global_rect().size.y <= 44.0, "skill status stays inside its card")
	_check(hud._upgrade_status.is_visible_in_tree() and hud._upgrade_status.get_global_rect().size.x >= 80.0 and hud._upgrade_status.get_global_rect().size.y <= 44.0, "upgrade status stays inside its card")
	_check(hud._dash_status.is_visible_in_tree() and hud._dash_status.get_global_rect().size.x >= 80.0 and hud._dash_status.get_global_rect().size.y <= 44.0, "dash status stays inside its card")
	game.queue_free()
	await process_frame
	state.start_campaign()


func _test_penetration() -> void:
	var enemy_scene := load("res://scenes/chaser.tscn") as PackedScene
	var projectile_scene := load("res://scenes/projectile.tscn") as PackedScene
	var first := enemy_scene.instantiate() as ScrapChaser
	var second := enemy_scene.instantiate() as ScrapChaser
	var projectile := projectile_scene.instantiate()
	first.position = Vector3(3.0, 0.65, 0.0)
	second.position = Vector3(6.0, 0.65, 0.0)
	root.add_child(first)
	root.add_child(second)
	root.add_child(projectile)
	await physics_frame
	var rail := load("res://assets/data/weapons/rail_lance.tres") as WeaponData
	_check(projectile.configure(rail), "rail projectile accepts valid configuration")
	projectile.launch(Vector3(0.0, 0.88, 0.0), Vector3.RIGHT)
	for frame in 20:
		await physics_frame
		if first.health < first.max_health and second.health < second.max_health:
			break
	_check(first.health < first.max_health, "penetrating projectile damages first enemy")
	_check(second.health < second.max_health, "penetrating projectile continues into second enemy")
	if is_instance_valid(projectile):
		projectile.queue_free()
	if is_instance_valid(first):
		first.queue_free()
	if is_instance_valid(second):
		second.queue_free()
	await process_frame


func _test_status_duration_and_ticks() -> void:
	var target := DamageTarget.new()
	var controller := StatusEffectController.new()
	target.add_child(controller)
	root.add_child(target)
	await process_frame
	var slow := (load("res://assets/data/status/slow.tres") as StatusEffectData).duplicate(true) as StatusEffectData
	slow.proc_chance = 1.0
	_check(controller.apply_effect(slow), "slow status applies")
	_check(controller.movement_multiplier() < 1.0, "slow status changes movement multiplier")
	controller.advance(slow.duration + 0.01)
	_check(not controller.has_effect(slow.effect_id), "slow status expires after configured duration")
	_check(is_equal_approx(controller.movement_multiplier(), 1.0), "expired slow restores movement multiplier")
	var burn := (load("res://assets/data/status/burn.tres") as StatusEffectData).duplicate(true) as StatusEffectData
	burn.proc_chance = 1.0
	_check(controller.apply_effect(burn), "burn status applies")
	controller.advance(burn.tick_interval + 0.01)
	_check(target.received > 0.0, "burn status uses shared damage entry point")
	var invalid := StatusEffectData.new()
	_check(not controller.apply_effect(invalid), "invalid status configuration is rejected")
	target.queue_free()
	await process_frame


func _test_player_gadget_fields() -> void:
	var enemy := (load("res://scenes/chaser.tscn") as PackedScene).instantiate() as ScrapChaser
	enemy.enemy_data = load("res://assets/data/enemies/chaser.tres") as EnemyData
	enemy.position = Vector3(2.0, 0.0, 0.0)
	enemy.add_to_group("enemies")
	root.add_child(enemy)
	await process_frame
	var fire := PlayerGroundField.new()
	root.add_child(fire)
	fire.configure(&"fire", Vector3.ZERO, 4.0, 12.0, Color.ORANGE, "燃烧瓶")
	await process_frame
	fire._apply_tick()
	_check(enemy.health < enemy.max_health, "player fire field damages enemies")
	var emp := PlayerGroundField.new()
	root.add_child(emp)
	emp.configure(&"emp", Vector3.ZERO, 4.0, 8.0, Color.CORNFLOWER_BLUE, "电磁炸弹")
	await process_frame
	emp._apply_tick()
	_check(enemy._slow_multiplier < 1.0 and enemy._slow_remaining > 0.0, "EMP field slows nearby enemies")
	var grenade := PlayerGadget.new()
	root.add_child(grenade)
	grenade.configure(&"shock", Vector3.ZERO, Vector3(2.0, 0.0, 0.0), 3.5, 24.0, Color.CYAN, "震爆手雷")
	await process_frame
	grenade._damage_enemies(Vector3(2.0, 0.0, 0.0), 3.5, 24.0, 15.0)
	_check(enemy.health < enemy.max_health - 12.0, "shock grenade damages at its target point")
	if is_instance_valid(fire):
		fire.queue_free()
	if is_instance_valid(emp):
		emp.queue_free()
	if is_instance_valid(grenade):
		grenade.queue_free()
	if is_instance_valid(enemy):
		enemy.queue_free()
	await process_frame


func _test_generated_audio() -> void:
	var stream := SoundSynth.tone(440.0, 0.05)
	_check(stream != null, "synthesized audio stream exists")
	_check(stream.data.size() > 0, "synthesized audio has sample data")


func _test_repeated_game_cleanup() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var baseline := root.get_child_count()
	for run_index in 3:
		var game := game_scene.instantiate()
		root.add_child(game)
		await process_frame
		await process_frame
		game.queue_free()
		await process_frame
	_check(root.get_child_count() == baseline, "repeated game scenes release root nodes")


func _test_upgrade_offer_flow() -> void:
	var game := (load("res://scenes/game.tscn") as PackedScene).instantiate()
	game.initial_spawn_interval = 99.0
	root.add_child(game)
	await process_frame
	var enemy := (load("res://scenes/chaser.tscn") as PackedScene).instantiate() as ScrapChaser
	game.get_node("Enemies").add_child(enemy)
	await process_frame
	game._on_enemy_died(enemy)
	await process_frame
	_check(not game.upgrade_panel.overlay.visible, "first kill does not trigger upgrade")
	game._on_enemy_died(enemy)
	await process_frame
	_check(game._upgrade_ready, "second kill marks an upgrade as ready")
	_check(not game.upgrade_panel.overlay.visible, "ready upgrade does not interrupt combat")
	_check(not paused, "ready upgrade leaves combat running")
	game._offer_upgrade()
	await process_frame
	_check(game.upgrade_panel.overlay.visible, "F upgrade action opens the ready offer")
	_check(paused, "opened upgrade offer pauses combat")
	_check(game.upgrade_panel._choices.size() == 3, "upgrade panel displays three choices")
	game.upgrade_panel._choose(0)
	await process_frame
	_check(not paused, "choosing an upgrade resumes combat")
	_check(not game.upgrade_panel.overlay.visible, "upgrade panel closes after selection")
	_check(game.player.skill_system._levels.size() == 1, "selected skill is applied to player")
	game.queue_free()
	await process_frame


func _test_campaign_ending() -> void:
	var state := root.get_node("GameState")
	state.start_campaign()
	state.current_stage = state.MAX_STAGE
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var game := game_scene.instantiate()
	game.round_duration = 1.0
	game.initial_spawn_interval = 99.0
	game.required_kills = 0
	root.add_child(game)
	await process_frame
	game._finish_round(true)
	await process_frame
	_check(game._ending_started, "stage ten victory starts the campaign ending")
	_check(game.get_node_or_null("PauseLayer/EndCredits") != null, "stage ten creates the end credits layer")
	_check(not game.result_panel.visible, "stage ten ending does not use the normal result panel")
	_check(state.has_achievement(&"campaign_complete"), "stage ten records the campaign completion achievement")
	paused = false
	game.queue_free()
	await process_frame
	state.start_campaign()


func _test_round_results() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene

	var victory_game := game_scene.instantiate()
	victory_game.round_duration = 1.0
	victory_game.initial_spawn_interval = 99.0
	victory_game.required_kills = 0
	root.add_child(victory_game)
	await process_frame
	victory_game._process(1.1)
	_check(victory_game._round_finished, "timer expiry finishes the round")
	_check(
		victory_game.get_node("PauseLayer/ResultPanel/Panel/Content/Title").text == "区域已肃清",
		"timer expiry shows victory result"
	)
	_check(
		victory_game.get_node("PauseLayer/ResultPanel/Panel/Content/Buttons/NextButton").visible,
		"victory result offers the next stage"
	)
	paused = false
	victory_game.queue_free()
	await process_frame

	var quota_game := game_scene.instantiate()
	quota_game.round_duration = 1.0
	quota_game.initial_spawn_interval = 99.0
	quota_game.required_kills = 2
	root.add_child(quota_game)
	await process_frame
	quota_game._process(1.1)
	_check(quota_game._round_finished, "timer expiry finishes an unmet objective")
	_check(
		quota_game.get_node("PauseLayer/ResultPanel/Panel/Content/Title").text == "区域失守",
		"surviving without enough kills does not win"
	)
	_check(
		not quota_game.get_node("PauseLayer/ResultPanel/Panel/Content/Buttons/NextButton").visible,
		"failed objective does not offer the next stage"
	)
	paused = false
	quota_game.queue_free()
	await process_frame

	var defeat_game := game_scene.instantiate()
	defeat_game.initial_spawn_interval = 99.0
	root.add_child(defeat_game)
	await process_frame
	defeat_game.player.take_damage(defeat_game.player.max_health)
	_check(defeat_game._round_finished, "player death finishes the round")
	_check(
		defeat_game.get_node("PauseLayer/ResultPanel/Panel/Content/Title").text == "作战单元已损毁",
		"player death shows defeat result"
	)
	_check(
		not defeat_game.get_node("PauseLayer/ResultPanel/Panel/Content/Buttons/NextButton").visible,
		"player death does not offer the next stage"
	)
	paused = false
	defeat_game.queue_free()
	await process_frame
