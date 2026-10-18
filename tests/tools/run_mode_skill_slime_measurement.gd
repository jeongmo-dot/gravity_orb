extends SceneTree

const CONFIG: SlimeConfig = preload("res://config/slime_config.tres")
const DT: float = 1.0 / 60.0
const DEFAULT_SEED_COUNT: int = 100
const DEFAULT_TURN_CAP: int = 250
const DEFAULT_OUTPUT: String = "res://artifacts/measurements/mode_skill_slime.json"
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.RIGHT,
]
const STRATEGIES: Array[String] = ["r", "s", "g", "preview_space", "preview_merge"]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_count: int = _int_argument("--seed-count=", DEFAULT_SEED_COUNT)
	var seed_start: int = _int_argument("--seed-start=", 1)
	var turn_cap: int = _int_argument("--turn-cap=", DEFAULT_TURN_CAP)
	var output_path: String = _string_argument("--output=", DEFAULT_OUTPUT)
	var strategies: Array[String] = _strategy_argument()
	var candidate_settings: Dictionary = _candidate_settings()
	var threads: Array[Thread] = []
	for strategy: String in strategies:
		var worker := Thread.new()
		worker.start(
			Callable(self, "_measure_strategy").bind(
				strategy,
				seed_start,
				seed_count,
				turn_cap,
				candidate_settings
			)
		)
		threads.append(worker)
	var strategy_reports: Dictionary = {}
	for index: int in range(threads.size()):
		var result: Dictionary = threads[index].wait_to_finish() as Dictionary
		strategy_reports[strategies[index]] = result
		print(
			"MODE_SKILL_SLIME strategy=%s seeds=%d seconds=%.3f"
			% [strategies[index], seed_count, float(result["measurement_seconds"])]
		)
	var report: Dictionary = {
		"mode": "slime",
		"seed_start": seed_start,
		"seed_count": seed_count,
		"turn_cap": turn_cap,
		"candidate_settings": candidate_settings,
		"strategies": strategy_reports,
	}
	_write_report(output_path, report)
	print("MODE_SKILL_SLIME_RESULT path=%s exit=0" % output_path)
	quit(0)


func _measure_strategy(
	strategy: String,
	seed_start: int,
	seed_count: int,
	turn_cap: int,
	candidate_settings: Dictionary
) -> Dictionary:
	var started_msec: int = Time.get_ticks_msec()
	var measurement_config: SlimeConfig = CONFIG.duplicate(true) as SlimeConfig
	_apply_candidate_settings(measurement_config, candidate_settings)
	var rows: Array[Dictionary] = []
	var preview_decision_turns: int = 0
	var preview_fatal_avoidance_turns: int = 0
	var preview_unblocked_spread_sum: float = 0.0
	var preview_score_gain_spreads: Array[float] = []
	var preview_decision_usec_sum: int = 0
	for seed_value: int in range(seed_start, seed_start + seed_count):
		var sim := SlimeSim.new(measurement_config, seed_value, false, true)
		var bot_rng := RandomNumberGenerator.new()
		bot_rng.seed = 0x5A1E0000 + seed_value * 131 + strategy.hash()
		_run_until_idle(sim)
		var seen_colors: Dictionary = {}
		_record_seen_colors(sim, seen_colors)
		_record_spawned_colors(sim.drain_events(), seen_colors)
		var early_merge_count: int = 0
		var maximum_mass: int = _maximum_mass(sim)
		var maximum_level: int = _maximum_level(sim)
		while not sim.game_over and sim.turn < turn_cap:
			var direction: Vector2i
			if strategy == "preview_space" or strategy == "preview_merge":
				var preview_decision: Dictionary = _choose_preview_direction(
					sim,
					strategy,
					bot_rng
				)
				direction = preview_decision["direction"] as Vector2i
				preview_decision_turns += 1
				preview_fatal_avoidance_turns += int(
					preview_decision["fatal_avoidance"]
				)
				preview_unblocked_spread_sum += float(
					preview_decision["unblocked_direction_spread"]
				)
				preview_score_gain_spreads.append(
					float(preview_decision["score_gain_spread"])
				)
				preview_decision_usec_sum += int(preview_decision["decision_usec"])
			else:
				direction = _choose_direction(sim, strategy, bot_rng)
			if not sim.start_turn(direction):
				break
			_run_until_idle(sim)
			var events: Array[Dictionary] = sim.drain_events()
			_record_spawned_colors(events, seen_colors)
			for event: Dictionary in events:
				if sim.turn <= 30 and str(event.get("type", "")) == "absorbed":
					early_merge_count += 1
			_record_seen_colors(sim, seen_colors)
			maximum_mass = maxi(maximum_mass, _maximum_mass(sim))
			maximum_level = maxi(maximum_level, _maximum_level(sim))
		rows.append({
			"seed": seed_value,
			"turns": sim.turn,
			"score": sim.score,
			"game_over": sim.game_over,
			"turn_cap_reached": sim.turn >= turn_cap and not sim.game_over,
			"max_level_reached": maximum_level,
			"max_mass_reached": maximum_mass,
			"max_completions": sim.max_completions,
			"max_clears": sim.max_clears,
			"max_chain": sim.run_best_chain,
			"early_merge_count": early_merge_count,
			"early_turn_count": mini(sim.turn, 30),
			"seen_colors": _sorted_color_keys(seen_colors),
			"seen_color_count": seen_colors.size(),
		})
	return {
		"measurement_seconds": float(Time.get_ticks_msec() - started_msec) / 1000.0,
		"rows": rows,
		"choice_metrics": {
			"decision_turns": preview_decision_turns,
			"fatal_avoidance_turns": preview_fatal_avoidance_turns,
			"fatal_avoidance_turn_ratio": _safe_ratio(
				preview_fatal_avoidance_turns,
				preview_decision_turns
			),
			"unblocked_direction_spread_mean": _safe_ratio_float(
				preview_unblocked_spread_sum,
				preview_decision_turns
			),
			"score_gain_spread_median": _median(preview_score_gain_spreads),
			"unblocked_direction_spread_sum": preview_unblocked_spread_sum,
			"score_gain_spreads": preview_score_gain_spreads,
			"decision_usec_sum": preview_decision_usec_sum,
			"decision_milliseconds_per_turn": _safe_ratio_float(
				float(preview_decision_usec_sum) / 1000.0,
				preview_decision_turns
			),
		},
	}


func _choose_direction(
	sim: SlimeSim,
	strategy: String,
	bot_rng: RandomNumberGenerator
) -> Vector2i:
	if strategy == "r":
		return _random_direction(DIRECTIONS, bot_rng)
	var safe_candidates: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		if sim.entry_clearance_for(direction) >= 0.0:
			safe_candidates.append(direction)
	var found_safe_candidate: bool = not safe_candidates.is_empty()
	if not found_safe_candidate:
		safe_candidates = DIRECTIONS.duplicate()
	if strategy == "s":
		return _random_direction(safe_candidates, bot_rng)
	if found_safe_candidate:
		safe_candidates = _without_current_gravity_when_possible(
			safe_candidates,
			sim.gravity_direction
		)
	var best_count: int = -1
	var best_directions: Array[Vector2i] = []
	for direction: Vector2i in safe_candidates:
		var count: int = _count_reaction_pairs(sim, direction)
		if count > best_count:
			best_count = count
			best_directions = [direction]
		elif count == best_count:
			best_directions.append(direction)
	return _random_direction(best_directions, bot_rng)


func _choose_preview_direction(
	sim: SlimeSim,
	strategy: String,
	bot_rng: RandomNumberGenerator
) -> Dictionary:
	var decision_started_usec: int = Time.get_ticks_usec()
	var best_direction: Vector2i = DIRECTIONS[0]
	var best_metric: float = -INF
	var has_game_over: bool = false
	var has_survivor: bool = false
	var minimum_unblocked: int = 4
	var maximum_unblocked: int = 0
	var minimum_score_gain: int = 2147483647
	var maximum_score_gain: int = -2147483648
	for direction: Vector2i in DIRECTIONS:
		var trial: SlimeSim = sim.duplicate_sim()
		trial.next_slimes.clear()
		var score_before: int = trial.score
		trial.start_turn(direction)
		_run_until_idle(trial)
		var score_gain: int = trial.score - score_before
		var unblocked_count: int = _unblocked_direction_count(trial)
		has_game_over = has_game_over or trial.game_over
		has_survivor = has_survivor or not trial.game_over
		minimum_unblocked = mini(minimum_unblocked, unblocked_count)
		maximum_unblocked = maxi(maximum_unblocked, unblocked_count)
		minimum_score_gain = mini(minimum_score_gain, score_gain)
		maximum_score_gain = maxi(maximum_score_gain, score_gain)
		var metric: float = trial.entry_clearance_for(direction)
		if strategy == "preview_merge":
			metric += float(score_gain) * 3.0
		metric += bot_rng.randf() * 0.01
		if metric > best_metric:
			best_metric = metric
			best_direction = direction
	return {
		"direction": best_direction,
		"fatal_avoidance": has_game_over and has_survivor,
		"unblocked_direction_spread": maximum_unblocked - minimum_unblocked,
		"score_gain_spread": maximum_score_gain - minimum_score_gain,
		"decision_usec": Time.get_ticks_usec() - decision_started_usec,
	}


func _without_current_gravity_when_possible(
	candidates: Array[Vector2i],
	current_gravity: Vector2i
) -> Array[Vector2i]:
	if candidates.size() <= 1 or not candidates.has(current_gravity):
		return candidates
	var alternatives: Array[Vector2i] = []
	for direction: Vector2i in candidates:
		if direction != current_gravity:
			alternatives.append(direction)
	return alternatives if not alternatives.is_empty() else candidates


func _unblocked_direction_count(sim: SlimeSim) -> int:
	var count: int = 0
	for direction: Vector2i in DIRECTIONS:
		if sim.entry_clearance_for(direction) >= 0.0:
			count += 1
	return count


func _count_reaction_pairs(sim: SlimeSim, direction: Vector2i) -> int:
	var count: int = 0
	for first_index: int in range(sim.slimes.size()):
		var first: SlimeSim.SlimeBody = sim.slimes[first_index]
		for second_index: int in range(first_index + 1, sim.slimes.size()):
			var second: SlimeSim.SlimeBody = sim.slimes[second_index]
			var reacts: bool = first.color_index == second.color_index or (
				first.mass >= sim.config.max_mass
				and second.mass >= sim.config.max_mass
			)
			if not reacts:
				continue
			var offset: Vector2 = second.position - first.position
			var maximum_distance: float = (first.radius + second.radius) * 3.0
			if offset.is_zero_approx() or offset.length() > maximum_distance:
				continue
			if absf(offset.normalized().dot(Vector2(direction))) >= 0.8:
				count += 1
	return count


func _random_direction(
	candidates: Array[Vector2i],
	bot_rng: RandomNumberGenerator
) -> Vector2i:
	if candidates.is_empty():
		return Vector2i.DOWN
	return candidates[bot_rng.randi_range(0, candidates.size() - 1)]


func _run_until_idle(sim: SlimeSim) -> void:
	var safety: int = 0
	while sim.moving and safety < 180:
		sim.step(DT)
		safety += 1


func _maximum_mass(sim: SlimeSim) -> int:
	var maximum: int = 0
	for slime: SlimeSim.SlimeBody in sim.slimes:
		maximum = maxi(maximum, slime.mass)
	return maximum


func _maximum_level(sim: SlimeSim) -> int:
	var maximum: int = 0
	for slime: SlimeSim.SlimeBody in sim.slimes:
		maximum = maxi(maximum, slime.level)
	return maximum


func _record_seen_colors(sim: SlimeSim, seen_colors: Dictionary) -> void:
	for slime: SlimeSim.SlimeBody in sim.slimes:
		seen_colors[slime.color_index] = true


func _record_spawned_colors(events: Array[Dictionary], seen_colors: Dictionary) -> void:
	for event: Dictionary in events:
		if str(event.get("type", "")) == "spawned":
			seen_colors[int(event.get("color", 0))] = true


func _sorted_color_keys(seen_colors: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for color_value: Variant in seen_colors.keys():
		result.append(int(color_value))
	result.sort()
	return result


func _safe_ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator == 0 else float(numerator) / float(denominator)


func _safe_ratio_float(numerator: float, denominator: int) -> float:
	return 0.0 if denominator == 0 else numerator / float(denominator)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	var middle: int = sorted_values.size() / 2
	if sorted_values.size() % 2 == 1:
		return sorted_values[middle]
	return (sorted_values[middle - 1] + sorted_values[middle]) * 0.5


func _write_report(output_path: String, report: Dictionary) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write slime skill report: %s" % absolute_path)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")


func _int_argument(prefix: String, fallback: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return maxi(1, argument.trim_prefix(prefix).to_int())
	return fallback


func _string_argument(prefix: String, fallback: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback


func _strategy_argument() -> Array[String]:
	var requested: String = _string_argument("--strategies=", ",".join(STRATEGIES))
	var result: Array[String] = []
	for raw_strategy: String in requested.split(",", false):
		var strategy: String = raw_strategy.strip_edges().to_lower()
		if strategy in STRATEGIES and not result.has(strategy):
			result.append(strategy)
	if result.is_empty():
		result.append_array(STRATEGIES)
	return result


func _candidate_settings() -> Dictionary:
	return {
		"color_unlock_mode": _string_argument("--color-unlock-mode=", CONFIG.color_unlock_mode),
		"color_unlock_turns": _parse_int_list(
			_string_argument("--color-unlock-turns=", "")
		),
		"turn_floor_steps": _parse_floor_steps(
			_string_argument("--turn-floor-steps=", "")
		),
	}


func _apply_candidate_settings(config: SlimeConfig, settings: Dictionary) -> void:
	config.color_unlock_mode = str(settings["color_unlock_mode"])
	var unlock_turns: Array[int] = []
	for value: Variant in settings["color_unlock_turns"] as Array:
		unlock_turns.append(int(value))
	config.color_unlock_turns.assign(unlock_turns)
	var floor_steps: Array[Vector2i] = []
	for value: Variant in settings["turn_floor_steps"] as Array:
		var pair: Array = value as Array
		floor_steps.append(Vector2i(int(pair[0]), int(pair[1])))
	if not floor_steps.is_empty():
		config.turn_floor_steps.assign(floor_steps)


func _parse_int_list(value: String) -> Array[int]:
	var result: Array[int] = []
	for item: String in value.split(",", false):
		var stripped: String = item.strip_edges()
		if not stripped.is_empty():
			result.append(stripped.to_int())
	return result


func _parse_floor_steps(value: String) -> Array[Array]:
	var result: Array[Array] = []
	for item: String in value.split(",", false):
		var parts: PackedStringArray = item.strip_edges().split(":", false)
		if parts.size() == 2:
			result.append([parts[0].to_int(), parts[1].to_int()])
	return result
