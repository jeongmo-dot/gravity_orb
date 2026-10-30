extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board3D.tscn")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const TOLERANCE: float = 0.001
const TURN_CASES: Array[Dictionary] = [
	{"from": Vector2i.LEFT, "to": Vector2i.DOWN},
	{"from": Vector2i.LEFT, "to": Vector2i.UP},
	{"from": Vector2i.RIGHT, "to": Vector2i.DOWN},
	{"from": Vector2i.RIGHT, "to": Vector2i.UP},
	{"from": Vector2i.DOWN, "to": Vector2i.LEFT},
	{"from": Vector2i.DOWN, "to": Vector2i.RIGHT},
	{"from": Vector2i.UP, "to": Vector2i.LEFT},
	{"from": Vector2i.UP, "to": Vector2i.RIGHT},
]


func test_eight_quarter_turns_use_normalized_diagonal_then_final_direction() -> void:
	var original_time: float = Config.data.gravity_turn_diagonal_time
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	var emitted: Array[Vector2i] = []
	board.visual_gravity_changed.connect(
		func(direction: Vector2i) -> void: emitted.append(direction)
	)
	var transition_frames: int = ceili(0.15 * float(Engine.physics_ticks_per_second))
	for turn_case: Dictionary in TURN_CASES:
		var from_direction: Vector2i = turn_case["from"] as Vector2i
		var to_direction: Vector2i = turn_case["to"] as Vector2i
		Config.data.gravity_turn_diagonal_time = 0.0
		board.set_gravity(from_direction)
		Config.data.gravity_turn_diagonal_time = 0.15
		emitted.clear()
		board.set_gravity(to_direction)
		var expected_diagonal: Vector2 = Vector2(from_direction + to_direction).normalized()
		_assert_vector_near(
			board.actual_gravity_direction(),
			expected_diagonal,
			TOLERANCE,
			"quarter turn starts on its signed diagonal"
		)
		assert_eq(board.gravity_direction(), to_direction, "board final direction changes immediately")
		assert_eq(emitted, [to_direction], "visual signal emits the final direction once")
		_assert_orb_acceleration(orb, expected_diagonal, Config.data.gravity_for_level(1))
		for _frame: int in range(transition_frames):
			board._physics_process(1.0 / float(Engine.physics_ticks_per_second))
		assert_true(board.is_gravity_transition_active(), "diagonal lasts all configured physics frames")
		_assert_orb_acceleration(orb, expected_diagonal, Config.data.gravity_for_level(1))
		board._finish_gravity_transition(board._gravity_transition_id)
		assert_true(not board.is_gravity_transition_active(), "transition finishes after the diagonal interval")
		_assert_vector_near(
			board.actual_gravity_direction(),
			Vector2(to_direction),
			TOLERANCE,
			"applied gravity reaches the final direction"
		)
		_assert_orb_acceleration(orb, Vector2(to_direction), Config.data.gravity_for_level(1))
	Config.data.gravity_turn_diagonal_time = original_time
	await _cleanup(board)


func test_same_opposite_and_zero_time_turns_change_gravity_immediately() -> void:
	var original_time: float = Config.data.gravity_turn_diagonal_time
	var board: Board3D = await _create_board()
	var orb: Orb3D = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2.ZERO)
	Config.data.gravity_turn_diagonal_time = 0.15
	board.set_gravity(Vector2i.DOWN)
	assert_true(not board.is_gravity_transition_active(), "same direction is immediate")
	_assert_orb_acceleration(orb, Vector2.DOWN, Config.data.gravity_for_level(1))
	board.set_gravity(Vector2i.UP)
	assert_true(not board.is_gravity_transition_active(), "opposite direction is immediate")
	_assert_orb_acceleration(orb, Vector2.UP, Config.data.gravity_for_level(1))
	board.set_gravity(Vector2i.LEFT)
	assert_true(board.is_gravity_transition_active(), "quarter turn normally transitions")
	Config.data.gravity_turn_diagonal_time = 0.0
	board.set_gravity(Vector2i.DOWN)
	assert_true(not board.is_gravity_transition_active(), "zero duration preserves immediate behavior")
	_assert_orb_acceleration(orb, Vector2.DOWN, Config.data.gravity_for_level(1))
	Config.data.gravity_turn_diagonal_time = original_time
	await _cleanup(board)


func test_transition_applies_to_spawn_growth_and_entrance_release() -> void:
	var original_time: float = Config.data.gravity_turn_diagonal_time
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.JELLY
	var board: Board3D = await _create_board()
	Config.data.gravity_turn_diagonal_time = 0.0
	board.set_gravity(Vector2i.LEFT)
	Config.data.gravity_turn_diagonal_time = 0.15
	board.set_gravity(Vector2i.DOWN)
	var diagonal: Vector2 = Vector2(-1.0, 1.0).normalized()
	var spawned: Orb3D = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, Vector2.ZERO)
	_assert_orb_acceleration(spawned, diagonal, Config.data.gravity_for_level(1))
	assert_near(
		spawned._jelly_frame_target_rotation,
		-PI * 0.25,
		TOLERANCE,
		"JELLY deform frame follows the active diagonal gravity"
	)
	spawned.set_jelly_mass(8.0, Config.data)
	assert_eq(spawned.level, 4, "mass growth reaches level four during transition")
	_assert_orb_acceleration(spawned, diagonal, Config.data.gravity_for_level(4))

	var waiter: Orb3D = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		1,
		Vector2(300.0, -400.0)
	)
	waiter.enter_entrance_wait(Vector2(300.0, -400.0), Vector2i.DOWN)
	board._update_entrance_waiters()
	assert_true(not waiter.is_waiting_at_entrance, "free entrance releases the waiting orb")
	assert_eq(waiter.entrance_gravity, Vector2i.DOWN, "entrance placement keeps the final direction")
	_assert_orb_acceleration(waiter, diagonal, Config.data.gravity_for_level(1))
	Config.data.gravity_turn_diagonal_time = original_time
	Config.data.game_mode = original_mode
	await _cleanup(board)


func test_turn_manager_does_not_accumulate_stability_during_transition() -> void:
	var snapshot: Dictionary = {
		"diagonal_time": Config.data.gravity_turn_diagonal_time,
		"stable_linear_speed": Config.data.stable_linear_speed,
		"stable_angular_speed": Config.data.stable_angular_speed,
		"stable_duration": Config.data.stable_duration,
		"max_settle_time": Config.data.max_settle_time,
	}
	Config.data.gravity_turn_diagonal_time = 0.15
	Config.data.stable_linear_speed = 1.0e9
	Config.data.stable_angular_speed = 1.0e9
	Config.data.stable_duration = 0.01
	Config.data.max_settle_time = 1.5
	var fixture: Dictionary = await _create_manager_fixture()
	var board: Board3D = fixture["board"] as Board3D
	var manager: TurnManager = fixture["manager"] as TurnManager
	Config.data.gravity_turn_diagonal_time = 0.0
	board.set_gravity(Vector2i.LEFT)
	Config.data.gravity_turn_diagonal_time = 0.15
	board.set_gravity(Vector2i.DOWN)
	manager.gravity = Vector2i.DOWN
	manager.state = TurnManager.State.SIMULATING
	manager._stable_time = 0.0
	manager.settle_elapsed = 0.0
	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	var transition_frames: int = ceili(0.15 * float(Engine.physics_ticks_per_second))
	for _frame: int in range(transition_frames):
		board._physics_process(tick)
		manager._physics_process(tick)
	assert_true(board.is_gravity_transition_active(), "transition remains active through frame eighteen")
	assert_near(manager._stable_time, 0.0, TOLERANCE, "stable time stays zero during transition")
	assert_near(manager.settle_elapsed, 0.15, TOLERANCE, "turn cap clock starts at the swipe")
	assert_eq(manager.state, TurnManager.State.SIMULATING, "transition cannot finish the turn")
	board._finish_gravity_transition(board._gravity_transition_id)
	manager._physics_process(tick)
	assert_near(manager._stable_time, tick, TOLERANCE, "stability starts after transition")
	Config.data.gravity_turn_diagonal_time = float(snapshot["diagonal_time"])
	Config.data.stable_linear_speed = float(snapshot["stable_linear_speed"])
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])
	Config.data.stable_duration = float(snapshot["stable_duration"])
	Config.data.max_settle_time = float(snapshot["max_settle_time"])
	await _cleanup(fixture["root"] as Node)


func _create_board() -> Board3D:
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	tree.root.add_child(board)
	await tree.process_frame
	return board


func _create_manager_fixture() -> Dictionary:
	var root: Node3D = Node3D.new()
	root.name = "GravityTurnManagerFixture"
	var board: Board3D = BOARD_SCENE.instantiate() as Board3D
	board.name = "Board"
	board.unique_name_in_owner = true
	board.set_physics_process(false)
	root.add_child(board)
	board.owner = root
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
	manager.set_physics_process(false)
	root.add_child(manager)
	manager.owner = root
	tree.root.add_child(root)
	await tree.process_frame
	return {"root": root, "board": board, "manager": manager}


func _assert_orb_acceleration(orb: Orb3D, direction: Vector2, strength: float) -> void:
	var body: RigidBody3D = orb.get_physics_body()
	var acceleration: Vector2 = Orb3D.world_vector_to_plane(body.constant_force / body.mass)
	assert_near(acceleration.length(), strength, 0.01, "gravity magnitude stays normalized")
	_assert_vector_near(acceleration.normalized(), direction.normalized(), TOLERANCE, "gravity direction")


func _assert_vector_near(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	assert_near(actual.x, expected.x, tolerance, "%s x" % message)
	assert_near(actual.y, expected.y, tolerance, "%s y" % message)


func _cleanup(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
	await tree.process_frame
