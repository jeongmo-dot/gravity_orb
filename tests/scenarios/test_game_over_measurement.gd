extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SCORE_MANAGER_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const SEEDS: Array[int] = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112]
const MAX_TURNS: int = 400
const WAIT_TIMEOUT_SECONDS: float = 3.0
const DIVERGENCE_SPEED: float = 5000.0
const DIVERGENCE_MARGIN: float = 100.0
const REPORT_PATH_PATTERN: String = "res://.godot/game_over_measurement_%s.json"
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


func test_game_over_distribution_warning_accuracy_and_density_metrics() -> void:
	var game_over_turns: Array[int] = []
	var game_over_occupancies: Array[float] = []
	var game_over_orb_counts: Array[int] = []
	var early_game_overs: Array[Dictionary] = []
	var warned_swipes: int = 0
	var warned_game_overs: int = 0
	var unwarned_swipes: int = 0
	var unwarned_game_overs: int = 0
	var aborted_seeds: Array[Dictionary] = []
	var seed_rows: Array[Dictionary] = []
	var bins: Dictionary = _empty_metric_bins()
	var high_density_events: Array[Dictionary] = []
	var jam_diagnostics: Dictionary = _empty_jam_diagnostics()
	var all_turn_seconds: Array[float] = []

	for seed: int in SEEDS:
		var fixture: Dictionary = await _create_ready_fixture(seed)
		var board: Board = fixture["board"] as Board
		var manager: TurnManager = fixture["manager"] as TurnManager
		var score_manager: ScoreManager = fixture["score_manager"] as ScoreManager
		var reaction_counts: Dictionary = fixture["reaction_counts"] as Dictionary
		var completed_turns: int = 0
		var game_over_occupancy: float = -1.0
		var game_over_orbs: int = -1
		var warned_on_game_over: bool = false
		var aborted: bool = false
		var seed_turn_seconds: Array[float] = []
		for turn_offset: int in range(MAX_TURNS):
			var direction: Vector2i = DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()]
			var same_direction: bool = direction == manager.gravity
			var warned: bool = manager.blocked_directions.has(direction)
			if warned:
				warned_swipes += 1
			else:
				unwarned_swipes += 1
			var guards_before: int = board.escape_guard_count
			var recoveries_before: int = board.wall_recovery_count
			var recovery_event_index: int = board.wall_recovery_events.size()
			var merges_before: int = int(reaction_counts["merges"])
			var annihilations_before: int = int(reaction_counts["annihilations"])
			var orb_snapshot: Dictionary = _snapshot_orbs(board)

			manager.on_swipe(direction)
			var frame_metrics: Dictionary = await _wait_for_turn_end(
				manager,
				board,
				direction,
				seed,
				turn_offset + 1
			)
			completed_turns = turn_offset + 1
			var turn_seconds: float = (
				float(frame_metrics["frames"]) / float(Engine.physics_ticks_per_second)
			)
			seed_turn_seconds.append(turn_seconds)
			all_turn_seconds.append(turn_seconds)
			var occupancy: float = _board_occupancy(board)
			var bin_name: String = _occupancy_bin(occupancy)
			var values: Dictionary = bins[bin_name] as Dictionary
			values["turns"] = int(values["turns"]) + 1
			values["turn_seconds"].append(turn_seconds)
			values["escape_guards"] = (
				int(values["escape_guards"]) + board.escape_guard_count - guards_before
			)
			values["wall_recoveries"] = (
				int(values["wall_recoveries"]) + board.wall_recovery_count - recoveries_before
			)
			values["departures"] = (
				int(values["departures"]) + int(frame_metrics["departures"])
			)
			values["divergences"] = (
				int(values["divergences"]) + int(frame_metrics["divergences"])
			)
			values["max_penetration"] = maxf(
				float(values["max_penetration"]),
				float(frame_metrics["max_penetration"])
			)
			values["merges"] = (
				int(values["merges"]) + int(reaction_counts["merges"]) - merges_before
			)
			values["annihilations"] = (
				int(values["annihilations"])
				+ int(reaction_counts["annihilations"])
				- annihilations_before
			)
			if not same_direction and not bool(frame_metrics["aborted"]):
				_record_movement(
					values,
					orb_snapshot,
					board,
					direction,
					occupancy,
					jam_diagnostics
				)

			if occupancy >= 0.40:
				for event_index: int in range(recovery_event_index, board.wall_recovery_events.size()):
					var recovery_event: Dictionary = board.wall_recovery_events[event_index]
					high_density_events.append(
						_wall_recovery_diagnostic(
							recovery_event,
							board,
							direction,
							seed,
							completed_turns,
							occupancy
						)
					)
				for divergence_event: Dictionary in frame_metrics["divergence_events"]:
					divergence_event["occupancy"] = occupancy
					high_density_events.append(divergence_event)

			if bool(frame_metrics["aborted"]):
				aborted = true
				aborted_seeds.append(
					{
						"seed": seed,
						"turn": completed_turns,
						"occupancy": occupancy,
						"orbs": board.get_orbs().size(),
						"direction": OrbTypes.dir_name(direction),
						"reason": frame_metrics["abort_reason"],
					}
				)
				break

			if manager.state != TurnManager.State.GAME_OVER:
				continue
			game_over_occupancy = occupancy
			game_over_orbs = board.get_orbs().size()
			warned_on_game_over = warned
			if warned:
				warned_game_overs += 1
			else:
				unwarned_game_overs += 1
			if occupancy < 0.25:
				early_game_overs.append(
					{
						"seed": seed,
						"turn": completed_turns,
						"occupancy": occupancy,
						"direction": OrbTypes.dir_name(direction),
						"spawned_levels": manager.game_over_details["spawned_levels"],
						"overlap_counts": manager.game_over_details["overlap_counts"],
					}
				)
			break

		game_over_turns.append(
			completed_turns if manager.state == TurnManager.State.GAME_OVER else -1
		)
		game_over_occupancies.append(game_over_occupancy)
		game_over_orb_counts.append(game_over_orbs)
		seed_rows.append(
			{
				"seed": seed,
				"game_over_turn": game_over_turns.back(),
				"occupancy": game_over_occupancy,
				"orbs": game_over_orbs,
				"direction": (
					OrbTypes.dir_name(manager.gravity)
					if manager.state == TurnManager.State.GAME_OVER
					else "NONE"
				),
				"warned": warned_on_game_over,
				"aborted": aborted,
				"completed_turns": completed_turns,
				"average_turn_seconds": _average(seed_turn_seconds),
				"turn_p50_seconds": _percentile(seed_turn_seconds, 0.50),
				"score": score_manager.score,
				"max_combo": manager.max_combo,
			}
		)
		print(
			"Game-over seed=%d turn=%d occupancy=%.6f orbs=%d direction=%s warned=%s aborted=%s completed_turns=%d turn_avg=%.6f score=%d max_combo=%d" % [
				seed,
				game_over_turns.back(),
				game_over_occupancy,
				game_over_orbs,
				(
					OrbTypes.dir_name(manager.gravity)
					if manager.state == TurnManager.State.GAME_OVER
					else "NONE"
				),
				str(warned_on_game_over),
				str(aborted),
				completed_turns,
				_average(seed_turn_seconds),
				score_manager.score,
				manager.max_combo,
			]
		)
		await _cleanup_fixture(fixture)

	var finalized_bins: Dictionary = _finalize_bins(bins)
	var report: Dictionary = {
		"case": _physics_case_name(),
		"config": {
			"gravity_strength": Config.data.gravity_strength,
			"orb_friction": Config.data.orb_friction,
			"wall_friction": Config.data.wall_friction,
			"orb_bounce": Config.data.orb_bounce,
			"fixed_fps_argument": 240,
			"physics_ticks_per_second": Engine.physics_ticks_per_second,
		},
		"seed_rows": seed_rows,
		"game_over_turns": game_over_turns,
		"game_over_turn_p50": _int_percentile(_positive_ints(game_over_turns), 0.50),
		"game_over_occupancies": game_over_occupancies,
		"game_over_orb_counts": game_over_orb_counts,
		"early_game_overs": early_game_overs,
		"aborted_seeds": aborted_seeds,
		"aborted_count": aborted_seeds.size(),
		"warned_swipes": warned_swipes,
		"warned_game_overs": warned_game_overs,
		"warned_game_over_ratio": _safe_ratio(warned_game_overs, warned_swipes),
		"unwarned_swipes": unwarned_swipes,
		"unwarned_game_overs": unwarned_game_overs,
		"turn_average_seconds": _average(all_turn_seconds),
		"turn_p50_seconds": _percentile(all_turn_seconds, 0.50),
		"bins": finalized_bins,
		"high_density_event_count": high_density_events.size(),
		"high_density_top_causes": _cause_summary(high_density_events),
		"jam_diagnostics": _finalize_jam_diagnostics(jam_diagnostics),
	}
	print(
		"Game-over summary case=%s turns=%s occupancies=%s aborted=%d turn_p50=%.6f bins=%s top_causes=%s jam=%s" % [
			report["case"],
			str(game_over_turns),
			str(game_over_occupancies),
			aborted_seeds.size(),
			float(report["turn_p50_seconds"]),
			str(finalized_bins),
			str(report["high_density_top_causes"]),
			str(report["jam_diagnostics"]),
		]
	)
	_write_report(report)
	assert_eq(game_over_turns.size(), SEEDS.size(), "all seeds measured")


func _create_ready_fixture(seed: int) -> Dictionary:
	InputRouter.set_locked(false)
	var fixture_root: Node = Node.new()
	fixture_root.name = "GameOverMeasurementFixture"
	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	board.diagnostic_warnings_enabled = false
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
	var reaction_counts: Dictionary = {"merges": 0, "annihilations": 0}
	resolver.reaction_applied.connect(
		func(reaction: Dictionary) -> void:
			var type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
			if type == ReactionRules.Type.MERGE or type == ReactionRules.Type.MAX_CLEAR:
				reaction_counts["merges"] = int(reaction_counts["merges"]) + 1
			elif type == ReactionRules.Type.ANNIHILATE:
				reaction_counts["annihilations"] = int(reaction_counts["annihilations"]) + 1
	)
	manager.reaction_ready.connect(score_manager.on_reaction)
	spawner.orb_spawned.connect(score_manager.on_orb_spawned)
	spawner.init_rng(seed)
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	return {
		"root": fixture_root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"manager": manager,
		"score_manager": score_manager,
		"reaction_counts": reaction_counts,
	}


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
	assert_eq(manager.state, target, "measurement initial state timeout")


func _wait_for_turn_end(
	manager: TurnManager,
	board: Board,
	direction: Vector2i,
	seed: int,
	turn: int
) -> Dictionary:
	var metrics: Dictionary = {
		"departures": 0,
		"divergences": 0,
		"divergence_events": [],
		"max_penetration": 0.0,
		"aborted": false,
		"abort_reason": "",
		"frames": 0,
	}
	var divergent_ids: Dictionary = {}
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for frame: int in range(max_frames):
		await tree.physics_frame
		metrics["frames"] = frame + 1
		for orb: Orb in board.get_orbs():
			var finite: bool = orb.position.is_finite() and orb.linear_velocity.is_finite()
			var center_extent: float = (
				maxf(absf(orb.position.x), absf(orb.position.y)) if finite else INF
			)
			if finite:
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
			var divergent: bool = (
				not finite
				or orb.linear_velocity.length() > DIVERGENCE_SPEED
				or center_extent > board.half_size() + DIVERGENCE_MARGIN
			)
			var orb_id: int = orb.get_instance_id()
			if divergent and not divergent_ids.has(orb_id):
				divergent_ids[orb_id] = true
				metrics["divergences"] = int(metrics["divergences"]) + 1
				metrics["divergence_events"].append(
					_orb_diagnostic(
						"divergence",
						orb,
						board,
						direction,
						seed,
						turn
					)
				)
		if not divergent_ids.is_empty():
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


func _freeze_orbs(board: Board) -> void:
	for orb: Orb in board.get_orbs():
		orb.set_physics_process(false)
		orb.set_process(false)
		orb.collision_layer = 0
		orb.collision_mask = 0
		orb.constant_force = Vector2.ZERO
		if orb.position.is_finite() and orb.linear_velocity.is_finite():
			orb.linear_velocity = Vector2.ZERO
			orb.angular_velocity = 0.0


func _snapshot_orbs(board: Board) -> Dictionary:
	var snapshot: Dictionary = {}
	for orb: Orb in board.get_orbs():
		snapshot[orb.get_instance_id()] = {
			"position": orb.position,
			"radius": orb.get_radius(),
			"level": orb.level,
		}
	return snapshot


func _record_movement(
	values: Dictionary,
	start_snapshot: Dictionary,
	board: Board,
	direction: Vector2i,
	occupancy: float,
	jam_diagnostics: Dictionary
) -> void:
	var gravity_axis: Vector2 = Vector2(direction)
	for orb: Orb in board.get_orbs():
		var orb_id: int = orb.get_instance_id()
		if not start_snapshot.has(orb_id):
			continue
		var start: Dictionary = start_snapshot[orb_id] as Dictionary
		var movement: float = (orb.position - (start["position"] as Vector2)).dot(gravity_axis)
		var radius: float = float(start["radius"])
		var level_key: String = "L%d" % int(start["level"])
		values["movement_sum"] = float(values["movement_sum"]) + movement
		values["movement_count"] = int(values["movement_count"]) + 1
		var level_stats: Dictionary = values["movement_by_level"] as Dictionary
		if not level_stats.has(level_key):
			level_stats[level_key] = {"sum": 0.0, "count": 0, "barely": 0}
		var level_values: Dictionary = level_stats[level_key] as Dictionary
		level_values["sum"] = float(level_values["sum"]) + movement
		level_values["count"] = int(level_values["count"]) + 1
		if movement >= radius:
			continue
		values["barely_moved"] = int(values["barely_moved"]) + 1
		level_values["barely"] = int(level_values["barely"]) + 1
		if occupancy >= 0.40:
			_record_jam_sample(jam_diagnostics, orb, board, direction, movement)


func _record_jam_sample(
	jam: Dictionary,
	orb: Orb,
	board: Board,
	direction: Vector2i,
	movement: float
) -> void:
	jam["samples"] = int(jam["samples"]) + 1
	jam["movement_sum"] = float(jam["movement_sum"]) + movement
	_increment(jam["by_level"] as Dictionary, "L%d" % orb.level)
	if _is_wall_contact(orb.position, orb.get_current_radius(), board):
		jam["wall_contact_samples"] = int(jam["wall_contact_samples"]) + 1
	var pile_depth: int = _pile_depth(orb.position, orb.get_current_radius(), board, direction)
	jam["pile_depth_sum"] = int(jam["pile_depth_sum"]) + pile_depth
	jam["pile_depth_max"] = maxi(int(jam["pile_depth_max"]), pile_depth)
	for neighbor_level: int in _neighbor_levels(
		orb.position,
		orb.get_current_radius(),
		orb.get_instance_id(),
		board
	):
		_increment(jam["neighbor_levels"] as Dictionary, "L%d" % neighbor_level)


func _wall_recovery_diagnostic(
	event: Dictionary,
	_board: Board,
	direction: Vector2i,
	seed: int,
	turn: int,
	occupancy: float
) -> Dictionary:
	var orb_id: int = int(event["orb_id"])
	return {
		"kind": "wall_recovery",
		"seed": seed,
		"turn": turn,
		"occupancy": occupancy,
		"direction": OrbTypes.dir_name(direction),
		"orb_id": orb_id,
		"level": int(event["level"]),
		"last_event": str(event["last_event"]),
		"frames_since_last_event": int(event["frames_since_last_event"]),
		"pile_depth": int(event["pile_depth"]),
		"neighbor_levels": event["neighbor_levels"],
		"wall_contact": bool(event["wall_contact"]),
		"penetration": float(event["depth"]),
		"ghost": bool(event["ghost"]),
	}


func _orb_diagnostic(
	kind: String,
	orb: Orb,
	board: Board,
	direction: Vector2i,
	seed: int,
	turn: int
) -> Dictionary:
	var physics_frame: int = Engine.get_physics_frames()
	return {
		"kind": kind,
		"seed": seed,
		"turn": turn,
		"direction": OrbTypes.dir_name(direction),
		"orb_id": orb.get_instance_id(),
		"level": orb.level,
		"last_event": orb.diagnostic_last_event,
		"frames_since_last_event": maxi(
			physics_frame - orb.diagnostic_last_event_physics_frame,
			0
		),
		"pile_depth": _pile_depth(
			orb.position,
			orb.get_current_radius(),
			board,
			direction
		),
		"neighbor_levels": _neighbor_levels(
			orb.position,
			orb.get_current_radius(),
			orb.get_instance_id(),
			board
		),
		"wall_contact": _is_wall_contact(
			orb.position,
			orb.get_current_radius(),
			board
		),
		"speed": orb.linear_velocity.length(),
		"position": [orb.position.x, orb.position.y],
	}


func _neighbor_levels(
	position: Vector2,
	radius: float,
	orb_id: int,
	board: Board
) -> Array[int]:
	var levels: Array[int] = []
	for other: Orb in board.get_orbs():
		if other.get_instance_id() == orb_id:
			continue
		var contact_distance: float = radius + other.get_current_radius() + Config.data.ghost_exit_overlap
		if position.distance_squared_to(other.position) <= contact_distance * contact_distance:
			levels.append(other.level)
	return levels


func _pile_depth(
	position: Vector2,
	radius: float,
	board: Board,
	direction: Vector2i
) -> int:
	var perpendicular: Vector2 = Vector2(OrbTypes.perpendicular(direction))
	var count: int = 0
	for other: Orb in board.get_orbs():
		var cross_distance: float = absf((other.position - position).dot(perpendicular))
		if cross_distance <= radius + other.get_current_radius():
			count += 1
	return count


func _is_wall_contact(position: Vector2, radius: float, board: Board) -> bool:
	var wall_gap: float = minf(
		board.half_size() - absf(position.x) - radius,
		board.half_size() - absf(position.y) - radius
	)
	return wall_gap <= Config.data.floor_contact_tolerance


func _board_occupancy(board: Board) -> float:
	var occupied_area: float = 0.0
	for orb: Orb in board.get_orbs():
		var radius: float = orb.get_radius()
		occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _occupancy_bin(occupancy: float) -> String:
	if occupancy < 0.20:
		return "0-20"
	if occupancy < 0.40:
		return "20-40"
	if occupancy < 0.60:
		return "40-60"
	return "60+"


func _empty_metric_bins() -> Dictionary:
	var result: Dictionary = {}
	for bin_name: String in BIN_NAMES:
		result[bin_name] = {
			"turns": 0,
			"turn_seconds": [],
			"escape_guards": 0,
			"wall_recoveries": 0,
			"departures": 0,
			"divergences": 0,
			"max_penetration": 0.0,
			"merges": 0,
			"annihilations": 0,
			"movement_sum": 0.0,
			"movement_count": 0,
			"barely_moved": 0,
			"movement_by_level": {},
		}
	return result


func _finalize_bins(bins: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for bin_name: String in BIN_NAMES:
		var source: Dictionary = bins[bin_name] as Dictionary
		var values: Dictionary = source.duplicate(true)
		var turns: int = int(source["turns"])
		var movement_count: int = int(source["movement_count"])
		var turn_seconds: Array[float] = []
		for value: Variant in source["turn_seconds"]:
			turn_seconds.append(float(value))
		values.erase("turn_seconds")
		values["turn_average_seconds"] = _average(turn_seconds)
		values["turn_p50_seconds"] = _percentile(turn_seconds, 0.50)
		values["merges_per_turn"] = _safe_ratio(int(source["merges"]), turns)
		values["annihilations_per_turn"] = _safe_ratio(
			int(source["annihilations"]),
			turns
		)
		values["average_movement"] = (
			float(source["movement_sum"]) / float(movement_count)
			if movement_count > 0
			else 0.0
		)
		values["barely_moved_ratio"] = _safe_ratio(
			int(source["barely_moved"]),
			movement_count
		)
		values["movement_by_level"] = _finalize_level_stats(
			source["movement_by_level"] as Dictionary
		)
		result[bin_name] = values
	return result


func _finalize_level_stats(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for level_key: String in source:
		var values: Dictionary = source[level_key] as Dictionary
		var count: int = int(values["count"])
		result[level_key] = {
			"count": count,
			"average_movement": (
				float(values["sum"]) / float(count) if count > 0 else 0.0
			),
			"barely_moved": int(values["barely"]),
			"barely_moved_ratio": _safe_ratio(int(values["barely"]), count),
		}
	return result


func _empty_jam_diagnostics() -> Dictionary:
	return {
		"samples": 0,
		"movement_sum": 0.0,
		"by_level": {},
		"neighbor_levels": {},
		"wall_contact_samples": 0,
		"pile_depth_sum": 0,
		"pile_depth_max": 0,
	}


func _finalize_jam_diagnostics(source: Dictionary) -> Dictionary:
	var samples: int = int(source["samples"])
	return {
		"samples": samples,
		"average_movement": (
			float(source["movement_sum"]) / float(samples) if samples > 0 else 0.0
		),
		"by_level": source["by_level"],
		"neighbor_levels": source["neighbor_levels"],
		"wall_contact_samples": int(source["wall_contact_samples"]),
		"wall_contact_ratio": _safe_ratio(
			int(source["wall_contact_samples"]),
			samples
		),
		"average_pile_depth": (
			float(source["pile_depth_sum"]) / float(samples) if samples > 0 else 0.0
		),
		"pile_depth_max": int(source["pile_depth_max"]),
	}


func _cause_summary(events: Array[Dictionary]) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for event: Dictionary in events:
		var cause: String = str(event.get("last_event", "unknown"))
		var level: int = int(event["level"])
		var cause_key: String = "%s|L%d" % [cause, level]
		if not grouped.has(cause_key):
			grouped[cause_key] = {
				"cause": cause,
				"level": level,
				"count": 0,
				"wall_recoveries": 0,
				"divergences": 0,
				"frames_sum": 0,
				"pile_depth_sum": 0,
				"levels": {},
			}
		var values: Dictionary = grouped[cause_key] as Dictionary
		values["count"] = int(values["count"]) + 1
		if str(event["kind"]) == "wall_recovery":
			values["wall_recoveries"] = int(values["wall_recoveries"]) + 1
		else:
			values["divergences"] = int(values["divergences"]) + 1
		values["frames_sum"] = int(values["frames_sum"]) + int(event["frames_since_last_event"])
		values["pile_depth_sum"] = int(values["pile_depth_sum"]) + int(event["pile_depth"])
		_increment(values["levels"] as Dictionary, "L%d" % int(event["level"]))
	var result: Array[Dictionary] = []
	for cause_key: String in grouped:
		var source: Dictionary = grouped[cause_key] as Dictionary
		var count: int = int(source["count"])
		result.append(
			{
				"cause": str(source["cause"]),
				"level": int(source["level"]),
				"count": count,
				"wall_recoveries": int(source["wall_recoveries"]),
				"divergences": int(source["divergences"]),
				"average_frames_since_event": (
					float(source["frames_sum"]) / float(count) if count > 0 else 0.0
				),
				"average_pile_depth": (
					float(source["pile_depth_sum"]) / float(count) if count > 0 else 0.0
				),
				"levels": source["levels"],
			}
		)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["count"]) > int(b["count"])
	)
	return result.slice(0, mini(3, result.size()))


func _increment(counts: Dictionary, key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1


func _average(values: Array[float]) -> float:
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


func _positive_ints(values: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for value: int in values:
		if value >= 0:
			result.append(value)
	return result


func _int_percentile(values: Array[int], ratio: float) -> int:
	if values.is_empty():
		return -1
	var sorted: Array[int] = values.duplicate()
	sorted.sort()
	var index: int = clampi(roundi(float(sorted.size() - 1) * ratio), 0, sorted.size() - 1)
	return sorted[index]


func _safe_ratio(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0


func _physics_case_name() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--physics-case="):
			return argument.trim_prefix("--physics-case=").validate_filename()
	return "G%d_F%s_B%s" % [
		roundi(Config.data.gravity_strength),
		str(Config.data.orb_friction).replace(".", "p"),
		str(Config.data.orb_bounce).replace(".", "p"),
	]


func _write_report(report: Dictionary) -> void:
	var report_path: String = REPORT_PATH_PATTERN % _physics_case_name()
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	assert_true(file != null, "measurement report file opens")
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("Measurement report: %s" % report_path)


func _cleanup_fixture(fixture: Dictionary) -> void:
	InputRouter.set_locked(false)
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame
