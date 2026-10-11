class_name CosmicSparkle
extends Control

const MAX_VISIBLE_SPARKLES: int = 20
const DRAW_SIZE: float = 40.0

var active: bool = false

var _elapsed: float = 0.0
var _duration: float = 0.8
var _center: Vector2 = Vector2.ZERO
var _start_offset: Vector2 = Vector2.ZERO
var _end_offset: Vector2 = Vector2.ZERO
var _turns: float = 0.0
var _sparkle_color: Color = Color.WHITE
var _sparkle_size: float = 14.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ONE * DRAW_SIZE
	pivot_offset = size * 0.5
	add_to_group(&"v4_ui_sparkle")
	stop()
	queue_redraw()


func play(
	center: Vector2,
	color_value: Color,
	duration: float,
	start_offset: Vector2,
	end_offset: Vector2,
	turns: float = 0.0,
	sparkle_size: float = 14.0
) -> bool:
	if not visible and visible_count(get_tree()) >= MAX_VISIBLE_SPARKLES:
		return false
	_center = center
	_sparkle_color = color_value
	_duration = maxf(duration, 0.001)
	_start_offset = start_offset
	_end_offset = end_offset
	_turns = turns
	_sparkle_size = sparkle_size
	_elapsed = 0.0
	active = true
	visible = true
	modulate = Color.WHITE
	position = _center + _start_offset - size * 0.5
	rotation = _start_offset.angle()
	scale = Vector2.ONE * 0.35
	set_process(true)
	queue_redraw()
	return true


func stop() -> void:
	active = false
	visible = false
	set_process(false)
	modulate = Color.WHITE
	scale = Vector2.ONE


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed = minf(_elapsed + maxf(delta, 0.0), _duration)
	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var start_radius: float = _start_offset.length()
	var end_radius: float = _end_offset.length()
	var offset: Vector2
	if absf(_turns) > 0.001 and start_radius > 0.001:
		var angle: float = _start_offset.angle() + TAU * _turns * progress
		offset = Vector2.RIGHT.rotated(angle) * lerpf(start_radius, end_radius, progress)
	else:
		offset = _start_offset.lerp(_end_offset, progress)
	position = _center + offset - size * 0.5
	rotation = progress * TAU * (1.0 + absf(_turns))
	var pulse: float = 0.55 + 0.45 * sin(progress * PI * 3.0)
	scale = Vector2.ONE * pulse
	modulate.a = sin(progress * PI)
	if progress >= 1.0:
		stop()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var glow_color: Color = _sparkle_color
	glow_color.a = 0.20
	draw_colored_polygon(_star_points(center, _sparkle_size * 1.45, 3.0), glow_color)
	draw_colored_polygon(_star_points(center, _sparkle_size, 2.0), _sparkle_color)


func _star_points(center: Vector2, outer_radius: float, inner_radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in range(8):
		var radius: float = outer_radius if index % 2 == 0 else inner_radius
		points.append(center + Vector2.UP.rotated(float(index) * PI / 4.0) * radius)
	return points


static func visible_count(scene_tree: SceneTree) -> int:
	var count: int = 0
	for node: Node in scene_tree.get_nodes_in_group(&"v4_ui_sparkle"):
		if node is CanvasItem and (node as CanvasItem).visible:
			count += 1
	return count
