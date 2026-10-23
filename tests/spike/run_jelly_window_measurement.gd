extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const OUTPUT_PREFIX: String = "--output="
const WARMUP_SECONDS: float = 0.8
const MEASUREMENT_SECONDS: float = 5.0
const BOARD_HALF: float = 440.0

var _output_path: String = "res://artifacts/measurements/jelly_window.json"
var _main: Main
var _board: Board3D
var _orbs: Array[Orb3D] = []
var _frame_samples_ms: Array[float] = []
var _draw_call_samples: Array[int] = []
var _last_process_usec: int = 0
var _recording: bool = false


func _ready() -> void:
	_parse_arguments()
	call_deferred("_run")


func _process(delta: float) -> void:
	for orb: Orb3D in _orbs:
		var next_position: Vector2 = orb.position + orb.linear_velocity * delta
		var limit: float = BOARD_HALF - orb.get_current_radius()
		var velocity: Vector2 = orb.linear_velocity
		if absf(next_position.x) >= limit:
			velocity.x *= -1.0
		if absf(next_position.y) >= limit:
			velocity.y *= -1.0
		orb.linear_velocity = velocity
		orb.position = next_position.clamp(Vector2.ONE * -limit, Vector2.ONE * limit)
		orb._process(delta)
	var now_usec: int = Time.get_ticks_usec()
	if _recording and _last_process_usec > 0:
		_frame_samples_ms.append(float(now_usec - _last_process_usec) / 1000.0)
		_draw_call_samples.append(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		))
	_last_process_usec = now_usec


func _run() -> void:
	Main.queue_mode(GameConfig.GameMode.JELLY)
	_main = MAIN_SCENE.instantiate() as Main
	add_child(_main)
	await get_tree().process_frame
	_board = _main.get_node("Board") as Board3D
	(_main.get_node("TurnManager") as TurnManager).set_physics_process(false)
	(_main.get_node("BlitzManager") as BlitzManager).set_physics_process(false)
	for existing: Orb3D in _board.get_orbs().duplicate():
		_board.remove_orb(existing)
	for index: int in range(40):
		var column: int = index % 8
		var row: int = index / 8
		var orb: Orb3D = _board.spawn_orb(
			index % JellyOrbArt.PALETTE.size(),
			1 + index % 3,
			Vector2(-350.0 + float(column) * 100.0, -300.0 + float(row) * 150.0)
		)
		orb.disable_physics()
		orb.linear_velocity = Vector2(
			520.0 if (column + row) % 2 == 0 else -520.0,
			360.0 if row % 2 == 0 else -360.0
		)
		_orbs.append(orb)
	await _wait_seconds(WARMUP_SECONDS)
	_last_process_usec = Time.get_ticks_usec()
	_recording = true
	await _wait_seconds(MEASUREMENT_SECONDS)
	_recording = false
	var report: Dictionary = {
		"duration_seconds": MEASUREMENT_SECONDS,
		"jelly_count": _orbs.size(),
		"frame_samples_ms": _frame_samples_ms,
		"draw_call_samples": _draw_call_samples,
		"renderer": RenderingServer.get_video_adapter_name(),
		"vsync_mode": int(DisplayServer.window_get_vsync_mode()),
	}
	var absolute_output: String = ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write JELLY window measurement report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("JELLY_WINDOW_MEASUREMENT samples=%d orbs=%d" % [_frame_samples_ms.size(), _orbs.size()])
	get_tree().quit(0)


func _wait_seconds(seconds: float) -> void:
	var started_usec: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started_usec) / 1_000_000.0 < seconds:
		await get_tree().process_frame


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_PREFIX):
			_output_path = argument.trim_prefix(OUTPUT_PREFIX)
