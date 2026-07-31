class_name WeaponPickup
extends Node3D

var weapon: WeaponData


func configure(value: WeaponData) -> void:
	weapon = value


func _ready() -> void:
	add_to_group("weapon_pickups")
	var pedestal := MeshInstance3D.new()
	var pedestal_mesh := CylinderMesh.new()
	pedestal_mesh.top_radius = 0.34
	pedestal_mesh.bottom_radius = 0.5
	pedestal_mesh.height = 0.16
	pedestal.mesh = pedestal_mesh
	pedestal.position.y = 0.08
	var pedestal_material := StandardMaterial3D.new()
	pedestal_material.albedo_color = Color(0.05, 0.12, 0.13, 1.0)
	pedestal_material.emission_enabled = true
	pedestal_material.emission = Color(0.04, 0.24, 0.23)
	pedestal.material_override = pedestal_material
	add_child(pedestal)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.9, 0.18, 0.32)
	body.mesh = body_mesh
	body.position.y = 0.68
	var body_material := StandardMaterial3D.new()
	var color := weapon.vfx.projectile_color if weapon != null and weapon.vfx != null else Color(0.3, 0.9, 0.75)
	body_material.albedo_color = color
	body_material.emission_enabled = true
	body_material.emission = color * 0.65
	body.material_override = body_material
	add_child(body)

	var label := Label3D.new()
	label.name = "Prompt"
	label.text = "武器寄存器\nF  更换  ·  %s" % (weapon.display_name if weapon != null else "未知武器")
	label.position = Vector3(0.0, 1.25, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 42
	label.outline_size = 5
	label.modulate = Color(0.8, 1.0, 0.94, 0.92)
	add_child(label)
	_create_float_motion()


func interaction_text(is_full: bool) -> String:
	if weapon == null:
		return ""
	if is_full:
		return "F  打开武器寄存器  ·  替换为 %s" % weapon.display_name
	return "F  获取 %s" % weapon.display_name


func interact(player: WastelandPlayer) -> void:
	if player != null and player.try_pickup_weapon(weapon):
		queue_free()


func _create_float_motion() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", position.y + 0.14, 0.7).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", position.y, 0.7).set_trans(Tween.TRANS_SINE)
