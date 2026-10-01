extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const COLLISION_RESOLVER_SCRIPT: Script = preload(
	"res://tests/support/PassiveCollisionResolver.gd"
)
const HIGH_THRESHOLD: float = 1.0e9
const WAIT_TIMEOUT_SECONDS: float = 4.0

var _restart_count: int = 0


func test_full_spawn_wall_enters_game_over_and_keeps_input_locked() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_single_center_spawn()
	Config.data.gravity_strength = 0.0
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	Config.data.stable_duration = Config.data.ghost_max_time + 0.05
	Config.data.max_settle_time = Config.data.ghost_max_time + 0.10
	var fixture: Dictionary = await _create_fixture(5101)
	var board: Board = fixture["board"] as Board
	var manager: TurnManager = fixture["manager"] as TurnManager
	var blocker: Orb = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		Config.data.orb_max_level,
		Vector2(0.0, -board.half_size() + Config.data.radius_for_level(7) + 4.0)
	)
	blocker.exit_ghost_state()
	var game_over_count: Array[int] = [0]
	manager.game_over.connect(func() -> void: game_over_count[0] += 1)

	manager.on_swipe(Vector2i.DOWN)
	await _wait_for_state(manager, TurnManager.State.GAME_OVER)
	assert_eq(game_over_count[0], 1, "game over signal count")
	assert_eq(InputRouter.is_locked(), true, "input remains locked")
	var blocked_spawn: Orb = _find_turn_spawn(board, 1)
	assert_true(blocked_spawn != null, "turn spawn remains active")
	if blocked_spawn != null:
		assert_true(blocked_spawn.is_ghost, "blocked turn spawn remains ghost")
		assert_true(
			blocked_spawn.ghost_elapsed > Config.data.ghost_max_time,
			"turn spawn does not use ghost timeout"
		)
	var turn_before: int = manager.turn_index
	var gravity_before: Vector2i = manager.gravity
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.turn_index, turn_before, "game-over swipe does not start turn")
	assert_eq(manager.gravity, gravity_before, "game-over swipe does not change gravity")

	_restart_count = 0
	InputRouter.restart_requested.connect(_record_restart)
	InputRouter._handle_event(_restart_key_event())
	assert_eq(_restart_count, 1, "R emits restart while input is locked")
	InputRouter.restart_requested.disconnect(_record_restart)
	await _cleanup_fixture(fixture, snapshot)


func test_bottom_pile_moves_away_on_up_swipe_without_game_over() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_single_center_spawn()
	Config.data.stable_linear_speed = 0.0
	Config.data.stable_angular_speed = 0.0
	Config.data.max_settle_time = 1.5
	var fixture: Dictionary = await _create_fixture(5102)
	var board: Board = fixture["board"] as Board
	var manager: TurnManager = fixture["manager"] as TurnManager
	var radius: float = Config.data.radius_for_level(1)
	var pile_orb: Orb = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(0.0, board.half_size() - radius - Config.data.spawn_margin),
		Vector2(0.0, -200.0)
	)
	pile_orb.exit_ghost_state()

	manager.on_swipe(Vector2i.UP)
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "moving pile survives turn")
	assert_eq(InputRouter.is_locked(), false, "input unlocks after surviving turn")
	var turn_spawn: Orb = _find_turn_spawn(board, 1)
	assert_true(turn_spawn != null, "up-swipe turn spawn exists")
	if turn_spawn != null:
		assert_true(not turn_spawn.is_ghost, "turn spawn found room before turn end")
	await _cleanup_fixture(fixture, snapshot)


func test_reaction_ghost_is_excluded_from_game_over() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_configure_single_center_spawn()
	var fixture: Dictionary = await _create_fixture(5103)
	var board: Board = fixture["board"] as Board
	var manager: TurnManager = fixture["manager"] as TurnManager
	var normal: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2.ZERO)
	normal.exit_ghost_state()
	var reaction_ghost: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 2, Vector2.ZERO)
	assert_eq(reaction_ghost.spawned_turn_index, -1, "reaction ghost has no turn marker")
	manager.turn_index = 1
	manager._is_initial_settle = false
	manager._on_settled()

	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "reaction ghost does not end game")
	assert_true(reaction_ghost.is_ghost, "reaction result may still be ghost")
	assert_eq(InputRouter.is_locked(), false, "reaction ghost check unlocks input")
	await _cleanup_fixture(fixture, snapshot)


func test_warning_signal_contains_only_direction_with_full_spawn_wall() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.grow_duration = 0.0
	Config.data.initial_orb_count = 0
	Config.data.spawn_count_per_turn = 1
	var fixture: Dictionary = await _create_fixture(5104)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var radius: float = Config.data.radius_for_level(1)
	var top_y: float = -board.half_size() + radius + Config.data.spawn_margin
	for x_position: int in range(-440, 441, 40):
		var orb: Orb = board.spawn_orb(
			OrbTypes.OrbColor.GREEN,
			1,
			Vector2(float(x_position), top_y)
		)
		orb.exit_ghost_state()
	spawner._next_batch = [
		{"color": OrbTypes.OrbColor.YELLOW, "level": 1, "t": 0.5},
	]
	var emissions: Array[Array] = []
	manager.warning_changed.connect(
		func(directions: Array[Vector2i]) -> void: emissions.append(directions.duplicate())
	)
	manager._update_warnings()

	assert_eq(manager.blocked_directions, [Vector2i.DOWN], "only top spawn wall is blocked")
	assert_eq(emissions.size(), 1, "warning emits once for changed directions")
	manager._update_warnings()
	assert_eq(emissions.size(), 1, "unchanged warning is not emitted again")
	await _cleanup_fixture(fixture, snapshot)


func _configure_single_center_spawn() -> void:
	Config.data.spawn_position_mode = GameConfig.SpawnPositionMode.CENTER
	Config.data.spawn_count_per_turn = 1
	Config.data.spawn_count_ramp_turns = 0
	Config.data.spawn_level_weights = PackedFloat32Array([1.0, 0.0])
	Config.data.initial_orb_count = 0
	Config.data.grow_duration = 0.0


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
	board.orb_contact.disconnect(resolver.report_contact)
	spawner.init_rng(seed)
	spawner.spawn_initial(board, Vector2i.DOWN)
	return {
		"root": fixture_root,
		"board": board,
		"spawner": spawner,
		"resolver": resolver,
		"manager": manager,
	}


func _find_turn_spawn(board: Board, turn_index: int) -> Orb:
	for orb: Orb in board.get_orbs():
		if orb.spawned_turn_index == turn_index:
			return orb
	return null


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


func _cleanup_fixture(fixture: Dictionary, snapshot: Dictionary) -> void:
	InputRouter.set_locked(false)
	_restore_config(snapshot)
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame


func _record_restart() -> void:
	_restart_count += 1


func _restart_key_event() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_R
	event.pressed = true
	return event
