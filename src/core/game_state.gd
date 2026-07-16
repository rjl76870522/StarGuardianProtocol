extends Node

var last_survival_time: float = 0.0
var last_kills: int = 0
var runs_started: int = 0
var current_stage: int = 1
var carried_skill_levels: Dictionary = {}
var campaign_seed: int = 1
var weapon_levels: Dictionary = {&"auto_rifle": 1}
var unlocked_weapons: Dictionary = {&"auto_rifle": true}


func start_campaign() -> void:
	current_stage = 1
	carried_skill_levels.clear()
	campaign_seed = int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	weapon_levels = {&"auto_rifle": 1}
	unlocked_weapons = {&"auto_rifle": true}
	_autosave()


func continue_campaign() -> bool:
	var manager := get_node_or_null("/root/SaveManager")
	return manager != null and manager.apply_campaign(self)


func advance_stage() -> void:
	current_stage += 1
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
