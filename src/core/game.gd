extends Node3D

const ENEMY_SCENE := preload("res://scenes/chaser.tscn")
const IMPACT_SCENE := preload("res://scenes/impact_flash.tscn")
const BOSS_SCENE := preload("res://scenes/boss.tscn")
const SALVAGE_CACHE := preload("res://src/world/salvage_cache.gd")
const WEAPON_PICKUP := preload("res://src/world/weapon_pickup.gd")
const END_CREDITS := preload("res://src/ui/end_credits.gd")
const BOSS_SPAWN_DISTANCE := 5.8
const BOSS_SPAWN_CLEARANCE := 2.05
const ENEMY_CATALOG: Array[EnemyData] = [
	preload("res://assets/data/enemies/chaser.tres"),
	preload("res://assets/data/enemies/shooter.tres"),
	preload("res://assets/data/enemies/bomber.tres"),
	preload("res://assets/data/enemies/heavy.tres"),
	preload("res://assets/data/enemies/repair.tres"),
	preload("res://assets/data/enemies/mage.tres"),
	preload("res://assets/data/enemies/elite_blink.tres"),
	preload("res://assets/data/enemies/elite_hazard.tres"),
	preload("res://assets/data/enemies/elite_sentinel.tres"),
]
const SKILL_CATALOG: Array[SkillData] = [
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
]

@export var round_duration: float = 60.0
@export var initial_spawn_interval: float = 2.8
@export var minimum_spawn_interval: float = 1.5
@export var max_active_enemies: int = 16
@export var required_kills: int = 8
@export var upgrade_kill_interval: int = 2
@export var boss_spawn_elapsed: float = 30.0

var time_left: float
var kills: int = 0
var _spawn_cooldown: float = 0.5
var _round_finished: bool = false
var _paused: bool = false
var _rng := RandomNumberGenerator.new()
var _camera_shake: float = 0.0
var _camera_base_position: Vector3
var _next_upgrade_kills: int
var _upgrade_ready: bool = false
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _active_boss: WastelandBoss
var _boss_position_check_pending := false
var _pending_reward_weapon: WeaponData
var _zone_cache_interval := 6
var _zone_cache_scrap := 2
var _next_cache_kills := 6
var _ending_started := false

@onready var player: WastelandPlayer = $Player
@onready var hud: WastelandHUD = $HUD
@onready var pause_panel: Control = $PauseLayer/PausePanel
@onready var result_panel: Control = $PauseLayer/ResultPanel
@onready var camera: Camera3D = $Player/CameraRig/Camera3D
@onready var upgrade_panel: UpgradePanel = $UpgradePanel
@onready var boss_debug_panel: BossDebugPanel = $BossDebugPanel
@onready var weapon_reward_panel: WeaponRewardPanel = $WeaponRewardPanel
@onready var route_panel: RoutePanel = $RoutePanel


func _ready() -> void:
	GameState.begin_run()
	_apply_stage_difficulty()
	_apply_zone_contract()
	time_left = round_duration
	_rng.randomize()
	_camera_base_position = camera.position
	_next_upgrade_kills = upgrade_kill_interval
	player.health_changed.connect(hud.set_health)
	player.died.connect(_on_player_died)
	player.fired.connect(_on_player_fired)
	player.dash_started.connect(_on_dash_started)
	player.weapon_changed.connect(_on_weapon_changed)
	player.skill_upgraded.connect(_on_skill_upgraded)
	player.action_message.connect(_on_action_message)
	player.interaction_hint.connect(hud.set_interaction_hint)
	upgrade_panel.skill_selected.connect(_on_skill_selected)
	weapon_reward_panel.weapon_selected.connect(_on_weapon_reward_selected)
	route_panel.route_selected.connect(_on_route_selected)
	hud.set_health(player.health, player.max_health)
	hud.set_time(time_left)
	hud.set_kills(kills, required_kills)
	hud.set_stage(GameState.current_stage, $Arena.map_display_name)
	hud.set_weapon(player.current_weapon, player.weapon_index)
	_spawn_pending_weapon()
	for skill in SKILL_CATALOG:
		var carried_level := player.skill_system.get_level(skill.skill_id)
		if carried_level > 0:
			hud.set_skill(skill, carried_level)
	hud.show_message("第 %d 关" % GameState.current_stage, "%s\n击毁 %d 个敌人并坚守六十秒" % [_zone_contract_brief(), required_kills])
	get_tree().create_timer(2.0).timeout.connect(hud.hide_message)
	$PauseLayer/PausePanel/Panel/Content/Buttons/ResumeButton.pressed.connect(_toggle_pause)
	$PauseLayer/PausePanel/Panel/Content/Buttons/RestartButton.pressed.connect(_restart)
	$PauseLayer/PausePanel/Panel/Content/Buttons/MenuButton.pressed.connect(_return_to_menu)
	$PauseLayer/PausePanel/Panel/Content/Buttons/TelemetryButton.pressed.connect(_toggle_telemetry)
	$PauseLayer/ResultPanel/Panel/Content/Buttons/RestartButton.pressed.connect(_restart)
	$PauseLayer/ResultPanel/Panel/Content/Buttons/NextButton.pressed.connect(_next_stage)
	$PauseLayer/ResultPanel/Panel/Content/Buttons/MenuButton.pressed.connect(_return_to_menu)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _round_finished:
		_toggle_pause()
	if Input.is_action_just_pressed("boss_spawn_debug") and not _round_finished and not _boss_spawned:
		_spawn_boss()
	if Input.is_action_just_pressed("upgrade") and _upgrade_ready and not _round_finished and not upgrade_panel.overlay.visible:
		_offer_upgrade()
	if Input.is_action_just_pressed("upgrade_debug") and not _round_finished and not upgrade_panel.overlay.visible:
		_offer_upgrade(true)
	if _paused or _round_finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	_spawn_cooldown -= delta
	hud.set_time(time_left)
	if _spawn_cooldown <= 0.0:
		_spawn_enemy()
		var pressure := 1.0 - time_left / round_duration
		_spawn_cooldown = lerpf(initial_spawn_interval, minimum_spawn_interval, pressure)
	if round_duration - time_left >= _boss_spawn_delay():
		_ensure_boss_present()
	if time_left <= 0.0:
		if kills >= required_kills and (not _boss_spawned or _boss_defeated):
			_finish_round(true)
		else:
			_finish_round(false, "区域失守")
	_update_camera_shake(delta)


func _spawn_enemy() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= max_active_enemies:
		return
	var enemy: ScrapChaser = ENEMY_SCENE.instantiate()
	enemy.enemy_data = _choose_enemy_data()
	enemy.target = player
	enemy.add_to_group("enemies")
	enemy.position = $Arena.combat_spawn_position(_rng)
	$Enemies.add_child(enemy)
	enemy.apply_difficulty(_stage_multiplier())
	enemy.died.connect(_on_enemy_died)
	enemy.hit_player.connect(_on_player_hit)


func _choose_enemy_data() -> EnemyData:
	var elapsed := round_duration - time_left
	var maximum_index := 0
	if elapsed >= 10.0:
		maximum_index = 2
	if elapsed >= 20.0:
		maximum_index = 4
	if elapsed >= 34.0:
		maximum_index = 8
	return ENEMY_CATALOG[_rng.randi_range(0, maximum_index)]


func _spawn_boss() -> void:
	if _boss_defeated or is_instance_valid(_active_boss):
		return
	var boss := BOSS_SCENE.instantiate() as WastelandBoss
	if boss == null:
		push_error("Boss scene could not be instantiated")
		return
	boss.target = player
	boss.add_to_group("enemies")
	$Enemies.add_child(boss)
	_active_boss = boss
	_boss_spawned = true
	boss.global_position = _boss_spawn_position()
	boss.apply_difficulty(_stage_multiplier())
	if GameState.current_stage == 1:
		boss.max_health = minf(boss.max_health, 460.0)
		boss.health = boss.max_health
	boss.health_changed.connect(func(current: float, maximum: float) -> void: hud.show_boss(current, maximum))
	boss.phase_changed.connect(func(_index: int, phase: BossPhaseData) -> void: hud.show_boss(boss.health, boss.max_health, phase.display_name))
	boss.summon_requested.connect(_summon_enemies)
	boss.died.connect(_on_boss_died)
	boss_debug_panel.bind_boss(boss)
	hud.show_boss(boss.health, boss.max_health, WastelandBoss.PHASES[0].display_name)
	hud.show_message("警告", "异星母舰已从前方进入战场")
	get_tree().create_timer(2.0).timeout.connect(hud.hide_message)
	# Let the scene enter the tree before making the final visibility check.
	# This also protects later maps whose cover layout differs from stage one.
	if not _boss_position_check_pending:
		_boss_position_check_pending = true
		call_deferred("_verify_boss_spawn", boss)


func _ensure_boss_present() -> void:
	if _boss_defeated or is_instance_valid(_active_boss):
		return
	# A queued-free boss or a failed initial insertion must not leave a stage
	# unwinnable just because its boolean was set before it reached the tree.
	_boss_spawned = false
	_spawn_boss()


func _verify_boss_spawn(boss: WastelandBoss) -> void:
	_boss_position_check_pending = false
	if _boss_defeated or not is_instance_valid(boss) or boss != _active_boss:
		return
	var arena := $Arena
	if not arena.is_clear_for_boss(boss.global_position, BOSS_SPAWN_CLEARANCE) or not _is_boss_position_visible(boss.global_position):
		boss.global_position = _boss_spawn_position()
	# A Boss health bar must remain visible even while its entrance animation is playing.
	hud.show_boss(boss.health, boss.max_health, WastelandBoss.PHASES[boss.phase_index].display_name)


func _summon_enemies(count: int) -> void:
	for index in count:
		_spawn_enemy()


func _on_boss_died() -> void:
	_active_boss = null
	_boss_defeated = true
	kills += 3
	hud.set_kills(kills, required_kills)
	hud.hide_boss()
	hud.show_message("核心摧毁", "异星母舰已停止运行")
	get_tree().create_timer(2.0).timeout.connect(hud.hide_message)


func _on_enemy_died(enemy: ScrapChaser) -> void:
	kills += 1
	player.on_kill()
	hud.set_kills(kills, required_kills)
	_spawn_impact(enemy.global_position, Color("ffb340"))
	_camera_shake = maxf(_camera_shake, 0.12)
	if kills >= _next_upgrade_kills and not _round_finished and not _upgrade_ready:
		_mark_upgrade_ready()
	if kills >= _next_cache_kills and not _round_finished:
		_spawn_salvage_cache(enemy.global_position)
		_next_cache_kills += _zone_cache_interval


func _on_player_hit() -> void:
	_camera_shake = maxf(_camera_shake, 0.22)


func _on_player_fired(recoil: float) -> void:
	_camera_shake = maxf(_camera_shake, recoil * 0.06)


func _boss_spawn_delay() -> float:
	# The first stage is the tutorial encounter. It must always appear early
	# enough to be seen and defeated before the sixty-second round ends.
	if GameState.current_stage == 1:
		return 8.0
	return minf(boss_spawn_elapsed, 12.0)


func _boss_spawn_position() -> Vector3:
	# A single fixed point worked on the rectangular first map but can land in
	# cover on the angled second map.  Prefer a clear point that is already in
	# the player's camera view; fall back to a safe point near the player.
	var directions := [
		Vector3(0.0, 0.0, -1.0),
		Vector3(0.72, 0.0, -0.7).normalized(),
		Vector3(-0.72, 0.0, -0.7).normalized(),
		Vector3(1.0, 0.0, 0.0),
		Vector3(-1.0, 0.0, 0.0),
		Vector3(0.0, 0.0, 1.0),
	]
	if player.global_position.z < -3.5:
		directions.reverse()
	for direction in directions:
		var candidate: Vector3 = player.global_position + direction * BOSS_SPAWN_DISTANCE
		candidate.y = 0.0
		candidate = $Arena.confine_to_combat_area(candidate, 2.2)
		if $Arena.is_clear_for_boss(candidate, BOSS_SPAWN_CLEARANCE) and _is_boss_position_visible(candidate):
			return candidate
	var fallback: Vector3 = $Arena.confine_to_combat_area(player.global_position + Vector3(0.0, 0.0, 3.6), 2.2)
	fallback.y = 0.0
	return fallback


func _is_boss_position_visible(position_value: Vector3) -> bool:
	if camera == null or camera.is_position_behind(position_value + Vector3.UP * 0.9):
		return false
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return true
	var screen_position: Vector2 = camera.unproject_position(position_value + Vector3.UP * 0.9)
	return Rect2(Vector2(18.0, 72.0), viewport_size - Vector2(36.0, 150.0)).has_point(screen_position)


func _mark_upgrade_ready() -> void:
	_upgrade_ready = true
	hud.show_upgrade_ready()
	hud.show_message("强化模块就绪", "按 E 打开强化选择，当前战斗不会中断")
	get_tree().create_timer(2.4).timeout.connect(hud.hide_message)


func _offer_upgrade(force: bool = false) -> void:
	if _round_finished or upgrade_panel.overlay.visible or (not _upgrade_ready and not force):
		return
	var choices := player.skill_system.available_choices(SKILL_CATALOG, 3, _rng)
	if choices.is_empty():
		_next_upgrade_kills = 1 << 30
		_upgrade_ready = false
		hud.show_all_skills_maxed()
		return
	_upgrade_ready = false
	hud.clear_upgrade_ready()
	_paused = true
	get_tree().paused = true
	upgrade_panel.show_choices(choices, player.skill_system)


func _on_skill_selected(skill: SkillData) -> void:
	if not player.apply_skill(skill):
		return
	_next_upgrade_kills += upgrade_kill_interval
	_paused = false
	get_tree().paused = false


func _on_weapon_changed(weapon: WeaponData, index: int) -> void:
	hud.set_weapon(weapon, index)


func _on_skill_upgraded(skill: SkillData, level: int) -> void:
	hud.set_skill(skill, level)


func _on_action_message(message: String) -> void:
	# Gadget feedback must not cover the tactical view while the player aims.
	hud.show_salvage_hint(message)


func _on_dash_started() -> void:
	hud.set_dash_ready(false)
	get_tree().create_timer(player.dash_cooldown).timeout.connect(func() -> void: hud.set_dash_ready(true))


func _spawn_impact(at: Vector3, color: Color, size: float = 0.28) -> void:
	var effect: MeshInstance3D = IMPACT_SCENE.instantiate()
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	effect.material_override = material
	effect.scale = Vector3.ONE * size
	add_child(effect)
	effect.global_position = at


func _update_camera_shake(delta: float) -> void:
	_camera_shake = move_toward(_camera_shake, 0.0, delta * 1.8)
	if _camera_shake > 0.0:
		camera.position = _camera_base_position + Vector3(
			_rng.randf_range(-_camera_shake, _camera_shake),
			_rng.randf_range(-_camera_shake, _camera_shake),
			0.0
		)
	else:
		camera.position = _camera_base_position


func _on_player_died() -> void:
	_finish_round(false)


func _finish_round(victory: bool, failure_title: String = "作战单元已损毁") -> void:
	if _round_finished:
		return
	_round_finished = true
	if victory:
		_auto_collect_stage_loot()
	GameState.finish_run(round_duration - time_left, kills)
	if victory and GameState.current_stage >= GameState.MAX_STAGE:
		_show_campaign_ending()
		return
	result_panel.visible = true
	result_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var title := "区域已肃清" if victory else failure_title
	var detail := "第 %d 关   |   存活 %02d:%02d   |   击毁敌人 %d" % [
		GameState.current_stage,
		int(GameState.last_survival_time) / 60,
		int(GameState.last_survival_time) % 60,
		kills,
	]
	$PauseLayer/ResultPanel/Panel/Content/Title.text = title
	$PauseLayer/ResultPanel/Panel/Content/Detail.text = detail
	var next_button: Button = $PauseLayer/ResultPanel/Panel/Content/Buttons/NextButton
	next_button.visible = victory and GameState.current_stage < GameState.MAX_STAGE
	next_button.text = "领取武器，进入第 %d 关" % mini(GameState.current_stage + 1, GameState.MAX_STAGE)
	get_tree().paused = true
	if victory:
		next_button.grab_focus()
	else:
		$PauseLayer/ResultPanel/Panel/Content/Buttons/RestartButton.grab_focus()


func _show_campaign_ending() -> void:
	if _ending_started:
		return
	_ending_started = true
	GameState.unlock_achievement(&"campaign_complete")
	get_tree().paused = true
	var credits := END_CREDITS.new() as Control
	credits.name = "EndCredits"
	$PauseLayer.add_child(credits)
	credits.finished.connect(_return_to_menu)


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	pause_panel.visible = _paused
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	if _paused:
		_update_telemetry_button()
		$PauseLayer/PausePanel/Panel/Content/Buttons/ResumeButton.grab_focus()


func _toggle_telemetry() -> void:
	GameState.show_combat_telemetry = not GameState.show_combat_telemetry
	_update_telemetry_button()
	hud.show_message("战场显示", "敌人血条与数值已%s" % ("显示" if GameState.show_combat_telemetry else "隐藏"))


func _update_telemetry_button() -> void:
	$PauseLayer/PausePanel/Panel/Content/Buttons/TelemetryButton.text = "战斗数值：%s" % ("显示" if GameState.show_combat_telemetry else "隐藏")


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _next_stage() -> void:
	result_panel.visible = false
	var pool: Array[WeaponData] = []
	# The first choice is always the equipped weapon: players can explicitly
	# choose to upgrade it instead of taking a new weapon category.
	if player.current_weapon != null:
		pool.append(player.current_weapon)
	for weapon in WastelandPlayer.WEAPON_CATALOG:
		var candidate := weapon as WeaponData
		if candidate != null and (player.current_weapon == null or candidate.weapon_id != player.current_weapon.weapon_id):
			pool.append(candidate)
	for index in range(pool.size() - 1, 1, -1):
		var swap_index := _rng.randi_range(1, index)
		var temporary := pool[index]
		pool[index] = pool[swap_index]
		pool[swap_index] = temporary
	var rewards: Array[WeaponData] = []
	rewards.append(pool[0])
	rewards.append_array(pool.slice(1, 3))
	weapon_reward_panel.show_rewards(rewards)


func _auto_collect_stage_loot() -> void:
	var recovered := 0
	for candidate in get_tree().get_nodes_in_group("salvage_caches"):
		if candidate is SalvageCache and (candidate as SalvageCache).collect(player, false):
			recovered += 1
	if recovered > 0:
		hud.show_salvage_hint("关卡结算已自动回收 %d 个补给箱" % recovered)


func _on_weapon_reward_selected(weapon: WeaponData) -> void:
	_pending_reward_weapon = weapon
	# Routes are generated by the starport network. Weapon choice remains
	# player-controlled, while the next environment is a fresh random contract.
	_on_route_selected(_rng.randi_range(0, 9))


func _on_route_selected(zone: int) -> void:
	if _pending_reward_weapon == null:
		return
	var level := GameState.queue_weapon_reward(_pending_reward_weapon.weapon_id)
	var module_id := GameState.grant_weapon_module(_pending_reward_weapon.weapon_id)
	var storage_note := "已写入背包" if GameState.pending_weapon_id.is_empty() else "背包已满，武器寄存器已部署"
	hud.show_salvage_hint("%s升至 %d 级，获得武器模块：%s  ·  %s" % [_pending_reward_weapon.display_name, level, _weapon_module_name(module_id), storage_note])
	GameState.select_zone(zone)
	GameState.advance_stage()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _weapon_module_name(module_id: StringName) -> String:
	match module_id:
		&"overdrive": return "超频射速"
		&"impact": return "冲击增幅"
		&"ricochet": return "偏转反弹"
		&"seeker": return "追踪锁定"
		&"range": return "超距聚焦"
		_: return "未知模块"


func _apply_zone_contract() -> void:
	match GameState.selected_zone:
		0:
			_zone_cache_interval = 5
			_zone_cache_scrap = 3
		1:
			initial_spawn_interval *= 0.88
			minimum_spawn_interval *= 0.9
			_zone_cache_interval = 7
		2:
			upgrade_kill_interval = maxi(1, upgrade_kill_interval - 1)
			_next_upgrade_kills = upgrade_kill_interval
			max_active_enemies += 3
			_zone_cache_interval = 7
		3:
			player.apply_zone_support(28.0, 0.45)
			_zone_cache_interval = 6
			_zone_cache_scrap = 2
		4:
			_zone_cache_interval = 4
			_zone_cache_scrap = 3
		5:
			player.apply_zone_support(0.0, 0.85)
			_zone_cache_interval = 5
		6:
			max_active_enemies += 4
			_zone_cache_interval = 5
			_zone_cache_scrap = 3
		_:
			player.apply_zone_support(40.0, 0.15)
			_zone_cache_interval = 5
	_next_cache_kills = _zone_cache_interval


func _zone_contract_brief() -> String:
	match GameState.selected_zone:
		0: return "轨道打捞：补给箱提供更多合金"
		1: return "日冕过载：敌军推进更快，等离子舱更多"
		2: return "高压试验：强化模块更频繁，敌群更密集"
		3: return "冷却庇护：获得额外生命与机动能力"
		4: return "坠落打捞：回收箱出现更频繁"
		5: return "星云机动：获得更高移动速度"
		6: return "月面围猎：敌群更密集，合金更多"
		7: return "深空矿区：获得重装生命补给"
		8: return "红移中继：武器模块更易出现"
		_: return "极光塔防：防线获得稳定补给"


func _spawn_salvage_cache(origin: Vector3) -> void:
	var cache := SALVAGE_CACHE.new() as SalvageCache
	cache.scrap_amount = _zone_cache_scrap
	cache.heal_amount = 18.0 if GameState.selected_zone == 3 else 13.0
	cache.armor_charge = 8.0 if _rng.randf() < 0.18 else 0.0
	cache.global_position = origin + Vector3(_rng.randf_range(-0.7, 0.7), 0.0, _rng.randf_range(-0.7, 0.7))
	add_child(cache)
	cache.collected.connect(_on_salvage_cache_collected)
	hud.show_salvage_hint("回收箱已投放")


func _on_salvage_cache_collected(scrap_amount: int, heal_amount: float) -> void:
	GameState.add_scrap(scrap_amount)
	hud.show_salvage_hint("回收 +%d 合金  ·  +%d 生命" % [scrap_amount, int(heal_amount)])


func _spawn_pending_weapon() -> void:
	if GameState.pending_weapon_id.is_empty():
		return
	var reward: WeaponData
	for candidate in WastelandPlayer.WEAPON_CATALOG:
		var weapon := candidate as WeaponData
		if weapon != null and weapon.weapon_id == GameState.pending_weapon_id:
			reward = weapon
			break
	if reward == null:
		GameState.clear_pending_weapon(GameState.pending_weapon_id)
		return
	var pickup := WEAPON_PICKUP.new()
	pickup.configure(reward)
	pickup.global_position = player.global_position + Vector3(2.0, 0.0, 1.2)
	call_deferred("add_child", pickup)
	hud.show_salvage_hint("武器寄存器已部署  ·  靠近后按 F 更换装备")


func _stage_multiplier() -> float:
	# Endless scaling: early stages ramp quickly, later stages stay survivable with upgrades.
	return 1.0 + float(GameState.current_stage - 1) * 0.11 + pow(float(GameState.current_stage - 1), 1.18) * 0.012


func _apply_stage_difficulty() -> void:
	var stage_offset := GameState.current_stage - 1
	required_kills += mini(stage_offset * 2, 44)
	max_active_enemies += mini(stage_offset * 2, 22)
	initial_spawn_interval = maxf(initial_spawn_interval * pow(0.94, stage_offset), 1.7)
	minimum_spawn_interval = maxf(minimum_spawn_interval * pow(0.94, stage_offset), 0.85)
	if GameState.current_stage >= GameState.MAX_STAGE and GameState.unlock_achievement(&"endless_2000"):
		hud.show_message("终焉守望者", "你已抵达第 %d 关，获得星域守望者成就" % GameState.MAX_STAGE)


func _return_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
