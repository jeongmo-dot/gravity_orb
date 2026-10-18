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
	var turn_cap: int = _int_argument("--turn-cap=", DEFAULT_TURN_CAP)
	var output_path: String = _string_argument("--output=", DEFAULT_OUTPUT)
	var threads: Array[Thread] = []
	for strategy: String in STRATEGIES:
		var worker := Thread.new()
		worker.start(Callable(self, "_measure_strategy").bind(strategy, seed_count, turn_cap))
		threads.append(worker)
	var strategy_reports: Dictionary = {}
	for index: int in range(threads.size()):
		var result: Dictionary = threads[index].wait_to_finish() as Dictionary
		strategy_reports[STRATEGIES[index]] = result
		print(
			"MODE_SKILL_SLIME strategy=%s seeds=%d seconds=%.3f"
			% [STRATEGIES[index], seed_count, float(result["measurement_seconds"])]
		)
	var report: Dictionary = {
		"mode": "slime",
		"seed_count": seed_count,
		"turn_cap": turn_cap,
		"strategies": strategy_reports,
	}
	_write_report(output_path, report)
	print("MODE_SKILL_SLIME_RESULT path=%s exit=0" % output_path)
	quit(0)


func _measure_strategy(strategy: String, seed_count: int, turn_cap: int) -> Dictionary:
	var started_msec: int = Time.get_ticks_msec()
	var rows: Array[Dictionary] = []
	for seed_value: int in range(1, seed_count + 1):
		var sim := SlimeSim.new(CONFIG, seed_value, false, true)
		var bot_rng := RandomNumberGenerator.new()
		bot_rng.seed = 0x5A1E0000 + seed_value * 131 + strategy.hash()
		_run_until_idle(sim)
		var maximum_mass: int = _maximum_mass(sim)
		var maximum_level: int = _maximum_level(sim)
		while not sim.game_over and sim.turn < turn_cap:
			var direction: Vector2i = _choose_direction(sim, strategy, bot_rng)
			if not sim.start_turn(direction):
				break
			_run_until_idle(sim)
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
		})
	return {
		"measurement_seconds": float(Time.get_ticks_msec() - started_msec) / 1000.0,
		"rows": rows,
	}


func _choose_direction(
	sim: SlimeSim,
	strategy: String,
	bot_rng: RandomNumberGenerator
) -> Vector2i:
	if strategy == "r":
		return _random_direction(DIRECTIONS, bot_rng)
	if strategy == "preview_space" or strategy == "preview_merge":
		return _choose_preview_direction(sim, strategy, bot_rng)
	var safe_candidates: Array[Vector2i] = []
	for direction: Vector2i in DIRECTIONS:
		if sim.entry_clearance_for(direction) >= 0.0:
			safe_candidates.append(direction)
	if safe_candidates.is_empty():
		safe_candidates = DIRECTIONS.duplicate()
	if strategy == "s":
		return _random_direction(safe_candidates, bot_rng)
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
) -> Vector2i:
	var best_direction: Vector2i = DIRECTIONS[0]
	var best_metric: float = -INF
	for direction: Vector2i in DIRECTIONS:
		var trial: SlimeSim = sim.duplicate_sim()
		trial.next_slimes.clear()
		var score_before: int = trial.score
		trial.start_turn(direction)
		_run_until_idle(trial)
		var metric: float = trial.entry_clearance_for(direction)
		if strategy == "preview_merge":
			metric += float(trial.score - score_before) * 3.0
		metric += bot_rng.randf() * 0.01
		if metric > best_metric:
			best_metric = metric
			best_direction = direction
	return best_direction


func _count_reaction_pairs(sim: SlimeSim, direction: Vector2i) -> int:
	var count: int = 0
	for first_index: int in range(sim.slimes.size()):
		var first: SlimeSim.SlimeBody = sim.slimes[first_index]
		for second_index: int in range(first_index + 1, sim.slimes.size()):
			var second: SlimeSim.SlimeBody = sim.slimes[second_index]
			var reacts: bool = first.color_index == second.color_index or (
				first.mass >= CONFIG.max_mass
				and second.mass >= CONFIG.max_mass
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
