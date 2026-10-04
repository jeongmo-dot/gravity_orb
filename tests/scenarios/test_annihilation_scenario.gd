extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const COLLISION_RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const CONTACT_WAIT_SECONDS: float = 1.0
const POSITION_TOLERANCE: float = 0.1

var _reactions: Array[Dictionary] = []


func test_rule_a_removes_both_orbs() -> void:
	var original_rule: GameConfig.AnnihilationRule = Config.data.annihilation_rule
	Config.data.annihilation_rule = GameConfig.AnnihilationRule.A_BOTH
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var red: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(-56.0, 0.0))
	var blue: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(56.0, 0.0))

	resolver.report_contact(red, blue)
	var applied: int = resolver.flush()
	assert_eq(applied, 1, "rule A reaction count")
	assert_eq(_reactions.size(), 1, "rule A signal count")
	assert_eq(board.get_orbs().size(), 0, "rule A removes both")
	if _reactions.size() == 1:
		_assert_reaction_dictionary(_reactions[0])
		assert_eq(_reactions[0]["type"], ReactionRules.Type.ANNIHILATE, "rule A type")
		assert_eq(_reactions[0]["result_orb"], null, "rule A has no result")
	await _cleanup_fixture(fixture)
	Config.data.annihilation_rule = original_rule


func test_rule_b_leaves_different_levels_untouched() -> void:
	var original_rule: GameConfig.AnnihilationRule = Config.data.annihilation_rule
	Config.data.annihilation_rule = GameConfig.AnnihilationRule.B_SAME_LEVEL
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var red: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(-56.0, 0.0))
	var blue: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(56.0, 0.0))

	resolver.report_contact(red, blue)
	assert_eq(resolver.flush(), 0, "rule B reaction count")
	assert_eq(_reactions.size(), 0, "rule B signal count")
	assert_eq(board.get_orbs().size(), 2, "rule B keeps both")
	await _cleanup_fixture(fixture)
	Config.data.annihilation_rule = original_rule


func test_rule_c_spawns_remainder_at_larger_orb_state() -> void:
	var original_rule: GameConfig.AnnihilationRule = Config.data.annihilation_rule
	Config.data.annihilation_rule = GameConfig.AnnihilationRule.C_REMAINDER
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var red_position: Vector2 = Vector2(-72.0, 17.0)
	var red_velocity: Vector2 = Vector2(21.0, -13.0)
	var red: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 4, red_position, red_velocity)
	var blue: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(75.0, 17.0))

	resolver.report_contact(red, blue)
	assert_eq(resolver.flush(), 1, "rule C reaction count")
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(orbs.size(), 1, "rule C result count")
	if orbs.size() == 1:
		assert_eq(orbs[0].color, OrbTypes.OrbColor.RED, "rule C result color")
		assert_eq(orbs[0].level, 3, "rule C result level")
		assert_eq(orbs[0].generation, 1, "rule C result generation")
		assert_true(
			orbs[0].position.distance_to(red_position) <= POSITION_TOLERANCE,
			"rule C result position"
		)
		assert_true(
			orbs[0].linear_velocity.distance_to(red_velocity) <= POSITION_TOLERANCE,
			"rule C result velocity"
		)
	await _cleanup_fixture(fixture)
	Config.data.annihilation_rule = original_rule


func test_merge_then_annihilation_reports_chain_one_two() -> void:
	var original_rule: GameConfig.AnnihilationRule = Config.data.annihilation_rule
	Config.data.annihilation_rule = GameConfig.AnnihilationRule.A_BOTH
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var red_a: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-49.5, 0.0))
	var red_b: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(49.5, 0.0))

	resolver.report_contact(red_a, red_b)
	assert_eq(resolver.flush(), 1, "chain merge count")
	var merge_result: Orb = _reactions[0]["result_orb"] as Orb
	assert_true(merge_result != null, "chain merge result")
	if merge_result != null:
		var blue: Orb = board.spawn_orb(
			OrbTypes.OrbColor.BLUE,
			2,
			merge_result.position
		)
		blue.exit_ghost_state()
		resolver.report_contact(merge_result, blue)
		assert_eq(resolver.flush(), 0, "chain annihilation waits for result lock")
		var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
		var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
		for frame_index: int in range(delay_frames):
			var applied: int = resolver.flush(tick)
			if frame_index < delay_frames - 1:
				assert_eq(applied, 0, "chain annihilation remains locked")
			else:
				assert_eq(applied, 1, "chain annihilation count")
	assert_eq(_reaction_chains(), [1, 2], "annihilation chain order")
	assert_eq(board.get_orbs().size(), 0, "annihilation chain final count")
	print("Annihilation chain sequence: %s" % str(_reaction_chains()))
	await _cleanup_fixture(fixture)
	Config.data.annihilation_rule = original_rule


func test_sweep_rechecks_resting_pair_after_rule_change() -> void:
	var original_rule: GameConfig.AnnihilationRule = Config.data.annihilation_rule
	Config.data.annihilation_rule = GameConfig.AnnihilationRule.B_SAME_LEVEL
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var contact_half_distance: float = (
		(Config.data.radius_for_level(2) + Config.data.radius_for_level(1)) * 0.5
		- 0.5
	)
	var red: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		2,
		Vector2(-contact_half_distance, 0.0)
	)
	var blue: Orb = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		1,
		Vector2(contact_half_distance, 0.0)
	)
	var found_contact: bool = await _wait_for_contact(board, resolver, red, blue)
	assert_true(found_contact, "resting pair becomes a reported contact")

	Config.data.annihilation_rule = GameConfig.AnnihilationRule.A_BOTH
	var swept: int = resolver.sweep_resting_contacts()
	assert_eq(swept, 1, "sweep reaction count")
	assert_eq(board.get_orbs().size(), 0, "sweep removes both")
	print("Annihilation sweep applied: %d" % swept)
	await _cleanup_fixture(fixture)
	Config.data.annihilation_rule = original_rule


func test_rule_change_affects_only_subsequent_flushes() -> void:
	var original_rule: GameConfig.AnnihilationRule = Config.data.annihilation_rule
	Config.data.annihilation_rule = GameConfig.AnnihilationRule.A_BOTH
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var first_red: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(-200.0, 0.0))
	var first_blue: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(-88.0, 0.0))
	resolver.report_contact(first_red, first_blue)
	assert_eq(resolver.flush(), 1, "rule A first collision")

	Config.data.annihilation_rule = GameConfig.AnnihilationRule.B_SAME_LEVEL
	var second_red: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2(88.0, 0.0))
	var second_blue: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(200.0, 0.0))
	resolver.report_contact(second_red, second_blue)
	assert_eq(resolver.flush(), 0, "rule B second collision")
	assert_eq(_reactions.size(), 1, "only first collision reacts")
	assert_eq(board.get_orbs().size(), 2, "second pair remains")
	await _cleanup_fixture(fixture)
	Config.data.annihilation_rule = original_rule


func _create_fixture() -> Dictionary:
	_reactions.clear()
	Config.data.opposite_pairs = [
		Vector2i(OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE),
	]
	var fixture_root: Node = Node.new()
	fixture_root.name = "AnnihilationFixture"

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
	board.set_gravity(Vector2i.ZERO)
	resolver.reaction_applied.connect(_record_reaction)
	return {
		"root": fixture_root,
		"board": board,
		"resolver": resolver,
	}


func _wait_for_contact(
	board: Board,
	resolver: CollisionResolver,
	a: Orb,
	b: Orb
) -> bool:
	var frame_count: int = ceili(
		float(Engine.physics_ticks_per_second) * CONTACT_WAIT_SECONDS
	)
	for _frame: int in range(frame_count):
		await tree.physics_frame
		assert_board_motion_bounds(board, "annihilation contact wait")
		resolver.flush()
		if a.get_colliding_bodies().has(b) or b.get_colliding_bodies().has(a):
			return true
	return false


func _cleanup_fixture(fixture: Dictionary) -> void:
	var fixture_root: Node = fixture["root"] as Node
	fixture_root.queue_free()
	await tree.process_frame
	Config.data.opposite_pairs = []


func _reaction_chains() -> Array[int]:
	var chains: Array[int] = []
	for reaction: Dictionary in _reactions:
		chains.append(int(reaction["chain"]))
	return chains


func _assert_reaction_dictionary(reaction: Dictionary) -> void:
	var keys: Array[String] = [
		"type",
		"chain",
		"occupancy",
		"levels",
		"colors",
		"position",
		"result_level",
		"result_color",
		"result_orb",
	]
	for key: String in keys:
		assert_true(reaction.has(key), "reaction key %s" % key)


func _record_reaction(reaction: Dictionary) -> void:
	_reactions.append(reaction)
