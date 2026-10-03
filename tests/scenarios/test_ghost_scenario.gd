extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const GHOST_LAYER: int = 4
const WALL_MASK: int = 1
const NORMAL_LAYER: int = 2
const NORMAL_MASK: int = 3
const POSITION_TOLERANCE: float = 0.001

var _reactions: Array[Dictionary] = []


func test_floor_dummy_is_not_pushed_and_ghost_exits_after_overlap_clears() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var board: Board = fixture["board"] as Board
	board.set_gravity(Vector2i.DOWN)
	var bottom_y: float = (
		board.half_size()
		- Config.data.radius_for_level(1)
		- Config.data.spawn_margin
	)
	var x_positions: Array[float] = [-350.0, -210.0, -70.0, 70.0, 210.0, 350.0]
	var dummies: Array[Orb] = []
	for x: float in x_positions:
		dummies.append(
			_spawn_normal(board, OrbTypes.OrbColor.GREEN, 1, Vector2(x, bottom_y))
		)
	await _advance(board, 0.12)
	var original_positions: Array[Vector2] = []
	for dummy: Orb in dummies:
		original_positions.append(dummy.position)

	var ghost: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		dummies[2].position,
		Vector2(0.0, -1400.0)
	)
	_assert_ghost_state(ghost, "dummy overlap spawn")
	await _advance(board, 0.12)

	var maximum_dummy_displacement: float = 0.0
	for index: int in range(dummies.size()):
		maximum_dummy_displacement = maxf(
			maximum_dummy_displacement,
			dummies[index].position.distance_to(original_positions[index])
		)
	assert_true(
		maximum_dummy_displacement < 2.0,
		"ghost must not push dummy orbs; max displacement %.3f" % maximum_dummy_displacement
	)
	_assert_normal_state(ghost, "dummy overlap exit")
	assert_true(
		ghost.ghost_elapsed <= 0.1,
		"moving ghost exits within 0.1 seconds after clearing overlap"
	)
	print(
		"Ghost dummy displacement=%.3f duration=%.6f timeouts=%d" % [
			maximum_dummy_displacement,
			ghost.ghost_elapsed,
			board.ghost_timeout_count,
		]
	)
	await _cleanup_fixture(fixture)


func test_initial_orbs_are_normal_and_empty_turn_spawn_exits_quickly() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var root: Node = fixture["root"] as Node
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	root.add_child(spawner)
	spawner.init_rng(11001)
	spawner.spawn_initial(board, Vector2i.DOWN)
	for orb: Orb in board.get_orbs():
		_assert_normal_state(orb, "initial orb")

	board.set_gravity(Vector2i.RIGHT)
	var turn_spawns: Array = spawner.try_spawn(board, Vector2i.RIGHT)
	var turn_spawn: Orb = turn_spawns[0]
	_assert_ghost_state(turn_spawn, "turn spawn")
	var max_frames: int = ceili(0.1 * float(Engine.physics_ticks_per_second))
	for _frame: int in range(max_frames):
		if not turn_spawn.is_ghost:
			break
		await tree.physics_frame
		assert_board_motion_bounds(board, "empty ghost exit")
	_assert_normal_state(turn_spawn, "empty turn spawn exit")
	assert_true(turn_spawn.ghost_elapsed <= 0.1, "empty turn spawn exits within 0.1 seconds")
	assert_eq(board.ghost_timeout_count, 0, "empty turn spawn timeout count")
	print("Ghost empty duration=%.6f" % turn_spawn.ghost_elapsed)
	await _cleanup_fixture(fixture)


func test_two_ghosts_pass_through_each_other_and_both_exit() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var board: Board = fixture["board"] as Board
	board.set_gravity(Vector2i.ZERO)
	var blocker: Orb = _spawn_normal(
		board,
		OrbTypes.OrbColor.GREEN,
		3,
		Vector2.ZERO
	)
	var blocker_position: Vector2 = blocker.position
	var pair_offset: float = Config.data.radius_for_level(1) * 0.6
	var ghost_a: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-pair_offset, 0.0),
		Vector2(600.0, 0.0)
	)
	var ghost_b: Orb = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		1,
		Vector2(pair_offset, 0.0),
		Vector2(-600.0, 0.0)
	)
	_assert_ghost_state(ghost_a, "ghost pair a")
	_assert_ghost_state(ghost_b, "ghost pair b")

	var crossed: bool = false
	var max_frames: int = ceili(0.4 * float(Engine.physics_ticks_per_second))
	for _frame: int in range(max_frames):
		await tree.physics_frame
		assert_board_motion_bounds(board, "ghost pair pass-through")
		if ghost_a.is_ghost and ghost_b.is_ghost and ghost_a.position.x > ghost_b.position.x:
			crossed = true
		if not ghost_a.is_ghost and not ghost_b.is_ghost:
			break
	assert_true(crossed, "ghost pair crosses while both are ghost")
	_assert_normal_state(ghost_a, "ghost pair a exit")
	_assert_normal_state(ghost_b, "ghost pair b exit")
	assert_true(
		blocker.position.distance_to(blocker_position) < 2.0,
		"ghost pair does not push normal blocker"
	)
	assert_eq(board.ghost_timeout_count, 0, "ghost pair timeout count")
	print(
		"Ghost pair durations=[%.6f, %.6f] blocker_displacement=%.3f" % [
			ghost_a.ghost_elapsed,
			ghost_b.ghost_elapsed,
			blocker.position.distance_to(blocker_position),
		]
	)
	await _cleanup_fixture(fixture)


func test_ghost_exits_then_merges_on_normal_contact() -> void:
	var fixture: Dictionary = await _create_fixture(true)
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	board.set_gravity(Vector2i.DOWN)
	var bottom_y: float = (
		board.half_size()
		- Config.data.radius_for_level(1)
		- Config.data.spawn_margin
	)
	_spawn_normal(board, OrbTypes.OrbColor.RED, 1, Vector2(0.0, bottom_y))
	await _advance_and_flush(board, resolver, 0.1)
	var falling: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(0.0, 180.0)
	)
	_assert_ghost_state(falling, "falling merge orb")

	await _advance_and_flush(board, resolver, 1.0, true)
	assert_eq(_reactions.size(), 1, "post-ghost merge reaction count")
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(orbs.size(), 1, "post-ghost merge result count")
	if orbs.size() == 1:
		assert_eq(orbs[0].level, 2, "post-ghost merge result level")
	assert_eq(board.ghost_timeout_count, 0, "post-ghost merge timeout count")
	print("Ghost merge reactions=%d" % _reactions.size())
	await _cleanup_fixture(fixture)


func test_packed_floor_times_out_once_without_divergence() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var board: Board = fixture["board"] as Board
	board.set_gravity(Vector2i.DOWN)
	var bottom_y: float = (
		board.half_size()
		- Config.data.radius_for_level(1)
		- Config.data.spawn_margin
	)
	var dummies: Array[Orb] = []
	var dummy_starts: Array[Vector2] = []
	var radius: float = Config.data.radius_for_level(1)
	for multiplier: float in [-5.0, -3.0, -1.0, 1.0, 3.0, 5.0]:
		var dummy: Orb = _spawn_normal(
			board,
			OrbTypes.OrbColor.GREEN,
			1,
			Vector2(multiplier * radius, bottom_y)
		)
		dummy.freeze = true
		dummies.append(dummy)
		dummy_starts.append(dummy.position)
	await _advance(board, 0.1)

	var ghost: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(0.0, bottom_y)
	)
	_assert_ghost_state(ghost, "packed floor spawn")
	await _advance(board, Config.data.ghost_max_time + 0.15)
	assert_eq(board.ghost_timeout_count, 1, "packed floor timeout count")
	assert_true(
		board.timeout_correction_count > 0,
		"packed floor timeout correction count"
	)
	_assert_normal_state(ghost, "packed floor timeout exit")
	assert_board_motion_bounds(board, "packed floor after timeout")
	assert_eq(board.escape_guard_count, 0, "packed floor escape guards")
	for index: int in range(dummies.size()):
		assert_true(
			dummies[index].position.distance_to(dummy_starts[index]) < 2.0,
			"packed floor dummy %d displacement" % index
		)
	print(
		"Ghost packed timeout_count=%d duration=%.6f" % [
			board.ghost_timeout_count,
			ghost.ghost_elapsed,
		]
	)
	await _cleanup_fixture(fixture)


func test_timeout_restores_existing_wall_penetration_without_guard() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var board: Board = fixture["board"] as Board
	board.set_gravity(Vector2i.DOWN)
	var radius: float = Config.data.radius_for_level(1)
	var existing: Orb = _spawn_normal(
		board,
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(board.half_size() - radius + 30.0, 0.0)
	)
	existing.freeze = true
	var ghost: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		existing.position
	)
	ghost.ghost_elapsed = Config.data.ghost_max_time
	var timeout_wait_frames: int = 0
	while ghost.is_ghost and timeout_wait_frames < 3:
		await tree.physics_frame
		timeout_wait_frames += 1

	assert_eq(board.ghost_timeout_count, 1, "wall penetration timeout count")
	assert_true(
		board.timeout_correction_count > 0,
		"wall penetration timeout correction count"
	)
	assert_eq(board.escape_guard_count, 0, "wall penetration escape guards")
	assert_true(
		existing.position.x + existing.get_current_radius() <= board.half_size(),
		"existing orb restored inside right wall"
	)
	_assert_normal_state(ghost, "wall penetration timeout exit")
	await _cleanup_fixture(fixture)


func test_proactive_wall_recovery_precedes_escape_guard() -> void:
	var fixture: Dictionary = await _create_fixture(false)
	var board: Board = fixture["board"] as Board
	var orb: Orb = _spawn_normal(
		board,
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2.ZERO
	)
	var recovery_position: Vector2 = Vector2(
		board.half_size() - orb.get_current_radius() + 20.0,
		0.0
	)
	orb.queue_timeout_correction(recovery_position, Vector2.ZERO)
	await tree.physics_frame
	await tree.physics_frame

	assert_eq(board.wall_recovery_count, 1, "proactive recovery axis count")
	assert_eq(board.escape_guard_count, 0, "proactive recovery escape guards")
	assert_eq(
		board.wall_recovery_since_last_ghost_timeout_frames,
		[-1] as Array[int],
		"proactive recovery has no preceding ghost timeout"
	)
	await _cleanup_fixture(fixture)


func test_growth_point_two_reproduction_has_no_divergence_or_guard() -> void:
	var original_duration: float = Config.data.grow_duration
	var original_ratio: float = Config.data.grow_start_ratio
	Config.data.grow_duration = 0.0
	Config.data.grow_start_ratio = 0.3
	var fixture: Dictionary = await _create_fixture(false)
	var board: Board = fixture["board"] as Board
	board.set_gravity(Vector2i.DOWN)
	var corner: Orb = _spawn_normal(
		board,
		OrbTypes.OrbColor.GREEN,
		3,
		Vector2(-401.9134, -401.8694),
		Vector2(0.0, -0.02683)
	)
	var neighbor: Orb = _spawn_normal(
		board,
		OrbTypes.OrbColor.GREEN,
		4,
		Vector2(-241.5669, -329.8949),
		Vector2(-76.14867, 177.3462)
	)
	Config.data.grow_duration = 0.20
	Config.data.grow_start_ratio = 0.3
	var ghost: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-381.0987, -426.0)
	)
	_assert_ghost_state(ghost, "divergence reproduction spawn")

	var metrics: Dictionary = await _observe_motion(board, 1.0)
	assert_eq(board.escape_guard_count, 0, "divergence reproduction escape guards")
	assert_true(
		float(metrics["maximum_extent"]) <= board.half_size() * 2.0,
		"divergence reproduction center bound"
	)
	assert_true(
		float(metrics["maximum_speed"]) <= 10000.0,
		"divergence reproduction speed bound"
	)
	assert_true(is_instance_valid(corner), "corner orb remains valid")
	assert_true(is_instance_valid(neighbor), "neighbor orb remains valid")
	print(
		"Ghost divergence reproduction max_extent=%.3f max_speed=%.3f max_penetration=%.3f guards=%d timeouts=%d ghost_duration=%.6f" % [
			float(metrics["maximum_extent"]),
			float(metrics["maximum_speed"]),
			float(metrics["maximum_penetration"]),
			board.escape_guard_count,
			board.ghost_timeout_count,
			ghost.ghost_elapsed,
		]
	)
	await _cleanup_fixture(fixture)
	Config.data.grow_duration = original_duration
	Config.data.grow_start_ratio = original_ratio


func _create_fixture(connect_reactions: bool) -> Dictionary:
	_reactions.clear()
	var fixture_root: Node = Node.new()
	fixture_root.name = "GhostFixture"

	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root

	var resolver: CollisionResolver = COLLISION_RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root

	tree.root.add_child(fixture_root)
	await tree.process_frame
	if not connect_reactions and board.orb_contact.is_connected(resolver.report_contact):
		board.orb_contact.disconnect(resolver.report_contact)
	resolver.reaction_applied.connect(_record_reaction)
	board.set_gravity(Vector2i.ZERO)
	return {
		"root": fixture_root,
		"board": board,
		"resolver": resolver,
	}


func _spawn_normal(
	board: Board,
	color: int,
	level: int,
	position: Vector2,
	velocity: Vector2 = Vector2.ZERO
) -> Orb:
	var orb: Orb = board.spawn_orb(color, level, position, velocity)
	orb.exit_ghost_state()
	return orb


func _advance(board: Board, seconds: float) -> void:
	var frame_count: int = ceili(seconds * float(Engine.physics_ticks_per_second))
	for _frame: int in range(frame_count):
		await tree.physics_frame
		assert_board_motion_bounds(board, "ghost scenario")


func _advance_and_flush(
	board: Board,
	resolver: CollisionResolver,
	seconds: float,
	stop_after_reaction: bool = false
) -> void:
	var frame_count: int = ceili(seconds * float(Engine.physics_ticks_per_second))
	for _frame: int in range(frame_count):
		await tree.physics_frame
		resolver.flush()
		assert_board_motion_bounds(board, "ghost reaction scenario")
		if stop_after_reaction and not _reactions.is_empty():
			return


func _observe_motion(board: Board, seconds: float) -> Dictionary:
	var metrics: Dictionary = {
		"maximum_extent": 0.0,
		"maximum_speed": 0.0,
		"maximum_penetration": 0.0,
	}
	var frame_count: int = ceili(seconds * float(Engine.physics_ticks_per_second))
	for _frame: int in range(frame_count):
		await tree.physics_frame
		assert_board_motion_bounds(board, "ghost divergence reproduction")
		for orb: Orb in board.get_orbs():
			var extent: float = maxf(absf(orb.position.x), absf(orb.position.y))
			metrics["maximum_extent"] = maxf(float(metrics["maximum_extent"]), extent)
			metrics["maximum_speed"] = maxf(
				float(metrics["maximum_speed"]),
				orb.linear_velocity.length()
			)
			metrics["maximum_penetration"] = maxf(
				float(metrics["maximum_penetration"]),
				maxf(extent + orb.get_current_radius() - board.half_size(), 0.0)
			)
	return metrics


func _assert_ghost_state(orb: Orb, context: String) -> void:
	var visual: OrbVisual = orb.get_node("Visual") as OrbVisual
	assert_true(orb.is_ghost, "%s ghost flag" % context)
	assert_eq(orb.collision_layer, GHOST_LAYER, "%s collision layer" % context)
	assert_eq(orb.collision_mask, WALL_MASK, "%s collision mask" % context)
	assert_near(visual.get_alpha(), Config.data.ghost_alpha, POSITION_TOLERANCE, "%s alpha" % context)


func _assert_normal_state(orb: Orb, context: String) -> void:
	var visual: OrbVisual = orb.get_node("Visual") as OrbVisual
	assert_true(not orb.is_ghost, "%s normal flag" % context)
	assert_eq(orb.collision_layer, NORMAL_LAYER, "%s collision layer" % context)
	assert_eq(orb.collision_mask, NORMAL_MASK, "%s collision mask" % context)
	assert_near(visual.get_alpha(), 1.0, POSITION_TOLERANCE, "%s alpha" % context)


func _cleanup_fixture(fixture: Dictionary) -> void:
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame


func _record_reaction(reaction: Dictionary) -> void:
	_reactions.append(reaction)
