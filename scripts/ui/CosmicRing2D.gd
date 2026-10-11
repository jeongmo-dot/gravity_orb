class_name CosmicRing2D
extends Control

var active: bool = false

var _elapsed: float = 0.0
var _duration: float = 0.6
var _start_radius: float = 1.0
var _end_radius: float = 1.0
var _current_radius: float = 1.0
var _ring_color: Color = Color.WHITE
var _line_width: float = 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stop()


func play(
	center: Vector2,
	color_value: Color,
	start_radius: float,
	end_radius: float,
	duration: float,
	line_width: float = 3.0
) -> void:
	_ring_color = color_value
	_start_radius = maxf(start_radius, 1.0)
	_end_radius = maxf(end_radius, _start_radius)
	_duration = maxf(duration, 0.001)
	_line_width = maxf(line_width, 1.0)
	_current_radius = _start_radius
	_elapsed = 0.0
	var diameter: float = (_end_radius + _line_width + 8.0) * 2.0
	size = Vector2.ONE * diameter
	pivot_offset = size * 0.5
	position = center - size * 0.5
	modulate = Color.WHITE
	active = true
	visible = true
	set_process(true)
	queue_redraw()


func stop() -> void:
	active = false
	visible = false
	set_process(false)
	modulate = Color.WHITE


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed = minf(_elapsed + maxf(delta, 0.0), _duration)
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	_current_radius = lerpf(_start_radius, _end_radius, progress)
	modulate.a = 1.0 - progress
	queue_redraw()
	if progress >= 1.0:
		stop()


func _draw() -> void:
	draw_arc(
		size * 0.5,
		_current_radius,
		0.0,
		TAU,
		96,
		_ring_color,
		_line_width,
		true
	)
