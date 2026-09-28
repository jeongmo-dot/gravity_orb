extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const TURN_MANAGER_SCRIPT: Script = preload("res://scripts/core/TurnManager.gd")
const OBSERVE_SECONDS: float = 0.5
const POSITION_TOLERANCE: float = 1.0
const WAIT_TIMEOUT_SECONDS: float = 8.0
const HIGH_THRESHOLD: float = 1.0e9

var _reactions: Array[Dictionary] = []
var _chains: Array[int] = []
var _finished_max_chains: Array[int] = []


func test_matching_pair_merges_once_at_clamped_midpoint() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var radius: float = Config.data.radius_for_level(1)
	var bottom_y: float = board.half_size() - radius - Config.data.spawn_margin
	var a: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-49.5, bottom_y))
	var b: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(49.5, bottom_y))
	var raw_midpoint: Vector2 = (a.position + b.position) * 0.5
	var result_radius: float = Config.data.radius_for_level(2)
	var expected_position: Vector2 = Vector2(
		clampf(raw_midpoint.x, -board.half_size() + result_radius, board.half_size() - result_radius),
		clampf(raw_midpoint.y, -board.half_size() + result_radius, board.half_size() - result_radius)
	)

	var applied: int = await _advance_and_flush(resolver, OBSERVE_SECONDS)
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(applied, 1, "matching pair reaction count")
	assert_eq(_reactions.size(), 1, "matching pair signal count")
	assert_eq(orbs.size(), 1, "matching pair result count")
	if orbs.size() == 1:
		assert_eq(orbs[0].color, OrbTypes.OrbColor.RED, "merge result color")
		assert_eq(orbs[0].level, 2, "merge result level")
		assert_eq(orbs[0].generation, 1, "merge result generation")
	if _reactions.size() == 1:
		assert_true(
			(_reactions[0]["position"] as Vector2).distance_to(expected_position) <= POSITION_TOLERANCE,
			"merge result position"
		)
		_assert_reaction_dictionary(_reactions[0])
	await _cleanup_fixture(fixture)


func test_three_simultaneous_contacts_apply_exactly_one_merge() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-49.0, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(49.0, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(0.0, 84.0))

	var applied: int = await _advance_and_flush(resolver, OBSERVE_SECONDS)
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(applied, 1, "three-orb reaction count")
	assert_eq(_reactions.size(), 1, "three-orb signal count")
	assert_eq(orbs.size(), 2, "three-orb remaining count")
	assert_eq(_count_level(orbs, 1), 1, "three-orb remaining level one")
	assert_eq(_count_level(orbs, 2), 1, "three-orb merged level two")
	await _cleanup_fixture(fixture)


func test_nonmatching_pairs_do_not_merge() -> void:
	var color_fixture: Dictionary = await _create_fixture()
	var color_board: Board = color_fixture["board"] as Board
	var color_resolver: CollisionResolver = color_fixture["resolver"] as CollisionResolver
	color_board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-49.5, 0.0))
	color_board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(49.5, 0.0))
	var color_applied: int = await _advance_and_flush(color_resolver, OBSERVE_SECONDS)
	assert_eq(color_applied, 0, "different-color reaction count")
	assert_eq(color_board.get_orbs().size(), 2, "different-color orb count")
	await _cleanup_fixture(color_fixture)

	var level_fixture: Dictionary = await _create_fixture()
	var level_board: Board = level_fixture["board"] as Board
	var level_resolver: CollisionResolver = level_fixture["resolver"] as CollisionResolver
	level_board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-55.0, 0.0))
	level_board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(55.0, 0.0))
	var level_applied: int = await _advance_and_flush(level_resolver, OBSERVE_SECONDS)
	assert_eq(level_applied, 0, "different-level reaction count")
	assert_eq(level_board.get_orbs().size(), 2, "different-level orb count")
	await _cleanup_fixture(level_fixture)


func test_merge_result_reacts_again_as_chain_two() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-49.5, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(49.5, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(0.0, 110.0))

	var applied: int = await _advance_and_flush(resolver, OBSERVE_SECONDS)
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(applied, 2, "chain reaction count")
	assert_eq(_reaction_chains(), [1, 2], "chain reaction order")
	assert_eq(_chains, [1, 2], "chain_changed sequence")
	assert_eq(manager.turn_max_chain, 2, "turn maximum chain")
	assert_eq(orbs.size(), 1, "chain result count")
	if orbs.size() == 1:
		assert_eq(orbs[0].level, 3, "chain result level")
		assert_eq(orbs[0].generation, 2, "chain result generation")
	print("Merge chain sequence: %s" % str(_reaction_chains()))
	await _cleanup_fixture(fixture)


func test_independent_simultaneous_merges_are_both_chain_one() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-250.0, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-151.0, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(151.0, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(250.0, 0.0))

	var applied: int = await _advance_and_flush(resolver, OBSERVE_SECONDS)
	assert_eq(applied, 2, "independent reaction count")
	assert_eq(_reaction_chains(), [1, 1], "independent chain values")
	assert_eq(manager.turn_max_chain, 1, "independent maximum chain")
	assert_eq(board.get_orbs().size(), 2, "independent result count")
	await _cleanup_fixture(fixture)


func test_max_level_pair_clears_without_result() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	board.spawn_orb(OrbTypes.OrbColor.RED, Config.data.orb_max_level, Vector2(-180.0, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.RED, Config.data.orb_max_level, Vector2(180.0, 0.0))

	var applied: int = await _advance_and_flush(resolver, OBSERVE_SECONDS)
	assert_eq(applied, 1, "maximum clear reaction count")
	assert_eq(board.get_orbs().size(), 0, "maximum clear orb count")
	if _reactions.size() == 1:
		assert_eq(_reactions[0]["type"], ReactionRules.Type.MAX_CLEAR, "maximum clear type")
		assert_eq(_reactions[0]["result_level"], 0, "maximum clear result level")
		assert_eq(_reactions[0]["result_orb"], null, "maximum clear result orb")
	await _cleanup_fixture(fixture)


func test_wall_merge_result_is_clamped_inside_board() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(426.0, -49.5))
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(426.0, 49.5))

	var applied: int = await _advance_and_flush(resolver, OBSERVE_SECONDS)
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(applied, 1, "wall reaction count")
	assert_eq(orbs.size(), 1, "wall result count")
	if _reactions.size() == 1:
		var position: Vector2 = _reactions[0]["position"] as Vector2
		var radius: float = Config.data.radius_for_level(2)
		assert_true(absf(position.x) <= board.half_size() - radius, "wall result x inside")
		assert_true(absf(position.y) <= board.half_size() - radius, "wall result y inside")
	await _cleanup_fixture(fixture)


func test_turn_manager_finishes_turn_after_merge() -> void:
	var snapshot: Dictionary = _snapshot_turn_config()
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	spawner.init_rng(5009)
	var initial_count: int = Config.data.initial_orb_count
	Config.data.initial_orb_count = 0
	spawner.spawn_initial(board, Vector2i.DOWN)
	Config.data.initial_orb_count = initial_count
	manager.turn_finished.connect(_record_turn_finished)
	manager.start_game()
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)

	board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-80.0, 0.0),
		Vector2(400.0, 0.0)
	)
	board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(80.0, 0.0),
		Vector2(-400.0, 0.0)
	)
	manager.on_swipe(Vector2i.DOWN)
	await _wait_for_state(manager, TurnManager.State.WAITING_INPUT)

	assert_eq(manager.turn_index, 1, "merge turn index")
	assert_true(manager.turn_max_chain >= 1, "merge turn maximum chain")
	assert_eq(_finished_max_chains.size(), 1, "turn_finished signal count")
	if _finished_max_chains.size() == 1:
		assert_true(_finished_max_chains[0] >= 1, "turn_finished maximum chain")
	assert_true(_reactions.size() >= 1, "merge reaction during turn")
	await _cleanup_fixture(fixture)
	_restore_turn_config(snapshot)


func _create_fixture() -> Dictionary:
	InputRouter.set_locked(false)
	_reset_records()
	var fixture_root: Node = Node.new()
	fixture_root.name = "MergeFixture"

	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	fixture_root.add_child(board)
	board.owner = fixture_root

	var resolver: CollisionResolver = COLLISION_RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	fixture_root.add_child(resolver)
	resolver.owner = fixture_root

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
	resolver.reaction_applied.connect(_record_reaction)
	manager.chain_changed.connect(_record_chain)
	return {
		"root": fixture_root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"manager": manager,
	}


func _advance_and_flush(resolver: CollisionResolver, seconds: float) -> int:
	var applied: int = 0
	var frame_count: int = ceili(float(Engine.physics_ticks_per_second) * seconds)
	for _frame: int in range(frame_count):
		await tree.physics_frame
		applied += resolver.flush()
	return applied


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
	assert_eq(manager.state, target, "state wait timeout")


func _cleanup_fixture(fixture: Dictionary) -> void:
	InputRouter.set_locked(false)
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame


func _count_level(orbs: Array[Orb], level: int) -> int:
	var count: int = 0
	for orb: Orb in orbs:
		if orb.level == level:
			count += 1
	return count


func _reaction_chains() -> Array[int]:
	var chains: Array[int] = []
	for reaction: Dictionary in _reactions:
		chains.append(int(reaction["chain"]))
	return chains


func _assert_reaction_dictionary(reaction: Dictionary) -> void:
	var keys: Array[String] = [
		"type",
		"chain",
		"levels",
		"colors",
		"position",
		"result_level",
		"result_color",
		"result_orb",
	]
	for key: String in keys:
		assert_true(reaction.has(key), "reaction key %s" % key)


func _snapshot_turn_config() -> Dictionary:
	return {
		"stable_linear_speed": Config.data.stable_linear_speed,
		"stable_angular_speed": Config.data.stable_angular_speed,
		"initial_orb_count": Config.data.initial_orb_count,
	}


func _restore_turn_config(snapshot: Dictionary) -> void:
	Config.data.stable_linear_speed = float(snapshot["stable_linear_speed"])
	Config.data.stable_angular_speed = float(snapshot["stable_angular_speed"])
	Config.data.initial_orb_count = int(snapshot["initial_orb_count"])


func _reset_records() -> void:
	_reactions.clear()
	_chains.clear()
	_finished_max_chains.clear()


func _record_reaction(reaction: Dictionary) -> void:
	_reactions.append(reaction)


func _record_chain(chain: int) -> void:
	_chains.append(chain)


func _record_turn_finished(_turn_index: int, max_chain: int) -> void:
	_finished_max_chains.append(max_chain)
