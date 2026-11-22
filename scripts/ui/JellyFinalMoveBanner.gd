class_name JellyFinalMoveBanner
extends Control

const JUA: FontFile = preload("res://assets/fonts/Jua-Regular.ttf")
const TITLE_COLOR: Color = Color("#C2334A")
const TEXT_COLOR: Color = Color("#5B2A3C")

var message: String = ""
var _panel_style: StyleBoxFlat


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color("#FFFAF3")
	_panel_style.border_color = Color("#FF5A6E")
	_panel_style.set_border_width_all(6)
	_panel_style.set_corner_radius_all(30)
	_panel_style.shadow_color = Color("#C2334A")
	_panel_style.shadow_size = 1
	_panel_style.shadow_offset = Vector2(0.0, 8.0)
	set_process(false)
	visible = false


func show_final_move(next_message: String) -> void:
	message = next_message
	visible = true
	queue_redraw()


func hide_final_move() -> void:
	visible = false


func _draw() -> void:
	if not visible:
		return
	var band_width: float = minf(maxf(size.x - 80.0, 1.0), 420.0)
	var band_rect: Rect2 = Rect2(
		(size.x - band_width) * 0.5,
		maxf(size.y * 0.5 - 360.0, 174.0),
		band_width,
		122.0
	)
	draw_style_box(_panel_style, band_rect)
	draw_string(
		JUA,
		band_rect.position + Vector2(0.0, 44.0),
		"FINAL MOVE",
		HORIZONTAL_ALIGNMENT_CENTER,
		band_rect.size.x,
		32,
		TITLE_COLOR
	)
	draw_string(
		JUA,
		band_rect.position + Vector2(-40.0, 91.0),
		message,
		HORIZONTAL_ALIGNMENT_CENTER,
		band_rect.size.x + 80.0,
		24,
		TEXT_COLOR
	)
