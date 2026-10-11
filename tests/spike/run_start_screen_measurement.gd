extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const OUTPUT_PREFIX: String = "--output="
const WARMUP_SECONDS: float = 0.5
const MEASUREMENT_SECONDS: float = 5.0

var _output_path: String = "res://artifacts/measurements/start_screen.json"
var _frame_samples_ms: Array[float] = []
var _draw_call_samples: Array[int] = []
var _last_process_usec: int = 0
var _recording: bool = false


func _ready() -> void:
	_parse_arguments()
	call_deferred("_run")


func _process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	if _recording and _last_process_usec > 0:
		_frame_samples_ms.append(float(now_usec - _last_process_usec) / 1000.0)
		_draw_call_samples.append(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
		))
	_last_process_usec = now_usec


func _run() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	(main.get_node("ScoreManager") as ScoreManager).save_path = ""
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = ""
	add_child(main)
	await get_tree().process_frame
	await _wait_seconds(WARMUP_SECONDS)
	_last_process_usec = Time.get_ticks_usec()
	_recording = true
	await _wait_seconds(MEASUREMENT_SECONDS)
	_recording = false
	var report: Dictionary = {
		"duration_seconds": MEASUREMENT_SECONDS,
		"frame_samples_ms": _frame_samples_ms,
		"draw_call_samples": _draw_call_samples,
		"renderer": RenderingServer.get_video_adapter_name(),
		"vsync_mode": int(DisplayServer.window_get_vsync_mode()),
		"viewport_size": {
			"x": get_viewport().get_visible_rect().size.x,
			"y": get_viewport().get_visible_rect().size.y,
		},
	}
	var absolute_output: String = ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write start-screen measurement report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("START_SCREEN_MEASUREMENT samples=%d" % _frame_samples_ms.size())
	get_tree().quit(0)


func _wait_seconds(seconds: float) -> void:
	var started_usec: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started_usec) / 1_000_000.0 < seconds:
		await get_tree().process_frame


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_PREFIX):
			_output_path = argument.trim_prefix(OUTPUT_PREFIX)
