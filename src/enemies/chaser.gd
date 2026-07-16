class_name ScrapChaser
extends CharacterBody3D

signal died(enemy: ScrapChaser)
signal hit_player

@export var move_speed: float = 2.4
@export var max_health: float = 24.0
@export var contact_damage: float = 3.0
@export var attack_interval: float = 0.95
@export var attack_range: float = 1.55

var target: WastelandPlayer
var health: float
var _attack_cooldown: float = 0.0
var _dead: bool = false

@onready var hit_audio: AudioStreamPlayer3D = $HitAudio


func _ready() -> void:
	health = max_health
	hit_audio.stream = SoundSynth.tone(105.0, 0.075, 0.18)


func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target) or target.is_dead:
		velocity = Vector3.ZERO
		return
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var offset := target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > attack_range:
		velocity = offset.normalized() * move_speed
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
