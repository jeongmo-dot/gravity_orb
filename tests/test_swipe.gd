extends TestCase

const MIN_DISTANCE: float = 80.0
const DOMINANCE_RATIO: float = 1.5


func test_four_directions() -> void:
	assert_eq(_classify(Vector2(200.0, 0.0)), Vector2i.RIGHT, "right")
	assert_eq(_classify(Vector2(-200.0, 0.0)), Vector2i.LEFT, "left")
	assert_eq(_classify(Vector2(0.0, 200.0)), Vector2i.DOWN, "down")
	assert_eq(_classify(Vector2(0.0, -200.0)), Vector2i.UP, "up")


func test_minimum_distance_boundary() -> void:
	assert_eq(_classify(Vector2(79.9, 0.0)), Vector2i.ZERO, "below minimum")
	assert_eq(_classify(Vector2(80.0, 0.0)), Vector2i.RIGHT, "minimum included")


func test_dominance_boundary_and_diagonals() -> void:
	assert_eq(_classify(Vector2(150.0, 100.0)), Vector2i.RIGHT, "ratio boundary included")
	assert_eq(_classify(Vector2(149.0, 100.0)), Vector2i.ZERO, "below ratio")
	assert_eq(_classify(Vector2(100.0, 100.0)), Vector2i.ZERO, "equal diagonal")


func _classify(delta: Vector2) -> Vector2i:
	return SwipeDetector.classify(delta, MIN_DISTANCE, DOMINANCE_RATIO)
