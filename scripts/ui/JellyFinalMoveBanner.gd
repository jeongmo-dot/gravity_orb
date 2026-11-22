class_name JellyFinalMoveBanner
extends Control

const TITLE_COLOR: Color = Color("#C2334A")
const TEXT_COLOR: Color = Color("#5B2A3C")
const HUD_THEME: Theme = preload("res://assets/ui/gravity_orb_theme.tres")
const BAND_MIN_WIDTH: float = 420.0
const BAND_SCREEN_MARGIN: float = 40.0
const BAND_HEIGHT: float = 122.0
const BORDER_WIDTH: float = 6.0
const INNER_PADDING: float = 24.0
const GLYPH_EDGE_SAFETY: float = 4.0
const TITLE_FONT_SIZE: int = 32
const MESSAGE_FONT_MAX: int = 24
const MESSAGE_FONT_MIN: int = 18

var message: String = ""
var _panel_style: StyleBoxFlat
var _warm_font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = HUD_THEME
	_warm_font = get_theme_font(&"font", &"WarmText")
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
	var layout: Dictionary = layout_for_message(message)
	var band_rect: Rect2 = layout["band_rect"] as Rect2
	var text_rect: Rect2 = layout["text_rect"] as Rect2
	var message_font_size: int = int(layout["message_font_size"])
	draw_style_box(_panel_style, band_rect)
	draw_string(
		_warm_font,
		Vector2(text_rect.position.x, band_rect.position.y + 44.0),
		"FINAL MOVE",
		HORIZONTAL_ALIGNMENT_CENTER,
		text_rect.size.x,
		TITLE_FONT_SIZE,
		TITLE_COLOR
	)
	draw_string(
		_warm_font,
		Vector2(text_rect.position.x, band_rect.position.y + 91.0),
		message,
		HORIZONTAL_ALIGNMENT_CENTER,
		text_rect.size.x,
		message_font_size,
		TEXT_COLOR
	)


func layout_for_message(text: String) -> Dictionary:
	var font: Font = _warm_font
	if font == null:
		font = HUD_THEME.get_font(&"font", &"WarmText")
	var max_band_width: float = maxf(size.x - BAND_SCREEN_MARGIN * 2.0, 1.0)
	var fixed_horizontal_space: float = 2.0 * (
		BORDER_WIDTH + INNER_PADDING + GLYPH_EDGE_SAFETY
	)
	var max_text_width: float = maxf(max_band_width - fixed_horizontal_space, 1.0)
	var message_font_size: int = MESSAGE_FONT_MAX
	while (
		message_font_size > MESSAGE_FONT_MIN
		and _text_width(font, text, message_font_size) > max_text_width
	):
		message_font_size -= 1
	var title_width: float = _text_width(font, "FINAL MOVE", TITLE_FONT_SIZE)
	var message_width: float = _text_width(font, text, message_font_size)
	var desired_width: float = maxf(
		BAND_MIN_WIDTH,
		maxf(title_width, message_width) + fixed_horizontal_space
	)
	var band_width: float = minf(desired_width, max_band_width)
	var band_rect: Rect2 = Rect2(
		(size.x - band_width) * 0.5,
		maxf(size.y * 0.5 - 360.0, 174.0),
		band_width,
		BAND_HEIGHT
	)
	var inset: float = BORDER_WIDTH + INNER_PADDING
	return {
		"band_rect": band_rect,
		"text_rect": Rect2(
			band_rect.position + Vector2(inset, 0.0),
			Vector2(maxf(band_rect.size.x - inset * 2.0, 1.0), band_rect.size.y)
		),
		"message_font_size": message_font_size,
		"message_width": message_width,
	}


static func _text_width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size
	).x


func uses_theme_font_variation() -> bool:
	return _warm_font is FontVariation
