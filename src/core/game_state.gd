extends Node

const MAX_STAGE := 24
const PLAYABLE_SKINS := [
	&"prism_guardian",
	&"red_guardian",
	&"orange_guardian",
	&"yellow_guardian",
	&"green_guardian",
	&"cyan_guardian",
	&"blue_guardian",
	&"violet_guardian",
]
const BASE_TACTICAL_SKILLS: Array[StringName] = [&"fury", &"recovery", &"bounce", &"tracking"]
const ACHIEVEMENT_IDS: Array[StringName] = [
	&"first_skin_change",
	&"sector_6_reached",
	&"sector_12_reached",
	&"sector_18_reached",
	&"sector_24_reached",
	&"campaign_complete",
	&"campaign_24_complete",
]

var last_survival_time: float = 0.0
var last_kills: int = 0
var runs_started: int = 0
var current_stage: int = 1
var carried_skill_levels: Dictionary = {}
var campaign_seed: int = 1
var weapon_levels: Dictionary = {&"flame_projector": 1}
var unlocked_weapons: Dictionary = {&"flame_projector": true}
var loadout_weapon_ids: Array[StringName] = [&"flame_projector"]
var selected_start_weapon_id: StringName = &"flame_projector"
var pending_weapon_id: StringName = &""
var show_combat_telemetry: bool = true
var selected_zone: int = 0
var scrap: int = 12
var garden_level: int = 0
var home_skill_levels: Dictionary = {}
var weapon_modules: Dictionary = {}
var achievements: Dictionary = {}
var equipped_skin: StringName = &"prism_guardian"
var carried_health: float = -1.0
var campaign_active: bool = false
var highest_stage: int = 1
var total_kills: int = 0
var total_runs: int = 0
var weapon_usage: Dictionary = {}
var master_volume: float = 0.8
var audio_muted: bool = false
var _pending_resume_stage: int = 0


func _ready() -> void:
	apply_audio_settings()


func start_campaign() -> void:
	campaign_active = true
	current_stage = 1
	_pending_resume_stage = 0
	carried_skill_levels.clear()
	campaign_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	weapon_levels = {selected_start_weapon_id: 1}
	unlocked_weapons = {selected_start_weapon_id: true}
	loadout_weapon_ids = [selected_start_weapon_id]
	pending_weapon_id = &""
	carried_health = -1.0
	highest_stage = maxi(highest_stage, current_stage)
	_autosave()


func continue_campaign() -> bool:
	var manager := get_node_or_null("/root/SaveManager")
	if manager == null or not manager.apply_campaign(self):
		return false
	# Hold the restored stage until the battle scene is ready. This protects a
	# continue action from any new-campaign initialization during scene loading.
	_pending_resume_stage = current_stage
	return true


func consume_resume_stage() -> int:
	var restored_stage := _pending_resume_stage
	_pending_resume_stage = 0
	return restored_stage


func advance_stage() -> void:
	current_stage = mini(current_stage + 1, MAX_STAGE)
	highest_stage = maxi(highest_stage, current_stage)
	if current_stage >= 6:
		unlock_achievement(&"sector_6_reached")
	if current_stage >= 12:
		unlock_achievement(&"sector_12_reached")
	if current_stage >= 18:
		unlock_achievement(&"sector_18_reached")
	if current_stage >= MAX_STAGE:
		unlock_achievement(&"sector_24_reached")
	campaign_active = true
	_autosave()


func complete_campaign() -> void:
	# Archive the successful campaign without leaving a resumable final-stage run.
	achievements[&"campaign_complete"] = true
	achievements[&"campaign_24_complete"] = true
	campaign_active = false
	current_stage = 1
	_pending_resume_stage = 0
	carried_skill_levels.clear()
	weapon_levels = {selected_start_weapon_id: 1}
	unlocked_weapons = {selected_start_weapon_id: true}
	loadout_weapon_ids = [selected_start_weapon_id]
	pending_weapon_id = &""
	carried_health = -1.0
	_autosave()


func record_skill(skill_id: StringName, level: int) -> void:
	carried_skill_levels[skill_id] = level
	_autosave()


func upgrade_weapon(weapon_id: StringName) -> int:
	unlocked_weapons[weapon_id] = true
	var next_level := mini(int(weapon_levels.get(weapon_id, 0)) + 1, 10)
	weapon_levels[weapon_id] = next_level
	_autosave()
	return next_level


func queue_weapon_reward(weapon_id: StringName) -> int:
	var level := upgrade_weapon(weapon_id)
	# A free loadout slot receives the reward immediately.  The physical
	# registrar only appears once the operator must decide what to replace.
	if has_weapon_in_loadout(weapon_id) or add_weapon_to_loadout(weapon_id):
		pending_weapon_id = &""
	else:
		pending_weapon_id = weapon_id
	_autosave()
	return level


func grant_weapon_module(weapon_id: StringName) -> StringName:
	var modules: Dictionary = weapon_modules.get(weapon_id, {})
	var catalog: Array[StringName] = [&"overdrive", &"impact", &"ricochet", &"seeker", &"range"]
	var module_id := catalog[posmod(current_stage + str(weapon_id).length(), catalog.size())]
	modules[module_id] = mini(int(modules.get(module_id, 0)) + 1, 5)
	weapon_modules[weapon_id] = modules
	_autosave()
	return module_id


func weapon_module_level(weapon_id: StringName, module_id: StringName) -> int:
	var modules: Dictionary = weapon_modules.get(weapon_id, {})
	return int(modules.get(module_id, 0))


func home_skill_level(skill_id: StringName) -> int:
	# Every operator enters a run with the four tactical controls at level 1.
	# Home training improves that same baseline instead of unlocking a missing key.
	var saved_level := int(home_skill_levels.get(skill_id, 0))
	return maxi(1, saved_level) if skill_id in BASE_TACTICAL_SKILLS else saved_level


func set_carried_health(value: float) -> void:
	carried_health = maxf(value, 1.0)
	_autosave()


func learn_next_home_skill() -> Dictionary:
	var catalog: Array[Dictionary] = [
		{"id": &"fury", "name": "暴怒回路", "max": 5},
		{"id": &"recovery", "name": "治疗协议", "max": 5},
		{"id": &"bounce", "name": "反弹校准", "max": 4},
		{"id": &"tracking", "name": "追踪校准", "max": 4},
	]
	for entry in catalog:
		var skill_id: StringName = entry["id"]
		var level := home_skill_level(skill_id)
		if level >= int(entry["max"]):
			continue
		var cost := 5 + level * 4
		if scrap < cost:
			return {"ok": false, "reason": "合金不足，需要 %d 合金学习%s" % [cost, entry["name"]]}
		scrap -= cost
		home_skill_levels[skill_id] = level + 1
		_autosave()
		return {"ok": true, "name": entry["name"], "level": level + 1, "cost": cost}
	return {"ok": false, "reason": "所有人物技能均已满级"}


func learn_home_skill(skill_id: StringName) -> Dictionary:
	var catalog := {
		&"fury": {"name": "暴怒回路", "max": 5},
		&"recovery": {"name": "治疗协议", "max": 5},
		&"bounce": {"name": "反弹校准", "max": 4},
		&"tracking": {"name": "追踪校准", "max": 4},
	}
	if not catalog.has(skill_id):
		return {"ok": false, "reason": "未知训练项目"}
	var entry: Dictionary = catalog[skill_id]
	var level := home_skill_level(skill_id)
	if level >= int(entry["max"]):
		return {"ok": false, "reason": "%s 已满级" % entry["name"]}
	var cost := 5 + level * 4
	if scrap < cost:
		return {"ok": false, "reason": "合金不足，需要 %d 合金" % cost}
	scrap -= cost
	home_skill_levels[skill_id] = level + 1
	_autosave()
	return {"ok": true, "name": entry["name"], "level": level + 1, "cost": cost}


func home_skill_reset_refund() -> int:
	var refund := 0
	for skill_id in BASE_TACTICAL_SKILLS:
		var saved_level := int(home_skill_levels.get(skill_id, 0))
		for level in range(1, saved_level):
			refund += 5 + level * 4
	return refund


func reset_home_skills() -> int:
	var refund := home_skill_reset_refund()
	home_skill_levels.clear()
	scrap = clampi(scrap + refund, 0, 99999)
	_autosave()
	return refund


func clear_pending_weapon(weapon_id: StringName) -> void:
	if pending_weapon_id == weapon_id:
		pending_weapon_id = &""
		_autosave()


func has_weapon_in_loadout(weapon_id: StringName) -> bool:
	return loadout_weapon_ids.has(weapon_id)


func add_weapon_to_loadout(weapon_id: StringName) -> bool:
	if has_weapon_in_loadout(weapon_id):
		return true
	if loadout_weapon_ids.size() >= 5:
		return false
	unlocked_weapons[weapon_id] = true
	loadout_weapon_ids.append(weapon_id)
	_autosave()
	return true


func remove_weapon_from_loadout(weapon_id: StringName) -> bool:
	if loadout_weapon_ids.size() <= 1:
		return false
	var index := loadout_weapon_ids.find(weapon_id)
	if index < 0:
		return false
	loadout_weapon_ids.remove_at(index)
	_autosave()
	return true


func upgrade_starter_weapon() -> bool:
	var cost := starter_weapon_upgrade_cost()
	if scrap < cost:
		return false
	scrap -= cost
	upgrade_weapon(selected_start_weapon_id)
	return true


func starter_weapon_upgrade_cost() -> int:
	return 4 + weapon_level(selected_start_weapon_id) * 2


func upgrade_health_system() -> bool:
	var cost := health_system_upgrade_cost()
	if scrap < cost:
		return false
	scrap -= cost
	garden_level += 1
	_autosave()
	return true


func health_system_upgrade_cost() -> int:
	return 4 + garden_level * 3


func add_scrap(amount: int) -> void:
	if amount <= 0:
		return
	scrap = clampi(scrap + amount, 0, 99999)
	_autosave()


func select_zone(zone: int) -> void:
	selected_zone = posmod(zone, MAX_STAGE)
	_autosave()


func is_weapon_unlocked(weapon_id: StringName) -> bool:
	return bool(unlocked_weapons.get(weapon_id, false))


func weapon_level(weapon_id: StringName) -> int:
	return int(weapon_levels.get(weapon_id, 0))


func _autosave() -> void:
	var manager := get_node_or_null("/root/SaveManager")
	if manager != null:
		manager.save_campaign(self)


func begin_run() -> void:
	runs_started += 1
	total_runs += 1
	highest_stage = maxi(highest_stage, current_stage)
	last_survival_time = 0.0
	last_kills = 0


func finish_run(survival_time: float, kills: int) -> void:
	last_survival_time = survival_time
	last_kills = kills
	total_kills += maxi(kills, 0)
	scrap += maxi(1, kills / 3) + garden_level
	_autosave()


func record_weapon_use(weapon_id: StringName) -> void:
	if weapon_id.is_empty():
		return
	weapon_usage[weapon_id] = int(weapon_usage.get(weapon_id, 0)) + 1


func favorite_weapon_id() -> StringName:
	var favorite := selected_start_weapon_id
	var highest_count := -1
	for raw_weapon_id in weapon_usage:
		var count := int(weapon_usage[raw_weapon_id])
		if count > highest_count:
			highest_count = count
			favorite = StringName(str(raw_weapon_id))
	return favorite


func favorite_weapon_uses() -> int:
	return int(weapon_usage.get(favorite_weapon_id(), 0))


func achievement_count() -> int:
	var count := 0
	for achievement_id in ACHIEVEMENT_IDS:
		if has_achievement(achievement_id):
			count += 1
	return count


func apply_audio_settings() -> void:
	if AudioServer.get_bus_count() <= 0:
		return
	AudioServer.set_bus_mute(0, audio_muted)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply_audio_settings()
	_autosave()


func set_audio_muted(value: bool) -> void:
	audio_muted = value
	apply_audio_settings()
	_autosave()


func unlock_achievement(achievement_id: StringName) -> bool:
	if bool(achievements.get(achievement_id, false)):
		return false
	achievements[achievement_id] = true
	_autosave()
	return true


func has_achievement(achievement_id: StringName) -> bool:
	return bool(achievements.get(achievement_id, false))
