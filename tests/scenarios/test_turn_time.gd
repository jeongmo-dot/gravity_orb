extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const SEEDS: Array[int] = [101, 102, 103, 104, 105, 106]
const TURNS_PER_SEED: int = 20
const DIRECTION_PATTERN: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.RIGHT,
]
const SWEEP_ROLLING_RESISTANCES: Array[float] = [0.5, 1.0, 1.5]
const SWEEP_STABLE_THRESHOLDS: Vector2 = Vector2(30.0, 3.0)
const TARGET_MAX_FORCED_SETTLES: int = 6
const TARGET_MAX_P50: float = 1.9
const TARGET_MAX_P90: float = 2.2
const MAX_ALLOWED_PENETRATION: float = 12.0
const WAIT_TIMEOUT_SECONDS: float = 5.0
const CANDIDATE_ARGUMENT_PREFIX: String = "--turn-time-candidate="
const PHYSICS_DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
]
const PHYSICS_SECONDS_PER_DIRECTION: float = 2.0
const PHYSICS_LAPS: int = 4
const PHYSICS_STANDARD_SEED_START: int = 1000
const PHYSICS_STANDARD_SEED_END_EXCLUSIVE: int = 1020
const PHYSICS_REGRESSION_SEED: int = 1047
const PHYSICS_WORST_SEED: int = 2000
const PHYSICS_STANDARD_ORB_COUNT: int = 5
const CONTINUOUS_TURN_SEED: int = 4242
const CONTINUOUS_TURNS: int = 20
const OVERLAP_SEED: int = 4006
const OVERLAP_OBSERVE_SECONDS: float = 0.5


func test_selected_defaults_meet_turn_time_targets() -> void:
	if not _candidate_argument().is_empty():
		return
	var snapshot: Dictionary = _snapshot_config()
	var metrics: Dictionary = await _measure_current_config()
	_print_metrics("selected", metrics)
	assert_eq(
		int(metrics["turns"]),
		SEEDS.size() * TURNS_PER_SEED,
		"measured turns"
	)
	assert_true(
		int(metrics["forced_settles"]) <= TARGET_MAX_FORCED_SETTLES,
		"forced settles target"
	)
	assert_true(float(metrics["p50"]) <= TARGET_MAX_P50, "p50 target")
	assert_true(float(metrics["p90"]) <= TARGET_MAX_P90, "p90 target")
	_restore_config(snapshot)


func test_independent_candidate_report_when_requested() -> void:
	var candidate_argument: String = _candidate_argument()
	if candidate_argument.is_empty():
		return
	var snapshot: Dictionary = _snapshot_config()
	var rolling_resistance: float = candidate_argument.to_float()
	assert_true(
		is_zero_approx(rolling_resistance)
		or SWEEP_ROLLING_RESISTANCES.has(rolling_resistance),
		"supported independent candidate"
	)
	Config.data.rolling_resistance = rolling_resistance
	Config.data.rest_speed = 0.0
	Config.data.rest_damp = 0.0
	Config.data.stable_linear_speed = SWEEP_STABLE_THRESHOLDS.x
	Config.data.stable_angular_speed = SWEEP_STABLE_THRESHOLDS.y
	var metrics: Dictionary = await _measure_candidate()
	var qualifies: bool = _candidate_meets_targets(
		metrics["turn"] as Dictionary,
		metrics["physics"] as Dictionary,
		metrics["continuous"] as Dictionary,
		metrics["overlap"] as Dictionary
	)
	_print_candidate_metrics(
		metrics["turn"] as Dictionary,
		metrics["physics"] as Dictionary,
		metrics["continuous"] as Dictionary,
		metrics["overlap"] as Dictionary,
		qualifies
	)
	assert_eq(
		int((metrics["turn"] as Dictionary)["turns"]),
		SEEDS.size() * TURNS_PER_SEED,
		"independent candidate measured turns"
	)
	_restore_config(snapshot)


func _measure_candidate() -> Dictionary:
	var physics_metrics: Dictionary = await _measure_physics_regression()
	var continuous_metrics: Dictionary = await _measure_continuous_turns()
	var overlap_metrics: Dictionary = await _measure_overlap_spawn()
	var turn_metrics: Dictionary = await _measure_current_config()
	return {
		"turn": turn_metrics,
		"physics": physics_metrics,
		"continuous": continuous_metrics,
		"overlap": overlap_metrics,
	}


func _measure_current_config() -> Dictionary:
	var turn_times: Array[float] = []
	var direction_times: Dictionary = {
		"DOWN": [] as Array[float],
		"RIGHT": [] as Array[float],
		"UP": [] as Array[float],
		"LEFT": [] as Array[float],
	}
	var forced_settles: int = 0
	var final_orb_total: int = 0
	var escape_guard_total: int = 0
	var tick_seconds: float = 1.0 / float(Engine.physics_ticks_per_second)

	for seed: int in SEEDS:
		var fixture: Dictionary = await _create_ready_fixture(seed)
		var board: Board = fixture["board"] as Board
		var manager: TurnManager = fixture["manager"] as TurnManager
		for turn_offset: int in range(TURNS_PER_SEED):
			var direction: Vector2i = DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()]
			manager.on_swipe(direction)
			await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
			var turn_time: float = manager._settle_elapsed + tick_seconds
			turn_times.append(turn_time)
			var direction_name: String = OrbTypes.dir_name(direction)
			var samples: Array[float] = direction_times[direction_name] as Array[float]
			samples.append(turn_time)
			if manager._settle_elapsed + tick_seconds >= Config.data.max_settle_time:
				forced_settles += 1
		final_orb_total += board.get_orbs().size()
		escape_guard_total += board.escape_guard_count
		await _cleanup_fixture(fixture)

	return {
		"turns": turn_times.size(),
		"forced_settles": forced_settles,
		"average": _average(turn_times),
		"p50": _percentile(turn_times, 0.50),
		"p90": _percentile(turn_times, 0.90),
		"maximum": _percentile(turn_times, 1.0),
		"final_orb_average": float(final_orb_total) / float(SEEDS.size()),
		"escape_guards": escape_guard_total,
		"direction_p50": {
			"DOWN": _percentile(direction_times["DOWN"] as Array[float], 0.50),
			"RIGHT": _percentile(direction_times["RIGHT"] as Array[float], 0.50),
			"UP": _percentile(direction_times["UP"] as Array[float], 0.50),
			"LEFT": _percentile(direction_times["LEFT"] as Array[float], 0.50),
		},
	}


func _measure_physics_regression() -> Dictionary:
	var aggregate: Dictionary = _empty_board_metrics()
	var standard_levels: Array[int] = _standard_levels(PHYSICS_STANDARD_ORB_COUNT)
	for seed: int in range(PHYSICS_STANDARD_SEED_START, PHYSICS_STANDARD_SEED_END_EXCLUSIVE):
		var metrics: Dictionary = await _run_physics_scenario(seed, standard_levels)
		_merge_board_metrics(aggregate, metrics)
	var regression_metrics: Dictionary = await _run_physics_scenario(
		PHYSICS_REGRESSION_SEED,
		standard_levels
	)
	_merge_board_metrics(aggregate, regression_metrics)
	var worst_levels: Array[int] = [4, 4, 4, 4, 1, 1, 1, 1]
	var worst_metrics: Dictionary = await _run_physics_scenario(PHYSICS_WORST_SEED, worst_levels)
	_merge_board_metrics(aggregate, worst_metrics)
	return aggregate


func _run_physics_scenario(seed: int, levels: Array[int]) -> Dictionary:
	var board: Board = BOARD_SCENE.instantiate() as Board
	tree.root.add_child(board)
	await tree.process_frame
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	_spawn_seeded_orbs(board, rng, levels)
	var metrics: Dictionary = _empty_board_metrics()
	var frames_per_direction: int = int(
		Engine.physics_ticks_per_second * PHYSICS_SECONDS_PER_DIRECTION
	)
	for _lap: int in range(PHYSICS_LAPS):
		for direction: Vector2i in PHYSICS_DIRECTIONS:
			board.set_gravity(direction)
			for _frame: int in range(frames_per_direction):
				await tree.physics_frame
				_accumulate_board_metrics(board, metrics)
	board.queue_free()
	await tree.process_frame
	return metrics


func _measure_continuous_turns() -> Dictionary:
	var fixture: Dictionary = await _create_ready_fixture(CONTINUOUS_TURN_SEED, false)
	var board: Board = fixture["board"] as Board
	var manager: TurnManager = fixture["manager"] as TurnManager
	var metrics: Dictionary = _empty_board_metrics()
	for turn_offset: int in range(CONTINUOUS_TURNS):
		manager.on_swipe(PHYSICS_DIRECTIONS[turn_offset % PHYSICS_DIRECTIONS.size()])
		await _wait_for_state_with_metrics(manager, TurnManager.State.WAITING_INPUT, board, metrics)
	metrics["final_orbs"] = board.get_orbs().size()
	await _cleanup_fixture(fixture)
	return metrics


func _measure_overlap_spawn() -> Dictionary:
	var original_spawn_mode: GameConfig.SpawnPositionMode = Config.data.spawn_position_mode
	var original_initial_count: int = Config.data.initial_orb_count
	Config.data.spawn_position_mode = GameConfig.SpawnPositionMode.CENTER
	var fixture: Dictionary = await _create_fixture(OVERLAP_SEED, false)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	Config.data.initial_orb_count = 0
	spawner.spawn_initial(board, Vector2i.DOWN)
	Config.data.initial_orb_count = original_initial_count

	var radius: float = Config.data.radius_for_level(1)
	var bottom_y: float = board.half_size() - radius - Config.data.spawn_margin
	var bottom_x_positions: Array[float] = [-360.0, -240.0, -120.0, 0.0, 120.0, 240.0, 360.0]
	var overlap_dummy: Orb
	for index: int in range(bottom_x_positions.size()):
		var orb: Orb = board.spawn_orb(
			index % Config.data.color_display.size(),
			1,
			Vector2(bottom_x_positions[index], bottom_y)
		)
		if is_zero_approx(bottom_x_positions[index]):
			overlap_dummy = orb
	board.spawn_orb(1, 1, Vector2(0.0, bottom_y - radius * 2.0))

	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	var preview: Dictionary = spawner.peek_next()
	var spawned_radius: float = Config.data.radius_for_level(int(preview["level"]))
	var spawn_line: Dictionary = board.spawn_line(Vector2i.UP, spawned_radius)
	overlap_dummy.position = spawn_line["origin"] as Vector2
	overlap_dummy.linear_velocity = Vector2.ZERO
	overlap_dummy.angular_velocity = 0.0
	manager.on_swipe(Vector2i.UP)
	await _wait_for_state(manager, TurnManager.State.SIMULATING)
	var metrics: Dictionary = await _observe_board(board, OVERLAP_OBSERVE_SECONDS)
	await _cleanup_fixture(fixture)
	Config.data.spawn_position_mode = original_spawn_mode
	Config.data.initial_orb_count = original_initial_count
	return metrics


func _create_ready_fixture(seed: int, connect_merges: bool = true) -> Dictionary:
	var fixture: Dictionary = await _create_fixture(seed, connect_merges)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	return fixture


func _create_fixture(seed: int, connect_merges: bool) -> Dictionary:
	InputRouter.set_locked(false)
	var fixture_root: Node = Node.new()
	fixture_root.name = "TurnTimeFixture"

	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root

	var resolver: CollisionResolver = COLLISION_RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root

	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	fixture_root.add_child(spawner)
	spawner.owner = fixture_root

	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	fixture_root.add_child(manager)
	manager.owner = fixture_root

	tree.root.add_child(fixture_root)
	await tree.process_frame
	if not connect_merges and board.orb_contact.is_connected(resolver.report_contact):
		board.orb_contact.disconnect(resolver.report_contact)
	spawner.init_rng(seed)
	return {
		"root": fixture_root,
		"board": board,
		"spawner": spawner,
		"resolver": resolver,
		"manager": manager,
	}


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
	assert_eq(manager.state, target, "state wait timeout")


func _wait_for_state_with_metrics(
	manager: TurnManager,
	target: TurnManager.State,
	board: Board,
	metrics: Dictionary
) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
		_accumulate_board_metrics(board, metrics)
	assert_eq(manager.state, target, "state wait timeout")


func _cleanup_fixture(fixture: Dictionary) -> void:
	InputRouter.set_locked(false)
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame


func _observe_board(board: Board, duration_seconds: float) -> Dictionary:
	var metrics: Dictionary = _empty_board_metrics()
	var frame_count: int = ceili(float(Engine.physics_ticks_per_second) * duration_seconds)
	for _frame: int in range(frame_count):
		await tree.physics_frame
		_accumulate_board_metrics(board, metrics)
	return metrics


func _empty_board_metrics() -> Dictionary:
	return {
		"departures": 0,
		"max_penetration": 0.0,
		"escape_guards": 0,
	}


func _accumulate_board_metrics(board: Board, metrics: Dictionary) -> void:
	metrics["escape_guards"] = maxi(
		int(metrics["escape_guards"]),
		board.escape_guard_count
	)
	for orb: Orb in board.get_orbs():
		var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
		var penetration: float = maxf(
			center_extent + orb.get_radius() - board.half_size(),
			0.0
		)
		metrics["max_penetration"] = maxf(
			float(metrics["max_penetration"]),
			penetration
		)
		if center_extent > board.half_size():
			metrics["departures"] = int(metrics["departures"]) + 1


func _merge_board_metrics(aggregate: Dictionary, metrics: Dictionary) -> void:
	aggregate["departures"] = int(aggregate["departures"]) + int(metrics["departures"])
	aggregate["escape_guards"] = (
		int(aggregate["escape_guards"]) + int(metrics["escape_guards"])
	)
	aggregate["max_penetration"] = maxf(
		float(aggregate["max_penetration"]),
		float(metrics["max_penetration"])
	)


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
		board.spawn_orb(index % color_count, level, cell_center + offset)


func _standard_levels(count: int) -> Array[int]:
	var levels: Array[int] = []
	for index: int in range(count):
		levels.append(index % 4 + 1)
	return levels


func _average(values: Array[float]) -> float:
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], quantile: float) -> float:
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var index: int = ceili(quantile * float(sorted_values.size())) - 1
	return sorted_values[clampi(index, 0, sorted_values.size() - 1)]


func _print_metrics(label: String, metrics: Dictionary) -> void:
	var direction_p50: Dictionary = metrics["direction_p50"] as Dictionary
	print(
		"Turn-time %s rr=%.1f rest=%.0f/%.0f stable=%.0f/%.0f turns=%d forced=%d average=%.6f p50=%.6f p90=%.6f max=%.6f final_orbs_avg=%.3f escape_guards=%d direction_p50=[D %.6f R %.6f U %.6f L %.6f]" % [
			label,
			Config.data.rolling_resistance,
			Config.data.rest_speed,
			Config.data.rest_damp,
			Config.data.stable_linear_speed,
			Config.data.stable_angular_speed,
			int(metrics["turns"]),
			int(metrics["forced_settles"]),
			float(metrics["average"]),
			float(metrics["p50"]),
			float(metrics["p90"]),
			float(metrics["maximum"]),
			float(metrics["final_orb_average"]),
			int(metrics["escape_guards"]),
			float(direction_p50["DOWN"]),
			float(direction_p50["RIGHT"]),
			float(direction_p50["UP"]),
			float(direction_p50["LEFT"]),
		]
	)


func _candidate_meets_targets(
	turn_metrics: Dictionary,
	physics_metrics: Dictionary,
	continuous_metrics: Dictionary,
	overlap_metrics: Dictionary
) -> bool:
	return (
		int(turn_metrics["forced_settles"]) <= TARGET_MAX_FORCED_SETTLES
		and float(turn_metrics["p50"]) <= TARGET_MAX_P50
		and float(turn_metrics["p90"]) <= TARGET_MAX_P90
		and int(physics_metrics["departures"]) == 0
		and float(physics_metrics["max_penetration"]) <= MAX_ALLOWED_PENETRATION
		and int(continuous_metrics["departures"]) == 0
		and int(overlap_metrics["departures"]) == 0
		and float(overlap_metrics["max_penetration"]) <= MAX_ALLOWED_PENETRATION
		and int(physics_metrics["escape_guards"]) == 0
		and int(continuous_metrics["escape_guards"]) == 0
		and int(overlap_metrics["escape_guards"]) == 0
	)


func _print_candidate_metrics(
	turn_metrics: Dictionary,
	physics_metrics: Dictionary,
	continuous_metrics: Dictionary,
	overlap_metrics: Dictionary,
	qualifies: bool
) -> void:
	var direction_p50: Dictionary = turn_metrics["direction_p50"] as Dictionary
	print(
		"Turn-time candidate rr=%.1f rest=%.0f/%.0f stable=%.0f/%.0f forced=%d average=%.6f p50=%.6f p90=%.6f max=%.6f final_orbs_avg=%.3f physics_departures=%d physics_penetration=%.3f continuous_departures=%d continuous_penetration=%.3f overlap_departures=%d overlap_penetration=%.3f guards=[turn %d physics %d continuous %d overlap %d] qualifies=%s direction_p50=[D %.6f R %.6f U %.6f L %.6f]" % [
			Config.data.rolling_resistance,
			Config.data.rest_speed,
			Config.data.rest_damp,
			Config.data.stable_linear_speed,
			Config.data.stable_angular_speed,
			int(turn_metrics["forced_settles"]),
			float(turn_metrics["average"]),
			float(turn_metrics["p50"]),
			float(turn_metrics["p90"]),
			float(turn_metrics["maximum"]),
			float(turn_metrics["final_orb_average"]),
			int(physics_metrics["departures"]),
			float(physics_metrics["max_penetration"]),
			int(continuous_metrics["departures"]),
			float(continuous_metrics["max_penetration"]),
			int(overlap_metrics["departures"]),
			float(overlap_metrics["max_penetration"]),
			int(turn_metrics["escape_guards"]),
			int(physics_metrics["escape_guards"]),
			int(continuous_metrics["escape_guards"]),
			int(overlap_metrics["escape_guards"]),
			str(qualifies),
			float(direction_p50["DOWN"]),
			float(direction_p50["RIGHT"]),
			float(direction_p50["UP"]),
			float(direction_p50["LEFT"]),
		]
	)


func _candidate_argument() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(CANDIDATE_ARGUMENT_PREFIX):
			return argument.trim_prefix(CANDIDATE_ARGUMENT_PREFIX)
	return ""


func _snapshot_config() -> Dictionary:
	return {
		"rolling_resistance": Config.data.rolling_resistance,
		"rest_speed": Config.data.rest_speed,
		"rest_damp": Config.data.rest_damp,
		"stable_linear_speed": Config.data.stable_linear_speed,
		"stable_angular_speed": Config.data.stable_angular_speed,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.rolling_resistance = float(snapshot["rolling_resistance"])
	Config.data.rest_speed = float(snapshot["rest_speed"])
	Config.data.rest_damp = float(snapshot["rest_damp"])
	Config.data.stable_linear_speed = float(snapshot["stable_linear_speed"])
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])
