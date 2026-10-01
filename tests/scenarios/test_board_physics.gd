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
const DIVERGENCE_SPEED: float = 5000.0
const DIVERGENCE_MARGIN: float = 100.0
const STANDARD_ORB_COUNT: int = 5
const POSITION_TOLERANCE: float = 0.1


func test_floor_resistance_is_zero_for_airborne_orb_contact() -> void:
	var original_resistance: float = Config.data.rolling_resistance
	Config.data.rolling_resistance = 1.5
	var board: Board = BOARD_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	var radius: float = Config.data.radius_for_level(1)
	var left: Orb = board.spawn_orb(0, 1, Vector2(-radius, 0.0), Vector2(100.0, 0.0))
	var right: Orb = board.spawn_orb(1, 1, Vector2(radius, 0.0), Vector2(-100.0, 0.0))
	await tree.physics_frame
	assert_board_motion_bounds(board, "airborne contact")
	assert_true(
		left._last_rolling_resistance_force.is_zero_approx(),
		"airborne left orb rolling force"
	)
	assert_true(
		right._last_rolling_resistance_force.is_zero_approx(),
		"airborne right orb rolling force"
	)
	assert_eq(board.escape_guard_count, 0, "airborne contact escape guards")
	board.queue_free()
	await tree.process_frame
	Config.data.rolling_resistance = original_resistance


func test_guard_restores_orb_after_forty_pixel_penetration() -> void:
	var board: Board = BOARD_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	var final_radius: float = Config.data.radius_for_level(1)
	var current_radius: float = (
		final_radius
		if Config.data.grow_duration <= 0.0
		else final_radius * Config.data.grow_start_ratio
	)
	var boundary: float = board.half_size() - current_radius
	var orb: Orb = board.spawn_orb(
		0,
		1,
		Vector2(boundary + 40.0, 0.0),
		Vector2(100.0, 0.0)
	)
	orb.set_physics_process(false)
	orb._physics_process(0.0)
	var body_transform: Transform2D = PhysicsServer2D.body_get_state(
		orb.get_rid(),
		PhysicsServer2D.BODY_STATE_TRANSFORM
	) as Transform2D
	var body_velocity: Vector2 = PhysicsServer2D.body_get_state(
		orb.get_rid(),
		PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY
	) as Vector2
	assert_eq(board.escape_guard_count, 1, "forty-pixel penetration guard count")
	assert_near(
		body_transform.origin.x,
		boundary,
		POSITION_TOLERANCE,
		"guarded boundary position"
	)
	assert_true(body_velocity.x <= 0.0, "outward velocity component cleared")
	board.queue_free()
	await tree.process_frame


func test_cycle_seeded_orbs_remain_inside_board_during_gravity_cycles() -> void:
	var results: Array[Dictionary] = []
	for seed: int in range(STANDARD_SEED_START, STANDARD_SEED_END_EXCLUSIVE):
		var standard_levels: Array[int] = _standard_levels(STANDARD_ORB_COUNT)
		results.append(await _run_scenario(seed, "standard", standard_levels))

	var regression_levels: Array[int] = _standard_levels(STANDARD_ORB_COUNT)
	results.append(await _run_scenario(KNOWN_REGRESSION_SEED, "regression", regression_levels))

	var worst_case_levels: Array[int] = [4, 4, 4, 4, 1, 1, 1, 1]
	results.append(await _run_scenario(WORST_CASE_SEED, "worst", worst_case_levels))

	var total_departures: int = 0
	var total_escape_guards: int = 0
	var total_wall_recoveries: int = 0
	var total_timeout_corrections: int = 0
	var total_ghost_timeouts: int = 0
	var total_divergences: int = 0
	var overall_maximum_penetration: float = 0.0
	var overall_maximum_penetration_ratio: float = 0.0
	var overall_maximum_penetration_level: int = 0
	var overall_maximum_speed: float = 0.0
	var recovery_timeout_lags: Array[int] = []
	for result: Dictionary in results:
		total_departures += int(result["departures"])
		total_escape_guards += int(result["escape_guards"])
		total_wall_recoveries += int(result["wall_recoveries"])
		total_timeout_corrections += int(result["timeout_corrections"])
		total_ghost_timeouts += int(result["ghost_timeouts"])
		total_divergences += int(result["divergences"])
		overall_maximum_penetration = maxf(
			overall_maximum_penetration,
			float(result["max_penetration"])
		)
		overall_maximum_speed = maxf(overall_maximum_speed, float(result["max_speed"]))
		if float(result["max_penetration_ratio"]) > overall_maximum_penetration_ratio:
			overall_maximum_penetration_ratio = float(result["max_penetration_ratio"])
			overall_maximum_penetration_level = int(result["max_penetration_level"])
		recovery_timeout_lags.append_array(
			result["wall_recovery_timeout_lags"] as Array[int]
		)

	print(
		"Scenario summary: seeds=%d departures=%d divergences=%d max_penetration=%.3f max_penetration_ratio=%.6f ratio_level=%d max_speed=%.3f escape_guards=%d wall_recoveries=%d recovery_timeout_lags=%s timeout_corrections=%d ghost_timeouts=%d" % [
			results.size(),
			total_departures,
			total_divergences,
			overall_maximum_penetration,
			overall_maximum_penetration_ratio,
			overall_maximum_penetration_level,
			overall_maximum_speed,
			total_escape_guards,
			total_wall_recoveries,
			str(recovery_timeout_lags),
			total_timeout_corrections,
			total_ghost_timeouts,
		]
	)
	assert_eq(total_departures, 0, "total orb center departures")
	assert_eq(total_divergences, 0, "total divergent orb frames")
	assert_eq(total_escape_guards, 0, "total escape guard activations")
	assert_eq(total_wall_recoveries, 0, "total wall recovery activations")
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
	var divergence_count: int = 0
	var maximum_penetration: float = 0.0
	var maximum_penetration_ratio: float = 0.0
	var maximum_penetration_level: int = 0
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
				assert_board_motion_bounds(
					board,
					"physics seed %d frame %d" % [seed, scenario_frame + 1]
				)
				scenario_frame += 1
				var orbs: Array[Orb] = board.get_orbs()
				for orb_index: int in range(orbs.size()):
					var orb: Orb = orbs[orb_index]
					var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
					var penetration: float = maxf(
						center_extent + orb.get_current_radius() - board.half_size(),
						0.0
					)
					maximum_penetration = maxf(maximum_penetration, penetration)
					var penetration_ratio: float = penetration / orb.get_radius()
					if penetration_ratio > maximum_penetration_ratio:
						maximum_penetration_ratio = penetration_ratio
						maximum_penetration_level = orb.level
					var speed: float = orb.linear_velocity.length()
					maximum_speed = maxf(maximum_speed, speed)
					if (
						speed > DIVERGENCE_SPEED
						or center_extent > board.half_size() + DIVERGENCE_MARGIN
					):
						divergence_count += 1
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
		"Scenario seed=%d kind=%s initial_overlaps=%d departures=%d divergences=%d max_penetration=%.3f max_penetration_ratio=%.6f ratio_level=%d max_speed=%.3f escape_guards=%d wall_recoveries=%d recovery_timeout_lags=%s timeout_corrections=%d ghost_timeouts=%d" % [
			seed,
			scenario_name,
			initial_overlap_count,
			departure_count,
			divergence_count,
			maximum_penetration,
			maximum_penetration_ratio,
			maximum_penetration_level,
			maximum_speed,
			board.escape_guard_count,
			board.wall_recovery_count,
			str(board.wall_recovery_since_last_ghost_timeout_frames),
			board.timeout_correction_count,
			board.ghost_timeout_count,
		]
	)
	assert_eq(departure_count, 0, "seed %d orb center departures" % seed)
	assert_eq(divergence_count, 0, "seed %d divergent orb frames" % seed)
	assert_eq(board.escape_guard_count, 0, "seed %d escape guard activations" % seed)
	assert_eq(board.wall_recovery_count, 0, "seed %d wall recovery activations" % seed)
	assert_true(
		maximum_penetration <= MAX_ALLOWED_PENETRATION,
		"seed %d wall penetration must be at most %.3fpx, got %.3fpx" % [
			seed,
			MAX_ALLOWED_PENETRATION,
			maximum_penetration,
		]
	)

	var escape_guard_count: int = board.escape_guard_count
	var wall_recovery_count: int = board.wall_recovery_count
	var timeout_correction_count: int = board.timeout_correction_count
	var ghost_timeout_count: int = board.ghost_timeout_count
	var wall_recovery_timeout_lags: Array[int] = (
		board.wall_recovery_since_last_ghost_timeout_frames.duplicate()
	)
	board.queue_free()
	await tree.process_frame
	return {
		"seed": seed,
		"kind": scenario_name,
		"departures": departure_count,
		"divergences": divergence_count,
		"max_penetration": maximum_penetration,
		"max_penetration_ratio": maximum_penetration_ratio,
		"max_penetration_level": maximum_penetration_level,
		"max_speed": maximum_speed,
		"escape_guards": escape_guard_count,
		"wall_recoveries": wall_recovery_count,
		"wall_recovery_timeout_lags": wall_recovery_timeout_lags,
		"timeout_corrections": timeout_correction_count,
		"ghost_timeouts": ghost_timeout_count,
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
