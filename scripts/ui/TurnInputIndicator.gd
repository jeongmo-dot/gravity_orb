class_name TurnInputIndicator
extends Control

const READY_COLOR: Color = Color("#BFE9FF")
const BLOCKED_COLOR: Color = Color("#FF3B30")
const REJECTED_COLOR: Color = Color("#8EA3C8")
const READY_FADE_DURATION: float = 0.20
const BUSY_FADE_DURATION: float = 0.10
const REJECTED_FLASH_DURATION: float = 0.30
const BREATH_DURATION: float = 1.60
const BREATH_ALPHA_MIN: float = 0.85
const BREATH_ALPHA_MAX: float = 1.0
const BUSY_BORDER_ALPHA: float = 0.40
const BORDER_WIDTH: float = 5.0
const ARROW_SIZE: float = 56.0
const ARROW_HALF_SPAN: float = 24.0
const ARROW_DEPTH: float = 18.0
const ARROW_STROKE_WIDTH: float = 8.0
const ARROW_HORIZONTAL_OFFSET: float = 13.0
const ARROW_VERTICAL_OFFSET: float = 34.0
const BLOCKED_MARK_SIZE: float = 12.0
const BLOCKED_MARK_SIDE_OFFSET: float = 34.0
const BLOCKED_MARK_VERTICAL_OFFSET: float = 24.0
const ORBIT_DIAMETER: float = 20.0
const ORBIT_RADIUS: float = ORBIT_DIAMETER * 0.5
const ORBIT_OUTSIDE_GAP: float = 4.0
const ORBIT_TRAIL_SIDE_FRACTION: float = 0.15
const ORBIT_TRAIL_SAMPLES: int = 18

var _manager: TurnManager
var _board: Board3D
var _ready_state: bool = false
var _cues_visible: bool = false
var _arrow_alpha: float = 0.0
var _breath_elapsed: float = 0.0
var _orbit_progress: float = 0.0
var _rejected_remaining: float = 0.0
var _rejected_direction: Vector2i = Vector2i.ZERO
var _rejection_flash_count: int = 0
var _blocked_directions: Array[Vector2i] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	visible = false


func bind(manager: Variant, board: Variant) -> void:
	_manager = manager as TurnManager
	_board = board as Board3D
	if _manager == null or _board == null:
		visible = false
		set_process(false)
		return
	visible = true
	set_process(true)
	if not _manager.state_changed.is_connected(_on_state_changed):
		_manager.state_changed.connect(_on_state_changed)
	if not _manager.warning_changed.is_connected(_on_warning_changed):
		_manager.warning_changed.connect(_on_warning_changed)
	if not _manager.game_over.is_connected(_on_game_over):
		_manager.game_over.connect(_on_game_over)
	if not InputRouter.swipe_rejected.is_connected(_on_swipe_rejected):
		InputRouter.swipe_rejected.connect(_on_swipe_rejected)
	_on_warning_changed(_manager.blocked_directions)
	_on_state_changed(int(_manager.state))


func _exit_tree() -> void:
	if InputRouter.swipe_rejected.is_connected(_on_swipe_rejected):
		InputRouter.swipe_rejected.disconnect(_on_swipe_rejected)


func _process(delta: float) -> void:
	if not _cues_visible:
		return
	var real_delta: float = maxf(delta, 0.0) / maxf(Engine.time_scale, 0.001)
	var target_alpha: float = 1.0 if _ready_state else 0.0
	var fade_duration: float = READY_FADE_DURATION if _ready_state else BUSY_FADE_DURATION
	_arrow_alpha = move_toward(_arrow_alpha, target_alpha, real_delta / fade_duration)
	if _ready_state:
		_breath_elapsed = fmod(_breath_elapsed + real_delta, BREATH_DURATION)
	elif _manager != null:
		_orbit_progress = _classic_busy_progress()
	if _rejected_remaining > 0.0:
		_rejected_remaining = maxf(_rejected_remaining - real_delta, 0.0)
		if is_zero_approx(_rejected_remaining):
			_rejected_direction = Vector2i.ZERO
	queue_redraw()


func _draw() -> void:
	if not _cues_visible or _board == null:
		return
	var board_rect: Rect2 = _projected_board_rect()
	if board_rect.size.x <= 0.0 or board_rect.size.y <= 0.0:
		return
	var border_color: Color = current_border_color()
	draw_rect(board_rect, border_color, false, BORDER_WIDTH, true)
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		var alpha: float = _arrow_alpha
		var scale_value: float = arrow_scale()
		var color: Color = arrow_color(direction)
		if direction == _rejected_direction and _rejected_remaining > 0.0:
			alpha = _rejected_remaining / REJECTED_FLASH_DURATION
			scale_value = 1.0
			color = REJECTED_COLOR
		elif _ready_state:
			alpha *= breathing_alpha()
		if alpha <= 0.001:
			continue
		color.a *= alpha
		_draw_arrow(board_rect, direction, color, scale_value)
		if direction in _blocked_directions and _ready_state:
			_draw_blocked_mark(board_rect, direction, color, scale_value)
	if not _ready_state:
		_draw_orbit_light(board_rect)


func _on_state_changed(next_state: int) -> void:
	if next_state == int(TurnManager.State.GAME_OVER):
		_cues_visible = false
		_ready_state = false
		_arrow_alpha = 0.0
		_rejected_remaining = 0.0
		_rejected_direction = Vector2i.ZERO
		queue_redraw()
		return
	_cues_visible = true
	var was_ready: bool = _ready_state
	_ready_state = next_state == int(TurnManager.State.WAITING_INPUT)
	if _ready_state and not was_ready:
		_breath_elapsed = 0.0
	if not _ready_state:
		_orbit_progress = 0.0
	queue_redraw()


func _on_game_over() -> void:
	_on_state_changed(int(TurnManager.State.GAME_OVER))


func _on_warning_changed(directions: Array[Vector2i]) -> void:
	_blocked_directions.clear()
	_blocked_directions.append_array(directions)
	queue_redraw()


func _on_swipe_rejected(direction: Vector2i) -> void:
	if not _cues_visible or _ready_state or direction == Vector2i.ZERO:
		return
	_rejected_direction = direction
	_rejected_remaining = REJECTED_FLASH_DURATION
	_rejection_flash_count += 1
	queue_redraw()


func arrow_color(direction: Vector2i) -> Color:
	return BLOCKED_COLOR if direction in _blocked_directions else READY_COLOR


func is_ready_cue() -> bool:
	return _cues_visible and _ready_state


func is_busy_cue() -> bool:
	return _cues_visible and not _ready_state


func arrow_alpha() -> float:
	return _arrow_alpha


func arrow_scale() -> float:
	return lerpf(0.8, 1.0, _arrow_alpha)


func breathing_alpha() -> float:
	var wave: float = 0.5 - 0.5 * cos(_breath_elapsed * TAU / BREATH_DURATION)
	return lerpf(BREATH_ALPHA_MIN, BREATH_ALPHA_MAX, wave)


func arrow_size() -> float:
	return ARROW_SIZE


func orbit_light_diameter() -> float:
	return ORBIT_DIAMETER


func orbit_trail_length(board_rect: Rect2) -> float:
	return minf(board_rect.size.x, board_rect.size.y) * ORBIT_TRAIL_SIDE_FRACTION


func orbit_visible() -> bool:
	return _cues_visible and not _ready_state


func border_alpha() -> float:
	return current_border_color().a


func current_border_color() -> Color:
	var color: Color = READY_COLOR
	if _ready_state:
		color.a = 1.0
	else:
		color.a = BUSY_BORDER_ALPHA
	return color


func direction_arrows_visible() -> bool:
	return _cues_visible and (
		_arrow_alpha > 0.001 or _rejected_remaining > 0.0
	)


func uses_direction_arrows() -> bool:
	return true


func rejection_flash_count() -> int:
	return _rejection_flash_count


func rejected_direction() -> Vector2i:
	return _rejected_direction


func orbit_progress() -> float:
	return _orbit_progress


func _classic_busy_progress() -> float:
	if _manager == null or _manager.state == TurnManager.State.SPAWNING:
		return 0.0
	return clampf(
		_manager.settle_elapsed / maxf(Config.data.max_settle_time, 0.001),
		0.0,
		1.0
	)


func _projected_board_rect() -> Rect2:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Rect2()
	var outer_half_m: float = _board.half_size() / Board3D.PIXELS_PER_METER
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	for corner: Vector2 in [
		Vector2(-outer_half_m, -outer_half_m),
		Vector2(outer_half_m, -outer_half_m),
		Vector2(outer_half_m, outer_half_m),
		Vector2(-outer_half_m, outer_half_m),
	]:
		var projected: Vector2 = camera.unproject_position(
			_board.to_global(Vector3(corner.x, corner.y, 0.0))
		)
		minimum = minimum.min(projected)
		maximum = maximum.max(projected)
	return Rect2(minimum, maximum - minimum)


func arrow_bounds(board_rect: Rect2, direction: Vector2i, scale_value: float = 1.0) -> Rect2:
	var center: Vector2 = _arrow_center(board_rect, direction)
	var direction_vector: Vector2 = Vector2(direction)
	var perpendicular: Vector2 = Vector2(-direction_vector.y, direction_vector.x)
	var half_depth: float = ARROW_DEPTH * 0.5 * scale_value
	var half_span: float = ARROW_HALF_SPAN * scale_value
	var points: PackedVector2Array = PackedVector2Array([
		center - direction_vector * half_depth + perpendicular * half_span,
		center + direction_vector * half_depth,
		center - direction_vector * half_depth - perpendicular * half_span,
	])
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return Rect2(minimum, maximum - minimum).grow(ARROW_STROKE_WIDTH * 0.5)


func orbit_path_rect(board_rect: Rect2) -> Rect2:
	return board_rect.grow(ORBIT_RADIUS + ORBIT_OUTSIDE_GAP)


func blocked_mark_bounds(board_rect: Rect2, direction: Vector2i) -> Rect2:
	var center: Vector2 = _blocked_mark_center(board_rect, direction)
	var half_extent: float = BLOCKED_MARK_SIZE * 0.5 + 1.5
	return Rect2(center - Vector2.ONE * half_extent, Vector2.ONE * half_extent * 2.0)


func _draw_arrow(
	board_rect: Rect2,
	direction: Vector2i,
	color: Color,
	scale_value: float
) -> void:
	var direction_vector: Vector2 = Vector2(direction)
	var center: Vector2 = _arrow_center(board_rect, direction)
	var perpendicular: Vector2 = Vector2(-direction_vector.y, direction_vector.x)
	var half_depth: float = ARROW_DEPTH * 0.5 * scale_value
	var half_span: float = ARROW_HALF_SPAN * scale_value
	draw_polyline(
		PackedVector2Array([
			center - direction_vector * half_depth + perpendicular * half_span,
			center + direction_vector * half_depth,
			center - direction_vector * half_depth - perpendicular * half_span,
		]),
		color,
		ARROW_STROKE_WIDTH * scale_value,
		true
	)


func _draw_blocked_mark(
	board_rect: Rect2,
	direction: Vector2i,
	color: Color,
	scale_value: float
) -> void:
	var center: Vector2 = _blocked_mark_center(board_rect, direction)
	var half_size: float = BLOCKED_MARK_SIZE * 0.5 * scale_value
	var stroke_width: float = 3.0 * scale_value
	draw_line(
		center - Vector2(half_size, half_size),
		center + Vector2(half_size, half_size),
		color,
		stroke_width,
		true
	)
	draw_line(
		center + Vector2(-half_size, half_size),
		center + Vector2(half_size, -half_size),
		color,
		stroke_width,
		true
	)


func _arrow_center(board_rect: Rect2, direction: Vector2i) -> Vector2:
	var center: Vector2 = board_rect.get_center()
	if direction.x < 0:
		center.x = board_rect.position.x - ARROW_HORIZONTAL_OFFSET
	elif direction.x > 0:
		center.x = board_rect.end.x + ARROW_HORIZONTAL_OFFSET
	elif direction.y < 0:
		center.y = board_rect.position.y - ARROW_VERTICAL_OFFSET
	else:
		center.y = board_rect.end.y + ARROW_VERTICAL_OFFSET
	return center


func _blocked_mark_center(board_rect: Rect2, direction: Vector2i) -> Vector2:
	var offset: float = (
		BLOCKED_MARK_SIDE_OFFSET
		if direction.x != 0
		else BLOCKED_MARK_VERTICAL_OFFSET
	)
	return _arrow_center(board_rect, direction) + Vector2.UP * offset


func _draw_orbit_light(board_rect: Rect2) -> void:
	var orbit_rect: Rect2 = orbit_path_rect(board_rect)
	var perimeter: float = 2.0 * (orbit_rect.size.x + orbit_rect.size.y)
	var trail_progress: float = orbit_trail_length(board_rect) / perimeter
	for sample_index: int in range(ORBIT_TRAIL_SAMPLES, 0, -1):
		var trail_ratio: float = float(sample_index) / float(ORBIT_TRAIL_SAMPLES)
		var sample_progress: float = orbit_progress() - trail_progress * trail_ratio
		var trail_position: Vector2 = _point_on_rect_perimeter(orbit_rect, sample_progress)
		var trail_color: Color = READY_COLOR
		trail_color.a = lerpf(0.03, 0.38, pow(1.0 - trail_ratio, 1.6))
		draw_circle(trail_position, lerpf(2.0, 5.5, 1.0 - trail_ratio), trail_color)
	var position_on_border: Vector2 = _point_on_rect_perimeter(
		orbit_rect,
		orbit_progress()
	)
	var glow_color: Color = READY_COLOR
	glow_color.a = 0.16
	draw_circle(position_on_border, ORBIT_RADIUS * 2.2, glow_color)
	glow_color.a = 0.36
	draw_circle(position_on_border, ORBIT_RADIUS * 1.45, glow_color)
	glow_color.a = 0.95
	draw_circle(position_on_border, ORBIT_RADIUS, glow_color)


func _point_on_rect_perimeter(rect: Rect2, progress: float) -> Vector2:
	var horizontal: float = rect.size.x
	var vertical: float = rect.size.y
	var perimeter: float = 2.0 * (horizontal + vertical)
	var distance: float = fposmod(progress, 1.0) * perimeter
	if distance <= horizontal:
		return rect.position + Vector2(distance, 0.0)
	distance -= horizontal
	if distance <= vertical:
		return Vector2(rect.end.x, rect.position.y + distance)
	distance -= vertical
	if distance <= horizontal:
		return Vector2(rect.end.x - distance, rect.end.y)
	distance -= horizontal
	return Vector2(rect.position.x, rect.end.y - distance)
