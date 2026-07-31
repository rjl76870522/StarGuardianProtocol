class_name SalvageCache
extends Area3D

signal collected(scrap_amount: int, heal_amount: float)

var scrap_amount: int = 2
var heal_amount: float = 14.0
var armor_charge: float = 0.0
var _collected := false
var _visual: MeshInstance3D


func _ready() -> void:
	add_to_group("salvage_caches")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)

	_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.72, 0.48, 0.58)
	_visual.mesh = mesh
	_visual.position.y = 0.34
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b58b35")
	material.metallic = 0.78
	material.roughness = 0.38
	material.emission_enabled = true
	material.emission = Color("ffcb58")
	material.emission_energy_multiplier = 0.7
	_visual.material_override = material
	add_child(_visual)

	var beacon := OmniLight3D.new()
	beacon.light_color = Color("ffbf43")
	beacon.light_energy = 1.0
	beacon.omni_range = 3.0
	beacon.position.y = 0.65
	add_child(beacon)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 1.0, 1.0)
	collision.shape = shape
	collision.position.y = 0.42
	add_child(collision)
	_bob()


func _bob() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(_visual, "position:y", 0.46, 0.75).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_visual, "position:y", 0.26, 0.75).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node3D) -> void:
	if _collected or not body is WastelandPlayer:
		return
	collect(body as WastelandPlayer)


func collect(player: WastelandPlayer, restore_health: bool = true) -> bool:
	if _collected or player == null:
		return false
	_collected = true
	if restore_health:
		player.restore_health(heal_amount)
	if restore_health and armor_charge > 0.0:
		player.apply_zone_support(armor_charge, 0.0)
		player.action_message.emit("获得护甲芯片，最大生命 +%d" % int(armor_charge))
	collected.emit(scrap_amount, heal_amount if restore_health else 0.0)
	queue_free()
	return true
