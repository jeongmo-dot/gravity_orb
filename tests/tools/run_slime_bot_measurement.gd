extends SceneTree

const CONFIG: SlimeConfig = preload("res://config/slime_config.tres")
const DT: float = 1.0 / 60.0
const DEFAULT_SEED_COUNT: int = 100
const DEFAULT_TURN_CAP: int = 250
const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var seed_count: int = _int_argument("--seed-count=", DEFAULT_SEED_COUNT)
	var turn_cap: int = _int_argument("--turn-cap=", DEFAULT_TURN_CAP)
	var strategies: Array[String] = ["random", "space", "merge"]
	var threads: Array[Thread] = []
	for strategy: String in ["random", "space", "merge"]:
		var worker := Thread.new()
		worker.start(Callable(self, "_measure_strategy").bind(strategy, seed_count, turn_cap))
		threads.append(worker)
	for index: int in range(threads.size()):
		var result: Dictionary = threads[index].wait_to_finish() as Dictionary
		result["strategy"] = strategies[index]
		print("SLIME_BOT_RESULT ", JSON.stringify(result))
	print("SLIME_BOT_MEASUREMENT_COMPLETE strategies=3 seeds=%d turn_cap=%d" % [seed_count, turn_cap])
	quit(0)


func _measure_strategy(strategy: String, seed_count: int, turn_cap: int) -> Dictionary:
	var turns: Array[float] = []
	var scores: Array[float] = []
	var turn_times: Array[float] = []
	var color_distribution: Dictionary = {}
	var reached_cap: int = 0
	var total_max_completions: int = 0
	var total_max_clears: int = 0
	var total_final_moves: int = 0
	var total_final_successes: int = 0
	var total_intro_cancels: int = 0
	var maximum_slimes: int = 0
	for seed_value: int in range(1, seed_count + 1):
		var sim := SlimeSim.new(CONFIG, seed_value, false, true)
		var bot_rng := RandomNumberGenerator.new()
		bot_rng.seed = 0xB070000 + seed_value * 97 + strategy.hash()
		_run_until_idle(sim)
		while not sim.game_over and sim.turn < turn_cap:
			var direction: Vector2i = _choose_direction(sim, strategy, bot_rng)
			if not sim.start_turn(direction):
				break
			_run_until_idle(sim)
		if sim.turn >= turn_cap and not sim.game_over:
			reached_cap += 1
		turns.append(float(sim.turn))
		scores.append(float(sim.score))
		turn_times.append_array(sim.completed_turn_durations)
		var color_key: String = str(sim.active_color_count)
		color_distribution[color_key] = int(color_distribution.get(color_key, 0)) + 1
		total_max_completions += sim.max_completions
		total_max_clears += sim.max_clears
		total_final_moves += sim.final_move_count
		total_final_successes += sim.final_move_success_count
		total_intro_cancels += sim.intro_cancel_count
		maximum_slimes = maxi(maximum_slimes, sim.maximum_slime_count)
		if seed_value % 10 == 0 or seed_value == seed_count:
			print("SLIME_BOT_PROGRESS strategy=%s seed=%d/%d" % [strategy, seed_value, seed_count])
	return {
		"games": seed_count,
		"turn_mean": _mean(turns),
		"turn_median": _percentile(turns, 0.50),
		"turn_cap_reached": reached_cap,
		"score_mean": _mean(scores),
		"score_median": _percentile(scores, 0.50),
		"final_color_count_distribution": color_distribution,
		"max_completions_mean": float(total_max_completions) / float(seed_count),
		"max_clears_mean": float(total_max_clears) / float(seed_count),
		"final_move_count": total_final_moves,
		"final_move_success_rate": (
			0.0
			if total_final_moves == 0
			else float(total_final_successes) / float(total_final_moves)
		),
		"intro_cancels_mean": float(total_intro_cancels) / float(seed_count),
		"turn_time_p50": _percentile(turn_times, 0.50),
		"turn_time_p95": _percentile(turn_times, 0.95),
		"maximum_slimes": maximum_slimes,
	}


func _choose_direction(sim: SlimeSim, strategy: String, bot_rng: RandomNumberGenerator) -> Vector2i:
	if strategy == "random":
		return DIRECTIONS[bot_rng.randi_range(0, DIRECTIONS.size() - 1)]
	var best_direction: Vector2i = DIRECTIONS[0]
	var best_metric: float = -INF
	for direction: Vector2i in DIRECTIONS:
		var trial: SlimeSim = sim.duplicate_sim()
		trial.next_slimes.clear()
		var score_before: int = trial.score
		trial.start_turn(direction)
		_run_until_idle(trial)
		var clearance: float = trial.entry_clearance_for(direction)
		var metric: float = clearance
		if strategy == "merge":
			metric += float(trial.score - score_before) * 3.0
		metric += bot_rng.randf() * 0.01
		if metric > best_metric:
			best_metric = metric
			best_direction = direction
	return best_direction


func _run_until_idle(sim: SlimeSim) -> void:
	var safety: int = 0
	while sim.moving and safety < 180:
		sim.step(DT)
		safety += 1


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var position: float = clampf(percentile, 0.0, 1.0) * float(sorted.size() - 1)
	var lower: int = int(floor(position))
	var upper: int = int(ceil(position))
	return lerpf(sorted[lower], sorted[upper], position - float(lower))


func _int_argument(prefix: String, fallback: int) -> int:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return maxi(1, argument.trim_prefix(prefix).to_int())
	return fallback
