class_name ScrapChaser
extends CharacterBody3D

signal died(enemy: ScrapChaser)
signal hit_player

@export var move_speed: float = 2.4
@export var max_health: float = 24.0
@export var contact_damage: float = 8.0
@export var attack_interval: float = 0.95
@export var attack_range: float = 1.55

var target: WastelandPlayer
var health: float
var _attack_cooldown: float = 0.0
var _dead: bool = false
var _knockback_velocity: Vector3 = Vector3.ZERO

@onready var hit_audio: AudioStreamPlayer3D = $HitAudio
@onready var status_effects: StatusEffectController = $StatusEffects


func _ready() -> void:
	health = max_health
	hit_audio.stream = SoundSynth.tone(105.0, 0.075, 0.18)


func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target) or target.is_dead:
		velocity = Vector3.ZERO
		return
	if _knockback_velocity.length_squared() > 0.05:
		velocity = _knockback_velocity
		move_and_slide()
		_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 24.0 * delta)
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > attack_range:
		velocity = offset.normalized() * move_speed * status_effects.movement_multiplier()
		look_at(global_position + offset.normalized(), Vector3.UP)
		move_and_slide()
	elif _attack_cooldown <= 0.0:
		_attack_cooldown = attack_interval
		target.take_damage(contact_damage)
		hit_player.emit()


func take_damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	health -= amount
	hit_audio.play()
	$Core.scale = Vector3.ONE * 1.7
	create_tween().tween_property($Core, "scale", Vector3.ONE, 0.1)
	if health <= 0.0:
		_dead = true
		collision_layer = 0
		collision_mask = 0
		died.emit(self)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(self, "scale", Vector3(1.5, 0.05, 1.5), 0.18)
		tween.tween_property(self, "rotation:y", rotation.y + PI, 0.18)
		tween.chain().tween_callback(queue_free)


func apply_status_effect(effect: StatusEffectData, source_direction: Vector3 = Vector3.ZERO) -> bool:
	return status_effects.apply_effect(effect, source_direction)


func apply_knockback(force: Vector3) -> void:
	_knockback_velocity += Vector3(force.x, 0.0, force.z)
