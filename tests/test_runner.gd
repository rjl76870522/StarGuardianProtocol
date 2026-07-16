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
	await _test_scene_smoke()
	await _test_player_damage_and_invulnerability()
	await _test_enemy_damage_once()
	await _test_projectile_does_not_hit_twice()
	_test_generated_audio()
	await _test_repeated_game_cleanup()
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


func _test_scene_smoke() -> void:
	for path in [
		"res://scenes/main_menu.tscn",
		"res://scenes/player.tscn",
		"res://scenes/chaser.tscn",
		"res://scenes/projectile.tscn",
		"res://scenes/hud.tscn",
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


func _test_round_results() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene

	var victory_game := game_scene.instantiate()
	victory_game.round_duration = 1.0
	victory_game.initial_spawn_interval = 99.0
	root.add_child(victory_game)
	await process_frame
	victory_game._process(1.1)
	_check(victory_game._round_finished, "timer expiry finishes the round")
	_check(
		victory_game.get_node("PauseLayer/ResultPanel/Panel/Content/Title").text == "SECTOR SECURED",
		"timer expiry shows victory result"
	)
	paused = false
	victory_game.queue_free()
	await process_frame

	var defeat_game := game_scene.instantiate()
	defeat_game.initial_spawn_interval = 99.0
	root.add_child(defeat_game)
	await process_frame
	defeat_game.player.take_damage(defeat_game.player.max_health)
	_check(defeat_game._round_finished, "player death finishes the round")
	_check(
		defeat_game.get_node("PauseLayer/ResultPanel/Panel/Content/Title").text == "UNIT DESTROYED",
		"player death shows defeat result"
	)
	paused = false
	defeat_game.queue_free()
	await process_frame
