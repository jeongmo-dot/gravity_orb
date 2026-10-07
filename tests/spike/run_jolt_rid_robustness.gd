extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
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
const PAIR_SAMPLE_FRAMES: int = 12

var _mode: String = "turn"
var _seed: int = 101
var _dummy_body_count: int = 0
var _turns: int = 120
var _output_path: String = "res://artifacts/jolt_rid_robustness.json"
var _runner_failed: bool = false
var _active_departures: Dictionary = {}
var _recent_orb_events: Dictionary = {}
var _last_global_event: String = "initial_gravity"
var _last_global_event_frame: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_apply_arguments()
	var original_ticks: int = Engine.physics_ticks_per_second
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_fx: bool = Config.data.fx_enabled
	var original_hitstop: bool = Config.data.fx_hitstop_enabled
	var original_sfx: bool = Config.data.sfx_enabled
	Engine.physics_ticks_per_second = TICKS_PER_SECOND
	Config.data.fx_enabled = false
	Config.data.fx_hitstop_enabled = false
	Config.data.sfx_enabled = false
	await _perturb_rid_order()
	var row: Dictionary = (
		await _run_blitz()
		if _mode == "blitz"
		else await _run_turn()
	)
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"physics_ticks_per_second": TICKS_PER_SECOND,
		"mode": _mode,
		"seed": _seed,
		"dummy_body_count": _dummy_body_count,
		"row": row,
	}
	_write_report(report)
	var physical: Dictionary = row["physical"] as Dictionary
	print(
		(
			"JOLT_RID mode=%s p=%d seed=%d completed=%s departure_frames=%d "
			+ "orb_frames=%d max_outside=%.3f returned=%d never=%d removed=%d wall=%.3f pair=%.3f"
		)
		% [
			_mode,
			_dummy_body_count,
			_seed,
			str(bool(row["completed"])),
			int(physical["departure_frame_count"]),
			int(physical["departure_orb_frame_count"]),
			float(physical["max_outside_distance_px"]),
			int(physical["returned_count"]),
			int(physical["never_returned_count"]),
			int(physical["removed_while_outside_count"]),
			float(physical["max_wall_penetration_px"]),
			float(physical["max_pair_penetration_px_sampled_10hz"]),
		]
	)
	Config.data.game_mode = original_mode
	Config.data.fx_enabled = original_fx
	Config.data.fx_hitstop_enabled = original_hitstop
	Config.data.sfx_enabled = original_sfx
	Engine.physics_ticks_per_second = original_ticks
	get_tree().quit(1 if _runner_failed else 0)


func _perturb_rid_order() -> void:
	if _dummy_body_count <= 0:
		return
	var holder: Node3D = Node3D.new()
	holder.name = "RidPerturbation"
	get_tree().root.add_child(holder)
	for index: int in range(_dummy_body_count):
		var body: RigidBody3D = RigidBody3D.new()
		body.name = "DummyBody%d" % index
		body.freeze = true
		body.collision_layer = 0
		body.collision_mask = 0
		body.position = Vector3(1000.0 + float(index) * 2.0, 1000.0, 0.0)
		var collision: CollisionShape3D = CollisionShape3D.new()
		var shape: SphereShape3D = SphereShape3D.new()
		shape.radius = 0.25
		collision.shape = shape
		body.add_child(collision)
		holder.add_child(body)
	await get_tree().physics_frame
	holder.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _run_turn() -> Dictionary:
	Config.data.game_mode = GameConfig.GameMode.TURN
	var fixture: Dictionary = await _create_fixture(false)
	var root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var score: ScoreManager = fixture["score"] as ScoreManager
	spawner.spawn_initial(board, Vector2i.DOWN)
	_record_global_event("initial_gravity")
	manager.start_game()
	var physical: Dictionary = _empty_physical_metrics()
	await _wait_for_turn_state(manager, board, physical)
	var completed_turns: int = 0
	for turn_offset: int in range(_turns):
		if manager.state == TurnManager.State.GAME_OVER:
			break
		_record_global_event("gravity_change")
		manager.on_swipe(DIRECTION_PATTERN[turn_offset % DIRECTION_PATTERN.size()])
		await _wait_for_turn_state(manager, board, physical)
		completed_turns = turn_offset + 1
	_finalize_physical(board, physical)
	var row: Dictionary = {
		"completed": completed_turns == _turns,
		"completed_turns": completed_turns,
		"game_over": manager.state == TurnManager.State.GAME_OVER,
		"score": score.score,
		"final_orbs": board.get_orbs().size(),
		"physical": physical,
	}
	root.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	InputRouter.set_locked(false)
	return row


func _run_blitz() -> Dictionary:
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var fixture: Dictionary = await _create_fixture(true)
	var root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var score: ScoreManager = fixture["score"] as ScoreManager
	spawner.set_blitz_mode(true)
	spawner.spawn_initial(board, Vector2i.DOWN)
	_record_global_event("initial_gravity")
	manager.start_game()
	var physical: Dictionary = _empty_physical_metrics()
	var elapsed: float = 0.0
	var bot_elapsed: float = 0.0
	var tick: float = 1.0 / float(TICKS_PER_SECOND)
	var sample_index: int = 0
	while manager.state != BlitzManager.State.FINISHED:
		await get_tree().physics_frame
		elapsed += tick
		sample_index += 1
		_sample_physical(board, physical, sample_index)
		if manager.state == BlitzManager.State.RUNNING:
			bot_elapsed += tick
			while bot_elapsed + 0.000001 >= BOT_INTERVAL:
				bot_elapsed -= BOT_INTERVAL
				var direction: Vector2i = _choose_bot_direction(
					board,
					spawner,
					manager.gravity
				)
				var accepted_before: int = manager.accepted_swipes
				manager.on_swipe(direction)
				if manager.accepted_swipes > accepted_before:
					_record_global_event("gravity_change")
		if elapsed >= SESSION_TIMEOUT_SECONDS:
			_runner_failed = true
			break
	_finalize_physical(board, physical)
	var row: Dictionary = {
		"completed": manager.state == BlitzManager.State.FINISHED,
		"play_time": manager.play_time_elapsed,
		"score": score.score,
		"final_orbs": board.get_orbs().size(),
		"physical": physical,
	}
	root.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	InputRouter.set_locked(false)
	return row


func _create_fixture(blitz: bool) -> Dictionary:
	InputRouter.set_locked(false)
	_active_departures.clear()
	_recent_orb_events.clear()
	_last_global_event = "initial_gravity"
	_last_global_event_frame = Engine.get_physics_frames()
	var root: Node3D = Node3D.new()
	root.name = "JoltRidRobustness_%s_P%d_Seed%d" % [
		_mode,
		_dummy_body_count,
		_seed,
	]
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	root.add_child(board)
	board.owner = root
	var resolver: CollisionResolver = CollisionResolver.new()
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
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
	var manager: Node
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
	root.add_child(manager)
	manager.owner = root
	get_tree().root.add_child(root)
	await get_tree().process_frame
	spawner.init_rng(_seed)
	spawner.orb_spawned.connect(score.on_orb_spawned)
	manager.reaction_ready.connect(score.on_reaction)
	manager.reaction_ready.connect(_record_reaction_event)
	return {
		"root": root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"score": score,
		"manager": manager,
	}


func _wait_for_turn_state(
	manager: TurnManager,
	board: Board3D,
	physical: Dictionary
) -> void:
	var max_frames: int = ceili(TURN_TIMEOUT_SECONDS * float(TICKS_PER_SECOND))
	for sample_index: int in range(max_frames):
		await get_tree().physics_frame
		_sample_physical(board, physical, sample_index)
		if (
			manager.state == TurnManager.State.WAITING_INPUT
			or manager.state == TurnManager.State.GAME_OVER
		):
			return
	_runner_failed = true
	push_error("Jolt RID robustness TURN fixture timed out")


func _empty_physical_metrics() -> Dictionary:
	return {
		"max_wall_penetration_px": 0.0,
		"max_pair_penetration_px_sampled_10hz": 0.0,
		"sample_frames": 0,
		"departure_frame_count": 0,
		"departure_orb_frame_count": 0,
		"departure_ids": {},
		"departure_levels": {},
		"max_outside_distance_px": 0.0,
		"returned_count": 0,
		"never_returned_count": 0,
		"removed_while_outside_count": 0,
		"preceding_event_counts": {},
		"departure_events": [],
	}


func _sample_physical(board: Board3D, metrics: Dictionary, sample_index: int) -> void:
	metrics["sample_frames"] = int(metrics["sample_frames"]) + 1
	var frame: int = Engine.get_physics_frames()
	var half: float = board.half_size()
	var current_ids: Dictionary = {}
	var frame_has_departure: bool = false
	for orb: Orb3D in board.get_orbs():
		var orb_id: int = orb.stable_spawn_id
		current_ids[orb_id] = true
		var wall_penetration: float = maxf(
			maxf(absf(orb.position.x) + orb.get_radius() - half, 0.0),
			maxf(absf(orb.position.y) + orb.get_radius() - half, 0.0)
		)
		metrics["max_wall_penetration_px"] = maxf(
			float(metrics["max_wall_penetration_px"]),
			wall_penetration
		)
		var outside_distance: float = maxf(
			maxf(absf(orb.position.x), absf(orb.position.y)) - half,
			0.0
		)
		if outside_distance > 0.0:
			frame_has_departure = true
			metrics["departure_orb_frame_count"] = (
				int(metrics["departure_orb_frame_count"]) + 1
			)
			metrics["max_outside_distance_px"] = maxf(
				float(metrics["max_outside_distance_px"]),
				outside_distance
			)
			if not _active_departures.has(orb_id):
				var preceding: Dictionary = _preceding_event(orb, frame)
				_active_departures[orb_id] = {
					"stable_spawn_id": orb_id,
					"level": orb.level,
					"start_frame": frame,
					"end_frame": frame,
					"outside_frames": 0,
					"max_outside_distance_px": 0.0,
					"preceding_event": preceding["name"],
					"preceding_event_age_frames": preceding["age_frames"],
					"outcome": "active",
				}
				var departure_ids: Dictionary = metrics["departure_ids"] as Dictionary
				departure_ids[orb_id] = true
				var levels: Dictionary = metrics["departure_levels"] as Dictionary
				var level_key: String = "L%d" % orb.level
				levels[level_key] = int(levels.get(level_key, 0)) + 1
			var episode: Dictionary = _active_departures[orb_id] as Dictionary
			episode["end_frame"] = frame
			episode["outside_frames"] = int(episode["outside_frames"]) + 1
			episode["max_outside_distance_px"] = maxf(
				float(episode["max_outside_distance_px"]),
				outside_distance
			)
			_active_departures[orb_id] = episode
		elif _active_departures.has(orb_id):
			_finish_departure(metrics, orb_id, "returned", frame)
	if frame_has_departure:
		metrics["departure_frame_count"] = int(metrics["departure_frame_count"]) + 1
	for active_id_value: Variant in _active_departures.keys():
		var active_id: int = int(active_id_value)
		if not current_ids.has(active_id):
			_finish_departure(metrics, active_id, "removed_while_outside", frame)
	if sample_index % PAIR_SAMPLE_FRAMES == 0:
		metrics["max_pair_penetration_px_sampled_10hz"] = maxf(
			float(metrics["max_pair_penetration_px_sampled_10hz"]),
			_max_pair_penetration(board)
		)


func _finalize_physical(board: Board3D, metrics: Dictionary) -> void:
	var frame: int = Engine.get_physics_frames()
	var current_ids: Dictionary = {}
	for orb: Orb3D in board.get_orbs():
		current_ids[orb.stable_spawn_id] = true
	for active_id_value: Variant in _active_departures.keys():
		var active_id: int = int(active_id_value)
		var outcome: String = "never_returned" if current_ids.has(active_id) else "removed_while_outside"
		_finish_departure(metrics, active_id, outcome, frame)
	metrics["departure_game"] = not (metrics["departure_ids"] as Dictionary).is_empty()


func _finish_departure(
	metrics: Dictionary,
	orb_id: int,
	outcome: String,
	end_frame: int
) -> void:
	if not _active_departures.has(orb_id):
		return
	var episode: Dictionary = _active_departures[orb_id] as Dictionary
	episode["end_frame"] = end_frame
	episode["outcome"] = outcome
	var events: Array = metrics["departure_events"] as Array
	events.append(episode.duplicate(true))
	var preceding_counts: Dictionary = metrics["preceding_event_counts"] as Dictionary
	var preceding_name: String = str(episode["preceding_event"])
	preceding_counts[preceding_name] = int(preceding_counts.get(preceding_name, 0)) + 1
	match outcome:
		"returned":
			metrics["returned_count"] = int(metrics["returned_count"]) + 1
		"never_returned":
			metrics["never_returned_count"] = int(metrics["never_returned_count"]) + 1
		"removed_while_outside":
			metrics["removed_while_outside_count"] = (
				int(metrics["removed_while_outside_count"]) + 1
			)
	_active_departures.erase(orb_id)


func _record_reaction_event(reaction: Dictionary) -> void:
	var frame: int = int(reaction.get("reaction_physics_frame", Engine.get_physics_frames()))
	var reaction_type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
	if reaction_type == ReactionRules.Type.BLAST:
		for target: Dictionary in reaction.get("blast_targets", []) as Array[Dictionary]:
			var orb: Variant = target.get("orb")
			if is_instance_valid(orb):
				_recent_orb_events[int(orb.stable_spawn_id)] = {
					"name": "blast_impulse",
					"frame": frame,
				}
	var result_orb: Variant = reaction.get("result_orb")
	if is_instance_valid(result_orb):
		_recent_orb_events[int(result_orb.stable_spawn_id)] = {
			"name": "merge_result_spawn",
			"frame": frame,
		}


func _record_global_event(event_name: String) -> void:
	_last_global_event = event_name
	_last_global_event_frame = Engine.get_physics_frames()


func _preceding_event(orb: Orb3D, frame: int) -> Dictionary:
	var best_name: String = _last_global_event
	var best_frame: int = _last_global_event_frame
	var diagnostic_name: String = orb.diagnostic_last_event
	var diagnostic_frame: int = orb.diagnostic_last_event_physics_frame
	if diagnostic_frame >= best_frame:
		best_frame = diagnostic_frame
		match diagnostic_name:
			"spawn":
				best_name = "swipe_spawn"
			"merge_result":
				best_name = "merge_result_spawn"
			_:
				best_name = diagnostic_name
	if _recent_orb_events.has(orb.stable_spawn_id):
		var recent: Dictionary = _recent_orb_events[orb.stable_spawn_id] as Dictionary
		if int(recent["frame"]) >= best_frame:
			best_frame = int(recent["frame"])
			best_name = str(recent["name"])
	return {
		"name": best_name,
		"age_frames": maxi(frame - best_frame, 0),
	}


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


func _apply_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rid-mode="):
			_mode = argument.trim_prefix("--rid-mode=").to_lower()
		elif argument.begins_with("--rid-seed="):
			_seed = argument.trim_prefix("--rid-seed=").to_int()
		elif argument.begins_with("--rid-dummy-count="):
			_dummy_body_count = maxi(
				argument.trim_prefix("--rid-dummy-count=").to_int(),
				0
			)
		elif argument.begins_with("--rid-turns="):
			_turns = maxi(argument.trim_prefix("--rid-turns=").to_int(), 1)
		elif argument.begins_with("--rid-output="):
			_output_path = argument.trim_prefix("--rid-output=")
	if _mode not in ["turn", "blitz"]:
		push_error("RID robustness mode must be turn or blitz")
		_runner_failed = true


func _write_report(report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write Jolt RID robustness report: %s" % absolute_path)
		_runner_failed = true
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
