class_name TurnInputIndicator
extends Control

const READY_COLOR: Color = Color("#BFE9FF")
const BLOCKED_COLOR: Color = Color("#FF3B30")
const REJECTED_COLOR: Color = Color("#8EA3C8")
const READY_FADE_DURATION: float = 0.20
const BUSY_FADE_DURATION: float = 0.10
const REJECTED_FLASH_DURATION: float = 0.30
const ORBIT_DURATION: float = 1.0
const BUSY_BORDER_ALPHA: float = 0.40
const BORDER_WIDTH: float = 5.0
const ARROW_OFFSET: float = 30.0
const ARROW_LENGTH: float = 24.0
const ARROW_HALF_WIDTH: float = 10.0
const ORBIT_RADIUS: float = 6.0

var _manager: TurnManager
var _board: Board3D
var _ready_state: bool = false
var _cues_visible: bool = false
var _arrow_alpha: float = 0.0
var _orbit_elapsed: float = 0.0
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
	if not _ready_state:
		_orbit_elapsed = fmod(_orbit_elapsed + real_delta, ORBIT_DURATION)
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
	var border_alpha: float = 1.0 if _ready_state else BUSY_BORDER_ALPHA
	var border_color: Color = READY_COLOR
	border_color.a = border_alpha
	draw_rect(board_rect, border_color, false, BORDER_WIDTH, true)
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		var alpha: float = _arrow_alpha
		var color: Color = arrow_color(direction)
		if direction == _rejected_direction and _rejected_remaining > 0.0:
			alpha = _rejected_remaining / REJECTED_FLASH_DURATION
			color = REJECTED_COLOR
		if alpha <= 0.001:
			continue
		color.a *= alpha
		_draw_arrow(board_rect, direction, color)
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
	_ready_state = next_state == int(TurnManager.State.WAITING_INPUT)
	if not _ready_state:
		_orbit_elapsed = 0.0
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


func orbit_visible() -> bool:
	return _cues_visible and not _ready_state


func border_alpha() -> float:
	return 1.0 if _ready_state else BUSY_BORDER_ALPHA


func rejection_flash_count() -> int:
	return _rejection_flash_count


func rejected_direction() -> Vector2i:
	return _rejected_direction


func orbit_progress() -> float:
	return _orbit_elapsed / ORBIT_DURATION


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


func _draw_arrow(board_rect: Rect2, direction: Vector2i, color: Color) -> void:
	var direction_vector: Vector2 = Vector2(direction)
	var center: Vector2 = board_rect.get_center()
	if direction.x < 0:
		center.x = board_rect.position.x - ARROW_OFFSET
	elif direction.x > 0:
		center.x = board_rect.end.x + ARROW_OFFSET
	elif direction.y < 0:
		center.y = board_rect.position.y - ARROW_OFFSET
	else:
		center.y = board_rect.end.y + ARROW_OFFSET
	var perpendicular: Vector2 = Vector2(-direction_vector.y, direction_vector.x)
	var tip: Vector2 = center + direction_vector * ARROW_LENGTH * 0.55
	var rear: Vector2 = center - direction_vector * ARROW_LENGTH * 0.45
	var head_base: Vector2 = center + direction_vector * ARROW_LENGTH * 0.05
	draw_line(rear, head_base, color, 5.0, true)
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			head_base + perpendicular * ARROW_HALF_WIDTH,
			head_base - perpendicular * ARROW_HALF_WIDTH,
		]),
		color
	)


func _draw_orbit_light(board_rect: Rect2) -> void:
	var orbit_rect: Rect2 = board_rect.grow(BORDER_WIDTH * 0.5)
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
