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
const SWEEP_ROLLING_RESISTANCES: Array[float] = [0.0, 0.1, 0.2, 0.3, 0.5]
const SWEEP_REST_SETTINGS: Array[Vector2] = [
	Vector2(0.0, 0.0),
	Vector2(60.0, 8.0),
	Vector2(120.0, 10.0),
]
const SWEEP_STABLE_THRESHOLDS: Array[Vector2] = [
	Vector2(12.0, 1.0),
	Vector2(30.0, 3.0),
]
const TARGET_MAX_FORCED_SETTLES: int = 6
const TARGET_MAX_P50: float = 1.6
const TARGET_MAX_P90: float = 2.2
const WAIT_TIMEOUT_SECONDS: float = 5.0
const SWEEP_ARGUMENT: String = "--turn-time-sweep"


func test_selected_defaults_meet_turn_time_targets() -> void:
	if OS.get_cmdline_user_args().has(SWEEP_ARGUMENT):
		return
	var snapshot: Dictionary = _snapshot_config()
	var metrics: Dictionary = await _measure_current_config()
	_print_metrics("selected", metrics)
	assert_eq(int(metrics["turns"]), SEEDS.size() * TURNS_PER_SEED, "measured turns")
	assert_true(
		int(metrics["forced_settles"]) <= TARGET_MAX_FORCED_SETTLES,
		"forced settles target"
	)
	assert_true(float(metrics["p50"]) <= TARGET_MAX_P50, "p50 target")
	assert_true(float(metrics["p90"]) <= TARGET_MAX_P90, "p90 target")
	_restore_config(snapshot)


func test_sweep_reports_all_thirty_combinations_when_requested() -> void:
	if not OS.get_cmdline_user_args().has(SWEEP_ARGUMENT):
		return
	var snapshot: Dictionary = _snapshot_config()
	var result_count: int = 0
	for rolling_resistance: float in SWEEP_ROLLING_RESISTANCES:
		for rest_setting: Vector2 in SWEEP_REST_SETTINGS:
			for thresholds: Vector2 in SWEEP_STABLE_THRESHOLDS:
				Config.data.rolling_resistance = rolling_resistance
				Config.data.rest_speed = rest_setting.x
				Config.data.rest_damp = rest_setting.y
				Config.data.stable_linear_speed = thresholds.x
				Config.data.stable_angular_speed = thresholds.y
				var metrics: Dictionary = await _measure_current_config()
				_print_metrics("sweep", metrics)
				result_count += 1
	assert_eq(result_count, 30, "sweep combination count")
	_restore_config(snapshot)


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
		await _cleanup_fixture(fixture)

	return {
		"turns": turn_times.size(),
		"forced_settles": forced_settles,
		"average": _average(turn_times),
		"p50": _percentile(turn_times, 0.50),
		"p90": _percentile(turn_times, 0.90),
		"maximum": _percentile(turn_times, 1.0),
		"final_orb_average": float(final_orb_total) / float(SEEDS.size()),
		"direction_p50": {
			"DOWN": _percentile(direction_times["DOWN"] as Array[float], 0.50),
			"RIGHT": _percentile(direction_times["RIGHT"] as Array[float], 0.50),
			"UP": _percentile(direction_times["UP"] as Array[float], 0.50),
			"LEFT": _percentile(direction_times["LEFT"] as Array[float], 0.50),
		},
	}


func _create_ready_fixture(seed: int) -> Dictionary:
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
	spawner.init_rng(seed)
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	return {
		"root": fixture_root,
		"board": board,
		"manager": manager,
	}


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
	assert_eq(manager.state, target, "state wait timeout")


func _cleanup_fixture(fixture: Dictionary) -> void:
	InputRouter.set_locked(false)
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame


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
		"Turn-time %s rr=%.1f rest=%.0f/%.0f stable=%.0f/%.0f turns=%d forced=%d average=%.6f p50=%.6f p90=%.6f max=%.6f final_orbs_avg=%.3f direction_p50=[D %.6f R %.6f U %.6f L %.6f]" % [
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
			float(direction_p50["DOWN"]),
			float(direction_p50["RIGHT"]),
			float(direction_p50["UP"]),
			float(direction_p50["LEFT"]),
		]
	)


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
