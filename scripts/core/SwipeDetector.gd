class_name SwipeDetector
extends RefCounted


static func classify(
	delta: Vector2,
	min_distance: float,
	dominance_ratio: float
) -> Vector2i:
	if delta.length() < min_distance:
		return Vector2i.ZERO

	var horizontal: float = absf(delta.x)
	var vertical: float = absf(delta.y)
	var major: float = maxf(horizontal, vertical)
	var minor: float = minf(horizontal, vertical)
	if major < minor * dominance_ratio:
		return Vector2i.ZERO

	if horizontal >= vertical:
		return Vector2i.RIGHT if delta.x > 0.0 else Vector2i.LEFT
	return Vector2i.DOWN if delta.y > 0.0 else Vector2i.UP
