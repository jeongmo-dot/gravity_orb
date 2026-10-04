extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const COLLISION_RESOLVER_SCRIPT: Script = preload(
	"res://tests/support/PassiveCollisionResolver.gd"
)
const HIGH_THRESHOLD: float = 1.0e9
const WAIT_TIMEOUT_SECONDS: float = 4.0


func test_blocked_preferred_position_uses_nearest_free_slot() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_single_center_spawn()
	var fixture: Dictionary = await _create_fixture(5101)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var radius: float = Config.data.radius_for_level(1)
	var line: Dictionary = board.spawn_line(Vector2i.DOWN, radius)
	var preferred: Vector2 = line["origin"] as Vector2
	var blocker: Orb = board.spawn_orb(OrbTypes.OrbColor.GREEN, 1, preferred)
	blocker.exit_ghost_state()
	blocker.freeze = true
	_set_next_level_one_batch(spawner, [0.5])

	var spawned: Array = spawner.try_spawn(board, Vector2i.DOWN, 1)
	assert_eq(spawned.size(), 1, "one orb spawned")
	var orb: Orb = spawned[0]
	assert_true(not orb.is_waiting_at_entrance, "nearby free slot avoids waiting")
	assert_true(orb.position.distance_to(preferred) > 1.0, "blocked preference is relocated")
	assert_true(
		board.maximum_normal_overlap(orb) <= Config.data.ghost_exit_overlap,
		"nearest slot satisfies overlap criterion"
	)
	await _cleanup_fixture(fixture, snapshot)


func test_full_spawn_wall_waits_without_falling_then_game_over() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_single_center_spawn()
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	Config.data.stable_duration = 0.10
	Config.data.max_settle_time = 0.25
	var fixture: Dictionary = await _create_fixture(5102)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	_fill_spawn_wall(board, Vector2i.DOWN, true)
	_set_next_level_one_batch(spawner, [0.5])

	manager.on_swipe(Vector2i.DOWN)
	await tree.physics_frame
	await tree.physics_frame
	var waiting: Array[Orb] = board.entrance_waiting_orbs()
	assert_eq(waiting.size(), 1, "full wall creates one entrance waiter")
	var start_position: Vector2 = waiting[0].position if not waiting.is_empty() else Vector2.ZERO
	await _wait_for_state(manager, TurnManager.State.GAME_OVER)
	assert_eq(manager.state, TurnManager.State.GAME_OVER, "waiter ends the turn in game over")
	assert_eq(InputRouter.is_locked(), true, "game over keeps input locked")
	if not waiting.is_empty():
		assert_true(waiting[0].is_waiting_at_entrance, "wait state remains at game over")
		assert_true(
			waiting[0].position.distance_to(start_position) < 1.0,
			"entrance waiter does not fall"
		)
	await _cleanup_fixture(fixture, snapshot)


func test_bottom_wall_moves_away_waiter_enters_without_game_over() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_single_center_spawn()
	Config.data.stable_linear_speed = 0.0
	Config.data.stable_angular_speed = 0.0
	Config.data.max_settle_time = 1.5
	var fixture: Dictionary = await _create_fixture(5103)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	_fill_spawn_wall(board, Vector2i.UP, true)
	_set_next_level_one_batch(spawner, [0.5])

	manager.on_swipe(Vector2i.UP)
	await tree.physics_frame
	await tree.physics_frame
	var spawned: Array[Orb] = []
	for orb: Orb in board.get_orbs():
		if orb.is_waiting_at_entrance:
			spawned.append(orb)
	assert_eq(spawned.size(), 1, "orb initially waits behind bottom pile")
	for orb: Orb in board.get_orbs():
		if orb.is_waiting_at_entrance:
			continue
		orb.freeze = false
		orb.linear_velocity = Vector2.UP * 500.0
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "opened entrance survives turn")
	assert_eq(board.entrance_waiting_orbs().size(), 0, "waiter entered after pile moved")
	assert_eq(InputRouter.is_locked(), false, "input unlocks after surviving turn")
	await _cleanup_fixture(fixture, snapshot)


func test_two_orb_batch_reserves_distinct_free_slots() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_single_center_spawn()
	Config.data.spawn_count_per_turn = 2
	var fixture: Dictionary = await _create_fixture(5104)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	_set_next_level_one_batch(spawner, [0.5, 0.5])

	var spawned: Array = spawner.try_spawn(board, Vector2i.DOWN, 1)
	assert_eq(spawned.size(), 2, "two-orb batch spawned")
	assert_true(not spawned[0].is_waiting_at_entrance, "first orb has a free slot")
	assert_true(not spawned[1].is_waiting_at_entrance, "second orb has a reserved free slot")
	var required_distance: float = (
		spawned[0].get_radius()
		+ spawned[1].get_radius()
		- Config.data.ghost_exit_overlap
	)
	assert_true(
		spawned[0].position.distance_to(spawned[1].position) >= required_distance,
		"batch placements do not overlap beyond the shared criterion"
	)
	await _cleanup_fixture(fixture, snapshot)


func test_warning_set_matches_directions_that_would_wait() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_single_center_spawn()
	var fixture: Dictionary = await _create_fixture(5105)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	_fill_spawn_wall(board, Vector2i.DOWN, true)
	_set_next_level_one_batch(spawner, [0.5])
	var warnings: Array[Vector2i] = board.blocked_spawn_directions(spawner.peek_next())
	var actual_waits: Array[Vector2i] = []

	for direction_index: int in range(OrbTypes.DIRECTIONS.size()):
		var direction: Vector2i = OrbTypes.DIRECTIONS[direction_index]
		var direction_fixture: Dictionary = await _create_fixture(5200 + direction_index)
		var direction_board: Board = direction_fixture["board"] as Board
		var direction_spawner: Spawner = direction_fixture["spawner"] as Spawner
		_fill_spawn_wall(direction_board, Vector2i.DOWN, true)
		_set_next_level_one_batch(direction_spawner, [0.5])
		var direction_spawned: Array = direction_spawner.try_spawn(
			direction_board,
			direction,
			1
		)
		if direction_spawned[0].is_waiting_at_entrance:
			actual_waits.append(direction)
		await _cleanup_fixture(direction_fixture, snapshot, false)

	assert_eq(warnings, actual_waits, "warning directions equal actual entrance waits")
	await _cleanup_fixture(fixture, snapshot)


func _configure_single_center_spawn() -> void:
	Config.data.spawn_position_mode = GameConfig.SpawnPositionMode.CENTER
	Config.data.spawn_count_per_turn = 1
	Config.data.spawn_count_ramp_turns = 0
	Config.data.spawn_level_weights = PackedFloat32Array([1.0, 0.0])
	Config.data.initial_orb_count = 0
	Config.data.grow_duration = 0.0


func _set_next_level_one_batch(spawner: Spawner, positions: Array[float]) -> void:
	spawner._preview_batches.clear()
	var next_batch: Array[Dictionary] = []
	for position_t: float in positions:
		next_batch.append(
			{
				"color": OrbTypes.OrbColor.YELLOW,
				"level": 1,
				"t": position_t,
			}
		)
	spawner._preview_batches.append(next_batch)


func _fill_spawn_wall(board: Board, gravity: Vector2i, frozen: bool) -> void:
	var radius: float = Config.data.radius_for_level(1)
	var line: Dictionary = board.spawn_line(gravity, radius)
	var origin: Vector2 = line["origin"] as Vector2
	var axis: Vector2 = line["axis"] as Vector2
	var extent: float = float(line["extent"])
	var offset: float = -extent
	while offset <= extent:
		var orb: Orb = board.spawn_orb(
			OrbTypes.OrbColor.GREEN,
			1,
			origin + axis * offset
		)
		orb.exit_ghost_state()
		orb.freeze = frozen
		offset += 45.0
	if offset - 45.0 < extent:
		var edge_orb: Orb = board.spawn_orb(
			OrbTypes.OrbColor.GREEN,
			1,
			origin + axis * extent
		)
		edge_orb.exit_ghost_state()
		edge_orb.freeze = frozen


func _create_fixture(seed: int) -> Dictionary:
	InputRouter.set_locked(false)
	var fixture_root: Node = Node.new()
	fixture_root.name = "GameOverFixture"
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
	var resolver: CollisionResolver = COLLISION_RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root
	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	fixture_root.add_child(manager)
	manager.owner = fixture_root
	tree.root.add_child(fixture_root)
	await tree.process_frame
	spawner.init_rng(seed)
	spawner.spawn_initial(board, Vector2i.DOWN)
	return {
		"root": fixture_root,
		"board": board,
		"spawner": spawner,
		"resolver": resolver,
		"manager": manager,
	}


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
	assert_eq(manager.state, target, "state wait timeout")


func _snapshot_config() -> Dictionary:
	return {
		"gravity_strength": Config.data.gravity_strength,
		"stable_linear_speed": Config.data.stable_linear_speed,
		"stable_angular_speed": Config.data.stable_angular_speed,
		"stable_duration": Config.data.stable_duration,
		"max_settle_time": Config.data.max_settle_time,
		"spawn_position_mode": Config.data.spawn_position_mode,
		"spawn_count_per_turn": Config.data.spawn_count_per_turn,
		"spawn_count_ramp_turns": Config.data.spawn_count_ramp_turns,
		"spawn_level_weights": Config.data.spawn_level_weights.duplicate(),
		"initial_orb_count": Config.data.initial_orb_count,
		"grow_duration": Config.data.grow_duration,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.gravity_strength = float(snapshot["gravity_strength"])
	Config.data.stable_linear_speed = float(snapshot["stable_linear_speed"])
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])
	Config.data.stable_duration = float(snapshot["stable_duration"])
	Config.data.max_settle_time = float(snapshot["max_settle_time"])
	Config.data.spawn_position_mode = int(snapshot["spawn_position_mode"]) as GameConfig.SpawnPositionMode
	Config.data.spawn_count_per_turn = int(snapshot["spawn_count_per_turn"])
	Config.data.spawn_count_ramp_turns = int(snapshot["spawn_count_ramp_turns"])
	Config.data.spawn_level_weights = snapshot["spawn_level_weights"] as PackedFloat32Array
	Config.data.initial_orb_count = int(snapshot["initial_orb_count"])
	Config.data.grow_duration = float(snapshot["grow_duration"])


func _cleanup_fixture(
	fixture: Dictionary,
	snapshot: Dictionary,
	restore_config: bool = true
) -> void:
	InputRouter.set_locked(false)
	if restore_config:
		_restore_config(snapshot)
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame
