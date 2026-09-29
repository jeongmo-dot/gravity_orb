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
const WAIT_TIMEOUT_SECONDS: float = 3.0


func test_all_turns_return_to_input_within_time_cap() -> void:
	var metrics: Dictionary = await _measure_current_config()
	_print_metrics(metrics)
	var tick_seconds: float = 1.0 / float(Engine.physics_ticks_per_second)
	assert_eq(
		int(metrics["turns"]),
		SEEDS.size() * TURNS_PER_SEED,
		"measured turns"
	)
	assert_true(
		float(metrics["maximum"]) <= Config.data.max_settle_time + tick_seconds,
		"all turns return within cap plus one physics tick"
	)


func _measure_current_config() -> Dictionary:
	var turn_times: Array[float] = []
	var direction_times: Dictionary = {
		"DOWN": [] as Array[float],
		"RIGHT": [] as Array[float],
		"UP": [] as Array[float],
		"LEFT": [] as Array[float],
	}
	var capped_turns: int = 0
	var final_orb_total: int = 0
	var escape_guard_total: int = 0
	var maximum_residual_speed: float = 0.0

	for seed: int in SEEDS:
		var fixture: Dictionary = await _create_ready_fixture(seed)
		var board: Board = fixture["board"] as Board
		var manager: TurnManager = fixture["manager"] as TurnManager
		for turn_offset: int in range(TURNS_PER_SEED):
			var direction: Vector2i = DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()]
			manager.on_swipe(direction)
			await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
			var turn_time: float = manager._settle_elapsed
			turn_times.append(turn_time)
			var direction_name: String = OrbTypes.dir_name(direction)
			var samples: Array[float] = direction_times[direction_name] as Array[float]
			samples.append(turn_time)
			maximum_residual_speed = maxf(
				maximum_residual_speed,
				_maximum_linear_speed(board)
			)
		capped_turns += manager.capped_turn_count
		final_orb_total += board.get_orbs().size()
		escape_guard_total += board.escape_guard_count
		await _cleanup_fixture(fixture)

	return {
		"turns": turn_times.size(),
		"capped_turns": capped_turns,
		"capped_ratio": float(capped_turns) / float(turn_times.size()),
		"average": _average(turn_times),
		"p50": _percentile(turn_times, 0.50),
		"p90": _percentile(turn_times, 0.90),
		"maximum": _percentile(turn_times, 1.0),
		"maximum_residual_speed": maximum_residual_speed,
		"final_orb_average": float(final_orb_total) / float(SEEDS.size()),
		"escape_guards": escape_guard_total,
		"direction_p50": {
			"DOWN": _percentile(direction_times["DOWN"] as Array[float], 0.50),
			"RIGHT": _percentile(direction_times["RIGHT"] as Array[float], 0.50),
			"UP": _percentile(direction_times["UP"] as Array[float], 0.50),
			"LEFT": _percentile(direction_times["LEFT"] as Array[float], 0.50),
		},
	}


func _maximum_linear_speed(board: Board) -> float:
	var maximum: float = 0.0
	for orb: Orb in board.get_orbs():
		maximum = maxf(maximum, orb.linear_velocity.length())
	return maximum


func _create_ready_fixture(seed: int) -> Dictionary:
	var fixture: Dictionary = await _create_fixture(seed)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	return fixture


func _create_fixture(seed: int) -> Dictionary:
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


func _print_metrics(metrics: Dictionary) -> void:
	var direction_p50: Dictionary = metrics["direction_p50"] as Dictionary
	print(
		"Turn-time cap=%.3f turns=%d capped=%d capped_ratio=%.6f average=%.6f p50=%.6f p90=%.6f max=%.6f max_residual_speed=%.3f final_orbs_avg=%.3f escape_guards=%d direction_p50=[D %.6f R %.6f U %.6f L %.6f]" % [
			Config.data.max_settle_time,
			int(metrics["turns"]),
			int(metrics["capped_turns"]),
			float(metrics["capped_ratio"]),
			float(metrics["average"]),
			float(metrics["p50"]),
			float(metrics["p90"]),
			float(metrics["maximum"]),
			float(metrics["maximum_residual_speed"]),
			float(metrics["final_orb_average"]),
			int(metrics["escape_guards"]),
			float(direction_p50["DOWN"]),
			float(direction_p50["RIGHT"]),
			float(direction_p50["UP"]),
			float(direction_p50["LEFT"]),
		]
	)
