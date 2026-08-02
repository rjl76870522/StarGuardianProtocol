extends Node

const SAVE_VERSION := 13
const MAX_CAMPAIGN_STAGE := 24
const VALID_WEAPON_IDS: Array[StringName] = [
	&"flame_projector", &"auto_rifle", &"scatter_cannon", &"rail_lance",
	&"arc_blade", &"sidearm", &"sniper_rifle", &"siege_cannon",
]
var save_path := "user://campaign_save.json"
var temp_path := "user://campaign_save.tmp"
var backup_path := "user://campaign_save.backup.json"


func has_campaign() -> bool:
	var data := load_campaign()
	return not data.is_empty() and bool(data.get("campaign_active", true))


func save_campaign(state: Node) -> bool:
	if state == null:
		return false
	var payload := {
		"version": SAVE_VERSION,
		"campaign_active": bool(state.campaign_active),
		"stage": int(state.current_stage),
		"seed": int(state.campaign_seed),
		"skills": _string_key_dictionary(state.carried_skill_levels),
		"weapons": _string_key_dictionary(state.weapon_levels),
		"unlocked_weapons": _string_key_dictionary(state.unlocked_weapons),
		"loadout_weapons": _string_array(state.loadout_weapon_ids),
		"selected_start_weapon": str(state.selected_start_weapon_id),
		"pending_weapon": str(state.pending_weapon_id),
		"scrap": int(state.scrap),
		"garden_level": int(state.garden_level),
		"home_skills": _string_key_dictionary(state.home_skill_levels),
		"weapon_modules": _nested_string_key_dictionary(state.weapon_modules),
		"selected_zone": int(state.selected_zone),
		"achievements": _string_key_dictionary(state.achievements),
		"equipped_skin": str(state.equipped_skin),
		"carried_health": float(state.carried_health),
		"highest_stage": int(state.highest_stage),
		"total_kills": int(state.total_kills),
		"total_runs": int(state.total_runs),
		"weapon_usage": _string_key_dictionary(state.weapon_usage),
		"master_volume": float(state.master_volume),
		"audio_muted": bool(state.audio_muted),
		"saved_at": Time.get_datetime_string_from_system(true),
	}
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(save_path):
		if DirAccess.rename_absolute(save_path, backup_path) != OK:
			return false
	if DirAccess.rename_absolute(temp_path, save_path) != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_path, save_path)
		return false
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	return true


func load_campaign() -> Dictionary:
	var data := _load_file(save_path)
	if not data.is_empty():
		return data
	return _load_file(backup_path)


func _load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {}
	var data := parsed as Dictionary
	var version := int(data.get("version", -1))
	if version < 5 or version > SAVE_VERSION:
		return {}
	if int(data.get("stage", 0)) < 1 or int(data.get("stage", 0)) > MAX_CAMPAIGN_STAGE:
		return {}
	if not data.get("skills", {}) is Dictionary or not data.get("weapons", {}) is Dictionary or not data.get("unlocked_weapons", {}) is Dictionary or not data.get("loadout_weapons", []) is Array:
		return {}
	var loadout: Array = data.get("loadout_weapons", [])
	if loadout.is_empty():
		return {}
	for entry in loadout:
		if not VALID_WEAPON_IDS.has(StringName(str(entry))):
			return {}
	var selected := StringName(str(data.get("selected_start_weapon", "")))
	if selected.is_empty() or not loadout.has(str(selected)):
		return {}
	return data


func apply_campaign(state: Node, allow_inactive: bool = false) -> bool:
	var data := load_campaign()
	if data.is_empty() or state == null or (not allow_inactive and not bool(data.get("campaign_active", true))):
		return false
	# Older campaign saves remain loadable. Clamp rather than discard them when
	# the campaign's final stage changes.
	state.current_stage = clampi(int(data["stage"]), 1, MAX_CAMPAIGN_STAGE)
	state.campaign_seed = int(data.get("seed", 1))
	state.carried_skill_levels = _validated_levels(data.get("skills", {}), 10)
	state.weapon_levels = _validated_levels(data.get("weapons", {}), 20)
	state.unlocked_weapons = _validated_unlocks(data.get("unlocked_weapons", {}))
	state.unlocked_weapons[&"flame_projector"] = true
	state.loadout_weapon_ids = _validated_loadout(data.get("loadout_weapons", []))
	if state.loadout_weapon_ids.is_empty():
		return false
	state.selected_start_weapon_id = StringName(str(data.get("selected_start_weapon", state.loadout_weapon_ids[0])))
	if not state.loadout_weapon_ids.has(state.selected_start_weapon_id):
		state.selected_start_weapon_id = state.loadout_weapon_ids[0]
	# Version 7 changes the default starter from the former automatic rifle to
	# the flame projector. Migrate only legacy saves; choices made afterwards
	# remain the player's own selection.
	if int(data.get("version", 0)) < 7 and state.selected_start_weapon_id == &"auto_rifle":
		state.selected_start_weapon_id = &"flame_projector"
		state.weapon_levels[&"flame_projector"] = maxi(int(state.weapon_levels.get(&"flame_projector", 0)), 1)
		state.unlocked_weapons[&"flame_projector"] = true
		if state.loadout_weapon_ids.is_empty():
			state.loadout_weapon_ids = [&"flame_projector"]
		state._autosave()
	state.pending_weapon_id = StringName(str(data.get("pending_weapon", "")))
	state.scrap = clampi(int(data.get("scrap", 12)), 0, 99999)
	state.garden_level = clampi(int(data.get("garden_level", 0)), 0, 30)
	state.home_skill_levels = _validated_levels(data.get("home_skills", {}), 5)
	state.weapon_modules = _validated_nested_levels(data.get("weapon_modules", {}), 5)
	state.selected_zone = posmod(int(data.get("selected_zone", 0)), MAX_CAMPAIGN_STAGE)
	state.achievements = _validated_unlocks(data.get("achievements", {}))
	# Version 9 replaces the former experimental skins with the fixed eight-skin
	# roster. Existing saves receive the prism guardian instead of an invalid ID.
	var legacy_uniform := int(data.get("version", 0)) < 9
	var saved_skin := StringName(str(data.get("equipped_skin", "prism_guardian")))
	state.equipped_skin = saved_skin if not legacy_uniform and state.PLAYABLE_SKINS.has(saved_skin) else &"prism_guardian"
	state.carried_health = clampf(float(data.get("carried_health", -1.0)), -1.0, 10000.0)
	state.highest_stage = clampi(int(data.get("highest_stage", state.current_stage)), 1, MAX_CAMPAIGN_STAGE)
	state.highest_stage = maxi(state.highest_stage, state.current_stage)
	state.total_kills = clampi(int(data.get("total_kills", 0)), 0, 999999999)
	state.total_runs = clampi(int(data.get("total_runs", 0)), 0, 999999999)
	state.weapon_usage = _validated_levels(data.get("weapon_usage", {}), 999999999)
	state.master_volume = clampf(float(data.get("master_volume", 0.8)), 0.0, 1.0)
	state.audio_muted = bool(data.get("audio_muted", false))
	state.apply_audio_settings()
	state.campaign_active = bool(data.get("campaign_active", true))
	if legacy_uniform:
		state._autosave()
	return true


func apply_profile(state: Node) -> bool:
	# Profile fields live beside the active run for migration compatibility. This
	# loads them even after a completed campaign is deliberately marked inactive.
	return apply_campaign(state, true)


func delete_campaign() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)


func _string_key_dictionary(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		result[str(key)] = source[key]
	return result


func _string_array(source: Array) -> Array:
	var result: Array[String] = []
	for item in source:
		result.append(str(item))
	return result


func _nested_string_key_dictionary(source: Dictionary) -> Dictionary:
	var result := {}
	for outer_key in source:
		if source[outer_key] is Dictionary:
			result[str(outer_key)] = _string_key_dictionary(source[outer_key])
	return result


func _validated_levels(source: Dictionary, maximum: int) -> Dictionary:
	var result := {}
	for key in source:
		var value := int(source[key])
		if value >= 0 and value <= maximum:
			result[StringName(str(key))] = value
	return result


func _validated_unlocks(source: Dictionary) -> Dictionary:
	var result := {}
	for key in source:
		if source[key] is bool:
			result[StringName(str(key))] = bool(source[key])
	return result


func _validated_nested_levels(source: Dictionary, maximum: int) -> Dictionary:
	var result := {}
	for outer_key in source:
		if not source[outer_key] is Dictionary:
			continue
		result[StringName(str(outer_key))] = _validated_levels(source[outer_key], maximum)
	return result


func _validated_loadout(source: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for item in source:
		var weapon_id := StringName(str(item))
		if weapon_id.is_empty() or not VALID_WEAPON_IDS.has(weapon_id) or result.has(weapon_id):
			continue
		result.append(weapon_id)
		if result.size() >= 5:
			break
	if result.is_empty():
		result.append(&"flame_projector")
	return result
