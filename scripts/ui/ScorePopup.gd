class_name ScorePopup
extends Control

signal finished(popup: ScorePopup)

const BASE_FONT_SIZE: float = 34.0
const POP_DURATION: float = 0.7
const LARGE_SCORE_EXTRA_DURATION: float = 0.2
const FADE_DURATION: float = 0.25
const RISE_DISTANCE: float = 60.0
const POP_IN_DURATION: float = 0.12
const POP_IN_PEAK_TIME: float = 0.07
const POPUP_SIZE: Vector2 = Vector2(440.0, 150.0)

var started_process_frame: int = -1
var anchor_position: Vector2 = Vector2.ZERO
var points: int = 0
var active: bool = false

var _score_label: Label
var _formula_label: Label
var _elapsed: float = 0.0
var _duration: float = POP_DURATION
var _shake_phase: float = 0.0


func _ready() -> void:
	custom_minimum_size = POPUP_SIZE
	size = POPUP_SIZE
	pivot_offset = POPUP_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_score_label = Label.new()
	_score_label.name = "Score"
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_score_label.offset_bottom = 96.0
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_score_label)
	_formula_label = Label.new()
	_formula_label.name = "Formula"
	_formula_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_formula_label.offset_top = 82.0
	_formula_label.offset_bottom = 132.0
	_formula_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_formula_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_formula_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_formula_label.add_theme_font_size_override("font_size", 22)
	_formula_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.86))
	add_child(_formula_label)
	deactivate(false)


func activate(
	screen_position: Vector2,
	p_points: int,
	formula: String,
	font_color: Color,
	outline_color: Color,
	outline_size: int,
	process_frame: int
) -> void:
	anchor_position = screen_position
	points = p_points
	started_process_frame = process_frame
	_elapsed = 0.0
	_duration = POP_DURATION + (LARGE_SCORE_EXTRA_DURATION if points >= 1000 else 0.0)
	_shake_phase = float((process_frame * 17 + points * 3) % 360) * PI / 180.0
	active = true
	visible = true
	modulate = Color.WHITE
	scale = Vector2.ONE * 0.6
	position = anchor_position - POPUP_SIZE * 0.5
	_score_label.text = "+%d" % points
	_score_label.add_theme_font_size_override("font_size", popup_font_size(points))
	_score_label.add_theme_color_override("font_color", font_color)
	_score_label.add_theme_color_override("font_outline_color", outline_color)
	_score_label.add_theme_constant_override("outline_size", outline_size)
	_formula_label.text = formula
	_formula_label.visible = not formula.is_empty()
	set_process(true)


func merge_score(additional_points: int) -> void:
	points += additional_points
	_duration = POP_DURATION + (LARGE_SCORE_EXTRA_DURATION if points >= 1000 else 0.0)
	_score_label.text = "+%d" % points
	_score_label.add_theme_font_size_override("font_size", popup_font_size(points))
	_formula_label.text = ""
	_formula_label.visible = false


func deactivate(emit_finished: bool = true) -> void:
	var was_active: bool = active
	active = false
	visible = false
	set_process(false)
	if emit_finished and was_active:
		finished.emit(self)


func score_text() -> String:
	return _score_label.text


func formula_text() -> String:
	return _formula_label.text if _formula_label.visible else ""


func score_color() -> Color:
	return _score_label.get_theme_color("font_color")


static func popup_font_size(score: int) -> int:
	var ratio: float = maxf(float(score) / 10.0, 0.0001)
	var factor: float = clampf(1.0 + 0.25 * log(ratio) / log(10.0), 1.0, 2.4)
	return roundi(BASE_FONT_SIZE * factor)


func _process(delta: float) -> void:
	if not active:
		return
	_elapsed += delta
	var progress: float = clampf(_elapsed / POP_DURATION, 0.0, 1.0)
	var shake_x: float = 0.0
	if points >= 1000:
		shake_x = sin(_elapsed * 44.0 + _shake_phase) * 3.0
	position = anchor_position - POPUP_SIZE * 0.5 + Vector2(shake_x, -RISE_DISTANCE * progress)
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
