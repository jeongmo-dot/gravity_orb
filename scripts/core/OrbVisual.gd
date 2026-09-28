class_name OrbVisual
extends Node2D

var _display_color: Color = Color.WHITE
var _radius: float = 0.0


func setup(display_color: Color, radius: float) -> void:
	_display_color = display_color
	_radius = radius
	queue_redraw()


func _draw() -> void:
	if _radius <= 0.0:
		return
	draw_circle(Vector2.ZERO, _radius, _display_color)
