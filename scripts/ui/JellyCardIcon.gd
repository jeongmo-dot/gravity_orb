class_name JellyCardIcon
extends Control

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
		JellyOrbArt.preview_texture_for(COLOR_INDEX, LEVEL),
		Rect2(center - Vector2.ONE * radius, Vector2.ONE * diameter),
		false
	)
	var source_radius: float = Config.data.radius_for_level(LEVEL)
	var face_scale: float = radius / source_radius
	var level_index: int = LEVEL - 1
	var eye_size: float = clampf(3.8 + float(level_index) * 0.75, 3.8, 7.6) * face_scale
	var half_width: float = eye_size * 0.72
	var half_height: float = eye_size * lerpf(1.08, 1.42, float(level_index) / 6.0)
	var eye_y: float = center.y - 0.12 * radius
	var eye_spacing: float = 0.30 * radius
	for side: float in [-1.0, 1.0]:
		var eye_center: Vector2 = Vector2(center.x + side * eye_spacing, eye_y)
		_draw_capsule_eye(eye_center, half_width, half_height)
		draw_circle(
			eye_center + Vector2(-0.28 * half_width, -0.40 * half_height),
			maxf(1.0, 0.27 * half_width),
			Color(1.0, 1.0, 1.0, 0.88)
		)


func _draw_capsule_eye(center: Vector2, half_width: float, half_height: float) -> void:
	var inner_height: float = maxf(0.0, half_height - half_width)
	draw_rect(
		Rect2(
			center.x - half_width,
			center.y - inner_height,
			half_width * 2.0,
			inner_height * 2.0
		),
		FACE_COLOR,
		true
	)
	draw_circle(center - Vector2(0.0, inner_height), half_width, FACE_COLOR)
	draw_circle(center + Vector2(0.0, inner_height), half_width, FACE_COLOR)
