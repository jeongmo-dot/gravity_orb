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
var _combos: Array[int] = []
var _combo_multipliers: Array[float] = []
var _max_combos: Array[int] = []
var _finished_combos: Array[int] = []


func test_matching_pair_merges_once_at_clamped_midpoint() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var radius: float = Config.data.radius_for_level(1)
	var bottom_y: float = board.half_size() - radius - Config.data.spawn_margin
	var half_distance: float = radius - 0.5
	var a: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-half_distance, bottom_y)
	)
	var b: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(half_distance, bottom_y)
	)
	var raw_midpoint: Vector2 = (a.position + b.position) * 0.5
	var result_radius: float = Config.data.radius_for_level(2)
	var expected_position: Vector2 = Vector2(
		clampf(raw_midpoint.x, -board.half_size() + result_radius, board.half_size() - result_radius),
		clampf(raw_midpoint.y, -board.half_size() + result_radius, board.half_size() - result_radius)
	)

	var applied: int = await _advance_and_flush(board, resolver, OBSERVE_SECONDS)
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
	var radius: float = Config.data.radius_for_level(1)
	var half_distance: float = radius - 1.0
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-half_distance, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(half_distance, 0.0))
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(0.0, radius * 1.68))

	var applied: int = await _advance_and_flush(board, resolver, OBSERVE_SECONDS)
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(applied, 1, "three-orb reaction count")
	assert_eq(_reactions.size(), 1, "three-orb signal count")
	assert_eq(orbs.size(), 2, "three-orb remaining count")
	assert_eq(_count_level(orbs, 1), 1, "three-orb remaining level one")
	assert_eq(_count_level(orbs, 2), 1, "three-orb merged level two")
	await _cleanup_fixture(fixture)


func test_nonmatching_pairs_do_not_react() -> void:
	var color_fixture: Dictionary = await _create_fixture()
	var color_board: Board = color_fixture["board"] as Board
	var color_resolver: CollisionResolver = color_fixture["resolver"] as CollisionResolver
	var level_one_half_distance: float = Config.data.radius_for_level(1) - 0.5
	color_board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-level_one_half_distance, 0.0)
	)
	color_board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(level_one_half_distance, 0.0)
	)
	var color_applied: int = await _advance_and_flush(
		color_board,
		color_resolver,
		OBSERVE_SECONDS
	)
	assert_eq(color_applied, 0, "different-color reaction count")
	assert_eq(color_board.get_orbs().size(), 2, "different-color orb count")
	await _cleanup_fixture(color_fixture)

	var level_fixture: Dictionary = await _create_fixture()
	var level_board: Board = level_fixture["board"] as Board
	var level_resolver: CollisionResolver = level_fixture["resolver"] as CollisionResolver
	var mixed_half_distance: float = (
		(Config.data.radius_for_level(1) + Config.data.radius_for_level(2)) * 0.5
		- 0.5
	)
	level_board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-mixed_half_distance, 0.0)
	)
	level_board.spawn_orb(
		OrbTypes.OrbColor.RED,
		2,
		Vector2(mixed_half_distance, 0.0)
	)
	var level_applied: int = await _advance_and_flush(
		level_board,
		level_resolver,
		OBSERVE_SECONDS
	)
	assert_eq(level_applied, 0, "different-level reaction count")
	assert_eq(level_board.get_orbs().size(), 2, "different-level orb count")
	await _cleanup_fixture(level_fixture)


func test_merge_result_reacts_again_as_chain_two() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var level_two_radius: float = Config.data.radius_for_level(2)
	var half_distance: float = level_two_radius - 0.5
	var first: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		2,
		Vector2(-half_distance, 0.0)
	)
	var second: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		2,
		Vector2(half_distance, 0.0)
	)
	var adjacent: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		3,
		Vector2.ZERO
	)
	adjacent.position = Vector2(0.0, adjacent.get_current_radius() * 2.0 - 1.0)
	adjacent.exit_ghost_state()
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "chain first reaction")

	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
	var applied: int = 1
	for frame_index: int in range(delay_frames):
		var frame_applied: int = resolver.flush(tick)
		applied += frame_applied
		if frame_index < delay_frames - 1:
			assert_eq(frame_applied, 0, "chain result remains locked")
		else:
			assert_eq(frame_applied, 1, "chain result unlocks on configured tick")
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(applied, 2, "chain reaction count")
	assert_eq(_reaction_chains(), [1, 2], "chain reaction order")
	assert_eq(_combos, [1, 2], "combo_changed sequence")
	assert_eq(_combo_multipliers, [1.0, 2.0], "chain multiplier display sequence")
	assert_eq(_max_combos, [1, 2], "chain maximum display sequence")
	assert_eq(manager.turn_combo, 2, "turn combo")
	assert_eq(orbs.size(), 1, "chain result count")
	if _reactions.size() == 2:
		assert_eq(
			int(_reactions[0]["type"]),
			ReactionRules.Type.MERGE,
			"first reaction invokes the merge shockwave path"
		)
		assert_eq(
			int(_reactions[1]["type"]),
			ReactionRules.Type.MERGE,
			"second reaction invokes the same merge shockwave path"
		)
	if orbs.size() == 1:
		assert_eq(orbs[0].level, 4, "chain result level")
		assert_eq(orbs[0].generation, 2, "chain result generation")
	print("Merge chain sequence: %s" % str(_reaction_chains()))
	await _cleanup_fixture(fixture)


func test_three_stage_chain_waits_between_every_reaction() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
	var radius_one: float = Config.data.radius_for_level(1)
	var first: Orb = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(-radius_one + 0.5, 0.0)
	)
	var second: Orb = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(radius_one - 0.5, 0.0)
	)
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "three-stage first reaction")

	var elapsed_frames: Array[int] = [0]
	for target_level: int in [2, 3]:
		var current_result: Orb = _reactions[_reactions.size() - 1]["result_orb"] as Orb
		var partner: Orb = board.spawn_orb(
			OrbTypes.OrbColor.GREEN,
			target_level,
			current_result.position
		)
		partner.exit_ghost_state()
		resolver.report_contact(current_result, partner)
		var reaction_count_before: int = _reactions.size()
		for frame_index: int in range(delay_frames):
			var applied: int = resolver.flush(tick)
			if frame_index < delay_frames - 1:
				assert_eq(applied, 0, "three-stage reaction remains locked")
			else:
				assert_eq(applied, 1, "three-stage reaction unlocks on delay")
		assert_eq(
			_reactions.size(),
			reaction_count_before + 1,
			"three-stage reaction count advances once"
		)
		elapsed_frames.append(elapsed_frames[-1] + delay_frames)

	assert_eq(_reaction_chains(), [1, 2, 3], "three-stage chain generations")
	assert_eq(_reaction_combos(), [1, 2, 3], "three-stage turn combos")
	assert_eq(_combo_multipliers, [1.0, 2.0, 4.0], "three-stage multipliers")
	assert_eq(_max_combos, [1, 2, 3], "three-stage maximums")
	assert_eq(elapsed_frames, [0, delay_frames, delay_frames * 2], "three-stage timing")
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(orbs.size(), 1, "three-stage final orb count")
	if orbs.size() == 1:
		assert_eq(orbs[0].level, 4, "three-stage final level")
	await _cleanup_fixture(fixture)


func test_each_delayed_chain_merge_applies_its_color_effect() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	board.set_gravity(Vector2i.DOWN)
	var radius_one: float = Config.data.radius_for_level(1)
	var first: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-radius_one + 0.5, 0.0)
	)
	var second: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(radius_one - 0.5, 0.0)
	)
	var partner: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 2, Vector2.ZERO)
	var observer: Orb = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		1,
		Vector2(100.0, 0.0)
	)
	partner.exit_ghost_state()
	observer.exit_ghost_state()
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "first delayed color reaction")
	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
	for frame_index: int in range(delay_frames):
		var applied: int = resolver.flush(tick)
		if frame_index == delay_frames - 1:
			assert_eq(applied, 1, "second delayed color reaction")
	assert_eq(_reactions.size(), 2, "two delayed color reactions")
	if _reactions.size() == 2:
		for reaction_index: int in range(2):
			var targets: Array[Dictionary] = (
				_reactions[reaction_index]["shock_targets"] as Array[Dictionary]
			)
			var observer_effect: Dictionary = {}
			for target_info: Dictionary in targets:
				if int(target_info["stable_spawn_id"]) == observer.stable_spawn_id:
					observer_effect = target_info
					break
			assert_true(
				not observer_effect.is_empty(),
				"chain reaction %d affects observer" % (reaction_index + 1)
			)
			if not observer_effect.is_empty():
				assert_eq(
					int(observer_effect["mode"]),
					GameConfig.ShockMode.PUSH,
					"chain reaction %d uses red PUSH" % (reaction_index + 1)
				)
	await _cleanup_fixture(fixture)


func test_locked_contact_that_separates_is_not_replayed() -> void:
	var previous_pairs: Array[Vector2i] = Config.data.opposite_pairs.duplicate()
	Config.data.opposite_pairs = [
		Vector2i(OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE),
	]
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var radius: float = Config.data.radius_for_level(1)
	var first: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-radius + 0.5, 0.0)
	)
	var second: Orb = board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(radius - 0.5, 0.0)
	)
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "separation fixture first merge")
	var locked_result: Orb = _reactions[0]["result_orb"] as Orb
	var opposite: Orb = board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		locked_result.level,
		locked_result.position
	)
	opposite.exit_ghost_state()
	resolver.report_contact(locked_result, opposite)
	assert_eq(resolver.flush(), 0, "locked opposite pair is deferred")
	assert_true(resolver.has_pending_reactions(), "locked touching pair blocks stability")
	opposite.position = Vector2(board.half_size() - opposite.get_radius(), 0.0)
	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
	for _frame: int in range(delay_frames + 1):
		resolver.flush(tick)
	assert_eq(_reactions.size(), 1, "separated locked contact is not replayed")
	assert_true(not resolver.has_pending_reactions(), "separated pair no longer blocks stability")
	await _cleanup_fixture(fixture)
	Config.data.opposite_pairs = previous_pairs


func test_new_contact_during_lock_reacts_on_unlock() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var radius: float = Config.data.radius_for_level(1)
	var first: Orb = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		1,
		Vector2(-radius + 0.5, 0.0)
	)
	var second: Orb = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		1,
		Vector2(radius - 0.5, 0.0)
	)
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "new-contact fixture first merge")
	var locked_result: Orb = _reactions[0]["result_orb"] as Orb
	var partner: Orb = board.spawn_orb(
		OrbTypes.OrbColor.YELLOW,
		locked_result.level,
		locked_result.position
	)
	partner.exit_ghost_state()
	resolver.report_contact(locked_result, partner)
	assert_eq(resolver.flush(), 0, "new contact is deferred while locked")
	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
	for frame_index: int in range(delay_frames):
		var applied: int = resolver.flush(tick)
		if frame_index < delay_frames - 1:
			assert_eq(applied, 0, "new contact waits until unlock frame")
		else:
			assert_eq(applied, 1, "new contact reacts on unlock frame")
	assert_eq(_reaction_chains(), [1, 2], "new contact chain generations")
	assert_eq(_reaction_combos(), [1, 2], "new contact combo sequence")
	await _cleanup_fixture(fixture)


func test_newly_merged_level_six_blasts_after_lock_release() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var radius: float = Config.data.radius_for_level(5)
	var first: Orb = board.spawn_orb(0, 5, Vector2(-radius + 0.5, 0.0))
	var second: Orb = board.spawn_orb(0, 5, Vector2(radius - 0.5, 0.0))
	assert_true(not first.is_blast_armed(), "L5 is not blast armed")
	first.exit_ghost_state()
	second.exit_ghost_state()
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "L5 pair merges")
	var merged: Orb = _reactions[0]["result_orb"] as Orb
	assert_true(merged.is_blast_armed(), "L5 to L6 merge starts blinking")
	var initial_brightness: float = merged.blast_brightness()
	var merged_visual: OrbVisual = merged.get_node("Visual") as OrbVisual
	merged_visual._process(Config.data.blast_blink_period * 0.25)
	assert_true(
		not is_equal_approx(merged.blast_brightness(), initial_brightness),
		"armed L6 brightness oscillates"
	)
	var partner: Orb = board.spawn_orb(1, 6, merged.position)
	partner.exit_ghost_state()
	resolver.report_contact(merged, partner)
	assert_eq(resolver.flush(), 0, "new L6 blast waits for merge lock")
	var tick: float = 1.0 / float(Engine.physics_ticks_per_second)
	var delay_frames: int = roundi(Config.data.chain_reaction_delay / tick)
	for frame_index: int in range(delay_frames):
		var applied: int = resolver.flush(tick)
		if frame_index < delay_frames - 1:
			assert_eq(applied, 0, "blast remains locked")
		else:
			assert_eq(applied, 1, "blast occurs on unlock")
	assert_eq(_reactions.size(), 2, "merge and blast reactions")
	assert_eq(_reactions[1]["type"], ReactionRules.Type.BLAST, "released reaction is blast")
	assert_eq(_reactions[1]["result_orb"], null, "blast creates no result")
	assert_eq(board.get_orbs().size(), 0, "blast removes both armed orbs")
	assert_true(merged.consumed, "armed visual owner consumed on blast")
	assert_eq(manager.turn_combo, 2, "blast increments combo")
	assert_eq(manager.max_combo, 2, "blast updates maximum combo")
	await _cleanup_fixture(fixture)


func test_zero_chain_reaction_delay_keeps_immediate_behavior() -> void:
	var original_delay: float = Config.data.chain_reaction_delay
	Config.data.chain_reaction_delay = 0.0
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var radius: float = Config.data.radius_for_level(1)
	var first: Orb = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(-radius + 0.5, 0.0)
	)
	var second: Orb = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		1,
		Vector2(radius - 0.5, 0.0)
	)
	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "zero-delay first merge")
	var result: Orb = _reactions[0]["result_orb"] as Orb
	var partner: Orb = board.spawn_orb(
		OrbTypes.OrbColor.GREEN,
		result.level,
		result.position + Vector2(result.get_radius() * 2.0 - 1.0, 0.0)
	)
	resolver.report_contact(result, partner)
	assert_eq(resolver.flush(), 1, "zero-delay follow-up is immediate")
	assert_eq(_reaction_combos(), [1, 2], "zero-delay combo sequence")
	await _cleanup_fixture(fixture)
	Config.data.chain_reaction_delay = original_delay


func test_independent_simultaneous_merges_advance_combo() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var half_distance: float = Config.data.radius_for_level(1) - 0.5
	var pair_offset: float = 200.0
	board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-pair_offset - half_distance, 0.0)
	)
	board.spawn_orb(
		OrbTypes.OrbColor.RED,
		1,
		Vector2(-pair_offset + half_distance, 0.0)
	)
	board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		1,
		Vector2(pair_offset - half_distance, 0.0)
	)
	board.spawn_orb(
		OrbTypes.OrbColor.BLUE,
		1,
		Vector2(pair_offset + half_distance, 0.0)
	)

	var applied: int = await _advance_and_flush(board, resolver, OBSERVE_SECONDS)
	assert_eq(applied, 2, "independent reaction count")
	assert_eq(_reaction_chains(), [1, 1], "independent chain values")
	assert_eq(_reaction_combos(), [1, 2], "independent combo values")
	assert_eq(manager.turn_combo, 2, "independent turn combo")
	assert_eq(board.get_orbs().size(), 2, "independent result count")
	await _cleanup_fixture(fixture)


func test_annihilation_advances_combo() -> void:
	var previous_pairs: Array[Vector2i] = Config.data.opposite_pairs.duplicate()
	Config.data.opposite_pairs = [
		Vector2i(OrbTypes.OrbColor.RED, OrbTypes.OrbColor.BLUE),
	]
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var manager: TurnManager = fixture["manager"] as TurnManager
	var first: Orb = board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(-20.0, 0.0))
	var second: Orb = board.spawn_orb(OrbTypes.OrbColor.BLUE, 1, Vector2(20.0, 0.0))

	resolver.report_contact(first, second)
	assert_eq(resolver.flush(), 1, "annihilation reaction count")
	assert_eq(manager.turn_combo, 1, "annihilation turn combo")
	if _reactions.size() == 1:
		assert_eq(_reactions[0]["type"], ReactionRules.Type.ANNIHILATE, "annihilation type")
		assert_eq(_reactions[0]["combo"], 1, "annihilation combo")
	await _cleanup_fixture(fixture)
	Config.data.opposite_pairs = previous_pairs


func test_max_level_pair_clears_without_result() -> void:
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var half_distance: float = (
		Config.data.radius_for_level(Config.data.orb_max_level) - 0.5
	)
	board.spawn_orb(
		OrbTypes.OrbColor.RED,
		Config.data.orb_max_level,
		Vector2(-half_distance, 0.0)
	)
	board.spawn_orb(
		OrbTypes.OrbColor.RED,
		Config.data.orb_max_level,
		Vector2(half_distance, 0.0)
	)

	var applied: int = await _advance_and_flush(board, resolver, OBSERVE_SECONDS)
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
	var radius: float = Config.data.radius_for_level(1)
	var wall_x: float = board.half_size() - radius - Config.data.spawn_margin
	var half_distance: float = radius - 0.5
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(wall_x, -half_distance))
	board.spawn_orb(OrbTypes.OrbColor.RED, 1, Vector2(wall_x, half_distance))

	var applied: int = await _advance_and_flush(board, resolver, OBSERVE_SECONDS)
	var orbs: Array[Orb] = board.get_orbs()
	assert_eq(applied, 1, "wall reaction count")
	assert_eq(orbs.size(), 1, "wall result count")
	if _reactions.size() == 1:
		var position: Vector2 = _reactions[0]["position"] as Vector2
		var result_radius: float = Config.data.radius_for_level(2)
		assert_true(
			absf(position.x) <= board.half_size() - result_radius,
			"wall result x inside"
		)
		assert_true(
			absf(position.y) <= board.half_size() - result_radius,
			"wall result y inside"
		)
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
	assert_true(manager.turn_combo >= 1, "merge turn combo")
	assert_eq(_finished_combos.size(), 1, "turn_finished signal count")
	if _finished_combos.size() == 1:
		assert_true(_finished_combos[0] >= 1, "turn_finished combo")
	assert_true(_reactions.size() >= 1, "merge reaction during turn")
	await _cleanup_fixture(fixture)
	_restore_turn_config(snapshot)


func test_waiting_input_flush_continues_previous_turn_combo() -> void:
	var snapshot: Dictionary = _snapshot_turn_config()
	Config.data.stable_linear_speed = HIGH_THRESHOLD
	Config.data.stable_angular_speed = HIGH_THRESHOLD
	var fixture: Dictionary = await _create_fixture()
	var board: Board = fixture["board"] as Board
	var resolver: CollisionResolver = fixture["resolver"] as CollisionResolver
	var spawner: Spawner = fixture["spawner"] as Spawner
	var manager: TurnManager = fixture["manager"] as TurnManager
	spawner.init_rng(5010)
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

	var chain_result: Orb = null
	for reaction_index: int in range(_reactions.size() - 1, -1, -1):
		var candidate: Orb = _reactions[reaction_index]["result_orb"] as Orb
		if candidate != null and is_instance_valid(candidate) and not candidate.consumed:
			chain_result = candidate
			break
	assert_true(chain_result != null, "turn leaves a merge result for waiting-input chain")
	if chain_result == null:
		await _cleanup_fixture(fixture)
		_restore_turn_config(snapshot)
		return

	var finished_combo: int = manager.turn_combo
	var expected_chain: int = chain_result.generation + 1
	var expected_combo: int = finished_combo + 1
	var result_radius: float = chain_result.get_radius()
	chain_result.position = Vector2(-result_radius + 0.5, 0.0)
	chain_result.linear_velocity = Vector2.ZERO
	chain_result.angular_velocity = 0.0
	var reaction_count_before: int = _reactions.size()
	var waiting_partner: Orb = board.spawn_orb(
		chain_result.color,
		chain_result.level,
		Vector2(result_radius - 0.5, 0.0)
	)
	resolver.report_contact(chain_result, waiting_partner)

	for _frame: int in range(120):
		if _reactions.size() > reaction_count_before:
			break
		await tree.physics_frame
		assert_board_motion_bounds(board, "waiting-input merge")
	assert_true(
		_reactions.size() > reaction_count_before,
		"waiting input emits reaction_applied"
	)
	assert_eq(manager.state, TurnManager.State.WAITING_INPUT, "reaction keeps waiting state")
	assert_eq(manager.turn_combo, expected_combo, "waiting reaction continues turn combo")
	if _reactions.size() > reaction_count_before:
		var waiting_reaction: Dictionary = _reactions[_reactions.size() - 1]
		assert_eq(int(waiting_reaction["chain"]), expected_chain, "waiting reaction chain")
		assert_eq(int(waiting_reaction["combo"]), expected_combo, "waiting reaction combo")
		var waiting_result: Orb = waiting_reaction["result_orb"] as Orb
		assert_true(waiting_result != null, "waiting reaction result orb")
		if waiting_result != null:
			assert_eq(waiting_result.generation, expected_chain, "waiting result generation")

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
	manager.combo_changed.connect(_record_combo)
	return {
		"root": fixture_root,
		"board": board,
		"resolver": resolver,
		"spawner": spawner,
		"manager": manager,
	}


func _advance_and_flush(
	board: Board,
	_resolver: CollisionResolver,
	seconds: float
) -> int:
	var reaction_count_before: int = _reactions.size()
	var frame_count: int = ceili(float(Engine.physics_ticks_per_second) * seconds)
	for _frame: int in range(frame_count):
		await tree.physics_frame
		assert_board_motion_bounds(board, "merge observation")
	return _reactions.size() - reaction_count_before


func _wait_for_state(manager: TurnManager, target: TurnManager.State) -> void:
	var max_frames: int = ceili(float(Engine.physics_ticks_per_second) * WAIT_TIMEOUT_SECONDS)
	for _frame: int in range(max_frames):
		if manager.state == target:
			return
		await tree.physics_frame
		var board: Board = manager.get_parent().get_node("Board") as Board
		assert_board_motion_bounds(board, "merge state wait")
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


func _reaction_combos() -> Array[int]:
	var combos: Array[int] = []
	for reaction: Dictionary in _reactions:
		combos.append(int(reaction["combo"]))
	return combos


func _assert_reaction_dictionary(reaction: Dictionary) -> void:
	var keys: Array[String] = [
		"type",
		"chain",
		"combo",
		"occupancy",
		"levels",
		"colors",
		"position",
		"result_level",
		"result_color",
		"result_orb",
		"shock_level",
		"shock_targets",
		"blast_targets",
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
	_combos.clear()
	_combo_multipliers.clear()
	_max_combos.clear()
	_finished_combos.clear()


func _record_reaction(reaction: Dictionary) -> void:
	_reactions.append(reaction)


func _record_combo(combo: int, multiplier: float, max_combo: int) -> void:
	_combos.append(combo)
	_combo_multipliers.append(multiplier)
	_max_combos.append(max_combo)


func _record_turn_finished(_turn_index: int, combo: int) -> void:
	_finished_combos.append(combo)
