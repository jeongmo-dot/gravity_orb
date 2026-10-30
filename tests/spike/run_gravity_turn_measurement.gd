extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const PILE_JITTER_SEED: int = 11620261030
const DEFAULT_OUTPUT_PATH: String = "res://artifacts/gravity_turn_measurement.json"

var _diagonal_time: float = 0.15
var _output_path: String = DEFAULT_OUTPUT_PATH


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _apply_arguments():
		return
	Engine.physics_ticks_per_second = 120
	Config.data.game_mode = GameConfig.GameMode.JELLY
	Config.data.gravity_turn_diagonal_time = _diagonal_time
	var report: Dictionary = {
		"engine": Engine.get_version_info(),
		"physics_engine": str(ProjectSettings.get_setting("physics/3d/physics_engine")),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"gravity_turn_diagonal_time": _diagonal_time,
		"single_orb": {
			"left_to_down": await _measure_single_orb(Vector2i.LEFT),
			"right_to_down": await _measure_single_orb(Vector2i.RIGHT),
		},
		"pile": {
			"left_to_down": await _measure_pile(Vector2i.LEFT),
			"right_to_down": await _measure_pile(Vector2i.RIGHT),
		},
	}
	_write_report(report)
	print("GRAVITY_TURN_MEASUREMENT %s" % JSON.stringify(report))
	get_tree().quit(0)


func _apply_arguments() -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--diagonal-time="):
			_diagonal_time = argument.trim_prefix("--diagonal-time=").to_float()
		elif argument.begins_with("--output="):
			_output_path = argument.trim_prefix("--output=")
	if _diagonal_time < 0.0:
		push_error("Gravity turn diagonal time must be non-negative")
		get_tree().quit(1)
		return false
	return true


func _measure_single_orb(initial_direction: Vector2i) -> Dictionary:
	var board: Board3D = await _create_board()
	Config.data.gravity_turn_diagonal_time = 0.0
	board.set_gravity(initial_direction)
	var radius: float = Config.data.radius_for_level(1)
	var start_position: Vector2 = Vector2(0.0, -board.half_size() + radius + Config.data.spawn_margin)
	var floor_y: float = board.half_size() - radius
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 1, start_position)
	var body: RigidBody3D = orb.get_physics_body()
	body.freeze = true
	orb.linear_velocity = Vector2.ZERO
	orb.angular_velocity = 0.0
	Config.data.gravity_turn_diagonal_time = _diagonal_time
	board.set_gravity(Vector2i.DOWN)
	var initial_actual_direction: Vector2 = board.actual_gravity_direction()
	var initial_acceleration: Vector2 = Orb3D.world_vector_to_plane(
		body.constant_force / body.mass
	)
	body.freeze = false
	body.sleeping = false
	var elapsed_frames: int = 0
	for frame_index: int in range(Engine.physics_ticks_per_second * 3):
		await get_tree().physics_frame
		elapsed_frames = frame_index + 1
		if orb.position.y >= floor_y - Config.data.floor_contact_tolerance:
			break
	var result: Dictionary = {
		"initial_direction": initial_direction,
		"initial_actual_direction": initial_actual_direction,
		"initial_acceleration_px_s2": initial_acceleration,
		"transition_frames": ceili(
			_diagonal_time * float(Engine.physics_ticks_per_second)
		),
		"impact_seconds": float(elapsed_frames) / float(Engine.physics_ticks_per_second),
		"impact_x_px": orb.position.x,
		"lateral_distance_px": absf(orb.position.x - start_position.x),
		"final_position": orb.position,
	}
	await _free_board(board)
	return result


func _measure_pile(initial_direction: Vector2i) -> Dictionary:
	var board: Board3D = await _create_board()
	var pile_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	pile_rng.seed = PILE_JITTER_SEED
	for orb_index: int in range(40):
		var column: int = orb_index % 8
		var row: int = orb_index / 8
		board.spawn_orb(
			orb_index % JellyOrbArt.PALETTE.size(),
			1,
			Vector2(
				-315.0 + float(column) * 90.0 + pile_rng.randf_range(-10.0, 10.0),
				-360.0 + float(row) * 78.0
			)
		)
	var horizontal_before: Vector2i = -initial_direction
	var settle_directions: Array[Vector2i] = [
		Vector2i.DOWN,
		horizontal_before,
		Vector2i.UP,
		initial_direction,
	]
	for direction: Vector2i in settle_directions:
		board.set_gravity(direction)
		await _wait_seconds(1.2)
	board.set_gravity(Vector2i.DOWN)
	var settle_frames: int = await _wait_until_stable(board, 5.0)
	var extents: Dictionary = _pile_extents(board)
	var result: Dictionary = {
		"initial_direction": initial_direction,
		"center_of_mass_x_px": _center_of_mass_x(board),
		"width_px": extents["width"],
		"height_px": extents["height"],
		"longest_line": _longest_support_line(board, Vector2i.DOWN),
		"settle_seconds": float(settle_frames) / float(Engine.physics_ticks_per_second),
		"forced_settle": settle_frames >= Engine.physics_ticks_per_second * 5,
		"jitter_seed": PILE_JITTER_SEED,
	}
	await _free_board(board)
	return result


func _create_board() -> Board3D:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.orb_contact_reporting_enabled = true
	board.orb_continuous_cd_enabled = true
	board.orb_allow_sleep = false
	get_tree().root.add_child(board)
	await get_tree().process_frame
	return board


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
		var stable: bool = not board.is_gravity_transition_active()
		if stable:
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


func _center_of_mass_x(board: Board3D) -> float:
	var weighted_x: float = 0.0
	var total_mass: float = 0.0
	for orb: Orb3D in board.get_orbs():
		var mass: float = orb.get_physics_body().mass
		weighted_x += orb.position.x * mass
		total_mass += mass
	return weighted_x / total_mass if total_mass > 0.0 else 0.0


func _longest_support_line(board: Board3D, gravity_direction: Vector2i) -> int:
	var orbs: Array[Orb3D] = board.get_orbs()
	var support_by_id: Dictionary = {}
	var gravity: Vector2 = Vector2(gravity_direction).normalized()
	var minimum_alignment: float = cos(deg_to_rad(10.0))
	for orb: Orb3D in orbs:
		var best_support: Orb3D = null
		var best_distance: float = INF
		for candidate: Orb3D in orbs:
			if candidate == orb:
				continue
			var delta: Vector2 = candidate.position - orb.position
			var distance: float = delta.length()
			var contact_distance: float = (
				orb.get_current_radius()
				+ candidate.get_current_radius()
				+ Config.data.floor_contact_tolerance
			)
			if (
				distance > 0.001
				and distance <= contact_distance
				and delta.normalized().dot(gravity) >= minimum_alignment
				and distance < best_distance
			):
				best_support = candidate
				best_distance = distance
		if best_support != null:
			support_by_id[orb.get_instance_id()] = best_support.get_instance_id()
	var longest: int = 0
	for orb: Orb3D in orbs:
		var line_length: int = 1
		var current_id: int = orb.get_instance_id()
		var visited: Dictionary = {current_id: true}
		while support_by_id.has(current_id):
			var support_id: int = int(support_by_id[current_id])
			if visited.has(support_id):
				break
			visited[support_id] = true
			line_length += 1
			current_id = support_id
		longest = maxi(longest, line_length)
	return longest


func _free_board(board: Board3D) -> void:
	board.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame


func _write_report(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file: FileAccess = FileAccess.open(_output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write gravity turn report: %s" % _output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
