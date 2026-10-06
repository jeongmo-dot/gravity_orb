extends Node

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const ORB_SCENE: PackedScene = preload("res://scenes/Orb3D.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main3D.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const BODY_COUNT: int = 70
const WARMUP_FRAMES: int = 120
const SAMPLE_FRAMES: int = 240
const TICKS: int = 120
const CASES: Array[String] = ["a", "b", "c", "d", "e", "f"]
const GRAVITY_DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.LEFT,
]

var _case_name: String = "a"
var _continuous_cd_enabled: bool = true
var _allow_sleep: bool = false
var _contact_reporting_enabled: bool = true
var _snapshot_path: String = ""
var _snapshot_rows: Array[Dictionary] = []
var _fixture_root: Node = null
var _board: Board3D = null
var _direct_bodies: Array[RigidBody3D] = []
var _wrapped_orbs: Array[Orb3D] = []
var _cycle_gravity: bool = true


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	Config.data.fx_hitstop_enabled = false
	_apply_arguments()
	_load_snapshot()
	Engine.physics_ticks_per_second = TICKS
	await _create_fixture()
	for frame: int in range(WARMUP_FRAMES):
		_update_gravity_cycle(frame)
		await get_tree().physics_frame

	var samples_ms: Array[float] = []
	var monitor_samples_ms: Array[float] = []
	for frame: int in range(SAMPLE_FRAMES):
		_update_gravity_cycle(WARMUP_FRAMES + frame)
		var started_usec: int = Time.get_ticks_usec()
		await get_tree().physics_frame
		samples_ms.append(float(Time.get_ticks_usec() - started_usec) / 1000.0)
		monitor_samples_ms.append(
			float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
		)

	var report: Dictionary = {
		"case": _case_name,
		"body_count": _fixture_body_count(),
		"snapshot_path": _snapshot_path,
		"ticks": TICKS,
		"continuous_cd": _continuous_cd_enabled,
		"allow_sleep": _allow_sleep,
		"contact_reporting": _case_contact_reporting(),
		"cycle_gravity": _cycle_gravity,
		"physics_step_wall_ms_mean": _mean(samples_ms),
		"physics_step_wall_ms_p50": _percentile(samples_ms, 0.50),
		"physics_step_wall_ms_p95": _percentile(samples_ms, 0.95),
		"physics_step_wall_ms_max": _percentile(samples_ms, 1.0),
		"performance_monitor_ms_mean": _mean(monitor_samples_ms),
	}
	var output_path: String = (
		"res://artifacts/jolt3d_second_decomposition_%s_ccd%d_sleep%d.json" % [
			_case_name,
			1 if _continuous_cd_enabled else 0,
			1 if _allow_sleep else 0,
		]
	)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write decomposition report: %s" % output_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print("JOLT3D_DECOMPOSITION %s" % JSON.stringify(report))
	if is_instance_valid(_fixture_root):
		_fixture_root.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _create_fixture() -> void:
	if _case_name == "a" or _case_name == "b":
		_fixture_root = Node3D.new()
		_fixture_root.name = "DirectBodyFixture"
		add_child(_fixture_root)
		_create_direct_walls(_fixture_root as Node3D)
		_create_direct_bodies(_fixture_root as Node3D, _case_name == "b")
		return
	if _case_name == "c":
		_fixture_root = Node3D.new()
		_fixture_root.name = "OrbWrapperFixture"
		add_child(_fixture_root)
		_create_direct_walls(_fixture_root as Node3D)
		_create_wrapped_orbs(_fixture_root as Node3D)
		return
	if _case_name == "d":
		_fixture_root = Node3D.new()
		_fixture_root.name = "BoardFixture"
		add_child(_fixture_root)
		_board = BOARD_SCENE.instantiate() as Board3D
		_fixture_root.add_child(_board)
		_configure_board_profile(_board)
		await get_tree().process_frame
		_spawn_board_orbs(_board)
		return
	if _case_name == "e":
		await _create_manager_fixture()
		return
	await _create_full_fixture()


func _create_manager_fixture() -> void:
	var root: Node3D = Node3D.new()
	root.name = "ManagerFixture"
	_fixture_root = root
	_board = BOARD_SCENE.instantiate() as Board3D
	_board.name = "Board"
	_board.unique_name_in_owner = true
	_configure_board_profile(_board)
	root.add_child(_board)
	_board.owner = root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	root.add_child(resolver)
	resolver.owner = root
	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	root.add_child(spawner)
	spawner.owner = root
	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	root.add_child(manager)
	manager.owner = root
	add_child(root)
	await get_tree().process_frame
	_spawn_board_orbs(_board)


func _create_full_fixture() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	_fixture_root = main
	_board = main.get_node("Board") as Board3D
	_configure_board_profile(_board)
	add_child(main)
	await get_tree().process_frame
	_board.clear()
	await get_tree().process_frame
	_spawn_board_orbs(_board)


func _create_direct_walls(parent: Node3D) -> void:
	var half_m: float = Config.data.board_size * 0.5 / Orb3D.PIXELS_PER_METER
	var thickness_m: float = Config.data.wall_thickness / Orb3D.PIXELS_PER_METER
	var span_m: float = half_m * 2.0 + thickness_m * 2.0
	_create_direct_wall(parent, Vector3(0.0, -half_m - thickness_m * 0.5, 0.0), Vector3(span_m, thickness_m, 0.8))
	_create_direct_wall(parent, Vector3(0.0, half_m + thickness_m * 0.5, 0.0), Vector3(span_m, thickness_m, 0.8))
	_create_direct_wall(parent, Vector3(-half_m - thickness_m * 0.5, 0.0, 0.0), Vector3(thickness_m, span_m, 0.8))
	_create_direct_wall(parent, Vector3(half_m + thickness_m * 0.5, 0.0, 0.0), Vector3(thickness_m, span_m, 0.8))


func _create_direct_wall(parent: Node3D, wall_position: Vector3, wall_size: Vector3) -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = wall_position
	wall.collision_layer = 1
	wall.collision_mask = 2
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = Config.data.wall_friction
	material.bounce = Config.data.wall_bounce
	wall.physics_material_override = material
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = wall_size
	collision.shape = shape
	wall.add_child(collision)
	parent.add_child(wall)


func _create_direct_bodies(parent: Node3D, contact_reporting: bool) -> void:
	for index: int in range(_fixture_body_count()):
		var row: Dictionary = _fixture_row(index)
		var body: RigidBody3D = _new_direct_body(contact_reporting, int(row["level"]))
		parent.add_child(body)
		body.position = _fixture_position_m(index)
		body.linear_velocity = _fixture_velocity_m(index)
		body.angular_velocity = Vector3(0.0, 0.0, float(row["angular_velocity"]))
		if contact_reporting:
			body.body_entered.connect(_on_direct_body_entered)
		_direct_bodies.append(body)


func _new_direct_body(contact_reporting: bool, level: int) -> RigidBody3D:
	var body: RigidBody3D = RigidBody3D.new()
	body.gravity_scale = 0.0
	body.can_sleep = _allow_sleep
	body.continuous_cd = _continuous_cd_enabled
	body.contact_monitor = contact_reporting
	body.max_contacts_reported = Config.data.contact_max_reported if contact_reporting else 0
	body.mass = Config.data.mass_for_level(level)
	body.linear_damp = Config.data.orb_linear_damp
	body.angular_damp = Config.data.orb_angular_damp
	body.axis_lock_linear_z = true
	body.axis_lock_angular_x = true
	body.axis_lock_angular_y = true
	body.collision_layer = 2
	body.collision_mask = 3
	body.constant_force = Vector3(Config.data.gravity_strength / Orb3D.PIXELS_PER_METER * body.mass, 0.0, 0.0)
	var material: PhysicsMaterial = PhysicsMaterial.new()
	material.friction = Config.data.orb_friction
	material.bounce = Config.data.orb_bounce
	body.physics_material_override = material
	var collision: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = Config.data.radius_for_level(level) / Orb3D.PIXELS_PER_METER
	collision.shape = sphere
	body.add_child(collision)
	return body


func _create_wrapped_orbs(parent: Node3D) -> void:
	for index: int in range(_fixture_body_count()):
		var row: Dictionary = _fixture_row(index)
		var orb: Orb3D = ORB_SCENE.instantiate() as Orb3D
		parent.add_child(orb)
		orb.configure_physics_profile(
			_contact_reporting_enabled,
			_continuous_cd_enabled,
			_allow_sleep
		)
		orb.setup(int(row["color"]), int(row["level"]), Config.data)
		orb.get_physics_body().body_entered.connect(_on_direct_body_entered)
		orb.get_physics_body().position = _fixture_position_m(index)
		orb.get_physics_body().linear_velocity = _fixture_velocity_m(index)
		orb.angular_velocity = float(row["angular_velocity"])
		orb.set_gravity(Vector2i.RIGHT, Config.data.gravity_strength)
		_wrapped_orbs.append(orb)


func _spawn_board_orbs(board: Board3D) -> void:
	board.set_gravity(Vector2i.RIGHT)
	for index: int in range(_fixture_body_count()):
		var row: Dictionary = _fixture_row(index)
		var position_m: Vector3 = _fixture_position_m(index)
		var velocity_m: Vector3 = _fixture_velocity_m(index)
		var orb: Orb3D = board.spawn_orb(
			int(row["color"]),
			int(row["level"]),
			Vector2(position_m.x, position_m.y) * Orb3D.PIXELS_PER_METER,
			Vector2(velocity_m.x, velocity_m.y) * Orb3D.PIXELS_PER_METER
		)
		orb.angular_velocity = float(row["angular_velocity"])


func _grid_position_m(index: int) -> Vector3:
	var column: int = index % 10
	var row: int = index / 10
	var spacing_px: float = Config.data.radius_for_level(1) * 2.0 + 2.0
	var bottom_y_px: float = Config.data.board_size * 0.5 - Config.data.radius_for_level(1) - 2.0
	return Vector3(
		(float(column) - 4.5) * spacing_px / Orb3D.PIXELS_PER_METER,
		(bottom_y_px - float(row) * spacing_px) / Orb3D.PIXELS_PER_METER,
		0.0
	)


func _fixture_body_count() -> int:
	return BODY_COUNT if _snapshot_rows.is_empty() else _snapshot_rows.size()


func _fixture_row(index: int) -> Dictionary:
	if not _snapshot_rows.is_empty():
		return _snapshot_rows[index]
	return {
		"color": index % 3,
		"level": 1,
		"angular_velocity": 0.0,
	}


func _fixture_position_m(index: int) -> Vector3:
	if _snapshot_rows.is_empty():
		return _grid_position_m(index)
	var row: Dictionary = _snapshot_rows[index]
	return Vector3(
		float(row["position_x"]) / Orb3D.PIXELS_PER_METER,
		float(row["position_y"]) / Orb3D.PIXELS_PER_METER,
		0.0
	)


func _fixture_velocity_m(index: int) -> Vector3:
	if _snapshot_rows.is_empty():
		return Vector3.ZERO
	var row: Dictionary = _snapshot_rows[index]
	return Vector3(
		float(row["velocity_x"]) / Orb3D.PIXELS_PER_METER,
		float(row["velocity_y"]) / Orb3D.PIXELS_PER_METER,
		0.0
	)


func _load_snapshot() -> void:
	if _snapshot_path.is_empty():
		return
	var file: FileAccess = FileAccess.open(_snapshot_path, FileAccess.READ)
	if file == null:
		push_error("Could not open snapshot report: %s" % _snapshot_path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("Invalid snapshot report: %s" % _snapshot_path)
		return
	var report: Dictionary = parsed as Dictionary
	var ticks: Array = report.get("ticks", []) as Array
	if ticks.is_empty():
		return
	var seeds: Array = (ticks[0] as Dictionary).get("seeds", []) as Array
	if seeds.is_empty():
		return
	var rows: Array = (seeds[0] as Dictionary).get("final_state", []) as Array
	for value: Variant in rows:
		_snapshot_rows.append(value as Dictionary)


func _configure_board_profile(board: Board3D) -> void:
	board.orb_contact_reporting_enabled = _contact_reporting_enabled
	board.orb_continuous_cd_enabled = _continuous_cd_enabled
	board.orb_allow_sleep = _allow_sleep
	board.orb_progressive_growth_enabled = false


func _update_gravity_cycle(frame: int) -> void:
	if not _cycle_gravity or frame % 30 != 0:
		return
	var direction: Vector2i = GRAVITY_DIRECTIONS[(frame / 30) % GRAVITY_DIRECTIONS.size()]
	if _board != null:
		_board.set_gravity(direction)
		return
	for orb: Orb3D in _wrapped_orbs:
		orb.set_gravity(direction, Config.data.gravity_strength)
	if not _wrapped_orbs.is_empty():
		return
	var acceleration: Vector3 = Vector3(
		float(direction.x),
		float(direction.y),
		0.0
	) * Config.data.gravity_strength / Orb3D.PIXELS_PER_METER
	for body: RigidBody3D in _direct_bodies:
		body.constant_force = acceleration * body.mass
		body.sleeping = false


func _case_contact_reporting() -> bool:
	return false if _case_name == "a" else _contact_reporting_enabled


func _on_direct_body_entered(_body: Node) -> void:
	pass


func _apply_arguments() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--jolt-case="):
			_case_name = argument.trim_prefix("--jolt-case=")
		elif argument == "--jolt-no-ccd":
			_continuous_cd_enabled = false
		elif argument == "--jolt-allow-sleep":
			_allow_sleep = true
		elif argument == "--jolt-no-contact-reporting":
			_contact_reporting_enabled = false
		elif argument.begins_with("--jolt-snapshot="):
			_snapshot_path = argument.trim_prefix("--jolt-snapshot=")
		elif argument == "--jolt-static":
			_cycle_gravity = false
	if not CASES.has(_case_name):
		push_error("Unknown Jolt decomposition case: %s" % _case_name)
		_case_name = "a"


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in values:
		total += value
	return total / float(values.size())


func _percentile(values: Array[float], ratio: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var index: int = clampi(roundi(float(sorted.size() - 1) * ratio), 0, sorted.size() - 1)
	return sorted[index]
