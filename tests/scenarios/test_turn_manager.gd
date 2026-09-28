extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const FIXTURE_SEED: int = 3000
const HIGH_THRESHOLD: float = 1.0e9
const WAIT_TIMEOUT_SECONDS: float = 4.0

var _states: Array[TurnManager.State] = []
var _turn_starts: Array[Dictionary] = []
var _turn_finishes: Array[Dictionary] = []


func test_t1_start_game_settles_without_starting_turn() -> void:
	var snapshot: Dictionary = _snapshot_m3_config()
	var fixture: Dictionary = await _create_fixture(FIXTURE_SEED + 1)
	var manager: TurnManager = fixture["manager"] as TurnManager
	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)

	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "initial state after settle")
	assert_eq(manager.turn_index, 0, "initial settle must not start a turn")
	assert_eq(InputRouter.is_locked(), false, "input unlocked after initial settle")
	await _cleanup_fixture(fixture, snapshot)


func test_t2_swipe_emits_full_state_and_turn_signal_sequence() -> void:
	var snapshot: Dictionary = _snapshot_m3_config()
	var fixture: Dictionary = await _create_ready_fixture(FIXTURE_SEED + 2)
	var manager: TurnManager = fixture["manager"] as TurnManager
	_reset_signal_records()
	manager.state_changed.connect(_record_state)
	manager.turn_started.connect(_record_turn_started)
	manager.turn_finished.connect(_record_turn_finished)

	manager.on_swipe(Vector2i.RIGHT)
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)

	assert_eq(
		_states,
		[
			TurnManager.State.SIMULATING,
			TurnManager.State.SPAWNING,
			TurnManager.State.CHECK_GAMEOVER,
			TurnManager.State.WAITING_INPUT,
		],
		"state transition order"
	)
	assert_eq(_turn_starts.size(), 1, "turn_started count")
	if _turn_starts.size() == 1:
		assert_eq(_turn_starts[0]["turn_index"], 1, "started turn index")
		assert_eq(_turn_starts[0]["direction"], Vector2i.RIGHT, "started direction")
	assert_eq(_turn_finishes.size(), 1, "turn_finished count")
	if _turn_finishes.size() == 1:
		assert_eq(_turn_finishes[0]["turn_index"], 1, "finished turn index")
		assert_eq(_turn_finishes[0]["max_chain"], 0, "M3 max chain")
	assert_eq(manager.gravity, Vector2i.RIGHT, "gravity after turn")
	await _cleanup_fixture(fixture, snapshot)


func test_t3_swipe_during_simulation_is_ignored() -> void:
	var snapshot: Dictionary = _snapshot_m3_config()
	var fixture: Dictionary = await _create_ready_fixture(FIXTURE_SEED + 3)
	var manager: TurnManager = fixture["manager"] as TurnManager
	manager.on_swipe(Vector2i.RIGHT)
	var turn_before_ignored_swipe: int = manager.turn_index
	var gravity_before_ignored_swipe: Vector2i = manager.gravity

	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.turn_index, turn_before_ignored_swipe, "turn unchanged while simulating")
	assert_eq(manager.gravity, gravity_before_ignored_swipe, "gravity unchanged while simulating")
	assert_eq(InputRouter.is_locked(), true, "input locked while simulating")

	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	await _cleanup_fixture(fixture, snapshot)


func test_t4_stable_duration_uses_scaled_seconds() -> void:
	var snapshot: Dictionary = _snapshot_m3_config()
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	var fixture: Dictionary = await _create_ready_fixture(FIXTURE_SEED + 4)
	var manager: TurnManager = fixture["manager"] as TurnManager

	manager.on_swipe(Vector2i.RIGHT)
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	var elapsed: float = manager._settle_elapsed
	var tick_seconds: float = 1.0 / float(Engine.physics_ticks_per_second)
	var elapsed_ticks: int = roundi(elapsed * float(Engine.physics_ticks_per_second))
	print(
		"TurnManager T4 stable settle: elapsed=%.6f ticks=%d target=%.2f" % [
			elapsed,
			elapsed_ticks,
			Config.data.stable_duration,
		]
	)
	assert_true(
		absf(elapsed - Config.data.stable_duration) <= tick_seconds,
		"stable settle within one physics tick"
	)
	await _cleanup_fixture(fixture, snapshot)


func test_t5_unstable_motion_forces_settle_at_maximum_time() -> void:
	var snapshot: Dictionary = _snapshot_m3_config()
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	var fixture: Dictionary = await _create_ready_fixture(FIXTURE_SEED + 5)
	var manager: TurnManager = fixture["manager"] as TurnManager
	Config.data.stable_linear_speed = 0.0
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])

	manager.on_swipe(Vector2i.RIGHT)
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	var elapsed: float = manager._settle_elapsed
	var tick_seconds: float = 1.0 / float(Engine.physics_ticks_per_second)
	var elapsed_ticks: int = roundi(elapsed * float(Engine.physics_ticks_per_second))
	print(
		"TurnManager T5 forced settle: elapsed=%.6f ticks=%d target=%.2f" % [
			elapsed,
			elapsed_ticks,
			Config.data.max_settle_time,
		]
	)
	assert_true(
		absf(elapsed - Config.data.max_settle_time) <= tick_seconds,
		"forced settle within one physics tick"
	)
	assert_eq(manager.turn_index, 1, "forced settle completes the turn")
	await _cleanup_fixture(fixture, snapshot)


func test_t6_disallowed_same_direction_swipe_is_ignored_without_lock() -> void:
	var snapshot: Dictionary = _snapshot_m3_config()
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	Config.data.allow_same_direction_swipe = false
	var fixture: Dictionary = await _create_ready_fixture(FIXTURE_SEED + 6)
	var manager: TurnManager = fixture["manager"] as TurnManager

	manager.on_swipe(Vector2i.DOWN)
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "same direction state")
	assert_eq(manager.turn_index, 0, "same direction turn index")
	assert_eq(InputRouter.is_locked(), false, "same direction does not lock input")
	await _cleanup_fixture(fixture, snapshot)


func test_t7_allowed_same_direction_swipe_starts_turn() -> void:
	var snapshot: Dictionary = _snapshot_m3_config()
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	Config.data.allow_same_direction_swipe = true
	var fixture: Dictionary = await _create_ready_fixture(FIXTURE_SEED + 7)
	var manager: TurnManager = fixture["manager"] as TurnManager

	manager.on_swipe(Vector2i.DOWN)
	assert_eq(manager.turn_index, 1, "same direction starts turn")
	assert_eq(manager.state, TurnManager.State.SIMULATING, "same direction simulates")
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	await _cleanup_fixture(fixture, snapshot)


func _create_ready_fixture(seed: int) -> Dictionary:
	var fixture: Dictionary = await _create_fixture(seed)
	var manager: TurnManager = fixture["manager"] as TurnManager
	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	return fixture


func _create_fixture(seed: int) -> Dictionary:
	InputRouter.set_locked(false)
	var fixture_root: Node = Node.new()
	fixture_root.name = "TurnManagerFixture"

	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root

	var manager: TurnManager = TURN_MANAGER_SCRIPT.new() as TurnManager
	manager.name = "TurnManager"
	fixture_root.add_child(manager)
	manager.owner = fixture_root

	tree.root.add_child(fixture_root)
	await tree.process_frame

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var position: Vector2 = Vector2(
		rng.randf_range(-120.0, 120.0),
		rng.randf_range(-120.0, 120.0)
	)
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, position)
	return {"root": fixture_root, "board": board, "manager": manager}


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(
		float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS
	)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
	assert_eq(manager.state, target, "state wait timeout")


func _cleanup_fixture(fixture: Dictionary, snapshot: Dictionary) -> void:
	InputRouter.set_locked(false)
	_restore_m3_config(snapshot)
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame


func _snapshot_m3_config() -> Dictionary:
	return {
		"stable_linear_speed": Config.data.stable_linear_speed,
		"stable_angular_speed": Config.data.stable_angular_speed,
		"stable_duration": Config.data.stable_duration,
		"max_settle_time": Config.data.max_settle_time,
		"allow_same_direction_swipe": Config.data.allow_same_direction_swipe,
	}


func _restore_m3_config(snapshot: Dictionary) -> void:
	Config.data.stable_linear_speed = float(snapshot["stable_linear_speed"])
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])
	Config.data.stable_duration = float(snapshot["stable_duration"])
	Config.data.max_settle_time = float(snapshot["max_settle_time"])
	Config.data.allow_same_direction_swipe = bool(snapshot["allow_same_direction_swipe"])


func _reset_signal_records() -> void:
	_states.clear()
	_turn_starts.clear()
	_turn_finishes.clear()


func _record_state(next_state: TurnManager.State) -> void:
	_states.append(next_state)


func _record_turn_started(next_turn_index: int, direction: Vector2i) -> void:
	_turn_starts.append({"turn_index": next_turn_index, "direction": direction})


func _record_turn_finished(finished_turn_index: int, max_chain: int) -> void:
	_turn_finishes.append({"turn_index": finished_turn_index, "max_chain": max_chain})
