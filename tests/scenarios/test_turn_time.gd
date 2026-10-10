extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SCORE_MANAGER_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const SEEDS: Array[int] = [101, 102, 103, 104, 105, 106]
const TURNS_PER_SEED: int = 20
const SPAWN_MEASUREMENT_TURNS_PER_SEED: int = 180
const OCCUPANCY_CHECKPOINTS: Array[int] = [30, 60, 90, 120, 150, 180]
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
const CONTINUOUS_PENETRATION_LIMIT: float = 34.0
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
	if _is_spawn_measurement():
		assert_true(
			int(metrics["turns"]) <= SEEDS.size() * SPAWN_MEASUREMENT_TURNS_PER_SEED,
			"measured spawn sweep turns do not exceed the planned total"
		)
	else:
		assert_true(
			int(metrics["turns"]) >= SEEDS.size()
			and int(metrics["turns"]) <= SEEDS.size() * TURNS_PER_SEED,
			"each seed measures until game over or twenty turns"
		)
	assert_true(
		float(metrics["maximum"]) <= Config.data.max_settle_time + tick_seconds,
		"all turns return within cap plus one physics tick"
	)
	if not _is_spawn_measurement():
		assert_eq(int(metrics["escape_guards"]), 0, "120-turn escape guard activations")
		assert_eq(int(metrics["divergences"]), 0, "120-turn divergent orb frames")
		assert_true(
			int(metrics["wall_recoveries"]) <= 2,
			"120-turn wall recovery activations must be at most 2, got %d" % int(
				metrics["wall_recoveries"]
			)
		)
	if _is_independent_measurement() and not _is_spawn_measurement():
		assert_true(
			float(metrics["maximum_penetration"]) <= CONTINUOUS_PENETRATION_LIMIT,
			"120-turn wall penetration must be at most %.3fpx, got %.3fpx" % [
				CONTINUOUS_PENETRATION_LIMIT,
				float(metrics["maximum_penetration"]),
			]
		)


func _measure_current_config() -> Dictionary:
	var turn_times: Array[float] = []
	var turn_end_occupancies: Array[float] = []
	var turn_end_orb_counts: Array[int] = []
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
	var maximum_penetration_ratio: float = 0.0
	var maximum_penetration_level: int = 0
	var center_departures: int = 0
	var divergence_count: int = 0
	var wall_recovery_timeout_lags: Array[int] = []
	var scores_by_seed: Array[int] = []
	var max_combos_by_seed: Array[int] = []
	var max_levels_by_seed: Array[int] = []
	var turns_by_seed: Array[int] = []
	var first_over_30_by_seed: Array[int] = []
	var first_over_50_by_seed: Array[int] = []
	var saturated_at_by_seed: Array[int] = []
	var checkpoint_samples: Dictionary = {}
	for checkpoint: int in OCCUPANCY_CHECKPOINTS:
		checkpoint_samples[checkpoint] = [] as Array[float]
	var turns_per_seed: int = (
		SPAWN_MEASUREMENT_TURNS_PER_SEED
		if _is_spawn_measurement()
		else TURNS_PER_SEED
	)

	for seed: int in SEEDS:
		var fixture: Dictionary = await _create_ready_fixture(seed)
		var board: Board = fixture["board"] as Board
		var manager: TurnManager = fixture["manager"] as TurnManager
		var score_manager: ScoreManager = fixture["score_manager"] as ScoreManager
		var first_over_30: int = -1
		var first_over_50: int = -1
		var saturated_at: int = -1
		var completed_turns: int = 0
		for turn_offset: int in range(turns_per_seed):
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
			if float(turn_metrics["max_penetration_ratio"]) > maximum_penetration_ratio:
				maximum_penetration_ratio = float(turn_metrics["max_penetration_ratio"])
				maximum_penetration_level = int(turn_metrics["max_penetration_level"])
			center_departures += int(turn_metrics["departures"])
			divergence_count += int(turn_metrics["divergences"])
			var turn_time: float = manager._settle_elapsed
			turn_times.append(turn_time)
			var direction_name: String = OrbTypes.dir_name(direction)
			var samples: Array[float] = direction_times[direction_name] as Array[float]
			samples.append(turn_time)
			maximum_residual_speed = maxf(
				maximum_residual_speed,
				_maximum_linear_speed(board)
			)
			var occupancy: float = _board_occupancy(board)
			turn_end_occupancies.append(occupancy)
			turn_end_orb_counts.append(board.get_orbs().size())
			completed_turns = turn_offset + 1
			if _is_spawn_measurement():
				if first_over_30 < 0 and occupancy > 0.30:
					first_over_30 = completed_turns
				if first_over_50 < 0 and occupancy > 0.50:
					first_over_50 = completed_turns
				if OCCUPANCY_CHECKPOINTS.has(completed_turns):
					var checkpoint_values: Array[float] = (
						checkpoint_samples[completed_turns] as Array[float]
					)
					checkpoint_values.append(occupancy)
				if occupancy > 0.70:
					saturated_at = completed_turns
					break
			if manager.state == TurnManager.State.GAME_OVER:
				break
		capped_turns += manager.capped_turn_count
		final_orb_total += board.get_orbs().size()
		escape_guard_total += board.escape_guard_count
		wall_recovery_total += board.wall_recovery_count
		timeout_correction_total += board.timeout_correction_count
		ghost_timeout_total += board.ghost_timeout_count
		ghost_completed_total += board.ghost_completed_count
		ghost_duration_total += board.ghost_total_duration
		wall_recovery_timeout_lags.append_array(
			board.wall_recovery_since_last_ghost_timeout_frames
		)
		scores_by_seed.append(score_manager.score)
		max_combos_by_seed.append(manager.max_combo)
		max_levels_by_seed.append(score_manager.max_level_reached)
		turns_by_seed.append(completed_turns)
		first_over_30_by_seed.append(first_over_30)
		first_over_50_by_seed.append(first_over_50)
		saturated_at_by_seed.append(saturated_at)
		print(
			"Turn-time seed=%d turns=%d score=%d max_combo=%d max_level=%d over30=%d over50=%d saturated=%d" % [
				seed,
				completed_turns,
				score_manager.score,
			manager.max_combo,
				score_manager.max_level_reached,
				first_over_30,
				first_over_50,
				saturated_at,
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
		"maximum_penetration_ratio": maximum_penetration_ratio,
		"maximum_penetration_level": maximum_penetration_level,
		"departures": center_departures,
		"divergences": divergence_count,
		"final_orb_average": float(final_orb_total) / float(SEEDS.size()),
		"turn_end_occupancy_average": _average(turn_end_occupancies),
		"turn_end_occupancy_maximum": _percentile(turn_end_occupancies, 1.0),
		"turn_end_orb_count_average": _average_int(turn_end_orb_counts),
		"turn_end_orb_count_maximum": _maximum_int(turn_end_orb_counts),
		"escape_guards": escape_guard_total,
		"wall_recoveries": wall_recovery_total,
		"wall_recovery_timeout_lags": wall_recovery_timeout_lags,
		"timeout_corrections": timeout_correction_total,
		"ghost_timeouts": ghost_timeout_total,
		"ghost_completed": ghost_completed_total,
		"ghost_average_duration": (
			ghost_duration_total / float(ghost_completed_total)
			if ghost_completed_total > 0
			else 0.0
		),
		"scores_by_seed": scores_by_seed,
		"max_combos_by_seed": max_combos_by_seed,
		"max_levels_by_seed": max_levels_by_seed,
		"turns_by_seed": turns_by_seed,
		"first_over_30_by_seed": first_over_30_by_seed,
		"first_over_50_by_seed": first_over_50_by_seed,
		"saturated_at_by_seed": saturated_at_by_seed,
		"checkpoint_occupancies": _checkpoint_averages(checkpoint_samples),
		"checkpoint_sample_counts": _checkpoint_sample_counts(checkpoint_samples),
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


func _board_occupancy(board: Board) -> float:
	var occupied_area: float = 0.0
	for orb: Orb in board.get_orbs():
		var radius: float = orb.get_radius()
		occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _is_independent_measurement() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if (
			argument.begins_with("--growth-suite=")
			or argument.begins_with("--mass-suite=")
			or argument.begins_with("--spawn-suite=")
		):
			return true
	return false


func _is_spawn_measurement() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--spawn-suite="):
			return true
	return false


func _checkpoint_averages(samples_by_turn: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for checkpoint: int in OCCUPANCY_CHECKPOINTS:
		var samples: Array[float] = samples_by_turn[checkpoint] as Array[float]
		result[checkpoint] = _average(samples) if not samples.is_empty() else -1.0
	return result


func _checkpoint_sample_counts(samples_by_turn: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for checkpoint: int in OCCUPANCY_CHECKPOINTS:
		var samples: Array[float] = samples_by_turn[checkpoint] as Array[float]
		result[checkpoint] = samples.size()
	return result


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
	manager.reaction_ready.connect(score_manager.on_reaction)
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
		"max_penetration_ratio": 0.0,
		"max_penetration_level": 0,
		"departures": 0,
		"divergences": 0,
	}
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		await tree.physics_frame
		_record_diagnostic_frame(board)
		for orb: Orb in board.get_orbs():
			var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
			if (
				not _is_spawn_measurement()
				and center_extent > board.half_size() * 2.0
				and not _bounds_reported
			):
				_bounds_reported = true
				assert_true(
					false,
					"turn-time center extent %.3f must be at most %.3f" % [
						center_extent,
						board.half_size() * 2.0,
					]
				)
			var speed: float = orb.linear_velocity.length()
			if not _is_spawn_measurement() and speed > 10000.0 and not _bounds_reported:
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
			var penetration_ratio: float = penetration / orb.get_radius()
			if penetration_ratio > float(metrics["max_penetration_ratio"]):
				metrics["max_penetration_ratio"] = penetration_ratio
				metrics["max_penetration_level"] = orb.level
			if center_extent > board.half_size():
				metrics["departures"] = int(metrics["departures"]) + 1
			if (
				speed > DIVERGENCE_SPEED
				or center_extent > board.half_size() + DIVERGENCE_MARGIN
			):
				metrics["divergences"] = int(metrics["divergences"]) + 1
		if manager.state == target or manager.state == TurnManager.State.GAME_OVER:
			return metrics
	assert_true(
		manager.state == target or manager.state == TurnManager.State.GAME_OVER,
		"state wait timeout"
	)
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


func _average_int(values: Array[int]) -> float:
	var total: int = 0
	for value: int in values:
		total += value
	return float(total) / float(values.size())


func _maximum_int(values: Array[int]) -> int:
	var maximum: int = 0
	for value: int in values:
		maximum = maxi(maximum, value)
	return maximum


func _percentile(values: Array[float], quantile: float) -> float:
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var index: int = ceili(quantile * float(sorted_values.size())) - 1
	return sorted_values[clampi(index, 0, sorted_values.size() - 1)]


func _print_metrics(metrics: Dictionary) -> void:
	var direction_p50: Dictionary = metrics["direction_p50"] as Dictionary
	var recovery_lags: Array[int] = metrics["wall_recovery_timeout_lags"] as Array[int]
	var recovery_lags_text: String = str(recovery_lags)
	if _is_spawn_measurement():
		recovery_lags_text = "%d samples, max=%d" % [
			recovery_lags.size(),
			_maximum_int(recovery_lags),
		]
	print(
		"Turn-time cap=%.3f turns=%d capped=%d capped_ratio=%.6f average=%.6f p50=%.6f p90=%.6f max=%.6f max_residual_speed=%.3f max_penetration=%.3f max_penetration_ratio=%.6f ratio_level=%d departures=%d divergences=%d final_orbs_avg=%.3f turn_end_occupancy_avg=%.6f turn_end_occupancy_max=%.6f turn_end_orbs_avg=%.3f turn_end_orbs_max=%d escape_guards=%d wall_recoveries=%d recovery_timeout_lags=%s timeout_corrections=%d ghost_timeouts=%d ghost_completed=%d ghost_avg=%.6f direction_p50=[D %.6f R %.6f U %.6f L %.6f]" % [
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
			float(metrics["maximum_penetration_ratio"]),
			int(metrics["maximum_penetration_level"]),
			int(metrics["departures"]),
			int(metrics["divergences"]),
			float(metrics["final_orb_average"]),
			float(metrics["turn_end_occupancy_average"]),
			float(metrics["turn_end_occupancy_maximum"]),
			float(metrics["turn_end_orb_count_average"]),
			int(metrics["turn_end_orb_count_maximum"]),
			int(metrics["escape_guards"]),
			int(metrics["wall_recoveries"]),
			recovery_lags_text,
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
	if _is_spawn_measurement():
		print(
			"Spawn-measurement case=%s count=%d ramp=%d max=%d active_colors=%d turns_by_seed=%s checkpoint_occupancies=%s checkpoint_samples=%s over30=%s over50=%s saturated=%s" % [
				_spawn_case_name(),
				Config.data.spawn_count_per_turn,
				Config.data.spawn_count_ramp_turns,
				Config.data.spawn_count_max,
				_active_color_count(),
				str(metrics["turns_by_seed"]),
				str(metrics["checkpoint_occupancies"]),
				str(metrics["checkpoint_sample_counts"]),
				str(metrics["first_over_30_by_seed"]),
				str(metrics["first_over_50_by_seed"]),
				str(metrics["saturated_at_by_seed"]),
			]
		)
	print(
		"Turn-time scores_by_seed=%s max_combos_by_seed=%s max_levels_by_seed=%s" % [
			str(metrics["scores_by_seed"]),
			str(metrics["max_combos_by_seed"]),
			str(metrics["max_levels_by_seed"]),
		]
	)


func _spawn_case_name() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--spawn-case="):
			return argument.trim_prefix("--spawn-case=").to_upper()
	return ""


func _active_color_count() -> int:
	var count: int = 0
	for weight: float in Config.data.spawn_color_weights:
		if weight > 0.0:
			count += 1
	return count
