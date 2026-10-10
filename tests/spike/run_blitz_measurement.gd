extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SCORE_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const BLITZ_SCRIPT: Script = preload("res://scripts/core/BlitzManager.gd")
const DEFAULT_SEEDS: Array[int] = [101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112]
const DEFAULT_OUTPUT: String = "res://artifacts/blitz_measurement.json"
const MAX_SESSION_SECONDS: float = 600.0
const DIVERGENCE_SPEED: float = 5000.0
const DEPARTURE_MARGIN: float = 100.0
const PAIR_SAMPLE_FRAMES: int = 12

var _bot_interval: float = 0.6
var _bot_kind: String = "heuristic"
var _color_count: int = 6
var _refill_rule: String = "target"
var _seeds: Array[int] = []
var _output_path: String = DEFAULT_OUTPUT
var _runner_failed: bool = false
var _seed_reactions: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_apply_arguments()
	_apply_color_count()
	_apply_refill_rule()
	Config.data.fx_hitstop_enabled = false
	var original_ticks: int = Engine.physics_ticks_per_second
	Engine.physics_ticks_per_second = 120
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var rows: Array[Dictionary] = []
	for seed: int in _seeds:
		rows.append(await _run_seed(seed))
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"physics_ticks_per_second": 120,
		"bot_interval": _bot_interval,
		"bot_kind": _bot_kind,
		"color_count": _color_count,
		"refill_rule": _refill_rule,
		"gravity_strength": Config.data.gravity_strength,
		"gravity_level_scale": Config.data.gravity_level_scale,
		"seeds": rows,
		"config": {
			"duration": Config.data.blitz_duration,
			"swipe_cooldown": Config.data.blitz_swipe_cooldown,
			"spawn_on_swipe": Config.data.blitz_spawn_on_swipe,
			"min_spawn_per_swipe": Config.data.blitz_min_spawn_per_swipe,
			"max_spawn_per_swipe": Config.data.blitz_max_spawn_per_swipe,
			"spawn_interval": Config.data.blitz_spawn_interval,
			"spawn_level_weights": Array(Config.data.blitz_spawn_level_weights),
			"spawn_color_weights": Array(Config.data.blitz_spawn_color_weights),
			"initial_occupancy": Config.data.blitz_initial_occupancy,
			"target_occupancy": Config.data.blitz_target_occupancy,
			"refill_interval": Config.data.blitz_refill_interval,
			"ready_time": Config.data.blitz_ready_time,
			"chain_window": Config.data.blitz_chain_window,
			"chain_idle": Config.data.blitz_chain_idle,
			"chain_step": Config.data.blitz_chain_step,
			"chain_max_multiplier": Config.data.blitz_chain_max_multiplier,
			"fever_chain": Config.data.blitz_fever_chain,
			"fever_duration": Config.data.blitz_fever_duration,
			"fever_multiplier": Config.data.blitz_fever_multiplier,
			"blast_min_level": Config.data.blitz_blast_min_level,
			"finale_interval": Config.data.blitz_finale_interval,
		},
	}
	Engine.physics_ticks_per_second = original_ticks
	_write_report(report)
	print("BLITZ_REPORT_PATH %s" % _output_path)
	get_tree().quit(1 if _runner_failed else 0)


func _run_seed(seed: int) -> Dictionary:
	_seed_reactions = 0
	var fixture: Dictionary = await _create_fixture(seed)
	var root: Node = fixture["root"] as Node
	var board: Board3D = fixture["board"] as Board3D
	var spawner: Spawner = fixture["spawner"] as Spawner
	var score: ScoreManager = fixture["score"] as ScoreManager
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var tick: float = 1.0 / 120.0
	var session_elapsed: float = 0.0
	var bot_elapsed: float = 0.0
	var next_occupancy_sample: float = 10.0
	var occupancy_timeline: Array[Dictionary] = []
	var max_wall: float = 0.0
	var max_pair: float = 0.0
	var departed_ids: Dictionary = {}
	var divergent_ids: Dictionary = {}
	var physics_frame_index: int = 0
	var pending_layer_samples: Array[Dictionary] = []
	var layer_distances: Dictionary = _empty_layer_distances()
	while manager.state != BlitzManager.State.FINISHED:
		await get_tree().physics_frame
		session_elapsed += tick
		physics_frame_index += 1
		if manager.state == BlitzManager.State.RUNNING:
			bot_elapsed += tick
			while bot_elapsed + 0.000001 >= _bot_interval:
				bot_elapsed -= _bot_interval
				var direction: Vector2i = _choose_bot_direction(
					board,
					spawner,
					manager.gravity
				)
				var accepted_before: int = manager.accepted_swipes
				manager.on_swipe(direction)
				if manager.accepted_swipes > accepted_before:
					pending_layer_samples.append({
						"due_time": session_elapsed + 1.0,
					})
		while (
			not pending_layer_samples.is_empty()
			and float(pending_layer_samples[0]["due_time"]) <= session_elapsed
		):
			var sample: Dictionary = pending_layer_samples.pop_front() as Dictionary
			_accumulate_layer_distances(
				board,
				manager.gravity,
				layer_distances
			)
		while manager.play_time_elapsed + 0.000001 >= next_occupancy_sample:
			occupancy_timeline.append({
				"second": int(next_occupancy_sample),
				"occupancy_percent": _occupancy(board) * 100.0,
			})
			next_occupancy_sample += 10.0
		max_wall = maxf(max_wall, _max_wall_penetration(board))
		_record_invalid_motion(board, departed_ids, divergent_ids)
		if physics_frame_index % PAIR_SAMPLE_FRAMES == 0:
			max_pair = maxf(max_pair, _max_pair_penetration(board))
		if session_elapsed >= MAX_SESSION_SECONDS:
			_runner_failed = true
			break
	var finale_score: int = score.score - manager.finale_score_start
	var row: Dictionary = {
		"seed": seed,
		"completed": manager.state == BlitzManager.State.FINISHED,
		"score": score.score,
		"reactions": _seed_reactions,
		"running_reactions": manager.reaction_count,
		"reaction_without_swipe_count": manager.passive_reaction_count,
		"reaction_without_swipe_percent": _safe_percent(
			manager.passive_reaction_count,
			manager.reaction_count
		),
		"reactions_per_second": (
			float(manager.reaction_count) / manager.play_time_elapsed
			if manager.play_time_elapsed > 0.0
			else 0.0
		),
		"max_combo": manager.max_combo,
		"max_chain": manager.max_chain,
		"chain_histogram": manager.chain_histogram,
		"fever_count": manager.fever_count,
		"fever_total_time": manager.fever_total_time,
		"fever_time_percent": _safe_percent_float(
			manager.fever_total_time,
			manager.play_time_elapsed
		),
		"blast_count": manager.blast_count,
		"finale_blast_count": manager.finale_blast_count,
		"time_bonus_total": manager.time_bonus_total,
		"play_time": manager.play_time_elapsed,
		"session_time": session_elapsed,
		"accepted_swipes": manager.accepted_swipes,
		"productive_swipes": manager.productive_swipes,
		"productive_swipe_percent": _safe_percent(
			manager.productive_swipes,
			manager.accepted_swipes
		),
		"initial_fill_count": spawner.last_blitz_initial_count,
		"spawn_count": manager.spawn_count,
		"spawn_batch_histogram": manager.spawn_batch_histogram,
		"max_spawn_batch": manager.max_spawn_batch,
		"remaining_refill_debt": manager.refill_debt,
		"skipped_spawn_ticks": manager.skipped_spawn_ticks,
		"skipped_spawn_count": manager.skipped_spawn_ticks,
		"first_reaction_time": manager.first_reaction_time,
		"finale_score": finale_score,
		"finale_score_percent": _safe_percent(finale_score, score.score),
		"final_occupancy_percent": _occupancy(board) * 100.0,
		"occupancy_timeline": occupancy_timeline,
		"max_wall_penetration_px": max_wall,
		"max_pair_penetration_px_sampled_10hz": max_pair,
		"departures": departed_ids.size(),
		"divergences": divergent_ids.size(),
		"layer_distance_by_level": _finalize_layer_distances(layer_distances),
	}
	print(
		"BLITZ_SEED rule=%s colors=%d bot=%s interval=%.1f seed=%d score=%d reactions=%d passive=%.1f%% rate=%.2f/s chain=%d productive=%.1f%% fever=%.1f%% blast=%d spawn=%d batch_max=%d debt=%d skipped=%d bonus=%.1f play=%.2f wall=%.3f pair=%.3f departures=%d divergences=%d" % [
			_refill_rule,
			_color_count,
			_bot_kind,
			_bot_interval,
			seed,
			score.score,
			_seed_reactions,
			float(row["reaction_without_swipe_percent"]),
			float(row["reactions_per_second"]),
			manager.max_chain,
			float(row["productive_swipe_percent"]),
			float(row["fever_time_percent"]),
			manager.blast_count,
			manager.spawn_count,
			manager.max_spawn_batch,
			manager.refill_debt,
			manager.skipped_spawn_ticks,
			manager.time_bonus_total,
			manager.play_time_elapsed,
			max_wall,
			max_pair,
			departed_ids.size(),
			divergent_ids.size(),
		]
	)
	InputRouter.set_locked(false)
	root.queue_free()
	await get_tree().process_frame
	return row


func _create_fixture(seed: int) -> Dictionary:
	var root: Node = Node.new()
	root.name = "BlitzMeasurementSeed%d" % seed
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	root.add_child(board)
	board.owner = root
	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	root.add_child(spawner)
	spawner.owner = root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	root.add_child(resolver)
	resolver.owner = root
	var score: ScoreManager = SCORE_SCRIPT.new() as ScoreManager
	score.name = "ScoreManager"
	score.unique_name_in_owner = true
	score.save_path = ""
	root.add_child(score)
	score.owner = root
	var manager: BlitzManager = BLITZ_SCRIPT.new() as BlitzManager
	manager.name = "BlitzManager"
	manager.unique_name_in_owner = true
	manager.refill_rule = _measurement_refill_rule()
	root.add_child(manager)
	manager.owner = root
	add_child(root)
	await get_tree().process_frame
	spawner.set_blitz_mode(true)
	spawner.init_rng(seed)
	spawner.orb_spawned.connect(score.on_orb_spawned)
	manager.reaction_ready.connect(score.on_reaction)
	score.reaction_scored.connect(_on_reaction_scored)
	spawner.spawn_initial(board, Vector2i.DOWN)
	manager.start_game()
	return {
		"root": root,
		"board": board,
		"spawner": spawner,
		"resolver": resolver,
		"score": score,
		"manager": manager,
	}


func _on_reaction_scored(_reaction: Dictionary) -> void:
	_seed_reactions += 1


func _occupancy(board: Board3D) -> float:
	var area: float = 0.0
	for orb: Orb3D in board.get_orbs():
		var radius: float = Config.data.radius_for_level(orb.level)
		area += PI * radius * radius
	return area / (Config.data.board_size * Config.data.board_size)


func _max_wall_penetration(board: Board3D) -> float:
	var maximum: float = 0.0
	var half: float = board.half_size()
	for orb: Orb3D in board.get_orbs():
		var radius: float = orb.get_radius()
		maximum = maxf(maximum, absf(orb.position.x) + radius - half)
		maximum = maxf(maximum, absf(orb.position.y) + radius - half)
	return maxf(maximum, 0.0)


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
			var penetration: float = (
				first.get_radius()
				+ second.get_radius()
				- first.position.distance_to(second.position)
			)
			maximum = maxf(maximum, penetration)
	return maxf(maximum, 0.0)


func _record_invalid_motion(
	board: Board3D,
	departed_ids: Dictionary,
	divergent_ids: Dictionary
) -> void:
	var half: float = board.half_size()
	for orb: Orb3D in board.get_orbs():
		var id: int = orb.stable_spawn_id
		if (
			absf(orb.position.x) > half + orb.get_radius() + DEPARTURE_MARGIN
			or absf(orb.position.y) > half + orb.get_radius() + DEPARTURE_MARGIN
		):
			departed_ids[id] = true
		if orb.linear_velocity.length() > DIVERGENCE_SPEED:
			divergent_ids[id] = true


func _empty_layer_distances() -> Dictionary:
	var distances: Dictionary = {}
	for level: int in range(1, 8):
		distances["L%d" % level] = {"sum": 0.0, "samples": 0}
	return distances


func _accumulate_layer_distances(
	board: Board3D,
	gravity: Vector2i,
	distances: Dictionary
) -> void:
	var half: float = board.half_size()
	for orb: Orb3D in board.get_orbs():
		if orb.is_ghost or orb.is_waiting_at_entrance:
			continue
		var key: String = "L%d" % orb.level
		if not distances.has(key):
			distances[key] = {"sum": 0.0, "samples": 0}
		var values: Dictionary = distances[key] as Dictionary
		values["sum"] = float(values["sum"]) + _distance_to_gravity_wall(
			orb.position,
			gravity,
			half
		)
		values["samples"] = int(values["samples"]) + 1


func _distance_to_gravity_wall(
	position: Vector2,
	gravity: Vector2i,
	half: float
) -> float:
	if gravity == Vector2i.DOWN:
		return half - position.y
	if gravity == Vector2i.UP:
		return half + position.y
	if gravity == Vector2i.RIGHT:
		return half - position.x
	return half + position.x


func _finalize_layer_distances(distances: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key_value: Variant in distances.keys():
		var key: String = str(key_value)
		var values: Dictionary = distances[key] as Dictionary
		var samples: int = int(values["samples"])
		result[key] = {
			"mean_px": (
				float(values["sum"]) / float(samples)
				if samples > 0
				else 0.0
			),
			"samples": samples,
		}
	return result


func _safe_percent(numerator: int, denominator: int) -> float:
	if denominator <= 0:
		return 0.0
	return float(numerator) * 100.0 / float(denominator)


func _safe_percent_float(numerator: float, denominator: float) -> float:
	if denominator <= 0.0:
		return 0.0
	return numerator * 100.0 / denominator


func _choose_bot_direction(
	board: Board3D,
	spawner: Spawner,
	previous: Vector2i
) -> Vector2i:
	if _bot_kind == "random":
		return spawner.next_blitz_direction(previous)
	var candidates: Array[Vector2i] = []
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		if direction != previous:
			candidates.append(direction)
	var best_directions: Array[Vector2i] = []
	var best_count: int = -1
	for direction: Vector2i in candidates:
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
			var reaction: Dictionary = ReactionRules.classify(
				first.color,
				first.level,
				second.color,
				second.level,
				Config.data
			)
			var reaction_type: ReactionRules.Type = reaction["type"] as ReactionRules.Type
			if (
				reaction_type != ReactionRules.Type.MERGE
				and reaction_type != ReactionRules.Type.MAX_CLEAR
				and reaction_type != ReactionRules.Type.BLAST
			):
				continue
			var offset: Vector2 = second.position - first.position
			var maximum_distance: float = (
				first.get_radius() + second.get_radius()
			) * 3.0
			if offset.length() > maximum_distance or offset.is_zero_approx():
				continue
			if absf(offset.normalized().dot(Vector2(direction))) >= 0.8:
				count += 1
	return count


func _apply_arguments() -> void:
	_seeds.append_array(DEFAULT_SEEDS)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--blitz-bot-interval="):
			_bot_interval = maxf(
				argument.trim_prefix("--blitz-bot-interval=").to_float(),
				0.001
			)
		elif argument.begins_with("--blitz-bot="):
			_bot_kind = argument.trim_prefix("--blitz-bot=").to_lower()
		elif argument.begins_with("--blitz-color-count="):
			_color_count = argument.trim_prefix("--blitz-color-count=").to_int()
		elif argument.begins_with("--blitz-refill-rule="):
			_refill_rule = argument.trim_prefix("--blitz-refill-rule=").to_lower()
		elif argument.begins_with("--blitz-seeds="):
			_seeds.clear()
			for value: String in argument.trim_prefix("--blitz-seeds=").split(","):
				_seeds.append(value.to_int())
		elif argument.begins_with("--blitz-output="):
			_output_path = argument.trim_prefix("--blitz-output=")
		elif argument.begins_with("--gravity-strength="):
			Config.data.gravity_strength = argument.trim_prefix(
				"--gravity-strength="
			).to_float()
		elif argument.begins_with("--gravity-level-scale="):
			Config.data.gravity_level_scale = argument.trim_prefix(
				"--gravity-level-scale="
			).to_float()


func _apply_color_count() -> void:
	if _color_count == 4:
		Config.data.blitz_spawn_color_weights = PackedFloat32Array(
			[1.0, 1.0, 1.0, 1.0, 0.0, 0.0]
		)
		return
	if _color_count == 6:
		Config.data.blitz_spawn_color_weights = PackedFloat32Array(
			[1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
		)
		return
	push_error("BLITZ color count must be 4 or 6, got %d" % _color_count)
	_runner_failed = true


func _apply_refill_rule() -> void:
	Config.data.blitz_min_spawn_per_swipe = 1
	Config.data.blitz_max_spawn_per_swipe = 8
	if _refill_rule in ["baseline", "debt", "target"]:
		return
	push_error(
		"BLITZ refill rule must be baseline, debt, or target, got %s"
		% _refill_rule
	)
	_runner_failed = true


func _measurement_refill_rule() -> BlitzManager.RefillRule:
	if _refill_rule == "baseline":
		return BlitzManager.RefillRule.SINGLE
	if _refill_rule == "debt":
		return BlitzManager.RefillRule.COUNT_DEBT
	return BlitzManager.RefillRule.TARGET_DENSITY


func _write_report(report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(_output_path)
	var directory: String = absolute_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory)
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write BLITZ report: %s" % absolute_path)
		_runner_failed = true
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
