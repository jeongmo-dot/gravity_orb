extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const OUTPUT_PREFIX: String = "--output="
const SETTLE_DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.DOWN,
]
const SETTLE_TURN_SECONDS: float = 1.5
const FINAL_SETTLE_SECONDS: float = 2.0
const MEASUREMENT_SECONDS: float = 3.0
const MOTION_SECONDS: float = 1.5
const TOGGLE_SECONDS: float = 0.5

enum Phase {
	NONE,
	REST,
	MOTION,
	BREATH_TOGGLE,
}

var _output_path: String = "res://artifacts/measurements/jelly_motion.json"
var _board: Board3D
var _orbs: Array[Orb3D] = []
var _last_scales: Dictionary = {}
var _last_rotations: Dictionary = {}
var _rest_max_scale_change_ratio: float = 0.0
var _motion_max_scale_change_ratio: float = 0.0
var _motion_max_rotation_change_radians: float = 0.0
var _max_breath_toggle_change_ratio: float = 0.0
var _rest_contact_events: int = 0
var _phase: Phase = Phase.NONE


func _ready() -> void:
	_parse_arguments()
	call_deferred("_run")


func _process(_delta: float) -> void:
	if _phase == Phase.NONE:
		return
	for orb: Orb3D in _orbs:
		if not is_instance_valid(orb) or orb.consumed:
			continue
		var scale: Vector3 = orb._mesh.scale
		var rotation: float = orb._mesh.rotation.z
		var key: int = orb.get_instance_id()
		if _last_scales.has(key):
			var previous_scale: Vector3 = _last_scales[key] as Vector3
			var ratio: float = _maximum_axis_change_ratio(previous_scale, scale)
			match _phase:
				Phase.REST:
					_rest_max_scale_change_ratio = maxf(_rest_max_scale_change_ratio, ratio)
				Phase.MOTION:
					_motion_max_scale_change_ratio = maxf(_motion_max_scale_change_ratio, ratio)
				Phase.BREATH_TOGGLE:
					_max_breath_toggle_change_ratio = maxf(
						_max_breath_toggle_change_ratio,
						ratio
					)
		if _phase == Phase.MOTION and _last_rotations.has(key):
			var previous_rotation: float = float(_last_rotations[key])
			var rotation_change: float = absf(wrapf(rotation - previous_rotation, -PI, PI))
			_motion_max_rotation_change_radians = maxf(
				_motion_max_rotation_change_radians,
				rotation_change
			)
		_last_scales[key] = scale
		_last_rotations[key] = rotation


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
	_board.orb_contact.connect(_on_orb_contact)
	_spawn_pile()
	await _settle_pile()
	_set_turn_resting(true)
	await _wait_seconds(0.5)
	var touching_pairs: int = _count_touching_pairs()
	var uses_smoothed_motion: bool = (
		not _orbs.is_empty()
		and _orbs[0].has_method("reset_jelly_motion_diagnostics")
	)
	for orb: Orb3D in _orbs:
		if uses_smoothed_motion:
			orb.call("reset_jelly_motion_diagnostics")
	_reset_frame_samples()
	_rest_contact_events = 0
	_phase = Phase.REST
	await _wait_seconds(MEASUREMENT_SECONDS)
	_phase = Phase.NONE
	var impact_starts: int = _rest_contact_events
	if uses_smoothed_motion:
		impact_starts = 0
		for orb: Orb3D in _orbs:
			impact_starts += int(orb.call("jelly_impact_start_count"))

	_reset_frame_samples()
	_phase = Phase.BREATH_TOGGLE
	_set_turn_resting(false)
	await _wait_seconds(TOGGLE_SECONDS)
	_set_turn_resting(true)
	await _wait_seconds(TOGGLE_SECONDS)
	_phase = Phase.NONE

	_set_turn_resting(false)
	_reset_frame_samples()
	_phase = Phase.MOTION
	_board.set_gravity(Vector2i.RIGHT)
	await _wait_seconds(MOTION_SECONDS)
	_phase = Phase.NONE

	var report: Dictionary = {
		"jelly_count": _orbs.size(),
		"settle_turn_count": SETTLE_DIRECTIONS.size(),
		"touching_pairs": touching_pairs,
		"measurement_seconds": MEASUREMENT_SECONDS,
		"motion_seconds": MOTION_SECONDS,
		"uses_smoothed_motion": uses_smoothed_motion,
		"impact_starts": impact_starts,
		"impact_starts_per_second": float(impact_starts) / MEASUREMENT_SECONDS,
		"rest_contact_events": _rest_contact_events,
		"rest_max_scale_change_ratio": _rest_max_scale_change_ratio,
		"motion_max_scale_change_ratio": _motion_max_scale_change_ratio,
		"motion_max_rotation_change_radians": _motion_max_rotation_change_radians,
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
		"JELLY_MOTION_MEASUREMENT contacts=%d touching=%d impacts_per_second=%.6f rest_scale=%.6f motion_scale=%.6f motion_rotation=%.6f breath_toggle=%.6f"
		% [
			_rest_contact_events,
			touching_pairs,
			report["impact_starts_per_second"],
			_rest_max_scale_change_ratio,
			_motion_max_scale_change_ratio,
			_motion_max_rotation_change_radians,
			report["max_breath_toggle_change_ratio"],
		]
	)
	get_tree().quit(0)


func _spawn_pile() -> void:
	for index: int in range(40):
		var column: int = index % 8
		var row: int = index / 8
		var orb: Orb3D = _board.spawn_orb(
			index % JellyOrbArt.PALETTE.size(),
			1,
			Vector2(-315.0 + float(column) * 90.0, -360.0 + float(row) * 78.0)
		)
		_orbs.append(orb)


func _settle_pile() -> void:
	_set_turn_resting(false)
	for direction: Vector2i in SETTLE_DIRECTIONS:
		_board.set_gravity(direction)
		await _wait_seconds(SETTLE_TURN_SECONDS)
	_board.set_gravity(Vector2i.DOWN)
	await _wait_seconds(FINAL_SETTLE_SECONDS)


func _set_turn_resting(resting: bool) -> void:
	if _board.has_method("set_turn_resting"):
		_board.call("set_turn_resting", resting)


func _on_orb_contact(_a: Orb3D, _b: Orb3D) -> void:
	if _phase == Phase.REST:
		_rest_contact_events += 1


func _count_touching_pairs() -> int:
	var count: int = 0
	for first_index: int in range(_orbs.size()):
		var first: Orb3D = _orbs[first_index]
		for second_index: int in range(first_index + 1, _orbs.size()):
			var second: Orb3D = _orbs[second_index]
			var touching_distance: float = (
				first.get_current_radius()
				+ second.get_current_radius()
				+ 4.0
			)
			if first.position.distance_to(second.position) <= touching_distance:
				count += 1
	return count


func _reset_frame_samples() -> void:
	_last_scales.clear()
	_last_rotations.clear()
	for orb: Orb3D in _orbs:
		_last_scales[orb.get_instance_id()] = orb._mesh.scale
		_last_rotations[orb.get_instance_id()] = orb._mesh.rotation.z


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
