class_name WarmRibbon
extends Control

const FACE_COLOR: Color = Color("#F2557F")
const DEPTH_COLOR: Color = Color("#B8325C")
const FOLD_RATIO: float = 0.06
const DEPTH_OFFSET: float = 12.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var face_height: float = maxf(size.y - DEPTH_OFFSET, 1.0)
	var face_size: Vector2 = Vector2(size.x, face_height)
	draw_colored_polygon(_ribbon_points(face_size, Vector2(0.0, DEPTH_OFFSET)), DEPTH_COLOR)
	draw_colored_polygon(_ribbon_points(face_size, Vector2.ZERO), FACE_COLOR)


func _ribbon_points(face_size: Vector2, offset: Vector2) -> PackedVector2Array:
	var fold: float = face_size.x * FOLD_RATIO
	var middle_y: float = face_size.y * 0.5
	return PackedVector2Array([
		offset,
		offset + Vector2(face_size.x, 0.0),
		offset + Vector2(face_size.x - fold, middle_y),
		offset + face_size,
		offset + Vector2(0.0, face_size.y),
		offset + Vector2(fold, middle_y),
	])
