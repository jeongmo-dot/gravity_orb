extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const DEFAULT_SEEDS: Array[int] = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112]
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
const TICKS_PER_SECOND: int = 120
const TURN_TIMEOUT_SECONDS: float = 3.5
const SESSION_TIMEOUT_SECONDS: float = 180.0
const BOT_INTERVAL: float = 0.6
const DIVERGENCE_SPEED: float = 5000.0
const DEPARTURE_MARGIN: float = 100.0
const PAIR_SAMPLE_FRAMES: int = 12

var _mode: String = "turn"
var _seeds: Array[int] = []
var _turns: int = 120
var _contact_max: int = 6
var _proximity_scan_enabled: bool = true
var _output_path: String = "res://artifacts/reaction_latency.json"
var _current_sfx_events: Array[Dictionary] = []
var _runner_failed: bool = false


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_apply_arguments()
	var original_ticks: int = Engine.physics_ticks_per_second
	var original_contact_max: int = Config.data.contact_max_reported
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Engine.physics_ticks_per_second = TICKS_PER_SECOND
	Config.data.contact_max_reported = _contact_max
	Config.data.fx_enabled = false
	Config.data.fx_hitstop_enabled = false
	Config.data.sfx_enabled = true
	var rows: Array[Dictionary] = []
	var all_latency: Array[Dictionary] = []
	var all_sfx: Array[Dictionary] = []
	for seed: int in _seeds:
		var row: Dictionary = (
			await _run_blitz_seed(seed)
			if _mode == "blitz"
			else await _run_turn_seed(seed)
		)
		all_latency.append_array(row["latency_records"] as Array[Dictionary])
		all_sfx.append_array(row["sfx_events"] as Array[Dictionary])
		row.erase("latency_records")
		row.erase("sfx_events")
		rows.append(row)
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"physics_ticks_per_second": TICKS_PER_SECOND,
		"mode": _mode,
		"contact_max_reported": _contact_max,
		"proximity_scan_enabled": _proximity_scan_enabled,
		"seeds": _seeds,
		"rows": rows,
		"latency": _summarize_latency(all_latency),
		"sfx": _summarize_sfx(all_sfx),
	}
	_write_report(report)
	print("REACTION_LATENCY %s" % JSON.stringify({
		"mode": _mode,
		"contact_max_reported": _contact_max,
		"latency": report["latency"],
		"sfx": report["sfx"],
	}))
	Config.data.contact_max_reported = original_contact_max
	Config.data.game_mode = original_mode
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop
	Config.data.sfx_enabled = original_sfx
	Engine.physics_ticks_per_second = original_ticks
	get_tree().quit(1 if _runner_failed else 0)


func _run_turn_seed(seed: int) -> Dictionary:
	Config.data.game_mode = GameConfig.GameMode.TURN
	var fixture: Dictionary = await _create_fixture(seed, false)
	var root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var score: ScoreManager = fixture["score"] as ScoreManager
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	var physical: Dictionary = _empty_physical_metrics()
	await _wait_for_turn_state(manager, board, physical)
	var completed_turns: int = 0
	for turn_offset: int in range(_turns):
		if manager.state == TurnManager.State.GAME_OVER:
			break
		manager.on_swipe(DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()])
		await _wait_for_turn_state(manager, board, physical)
		completed_turns = turn_offset + 1
	await get_tree().process_frame
	var latency_records: Array[Dictionary] = resolver.finish_latency_measurement()
	var row: Dictionary = {
		"seed": seed,
		"completed_turns": completed_turns,
		"game_over": manager.state == TurnManager.State.GAME_OVER,
		"score": score.score,
		"final_orbs": board.get_orbs().size(),
		"state_hash": _state_hash(board),
		"latency": _summarize_latency(latency_records),
		"sfx": _summarize_sfx(_current_sfx_events),
		"physical": physical,
		"latency_records": latency_records,
		"sfx_events": _current_sfx_events.duplicate(true),
	}
	print("REACTION_LATENCY_SEED mode=turn seed=%d turns=%d score=%d reactions=%d missed=%d wall=%.3f pair=%.3f" % [
		seed,
		completed_turns,
		score.score,
		int((row["latency"] as Dictionary)["reaction_count"]),
		int((row["latency"] as Dictionary)["missed_unlocked_count"]),
		float(physical["max_wall_penetration_px"]),
		float(physical["max_pair_penetration_px_sampled_10hz"]),
	])
	root.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	InputRouter.set_locked(false)
	return row


func _run_blitz_seed(seed: int) -> Dictionary:
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var fixture: Dictionary = await _create_fixture(seed, true)
	var root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var score: ScoreManager = fixture["score"] as ScoreManager
	spawner.set_blitz_mode(true)
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	var physical: Dictionary = _empty_physical_metrics()
	var elapsed: float = 0.0
	var bot_elapsed: float = 0.0
	var tick: float = 1.0 / float(TICKS_PER_SECOND)
	var frame_index: int = 0
	while manager.state != BlitzManager.State.FINISHED:
		await get_tree().physics_frame
		elapsed += tick
		frame_index += 1
		_sample_physical(board, physical, frame_index)
		if manager.state == BlitzManager.State.RUNNING:
			bot_elapsed += tick
			while bot_elapsed + 0.000001 >= BOT_INTERVAL:
				bot_elapsed -= BOT_INTERVAL
				manager.on_swipe(_choose_bot_direction(board, spawner, manager.gravity))
		if elapsed >= SESSION_TIMEOUT_SECONDS:
			_runner_failed = true
			break
	await get_tree().process_frame
	var latency_records: Array[Dictionary] = resolver.finish_latency_measurement()
	var row: Dictionary = {
		"seed": seed,
		"completed": manager.state == BlitzManager.State.FINISHED,
		"play_time": manager.play_time_elapsed,
		"score": score.score,
		"final_orbs": board.get_orbs().size(),
		"state_hash": _state_hash(board),
		"latency": _summarize_latency(latency_records),
		"sfx": _summarize_sfx(_current_sfx_events),
		"physical": physical,
		"latency_records": latency_records,
		"sfx_events": _current_sfx_events.duplicate(true),
	}
	print("REACTION_LATENCY_SEED mode=blitz seed=%d play=%.2f score=%d reactions=%d missed=%d wall=%.3f pair=%.3f" % [
		seed,
		manager.play_time_elapsed,
		score.score,
		int((row["latency"] as Dictionary)["reaction_count"]),
		int((row["latency"] as Dictionary)["missed_unlocked_count"]),
		float(physical["max_wall_penetration_px"]),
		float(physical["max_pair_penetration_px_sampled_10hz"]),
	])
	root.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	InputRouter.set_locked(false)
	return row


func _create_fixture(seed: int, blitz: bool) -> Dictionary:
	InputRouter.set_locked(false)
	_current_sfx_events.clear()
	var root: Node3D = Node3D.new()
	root.name = "ReactionLatencySeed%d" % seed
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	root.add_child(board)
	board.owner = root
	var resolver: CollisionResolver = CollisionResolver.new()
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	resolver.proximity_reaction_scan_enabled = _proximity_scan_enabled
	root.add_child(resolver)
	resolver.owner = root
	var spawner: Spawner = Spawner.new()
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	root.add_child(spawner)
	spawner.owner = root
	var score: ScoreManager = ScoreManager.new()
	score.name = "ScoreManager"
	score.unique_name_in_owner = true
	score.save_path = ""
	root.add_child(score)
	score.owner = root
	var manager: Variant
	if blitz:
		var blitz_manager: BlitzManager = BlitzManager.new()
		blitz_manager.name = "BlitzManager"
		blitz_manager.unique_name_in_owner = true
		blitz_manager.refill_rule = BlitzManager.RefillRule.TARGET_DENSITY
		manager = blitz_manager
	else:
		var turn_manager: TurnManager = TurnManager.new()
		turn_manager.name = "TurnManager"
		turn_manager.unique_name_in_owner = true
		manager = turn_manager
	root.add_child(manager as Node)
	(manager as Node).owner = root
	var director: FeedbackDirector = FeedbackDirector.new()
	director.name = "FeedbackDirector"
	root.add_child(director)
	director.owner = root
	get_tree().root.add_child(root)
	await get_tree().process_frame
	resolver.configure_latency_measurement(true)
	spawner.init_rng(seed)
	spawner.orb_spawned.connect(score.on_orb_spawned)
	manager.reaction_ready.connect(score.on_reaction)
	director.bind(manager, board)
	var bank: SfxBank = director.sfx_bank()
	bank.save_path = ""
	bank.play_called.connect(_on_sfx_play_called)
	return {
		"root": root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"score": score,
		"manager": manager,
		"director": director,
	}


func _wait_for_turn_state(
	manager: TurnManager,
	board: Board3D,
	physical: Dictionary
) -> void:
	var max_frames: int = ceili(TURN_TIMEOUT_SECONDS * float(TICKS_PER_SECOND))
	for frame_index: int in range(max_frames):
		await get_tree().physics_frame
		_sample_physical(board, physical, frame_index)
		if (
			manager.state == TurnManager.State.WAITING_INPUT
			or manager.state == TurnManager.State.GAME_OVER
		):
			return
	_runner_failed = true
	push_error("Reaction latency turn fixture timed out")


func _on_sfx_play_called(
	kind: String,
	reaction_usec: int,
	play_usec: int,
	reaction_physics_frame: int,
	play_physics_frame: int,
	reaction_process_frame: int,
	play_process_frame: int
) -> void:
	if reaction_usec <= 0:
		return
	_current_sfx_events.append({
		"kind": kind,
		"delay_ms": float(maxi(play_usec - reaction_usec, 0)) / 1000.0,
		"physics_frame_delay": maxi(play_physics_frame - reaction_physics_frame, 0),
		"process_frame_delay": maxi(play_process_frame - reaction_process_frame, 0),
	})


func _summarize_latency(records: Array[Dictionary]) -> Dictionary:
	var delay_ticks: Array[float] = []
	var unlocked_delay_ticks: Array[float] = []
	var delayed_contact_counts: Array[float] = []
	var path_counts: Dictionary = {
		"body_entered": 0,
		"sweep": 0,
		"lock_release": 0,
		"proximity": 0,
		"other": 0,
	}
	var missed_unlocked: int = 0
	var missed_locked: int = 0
	var preempted: int = 0
	var locked_reactions: int = 0
	var over_one_tick: int = 0
	var unlocked_over_one_tick: int = 0
	for record: Dictionary in records:
		if str(record["outcome"]) == "preempted":
			preempted += 1
			continue
		if str(record["outcome"]) != "reaction":
			if bool(record["locked"]):
				missed_locked += 1
			else:
				missed_unlocked += 1
			continue
		var ticks: int = int(record["delay_ticks"])
		delay_ticks.append(float(ticks))
		if not bool(record["locked"]):
			unlocked_delay_ticks.append(float(ticks))
		if ticks > 1:
			over_one_tick += 1
			delayed_contact_counts.append(float(record["contact_count"]))
			if not bool(record["locked"]):
				unlocked_over_one_tick += 1
		if bool(record["locked"]):
			locked_reactions += 1
		var path: String = str(record["path"])
		if path_counts.has(path):
			path_counts[path] = int(path_counts[path]) + 1
		else:
			path_counts["other"] = int(path_counts["other"]) + 1
	var tick_ms: float = 1000.0 / float(TICKS_PER_SECOND)
	return {
		"reaction_count": delay_ticks.size(),
		"delay_ms_p50": _percentile(delay_ticks, 0.50) * tick_ms,
		"delay_ms_p95": _percentile(delay_ticks, 0.95) * tick_ms,
		"delay_ms_max": _percentile(delay_ticks, 1.0) * tick_ms,
		"over_one_tick_count": over_one_tick,
		"over_one_tick_ratio": _ratio(over_one_tick, delay_ticks.size()),
		"unlocked_reaction_count": unlocked_delay_ticks.size(),
		"unlocked_delay_ms_p50": _percentile(unlocked_delay_ticks, 0.50) * tick_ms,
		"unlocked_delay_ms_p95": _percentile(unlocked_delay_ticks, 0.95) * tick_ms,
		"unlocked_delay_ms_max": _percentile(unlocked_delay_ticks, 1.0) * tick_ms,
		"unlocked_over_one_tick_count": unlocked_over_one_tick,
		"unlocked_over_one_tick_ratio": _ratio(
			unlocked_over_one_tick,
			unlocked_delay_ticks.size()
		),
		"path_counts": path_counts,
		"locked_reaction_count": locked_reactions,
		"missed_unlocked_count": missed_unlocked,
		"missed_locked_count": missed_locked,
		"preempted_count": preempted,
		"delayed_contact_count_p50": _percentile(delayed_contact_counts, 0.50),
		"delayed_contact_count_p95": _percentile(delayed_contact_counts, 0.95),
		"delayed_contact_count_max": _percentile(delayed_contact_counts, 1.0),
	}


func _summarize_sfx(events: Array[Dictionary]) -> Dictionary:
	var delay_ms: Array[float] = []
	var same_process_frame: int = 0
	var kind_counts: Dictionary = {"merge": 0, "blast": 0}
	for event: Dictionary in events:
		delay_ms.append(float(event["delay_ms"]))
		if int(event["process_frame_delay"]) == 0:
			same_process_frame += 1
		var kind: String = str(event["kind"])
		kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
	return {
		"play_count": events.size(),
		"delay_ms_p50": _percentile(delay_ms, 0.50),
		"delay_ms_p95": _percentile(delay_ms, 0.95),
		"delay_ms_max": _percentile(delay_ms, 1.0),
		"same_process_frame_count": same_process_frame,
		"same_process_frame_ratio": _ratio(same_process_frame, events.size()),
		"kind_counts": kind_counts,
	}


func _empty_physical_metrics() -> Dictionary:
	return {
		"max_wall_penetration_px": 0.0,
		"max_pair_penetration_px_sampled_10hz": 0.0,
		"departed_ids": {},
		"divergent_ids": {},
		"sample_frames": 0,
	}


func _sample_physical(board: Board3D, metrics: Dictionary, frame_index: int) -> void:
	metrics["sample_frames"] = int(metrics["sample_frames"]) + 1
	var half: float = board.half_size()
	var departed: Dictionary = metrics["departed_ids"] as Dictionary
	var divergent: Dictionary = metrics["divergent_ids"] as Dictionary
	for orb: Orb3D in board.get_orbs():
		metrics["max_wall_penetration_px"] = maxf(
			float(metrics["max_wall_penetration_px"]),
			maxf(
				maxf(absf(orb.position.x) + orb.get_radius() - half, 0.0),
				maxf(absf(orb.position.y) + orb.get_radius() - half, 0.0)
			)
		)
		if (
			absf(orb.position.x) > half + orb.get_radius() + DEPARTURE_MARGIN
			or absf(orb.position.y) > half + orb.get_radius() + DEPARTURE_MARGIN
		):
			departed[orb.stable_spawn_id] = true
		if not orb.position.is_finite() or orb.linear_velocity.length() > DIVERGENCE_SPEED:
			divergent[orb.stable_spawn_id] = true
	if frame_index % PAIR_SAMPLE_FRAMES == 0:
		metrics["max_pair_penetration_px_sampled_10hz"] = maxf(
			float(metrics["max_pair_penetration_px_sampled_10hz"]),
			_max_pair_penetration(board)
		)
	metrics["departures"] = departed.size()
	metrics["divergences"] = divergent.size()


func _max_pair_penetration(board: Board3D) -> float:
	var maximum: float = 0.0
	var orbs: Array[Orb3D] = board.get_orbs()
	for first_index: int in range(orbs.size()):
		var first: Orb3D = orbs[first_index]
		if first.is_ghost or first.is_waiting_at_entrance:
			continue
		for second_index: int in range(first_index + 1, orbs.size()):
			var second: Orb3D = orbs[second_index]
			if second.is_ghost or second.is_waiting_at_entrance:
				continue
			maximum = maxf(
				maximum,
				first.get_radius() + second.get_radius()
				- first.position.distance_to(second.position)
			)
	return maxf(maximum, 0.0)


func _choose_bot_direction(
	board: Board3D,
	spawner: Spawner,
	previous: Vector2i
) -> Vector2i:
	var best_directions: Array[Vector2i] = []
	var best_count: int = -1
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		if direction == previous:
			continue
		var count: int = _count_reaction_pairs(board, direction)
		if count > best_count:
			best_count = count
			best_directions = [direction]
		elif count == best_count:
			best_directions.append(direction)
	if best_count <= 0:
		return previous
	return spawner.choose_blitz_direction(best_directions)


func _count_reaction_pairs(board: Board3D, direction: Vector2i) -> int:
	var count: int = 0
	var orbs: Array[Orb3D] = board.get_orbs()
	for first_index: int in range(orbs.size()):
		var first: Orb3D = orbs[first_index]
		if first.is_ghost or first.is_waiting_at_entrance:
			continue
		for second_index: int in range(first_index + 1, orbs.size()):
			var second: Orb3D = orbs[second_index]
			if second.is_ghost or second.is_waiting_at_entrance:
				continue
			var classified: Dictionary = ReactionRules.classify(
				first.color,
				first.level,
				second.color,
				second.level,
				Config.data
			)
			if int(classified["type"]) == ReactionRules.Type.NONE:
				continue
			var offset: Vector2 = second.position - first.position
			var maximum_distance: float = (first.get_radius() + second.get_radius()) * 3.0
			if offset.length() > maximum_distance or offset.is_zero_approx():
				continue
			if absf(offset.normalized().dot(Vector2(direction))) >= 0.8:
				count += 1
	return count


func _state_hash(board: Board3D) -> String:
	var orbs: Array[Orb3D] = board.get_orbs()
	orbs.sort_custom(func(a: Orb3D, b: Orb3D) -> bool: return a.stable_spawn_id < b.stable_spawn_id)
	var rows: Array[Dictionary] = []
	for orb: Orb3D in orbs:
		rows.append({
			"id": orb.stable_spawn_id,
			"color": orb.color,
			"level": orb.level,
			"position": [snappedf(orb.position.x, 0.001), snappedf(orb.position.y, 0.001)],
			"velocity": [
				snappedf(orb.linear_velocity.x, 0.001),
				snappedf(orb.linear_velocity.y, 0.001),
			],
		})
	return JSON.stringify(rows)


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var index: int = clampi(
		roundi(float(sorted_values.size() - 1) * ratio),
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]


func _ratio(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0


func _apply_arguments() -> void:
	_seeds.append_array(DEFAULT_SEEDS)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--latency-mode="):
			_mode = argument.trim_prefix("--latency-mode=").to_lower()
		elif argument.begins_with("--latency-seeds="):
			_seeds.clear()
			for value: String in argument.trim_prefix("--latency-seeds=").split(",", false):
				_seeds.append(value.to_int())
		elif argument.begins_with("--latency-turns="):
			_turns = maxi(argument.trim_prefix("--latency-turns=").to_int(), 1)
		elif argument.begins_with("--latency-contact-max="):
			_contact_max = maxi(argument.trim_prefix("--latency-contact-max=").to_int(), 1)
		elif argument == "--latency-proximity=off":
			_proximity_scan_enabled = false
		elif argument == "--latency-proximity=on":
			_proximity_scan_enabled = true
		elif argument.begins_with("--latency-output="):
			_output_path = argument.trim_prefix("--latency-output=")
	if _mode not in ["turn", "blitz"]:
		push_error("Latency mode must be turn or blitz")
		_runner_failed = true


func _write_report(report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write reaction latency report: %s" % absolute_path)
		_runner_failed = true
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
