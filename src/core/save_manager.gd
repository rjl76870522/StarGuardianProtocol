extends Node

const SAVE_VERSION := 2
var save_path := "user://campaign_save.json"
var temp_path := "user://campaign_save.tmp"
var backup_path := "user://campaign_save.backup.json"


func has_campaign() -> bool:
	return FileAccess.file_exists(save_path) and not load_campaign().is_empty()


func save_campaign(state: Node) -> bool:
	if state == null:
		return false
	var payload := {
		"version": SAVE_VERSION,
		"stage": int(state.current_stage),
		"seed": int(state.campaign_seed),
		"skills": _string_key_dictionary(state.carried_skill_levels),
		"weapons": _string_key_dictionary(state.weapon_levels),
		"unlocked_weapons": _string_key_dictionary(state.unlocked_weapons),
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
	if int(data.get("version", -1)) != SAVE_VERSION:
		return {}
	if int(data.get("stage", 0)) < 1 or int(data.get("stage", 0)) > 999:
		return {}
	if not data.get("skills", {}) is Dictionary or not data.get("weapons", {}) is Dictionary:
		return {}
	return data


func apply_campaign(state: Node) -> bool:
	var data := load_campaign()
	if data.is_empty() or state == null:
		return false
	state.current_stage = int(data["stage"])
	state.campaign_seed = int(data.get("seed", 1))
	state.carried_skill_levels = _validated_levels(data.get("skills", {}), 10)
	state.weapon_levels = _validated_levels(data.get("weapons", {}), 20)
	state.unlocked_weapons = _validated_unlocks(data.get("unlocked_weapons", {}))
	state.unlocked_weapons[&"auto_rifle"] = true
	return true


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
