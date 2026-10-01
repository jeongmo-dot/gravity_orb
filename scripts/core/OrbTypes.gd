class_name OrbTypes
extends RefCounted

enum OrbColor { RED, BLUE, GREEN, YELLOW }

const DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]


static func dir_name(direction: Vector2i) -> String:
	if direction == Vector2i.UP:
		return "UP"
	if direction == Vector2i.DOWN:
		return "DOWN"
	if direction == Vector2i.LEFT:
		return "LEFT"
	if direction == Vector2i.RIGHT:
		return "RIGHT"
	return "UNKNOWN"


static func perpendicular(direction: Vector2i) -> Vector2i:
	return Vector2i(-direction.y, direction.x)
