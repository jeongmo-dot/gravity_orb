extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const SCORE_MANAGER_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const TICKS: Array[int] = [60, 120, 240]
const SEEDS: Array[int] = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112]
const MAX_TURNS: int = 400
const DETERMINISM_TURNS: int = 120
const WAIT_TIMEOUT_SECONDS: float = 3.5
const DIVERGENCE_SPEED: float = 5000.0
const DIVERGENCE_MARGIN: float = 100.0
const REPORT_PATH: String = "res://artifacts/jolt3d_measurement.json"
const BIN_NAMES: Array[String] = ["0-20", "20-40", "40-60", "60+"]
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

var _original_ticks: int = 0
var _had_runner_error: bool = false
var _ticks: Array[int] = []
var _seeds: Array[int] = []
var _max_turns: int = MAX_TURNS
var _determinism_turns: int = DETERMINISM_TURNS
var _report_path: String = REPORT_PATH
var _continuous_cd_enabled: bool = true
var _allow_sleep: bool = false
var _contact_reporting_enabled: bool = true
var _progressive_growth_enabled: bool = false
var _reaction_ghost_enabled: bool = false
var _record_seed_hashes: bool = false
var _scan_pairs_each_frame: bool = false
var _skip_determinism: bool = false
var _turn_shock_events: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_ticks = Engine.physics_ticks_per_second
	_ticks.append_array(TICKS)
	_seeds.append_array(SEEDS)
	_apply_arguments()
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"pixels_per_meter": Orb3D.PIXELS_PER_METER,
		"gravity_px_s2": Config.data.gravity_strength,
		"gravity_level_scale": Config.data.gravity_level_scale,
		"mass_exponent": Config.data.mass_exponent,
		"shock_impulse": Config.data.shock_impulse,
		"shock_radius_factor": Config.data.shock_radius_factor,
		"shock_level_scale": Config.data.shock_level_scale,
		"shock_jackpot_scale": Config.data.shock_jackpot_scale,
		"level_radii_px": Array(Config.data.level_radii),
		"corrections": {
			"reaction_ghost": _reaction_ghost_enabled,
			"growth": _progressive_growth_enabled,
			"timeout_correction": false,
			"proactive_wall_recovery": false,
			"escape_guard": false,
			"entrance_waiting_rule": true,
		},
		"physics_profile": {
			"contact_reporting": _contact_reporting_enabled,
			"continuous_cd": _continuous_cd_enabled,
			"allow_sleep": _allow_sleep,
		},
		"ticks": [],
	}
	for ticks: int in _ticks:
		Engine.physics_ticks_per_second = ticks
		var tick_report: Dictionary = await _run_tick_suite(ticks)
		report["ticks"].append(tick_report)

	Engine.physics_ticks_per_second = 120
	report["feel_metrics"] = await _measure_feel_metrics()
	report["determinism"] = (
		{"skipped": true}
		if _skip_determinism
		else await _run_determinism_check(101)
	)
	Engine.physics_ticks_per_second = _original_ticks
	_write_report(report)
	print("JOLT3D_REPORT_PATH %s" % _report_path)
	get_tree().quit(1 if _had_runner_error else 0)


func _run_tick_suite(ticks: int) -> Dictionary:
	var bins: Dictionary = _empty_bins()
	var seed_rows: Array[Dictionary] = []
	var physics_ms: Array[float] = []
	var game_over_turns: Array[float] = []
	var game_over_occupancies: Array[float] = []
	var game_over_count: int = 0
	var aborted_count: int = 0
	var ghost_completed_count: int = 0
	var ghost_timeout_count: int = 0
	var ghost_duration_sum: float = 0.0
	var rearrangement_values: Array[float] = []
	var shock_displacements: Dictionary = _empty_shock_displacements()
	for seed: int in _seeds:
		var result: Dictionary = await _run_seed(
			seed,
			_max_turns,
			bins,
			physics_ms,
			_record_seed_hashes,
			rearrangement_values,
			shock_displacements
		)
		seed_rows.append(result)
		ghost_completed_count += int(result["ghost_completed_count"])
		ghost_timeout_count += int(result["ghost_timeout_count"])
		ghost_duration_sum += float(result["ghost_duration_sum"])
		if bool(result["aborted"]):
			aborted_count += 1
		if bool(result["game_over"]):
			game_over_count += 1
			game_over_turns.append(float(result["completed_turns"]))
			game_over_occupancies.append(float(result["final_occupancy_percent"]))
	var report: Dictionary = {
		"physics_ticks_per_second": ticks,
		"seeds": seed_rows,
		"game_over_count": game_over_count,
		"aborted_count": aborted_count,
		"ghost_completed_count": ghost_completed_count,
		"ghost_timeout_count": ghost_timeout_count,
		"ghost_average_duration": _safe_ratio(ghost_duration_sum, ghost_completed_count),
		"game_over_turn_p50": _percentile(game_over_turns, 0.5),
		"game_over_occupancy_mean_percent": _mean(game_over_occupancies),
		"physics_ms_mean": _mean(physics_ms),
		"physics_ms_p50": _percentile(physics_ms, 0.5),
		"physics_ms_p95": _percentile(physics_ms, 0.95),
		"bins": _finalize_bins(bins),
		"rearrangement_60_plus_mean": _mean(rearrangement_values),
		"rearrangement_60_plus_samples": rearrangement_values.size(),
		"shock_displacement_by_target_level": _finalize_shock_displacements(
			shock_displacements
		),
	}
	print(
		"JOLT3D_TICK ticks=%d game_over=%d/%d aborted=%d turn_p50=%.1f occupancy_mean=%.4f physics_ms_mean=%.5f p95=%.5f" % [
			ticks,
			game_over_count,
			_seeds.size(),
			aborted_count,
			float(report["game_over_turn_p50"]),
			float(report["game_over_occupancy_mean_percent"]),
			float(report["physics_ms_mean"]),
			float(report["physics_ms_p95"]),
		]
	)
	return report


func _run_seed(
	seed: int,
	max_turns: int,
	bins: Dictionary,
	physics_ms: Array[float],
	record_hashes: bool,
	rearrangement_values: Array[float],
	shock_displacements: Dictionary
) -> Dictionary:
	var fixture: Dictionary = await _create_fixture(seed)
	var fixture_root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var manager: TurnManager = fixture["manager"] as TurnManager
	var score_manager: ScoreManager = fixture["score_manager"] as ScoreManager
	var completed_turns: int = 0
	var aborted: bool = false
	var abort_reason: String = ""
	var hashes: Array[String] = []
	var engine_count_samples: Array[Dictionary] = []
	var turn_performance_samples: Array[Dictionary] = []
	var seed_max_pair_end: Dictionary = {"penetration_px": 0.0, "category": "none"}
	var seed_max_pair_end_turn: int = 0
	var seed_max_wall: float = 0.0
	for turn_offset: int in range(max_turns):
		_turn_shock_events.clear()
		var direction: Vector2i = DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()]
		var same_direction: bool = direction == manager.gravity
		var before: Dictionary = _snapshot_orbs(board)
		var start_occupancy: float = _snapshot_occupancy(before)
		manager.on_swipe(direction)
		var frame_metrics: Dictionary = await _wait_for_turn_end(manager, board, physics_ms)
		if start_occupancy >= 0.60:
			var rearrangement: float = _kendall_rearrangement(before, board, direction)
			if rearrangement >= 0.0:
				rearrangement_values.append(rearrangement)
		_record_shock_displacements(shock_displacements, _turn_shock_events)
		completed_turns = turn_offset + 1
		turn_performance_samples.append({
			"turn": completed_turns,
			"active_orbs": board.get_orbs().size(),
			"physics_frames": int(frame_metrics["physics_ms_samples"]),
			"physics_ms_mean": _safe_ratio(
				float(frame_metrics["physics_ms_sum"]),
				int(frame_metrics["physics_ms_samples"])
			),
			"physics_ms_max": float(frame_metrics["physics_ms_max"]),
		})
		var occupancy: float = _board_occupancy(board)
		var bin_name: String = _occupancy_bin(occupancy)
		var bin_values: Dictionary = bins[bin_name] as Dictionary
		bin_values["turns"] = int(bin_values["turns"]) + 1
		bin_values["departures"] = int(bin_values["departures"]) + int(frame_metrics["departures"])
		bin_values["divergences"] = int(bin_values["divergences"]) + int(frame_metrics["divergences"])
		bin_values["max_wall_penetration_px"] = maxf(
			float(bin_values["max_wall_penetration_px"]),
			float(frame_metrics["max_wall_penetration_px"])
		)
		var turn_end_pair: Dictionary = _maximum_pair_penetration_details(board)
		if (
			float(turn_end_pair["penetration_px"])
			> float(bin_values["max_pair_penetration_px"])
		):
			bin_values["max_pair_penetration_px"] = turn_end_pair["penetration_px"]
			bin_values["max_pair_penetration_details"] = turn_end_pair
			bin_values["max_pair_penetration_seed"] = seed
			bin_values["max_pair_penetration_turn"] = completed_turns
		if float(turn_end_pair["penetration_px"]) > float(seed_max_pair_end["penetration_px"]):
			seed_max_pair_end = turn_end_pair
			seed_max_pair_end_turn = completed_turns
		seed_max_wall = maxf(seed_max_wall, float(frame_metrics["max_wall_penetration_px"]))
		bin_values["physics_ms_sum"] = (
			float(bin_values["physics_ms_sum"])
			+ float(frame_metrics["physics_ms_sum"])
		)
		bin_values["physics_ms_samples"] = (
			int(bin_values["physics_ms_samples"])
			+ int(frame_metrics["physics_ms_samples"])
		)
		bin_values["physics_ms_max"] = maxf(
			float(bin_values["physics_ms_max"]),
			float(frame_metrics["physics_ms_max"])
		)
		if (
			float(frame_metrics["max_pair_penetration_any_frame_px"])
			> float(bin_values["max_pair_penetration_any_frame_px"])
		):
			bin_values["max_pair_penetration_any_frame_px"] = frame_metrics[
				"max_pair_penetration_any_frame_px"
			]
			bin_values["max_pair_penetration_any_frame_details"] = frame_metrics[
				"max_pair_penetration_any_frame_details"
			]
		if not same_direction:
			_record_movement(bin_values, before, board, direction)
		if record_hashes:
			hashes.append(_state_hash(board))
		if completed_turns % 10 == 0:
			engine_count_samples.append(_engine_counts(completed_turns, board))
		if bool(frame_metrics["aborted"]):
			aborted = true
			abort_reason = str(frame_metrics["abort_reason"])
			break
		if manager.state == TurnManager.State.GAME_OVER:
			break
	var result: Dictionary = {
		"seed": seed,
		"completed_turns": completed_turns,
		"game_over": manager.state == TurnManager.State.GAME_OVER,
		"final_occupancy_percent": _board_occupancy(board) * 100.0,
		"final_orb_count": board.get_orbs().size(),
		"score": score_manager.score,
		"max_combo": score_manager.max_combo,
		"max_level_reached": score_manager.max_level_reached,
		"aborted": aborted,
		"abort_reason": abort_reason,
		"hashes": hashes,
		"final_state": _state_rows(board),
		"engine_count_samples": engine_count_samples,
		"final_engine_counts": _engine_counts(completed_turns, board),
		"turn_performance_samples": turn_performance_samples,
		"max_turn_end_pair": seed_max_pair_end,
		"max_turn_end_pair_turn": seed_max_pair_end_turn,
		"max_wall_penetration_px": seed_max_wall,
		"ghost_completed_count": board.ghost_completed_count,
		"ghost_timeout_count": board.ghost_timeout_count,
		"ghost_duration_sum": board.ghost_total_duration,
	}
	fixture_root.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	InputRouter.set_locked(false)
	return result


func _create_fixture(seed: int) -> Dictionary:
	InputRouter.set_locked(false)
	var fixture_root: Node3D = Node3D.new()
	fixture_root.name = "JoltMeasurementFixture"
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	board.orb_contact_reporting_enabled = _contact_reporting_enabled
	board.orb_continuous_cd_enabled = _continuous_cd_enabled
	board.orb_allow_sleep = _allow_sleep
	board.orb_progressive_growth_enabled = _progressive_growth_enabled
	board.reaction_ghost_enabled = _reaction_ghost_enabled
	fixture_root.add_child(board)
	board.owner = fixture_root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
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
	get_tree().root.add_child(fixture_root)
	await get_tree().process_frame
	resolver.reaction_applied.connect(score_manager.on_reaction)
	resolver.reaction_applied.connect(_record_shock_event)
	spawner.orb_spawned.connect(score_manager.on_orb_spawned)
	spawner.init_rng(seed)
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	var ready: bool = await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	if not ready:
		_had_runner_error = true
		push_error("Jolt fixture failed to reach WAITING_INPUT for seed %d" % seed)
	return {
		"root": fixture_root,
		"board": board,
		"manager": manager,
		"score_manager": score_manager,
	}


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> bool:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return true
		await get_tree().physics_frame
	return manager.state == target


func _measure_feel_metrics() -> Dictionary:
	return {
		"fall_time_seconds": {
			"L1": await _measure_fall_time(1),
			"L7": await _measure_fall_time(7),
		},
		"rolling_impact": {
			"L7_into_L1": await _measure_rolling_impact(7, 1),
			"L1_into_L7": await _measure_rolling_impact(1, 7),
		},
	}


func _measure_fall_time(level: int) -> float:
	var board: Board3D = await _create_feel_board()
	var radius: float = Config.data.radius_for_level(level)
	var start_y: float = -board.half_size() + radius + Config.data.spawn_margin
	var floor_y: float = board.half_size() - radius
	var orb: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		level,
		Vector2(0.0, start_y)
	)
	var elapsed_frames: int = 0
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * 3.0)
	for _frame: int in range(max_frames):
		await get_tree().physics_frame
		elapsed_frames += 1
		if orb.position.y >= floor_y - Config.data.floor_contact_tolerance:
			break
	board.queue_free()
	await get_tree().process_frame
	return float(elapsed_frames) / float(Engine.physics_ticks_per_second)


func _measure_rolling_impact(incoming_level: int, target_level: int) -> Dictionary:
	var board: Board3D = await _create_feel_board()
	var target_radius: float = Config.data.radius_for_level(target_level)
	var incoming_radius: float = Config.data.radius_for_level(incoming_level)
	var target_start: Vector2 = Vector2(
		160.0,
		board.half_size() - target_radius - Config.data.spawn_margin
	)
	var target: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		target_level,
		target_start
	)
	var settle_frames: int = ceili(float(Engine.physics_ticks_per_second) * 0.5)
	for _frame: int in range(settle_frames):
		await get_tree().physics_frame
	target_start = target.position
	board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		incoming_level,
		Vector2(
			-320.0,
			board.half_size() - incoming_radius - Config.data.spawn_margin
		),
		Vector2(900.0, 0.0)
	)
	var maximum_displacement: float = 0.0
	var observe_frames: int = ceili(float(Engine.physics_ticks_per_second) * 1.5)
	for _frame: int in range(observe_frames):
		await get_tree().physics_frame
		maximum_displacement = maxf(
			maximum_displacement,
			absf(target.position.x - target_start.x)
		)
	var result: Dictionary = {
		"target_displacement_px": absf(target.position.x - target_start.x),
		"target_max_displacement_px": maximum_displacement,
	}
	board.queue_free()
	await get_tree().process_frame
	return result


func _create_feel_board() -> Board3D:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.orb_contact_reporting_enabled = false
	board.orb_continuous_cd_enabled = _continuous_cd_enabled
	board.orb_allow_sleep = _allow_sleep
	board.orb_progressive_growth_enabled = false
	get_tree().root.add_child(board)
	await get_tree().process_frame
	board.set_gravity(Vector2i.DOWN)
	return board


func _wait_for_turn_end(
	manager: TurnManager,
	board: Board3D,
	physics_ms: Array[float]
) -> Dictionary:
	var metrics: Dictionary = {
		"departures": 0,
		"divergences": 0,
		"max_wall_penetration_px": 0.0,
		"max_pair_penetration_any_frame_px": 0.0,
		"max_pair_penetration_any_frame_details": {},
		"physics_ms_sum": 0.0,
		"physics_ms_samples": 0,
		"physics_ms_max": 0.0,
		"aborted": false,
		"abort_reason": "",
	}
	var departure_ids: Dictionary = {}
	var divergence_ids: Dictionary = {}
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		var step_started_usec: int = Time.get_ticks_usec()
		await get_tree().physics_frame
		var step_wall_ms: float = float(Time.get_ticks_usec() - step_started_usec) / 1000.0
		var monitor_ms: float = (
			float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		)
		physics_ms.append(maxf(step_wall_ms, monitor_ms))
		var measured_ms: float = maxf(step_wall_ms, monitor_ms)
		metrics["physics_ms_sum"] = float(metrics["physics_ms_sum"]) + measured_ms
		metrics["physics_ms_samples"] = int(metrics["physics_ms_samples"]) + 1
		metrics["physics_ms_max"] = maxf(float(metrics["physics_ms_max"]), measured_ms)
		for orb: Orb3D in board.get_orbs():
			var finite: bool = orb.position.is_finite() and orb.linear_velocity.is_finite()
			var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y)) if finite else INF
			if finite:
				metrics["max_wall_penetration_px"] = maxf(
					float(metrics["max_wall_penetration_px"]),
					maxf(center_extent + orb.get_radius() - board.half_size(), 0.0)
				)
			var orb_id: int = orb.get_instance_id()
			if finite and center_extent - orb.get_radius() > board.half_size():
				departure_ids[orb_id] = true
			var divergent: bool = (
				not finite
				or orb.linear_velocity.length() > DIVERGENCE_SPEED
				or center_extent > board.half_size() + DIVERGENCE_MARGIN
			)
			if divergent:
				divergence_ids[orb_id] = true
		metrics["departures"] = departure_ids.size()
		metrics["divergences"] = divergence_ids.size()
		if _scan_pairs_each_frame:
			var pair_details: Dictionary = _maximum_pair_penetration_details(board)
			if (
				float(pair_details["penetration_px"])
				> float(metrics["max_pair_penetration_any_frame_px"])
			):
				metrics["max_pair_penetration_any_frame_px"] = pair_details["penetration_px"]
				metrics["max_pair_penetration_any_frame_details"] = pair_details
		if not divergence_ids.is_empty():
			metrics["aborted"] = true
			metrics["abort_reason"] = "divergence"
			_freeze_orbs(board)
			return metrics
		if (
			manager.state == TurnManager.State.WAITING_INPUT
			or manager.state == TurnManager.State.GAME_OVER
		):
			return metrics
	metrics["aborted"] = true
	metrics["abort_reason"] = "turn_timeout"
	_freeze_orbs(board)
	return metrics


func _freeze_orbs(board: Board3D) -> void:
	for orb: Orb3D in board.get_orbs():
		orb.disable_physics()


func _snapshot_orbs(board: Board3D) -> Dictionary:
	var snapshot: Dictionary = {}
	for orb: Orb3D in board.get_orbs():
		snapshot[orb.get_instance_id()] = {
			"position": orb.position,
			"radius": orb.get_radius(),
			"level": orb.level,
		}
	return snapshot


func _snapshot_occupancy(snapshot: Dictionary) -> float:
	var occupied_area: float = 0.0
	for item_value: Variant in snapshot.values():
		var item: Dictionary = item_value as Dictionary
		var radius: float = float(item["radius"])
		occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _kendall_rearrangement(
	before: Dictionary,
	board: Board3D,
	direction: Vector2i
) -> float:
	var end_positions: Dictionary = {}
	for orb: Orb3D in board.get_orbs():
		end_positions[orb.get_instance_id()] = orb.position
	var start_items: Array[Dictionary] = []
	var end_items: Array[Dictionary] = []
	var axis: Vector2 = Vector2(direction)
	for id_value: Variant in before:
		var orb_id: int = int(id_value)
		if not end_positions.has(orb_id):
			continue
		var start_item: Dictionary = before[orb_id] as Dictionary
		var start_position: Vector2 = start_item["position"] as Vector2
		var end_position: Vector2 = end_positions[orb_id] as Vector2
		start_items.append({
			"id": orb_id,
			"projection": start_position.dot(axis),
		})
		end_items.append({
			"id": orb_id,
			"projection": end_position.dot(axis),
		})
	if start_items.size() < 2:
		return -1.0
	start_items.sort_custom(_projection_item_less)
	end_items.sort_custom(_projection_item_less)
	var end_ranks: Dictionary = {}
	for index: int in range(end_items.size()):
		end_ranks[int(end_items[index]["id"])] = index
	var inversions: int = 0
	for first_index: int in range(start_items.size()):
		var first_rank: int = int(end_ranks[int(start_items[first_index]["id"])])
		for second_index: int in range(first_index + 1, start_items.size()):
			var second_rank: int = int(end_ranks[int(start_items[second_index]["id"])])
			if first_rank > second_rank:
				inversions += 1
	var pair_count: int = start_items.size() * (start_items.size() - 1) / 2
	return float(inversions) / float(pair_count)


func _projection_item_less(first: Dictionary, second: Dictionary) -> bool:
	var first_projection: float = float(first["projection"])
	var second_projection: float = float(second["projection"])
	if not is_equal_approx(first_projection, second_projection):
		return first_projection < second_projection
	return int(first["id"]) < int(second["id"])


func _record_shock_event(reaction: Dictionary) -> void:
	var reaction_type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
	if (
		reaction_type != ReactionRules.Type.MERGE
		and reaction_type != ReactionRules.Type.MAX_CLEAR
	):
		return
	var targets: Array[Dictionary] = reaction["shock_targets"] as Array[Dictionary]
	_turn_shock_events.append({"targets": targets})


func _empty_shock_displacements() -> Dictionary:
	var result: Dictionary = {}
	for level_key: String in ["L1", "L4", "L7"]:
		result[level_key] = {
			"target_displacement_sum_px": 0.0,
			"target_samples": 0,
			"reaction_mean_sum_px": 0.0,
			"reaction_samples": 0,
		}
	return result


func _record_shock_displacements(
	totals: Dictionary,
	events: Array[Dictionary]
) -> void:
	for event: Dictionary in events:
		var event_sums: Dictionary = {"L1": 0.0, "L4": 0.0, "L7": 0.0}
		var event_counts: Dictionary = {"L1": 0, "L4": 0, "L7": 0}
		var targets: Array[Dictionary] = event["targets"] as Array[Dictionary]
		for target_info: Dictionary in targets:
			var level_key: String = "L%d" % int(target_info["level"])
			if not event_sums.has(level_key):
				continue
			var orb: Variant = target_info["orb"]
			if not is_instance_valid(orb) or orb.consumed:
				continue
			var start_position: Vector2 = target_info["position"] as Vector2
			var displacement: float = orb.position.distance_to(start_position)
			event_sums[level_key] = float(event_sums[level_key]) + displacement
			event_counts[level_key] = int(event_counts[level_key]) + 1
		for level_key: String in event_sums:
			var count: int = int(event_counts[level_key])
			if count == 0:
				continue
			var values: Dictionary = totals[level_key] as Dictionary
			values["target_displacement_sum_px"] = (
				float(values["target_displacement_sum_px"])
				+ float(event_sums[level_key])
			)
			values["target_samples"] = int(values["target_samples"]) + count
			values["reaction_mean_sum_px"] = (
				float(values["reaction_mean_sum_px"])
				+ float(event_sums[level_key]) / float(count)
			)
			values["reaction_samples"] = int(values["reaction_samples"]) + 1


func _finalize_shock_displacements(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for level_key: String in source:
		var values: Dictionary = source[level_key] as Dictionary
		result[level_key] = {
			"mean_target_displacement_px": _safe_ratio(
				float(values["target_displacement_sum_px"]),
				int(values["target_samples"])
			),
			"mean_surrounding_displacement_per_reaction_px": _safe_ratio(
				float(values["reaction_mean_sum_px"]),
				int(values["reaction_samples"])
			),
			"target_samples": values["target_samples"],
			"reaction_samples": values["reaction_samples"],
		}
	return result


func _record_movement(
	values: Dictionary,
	before: Dictionary,
	board: Board3D,
	direction: Vector2i
) -> void:
	var gravity_axis: Vector2 = Vector2(direction)
	for orb: Orb3D in board.get_orbs():
		var orb_id: int = orb.get_instance_id()
		if not before.has(orb_id):
			continue
		var item: Dictionary = before[orb_id] as Dictionary
		var start_position: Vector2 = item["position"] as Vector2
		var movement: float = (orb.position - start_position).dot(gravity_axis)
		var radius: float = float(item["radius"])
		values["movement_sum_px"] = float(values["movement_sum_px"]) + movement
		values["movement_samples"] = int(values["movement_samples"]) + 1
		if movement < radius:
			values["below_radius_samples"] = int(values["below_radius_samples"]) + 1
		var level_key: String = str(int(item["level"]))
		var level_values: Dictionary = values["levels"] as Dictionary
		if not level_values.has(level_key):
			level_values[level_key] = {"sum_px": 0.0, "samples": 0, "below_radius": 0}
		var per_level: Dictionary = level_values[level_key] as Dictionary
		per_level["sum_px"] = float(per_level["sum_px"]) + movement
		per_level["samples"] = int(per_level["samples"]) + 1
		if movement < radius:
			per_level["below_radius"] = int(per_level["below_radius"]) + 1


func _maximum_pair_penetration_details(board: Board3D) -> Dictionary:
	var maximum: float = 0.0
	var maximum_first: Orb3D = null
	var maximum_second: Orb3D = null
	var orbs: Array[Orb3D] = board.get_orbs()
	for first_index: int in range(orbs.size()):
		var first: Orb3D = orbs[first_index]
		if first.is_waiting_at_entrance:
			continue
		for second_index: int in range(first_index + 1, orbs.size()):
			var second: Orb3D = orbs[second_index]
			if second.is_waiting_at_entrance:
				continue
			var penetration: float = (
				first.get_current_radius()
				+ second.get_current_radius()
				- first.position.distance_to(second.position)
			)
			if penetration > maximum:
				maximum = penetration
				maximum_first = first
				maximum_second = second
	var details: Dictionary = {
		"penetration_px": maxf(maximum, 0.0),
		"category": "none",
	}
	if maximum_first == null or maximum_second == null:
		return details
	var current_frame: int = Engine.get_physics_frames()
	var immediate_frames: int = maxi(ceili(float(Engine.physics_ticks_per_second) * 0.1), 2)
	var first_age: int = maxi(
		current_frame - maximum_first.diagnostic_last_event_physics_frame,
		0
	)
	var second_age: int = maxi(
		current_frame - maximum_second.diagnostic_last_event_physics_frame,
		0
	)
	var category: String = "normal_pile"
	for orb: Orb3D in [maximum_first, maximum_second]:
		var age: int = maxi(current_frame - orb.diagnostic_last_event_physics_frame, 0)
		if age > immediate_frames:
			continue
		if orb.diagnostic_last_event == "merge_result":
			category = "merge_immediate"
			break
		if orb.diagnostic_last_event == "spawn":
			category = "spawn_immediate"
	details["category"] = category
	details["first_event"] = maximum_first.diagnostic_last_event
	details["second_event"] = maximum_second.diagnostic_last_event
	details["first_event_age_frames"] = first_age
	details["second_event_age_frames"] = second_age
	details["first_level"] = maximum_first.level
	details["second_level"] = maximum_second.level
	return details


func _board_occupancy(board: Board3D) -> float:
	var occupied_area: float = 0.0
	for orb: Orb3D in board.get_orbs():
		var radius: float = orb.get_radius()
		occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _occupancy_bin(occupancy: float) -> String:
	if occupancy < 0.2:
		return "0-20"
	if occupancy < 0.4:
		return "20-40"
	if occupancy < 0.6:
		return "40-60"
	return "60+"


func _empty_bins() -> Dictionary:
	var bins: Dictionary = {}
	for bin_name: String in BIN_NAMES:
		bins[bin_name] = {
			"turns": 0,
			"departures": 0,
			"divergences": 0,
			"max_wall_penetration_px": 0.0,
			"max_pair_penetration_px": 0.0,
			"max_pair_penetration_details": {},
			"max_pair_penetration_seed": 0,
			"max_pair_penetration_turn": 0,
			"max_pair_penetration_any_frame_px": 0.0,
			"max_pair_penetration_any_frame_details": {},
			"physics_ms_sum": 0.0,
			"physics_ms_samples": 0,
			"physics_ms_max": 0.0,
			"movement_sum_px": 0.0,
			"movement_samples": 0,
			"below_radius_samples": 0,
			"levels": {},
		}
	return bins


func _finalize_bins(bins: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for bin_name: String in BIN_NAMES:
		var values: Dictionary = bins[bin_name] as Dictionary
		var samples: int = int(values["movement_samples"])
		var levels: Dictionary = {}
		for level_key: String in (values["levels"] as Dictionary):
			var per_level: Dictionary = values["levels"][level_key] as Dictionary
			var level_samples: int = int(per_level["samples"])
			levels[level_key] = {
				"mean_movement_px": _safe_ratio(float(per_level["sum_px"]), level_samples),
				"below_radius_percent": _safe_ratio(float(per_level["below_radius"]) * 100.0, level_samples),
				"samples": level_samples,
			}
		result[bin_name] = {
			"turns": values["turns"],
			"departures": values["departures"],
			"divergences": values["divergences"],
			"max_wall_penetration_px": values["max_wall_penetration_px"],
			"max_pair_penetration_px": values["max_pair_penetration_px"],
			"max_pair_penetration_details": values["max_pair_penetration_details"],
			"max_pair_penetration_seed": values["max_pair_penetration_seed"],
			"max_pair_penetration_turn": values["max_pair_penetration_turn"],
			"max_pair_penetration_any_frame_px": values["max_pair_penetration_any_frame_px"],
			"max_pair_penetration_any_frame_details": values[
				"max_pair_penetration_any_frame_details"
			],
			"physics_ms_mean": _safe_ratio(
				float(values["physics_ms_sum"]),
				int(values["physics_ms_samples"])
			),
			"physics_ms_max": values["physics_ms_max"],
			"physics_ms_samples": values["physics_ms_samples"],
			"mean_movement_px": _safe_ratio(float(values["movement_sum_px"]), samples),
			"below_radius_percent": _safe_ratio(float(values["below_radius_samples"]) * 100.0, samples),
			"movement_samples": samples,
			"levels": levels,
		}
	return result


func _run_determinism_check(seed: int) -> Dictionary:
	var unused_bins_a: Dictionary = _empty_bins()
	var unused_bins_b: Dictionary = _empty_bins()
	var unused_physics_a: Array[float] = []
	var unused_physics_b: Array[float] = []
	var unused_rearrangement_a: Array[float] = []
	var unused_rearrangement_b: Array[float] = []
	var first: Dictionary = await _run_seed(
		seed,
		_determinism_turns,
		unused_bins_a,
		unused_physics_a,
		true,
		unused_rearrangement_a,
		_empty_shock_displacements()
	)
	var second: Dictionary = await _run_seed(
		seed,
		_determinism_turns,
		unused_bins_b,
		unused_physics_b,
		true,
		unused_rearrangement_b,
		_empty_shock_displacements()
	)
	var first_hashes: Array[String] = first["hashes"] as Array[String]
	var second_hashes: Array[String] = second["hashes"] as Array[String]
	var compared_turns: int = mini(first_hashes.size(), second_hashes.size())
	var first_mismatch_turn: int = -1
	for index: int in range(compared_turns):
		if first_hashes[index] != second_hashes[index]:
			first_mismatch_turn = index + 1
			break
	return {
		"seed": seed,
		"requested_turns": _determinism_turns,
		"compared_turns": compared_turns,
		"identical": first_mismatch_turn < 0 and first_hashes.size() == second_hashes.size(),
		"first_mismatch_turn": first_mismatch_turn,
		"run_a_game_over": first["game_over"],
		"run_b_game_over": second["game_over"],
	}


func _state_hash(board: Board3D) -> String:
	var states: Array[String] = []
	for orb: Orb3D in board.get_orbs():
		states.append(
			"%d:%d:%.3f:%.3f:%.3f:%.3f:%.3f:%d" % [
				orb.color,
				orb.level,
				orb.position.x,
				orb.position.y,
				orb.linear_velocity.x,
				orb.linear_velocity.y,
				orb.angular_velocity,
				1 if orb.is_waiting_at_entrance else 0,
			]
		)
	states.sort()
	return "|".join(states).sha256_text()


func _state_rows(board: Board3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for orb: Orb3D in board.get_orbs():
		rows.append({
			"color": orb.color,
			"level": orb.level,
			"position_x": orb.position.x,
			"position_y": orb.position.y,
			"velocity_x": orb.linear_velocity.x,
			"velocity_y": orb.linear_velocity.y,
			"angular_velocity": orb.angular_velocity,
			"waiting": orb.is_waiting_at_entrance,
		})
	return rows


func _engine_counts(turn: int, board: Board3D) -> Dictionary:
	var orbs_node: Node = board.get_node("Orbs")
	return {
		"turn": turn,
		"active_orbs": board.get_orbs().size(),
		"orb_child_nodes": orbs_node.get_child_count(),
		"object_count": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"node_count": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_node_count": int(
			Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
		),
		"resource_count": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
	}


func _safe_ratio(numerator: float, denominator: int) -> float:
	return 0.0 if denominator == 0 else numerator / float(denominator)


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = clampi(roundi(float(sorted.size() - 1) * ratio), 0, sorted.size() - 1)
	return sorted[index]


func _write_report(report: Dictionary) -> void:
	var absolute_directory: String = ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(absolute_directory)
	var file: FileAccess = FileAccess.open(_report_path, FileAccess.WRITE)
	if file == null:
		_had_runner_error = true
		push_error("Could not write Jolt report to %s" % _report_path)
		return
	file.store_string(JSON.stringify(report, "\t"))


func _apply_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--jolt-smoke":
			_ticks = [240]
			_seeds = [101]
			_max_turns = 3
			_determinism_turns = 3
			_report_path = "res://artifacts/jolt3d_smoke.json"
		elif argument.begins_with("--jolt-ticks="):
			_ticks = _parse_int_list(argument.trim_prefix("--jolt-ticks="))
		elif argument.begins_with("--jolt-seeds="):
			_seeds = _parse_int_list(argument.trim_prefix("--jolt-seeds="))
		elif argument.begins_with("--jolt-max-turns="):
			_max_turns = maxi(argument.trim_prefix("--jolt-max-turns=").to_int(), 1)
		elif argument.begins_with("--jolt-determinism-turns="):
			_determinism_turns = maxi(
				argument.trim_prefix("--jolt-determinism-turns=").to_int(),
				1
			)
		elif argument.begins_with("--jolt-output="):
			_report_path = argument.trim_prefix("--jolt-output=")
		elif argument.begins_with("--mass-exponent="):
			Config.data.mass_exponent = argument.trim_prefix("--mass-exponent=").to_float()
		elif argument.begins_with("--gravity-level-scale="):
			Config.data.gravity_level_scale = argument.trim_prefix(
				"--gravity-level-scale="
			).to_float()
		elif argument.begins_with("--shock-impulse="):
			Config.data.shock_impulse = argument.trim_prefix("--shock-impulse=").to_float()
		elif argument.begins_with("--shock-radius-factor="):
			Config.data.shock_radius_factor = argument.trim_prefix(
				"--shock-radius-factor="
			).to_float()
		elif argument.begins_with("--shock-level-scale="):
			Config.data.shock_level_scale = argument.trim_prefix(
				"--shock-level-scale="
			).to_float()
		elif argument.begins_with("--shock-jackpot-scale="):
			Config.data.shock_jackpot_scale = argument.trim_prefix(
				"--shock-jackpot-scale="
			).to_float()
		elif argument == "--jolt-no-ccd":
			_continuous_cd_enabled = false
		elif argument == "--jolt-allow-sleep":
			_allow_sleep = true
		elif argument == "--jolt-no-contact-reporting":
			_contact_reporting_enabled = false
		elif argument == "--jolt-growth":
			_progressive_growth_enabled = true
		elif argument == "--jolt-no-reaction-ghost":
			_reaction_ghost_enabled = false
		elif argument == "--jolt-reaction-ghost":
			_reaction_ghost_enabled = true
		elif argument == "--jolt-record-hashes":
			_record_seed_hashes = true
		elif argument == "--jolt-frame-pair-scan":
			_scan_pairs_each_frame = true
		elif argument == "--jolt-no-determinism":
			_skip_determinism = true


func _parse_int_list(csv: String) -> Array[int]:
	var result: Array[int] = []
	for raw_value: String in csv.split(",", false):
		result.append(raw_value.strip_edges().to_int())
	return result
