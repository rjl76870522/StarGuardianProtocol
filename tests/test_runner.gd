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
	_test_damage_rules()
	_test_combat_data_resources()
	_test_critical_hits()
	_test_skill_stacking_and_choices()
	await _test_scene_smoke()
	await _test_fire_rate_limit()
	await _test_penetration()
	await _test_status_duration_and_ticks()
	await _test_player_damage_and_invulnerability()
	await _test_player_aim_stays_level()
	await _test_enemy_damage_once()
	await _test_projectile_does_not_hit_twice()
	await _test_projectile_physics_hit()
	await _test_debris_has_collision()
	_test_generated_audio()
	await _test_repeated_game_cleanup()
	await _test_upgrade_offer_flow()
	await _test_round_results()

	if _failures.is_empty():
		print("TEST_RESULT: PASS (%d checks)" % _checks)
		await process_frame
		quit(0)
	else:
		printerr("TEST_RESULT: FAIL (%d failures, %d checks)" % [_failures.size(), _checks])
		await process_frame
		quit(1)


func _test_damage_rules() -> void:
	_check(is_equal_approx(DamageRules.calculate(10.0), 10.0), "base damage")
	_check(is_equal_approx(DamageRules.calculate(10.0, 2.0, 3.0), 17.0), "multiplier and armor")
	_check(is_equal_approx(DamageRules.calculate(2.0, 1.0, 99.0), 1.0), "minimum positive damage")
	_check(is_zero_approx(DamageRules.calculate(-1.0)), "invalid damage is zero")


func _test_combat_data_resources() -> void:
	var weapon_paths := [
		"res://assets/data/weapons/auto_rifle.tres",
		"res://assets/data/weapons/scatter_cannon.tres",
		"res://assets/data/weapons/rail_lance.tres",
	]
	for path in weapon_paths:
		var weapon := load(path) as WeaponData
		_check(weapon != null and weapon.is_valid(), "valid weapon resource: %s" % path)
		_check(weapon.icon != null, "weapon has an icon: %s" % path)
	var invalid_weapon := WeaponData.new()
	_check(not invalid_weapon.is_valid(), "invalid weapon configuration is rejected")
	for skill_id in ["rapid_fire", "move_speed", "ricochet", "penetration", "kill_heal", "orbit_drone"]:
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
	_check(system.get_level(&"rapid_fire") == 3, "skill levels stack to maximum")
	_check(is_equal_approx(system.get_value(&"rapid_fire"), 1.5), "stacked skill exposes final value")
	_check(not system.apply_upgrade(rapid), "skill rejects upgrades above maximum")
	var catalog: Array[SkillData] = []
	for skill_id in ["rapid_fire", "move_speed", "ricochet", "penetration", "kill_heal", "orbit_drone"]:
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


func _test_scene_smoke() -> void:
	for path in [
		"res://scenes/main_menu.tscn",
		"res://scenes/player.tscn",
		"res://scenes/chaser.tscn",
		"res://scenes/projectile.tscn",
		"res://scenes/hud.tscn",
		"res://scenes/orbit_drone.tscn",
		"res://scenes/upgrade_panel.tscn",
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
	_check(obstacles.size() == 4, "arena creates four physical debris obstacles")
	for obstacle in obstacles:
		_check(obstacle is StaticBody3D, "debris obstacle is a static body")
		_check(obstacle.get_node_or_null("CollisionShape3D") != null, "debris obstacle has a collision shape")
	if not obstacles.is_empty():
		var obstacle := obstacles[0] as StaticBody3D
		var start := obstacle.global_position + Vector3(-3.0, 0.0, 0.0)
		var finish := obstacle.global_position + Vector3(3.0, 0.0, 0.0)
		var query := PhysicsRayQueryParameters3D.create(start, finish, 1)
		var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
		_check(not hit.is_empty(), "physics ray cannot pass through debris")
		if not hit.is_empty():
			_check(hit["collider"] == obstacle, "physics ray hits the expected debris body")
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


func _test_fire_rate_limit() -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as WastelandPlayer
	root.add_child(player)
	await process_frame
	_check(player._try_fire(), "weapon fires when cooldown is ready")
	_check(not player._try_fire(), "weapon fire rate blocks immediate second shot")
	player._fire_cooldown = 0.0
	_check(player.equip_weapon(1), "shotgun can be equipped")
	_check(player._try_fire(), "shotgun fires through data-driven weapon path")
	_check(not player.equip_weapon(99), "invalid weapon index is rejected")
	player.queue_free()
	for projectile in get_nodes_in_group("projectiles"):
		projectile.queue_free()
	await process_frame


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
	_check(game.upgrade_panel.overlay.visible, "second kill opens upgrade offer")
	_check(paused, "upgrade offer pauses combat")
	_check(game.upgrade_panel._choices.size() == 3, "upgrade panel displays three choices")
	game.upgrade_panel._choose(0)
	await process_frame
	_check(not paused, "choosing an upgrade resumes combat")
	_check(not game.upgrade_panel.overlay.visible, "upgrade panel closes after selection")
	_check(game.player.skill_system._levels.size() == 1, "selected skill is applied to player")
	game.queue_free()
	await process_frame


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
	paused = false
	defeat_game.queue_free()
	await process_frame
