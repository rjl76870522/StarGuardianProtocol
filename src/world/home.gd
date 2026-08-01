class_name WastelandHome
extends Node3D

const ZONES := ["近地轨道平台", "日冕能源环", "量子交叉港", "冷星观测站", "失重航站", "星云补给带", "月面通信阵", "深空采矿区", "红移中继站", "极光防卫塔"]
const OBSTACLE_LAYER := 16

var _stations: Array[Dictionary] = []
var _nearest_station: Dictionary = {}
var _notice_time := 0.0
var _training_panel: Control
var _training_status: Label
var _training_buttons: Dictionary = {}

@onready var player: WastelandPlayer = $Player
@onready var summary: Label = $Interface/Margin/Top/Summary
@onready var prompt: Label = $Interface/Margin/PromptPanel/Prompt
@onready var notice: Label = $Interface/Margin/Notice
@onready var facility_guide: Label = $Interface/Margin/FacilityGuide


func _ready() -> void:
	player.set_home_mode(true)
	player.action_message.connect(_show_notice)
	_create_floor()
	_create_boundary()
	_create_spaceport_shell()
	_create_stations()
	_create_training_panel()
	_refresh_interface()
	_show_notice("星港中枢已上线，靠近发光终端后按 F 交互")


func _process(delta: float) -> void:
	_notice_time = maxf(_notice_time - delta, 0.0)
	if _notice_time <= 0.0:
		notice.visible = false
	_update_nearest_station()
	if Input.is_action_just_pressed("interact") and not _nearest_station.is_empty():
		_interact(StringName(_nearest_station.get("id", &"")))
	if Input.is_action_just_pressed("pause"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _create_floor() -> void:
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(30.0, 0.35, 22.0)
	mesh_node.mesh = mesh
	mesh_node.position.y = -0.18
	mesh_node.material_override = _material(Color("17211f"), 0.35)
	floor.add_child(mesh_node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(30.0, 0.35, 22.0)
	collision.shape = shape
	collision.position.y = -0.18
	floor.add_child(collision)
	add_child(floor)
	for x in range(-14, 15, 2):
		_create_strip(Vector3(x, 0.01, 0.0), Vector3(0.02, 0.01, 21.0), Color("28413a"))
	for z in range(-10, 11, 2):
		_create_strip(Vector3(0.0, 0.012, z), Vector3(29.0, 0.01, 0.02), Color("28413a"))


func _create_boundary() -> void:
	_create_wall(Vector3(0.0, 1.0, -10.8), Vector3(30.8, 2.0, 0.6))
	_create_wall(Vector3(0.0, 1.0, 10.8), Vector3(30.8, 2.0, 0.6))
	_create_wall(Vector3(-15.0, 1.0, 0.0), Vector3(0.6, 2.0, 22.0))
	_create_wall(Vector3(15.0, 1.0, 0.0), Vector3(0.6, 2.0, 22.0))


func _create_spaceport_shell() -> void:
	for index in 16:
		var pile := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.18 + float(index % 3) * 0.1
		mesh.bottom_radius = 0.42 + float(index % 4) * 0.1
		mesh.height = 0.6 + float(index % 3) * 0.34
		pile.mesh = mesh
		var side := -1.0 if index % 2 == 0 else 1.0
		pile.position = Vector3(side * (11.2 + float(index % 3)), mesh.height * 0.5, -8.6 + float(index) * 1.1)
		pile.rotation = Vector3(0.2 * float(index % 2), float(index) * 0.63, 0.18 * side)
		pile.material_override = _material(Color("1d3650").darkened(float(index % 3) * 0.08), 0.35, Color("45b9f3"))
		add_child(pile)
	for index in 5:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("4ca9ff") if index % 2 == 0 else Color("56f1c5")
		lamp.light_energy = 0.55
		lamp.omni_range = 4.0
		lamp.position = Vector3(-10.5 + index * 5.2, 2.0, -8.7)
		add_child(lamp)


func _create_stations() -> void:
	_add_station(&"departure", "出发终端", "开始星际防卫任务", Vector3(0.0, 0.0, -6.8), Color("36e5ad"))
	_add_station(&"workbench", "武器工作台", "升级当前初始武器", Vector3(-7.6, 0.0, -2.4), Color("ffb344"))
	_add_station(&"health", "生命维护舱", "投入合金提升初始生命", Vector3(-7.6, 0.0, 5.2), Color("75d66a"))
	_add_station(&"training", "人物训练舱", "选择局内主动技能", Vector3(7.6, 0.0, -2.4), Color("ee6578"))
	_add_station(&"exit", "返回终端", "返回主菜单", Vector3(7.6, 0.0, 5.2), Color("b490ef"))


func _add_station(id: StringName, title: String, description: String, at: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "%sStation" % title
	body.collision_layer = OBSTACLE_LAYER
	body.position = at
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.85
	pedestal_mesh.bottom_radius = 1.05
	pedestal_mesh.height = 0.58
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.29
	pedestal.material_override = _material(Color("293836"), 0.0)
	body.add_child(pedestal)
	var console := MeshInstance3D.new()
	var console_mesh := BoxMesh.new()
	console_mesh.size = Vector3(0.84, 1.15, 0.55)
	console.mesh = console_mesh
	console.position = Vector3(0.0, 1.02, 0.0)
	console.material_override = _material(color.darkened(0.4), 0.65, color)
	body.add_child(console)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.0
	shape.height = 1.25
	collision.shape = shape
	collision.position.y = 0.62
	body.add_child(collision)
	var label_height := 2.48
	var text_height := 2.66
	var label_backplate := MeshInstance3D.new()
	var backplate_mesh := BoxMesh.new()
	backplate_mesh.size = Vector3(3.6, 1.26, 0.07)
	label_backplate.mesh = backplate_mesh
	label_backplate.position = Vector3(0.0, label_height, 0.22)
	label_backplate.material_override = _label_plate_material(color)
	body.add_child(label_backplate)
	var label := Label3D.new()
	label.text = "%s\n%s\n[F] 交互" % [title, description]
	label.position = Vector3(0.0, text_height, 0.12)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.0082
	label.font_size = 38
	label.outline_size = 8
	label.outline_modulate = Color(0.01, 0.02, 0.018, 0.98)
	label.modulate = color.lightened(0.5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(label)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.15
	light.omni_range = 4.2
	light.position.y = 1.45
	body.add_child(light)
	add_child(body)
	_stations.append({"id": id, "title": title, "description": description, "position": at})


func _create_wall(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = OBSTACLE_LAYER
	body.position = at
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = _material(Color("27332f"), 0.0)
	body.add_child(mesh_node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


func _create_strip(at: Vector3, size: Vector3, color: Color) -> void:
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	line.mesh = mesh
	line.position = at
	line.material_override = _material(color, 0.28, color)
	add_child(line)


func _material(color: Color, emission_energy: float, emission_color: Color = Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.68
	material.roughness = 0.68
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = emission_energy
	return material


func _label_plate_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.01, 0.02, 0.018, 0.88)
	material.emission_enabled = true
	material.emission = color.darkened(0.72)
	material.emission_energy_multiplier = 0.55
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _update_nearest_station() -> void:
	_nearest_station = {}
	var nearest_distance := 3.8
	for station in _stations:
		var distance := player.global_position.distance_to(station["position"] as Vector3)
		if distance < nearest_distance:
			nearest_distance = distance
			_nearest_station = station
	if _nearest_station.is_empty():
		prompt.visible = false
		return
	prompt.visible = true
	prompt.text = "F  交互  ·  %s\n%s" % [_nearest_station["title"], _nearest_station["description"]]


func _interact(id: StringName) -> void:
	match id:
		&"departure":
			GameState.start_campaign()
			get_tree().change_scene_to_file("res://scenes/game.tscn")
		&"workbench":
			if GameState.upgrade_starter_weapon():
				_show_notice("初始步枪升级完成")
			else:
				_show_notice("合金不足，完成战役并回收补给箱可获得合金")
		&"health":
			if GameState.upgrade_health_system():
				_show_notice("生命维护完成，下一次开局生命值提高")
			else:
				_show_notice("合金不足，生命维护暂时无法执行")
		&"training":
			_open_training_panel()
		&"exit":
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	_refresh_interface()


func _refresh_interface() -> void:
	summary.text = "星港中枢  ·  合金 %d  ·  初始生命 %d  ·  训练技能 %d级\n下个防卫星域将在结算后随机生成" % [
		GameState.scrap,
		160 + GameState.garden_level * 18,
		GameState.home_skill_levels.size(),
	]
	facility_guide.text = "星港设施\n绿色终端  生命维护舱  ·  提升初始生命\n黄色终端  武器工作台  ·  升级\n红色终端  人物训练舱  ·  解锁局内能力\n青色终端  出发终端  ·  开始防卫任务"


func _show_notice(message: String) -> void:
	notice.text = message
	notice.visible = true
	_notice_time = 2.5


func _create_training_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_training_panel = Control.new()
	_training_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_training_panel.visible = false
	_training_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(_training_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_training_panel.add_child(dim)
	var frame := PanelContainer.new()
	frame.name = "TrainingFrame"
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -322.0
	frame.offset_top = -272.0
	frame.offset_right = 322.0
	frame.offset_bottom = 272.0
	frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = Color("10211f")
	frame_style.border_color = Color("ee6578")
	frame_style.set_border_width_all(2)
	frame_style.corner_radius_top_left = 12
	frame_style.corner_radius_top_right = 12
	frame_style.corner_radius_bottom_left = 12
	frame_style.corner_radius_bottom_right = 12
	frame_style.content_margin_left = 24.0
	frame_style.content_margin_right = 24.0
	frame_style.content_margin_top = 20.0
	frame_style.content_margin_bottom = 20.0
	frame.add_theme_stylebox_override("panel", frame_style)
	_training_panel.add_child(frame)
	var panel := VBoxContainer.new()
	panel.name = "TrainingPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_constant_override("separation", 12)
	frame.add_child(panel)
	var title := Label.new()
	title.text = "人物训练舱\n选择要在战斗中主动使用的能力"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	panel.add_child(title)
	_training_status = Label.new()
	_training_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_training_status.add_theme_font_size_override("font_size", 18)
	panel.add_child(_training_status)
	for spec in _training_specs():
		var button := Button.new()
		button.name = "Skill_%s" % spec["id"]
		button.custom_minimum_size = Vector2(0.0, 62.0)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_learn_training_skill.bind(spec["id"]))
		panel.add_child(button)
		_training_buttons[spec["id"]] = button
	var close := Button.new()
	close.text = "关闭训练舱"
	close.custom_minimum_size = Vector2(0.0, 44.0)
	close.pressed.connect(_close_training_panel)
	panel.add_child(close)


func _training_specs() -> Array[Dictionary]:
	return [
		{"id": &"fury", "name": "暴怒回路", "effect": "局内按 T 启动，短时射速大幅提升", "max": 5},
		{"id": &"recovery", "name": "治疗协议", "effect": "局内按 G 回复生命", "max": 5},
		{"id": &"bounce", "name": "反弹校准", "effect": "局内按 Y 启动，子弹额外弹射", "max": 4},
		{"id": &"tracking", "name": "追踪校准", "effect": "局内按 H 启动，子弹追踪目标", "max": 4},
	]


func _open_training_panel() -> void:
	if _training_panel == null:
		return
	_refresh_training_panel()
	_training_panel.visible = true
	get_tree().paused = true


func _close_training_panel() -> void:
	_training_panel.visible = false
	get_tree().paused = false


func _refresh_training_panel() -> void:
	if _training_panel == null:
		return
	if _training_status == null:
		return
	_training_status.text = "当前合金：%d  ·  已学习的能力可在战斗中按对应键启动" % GameState.scrap
	for spec in _training_specs():
		var level := GameState.home_skill_level(spec["id"])
		var cost := 5 + level * 4
		var button := _training_buttons.get(spec["id"]) as Button
		if button == null:
			continue
		button.text = "%s  %d/%d\n%s  ·  消耗 %d 合金" % [spec["name"], level, spec["max"], spec["effect"], cost]
		button.disabled = level >= int(spec["max"])


func _learn_training_skill(skill_id: StringName) -> void:
	var result := GameState.learn_home_skill(skill_id)
	_show_notice("%s 已学习至 %d 级" % [result["name"], result["level"]]) if bool(result.get("ok", false)) else _show_notice(str(result.get("reason", "训练失败")))
	_refresh_training_panel()
	_refresh_interface()
