extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const OUTPUT_PREFIX: String = "--output="
const SEED_PREFIX: String = "--seed="
const GRAVITY_STRENGTH_PREFIX: String = "--gravity-strength="
const GRAVITY_LEVEL_SCALE_PREFIX: String = "--gravity-level-scale="
const RUN_DURATION_SECONDS: float = 8.0
const FRAME_WARMUP_SECONDS: float = 0.5
const BOT_INTERVAL_SECONDS: float = 0.30
const FORCED_BLAST_TIME: float = 2.0
const FORCED_LARGE_BATCH_TIME: float = 4.05
const BURST_OFFSETS: Array[float] = [1.54, 2.04]
const DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
]

var _output_path: String = "res://artifacts/measurements/blitz_responsiveness.json"
var _seed: int = 101
var _main: Main
var _manager: BlitzManager
var _board: Board3D
var _requests: Array[Dictionary] = []
var _frame_samples_ms: Array[float] = []
var _draw_call_samples: Array[int] = []
var _input_latency_ms: Array[float] = []
var _spawn_latency_ms: Array[float] = []
var _last_process_usec: int = 0
var _record_frames: bool = false
var _pending_frame_marker: String = ""
var _marker_frames_ms: Dictionary = {}
var _direction_index: int = 0
var _request_id: int = 0
var _force_large_batch_pending: bool = false


func _ready() -> void:
	_parse_arguments()
	call_deferred("_run")


func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	if _last_process_usec > 0:
		var frame_ms: float = float(now_usec - _last_process_usec) / 1000.0
		if _record_frames:
			_frame_samples_ms.append(frame_ms)
			_draw_call_samples.append(RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			))
			if not _pending_frame_marker.is_empty():
				_marker_frames_ms[_pending_frame_marker] = frame_ms
				_pending_frame_marker = ""
	_last_process_usec = now_usec


func _run() -> void:
	Config.data.rng_seed = _seed
	_main = MAIN_SCENE.instantiate() as Main
	_main.launch_immediately(GameConfig.GameMode.BLITZ)
	add_child(_main)
	await get_tree().process_frame
	_manager = _main.get_node("BlitzManager") as BlitzManager
	_board = _main.get_node("Board") as Board3D
	(_main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(_main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	_manager.swipe_accepted.connect(_on_swipe_accepted)
	_manager.swipe_spawn_completed.connect(_on_swipe_spawn_completed)
	if not await _wait_for_running():
		push_error("BLITZ responsiveness measurement did not reach RUNNING")
		get_tree().quit(1)
		return

	var run_start_usec: int = Time.get_ticks_usec()
	var next_bot_time: float = 0.0
	var blast_forced: bool = false
	var large_batch_forced: bool = false
	var burst_done: Array[bool] = [false, false]
	while _seconds_since(run_start_usec) < RUN_DURATION_SECONDS:
		await get_tree().process_frame
		var elapsed: float = _seconds_since(run_start_usec)
		if elapsed >= FRAME_WARMUP_SECONDS:
			_record_frames = true
		while elapsed >= next_bot_time:
			_record_input(_next_direction())
			next_bot_time += BOT_INTERVAL_SECONDS
		for burst_index: int in range(BURST_OFFSETS.size()):
			if not burst_done[burst_index] and elapsed >= BURST_OFFSETS[burst_index]:
				burst_done[burst_index] = true
				_record_input(_next_direction())
		if not blast_forced and elapsed >= FORCED_BLAST_TIME:
			blast_forced = true
			_pending_frame_marker = "first_blast"
			var blast_levels: Array[int] = [
				Config.data.active_blast_min_level(),
				Config.data.active_blast_min_level(),
			]
			var blast_colors: Array[int] = [
				OrbTypes.OrbColor.RED,
				OrbTypes.OrbColor.BLUE,
			]
			_manager.on_reaction({
				"type": ReactionRules.Type.BLAST,
				"position": Vector2.ZERO,
				"levels": blast_levels,
				"colors": blast_colors,
				"shock_level": Config.data.active_blast_min_level(),
			})
		if not large_batch_forced and elapsed >= FORCED_LARGE_BATCH_TIME:
			large_batch_forced = true
			var original_refill_rule: BlitzManager.RefillRule = _manager.refill_rule
			_manager.refill_rule = BlitzManager.RefillRule.COUNT_DEBT
			_manager.refill_debt = Config.data.blitz_max_spawn_per_swipe
			_force_large_batch_pending = true
			_record_input(_next_direction())
			_manager.refill_rule = original_refill_rule
			_manager.refill_debt = 0

	_record_frames = false
	await get_tree().process_frame
	Engine.time_scale = 1.0
	var report: Dictionary = _build_report()
	var absolute_output: String = ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write responsiveness report: %s" % _output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("BLITZ_RESPONSIVENESS_SEED %s" % JSON.stringify(_summary_without_samples(report)))
	get_tree().quit(0)


func _wait_for_running() -> bool:
	var deadline_usec: int = Time.get_ticks_usec() + 5_000_000
	while Time.get_ticks_usec() < deadline_usec:
		if _manager != null and _manager.state == BlitzManager.State.RUNNING:
			return true
		await get_tree().process_frame
	return false


func _record_input(dir: Vector2i) -> void:
	_request_id += 1
	_requests.append({
		"id": _request_id,
		"dir": dir,
		"event_usec": Time.get_ticks_usec(),
		"accepted_usec": 0,
		"completed_usec": 0,
	})
	InputRouter.swipe.emit(dir)


func _on_swipe_accepted(dir: Vector2i) -> void:
	var request_index: int = _latest_pending_request(dir)
	if request_index < 0:
		return
	var request: Dictionary = _requests[request_index]
	request["accepted_usec"] = Time.get_ticks_usec()
	_requests[request_index] = request
	_input_latency_ms.append(
		float(int(request["accepted_usec"]) - int(request["event_usec"])) / 1000.0
	)


func _on_swipe_spawn_completed(dir: Vector2i, spawned_count: int) -> void:
	var request_index: int = _latest_incomplete_accepted_request(dir)
	if request_index >= 0:
		var request: Dictionary = _requests[request_index]
		request["completed_usec"] = Time.get_ticks_usec()
		_requests[request_index] = request
		_spawn_latency_ms.append(
			float(int(request["completed_usec"]) - int(request["accepted_usec"])) / 1000.0
		)
	if _force_large_batch_pending and spawned_count > 1:
		_force_large_batch_pending = false
		_pending_frame_marker = "first_large_batch"


func _latest_pending_request(dir: Vector2i) -> int:
	for index: int in range(_requests.size() - 1, -1, -1):
		var request: Dictionary = _requests[index]
		if int(request["accepted_usec"]) == 0 and request["dir"] == dir:
			return index
	return -1


func _latest_incomplete_accepted_request(dir: Vector2i) -> int:
	for index: int in range(_requests.size() - 1, -1, -1):
		var request: Dictionary = _requests[index]
		if (
			int(request["accepted_usec"]) > 0
			and int(request["completed_usec"]) == 0
			and request["dir"] == dir
		):
			return index
	return -1


func _next_direction() -> Vector2i:
	for _attempt: int in range(DIRECTIONS.size()):
		var dir: Vector2i = DIRECTIONS[_direction_index % DIRECTIONS.size()]
		_direction_index += 1
		if dir != _manager.gravity:
			return dir
	return -_manager.gravity


func _build_report() -> Dictionary:
	var dropped_inputs: int = 0
	for request: Dictionary in _requests:
		if int(request["accepted_usec"]) == 0:
			dropped_inputs += 1
	return {
		"seed": _seed,
		"gravity_strength": Config.data.gravity_strength,
		"gravity_level_scale": Config.data.gravity_level_scale,
		"duration_seconds": RUN_DURATION_SECONDS,
		"frame_samples_ms": _frame_samples_ms,
		"draw_call_samples": _draw_call_samples,
		"input_latency_ms": _input_latency_ms,
		"spawn_latency_ms": _spawn_latency_ms,
		"requested_inputs": _requests.size(),
		"accepted_inputs": _input_latency_ms.size(),
		"dropped_inputs": dropped_inputs,
		"first_blast_frame_ms": float(_marker_frames_ms.get("first_blast", -1.0)),
		"first_large_batch_frame_ms": float(
			_marker_frames_ms.get("first_large_batch", -1.0)
		),
		"max_spawn_batch": _manager.max_spawn_batch,
		"renderer": RenderingServer.get_video_adapter_name(),
		"shared_resources": Orb3D.shared_resource_counts(),
	}


func _summary_without_samples(report: Dictionary) -> Dictionary:
	var summary: Dictionary = report.duplicate(true)
	summary.erase("frame_samples_ms")
	summary.erase("draw_call_samples")
	summary.erase("input_latency_ms")
	summary.erase("spawn_latency_ms")
	return summary


func _seconds_since(start_usec: int) -> float:
	return float(Time.get_ticks_usec() - start_usec) / 1_000_000.0


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_PREFIX):
			_output_path = argument.trim_prefix(OUTPUT_PREFIX)
		elif argument.begins_with(SEED_PREFIX):
			_seed = argument.trim_prefix(SEED_PREFIX).to_int()
		elif argument.begins_with(GRAVITY_STRENGTH_PREFIX):
			Config.data.gravity_strength = argument.trim_prefix(
				GRAVITY_STRENGTH_PREFIX
			).to_float()
		elif argument.begins_with(GRAVITY_LEVEL_SCALE_PREFIX):
			Config.data.gravity_level_scale = argument.trim_prefix(
				GRAVITY_LEVEL_SCALE_PREFIX
			).to_float()
