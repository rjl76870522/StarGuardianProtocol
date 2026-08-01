extends Node

const MAX_STAGE := 10

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


func start_campaign() -> void:
	current_stage = 1
	carried_skill_levels.clear()
	campaign_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	weapon_levels = {selected_start_weapon_id: 1}
	unlocked_weapons = {selected_start_weapon_id: true}
	loadout_weapon_ids = [selected_start_weapon_id]
	pending_weapon_id = &""
	_autosave()


func continue_campaign() -> bool:
	var manager := get_node_or_null("/root/SaveManager")
	return manager != null and manager.apply_campaign(self)


func advance_stage() -> void:
	current_stage = mini(current_stage + 1, MAX_STAGE)
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
	return int(home_skill_levels.get(skill_id, 0))


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
	selected_zone = posmod(zone, 10)
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
	last_survival_time = 0.0
	last_kills = 0


func finish_run(survival_time: float, kills: int) -> void:
	last_survival_time = survival_time
	last_kills = kills
	scrap += maxi(1, kills / 3) + garden_level
	_autosave()


func unlock_achievement(achievement_id: StringName) -> bool:
	if bool(achievements.get(achievement_id, false)):
		return false
	achievements[achievement_id] = true
	_autosave()
	return true


func has_achievement(achievement_id: StringName) -> bool:
	return bool(achievements.get(achievement_id, false))
