extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SCORE_MANAGER_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
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
const CONTINUOUS_PENETRATION_LIMIT: float = 16.0
const DIVERGENCE_SPEED: float = 5000.0
const DIVERGENCE_MARGIN: float = 100.0
const DIAGNOSTIC_HISTORY_FRAMES: int = 10

var _diagnostic_history: Array[Dictionary] = []
var _diagnostic_triggered: bool = false
var _bounds_reported: bool = false


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
	assert_eq(int(metrics["escape_guards"]), 0, "120-turn escape guard activations")
	assert_true(
		int(metrics["wall_recoveries"]) <= 2,
		"120-turn wall recovery activations must be at most 2, got %d" % int(
			metrics["wall_recoveries"]
		)
	)
	if _is_independent_growth_measurement():
		assert_true(
			float(metrics["maximum_penetration"]) <= CONTINUOUS_PENETRATION_LIMIT,
			"120-turn wall penetration must be at most %.3fpx, got %.3fpx" % [
				CONTINUOUS_PENETRATION_LIMIT,
				float(metrics["maximum_penetration"]),
			]
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
	var wall_recovery_total: int = 0
	var timeout_correction_total: int = 0
	var ghost_timeout_total: int = 0
	var ghost_completed_total: int = 0
	var ghost_duration_total: float = 0.0
	var maximum_residual_speed: float = 0.0
	var maximum_penetration: float = 0.0
	var center_departures: int = 0
	var scores_by_seed: Array[int] = []
	var max_chains_by_seed: Array[int] = []
	var max_levels_by_seed: Array[int] = []

	for seed: int in SEEDS:
		var fixture: Dictionary = await _create_ready_fixture(seed)
		var board: Board = fixture["board"] as Board
		var manager: TurnManager = fixture["manager"] as TurnManager
		var score_manager: ScoreManager = fixture["score_manager"] as ScoreManager
		for turn_offset: int in range(TURNS_PER_SEED):
			var direction: Vector2i = DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()]
			manager.on_swipe(direction)
			var turn_metrics: Dictionary = await _wait_for_state_with_metrics(
				manager,
				board,
				TurnManager.State.WAITING_INPUT
			)
			maximum_penetration = maxf(
				maximum_penetration,
				float(turn_metrics["max_penetration"])
			)
			center_departures += int(turn_metrics["departures"])
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
		wall_recovery_total += board.wall_recovery_count
		timeout_correction_total += board.timeout_correction_count
		ghost_timeout_total += board.ghost_timeout_count
		ghost_completed_total += board.ghost_completed_count
		ghost_duration_total += board.ghost_total_duration
		scores_by_seed.append(score_manager.score)
		max_chains_by_seed.append(score_manager.max_chain)
		max_levels_by_seed.append(score_manager.max_level_reached)
		print(
			"Turn-time seed=%d score=%d max_chain=%d max_level=%d" % [
				seed,
				score_manager.score,
				score_manager.max_chain,
				score_manager.max_level_reached,
			]
		)
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
		"maximum_penetration": maximum_penetration,
		"departures": center_departures,
		"final_orb_average": float(final_orb_total) / float(SEEDS.size()),
		"escape_guards": escape_guard_total,
		"wall_recoveries": wall_recovery_total,
		"timeout_corrections": timeout_correction_total,
		"ghost_timeouts": ghost_timeout_total,
		"ghost_completed": ghost_completed_total,
		"ghost_average_duration": (
			ghost_duration_total / float(ghost_completed_total)
			if ghost_completed_total > 0
			else 0.0
		),
		"scores_by_seed": scores_by_seed,
		"max_chains_by_seed": max_chains_by_seed,
		"max_levels_by_seed": max_levels_by_seed,
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


func _is_independent_growth_measurement() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--growth-suite="):
			return true
	return false


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

	var score_manager: ScoreManager = SCORE_MANAGER_SCRIPT.new() as ScoreManager
	score_manager.name = "ScoreManager"
	score_manager.save_path = ""
	fixture_root.add_child(score_manager)
	score_manager.owner = fixture_root

	tree.root.add_child(fixture_root)
	await tree.process_frame
	resolver.reaction_applied.connect(score_manager.on_reaction)
	spawner.orb_spawned.connect(score_manager.on_orb_spawned)
	spawner.init_rng(seed)
	return {
		"root": fixture_root,
		"board": board,
		"spawner": spawner,
		"resolver": resolver,
		"manager": manager,
		"score_manager": score_manager,
	}


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
		var board: Board = manager.get_parent().get_node("Board") as Board
		assert_board_motion_bounds(board, "turn-time state wait")
	assert_eq(manager.state, target, "state wait timeout")


func _wait_for_state_with_metrics(
	manager: TurnManager,
	board: Board,
	target: TurnManager.State
) -> Dictionary:
	var metrics: Dictionary = {
		"max_penetration": 0.0,
		"departures": 0,
	}
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		await tree.physics_frame
		_record_diagnostic_frame(board)
		for orb: Orb in board.get_orbs():
			var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
			if center_extent > board.half_size() * 2.0 and not _bounds_reported:
				_bounds_reported = true
				assert_true(
					false,
					"turn-time center extent %.3f must be at most %.3f" % [
						center_extent,
						board.half_size() * 2.0,
					]
				)
			var speed: float = orb.linear_velocity.length()
			if speed > 10000.0 and not _bounds_reported:
				_bounds_reported = true
				assert_true(
					false,
					"turn-time speed %.3f must be at most 10000.000" % speed
				)
			var penetration: float = maxf(
				center_extent + orb.get_current_radius() - board.half_size(),
				0.0
			)
			metrics["max_penetration"] = maxf(
				float(metrics["max_penetration"]),
				penetration
			)
			if center_extent > board.half_size():
				metrics["departures"] = int(metrics["departures"]) + 1
		if manager.state == target:
			return metrics
	assert_eq(manager.state, target, "state wait timeout")
	return metrics


func _record_diagnostic_frame(board: Board) -> void:
	if not OS.get_cmdline_user_args().has("--growth-diagnose") or _diagnostic_triggered:
		return
	var physics_frame: int = Engine.get_physics_frames()
	var orbs: Array[Orb] = board.get_orbs()
	var states: Dictionary = {}
	var divergent_ids: Array[int] = []
	for orb: Orb in orbs:
		var orb_id: int = orb.get_instance_id()
		var overlaps: Array[int] = []
		for other: Orb in orbs:
			if other == orb:
				continue
			if orb.position.distance_to(other.position) < (
				orb.get_current_radius() + other.get_current_radius()
			):
				overlaps.append(other.get_instance_id())
		var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
		var speed: float = orb.linear_velocity.length()
		if speed > DIVERGENCE_SPEED or center_extent > board.half_size() + DIVERGENCE_MARGIN:
			divergent_ids.append(orb_id)
		states[orb_id] = {
			"id": orb_id,
			"level": orb.level,
			"generation": orb.generation,
			"current_radius": orb.get_current_radius(),
			"final_radius": orb.get_radius(),
			"position": orb.position,
			"velocity": orb.linear_velocity,
			"overlaps": overlaps,
			"guarded": orb._last_escape_guard_physics_frame == physics_frame,
			"age": maxi(physics_frame - orb._spawn_physics_frame, 0),
		}
	var snapshot: Dictionary = {
		"frame": physics_frame,
		"guards": board.escape_guard_count,
		"states": states,
	}
	if divergent_ids.is_empty():
		_diagnostic_history.append(snapshot)
		if _diagnostic_history.size() > DIAGNOSTIC_HISTORY_FRAMES:
			_diagnostic_history.pop_front()
		return
	_diagnostic_triggered = true
	_print_divergence_history(snapshot, divergent_ids)


func _print_divergence_history(current: Dictionary, divergent_ids: Array[int]) -> void:
	var relevant: Dictionary = {}
	for orb_id: int in divergent_ids:
		relevant[orb_id] = true
	var frames: Array[Dictionary] = _diagnostic_history.duplicate()
	frames.append(current)
	for frame_index: int in range(frames.size() - 1, -1, -1):
		var states: Dictionary = frames[frame_index]["states"] as Dictionary
		var ids_at_frame: Array = relevant.keys()
		for id_value: Variant in ids_at_frame:
			var orb_id: int = int(id_value)
			if not states.has(orb_id):
				continue
			var state: Dictionary = states[orb_id] as Dictionary
			for overlap_id: int in state["overlaps"] as Array[int]:
				relevant[overlap_id] = true
	print(
		"DIVERGENCE first_frame=%d ids=%s threshold_speed=%.1f threshold_extent_margin=%.1f" % [
			int(current["frame"]),
			str(divergent_ids),
			DIVERGENCE_SPEED,
			DIVERGENCE_MARGIN,
		]
	)
	for frame: Dictionary in frames:
		print(
			"DIVERGENCE_FRAME frame=%d guards=%d" % [
				int(frame["frame"]),
				int(frame["guards"]),
			]
		)
		var states: Dictionary = frame["states"] as Dictionary
		var relevant_ids: Array = relevant.keys()
		relevant_ids.sort()
		for id_value: Variant in relevant_ids:
			var orb_id: int = int(id_value)
			if not states.has(orb_id):
				continue
			var state: Dictionary = states[orb_id] as Dictionary
			print(
				"DIVERGENCE_ORB id=%d level=%d generation=%d current_radius=%.3f final_radius=%.3f position=%s velocity=%s overlaps=%s guarded=%s age=%d" % [
					orb_id,
					int(state["level"]),
					int(state["generation"]),
					float(state["current_radius"]),
					float(state["final_radius"]),
					str(state["position"]),
					str(state["velocity"]),
					str(state["overlaps"]),
					str(state["guarded"]),
					int(state["age"]),
				]
			)


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
		"Turn-time cap=%.3f turns=%d capped=%d capped_ratio=%.6f average=%.6f p50=%.6f p90=%.6f max=%.6f max_residual_speed=%.3f max_penetration=%.3f departures=%d final_orbs_avg=%.3f escape_guards=%d wall_recoveries=%d timeout_corrections=%d ghost_timeouts=%d ghost_completed=%d ghost_avg=%.6f direction_p50=[D %.6f R %.6f U %.6f L %.6f]" % [
			Config.data.max_settle_time,
			int(metrics["turns"]),
			int(metrics["capped_turns"]),
			float(metrics["capped_ratio"]),
			float(metrics["average"]),
			float(metrics["p50"]),
			float(metrics["p90"]),
			float(metrics["maximum"]),
			float(metrics["maximum_residual_speed"]),
			float(metrics["maximum_penetration"]),
			int(metrics["departures"]),
			float(metrics["final_orb_average"]),
			int(metrics["escape_guards"]),
			int(metrics["wall_recoveries"]),
			int(metrics["timeout_corrections"]),
			int(metrics["ghost_timeouts"]),
			int(metrics["ghost_completed"]),
			float(metrics["ghost_average_duration"]),
			float(direction_p50["DOWN"]),
			float(direction_p50["RIGHT"]),
			float(direction_p50["UP"]),
			float(direction_p50["LEFT"]),
		]
	)
	print(
		"Turn-time scores_by_seed=%s max_chains_by_seed=%s max_levels_by_seed=%s" % [
			str(metrics["scores_by_seed"]),
			str(metrics["max_chains_by_seed"]),
			str(metrics["max_levels_by_seed"]),
		]
	)
