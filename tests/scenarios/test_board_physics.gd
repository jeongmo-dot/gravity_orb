extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
]
const PHYSICS_FRAMES_PER_DIRECTION: int = 120
const LAPS: int = 4


func test_orbs_remain_inside_board_during_gravity_cycles() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	tree.root.add_child(main)
	await tree.process_frame
	var board: Board = main.get_node("Board") as Board
	var initial_overlap_count: int = _count_initial_overlaps(board)
	var departure_count: int = 0
	var maximum_speed: float = 0.0

	assert_eq(board.get_orbs().size(), Config.data.debug_test_orb_count, "test orb count")
	assert_eq(initial_overlap_count, 0, "initial wall or orb overlaps")
	for _lap: int in range(LAPS):
		for direction: Vector2i in DIRECTIONS:
			board.set_gravity(direction)
			for _frame: int in range(PHYSICS_FRAMES_PER_DIRECTION):
				await tree.physics_frame
				for orb: Orb in board.get_orbs():
					maximum_speed = maxf(maximum_speed, orb.linear_velocity.length())
					if absf(orb.position.x) > board.half_size() or absf(orb.position.y) > board.half_size():
						departure_count += 1

	print(
		"Scenario board_bounds: initial_overlaps=%d departures=%d max_speed=%.3f" % [
			initial_overlap_count,
			departure_count,
			maximum_speed,
		]
	)
	assert_eq(departure_count, 0, "orb center departures beyond board half-size")
	main.queue_free()
	await tree.process_frame


func _count_initial_overlaps(board: Board) -> int:
	var orbs: Array[Orb] = board.get_orbs()
	var overlap_count: int = 0
	for index: int in range(orbs.size()):
		var orb: Orb = orbs[index]
		var radius: float = orb.get_radius()
		if absf(orb.position.x) + radius > board.half_size():
			overlap_count += 1
		if absf(orb.position.y) + radius > board.half_size():
			overlap_count += 1
		for other_index: int in range(index + 1, orbs.size()):
			var other: Orb = orbs[other_index]
			var minimum_distance: float = radius + other.get_radius()
			if orb.position.distance_to(other.position) < minimum_distance:
				overlap_count += 1
	return overlap_count
