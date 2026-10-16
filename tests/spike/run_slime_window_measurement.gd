extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/SlimeMain.tscn")
const OUTPUT_PREFIX: String = "--output="
const WARMUP_SECONDS: float = 0.8
const MEASUREMENT_SECONDS: float = 5.0
const BOARD: Rect2 = Rect2(45.0, 180.0, 550.0, 700.0)

var _output_path: String = "res://artifacts/measurements/slime_window.json"
var _game: SlimeGame
var _sim: SlimeSim
var _frame_samples_ms: Array[float] = []
var _draw_call_samples: Array[int] = []
var _last_process_usec: int = 0
var _recording: bool = false


func _ready() -> void:
	_parse_arguments()
	call_deferred("_run")


func _process(delta: float) -> void:
	if _sim != null:
		_advance_showcase(delta)
	var now_usec: int = Time.get_ticks_usec()
	if _recording and _last_process_usec > 0:
		_frame_samples_ms.append(float(now_usec - _last_process_usec) / 1000.0)
		_draw_call_samples.append(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		))
	_last_process_usec = now_usec


func _run() -> void:
	_game = MAIN_SCENE.instantiate() as SlimeGame
	add_child(_game)
	await get_tree().process_frame
	_game.set_physics_process(false)
	_sim = _game.get_sim()
	_sim.reset(8080, false)
	_sim.gravity_direction = Vector2i.DOWN
	_sim.moving = true
	_sim.message = "중력 이동 중..."
	for index: int in range(40):
		var column: int = index % 8
		var row: int = index / 8
		var velocity := Vector2(
			180.0 if (column + row) % 2 == 0 else -180.0,
			125.0 if row % 2 == 0 else -125.0
		)
		var body: SlimeSim.SlimeBody = _sim.add_slime(
			Vector2(82.0 + float(column) * 68.0, 225.0 + float(row) * 140.0),
			0,
			index % 7,
			velocity
		)
		body.visual_scale = 1.0
	_game.refresh_presentation()
	await _wait_seconds(WARMUP_SECONDS)
	_last_process_usec = Time.get_ticks_usec()
	_recording = true
	await _wait_seconds(MEASUREMENT_SECONDS)
	_recording = false
	var report: Dictionary = {
		"duration_seconds": MEASUREMENT_SECONDS,
		"slime_count": _sim.slimes.size(),
		"frame_samples_ms": _frame_samples_ms,
		"draw_call_samples": _draw_call_samples,
		"renderer": RenderingServer.get_video_adapter_name(),
		"vsync_mode": int(DisplayServer.window_get_vsync_mode()),
	}
	var absolute_output: String = ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write slime window measurement report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SLIME_WINDOW_MEASUREMENT samples=%d slimes=%d" % [_frame_samples_ms.size(), _sim.slimes.size()])
	get_tree().quit(0)


func _advance_showcase(delta: float) -> void:
	for body: SlimeSim.SlimeBody in _sim.slimes:
		body.position += body.velocity * delta
		var minimum := BOARD.position + Vector2.ONE * body.radius
		var maximum := BOARD.end - Vector2.ONE * body.radius
		if body.position.x <= minimum.x or body.position.x >= maximum.x:
			body.velocity.x *= -1.0
		if body.position.y <= minimum.y or body.position.y >= maximum.y:
			body.velocity.y *= -1.0
		body.position = body.position.clamp(minimum, maximum)
		var stretch: float = clampf(body.velocity.length() / 1400.0, 0.0, 0.19)
		body.deform = body.deform.lerp(Vector2(1.0 - stretch * 0.55, 1.0 + stretch), minf(delta * 11.0, 1.0))
		body.roll += body.velocity.x / maxf(body.radius, 1.0) * delta * 0.86
	(_game.get_node("Content/SlimeView") as SlimeView).advance_visuals(delta)
	_game.refresh_presentation()


func _wait_seconds(seconds: float) -> void:
	var started_usec: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started_usec) / 1_000_000.0 < seconds:
		await get_tree().process_frame


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_PREFIX):
			_output_path = argument.trim_prefix(OUTPUT_PREFIX)
