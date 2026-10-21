class_name JellyFinalMoveBanner
extends Control

const ORBITRON: FontFile = preload("res://assets/fonts/Orbitron[wght].ttf")
const KOREAN_FONT: FontFile = preload("res://assets/fonts/NotoSansKR-Medium-KSX1001.ttf")
const WARNING_COLOR: Color = Color("#FFCF66")
const BACKGROUND_COLOR: Color = Color(0.08, 0.05, 0.10, 0.82)

var message: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	visible = false


func show_final_move(next_message: String) -> void:
	message = next_message
	visible = true
	set_process(true)
	queue_redraw()


func hide_final_move() -> void:
	visible = false
	set_process(false)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var band_width: float = minf(maxf(size.x - 80.0, 1.0), 420.0)
	var band_rect: Rect2 = Rect2(
		(size.x - band_width) * 0.5,
		maxf(size.y * 0.5 - 360.0, 174.0),
		band_width,
		68.0
	)
	var pulse: float = 0.82 + sin(float(Time.get_ticks_msec()) * 0.008) * 0.18
	draw_rect(band_rect, BACKGROUND_COLOR, true)
	draw_rect(band_rect, Color(WARNING_COLOR, pulse), false, 3.0)
	draw_string(
		ORBITRON,
		band_rect.position + Vector2(0.0, 44.0),
		"FINAL MOVE",
		HORIZONTAL_ALIGNMENT_CENTER,
		band_rect.size.x,
		28,
		WARNING_COLOR
	)
	draw_string(
		KOREAN_FONT,
		band_rect.position + Vector2(-40.0, 100.0),
		message,
		HORIZONTAL_ALIGNMENT_CENTER,
		band_rect.size.x + 80.0,
		18,
		Color("#DFE8FF")
	)
