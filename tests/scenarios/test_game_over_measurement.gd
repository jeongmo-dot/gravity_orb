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
const REPORT_PATH: String = "res://.godot/game_over_measurement_result.json"
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
	var safety_bins: Dictionary = _empty_metric_bins()
	var reaction_bins: Dictionary = _empty_metric_bins()

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
		for turn_offset: int in range(MAX_TURNS):
			var direction: Vector2i = DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()]
			var warned: bool = manager.blocked_directions.has(direction)
			if warned:
				warned_swipes += 1
			else:
				unwarned_swipes += 1
			var guards_before: int = board.escape_guard_count
			var recoveries_before: int = board.wall_recovery_count
			var merges_before: int = int(reaction_counts["merges"])
			var annihilations_before: int = int(reaction_counts["annihilations"])

			manager.on_swipe(direction)
			var frame_metrics: Dictionary = await _wait_for_turn_end(manager, board)
			completed_turns = turn_offset + 1
			var occupancy: float = _board_occupancy(board)
			var bin_name: String = _occupancy_bin(occupancy)
			var safety: Dictionary = safety_bins[bin_name] as Dictionary
			var reactions: Dictionary = reaction_bins[bin_name] as Dictionary
			safety["turns"] = int(safety["turns"]) + 1
			safety["escape_guards"] = (
				int(safety["escape_guards"])
				+ board.escape_guard_count
				- guards_before
			)
			safety["wall_recoveries"] = (
				int(safety["wall_recoveries"])
				+ board.wall_recovery_count
				- recoveries_before
			)
			safety["departures"] = int(safety["departures"]) + int(frame_metrics["departures"])
			safety["divergences"] = int(safety["divergences"]) + int(frame_metrics["divergences"])
			reactions["turns"] = int(reactions["turns"]) + 1
			reactions["merges"] = (
				int(reactions["merges"])
				+ int(reaction_counts["merges"])
				- merges_before
			)
			reactions["annihilations"] = (
				int(reactions["annihilations"])
				+ int(reaction_counts["annihilations"])
				- annihilations_before
			)
			if bool(frame_metrics["aborted"]):
				aborted = true
				aborted_seeds.append(
					{
						"seed": seed,
						"turn": completed_turns,
						"occupancy": occupancy,
						"orbs": board.get_orbs().size(),
						"direction": OrbTypes.dir_name(direction),
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
				"score": score_manager.score,
				"max_chain": score_manager.max_chain,
			}
		)
		print(
			"Game-over seed=%d turn=%d occupancy=%.6f orbs=%d direction=%s warned=%s aborted=%s completed_turns=%d score=%d max_chain=%d" % [
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
				score_manager.score,
				score_manager.max_chain,
			]
		)
		await _cleanup_fixture(fixture)

	print(
		"Game-over summary turns=%s occupancies=%s orb_counts=%s early_under_25=%d early_details=%s aborted=%s warned_swipes=%d warned_game_overs=%d warned_game_over_ratio=%.6f unwarned_swipes=%d unwarned_game_overs=%d safety=%s reactions=%s" % [
			str(game_over_turns),
			str(game_over_occupancies),
			str(game_over_orb_counts),
			early_game_overs.size(),
			str(early_game_overs),
			str(aborted_seeds),
			warned_swipes,
			warned_game_overs,
			_safe_ratio(warned_game_overs, warned_swipes),
			unwarned_swipes,
			unwarned_game_overs,
			str(safety_bins),
			str(_reaction_rates(reaction_bins)),
		]
	)
	_write_report(
		{
			"seed_rows": seed_rows,
			"game_over_turns": game_over_turns,
			"game_over_occupancies": game_over_occupancies,
			"game_over_orb_counts": game_over_orb_counts,
			"early_game_overs": early_game_overs,
			"aborted_seeds": aborted_seeds,
			"warned_swipes": warned_swipes,
			"warned_game_overs": warned_game_overs,
			"unwarned_swipes": unwarned_swipes,
			"unwarned_game_overs": unwarned_game_overs,
			"safety": safety_bins,
			"reactions": _reaction_rates(reaction_bins),
		}
	)
	assert_eq(game_over_turns.size(), SEEDS.size(), "all seeds measured")


func _create_ready_fixture(seed: int) -> Dictionary:
	InputRouter.set_locked(false)
	var fixture_root: Node = Node.new()
	fixture_root.name = "GameOverMeasurementFixture"
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
	var reaction_counts: Dictionary = {"merges": 0, "annihilations": 0}
	resolver.reaction_applied.connect(
		func(reaction: Dictionary) -> void:
			var type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
			if type == ReactionRules.Type.MERGE or type == ReactionRules.Type.MAX_CLEAR:
				reaction_counts["merges"] = int(reaction_counts["merges"]) + 1
			elif type == ReactionRules.Type.ANNIHILATE:
				reaction_counts["annihilations"] = int(reaction_counts["annihilations"]) + 1
	)
	resolver.reaction_applied.connect(score_manager.on_reaction)
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


func _wait_for_turn_end(manager: TurnManager, board: Board) -> Dictionary:
	var metrics: Dictionary = {"departures": 0, "divergences": 0, "aborted": false}
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		await tree.physics_frame
		for orb: Orb in board.get_orbs():
			var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
			if center_extent > board.half_size():
				metrics["departures"] = int(metrics["departures"]) + 1
			if (
				orb.linear_velocity.length() > DIVERGENCE_SPEED
				or center_extent > board.half_size() + DIVERGENCE_MARGIN
				or not orb.position.is_finite()
				or not orb.linear_velocity.is_finite()
			):
				metrics["divergences"] = int(metrics["divergences"]) + 1
				metrics["aborted"] = true
		if bool(metrics["aborted"]):
			for orb: Orb in board.get_orbs():
				orb.set_physics_process(false)
				orb.set_process(false)
				orb.collision_layer = 0
				orb.collision_mask = 0
				orb.freeze = true
			return metrics
		if (
			manager.state == TurnManager.State.WAITING_INPUT
			or manager.state == TurnManager.State.GAME_OVER
		):
			return metrics
	assert_true(false, "measurement turn state timeout")
	return metrics


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
	return "40+"


func _empty_metric_bins() -> Dictionary:
	return {
		"0-20": {
			"turns": 0,
			"escape_guards": 0,
			"wall_recoveries": 0,
			"departures": 0,
			"divergences": 0,
			"merges": 0,
			"annihilations": 0,
		},
		"20-40": {
			"turns": 0,
			"escape_guards": 0,
			"wall_recoveries": 0,
			"departures": 0,
			"divergences": 0,
			"merges": 0,
			"annihilations": 0,
		},
		"40+": {
			"turns": 0,
			"escape_guards": 0,
			"wall_recoveries": 0,
			"departures": 0,
			"divergences": 0,
			"merges": 0,
			"annihilations": 0,
		},
	}


func _reaction_rates(bins: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for bin_name: String in ["0-20", "20-40", "40+"]:
		var values: Dictionary = bins[bin_name] as Dictionary
		var turns: int = int(values["turns"])
		result[bin_name] = {
			"turns": turns,
			"merges": int(values["merges"]),
			"annihilations": int(values["annihilations"]),
			"merges_per_turn": _safe_ratio(int(values["merges"]), turns),
			"annihilations_per_turn": _safe_ratio(int(values["annihilations"]), turns),
		}
	return result


func _safe_ratio(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0


func _write_report(report: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	assert_true(file != null, "measurement report file opens")
	if file == null:
		return
	file.store_string(JSON.stringify(report, "\t"))


func _cleanup_fixture(fixture: Dictionary) -> void:
	InputRouter.set_locked(false)
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame
