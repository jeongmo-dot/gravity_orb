extends Node

const OUTPUT_PREFIX: String = "--full-board-performance-output="
const LABEL_PREFIX: String = "--full-board-performance-label="
const MERGE_DURATION_PREFIX: String = "--jelly-merge-duration="
const WINDOW_SIZE: Vector2i = Vector2i(540, 960)
const WARMUP_SECONDS: float = 0.75
const SAMPLE_SECONDS: float = 4.0
const MERGE_SAMPLE_SECONDS: float = 2.0

var _main: Main
var _board: Board3D
var _turn_manager: TurnManager
var _resolver: CollisionResolver
var _spawner: Spawner
var _simulate: bool = false
var _recording: bool = false
var _last_process_usec: int = 0
var _physics_steps_since_draw: int = 0
var _scenario_game_seconds: float = 0.0
var _scenario_real_started_usec: int = 0
var _samples: Dictionary = {}
var _merge_activation_pairs: Array[Array] = []
var _scenario_physics_step: int = 0


func configure(main: Main) -> void:
	_main = main
	_board = main.get_node("Board") as Board3D
	_turn_manager = main.get_node("TurnManager") as TurnManager
	_resolver = main.get_node("CollisionResolver") as CollisionResolver
	_spawner = main.get_node("Spawner") as Spawner
	call_deferred("_run")


func _physics_process(delta: float) -> void:
	if not _simulate:
		return
	_physics_steps_since_draw += 1
	_scenario_game_seconds += delta
	_activate_scheduled_merge_pairs()
	_scenario_physics_step += 1
	var total_started_usec: int = Time.get_ticks_usec()
	_board._advance_gravity_transition()
	var waiter_started_usec: int = Time.get_ticks_usec()
	_board._update_entrance_waiters()
	_record_duration("waiter_update_ms", waiter_started_usec)
	var ghost_started_usec: int = Time.get_ticks_usec()
	_board._update_ghost_orbs(delta)
	_record_duration("ghost_update_ms", ghost_started_usec)
	var flush_started_usec: int = Time.get_ticks_usec()
	_resolver.flush(delta)
	_record_duration("collision_flush_ms", flush_started_usec)
	var settle_started_usec: int = Time.get_ticks_usec()
	_turn_manager._all_below_threshold()
	_record_duration("settle_check_ms", settle_started_usec)
	_record_duration("script_physics_total_ms", total_started_usec)


func _process(_delta: float) -> void:
	if not _recording:
		_last_process_usec = Time.get_ticks_usec()
		_physics_steps_since_draw = 0
		return
	var now_usec: int = Time.get_ticks_usec()
	if _last_process_usec > 0:
		_record_value("frame_ms", float(now_usec - _last_process_usec) / 1000.0)
	_record_value("physics_steps_per_draw", float(_physics_steps_since_draw))
	if _physics_steps_since_draw > 0:
		_record_value(
			"physics_monitor_ms_per_step",
			Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			/ float(_physics_steps_since_draw)
		)
	_record_value(
		"process_monitor_ms",
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	)
	_record_value(
		"draw_calls",
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	)
	_last_process_usec = now_usec
	_physics_steps_since_draw = 0


func _run() -> void:
	Config.data.jelly_merge_duration = maxf(
		_argument_value(
			MERGE_DURATION_PREFIX,
			str(Config.data.jelly_merge_duration)
		).to_float(),
		0.0
	)
	DisplayServer.window_set_size(WINDOW_SIZE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_turn_manager.set_physics_process(false)
	_board.set_physics_process(false)
	var results: Dictionary = {
		"label": _argument_value(LABEL_PREFIX, "unlabeled"),
		"engine": Engine.get_version_info(),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"window": [WINDOW_SIZE.x, WINDOW_SIZE.y],
		"vsync": "disabled",
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"jelly_merge_duration": Config.data.jelly_merge_duration,
		"scenarios": [],
	}
	await _prepare_full_board(false)
	(results["scenarios"] as Array).append(
		await _measure_scenario("01_stopped_120", SAMPLE_SECONDS, true)
	)
	await _prepare_full_board(true)
	(results["scenarios"] as Array).append(
		await _measure_scenario("02_stopped_120_waiters_16", SAMPLE_SECONDS, true)
	)
	await _prepare_merge_heavy_board()
	(results["scenarios"] as Array).append(
		await _measure_scenario("03_merge_heavy_turn_75", MERGE_SAMPLE_SECONDS, false)
	)
	results["microbenchmarks"] = await _measure_microbenchmarks()
	var output_path: String = _argument_value(
		OUTPUT_PREFIX,
		ProjectSettings.globalize_path("res://artifacts/full_board_performance.json")
	)
	var directory_path: String = output_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(directory_path)
	var output: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error("Could not write full-board performance output: %s" % output_path)
		get_tree().quit(1)
		return
	output.store_string(JSON.stringify(results, "\t"))
	output.close()
	print("FULL_BOARD_PERFORMANCE_OUTPUT=%s" % output_path)
	get_tree().quit(0)


func _prepare_full_board(add_waiters: bool) -> void:
	_simulate = false
	_recording = false
	_merge_activation_pairs.clear()
	_board.clear()
	_resolver._pending.clear()
	_resolver._reaction_locks.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	for column: int in range(18):
		_spawn_stopped_orb(
			column % 4,
			1,
			Vector2(-425.0 + float(column) * 50.0, -425.0)
		)
	for row: int in range(9):
		for column: int in range(11):
			_spawn_stopped_orb(
				(column + row) % 4,
				2,
				Vector2(-400.0 + float(column) * 80.0, -320.0 + float(row) * 80.0)
			)
	for column: int in range(3):
		_spawn_stopped_orb(column % 4, 1, Vector2(-150.0 + float(column) * 150.0, 420.0))
	if add_waiters:
		for index: int in range(16):
			var waiter: Orb3D = _board.spawn_orb(
				index % 4,
				1,
				Vector2(-420.0 + float(index) * 56.0, -451.0)
			)
			waiter.enter_entrance_wait(waiter.position, Vector2i.DOWN)
	_simulate = true
	await _wait_real_seconds(WARMUP_SECONDS)


func _prepare_merge_heavy_board() -> void:
	_simulate = false
	_recording = false
	_merge_activation_pairs.clear()
	_board.clear()
	_resolver._pending.clear()
	_resolver._reaction_locks.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	for row: int in range(6):
		for column: int in range(9):
			var center: Vector2 = Vector2(
				-416.0 + float(column) * 104.0,
				-350.0 + float(row) * 140.0
			)
			var pair_index: int = row * 9 + column
			var color: int = (column + row) % 4
			if pair_index < 8:
				var first: Orb3D = _spawn_stopped_orb(
					color,
					1,
					center + Vector2(0.0, -35.0)
				)
				var second: Orb3D = _spawn_stopped_orb(
					color,
					1,
					center + Vector2(0.0, 35.0)
				)
				_merge_activation_pairs.append([first, second, center])
			else:
				_spawn_stopped_orb(color, 1, center + Vector2(-25.0, 0.0))
				_spawn_stopped_orb(
					(color + 1) % 4,
					1,
					center + Vector2(25.0, 0.0)
				)
	for column: int in range(12):
		_spawn_stopped_orb(
			column % 4,
			1,
			Vector2(-412.5 + float(column) * 75.0, 425.0)
		)
	for orb: Orb3D in _board.get_orbs():
		orb.get_physics_body().freeze = true
	await _wait_real_seconds(0.5)


func _spawn_stopped_orb(color: int, level: int, position: Vector2) -> Orb3D:
	var orb: Orb3D = _board.spawn_orb(color, level, position)
	orb.set_gravity_vector(Vector2.ZERO, 0.0)
	orb.linear_velocity = Vector2.ZERO
	orb.angular_velocity = 0.0
	return orb


func _activate_scheduled_merge_pairs() -> void:
	if _merge_activation_pairs.is_empty() or _scenario_physics_step % 12 != 0:
		return
	var activation_index: int = _scenario_physics_step / 12
	var start_index: int = activation_index * 2
	for pair_index: int in range(start_index, mini(start_index + 2, _merge_activation_pairs.size())):
		var pair: Array = _merge_activation_pairs[pair_index]
		var first_value: Variant = pair[0]
		var second_value: Variant = pair[1]
		if not is_instance_valid(first_value) or not is_instance_valid(second_value):
			continue
		var first: Orb3D = first_value as Orb3D
		var second: Orb3D = second_value as Orb3D
		var center: Vector2 = pair[2] as Vector2
		first.position = center + Vector2(0.0, -25.0)
		second.position = center + Vector2(0.0, 25.0)
		first.linear_velocity = Vector2.ZERO
		second.linear_velocity = Vector2.ZERO


func _measure_scenario(
	name: String,
	duration_seconds: float,
	warm_before_recording: bool
) -> Dictionary:
	if warm_before_recording:
		await _wait_real_seconds(0.25)
	_samples.clear()
	_scenario_game_seconds = 0.0
	_scenario_physics_step = 0
	_scenario_real_started_usec = Time.get_ticks_usec()
	_last_process_usec = _scenario_real_started_usec
	_physics_steps_since_draw = 0
	_recording = true
	_simulate = true
	await _wait_real_seconds(duration_seconds)
	_recording = false
	var real_elapsed_seconds: float = (
		float(Time.get_ticks_usec() - _scenario_real_started_usec) / 1000000.0
	)
	var result: Dictionary = {
		"name": name,
		"orbs": _board.get_orbs().size(),
		"waiters": _board.entrance_waiting_orbs().size(),
		"real_seconds": real_elapsed_seconds,
		"game_seconds": _scenario_game_seconds,
		"game_time_to_real_time": (
			_scenario_game_seconds / real_elapsed_seconds
			if real_elapsed_seconds > 0.0
			else 0.0
		),
		"metrics": _summarize_samples(_samples),
	}
	_simulate = false
	return result


func _measure_microbenchmarks() -> Dictionary:
	await _prepare_full_board(true)
	_simulate = false
	var result: Dictionary = {}
	result["get_orbs_ms"] = _benchmark_callable(func() -> void: _board.get_orbs(), 240)
	result["collision_scan_ms"] = _benchmark_callable(
		func() -> void: _resolver.measure_proximity_scan_usec(),
		120
	)
	result["pending_reaction_ms"] = _benchmark_callable(
		func() -> void: _resolver.has_pending_reactions(),
		240
	)
	result["warning_scan_ms"] = _benchmark_callable(
		func() -> void: _board.blocked_spawn_directions(_spawner.peek_next()),
		30
	)
	return result


func _benchmark_callable(callable: Callable, count: int) -> Dictionary:
	var values: Array[float] = []
	for _index: int in range(count):
		var started_usec: int = Time.get_ticks_usec()
		callable.call()
		values.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
	return _statistics(values)


func _wait_real_seconds(seconds: float) -> void:
	var end_usec: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < end_usec:
		await get_tree().process_frame


func _record_duration(name: String, started_usec: int) -> void:
	if not _recording:
		return
	_record_value(name, float(Time.get_ticks_usec() - started_usec) / 1000.0)


func _record_value(name: String, value: float) -> void:
	if not _recording:
		return
	var values: Array = _samples.get(name, []) as Array
	values.append(value)
	_samples[name] = values


func _summarize_samples(samples: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for name_value: Variant in samples.keys():
		var name: String = str(name_value)
		var typed_values: Array[float] = []
		for value: Variant in samples[name] as Array:
			typed_values.append(float(value))
		result[name] = _statistics(typed_values)
	return result


func _statistics(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "p50": 0.0, "p99": 0.0, "max": 0.0}
	var sorted_values: Array[float] = values.duplicate()
	sorted_values.sort()
	return {
		"count": sorted_values.size(),
		"p50": sorted_values[_percentile_index(sorted_values.size(), 0.50)],
		"p99": sorted_values[_percentile_index(sorted_values.size(), 0.99)],
		"max": sorted_values[-1],
	}


func _percentile_index(size: int, percentile: float) -> int:
	return clampi(ceili(float(size) * percentile) - 1, 0, size - 1)


func _argument_value(prefix: String, fallback: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback
