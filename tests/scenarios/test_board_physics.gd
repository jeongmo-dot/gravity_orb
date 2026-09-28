extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
]
const SIMULATION_SECONDS_PER_DIRECTION: float = 2.0
const LAPS: int = 4
const STANDARD_SEED_START: int = 1000
const STANDARD_SEED_END_EXCLUSIVE: int = 1020
const KNOWN_REGRESSION_SEED: int = 1047
const WORST_CASE_SEED: int = 2000
const MAX_ALLOWED_PENETRATION: float = 10.0


func test_seeded_orbs_remain_inside_board_during_gravity_cycles() -> void:
	var results: Array[Dictionary] = []
	for seed: int in range(STANDARD_SEED_START, STANDARD_SEED_END_EXCLUSIVE):
		var standard_levels: Array[int] = _standard_levels(Config.data.debug_test_orb_count)
		results.append(await _run_scenario(seed, "standard", standard_levels))

	var regression_levels: Array[int] = _standard_levels(Config.data.debug_test_orb_count)
	results.append(await _run_scenario(KNOWN_REGRESSION_SEED, "regression", regression_levels))

	var worst_case_levels: Array[int] = [4, 4, 4, 4, 1, 1, 1, 1]
	results.append(await _run_scenario(WORST_CASE_SEED, "worst", worst_case_levels))

	var total_departures: int = 0
	var overall_maximum_penetration: float = 0.0
	var overall_maximum_speed: float = 0.0
	for result: Dictionary in results:
		total_departures += int(result["departures"])
		overall_maximum_penetration = maxf(
			overall_maximum_penetration,
			float(result["max_penetration"])
		)
		overall_maximum_speed = maxf(overall_maximum_speed, float(result["max_speed"]))

	print(
		"Scenario summary: seeds=%d departures=%d max_penetration=%.3f max_speed=%.3f" % [
			results.size(),
			total_departures,
			overall_maximum_penetration,
			overall_maximum_speed,
		]
	)
	assert_eq(total_departures, 0, "total orb center departures")
	assert_true(
		overall_maximum_penetration <= MAX_ALLOWED_PENETRATION,
		"overall wall penetration must be at most %.3fpx, got %.3fpx" % [
			MAX_ALLOWED_PENETRATION,
			overall_maximum_penetration,
		]
	)


func _run_scenario(seed: int, scenario_name: String, levels: Array[int]) -> Dictionary:
	var board: Board = BOARD_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	_spawn_seeded_orbs(board, rng, levels)

	var initial_overlap_count: int = _count_initial_overlaps(board)
	var departure_count: int = 0
	var maximum_penetration: float = 0.0
	var maximum_speed: float = 0.0
	var first_departure_recorded: bool = false
	var scenario_frame: int = 0
	var frames_per_direction: int = int(
		Engine.physics_ticks_per_second * SIMULATION_SECONDS_PER_DIRECTION
	)

	assert_eq(initial_overlap_count, 0, "seed %d initial wall or orb overlaps" % seed)
	for lap: int in range(LAPS):
		for direction: Vector2i in DIRECTIONS:
			board.set_gravity(direction)
			for _frame: int in range(frames_per_direction):
				await tree.physics_frame
				scenario_frame += 1
				var orbs: Array[Orb] = board.get_orbs()
				for orb_index: int in range(orbs.size()):
					var orb: Orb = orbs[orb_index]
					var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
					var penetration: float = maxf(
						center_extent + orb.get_radius() - board.half_size(),
						0.0
					)
					maximum_penetration = maxf(maximum_penetration, penetration)
					maximum_speed = maxf(maximum_speed, orb.linear_velocity.length())
					if center_extent <= board.half_size():
						continue

					departure_count += 1
					if first_departure_recorded:
						continue
					first_departure_recorded = true
					print(
						"Scenario departure: seed=%d frame=%d lap=%d direction=%s orb=%d level=%d position=%s velocity=%s" % [
							seed,
							scenario_frame,
							lap + 1,
							OrbTypes.dir_name(direction),
							orb_index,
							orb.level,
							str(orb.position),
							str(orb.linear_velocity),
						]
					)

	print(
		"Scenario seed=%d kind=%s initial_overlaps=%d departures=%d max_penetration=%.3f max_speed=%.3f" % [
			seed,
			scenario_name,
			initial_overlap_count,
			departure_count,
			maximum_penetration,
			maximum_speed,
		]
	)
	assert_eq(departure_count, 0, "seed %d orb center departures" % seed)
	assert_true(
		maximum_penetration <= MAX_ALLOWED_PENETRATION,
		"seed %d wall penetration must be at most %.3fpx, got %.3fpx" % [
			seed,
			MAX_ALLOWED_PENETRATION,
			maximum_penetration,
		]
	)

	board.queue_free()
	await tree.process_frame
	return {
		"seed": seed,
		"kind": scenario_name,
		"departures": departure_count,
		"max_penetration": maximum_penetration,
		"max_speed": maximum_speed,
	}


func _spawn_seeded_orbs(
	board: Board,
	rng: RandomNumberGenerator,
	levels: Array[int]
) -> void:
	var count: int = levels.size()
	var columns: int = ceili(sqrt(float(count)))
	var rows: int = ceili(float(count) / float(columns))
	var cell_width: float = Config.data.board_size / float(columns)
	var cell_height: float = Config.data.board_size / float(rows)
	var half: float = board.half_size()
	var color_count: int = Config.data.color_display.size()

	for index: int in range(count):
		var color: int = index % color_count
		var level: int = levels[index]
		var radius: float = Config.data.radius_for_level(level)
		var column: int = index % columns
		var row: int = int(index / columns)
		var cell_center: Vector2 = Vector2(
			-half + (float(column) + 0.5) * cell_width,
			-half + (float(row) + 0.5) * cell_height
		)
		var max_offset: Vector2 = Vector2(
			maxf(cell_width * 0.5 - radius, 0.0),
			maxf(cell_height * 0.5 - radius, 0.0)
		)
		var offset: Vector2 = Vector2(
			rng.randf_range(-max_offset.x, max_offset.x),
			rng.randf_range(-max_offset.y, max_offset.y)
		)
		board.spawn_orb(color, level, cell_center + offset)


func _standard_levels(count: int) -> Array[int]:
	var levels: Array[int] = []
	for index: int in range(count):
		levels.append(index % 4 + 1)
	return levels


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
