extends Control

const ZONES := ["近地轨道平台", "日冕能源环", "量子交叉港", "冷星观测站", "失重航站", "星云补给带", "月面通信阵", "深空采矿区", "红移中继站", "极光防卫塔"]
const START_WEAPONS: Array[Dictionary] = [
	{"id": &"flame_projector", "name": "喷火器"},
	{"id": &"auto_rifle", "name": "自动步枪"},
	{"id": &"scatter_cannon", "name": "霰弹炮"},
	{"id": &"rail_lance", "name": "轨道枪"},
	{"id": &"arc_blade", "name": "电弧刃"},
	{"id": &"sidearm", "name": "脉冲手枪"},
	{"id": &"sniper_rifle", "name": "狙击步枪"},
	{"id": &"siege_cannon", "name": "攻城火炮"},
]


func _ready() -> void:
	$Layout/Panel/Buttons/StartButton.grab_focus()
	var continue_button: Button = $Layout/Panel/Buttons/ContinueButton
	continue_button.disabled = not SaveManager.has_campaign()
	continue_button.text = "继续战役  第 %d 关" % _saved_stage() if not continue_button.disabled else "继续战役  暂无存档"
	_refresh_camp()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _on_continue_pressed() -> void:
	if GameState.continue_campaign():
		get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_zone_pressed() -> void:
	var selected_index := 0
	for index in START_WEAPONS.size():
		if START_WEAPONS[index]["id"] == GameState.selected_start_weapon_id:
			selected_index = index
			break
	GameState.selected_start_weapon_id = START_WEAPONS[posmod(selected_index + 1, START_WEAPONS.size())]["id"]
	GameState._autosave()
	_refresh_camp()


func _on_upgrade_pressed() -> void:
	if GameState.upgrade_starter_weapon():
		_refresh_camp("初始武器已升级")
	else:
		_refresh_camp("合金不足")


func _on_garden_pressed() -> void:
	if GameState.upgrade_health_system():
		_refresh_camp("初始生命已提升")
	else:
		_refresh_camp("合金不足")


func _on_skin_pressed() -> void:
	var skins: Array[StringName] = [&"verdant_scout", &"ember_raider", &"azure_sentinel"]
	var current := skins.find(GameState.equipped_skin)
	GameState.equipped_skin = skins[posmod(current + 1, skins.size())]
	GameState.unlock_achievement(&"first_skin_change")
	GameState._autosave()
	_refresh_camp("外观已切换")


func _refresh_camp(message: String = "") -> void:
	var cost_weapon := 4 + GameState.weapon_level(GameState.selected_start_weapon_id) * 2
	var cost_health := 4 + GameState.garden_level * 3
	$Layout/Panel/Buttons/CampStatus.text = "%s\n合金 %d  |  初始生命 %d  |  当前开局武器 %s" % [message if not message.is_empty() else "星港中枢补给", GameState.scrap, 160 + GameState.garden_level * 18, _start_weapon_name(GameState.selected_start_weapon_id)]
	$Layout/Panel/Buttons/ZoneButton.text = "初始武器：%s  ‹ 点击切换 ›" % _start_weapon_name(GameState.selected_start_weapon_id)
	$Layout/Panel/Buttons/UpgradeButton.text = "升级当前初始武器  ·  消耗 %d 合金" % cost_weapon
	$Layout/Panel/Buttons/GardenButton.text = "升级初始生命  ·  消耗 %d 合金" % cost_health
	$Layout/Panel/Buttons/SkinButton.text = "作战皮肤：%s  ‹ 点击切换 ›" % _skin_name(GameState.equipped_skin)
	$Layout/Panel/Buttons/AchievementStatus.text = "成就档案  ·  已解锁 %d 项  ·  终焉守望者：%s" % [GameState.achievements.size(), "已获得" if GameState.has_achievement(&"endless_2000") else "未获得"]


func _saved_stage() -> int:
	return int(SaveManager.load_campaign().get("stage", 1))


func _skin_name(skin_id: StringName) -> String:
	match skin_id:
		&"ember_raider": return "余烬突袭者"
		&"azure_sentinel": return "湛蓝哨卫"
		_: return "翠绿侦察者"


func _start_weapon_name(weapon_id: StringName) -> String:
	for entry in START_WEAPONS:
		if entry["id"] == weapon_id:
			return str(entry["name"])
	return "喷火器"


func _on_quit_pressed() -> void:
	get_tree().quit()
