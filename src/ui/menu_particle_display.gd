class_name MenuParticleDisplay
extends Control

const PARTICLE_COUNT := 72

var _particles: Array[Dictionary] = []
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1
	_rng.seed = 73421
	for _index in PARTICLE_COUNT:
		_particles.append({
			"position": Vector2(_rng.randf(), _rng.randf()),
			"speed": _rng.randf_range(0.025, 0.105),
			"phase": _rng.randf_range(0.0, TAU),
			"size": _rng.randf_range(1.2, 3.4),
			"alpha": _rng.randf_range(0.20, 0.80),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var center := Vector2(size.x * 0.79, size.y * 0.45)
	var pulse := 0.55 + sin(_elapsed * 1.15) * 0.18
	for radius_factor in [0.10, 0.17, 0.26]:
		var radius: float = minf(size.x, size.y) * radius_factor
		draw_arc(center, radius, _elapsed * (0.25 + radius_factor), _elapsed * (0.25 + radius_factor) + TAU * 0.72, 54, Color(0.18, 0.78, 1.0, 0.12 + pulse * 0.11), 1.25)
	for particle in _particles:
		var position_fraction: Vector2 = particle["position"]
		var phase: float = particle["phase"]
		var x := fposmod(position_fraction.x + _elapsed * particle["speed"] * 0.13, 1.08) - 0.04
		var y := fposmod(position_fraction.y + sin(_elapsed * 0.55 + phase) * 0.012, 1.05)
		var point := Vector2(x * size.x, y * size.y)
		var alpha: float = particle["alpha"] * (0.62 + sin(_elapsed * 1.8 + phase) * 0.28)
		var color := Color(0.38, 0.88, 1.0, clampf(alpha, 0.08, 0.82))
		draw_circle(point, particle["size"], color)
		if point.distance_to(center) < minf(size.x, size.y) * 0.31:
			draw_line(point, center, Color(0.28, 0.78, 1.0, alpha * 0.16), 0.75)
	draw_circle(center, 7.0 + pulse * 6.0, Color(0.36, 0.94, 1.0, 0.62))
	draw_circle(center, 2.5, Color(0.91, 0.99, 1.0, 0.95))
