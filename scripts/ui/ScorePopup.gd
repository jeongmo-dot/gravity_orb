class_name ScorePopup
extends Control

signal finished(popup: ScorePopup)

const BASE_FONT_SIZE: float = 34.0
const TEXT_SCALE: float = 0.70
const FORMULA_FONT_SIZE: int = 15
const POP_DURATION: float = 0.7
const LARGE_SCORE_EXTRA_DURATION: float = 0.2
const FADE_DURATION: float = 0.25
const RISE_DISTANCE: float = 60.0
const POP_IN_DURATION: float = 0.12
const POP_IN_PEAK_TIME: float = 0.07
const POPUP_SIZE: Vector2 = Vector2(308.0, 126.0)
const GOLD_COLOR: Color = Color("#FFD54A")
const FORMULA_COLOR: Color = Color("#AFC5D8")
const COSMIC_GLOW_ALPHA: float = 0.28
const HUD_THEME: Theme = preload("res://assets/ui/gravity_orb_theme.tres")

var started_process_frame: int = -1
var anchor_position: Vector2 = Vector2.ZERO
var source_position: Vector2 = Vector2.ZERO
var points: int = 0
var active: bool = false

var _score_label: Label
var _formula_label: Label
var _sparkles: Array[CosmicSparkle] = []
var _elapsed: float = 0.0
var _duration: float = POP_DURATION
var _cosmic_score: bool = false


func _ready() -> void:
	theme = HUD_THEME
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	pivot_offset = POPUP_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_score_label = Label.new()
	_score_label.name = "Score"
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_bottom = 70.0
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_label.theme_type_variation = &"HudDisplayBold"
	add_child(_score_label)
	_formula_label = Label.new()
	_formula_label.name = "Formula"
	_formula_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_formula_label.offset_top = 78.4
	_formula_label.offset_bottom = 113.4
	_formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formula_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_formula_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_formula_label.theme_type_variation = &"HudDisplayMedium"
	_formula_label.add_theme_font_size_override("font_size", FORMULA_FONT_SIZE)
	_formula_label.add_theme_color_override("font_color", FORMULA_COLOR)
	add_child(_formula_label)
	for index: int in range(2):
		var sparkle: CosmicSparkle = CosmicSparkle.new()
		sparkle.name = "ScoreSparkle%d" % index
		sparkle.z_index = 2
		add_child(sparkle)
		_sparkles.append(sparkle)
	deactivate(false)


func activate(
	screen_position: Vector2,
	p_points: int,
	formula: String,
	font_color: Color,
	outline_color: Color,
	outline_size: int,
	process_frame: int,
	cosmic_score: bool = false
) -> void:
	anchor_position = screen_position
	points = p_points
	started_process_frame = process_frame
	_elapsed = 0.0
	_duration = POP_DURATION + (LARGE_SCORE_EXTRA_DURATION if points >= 1000 else 0.0)
	_cosmic_score = cosmic_score
	active = true
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE * 0.6
	position = anchor_position - POPUP_SIZE * 0.5
	_score_label.text = "+%s" % format_number(points)
	_score_label.add_theme_font_size_override("font_size", popup_font_size(points))
	_score_label.add_theme_color_override("font_color", font_color)
	_score_label.add_theme_color_override("font_outline_color", outline_color)
	_score_label.add_theme_constant_override("outline_size", outline_size)
	_configure_cosmic_style()
	_formula_label.text = formula
	_formula_label.visible = not formula.is_empty()
	set_process(true)


func merge_score(additional_points: int) -> void:
	points += additional_points
	_duration = POP_DURATION + (LARGE_SCORE_EXTRA_DURATION if points >= 1000 else 0.0)
	_score_label.text = "+%s" % format_number(points)
	_score_label.add_theme_font_size_override("font_size", popup_font_size(points))
	_formula_label.text = ""
	_formula_label.visible = false


func deactivate(emit_finished: bool = true) -> void:
	var was_active: bool = active
	active = false
	visible = false
	set_process(false)
	for sparkle: CosmicSparkle in _sparkles:
		sparkle.stop()
	if emit_finished and was_active:
		finished.emit(self)


func score_text() -> String:
	return _score_label.text


func formula_text() -> String:
	return _formula_label.text if _formula_label.visible else ""


func content_local_rect_for(p_points: int, formula: String) -> Rect2:
	var score_font: Font = _score_label.get_theme_font("font")
	var score_font_size: int = popup_font_size(p_points)
	var score_size: Vector2 = score_font.get_string_size(
		"+%s" % format_number(p_points),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		score_font_size
	)
	var outline_margin: float = 6.0
	var score_rect: Rect2 = Rect2(
		Vector2(
			(POPUP_SIZE.x - score_size.x) * 0.5 - outline_margin,
			(70.0 - score_size.y) * 0.5 - outline_margin
		),
		score_size + Vector2.ONE * outline_margin * 2.0
	)
	if formula.is_empty():
		return score_rect
	var formula_font: Font = _formula_label.get_theme_font("font")
	var formula_size: Vector2 = formula_font.get_string_size(
		formula,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		FORMULA_FONT_SIZE
	)
	var formula_rect: Rect2 = Rect2(
		Vector2(
			(POPUP_SIZE.x - formula_size.x) * 0.5 - outline_margin,
			78.4 + (35.0 - formula_size.y) * 0.5 - outline_margin
		),
		formula_size + Vector2.ONE * outline_margin * 2.0
	)
	return score_rect.merge(formula_rect)


func motion_offset_rect_for(p_points: int, formula: String) -> Rect2:
	var local_rect: Rect2 = content_local_rect_for(p_points, formula)
	var relative_position: Vector2 = (local_rect.position - pivot_offset) * 1.1
	var relative_end: Vector2 = (local_rect.end - pivot_offset) * 1.1
	var start_rect: Rect2 = Rect2(relative_position, relative_end - relative_position)
	return start_rect.merge(Rect2(
		start_rect.position + Vector2.UP * RISE_DISTANCE,
		start_rect.size
	))


func visual_global_rect() -> Rect2:
	var local_rect: Rect2 = content_local_rect_for(points, formula_text())
	var transform: Transform2D = get_global_transform()
	var corners: Array[Vector2] = [
		transform * local_rect.position,
		transform * Vector2(local_rect.end.x, local_rect.position.y),
		transform * local_rect.end,
		transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner: Vector2 in corners:
		minimum = minimum.min(corner)
		maximum = maximum.max(corner)
	return Rect2(minimum, maximum - minimum)


func score_color() -> Color:
	return _score_label.get_theme_color("font_color")


func is_cosmic_score() -> bool:
	return _cosmic_score


func active_sparkle_count() -> int:
	var count: int = 0
	for sparkle: CosmicSparkle in _sparkles:
		if sparkle.active:
			count += 1
	return count


func glow_alpha() -> float:
	return _score_label.get_theme_color("font_shadow_color").a


static func format_number(value: int) -> String:
	var negative: bool = value < 0
	var digits: String = str(absi(value))
	var formatted: String = ""
	for index: int in range(digits.length()):
		if index > 0 and (digits.length() - index) % 3 == 0:
			formatted += ","
		formatted += digits[index]
	return ("-" if negative else "") + formatted


static func popup_font_size(score: int) -> int:
	var ratio: float = maxf(float(score) / 10.0, 0.0001)
	var factor: float = clampf(1.0 + 0.25 * log(ratio) / log(10.0), 1.0, 2.4)
	return roundi(BASE_FONT_SIZE * TEXT_SCALE * factor)


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	var progress: float = clampf(_elapsed / POP_DURATION, 0.0, 1.0)
	position = anchor_position - POPUP_SIZE * 0.5 + Vector2(0.0, -RISE_DISTANCE * progress)
	if _elapsed < POP_IN_PEAK_TIME:
		var first_phase: float = _elapsed / POP_IN_PEAK_TIME
		scale = Vector2.ONE * lerpf(0.6, 1.1, first_phase)
	elif _elapsed < POP_IN_DURATION:
		var second_phase: float = (
			(_elapsed - POP_IN_PEAK_TIME) / (POP_IN_DURATION - POP_IN_PEAK_TIME)
		)
		scale = Vector2.ONE * lerpf(1.1, 1.0, second_phase)
	else:
		scale = Vector2.ONE
	var fade_start: float = _duration - FADE_DURATION
	modulate.a = (
		1.0 if _elapsed <= fade_start
		else clampf(1.0 - (_elapsed - fade_start) / FADE_DURATION, 0.0, 1.0)
	)
	if _elapsed >= _duration:
		deactivate()


func _configure_cosmic_style() -> void:
	var shadow_color: Color = GOLD_COLOR
	shadow_color.a = COSMIC_GLOW_ALPHA if _cosmic_score else 0.0
	_score_label.add_theme_color_override("font_shadow_color", shadow_color)
	_score_label.add_theme_constant_override(
		"shadow_outline_size",
		16 if _cosmic_score else 0
	)
	for sparkle: CosmicSparkle in _sparkles:
		sparkle.stop()
	if not _cosmic_score:
		return
	var sparkle_count: int = 2 if points >= 1000 else 1
	var offsets: Array[Vector2] = [Vector2(-65.8, -16.8), Vector2(68.6, 9.8)]
	for index: int in range(sparkle_count):
		_sparkles[index].play(
			POPUP_SIZE * 0.5,
			GOLD_COLOR,
			_duration,
			offsets[index],
			offsets[index] * 1.18,
			0.0,
			10.0 + float(index) * 2.0
		)
