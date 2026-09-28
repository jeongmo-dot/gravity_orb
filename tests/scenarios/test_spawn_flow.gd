extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const HIGH_THRESHOLD: float = 1.0e9
const WAIT_TIMEOUT_SECONDS: float = 8.0
const POSITION_TOLERANCE: float = 0.001
const REPRO_DIRECTIONS: Array[Vector2i] = [
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.UP,
	Vector2i.RIGHT,
	Vector2i.DOWN,
]

var _states: Array[TurnManager.State] = []
var _capture_board: Board
var _captured_spawn: Dictionary = {}


func test_spawn_line_matches_all_four_generation_walls() -> void:
	var snapshot: Dictionary = _snapshot_config()
	var fixture: Dictionary = await _create_fixture(4001, false)
	var board: Board = fixture["board"] as Board
	var radius: float = Config.data.radius_for_level(1)
	var distance: float = board.half_size() - radius - Config.data.spawn_margin
	var expected_origins: Dictionary = {
		Vector2i.DOWN: Vector2(0.0, -distance),
		Vector2i.UP: Vector2(0.0, distance),
		Vector2i.LEFT: Vector2(distance, 0.0),
		Vector2i.RIGHT: Vector2(-distance, 0.0),
	}

	for direction: Vector2i in OrbTypes.DIRECTIONS:
		var line: Dictionary = board.spawn_line(direction, radius)
		assert_true(
			(line["origin"] as Vector2).is_equal_approx(expected_origins[direction]),
			"%s spawn origin" % OrbTypes.dir_name(direction)
		)
		assert_eq(
			line["axis"],
			Vector2(OrbTypes.perpendicular(direction)),
			"%s spawn axis" % OrbTypes.dir_name(direction)
		)
		assert_near(
			float(line["extent"]),
			board.half_size() - radius,
			POSITION_TOLERANCE,
			"%s spawn extent" % OrbTypes.dir_name(direction)
		)

	print(
		"Spawn line origins: DOWN=%s UP=%s LEFT=%s RIGHT=%s" % [
			str(expected_origins[Vector2i.DOWN]),
			str(expected_origins[Vector2i.UP]),
			str(expected_origins[Vector2i.LEFT]),
			str(expected_origins[Vector2i.RIGHT]),
		]
	)
	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func test_initial_two_orbs_use_even_bottom_positions_without_overlap() -> void:
	var snapshot: Dictionary = _snapshot_config()
	var fixture: Dictionary = await _create_fixture(4002, true)
	var board: Board = fixture["board"] as Board
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(orbs.size(), 2, "initial orb count")

	var half: float = board.half_size()
	for index: int in range(orbs.size()):
		var orb: Orb = orbs[index]
		var fraction: float = float(index + 1) / float(orbs.size() + 1)
		var expected_position: Vector2 = Vector2(
			lerpf(-half, half, fraction),
			half - orb.get_radius() - Config.data.spawn_margin
		)
		assert_true(
			orb.position.is_equal_approx(expected_position),
			"initial position %d" % index
		)
		assert_true(
			absf(orb.position.x) + orb.get_radius() <= half,
			"initial orb %d inside horizontal walls" % index
		)
		assert_true(
			absf(orb.position.y) + orb.get_radius() <= half,
			"initial orb %d inside vertical walls" % index
		)
	if orbs.size() == 2:
		var center_distance: float = orbs[0].position.distance_to(orbs[1].position)
		var minimum_distance: float = orbs[0].get_radius() + orbs[1].get_radius()
		assert_true(center_distance >= minimum_distance, "initial orbs do not overlap")

	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func test_preview_matches_spawned_orb_and_spawn_line() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_set_fast_settle()
	var fixture: Dictionary = await _create_ready_fixture(4003)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var preview: Dictionary = spawner.peek_next()
	_arm_spawn_capture(manager, board)

	manager.on_swipe(Vector2i.RIGHT)
	await _wait_for_state(manager, TurnManager.State.SPAWNING)
	assert_eq(_captured_spawn["color"], preview["color"], "preview color")
	assert_eq(_captured_spawn["level"], preview["level"], "preview level")
	_assert_position_on_spawn_line(
		board,
		_captured_spawn["position"] as Vector2,
		float(_captured_spawn["radius"]),
		Vector2i.RIGHT,
		"preview spawn"
	)
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	assert_eq(board.get_orbs().size(), 3, "one orb added after one turn")

	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func test_seed_777_reproduces_five_turn_sequence() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_set_fast_settle()
	var first: Array[Dictionary] = await _run_seeded_turns(777)
	var second: Array[Dictionary] = await _run_seeded_turns(777)
	assert_eq(first, second, "seeded color, level, and spawn position sequence")
	_restore_config(snapshot)


func test_three_turns_add_three_orbs_and_settle_in_spawning_state() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_set_fast_settle()
	var fixture: Dictionary = await _create_ready_fixture(4005)
	var board: Board = fixture["board"] as Board
	var manager: TurnManager = fixture["manager"] as TurnManager
	_states.clear()
	manager.state_changed.connect(_record_state)
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]

	for direction: Vector2i in directions:
		manager.on_swipe(direction)
		await _wait_for_state(manager, TurnManager.State.SPAWNING)
		await tree.physics_frame
		assert_eq(manager.state, TurnManager.State.SPAWNING, "SPAWNING persists for settle")
		await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)

	assert_eq(board.get_orbs().size(), 5, "initial two plus three turn spawns")
	var expected_states: Array[TurnManager.State] = []
	for _turn: int in range(3):
		expected_states.append_array(
			[
				TurnManager.State.SIMULATING,
				TurnManager.State.SPAWNING,
				TurnManager.State.CHECK_GAMEOVER,
				TurnManager.State.WAITING_INPUT,
			]
		)
	assert_eq(_states, expected_states, "three-turn state sequence")

	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func _run_seeded_turns(seed: int) -> Array[Dictionary]:
	var fixture: Dictionary = await _create_ready_fixture(seed)
	var board: Board = fixture["board"] as Board
	var manager: TurnManager = fixture["manager"] as TurnManager
	var sequence: Array[Dictionary] = []
	_arm_spawn_capture(manager, board)

	for direction: Vector2i in REPRO_DIRECTIONS:
		_captured_spawn.clear()
		manager.on_swipe(direction)
		await _wait_for_state(manager, TurnManager.State.SPAWNING)
		var spawn_position: Vector2 = _captured_spawn["position"] as Vector2
		_assert_position_on_spawn_line(
			board,
			spawn_position,
			float(_captured_spawn["radius"]),
			direction,
			"seed %d" % seed
		)
		sequence.append(
			{
				"color": int(_captured_spawn["color"]),
				"level": int(_captured_spawn["level"]),
				"position": spawn_position,
			}
		)
		print(
			"Spawn flow seed=%d turn=%d gravity=%s color=%d level=%d position=%s" % [
				seed,
				sequence.size(),
				OrbTypes.dir_name(direction),
				int(_captured_spawn["color"]),
				int(_captured_spawn["level"]),
				str(spawn_position),
			]
		)
		await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)

	await _cleanup_fixture(fixture)
	return sequence


func _create_ready_fixture(seed: int) -> Dictionary:
	var fixture: Dictionary = await _create_fixture(seed, true)
	var manager: TurnManager = fixture["manager"] as TurnManager
	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	return fixture


func _create_fixture(seed: int, create_initial: bool) -> Dictionary:
	InputRouter.set_locked(false)
	var fixture_root: Node = Node.new()
	fixture_root.name = "SpawnFlowFixture"

	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root

	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	fixture_root.add_child(spawner)
	spawner.owner = fixture_root

	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	fixture_root.add_child(manager)
	manager.owner = fixture_root

	tree.root.add_child(fixture_root)
	await tree.process_frame
	spawner.init_rng(seed)
	if create_initial:
		spawner.spawn_initial(board, Vector2i.DOWN)
	return {
		"root": fixture_root,
		"board": board,
		"spawner": spawner,
		"manager": manager,
	}


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(
		float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS
	)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
	assert_eq(manager.state, target, "state wait timeout")


func _assert_position_on_spawn_line(
	board: Board,
	position: Vector2,
	radius: float,
	gravity: Vector2i,
	context: String
) -> void:
	var line: Dictionary = board.spawn_line(gravity, radius)
	var axis: Vector2 = line["axis"] as Vector2
	var offset: Vector2 = position - (line["origin"] as Vector2)
	var along_line: float = offset.dot(axis)
	assert_near(absf(offset.cross(axis)), 0.0, POSITION_TOLERANCE, context)
	assert_true(
		absf(along_line) <= float(line["extent"]) + POSITION_TOLERANCE,
		"%s position within line extent" % context
	)


func _set_fast_settle() -> void:
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	Config.data.spawn_position_mode = GameConfig.SpawnPositionMode.RANDOM


func _snapshot_config() -> Dictionary:
	return {
		"stable_linear_speed": Config.data.stable_linear_speed,
		"stable_angular_speed": Config.data.stable_angular_speed,
		"spawn_position_mode": Config.data.spawn_position_mode,
		"initial_orb_count": Config.data.initial_orb_count,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.stable_linear_speed = float(snapshot["stable_linear_speed"])
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])
	Config.data.spawn_position_mode = int(snapshot["spawn_position_mode"]) as GameConfig.SpawnPositionMode
	Config.data.initial_orb_count = int(snapshot["initial_orb_count"])


func _cleanup_fixture(fixture: Dictionary) -> void:
	InputRouter.set_locked(false)
	_capture_board = null
	_captured_spawn.clear()
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame


func _record_state(next_state: TurnManager.State) -> void:
	_states.append(next_state)


func _arm_spawn_capture(manager: TurnManager, board: Board) -> void:
	_capture_board = board
	_captured_spawn.clear()
	manager.state_changed.connect(_capture_spawn_on_state_change)


func _capture_spawn_on_state_change(next_state: TurnManager.State) -> void:
	if next_state != TurnManager.State.SPAWNING or not is_instance_valid(_capture_board):
		return
	var orbs: Array[Orb] = _capture_board.get_orbs()
	var spawned: Orb = orbs[orbs.size() - 1]
	_captured_spawn = {
		"color": spawned.color,
		"level": spawned.level,
		"position": spawned.position,
		"radius": spawned.get_radius(),
	}
