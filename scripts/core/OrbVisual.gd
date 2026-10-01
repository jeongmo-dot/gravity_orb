class_name OrbVisual
extends Node2D

var _display_color: Color = Color.WHITE
var _radius: float = 0.0
var _waiting_at_entrance: bool = false
var _waiting_blink_elapsed: float = 0.0


func setup(display_color: Color, radius: float) -> void:
	_display_color = display_color
	set_process(false)
	set_radius(radius)


func set_radius(radius: float) -> void:
	_radius = radius
	queue_redraw()


func get_radius() -> float:
	return _radius


func set_alpha(alpha: float) -> void:
	_display_color.a = clampf(alpha, 0.0, 1.0)
	queue_redraw()


func get_alpha() -> float:
	return _display_color.a


func set_waiting_at_entrance(waiting: bool) -> void:
	_waiting_at_entrance = waiting
	_waiting_blink_elapsed = 0.0
	set_process(waiting)
	queue_redraw()


func _process(delta: float) -> void:
	_waiting_blink_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if _radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, _radius, _display_color)
	if _waiting_at_entrance:
		var blink_alpha: float = 0.35 + 0.65 * absf(sin(_waiting_blink_elapsed * 8.0))
		draw_arc(
			Vector2.ZERO,
			_radius + 3.0,
			0.0,
			TAU,
			48,
			Color(1.0, 1.0, 1.0, blink_alpha),
			4.0,
			true
		)
