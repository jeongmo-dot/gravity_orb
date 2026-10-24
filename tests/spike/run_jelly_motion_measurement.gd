extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const OUTPUT_PREFIX: String = "--output="
const SETTLE_SECONDS: float = 4.0
const MEASUREMENT_SECONDS: float = 3.0
const TOGGLE_SECONDS: float = 0.5

var _output_path: String = "res://artifacts/measurements/jelly_motion.json"
var _board: Board3D
var _orbs: Array[Orb3D] = []
var _last_scales: Dictionary = {}
var _max_scale_change_ratio: float = 0.0
var _max_breath_toggle_change_ratio: float = 0.0
var _record_motion: bool = false
var _record_breath_toggle: bool = false


func _ready() -> void:
	_parse_arguments()
	call_deferred("_run")


func _process(_delta: float) -> void:
	if not _record_motion and not _record_breath_toggle:
		return
	for orb: Orb3D in _orbs:
		var scale: Vector3 = orb.visual_mesh_scale()
		var key: int = orb.get_instance_id()
		if _last_scales.has(key):
			var previous: Vector3 = _last_scales[key] as Vector3
			var ratio: float = _maximum_axis_change_ratio(previous, scale)
			if _record_motion:
				_max_scale_change_ratio = maxf(_max_scale_change_ratio, ratio)
			if _record_breath_toggle:
				_max_breath_toggle_change_ratio = maxf(
					_max_breath_toggle_change_ratio,
					ratio
				)
		_last_scales[key] = scale


func _run() -> void:
	Main.queue_mode(GameConfig.GameMode.JELLY)
	var main: Main = MAIN_SCENE.instantiate() as Main
	add_child(main)
	await get_tree().process_frame
	_board = main.get_node("Board") as Board3D
	(main.get_node("TurnManager") as TurnManager).set_physics_process(false)
	(main.get_node("BlitzManager") as BlitzManager).set_physics_process(false)
	for existing: Orb3D in _board.get_orbs().duplicate():
		_board.remove_orb(existing)
	for index: int in range(40):
		var column: int = index % 8
		var row: int = index / 8
		var orb: Orb3D = _board.spawn_orb(
			index % JellyOrbArt.PALETTE.size(),
			1,
			Vector2(-350.0 + float(column) * 100.0, -20.0 + float(row) * 82.0)
		)
		_orbs.append(orb)
	await _wait_seconds(SETTLE_SECONDS)
	if _board.has_method("set_turn_resting"):
		_board.call("set_turn_resting", true)
	for orb: Orb3D in _orbs:
		orb.reset_jelly_motion_diagnostics()
		_last_scales[orb.get_instance_id()] = orb.visual_mesh_scale()
	_record_motion = true
	await _wait_seconds(MEASUREMENT_SECONDS)
	_record_motion = false
	var impact_starts: int = 0
	for orb: Orb3D in _orbs:
		impact_starts += orb.jelly_impact_start_count()
	_record_breath_toggle = true
	if _board.has_method("set_turn_resting"):
		_board.call("set_turn_resting", false)
	else:
		for orb: Orb3D in _orbs:
			orb.linear_velocity = Vector2(150.0, 0.0)
	await _wait_seconds(TOGGLE_SECONDS)
	if _board.has_method("set_turn_resting"):
		_board.call("set_turn_resting", true)
	else:
		for orb: Orb3D in _orbs:
			orb.linear_velocity = Vector2.ZERO
	await _wait_seconds(TOGGLE_SECONDS)
	_record_breath_toggle = false
	var report: Dictionary = {
		"jelly_count": _orbs.size(),
		"settle_seconds": SETTLE_SECONDS,
		"measurement_seconds": MEASUREMENT_SECONDS,
		"impact_starts": impact_starts,
		"impact_starts_per_second": float(impact_starts) / MEASUREMENT_SECONDS,
		"max_scale_change_ratio": _max_scale_change_ratio,
		"max_breath_toggle_change_ratio": _max_breath_toggle_change_ratio,
	}
	var absolute_output: String = ProjectSettings.globalize_path(_output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write JELLY motion measurement report")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print(
		"JELLY_MOTION_MEASUREMENT impacts_per_second=%.6f max_scale_change=%.6f breath_toggle=%.6f"
		% [
			report["impact_starts_per_second"],
			report["max_scale_change_ratio"],
			report["max_breath_toggle_change_ratio"],
		]
	)
	get_tree().quit(0)


func _maximum_axis_change_ratio(previous: Vector3, current: Vector3) -> float:
	var x_ratio: float = absf(current.x - previous.x) / maxf(absf(previous.x), 0.000001)
	var y_ratio: float = absf(current.y - previous.y) / maxf(absf(previous.y), 0.000001)
	var z_ratio: float = absf(current.z - previous.z) / maxf(absf(previous.z), 0.000001)
	return maxf(x_ratio, maxf(y_ratio, z_ratio))


func _wait_seconds(seconds: float) -> void:
	var started_usec: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started_usec) / 1_000_000.0 < seconds:
		await get_tree().process_frame


func _parse_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(OUTPUT_PREFIX):
			_output_path = argument.trim_prefix(OUTPUT_PREFIX)
