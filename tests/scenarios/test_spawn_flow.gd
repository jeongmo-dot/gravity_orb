extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const COLLISION_RESOLVER_SCRIPT: Script = preload(
	"res://tests/support/PassiveCollisionResolver.gd"
)
const HIGH_THRESHOLD: float = 1.0e9
const WAIT_TIMEOUT_SECONDS: float = 8.0
const POSITION_TOLERANCE: float = 0.001
const OVERLAP_OBSERVE_SECONDS: float = 0.5
const OVERLAP_PENETRATION_LIMIT: float = 12.0
const CONTINUOUS_PENETRATION_LIMIT: float = 14.0
const DIVERGENCE_SPEED: float = 5000.0
const DIVERGENCE_MARGIN: float = 100.0
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
		assert_true(not orb.is_ghost, "initial orb %d is normal" % index)
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
	Config.data.spawn_count_per_turn = 1
	_set_fast_settle()
	var fixture: Dictionary = await _create_ready_fixture(4003)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var preview_batch: Array[Dictionary] = spawner.peek_next()
	var preview: Dictionary = preview_batch[0]
	_arm_spawn_capture(manager, board)

	var frame_before_swipe: int = Engine.get_physics_frames()
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.state, TurnManager.State.SPAWNING, "swipe enters SPAWNING")
	await tree.physics_frame
	assert_board_motion_bounds(board, "preview spawn frame")
	assert_eq(manager.state, TurnManager.State.SIMULATING, "spawn starts simulation")
	assert_eq(
		Engine.get_physics_frames() - frame_before_swipe,
		1,
		"spawn happens on the next physics frame"
	)
	assert_eq(board.get_orbs().size(), 3, "one orb exists after one physics frame")
	assert_eq(_captured_spawn["color"], preview["color"], "preview color")
	assert_eq(_captured_spawn["level"], preview["level"], "preview level")
	assert_eq(_captured_spawn["is_ghost"], true, "turn spawn starts as ghost")
	assert_eq(_captured_spawn["collision_layer"], 4, "turn spawn ghost layer")
	assert_eq(_captured_spawn["collision_mask"], 1, "turn spawn wall-only mask")
	assert_near(
		float(_captured_spawn["alpha"]),
		Config.data.ghost_alpha,
		POSITION_TOLERANCE,
		"turn spawn ghost alpha"
	)
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


func test_two_turn_preview_promotes_and_spawns_three_turns_in_order() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.spawn_count_per_turn = 1
	Config.data.preview_turns = 2
	_set_fast_settle()
	var fixture: Dictionary = await _create_ready_fixture(4026)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var promoted_batch: Array = []
	_arm_spawn_capture(manager, board)

	for turn_offset: int in range(3):
		var preview: Array = spawner.peek_preview()
		assert_eq(preview.size(), 2, "preview queue turn %d" % (turn_offset + 1))
		var next_batch: Array = preview[0] as Array
		var then_batch: Array = preview[1] as Array
		if not promoted_batch.is_empty():
			assert_eq(next_batch, promoted_batch, "THEN promotes to NEXT")
		var expected: Dictionary = next_batch[0] as Dictionary
		promoted_batch = then_batch.duplicate(true)
		_captured_spawn.clear()
		manager.on_swipe(REPRO_DIRECTIONS[turn_offset])
		await _wait_for_state(manager, TurnManager.State.SIMULATING)
		assert_eq(_captured_spawn["color"], expected["color"], "preview color")
		assert_eq(_captured_spawn["level"], expected["level"], "preview level")
		await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)

	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func test_preview_turns_one_matches_single_batch_spawn() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.spawn_count_per_turn = 1
	Config.data.preview_turns = 1
	_set_fast_settle()
	var fixture: Dictionary = await _create_ready_fixture(4027)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var preview: Array = spawner.peek_preview()
	assert_eq(preview.size(), 1, "one preview turn")
	var expected: Dictionary = (preview[0] as Array)[0] as Dictionary
	_arm_spawn_capture(manager, board)
	manager.on_swipe(Vector2i.RIGHT)
	await _wait_for_state(manager, TurnManager.State.SIMULATING)
	assert_eq(_captured_spawn["color"], expected["color"], "single preview color")
	assert_eq(_captured_spawn["level"], expected["level"], "single preview level")
	assert_eq(spawner.peek_preview().size(), 1, "single preview queue renewed")

	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func test_count_two_spawns_whole_preview_batch_in_one_physics_frame() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.spawn_count_per_turn = 2
	_set_fast_settle()
	var fixture: Dictionary = await _create_ready_fixture(4015)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	var preview: Array[Dictionary] = spawner.peek_next()
	assert_eq(preview.size(), 2, "two-item preview batch")

	manager.on_swipe(Vector2i.RIGHT)
	await tree.physics_frame
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(orbs.size(), 4, "two orbs created in spawn frame")
	for index: int in range(2):
		var spawned: Orb = orbs[orbs.size() - 2 + index]
		assert_eq(spawned.color, int(preview[index]["color"]), "batch color %d" % index)
		assert_eq(spawned.level, int(preview[index]["level"]), "batch level %d" % index)
		assert_eq(
			spawned._spawn_physics_frame,
			orbs[orbs.size() - 2]._spawn_physics_frame,
			"batch physics frame %d" % index
		)
	assert_eq(spawner.peek_next().size(), 2, "next batch renewed")

	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func test_seed_777_reproduces_five_turn_sequence() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_set_fast_settle()
	var first: Array[Dictionary] = await _run_seeded_turns(777)
	var second: Array[Dictionary] = await _run_seeded_turns(777)
	assert_eq(first, second, "seeded color, level, and spawn position sequence")
	_restore_config(snapshot)


func test_three_turns_spawn_before_one_settle_each() -> void:
	var snapshot: Dictionary = _snapshot_config()
	_set_fast_settle()
	var spawn_count: int = Config.data.spawn_count_per_turn
	var fixture: Dictionary = await _create_ready_fixture(4005)
	var board: Board = fixture["board"] as Board
	var manager: TurnManager = fixture["manager"] as TurnManager
	_states.clear()
	manager.state_changed.connect(_record_state)
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.LEFT]

	for direction: Vector2i in directions:
		var orb_count_before: int = board.get_orbs().size()
		manager.on_swipe(direction)
		assert_eq(manager.state, TurnManager.State.SPAWNING, "swipe enters SPAWNING")
		await _wait_for_state(manager, TurnManager.State.SIMULATING)
		assert_eq(
			board.get_orbs().size(),
			orb_count_before + spawn_count,
			"spawn precedes settling"
		)
		await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)

	assert_eq(
		board.get_orbs().size(),
		Config.data.initial_orb_count + directions.size() * spawn_count,
		"initial orbs plus three turn batches"
	)
	var expected_states: Array[TurnManager.State] = []
	for _turn: int in range(3):
		expected_states.append_array(
			[
				TurnManager.State.SPAWNING,
				TurnManager.State.SIMULATING,
				TurnManager.State.CHECK_GAMEOVER,
				TurnManager.State.WAITING_INPUT,
			]
		)
	assert_eq(_states, expected_states, "three-turn state sequence")

	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func test_center_spawn_relocates_from_overlap_and_remains_inside_board() -> void:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.spawn_count_per_turn = 1
	Config.data.spawn_position_mode = GameConfig.SpawnPositionMode.CENTER
	var fixture: Dictionary = await _create_fixture(4006, false)
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager

	var configured_initial_count: int = Config.data.initial_orb_count
	Config.data.initial_orb_count = 0
	spawner.spawn_initial(board, Vector2i.DOWN)
	Config.data.initial_orb_count = configured_initial_count

	var radius: float = Config.data.radius_for_level(1)
	var bottom_y: float = board.half_size() - radius - Config.data.spawn_margin
	var bottom_x_positions: Array[float] = [-360.0, -240.0, -120.0, 0.0, 120.0, 240.0, 360.0]
	var overlap_dummy: Orb
	for index: int in range(bottom_x_positions.size()):
		var orb: Orb = board.spawn_orb(
			index % Config.data.color_display.size(),
			1,
			Vector2(bottom_x_positions[index], bottom_y)
		)
		if is_zero_approx(bottom_x_positions[index]):
			overlap_dummy = orb
	board.spawn_orb(1, 1, Vector2(0.0, bottom_y - radius * 2.0))

	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)
	assert_eq(board.get_orbs().size(), 8, "eight level-1 orbs stabilized at bottom")

	var preview_batch: Array[Dictionary] = spawner.peek_next()
	var preview: Dictionary = preview_batch[0]
	var spawned_final_radius: float = Config.data.radius_for_level(int(preview["level"]))
	var spawn_line: Dictionary = board.spawn_line(Vector2i.UP, spawned_final_radius)
	var overlap_position: Vector2 = spawn_line["origin"] as Vector2
	overlap_dummy.position = overlap_position
	overlap_dummy.linear_velocity = Vector2.ZERO
	overlap_dummy.angular_velocity = 0.0
	_arm_spawn_capture(manager, board)

	manager.on_swipe(Vector2i.UP)
	var state_after_spawn: TurnManager.State = await manager.state_changed
	assert_eq(state_after_spawn, TurnManager.State.SIMULATING, "overlap spawn starts simulation")
	var spawn_distance: float = overlap_dummy.position.distance_to(
		_captured_spawn["position"] as Vector2
	)
	assert_true(
		spawn_distance
		>= (
			overlap_dummy.get_current_radius()
			+ spawned_final_radius
			- Config.data.ghost_exit_overlap
		),
		"CENTER spawn relocates to a free entrance slot"
	)

	var metrics: Dictionary = await _observe_board(board, OVERLAP_OBSERVE_SECONDS)
	print(
		"Spawn overlap seed=4006 duration=%.2f departures=%d divergences=%d max_penetration=%.3f max_penetration_ratio=%.6f ratio_level=%d max_speed=%.3f escape_guards=%d wall_recoveries=%d recovery_timeout_lags=%s timeout_corrections=%d ghost_timeouts=%d ghost_avg=%.6f" % [
			OVERLAP_OBSERVE_SECONDS,
			int(metrics["departures"]),
			int(metrics["divergences"]),
			float(metrics["max_penetration"]),
			float(metrics["max_penetration_ratio"]),
			int(metrics["max_penetration_level"]),
			float(metrics["max_speed"]),
			int(metrics["escape_guards"]),
			board.wall_recovery_count,
			str(board.wall_recovery_since_last_ghost_timeout_frames),
			board.timeout_correction_count,
			board.ghost_timeout_count,
			board.average_ghost_duration(),
		]
	)
	assert_eq(int(metrics["departures"]), 0, "overlap case orb center departures")
	assert_eq(int(metrics["divergences"]), 0, "overlap case divergent orb frames")
	assert_eq(int(metrics["escape_guards"]), 0, "overlap case escape guard activations")
	assert_eq(board.wall_recovery_count, 0, "overlap case wall recovery activations")
	assert_true(
		float(metrics["max_penetration"]) <= OVERLAP_PENETRATION_LIMIT,
		"overlap wall penetration must be at most %.3fpx, got %.3fpx" % [
			OVERLAP_PENETRATION_LIMIT,
			float(metrics["max_penetration"]),
		]
	)

	await _cleanup_fixture(fixture)
	_restore_config(snapshot)


func test_seed_4242_completes_twenty_turns_without_departures() -> void:
	var snapshot: Dictionary = _snapshot_config()
	var fixture: Dictionary = await _create_ready_fixture(4242)
	var board: Board = fixture["board"] as Board
	var manager: TurnManager = fixture["manager"] as TurnManager
	var directions: Array[Vector2i] = [
		Vector2i.DOWN,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.LEFT,
	]
	var total_departures: int = 0
	var total_divergences: int = 0
	var maximum_penetration: float = 0.0
	var maximum_penetration_ratio: float = 0.0
	var maximum_penetration_level: int = 0
	var capped_turn_count: int = 0
	var completed_turns: int = 0

	for turn_offset: int in range(20):
		var direction: Vector2i = directions[turn_offset % directions.size()]
		var capped_before: int = manager.capped_turn_count
		manager.on_swipe(direction)
		var metrics: Dictionary = await _wait_for_turn_with_metrics(manager, board)
		completed_turns = manager.turn_index
		var settle_elapsed: float = manager._settle_elapsed
		var capped: bool = manager.capped_turn_count > capped_before
		if capped:
			capped_turn_count += 1
		total_departures += int(metrics["departures"])
		total_divergences += int(metrics["divergences"])
		maximum_penetration = maxf(maximum_penetration, float(metrics["max_penetration"]))
		if float(metrics["max_penetration_ratio"]) > maximum_penetration_ratio:
			maximum_penetration_ratio = float(metrics["max_penetration_ratio"])
			maximum_penetration_level = int(metrics["max_penetration_level"])
		print(
			"Spawn flow seed=4242 turn=%d gravity=%s settle=%.6f capped=%s orbs=%d departures=%d max_penetration=%.3f" % [
				turn_offset + 1,
				OrbTypes.dir_name(direction),
				settle_elapsed,
				str(capped),
				board.get_orbs().size(),
				int(metrics["departures"]),
				float(metrics["max_penetration"]),
			]
		)
		assert_true(
			manager.state == TurnManager.State.WAITING_INPUT
			or manager.state == TurnManager.State.GAME_OVER,
			"turn returns to input or ends game"
		)
		if manager.state == TurnManager.State.GAME_OVER:
			break

	print(
		"Spawn flow seed=4242 summary turns=%d orbs=%d departures=%d divergences=%d max_penetration=%.3f max_penetration_ratio=%.6f ratio_level=%d capped_turns=%d escape_guards=%d wall_recoveries=%d recovery_timeout_lags=%s timeout_corrections=%d ghost_timeouts=%d ghost_avg=%.6f" % [
			completed_turns,
			board.get_orbs().size(),
			total_departures,
			total_divergences,
			maximum_penetration,
			maximum_penetration_ratio,
			maximum_penetration_level,
			capped_turn_count,
			board.escape_guard_count,
			board.wall_recovery_count,
			str(board.wall_recovery_since_last_ghost_timeout_frames),
			board.timeout_correction_count,
			board.ghost_timeout_count,
			board.average_ghost_duration(),
		]
	)
	assert_true(completed_turns > 0 and completed_turns <= 20, "turns before game over")
	assert_eq(
		board.get_orbs().size(),
		Config.data.initial_orb_count + completed_turns * Config.data.spawn_count_per_turn,
		"initial orbs plus completed turn spawns"
	)
	assert_eq(total_departures, 0, "continuous-turn orb center departures")
	assert_eq(total_divergences, 0, "continuous-turn divergent orb frames")
	assert_eq(board.escape_guard_count, 0, "continuous-turn escape guard activations")
	assert_eq(board.wall_recovery_count, 0, "continuous-turn wall recovery activations")
	assert_true(
		maximum_penetration <= CONTINUOUS_PENETRATION_LIMIT,
		"continuous-turn wall penetration must be at most %.3fpx, got %.3fpx" % [
			CONTINUOUS_PENETRATION_LIMIT,
			maximum_penetration,
		]
	)

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
		await _wait_for_state(manager, TurnManager.State.SIMULATING)
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
	if create_initial:
		spawner.spawn_initial(board, Vector2i.DOWN)
	return {
		"root": fixture_root,
		"board": board,
		"spawner": spawner,
		"resolver": resolver,
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
		var board: Board = manager.get_parent().get_node("Board") as Board
		assert_board_motion_bounds(board, "spawn-flow state wait")
	assert_eq(manager.state, target, "state wait timeout")


func _wait_for_turn_with_metrics(manager: TurnManager, board: Board) -> Dictionary:
	var metrics: Dictionary = _empty_physics_metrics()
	var max_frames: int = ceili(
		float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS
	)
	for _frame: int in range(max_frames):
		await tree.physics_frame
		assert_board_motion_bounds(board, "spawn-flow turn wait")
		_accumulate_board_metrics(board, metrics)
		if (
			manager.state == TurnManager.State.WAITING_INPUT
			or manager.state == TurnManager.State.GAME_OVER
		):
			return metrics
	assert_true(
		manager.state == TurnManager.State.WAITING_INPUT
		or manager.state == TurnManager.State.GAME_OVER,
		"turn wait timeout"
	)
	return metrics


func _observe_board(board: Board, duration_seconds: float) -> Dictionary:
	var metrics: Dictionary = _empty_physics_metrics()
	var frame_count: int = ceili(
		float(Engine.physics_ticks_per_second) * duration_seconds
	)
	for _frame: int in range(frame_count):
		await tree.physics_frame
		assert_board_motion_bounds(board, "spawn-flow observation")
		_accumulate_board_metrics(board, metrics)
	return metrics


func _empty_physics_metrics() -> Dictionary:
	return {
		"departures": 0,
		"max_penetration": 0.0,
		"max_penetration_ratio": 0.0,
		"max_penetration_level": 0,
		"max_speed": 0.0,
		"escape_guards": 0,
		"divergences": 0,
	}


func _accumulate_board_metrics(board: Board, metrics: Dictionary) -> void:
	metrics["escape_guards"] = maxi(
		int(metrics["escape_guards"]),
		board.escape_guard_count
	)
	for orb: Orb in board.get_orbs():
		var center_extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
		var penetration: float = maxf(
			center_extent + orb.get_current_radius() - board.half_size(),
			0.0
		)
		metrics["max_penetration"] = maxf(
			float(metrics["max_penetration"]),
			penetration
		)
		var penetration_ratio: float = penetration / orb.get_radius()
		if penetration_ratio > float(metrics["max_penetration_ratio"]):
			metrics["max_penetration_ratio"] = penetration_ratio
			metrics["max_penetration_level"] = orb.level
		var speed: float = orb.linear_velocity.length()
		metrics["max_speed"] = maxf(
			float(metrics["max_speed"]),
			speed
		)
		if (
			speed > DIVERGENCE_SPEED
			or center_extent > board.half_size() + DIVERGENCE_MARGIN
		):
			metrics["divergences"] = int(metrics["divergences"]) + 1
		if center_extent > board.half_size():
			metrics["departures"] = int(metrics["departures"]) + 1


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
		"spawn_count_per_turn": Config.data.spawn_count_per_turn,
		"preview_turns": Config.data.preview_turns,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.stable_linear_speed = float(snapshot["stable_linear_speed"])
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])
	Config.data.spawn_position_mode = int(snapshot["spawn_position_mode"]) as GameConfig.SpawnPositionMode
	Config.data.initial_orb_count = int(snapshot["initial_orb_count"])
	Config.data.spawn_count_per_turn = int(snapshot["spawn_count_per_turn"])
	Config.data.preview_turns = int(snapshot["preview_turns"])


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
	if next_state != TurnManager.State.SIMULATING or not is_instance_valid(_capture_board):
		return
	var orbs: Array[Orb] = _capture_board.get_orbs()
	var spawned: Orb = orbs[orbs.size() - 1]
	var visual: OrbVisual = spawned.get_node("Visual") as OrbVisual
	_captured_spawn = {
		"color": spawned.color,
		"level": spawned.level,
		"position": spawned.position,
		"radius": spawned.get_radius(),
		"current_radius": spawned.get_current_radius(),
		"is_ghost": spawned.is_ghost,
		"collision_layer": spawned.collision_layer,
		"collision_mask": spawned.collision_mask,
		"alpha": visual.get_alpha(),
	}
