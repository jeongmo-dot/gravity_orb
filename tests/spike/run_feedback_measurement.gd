extends Node3D

const OUTPUT_PATH: String = "res://artifacts/feedback_frame_measurement.json"
const WARMUP_FRAMES: int = 30
const SAMPLE_FRAMES: int = 180


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Config.data.fx_enabled = true
	Config.data.fx_hitstop_enabled = false
	Config.data.sfx_enabled = false
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)
	var director: FeedbackDirector = FeedbackDirector.new()
	add_child(director)
	await get_tree().process_frame
	for warmup_index: int in range(WARMUP_FRAMES):
		await get_tree().process_frame
	_emit_simultaneous_burst(director)
	await get_tree().create_timer(1.6).timeout
	director.clear_effects()
	await get_tree().process_frame
	var frame_times_ms: Array[float] = []
	var previous_ticks: int = Time.get_ticks_usec()
	for frame_index: int in range(SAMPLE_FRAMES):
		if frame_index == 0:
			_emit_simultaneous_burst(director)
		await get_tree().process_frame
		var ticks: int = Time.get_ticks_usec()
		frame_times_ms.append(float(ticks - previous_ticks) / 1000.0)
		previous_ticks = ticks
	frame_times_ms.sort()
	var over_16_7_count: int = _count_over(frame_times_ms, 16.7)
	var over_33_3_count: int = _count_over(frame_times_ms, 33.3)
	var p99: float = _percentile(frame_times_ms, 0.99)
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"sample_frames": SAMPLE_FRAMES,
		"burst": {"blasts": 3, "merges": 10},
		"frame_ms_p50": _percentile(frame_times_ms, 0.50),
		"frame_ms_p95": _percentile(frame_times_ms, 0.95),
		"frame_ms_p99": p99,
		"frame_ms_max": frame_times_ms[-1],
		"frames_over_16_7_ms": over_16_7_count,
		"frames_over_33_3_ms": over_33_3_count,
		"passes": p99 < 16.7 and over_33_3_count == 0,
	}
	_write_report(report)
	print("FEEDBACK_PERF %s" % JSON.stringify(report))
	get_tree().quit(0 if bool(report["passes"]) else 1)


func _emit_simultaneous_burst(director: FeedbackDirector) -> void:
	for blast_index: int in range(3):
		director.play_reaction({
			"type": ReactionRules.Type.BLAST,
			"levels": [4 + blast_index, 4 + blast_index],
			"colors": [blast_index, (blast_index + 1) % 6],
			"position": Vector2(float(blast_index - 1) * 180.0, 0.0),
		})
	for merge_index: int in range(10):
		director.play_reaction({
			"type": ReactionRules.Type.MERGE,
			"result_level": 2 + merge_index % 6,
			"result_color": merge_index % 6,
			"position": Vector2(
				float(merge_index % 4) * 120.0 - 180.0,
				float(merge_index / 4) * 120.0 - 60.0
			),
			"chain": merge_index + 1,
		})


func _percentile(sorted_values: Array[float], ratio: float) -> float:
	var index: int = clampi(
		roundi(float(sorted_values.size() - 1) * ratio),
		0,
		sorted_values.size() - 1
	)
	return sorted_values[index]


func _count_over(values: Array[float], threshold: float) -> int:
	var count: int = 0
	for value: float in values:
		if value > threshold:
			count += 1
	return count


func _write_report(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not open feedback measurement output: %s" % OUTPUT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))
