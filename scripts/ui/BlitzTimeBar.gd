class_name BlitzTimeBar
extends Control

const LAYER_COLORS: Array[Color] = [
	Color("#30D158"),
	Color("#22C7D9"),
	Color("#A35CF0"),
]
const DANGER_COLOR: Color = Color("#FF3B30")
const FEVER_GLOW_COLOR: Color = Color("#FFB020")
const BONUS_FADE_SECONDS: float = 0.30
const BONUS_MIN_WIDTH: float = 6.0

var _remaining: float = 0.0
var _reference: float = 45.0
var _bonus_start: float = 0.0
var _bonus_end: float = 0.0
var _bonus_elapsed: float = BONUS_FADE_SECONDS
var _bonus_fever: bool = false
var _bonus_fading: bool = false


func set_time(remaining: float, reference: float) -> void:
	_remaining = maxf(remaining, 0.0)
	_reference = maxf(reference, 0.001)
	queue_redraw()


func show_bonus(start_time: float, end_time: float, fever: bool) -> void:
	var safe_start: float = maxf(minf(start_time, end_time), 0.0)
	var safe_end: float = maxf(maxf(start_time, end_time), safe_start)
	if bonus_is_active():
		_bonus_start = minf(_bonus_start, safe_start)
		_bonus_end = maxf(_bonus_end, safe_end)
		_bonus_fever = _bonus_fever or fever
	else:
		_bonus_start = safe_start
		_bonus_end = safe_end
		_bonus_fever = fever
	_bonus_elapsed = 0.0
	_bonus_fading = false
	queue_redraw()


func advance_bonus(delta: float) -> void:
	if not bonus_is_active():
		return
	if not _bonus_fading:
		return
	_bonus_elapsed += maxf(delta, 0.0)
	queue_redraw()


func begin_bonus_fade() -> void:
	if not bonus_is_active() or _bonus_fading:
		return
	_bonus_fading = true
	_bonus_elapsed = 0.0
	queue_redraw()


func clear_bonus() -> void:
	_bonus_start = 0.0
	_bonus_end = 0.0
	_bonus_elapsed = BONUS_FADE_SECONDS
	_bonus_fever = false
	_bonus_fading = false
	queue_redraw()


func layer_count() -> int:
	return layer_count_for_time(_remaining, _reference)


func layer_fill_ratio() -> float:
	return layer_fill_for_time(_remaining, _reference)


func layer_color() -> Color:
	if _remaining <= 10.0 and layer_count() == 1:
		return DANGER_COLOR
	return color_for_layer(layer_count() - 1)


func bonus_is_active() -> bool:
	return (
		_bonus_end > _bonus_start
		and (not _bonus_fading or _bonus_elapsed < BONUS_FADE_SECONDS)
	)


func bonus_alpha() -> float:
	if not bonus_is_active():
		return 0.0
	if not _bonus_fading:
		return 1.0
	return 1.0 - clampf(
		_bonus_elapsed / BONUS_FADE_SECONDS,
		0.0,
		1.0
	)


func bonus_is_fever() -> bool:
	return _bonus_fever


func bonus_is_fading() -> bool:
	return _bonus_fading and bonus_is_active()


func bonus_piece_rects() -> Array[Rect2]:
	return bonus_rects_for_range(
		_bonus_start,
		_bonus_end,
		_reference,
		size.x,
		size.y,
		BONUS_MIN_WIDTH
	)


static func layer_count_for_time(remaining: float, reference: float) -> int:
	var safe_reference: float = maxf(reference, 0.001)
	return maxi(ceili(maxf(remaining, 0.0) / safe_reference), 1)


static func layer_fill_for_time(remaining: float, reference: float) -> float:
	var safe_reference: float = maxf(reference, 0.001)
	var safe_remaining: float = maxf(remaining, 0.0)
	if safe_remaining <= 0.0:
		return 0.0
	var count: int = layer_count_for_time(safe_remaining, safe_reference)
	return clampf(
		(safe_remaining - float(count - 1) * safe_reference) / safe_reference,
		0.0,
		1.0
	)


static func color_for_layer(layer_index: int) -> Color:
	return LAYER_COLORS[posmod(layer_index, LAYER_COLORS.size())]


static func bonus_rects_for_range(
	start_time: float,
	end_time: float,
	reference: float,
	bar_width: float,
	bar_height: float,
	minimum_width: float = BONUS_MIN_WIDTH
) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var safe_reference: float = maxf(reference, 0.001)
	var safe_start: float = maxf(minf(start_time, end_time), 0.0)
	var safe_end: float = maxf(maxf(start_time, end_time), safe_start)
	var cursor: float = safe_start
	while cursor < safe_end - 0.0001:
		var layer_index: int = floori(cursor / safe_reference)
		var layer_start: float = float(layer_index) * safe_reference
		var layer_end: float = layer_start + safe_reference
		var piece_end: float = minf(safe_end, layer_end)
		var start_ratio: float = clampf((cursor - layer_start) / safe_reference, 0.0, 1.0)
		var end_ratio: float = clampf((piece_end - layer_start) / safe_reference, 0.0, 1.0)
		var actual_end_x: float = end_ratio * maxf(bar_width, 0.0)
		var actual_width: float = maxf((end_ratio - start_ratio) * bar_width, 0.0)
		var display_width: float = minf(
			maxf(actual_width, minimum_width),
			maxf(bar_width, 0.0)
		)
		var display_x: float = clampf(
			actual_end_x - display_width,
			0.0,
			maxf(bar_width - display_width, 0.0)
		)
		rects.append(Rect2(display_x, 0.0, display_width, maxf(bar_height, 0.0)))
		cursor = piece_end
	return rects


func _draw() -> void:
	var count: int = layer_count()
	var fill_ratio: float = layer_fill_ratio()
	for layer_index: int in range(count - 1):
		draw_rect(Rect2(Vector2.ZERO, size), color_for_layer(layer_index))
	if fill_ratio > 0.0:
		draw_rect(
			Rect2(Vector2.ZERO, Vector2(size.x * fill_ratio, size.y)),
			layer_color()
		)
	if not bonus_is_active():
		return
	var alpha: float = bonus_alpha()
	var rects: Array[Rect2] = bonus_piece_rects()
	var first_layer: int = floori(_bonus_start / _reference)
	for index: int in range(rects.size()):
		var rect: Rect2 = rects[index]
		var base_color: Color = color_for_layer(first_layer + index)
		var bright: Color = base_color.lerp(Color.WHITE, 0.62)
		var glow: Color = (
			bright.lerp(FEVER_GLOW_COLOR, 0.60) if _bonus_fever else bright
		)
		glow.a = 0.30 * alpha
		var glow_rect: Rect2 = rect.grow(2.0)
		glow_rect = glow_rect.intersection(Rect2(Vector2.ZERO, size))
		draw_rect(glow_rect, glow)
		bright = bright.lerp(FEVER_GLOW_COLOR, 0.35) if _bonus_fever else bright
		bright.a = alpha
		draw_rect(rect, bright)
