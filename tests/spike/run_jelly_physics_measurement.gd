extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const DEFAULT_OUTPUT_PATH: String = "res://artifacts/jelly_physics_metrics.json"
const BEFORE_PROFILE: Dictionary = {
	"gravity_strength": 1800.0,
	"gravity_level_scale": 0.25,
	"orb_friction": 0.3,
	"orb_bounce": 0.15,
	"wall_friction": 0.3,
	"wall_bounce": 0.1,
	"rotation_lock": false,
}
const AFTER_PROFILE: Dictionary = {
	"gravity_strength": 3600.0,
	"gravity_level_scale": 0.05,
	"orb_friction": 0.6,
	"orb_bounce": 0.06,
	"wall_friction": 0.6,
	"wall_bounce": 0.06,
	"rotation_lock": true,
}

var _profile_name: String = "after"
var _output_path: String = DEFAULT_OUTPUT_PATH
var _rotation_lock: bool = true


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _apply_arguments():
		return
	var profile: Dictionary = BEFORE_PROFILE if _profile_name == "before" else AFTER_PROFILE
	_apply_profile(profile)
	Engine.physics_ticks_per_second = 120
	var report: Dictionary = {
		"profile": _profile_name,
		"engine": Engine.get_version_info(),
		"physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"values": profile.duplicate(true),
		"fall": {
			"L1": await _measure_fall(1),
			"L4": await _measure_fall(4),
			"L7": await _measure_fall(7),
		},
		"bounce": {
			"L1": await _measure_bounce(1),
			"L7": await _measure_bounce(7),
		},
		"color_effect_displacement_px": {
			"push_red": await _measure_color_effect(OrbTypes.OrbColor.RED),
			"shake_blue": await _measure_color_effect(OrbTypes.OrbColor.BLUE),
			"lift_yellow": await _measure_color_effect(OrbTypes.OrbColor.YELLOW),
			"pull_purple": await _measure_color_effect(OrbTypes.OrbColor.PURPLE),
		},
		"pile": await _measure_pile(),
	}
	_write_report(report)
	print("JELLY_PHYSICS_METRICS %s" % JSON.stringify(report))
	get_tree().quit(0)


func _apply_arguments() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--profile="):
			_profile_name = argument.trim_prefix("--profile=").to_lower()
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
	if _profile_name not in ["before", "after"]:
		push_error("Unknown JELLY physics profile: %s" % _profile_name)
		get_tree().quit(1)
		return false
	return true


func _apply_profile(profile: Dictionary) -> void:
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.gravity_strength = float(profile["gravity_strength"])
	Config.data.gravity_level_scale = float(profile["gravity_level_scale"])
	Config.data.orb_friction = float(profile["orb_friction"])
	Config.data.orb_bounce = float(profile["orb_bounce"])
	Config.data.wall_friction = float(profile["wall_friction"])
	Config.data.wall_bounce = float(profile["wall_bounce"])
	_rotation_lock = bool(profile["rotation_lock"])
	Orb3D.clear_shared_resource_cache()


func _measure_fall(level: int) -> Dictionary:
	var board: Board3D = await _create_board()
	var radius: float = Config.data.radius_for_level(level)
	var start_y: float = -board.half_size() + radius + Config.data.spawn_margin
	var floor_y: float = board.half_size() - radius
	var orb: Orb3D = _spawn_orb(board, level, Vector2(0.0, start_y))
	var elapsed_frames: int = 0
	var impact_speed: float = 0.0
	for _frame: int in range(Engine.physics_ticks_per_second * 3):
		var downward_speed: float = maxf(orb.linear_velocity.y, 0.0)
		impact_speed = maxf(impact_speed, downward_speed)
		await get_tree().physics_frame
		elapsed_frames += 1
		if orb.position.y >= floor_y - Config.data.floor_contact_tolerance:
			break
	var result: Dictionary = {
		"cross_board_seconds": float(elapsed_frames) / float(Engine.physics_ticks_per_second),
		"impact_speed_px_s": impact_speed,
	}
	await _free_board(board)
	return result


func _measure_bounce(level: int) -> Dictionary:
	var board: Board3D = await _create_board()
	var radius: float = Config.data.radius_for_level(level)
	var start_y: float = -board.half_size() + radius + Config.data.spawn_margin
	var floor_y: float = board.half_size() - radius
	var orb: Orb3D = _spawn_orb(board, level, Vector2(0.0, start_y))
	var phase: int = 0
	var impact_speed: float = 0.0
	var first_rebound_speed: float = 0.0
	var second_impact_speed: float = 0.0
	var second_rebound_speed: float = 0.0
	var first_contact_y: float = floor_y
	var second_contact_y: float = floor_y
	var first_apex_y: float = floor_y
	var second_apex_y: float = floor_y
	for _frame: int in range(Engine.physics_ticks_per_second * 5):
		await get_tree().physics_frame
		var velocity_y: float = orb.linear_velocity.y
		if phase == 0:
			impact_speed = maxf(impact_speed, velocity_y)
			if velocity_y < -1.0:
				first_rebound_speed = -velocity_y
				first_contact_y = orb.position.y
				first_apex_y = orb.position.y
				phase = 1
		elif phase == 1:
			first_apex_y = minf(first_apex_y, orb.position.y)
			if velocity_y >= 0.0:
				phase = 2
		elif phase == 2:
			second_impact_speed = maxf(second_impact_speed, velocity_y)
			if velocity_y < -1.0:
				second_rebound_speed = -velocity_y
				second_contact_y = orb.position.y
				second_apex_y = orb.position.y
				phase = 3
		elif phase == 3:
			second_apex_y = minf(second_apex_y, orb.position.y)
			if velocity_y >= 0.0:
				break
	var result: Dictionary = {
		"first_height_px": maxf(first_contact_y - first_apex_y, 0.0),
		"second_height_px": maxf(second_contact_y - second_apex_y, 0.0),
		"first_impact_speed_px_s": impact_speed,
		"first_rebound_speed_px_s": first_rebound_speed,
		"first_rebound_ratio": _safe_ratio(first_rebound_speed, impact_speed),
		"second_impact_speed_px_s": second_impact_speed,
		"second_rebound_speed_px_s": second_rebound_speed,
		"second_rebound_ratio": _safe_ratio(second_rebound_speed, second_impact_speed),
		"completed_two_bounces": phase >= 3,
	}
	await _free_board(board)
	return result


func _measure_pile() -> Dictionary:
	var board: Board3D = await _create_board()
	for orb_index: int in range(40):
		var column: int = orb_index % 8
		var row: int = orb_index / 8
		_spawn_orb(
			board,
			1,
			Vector2(-315.0 + float(column) * 90.0, -360.0 + float(row) * 78.0),
			orb_index % JellyOrbArt.PALETTE.size()
		)
	var settle_directions: Array[Vector2i] = [
		Vector2i.DOWN,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.LEFT,
		Vector2i.DOWN,
	]
	for direction: Vector2i in settle_directions:
		board.set_gravity(direction)
		await _wait_seconds(1.2)
	board.set_gravity(Vector2i.DOWN)
	await _wait_seconds(1.8)
	var extents: Dictionary = _pile_extents(board)
	board.set_gravity(Vector2i.RIGHT)
	var settle_frames: int = await _wait_until_stable(board, 5.0)
	var result: Dictionary = {
		"orb_count": board.get_orbs().size(),
		"rest_width_px": extents["width"],
		"rest_height_px": extents["height"],
		"right_settle_seconds": float(settle_frames) / float(Engine.physics_ticks_per_second),
		"right_forced_settle": settle_frames >= Engine.physics_ticks_per_second * 5,
	}
	await _free_board(board)
	return result


func _measure_color_effect(result_color: int) -> float:
	var board: Board3D = await _create_board()
	var radius: float = Config.data.radius_for_level(1)
	var floor_y: float = board.half_size() - radius
	var target: Orb3D = _spawn_orb(board, 1, Vector2(100.0, floor_y))
	await _wait_seconds(0.5)
	var start_position: Vector2 = target.position
	board.apply_shockwave(
		Vector2(0.0, floor_y),
		4,
		null,
		false,
		result_color,
		Callable(self, "_fixed_shake_direction")
	)
	var maximum_displacement: float = 0.0
	for _frame: int in range(ceili(0.75 * float(Engine.physics_ticks_per_second))):
		await get_tree().physics_frame
		maximum_displacement = maxf(
			maximum_displacement,
			target.position.distance_to(start_position)
		)
	await _free_board(board)
	return maximum_displacement


func _fixed_shake_direction() -> Vector2:
	return Vector2.RIGHT


func _create_board() -> Board3D:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.orb_contact_reporting_enabled = true
	board.orb_continuous_cd_enabled = true
	board.orb_allow_sleep = false
	get_tree().root.add_child(board)
	await get_tree().process_frame
	board.set_gravity(Vector2i.DOWN)
	return board


func _spawn_orb(
	board: Board3D,
	level: int,
	position_value: Vector2,
	color: int = OrbTypes.OrbColor.RED
) -> Orb3D:
	var orb: Orb3D = board.spawn_orb(color, level, position_value)
	orb.get_physics_body().axis_lock_angular_z = _rotation_lock
	return orb


func _wait_seconds(duration: float) -> void:
	for _frame: int in range(ceili(duration * float(Engine.physics_ticks_per_second))):
		await get_tree().physics_frame


func _wait_until_stable(board: Board3D, timeout_seconds: float) -> int:
	var stable_frames: int = 0
	var required_stable_frames: int = ceili(
		Config.data.stable_duration * float(Engine.physics_ticks_per_second)
	)
	var maximum_frames: int = ceili(timeout_seconds * float(Engine.physics_ticks_per_second))
	for frame_index: int in range(maximum_frames):
		await get_tree().physics_frame
		var stable: bool = true
		for orb: Orb3D in board.get_orbs():
			if (
				orb.linear_velocity.length() > Config.data.stable_linear_speed
				or absf(orb.angular_velocity) > Config.data.stable_angular_speed
			):
				stable = false
				break
		stable_frames = stable_frames + 1 if stable else 0
		if stable_frames >= required_stable_frames:
			return frame_index + 1
	return maximum_frames


func _pile_extents(board: Board3D) -> Dictionary:
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	for orb: Orb3D in board.get_orbs():
		var radius: float = orb.get_current_radius()
		minimum.x = minf(minimum.x, orb.position.x - radius)
		minimum.y = minf(minimum.y, orb.position.y - radius)
		maximum.x = maxf(maximum.x, orb.position.x + radius)
		maximum.y = maxf(maximum.y, orb.position.y + radius)
	return {"width": maximum.x - minimum.x, "height": maximum.y - minimum.y}


func _free_board(board: Board3D) -> void:
	board.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _safe_ratio(numerator: float, denominator: float) -> float:
	return numerator / denominator if denominator > 0.000001 else 0.0


func _write_report(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write JELLY physics report: %s" % _output_path)
		return
	file.store_string(JSON.stringify(report, "\t"))
