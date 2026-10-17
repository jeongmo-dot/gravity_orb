class_name SlimeCardIcon
extends Control

const CONFIG: SlimeConfig = preload("res://config/slime_config.tres")
const LEVEL: int = 3
const COLOR_INDEX: int = 0
const FACE_COLOR: Color = Color("17203c")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var diameter: float = minf(size.x, size.y)
	if diameter <= 0.0:
		return
	var radius: float = diameter * 0.5
	var center: Vector2 = size * 0.5
	draw_texture_rect(
		SlimeView.material_texture(CONFIG, COLOR_INDEX, LEVEL),
		Rect2(center - Vector2.ONE * radius, Vector2.ONE * diameter),
		false
	)
	var eye_radius: float = diameter * 0.055
	var eye_y: float = center.y - diameter * 0.055
	var eye_spacing: float = diameter * 0.145
	for side: float in [-1.0, 1.0]:
		var eye_center: Vector2 = Vector2(center.x + side * eye_spacing, eye_y)
		draw_circle(eye_center, eye_radius, FACE_COLOR)
		draw_circle(
			eye_center - Vector2(eye_radius * 0.26, eye_radius * 0.34),
			maxf(1.0, eye_radius * 0.27),
			Color(1.0, 1.0, 1.0, 0.9)
		)
	draw_arc(
		center + Vector2(0.0, diameter * 0.105),
		diameter * 0.075,
		0.12,
		PI - 0.12,
		18,
		FACE_COLOR,
		maxf(2.0, diameter * 0.035),
		true
	)
