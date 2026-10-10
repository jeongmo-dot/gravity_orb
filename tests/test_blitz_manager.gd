extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SCORE_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const BLITZ_SCRIPT: Script = preload("res://scripts/core/BlitzManager.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const BEST_SAVE_PATH: String = "res://tests/test_blitz_best.tmp.cfg"
const TOLERANCE: float = 0.001


func test_initial_fill_is_non_overlapping_and_ready_locks_input() -> void:
	var fixture: Dictionary = await _create_fixture(3100, 0.35, 1.5)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	var occupancy: float = _occupancy(board)
	assert_true(occupancy >= 0.35, "initial fill reaches target occupancy")
	assert_true(occupancy < 0.38, "initial fill only overshoots by one orb")
	assert_near(_maximum_overlap(board), 0.0, TOLERANCE, "initial fill has no overlap")
	assert_eq(spawner.peek_preview().size(), 2, "ready preserves NEXT and THEN")
	assert_eq(manager.state, BlitzManager.State.READY, "ready state begins after fill")
	assert_true(InputRouter.is_locked(), "ready locks input")
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.accepted_swipes, 0, "ready ignores swipe")
	assert_eq(manager.spawn_count, 0, "ready swipe does not spawn")
	manager._physics_process(1.5)
	assert_eq(manager.state, BlitzManager.State.RUNNING, "ready transitions to go")
	assert_true(not InputRouter.is_locked(), "go unlocks input")
	assert_near(manager.play_time_elapsed, 0.0, TOLERANCE, "timer waits for go")
	await _cleanup_fixture(fixture)


func test_swipe_changes_gravity_with_cooldown_buffer_and_same_direction_ignore() -> void:
	var fixture: Dictionary = await _create_fixture(3101)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	Config.data.blitz_target_occupancy = 0.0
	manager._sync_swipe_spawn_preview()
	var initial_count: int = board.get_orbs().size()
	var preview_before: Array = spawner.peek_preview()
	manager._physics_process(5.0)
	assert_eq(manager.spawn_count, 0, "time alone does not spawn in swipe mode")
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.gravity, Vector2i.RIGHT, "first swipe applies immediately")
	assert_eq(manager.accepted_swipes, 1, "first swipe accepted")
	assert_eq(manager.spawn_count, 1, "accepted swipe spawns one orb")
	assert_eq(board.get_orbs().size(), initial_count + 1, "one swipe adds one orb")
	var spawned: Orb = board.get_orbs()[-1]
	var expected_x: float = (
		-board.half_size() + spawned.get_radius() + Config.data.spawn_margin
	)
	assert_near(spawned.position.x, expected_x, TOLERANCE, "spawn uses new gravity opposite wall")
	var preview_after: Array = spawner.peek_preview()
	assert_eq(preview_after[0], preview_before[1], "THEN advances to NEXT")
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.gravity, Vector2i.RIGHT, "cooldown delays rapid swipe")
	assert_eq(manager.spawn_count, 1, "buffered swipe does not spawn early")
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	assert_eq(manager.gravity, Vector2i.UP, "buffer executes on cooldown end frame")
	assert_eq(manager.spawn_count, 2, "buffered swipe spawns once")
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.accepted_swipes, 2, "same direction ignored")
	assert_eq(manager.spawn_count, 2, "only accepted swipes spawn")
	await _cleanup_fixture(fixture)


func test_cooldown_uses_real_time_and_buffer_keeps_last_valid_direction() -> void:
	var fixture: Dictionary = await _create_fixture(3157)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	Config.data.blitz_spawn_on_swipe = false
	var original_time_scale: float = Engine.time_scale
	manager.on_swipe(Vector2i.RIGHT)
	manager.on_swipe(Vector2i.UP)
	manager.on_swipe(Vector2i.RIGHT)
	manager.on_swipe(Vector2i.LEFT)
	Engine.time_scale = 0.12
	manager._physics_process(0.0095)
	assert_eq(manager.gravity, Vector2i.RIGHT, "scaled 79ms keeps cooldown active")
	manager._physics_process(0.0001)
	assert_eq(manager.gravity, Vector2i.LEFT, "real 80ms executes latest buffered direction")
	assert_eq(manager.accepted_swipes, 2, "intermediate and same directions are discarded")
	Engine.time_scale = original_time_scale
	await _cleanup_fixture(fixture)


func test_ready_and_finale_do_not_store_buffered_swipes() -> void:
	var fixture: Dictionary = await _create_fixture(3158, 0.0, 1.5)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	Config.data.blitz_spawn_on_swipe = false
	manager.on_swipe(Vector2i.RIGHT)
	manager._physics_process(1.5)
	assert_eq(manager.accepted_swipes, 0, "READY swipe is not buffered")
	manager.on_swipe(Vector2i.RIGHT)
	manager.on_swipe(Vector2i.UP)
	manager._begin_finale()
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	assert_eq(manager.accepted_swipes, 1, "FINALE clears pending buffered swipe")
	await _cleanup_fixture(fixture)


func test_blitz_preview_signal_is_coalesced_to_one_per_swipe_frame() -> void:
	var fixture: Dictionary = await _create_fixture(3159)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var spawner: Spawner = fixture["spawner"] as Spawner
	await tree.process_frame
	var signal_count: Array[int] = [0]
	spawner.preview_changed.connect(func(_batches: Array) -> void: signal_count[0] += 1)
	manager.on_swipe(Vector2i.RIGHT)
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	await tree.process_frame
	assert_eq(signal_count[0], 1, "same-frame preview changes publish once")
	await _cleanup_fixture(fixture)


func test_target_density_empty_board_caps_at_eight_and_full_board_spawns_one() -> void:
	var fixture: Dictionary = await _create_fixture(3136)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	_clear_board(board)
	manager._sync_swipe_spawn_preview()
	assert_eq((spawner.peek_preview()[0] as Array).size(), 8, "empty board NEXT caps at eight")
	_add_level_orbs(board, 7, 7)
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 7))
	assert_eq(
		(spawner.peek_preview()[0] as Array).size(),
		1,
		"reaction refreshes NEXT from changed occupancy"
	)
	_clear_board(board)
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 7))
	assert_eq(
		(spawner.peek_preview()[0] as Array).size(),
		8,
		"NEXT returns to cap when reactions leave board empty"
	)
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.spawn_count, 8, "empty board swipe spawns capped eight")
	_clear_board(board)
	_add_level_orbs(board, 7, 7)
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager._sync_swipe_spawn_preview()
	assert_true(_occupancy(board) >= 0.4, "seven level seven orbs exceed target")
	assert_eq((spawner.peek_preview()[0] as Array).size(), 1, "full board NEXT falls to one")
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.spawn_count, 9, "full board keeps one-orb swipe penalty")
	assert_eq(manager.refill_debt, 0, "target density has no carried count debt")
	await _cleanup_fixture(fixture)


func test_target_density_thirty_percent_fills_toward_target() -> void:
	var fixture: Dictionary = await _create_fixture(3139)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	_clear_board(board)
	_add_level_orbs(board, 5, 7)
	manager._sync_swipe_spawn_preview()
	var occupancy_before: float = _occupancy(board)
	var next_batch: Array = spawner.peek_preview()[0] as Array
	var projected: float = occupancy_before + _candidate_batch_occupancy(next_batch)
	assert_true(occupancy_before >= 0.30, "fixture starts around thirty percent")
	assert_true(occupancy_before < 0.40, "fixture starts below target")
	assert_true(next_batch.size() > 1, "below target produces multiple candidates")
	assert_true(next_batch.size() <= 8, "target batch respects cap")
	assert_true(
		next_batch.size() == 8 or projected >= Config.data.blitz_target_occupancy,
		"batch reaches target or exhausts cap"
	)
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.spawn_count, next_batch.size(), "previewed density batch spawns together")
	await _cleanup_fixture(fixture)


func test_count_debt_measurement_rule_spawns_merge_blast_and_empty_amounts() -> void:
	var fixture: Dictionary = await _create_fixture(3136)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	manager.refill_rule = BlitzManager.RefillRule.COUNT_DEBT
	manager._sync_swipe_spawn_preview()
	var initial_count: int = board.get_orbs().size()
	for _index: int in range(3):
		manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_eq(manager.refill_debt, 3, "three merges add three debt")
	assert_eq((spawner.peek_preview()[0] as Array).size(), 3, "NEXT shows three")
	assert_eq((spawner.peek_preview()[1] as Array).size(), 1, "THEN stays one")
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.spawn_count, 3, "three merge debt spawns three")
	assert_eq(board.get_orbs().size(), initial_count + 3, "three orbs enter as one batch")
	assert_eq(manager.refill_debt, 0, "three spawn clears debt")
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager.on_reaction(
		_reaction(ReactionRules.Type.BLAST, Config.data.active_blast_min_level())
	)
	assert_eq(manager.refill_debt, 2, "blast adds two debt")
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.spawn_count, 5, "blast debt spawns two")
	assert_eq(manager.refill_debt, 0, "blast debt is cleared")
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager.on_swipe(Vector2i.LEFT)
	assert_eq(manager.spawn_count, 6, "empty debt keeps one-orb swipe penalty")
	assert_eq(manager.spawn_batch_histogram[3], 1, "three batch histogram")
	assert_eq(manager.spawn_batch_histogram[2], 1, "two batch histogram")
	assert_eq(manager.spawn_batch_histogram[1], 1, "one batch histogram")
	assert_eq(manager.max_spawn_batch, 3, "maximum batch tracks observation")
	await _cleanup_fixture(fixture)


func test_count_debt_measurement_rule_caps_at_eight_and_carries_three() -> void:
	var fixture: Dictionary = await _create_fixture(3137)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	manager.refill_rule = BlitzManager.RefillRule.COUNT_DEBT
	manager._sync_swipe_spawn_preview()
	for _index: int in range(11):
		manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_eq(manager.refill_debt, 11, "eleven debt accumulated")
	assert_eq((spawner.peek_preview()[0] as Array).size(), 8, "NEXT caps at eight")
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.spawn_count, 8, "first swipe spawns capped eight")
	assert_eq(manager.refill_debt, 3, "three debt carries")
	for orb: Orb in board.get_orbs():
		board.remove_orb(orb)
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.spawn_count, 11, "second swipe spawns carried three")
	assert_eq(manager.refill_debt, 0, "carried debt clears")
	assert_eq(manager.max_spawn_batch, 8, "maximum batch cap observed")
	await _cleanup_fixture(fixture)


func test_disabled_swipe_spawn_preserves_time_refill_and_blocked_tick() -> void:
	var fixture: Dictionary = await _create_fixture(3102)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	Config.data.blitz_spawn_on_swipe = false
	Config.data.blitz_spawn_interval = 0.8
	Config.data.blitz_refill_interval = 0.15
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_eq(manager.refill_debt, 0, "target density does not record count debt")
	var initial_count: int = board.get_orbs().size()
	Config.data.blitz_target_occupancy = 1.0
	manager._physics_process(0.149)
	assert_eq(manager.spawn_count, 0, "refill waits for 0.15 second boundary")
	manager._physics_process(0.001)
	assert_eq(manager.spawn_count, 1, "first interval spawns one")
	assert_eq(board.get_orbs().size(), initial_count + 1, "one orb entered board")
	Config.data.blitz_target_occupancy = 0.0
	manager._physics_process(0.799)
	assert_eq(manager.spawn_count, 1, "normal spawn waits for 0.8 second boundary")
	manager._physics_process(0.001)
	assert_eq(manager.spawn_count, 2, "occupancy boundary switches to normal interval")
	var waiting: Orb = board.get_orbs()[0]
	waiting.enter_entrance_wait(waiting.position, manager.gravity)
	manager._physics_process(Config.data.blitz_spawn_interval)
	assert_eq(manager.spawn_count, 2, "blocked interval does not accumulate spawn")
	assert_eq(manager.skipped_spawn_ticks, 1, "blocked interval counted once")
	waiting.exit_ghost_state()
	manager._physics_process(Config.data.blitz_spawn_interval)
	assert_eq(manager.spawn_count, 3, "next clear interval spawns once")
	var preview: Array = (fixture["spawner"] as Spawner).peek_preview()
	assert_eq(preview.size(), 2, "blitz keeps NEXT and THEN")
	assert_eq((preview[0] as Array).size(), 1, "NEXT is one timed spawn")
	assert_eq((preview[1] as Array).size(), 1, "THEN is one timed spawn")
	assert_eq(manager.refill_debt, 0, "time path keeps target density debt-free")
	await _cleanup_fixture(fixture)


func test_blocked_swipe_changes_gravity_without_consuming_next() -> void:
	var fixture: Dictionary = await _create_fixture(3105)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	Config.data.blitz_target_occupancy = 0.0
	manager._sync_swipe_spawn_preview()
	manager.on_swipe(Vector2i.RIGHT)
	var waiting: Orb = board.get_orbs()[-1]
	waiting.enter_entrance_wait(waiting.position, manager.gravity)
	for _index: int in range(3):
		manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	var next_before: Array[Dictionary] = spawner.peek_next()
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.gravity, Vector2i.UP, "blocked swipe still changes gravity")
	assert_eq(manager.accepted_swipes, 2, "blocked swipe remains accepted")
	assert_eq(manager.spawn_count, 1, "blocked entrance skips spawn")
	assert_eq(manager.skipped_spawn_ticks, 1, "blocked spawn is counted")
	assert_eq(manager.refill_debt, 0, "blocked target refill has no carry")
	assert_eq(spawner.peek_next(), next_before, "blocked spawn keeps NEXT")
	await _cleanup_fixture(fixture)


func test_target_density_reactions_do_not_add_refill_debt() -> void:
	var fixture: Dictionary = await _create_fixture(3138)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_eq(manager.refill_debt, 0, "running merge uses density instead of count debt")
	manager._begin_finale()
	manager.on_reaction(
		_reaction(ReactionRules.Type.BLAST, Config.data.active_blast_min_level())
	)
	manager.on_reaction(_reaction(ReactionRules.Type.MAX_CLEAR, 7))
	assert_eq(manager.refill_debt, 0, "finale reactions add no debt")
	await _cleanup_fixture(fixture)


func test_speed_chain_productive_miss_idle_fever_and_time_bonus_cap() -> void:
	var fixture: Dictionary = await _create_fixture(3103)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	Config.data.blitz_survival_enabled = false
	Config.data.blitz_spawn_on_swipe = false
	var first: Dictionary = _productive_swipe(manager, Vector2i.RIGHT)
	assert_eq(manager.chain, 1, "productive swipe raises chain once")
	assert_eq(manager.reaction_count, 1, "running reaction is counted")
	assert_eq(manager.passive_reaction_count, 0, "productive reaction is not passive")
	assert_eq(bool(first["productive_swipe"]), true, "reaction records productive swipe")
	assert_near(float(first["combo_multiplier"]), 1.25, TOLERANCE, "chain step")
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager.on_swipe(Vector2i.UP)
	manager._physics_process(Config.data.blitz_chain_window + 0.01)
	assert_eq(manager.chain, 0, "missed swipe resets chain")
	var second_fever_chain: int = Config.data.blitz_fever_chain * 2
	for index: int in range(second_fever_chain):
		manager._physics_process(Config.data.blitz_swipe_cooldown)
		_productive_swipe(manager, _next_direction(manager.gravity, index))
	assert_eq(manager.chain, second_fever_chain, "productive swipes build chain")
	assert_eq(manager.max_chain, second_fever_chain, "maximum chain tracks board run")
	assert_eq(manager.fever_count, 2, "two configured chain thresholds trigger fever")
	assert_near(
		manager.fever_remaining,
		Config.data.blitz_fever_duration,
		TOLERANCE,
		"second configured chain threshold refreshes fever"
	)
	var passive: Dictionary = _reaction(ReactionRules.Type.MERGE, 2)
	manager.on_reaction(passive)
	assert_eq(manager.chain, second_fever_chain, "reaction without swipe does not raise chain")
	assert_eq(manager.passive_reaction_count, 1, "reaction without swipe is counted")
	assert_eq(bool(passive["productive_swipe"]), false, "reaction records passive state")
	assert_near(
		float(passive["combo_multiplier"]),
		manager.current_combo_multiplier(),
		TOLERANCE,
		"passive reaction uses current chain"
	)
	for index: int in range(4):
		manager._physics_process(Config.data.blitz_swipe_cooldown)
		_productive_swipe(manager, _next_direction(manager.gravity, index))
	assert_near(manager.current_combo_multiplier(), 5.0, TOLERANCE, "chain multiplier cap")
	manager._physics_process(Config.data.blitz_chain_idle)
	assert_eq(manager.chain, 0, "two seconds without swipe resets chain")
	for _index: int in range(50):
		manager.on_reaction(
			_reaction(ReactionRules.Type.BLAST, Config.data.active_blast_min_level())
		)
	manager.on_reaction(_reaction(ReactionRules.Type.MAX_CLEAR, 7))
	assert_near(manager.time_bonus_total, 20.0, TOLERANCE, "time bonus is capped")
	await _cleanup_fixture(fixture)


func test_survival_clock_ramp_reaction_bonuses_fever_and_clock_cap() -> void:
	var fixture: Dictionary = await _create_fixture(3161)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	assert_near(manager.remaining_time, 30.0, TOLERANCE, "survival clock starts at thirty")
	Config.data.blitz_drain_ramp_per_minute = 0.0
	var original_time_scale: float = Engine.time_scale
	Engine.time_scale = 0.5
	manager._physics_process(0.5)
	Engine.time_scale = original_time_scale
	assert_near(manager.remaining_time, 29.0, TOLERANCE, "zero ramp drains real seconds")
	assert_near(manager.play_time_elapsed, 1.0, TOLERANCE, "survival time ignores time scale")
	manager.remaining_time = 100.0
	manager.play_time_elapsed = 60.0
	Config.data.blitz_drain_ramp_per_minute = 0.1
	manager._physics_process(1.0)
	assert_near(
		manager.remaining_time,
		98.8991667,
		TOLERANCE,
		"ramp integrates the multiplier across the elapsed second"
	)
	Config.data.blitz_drain_ramp_per_minute = 0.0
	manager.remaining_time = 20.0
	manager.time_bonus_total = 0.0
	manager.time_bonus_by_source.clear()
	var expected_by_level: Array[float] = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6]
	for index: int in range(expected_by_level.size()):
		var result_level: int = index + 2
		var before: float = manager.remaining_time
		manager.on_reaction(_merge_result_reaction(result_level))
		assert_near(
			manager.remaining_time - before,
			expected_by_level[index],
			TOLERANCE,
			"merge result L%d bonus" % result_level
		)
	var before_blast: float = manager.remaining_time
	manager.on_reaction(_reaction(ReactionRules.Type.BLAST, 6))
	assert_near(manager.remaining_time - before_blast, 2.0, TOLERANCE, "L6 blast bonus")
	var before_jackpot: float = manager.remaining_time
	manager.on_reaction(_reaction(ReactionRules.Type.MAX_CLEAR, 7))
	assert_near(manager.remaining_time - before_jackpot, 3.0, TOLERANCE, "jackpot bonus")
	manager.fever_remaining = 1.0
	var before_fever: float = manager.remaining_time
	manager.on_reaction(_reaction(ReactionRules.Type.BLAST, 6))
	assert_near(
		manager.remaining_time - before_fever,
		4.0,
		TOLERANCE,
		"fever doubles L6 blast bonus"
	)
	manager.fever_remaining = 0.0
	manager.remaining_time = 44.8
	var before_cap_total: float = manager.time_bonus_total
	manager.on_reaction(_reaction(ReactionRules.Type.MAX_CLEAR, 7))
	assert_near(manager.remaining_time, 45.0, TOLERANCE, "clock caps at forty five")
	assert_near(
		manager.time_bonus_total - before_cap_total,
		0.2,
		TOLERANCE,
		"overflow bonus is discarded"
	)
	await _cleanup_fixture(fixture)


func test_survival_disabled_preserves_ninety_seconds_and_legacy_bonus_cap() -> void:
	var fixture: Dictionary = await _create_fixture(3162)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	Config.data.blitz_survival_enabled = false
	manager.start_game()
	manager.set_physics_process(false)
	assert_near(manager.remaining_time, 90.0, TOLERANCE, "legacy clock starts at ninety")
	for _index: int in range(50):
		manager.on_reaction(
			_reaction(ReactionRules.Type.BLAST, Config.data.active_blast_min_level())
		)
	assert_near(manager.time_bonus_total, 20.0, TOLERANCE, "legacy bonus cap stays twenty")
	assert_near(manager.remaining_time, 110.0, TOLERANCE, "legacy bonuses extend duration")
	await _cleanup_fixture(fixture)


func test_time_up_locks_input_and_finale_blasts_largest_first() -> void:
	var fixture: Dictionary = await _create_fixture(3104)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	Config.data.blitz_duration = 0.05
	Config.data.blitz_finale_interval = 0.1
	board.spawn_orb(0, 6, Vector2(-180.0, 0.0)).exit_ghost_state()
	board.spawn_orb(1, 7, Vector2(180.0, 0.0)).exit_ghost_state()
	manager.remaining_time = Config.data.blitz_duration
	var finale_levels: Array[int] = []
	manager.finale_blast.connect(func(level: int) -> void: finale_levels.append(level))
	manager._physics_process(0.05)
	assert_eq(manager.state, BlitzManager.State.FINALE, "timer enters finale")
	assert_true(InputRouter.is_locked(), "input locks before finale")
	var spawn_count_before_finale_swipe: int = manager.spawn_count
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.spawn_count, spawn_count_before_finale_swipe, "finale does not spawn")
	manager._physics_process(0.1)
	manager._physics_process(0.1)
	assert_eq(finale_levels, [7, 6], "finale orders eligible large levels first")
	manager._physics_process(BlitzManager.FINALE_REACTION_IDLE_TIME + 0.01)
	assert_eq(manager.state, BlitzManager.State.FINISHED, "settle ends in result state")
	assert_eq(manager.finale_blast_count, 2, "two finale blasts counted")
	assert_eq(str(manager.game_over_details["reason"]), "TIME UP", "result reason")
	await _cleanup_fixture(fixture)


func test_turn_and_blitz_best_scores_use_separate_save_keys() -> void:
	_remove_test_file(BEST_SAVE_PATH)
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	Config.data.game_mode = GameConfig.GameMode.TURN
	var turn_score: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	turn_score.on_reaction(_reaction(ReactionRules.Type.MERGE, 3))
	var saved_turn_best: int = turn_score.best_score
	turn_score.commit_ranking(
		GameConfig.GameMode.TURN,
		{"max_combo": 1, "turns": 1, "max_level": 4},
		"2026-10-09 12:00"
	)
	turn_score.queue_free()
	await tree.process_frame
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var blitz_score: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	assert_eq(blitz_score.best_score, 0, "blitz does not load turn best")
	blitz_score.on_reaction(_reaction(ReactionRules.Type.MERGE, 4))
	var saved_blitz_best: int = blitz_score.best_score
	blitz_score.commit_ranking(
		GameConfig.GameMode.BLITZ,
		{"max_chain": 1, "blasts": 0, "fevers": 0},
		"2026-10-09 12:01"
	)
	assert_true(saved_blitz_best > saved_turn_best, "blitz best fixture differs")
	blitz_score.queue_free()
	await tree.process_frame
	Config.data.game_mode = GameConfig.GameMode.TURN
	var reloaded_turn: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	assert_eq(reloaded_turn.best_score, saved_turn_best, "turn best preserved")
	reloaded_turn.queue_free()
	await tree.process_frame
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var reloaded_blitz: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	assert_eq(reloaded_blitz.best_score, saved_blitz_best, "blitz best preserved")
	reloaded_blitz.queue_free()
	await tree.process_frame
	Config.data.game_mode = original_mode
	_remove_test_file(BEST_SAVE_PATH)


func test_main_selects_blitz_manager_and_shows_time_up_results() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var original_ready_time: float = Config.data.blitz_ready_time
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	Config.data.blitz_ready_time = 1.5
	var main: Main = MAIN_SCENE.instantiate() as Main
	main.launch_immediately(GameConfig.GameMode.BLITZ)
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	var manager: BlitzManager = main.get_node("BlitzManager") as BlitzManager
	var turn_manager: TurnManager = main.get_node("TurnManager") as TurnManager
	assert_eq(manager.state, BlitzManager.State.READY, "main starts blitz ready state")
	assert_true(InputRouter.is_locked(), "main ready locks input")
	assert_true(not turn_manager.is_physics_processing(), "turn manager disabled in blitz")
	assert_true(
		InputRouter.debug_toggle_game_mode.is_connected(Callable(main, "_toggle_game_mode")),
		"F4 toggle is bound to main restart path"
	)
	var timer_label: Label = main.get_node("UI/Hud/TimerLabel") as Label
	var max_chain_label: Label = main.get_node("UI/Hud/MaxComboLabel") as Label
	var chain_label: Label = main.get_node("UI/Hud/ComboLabel") as Label
	var multiplier_label: Label = main.get_node("UI/Hud/MultiplierLabel") as Label
	var blocked_label: Label = main.get_node("UI/Hud/BlockedLabel") as Label
	var hud: Hud = main.get_node("UI/Hud") as Hud
	assert_true(timer_label.visible, "blitz timer is visible")
	assert_true(timer_label.text.begins_with("READY"), "ready countdown is visible")
	assert_eq(max_chain_label.text, "MAX CHAIN 0", "blitz maximum uses chain label")
	assert_true(not blocked_label.visible, "turn blocked label is hidden")
	hud._on_preview_changed([
		[{"color": OrbTypes.OrbColor.PURPLE, "level": 1}],
		[{"color": OrbTypes.OrbColor.CYAN, "level": 2}],
	])
	var next_visual: OrbVisual = hud._next_preview.get_child(0) as OrbVisual
	var then_visual: OrbVisual = hud._then_preview.get_child(0) as OrbVisual
	assert_eq(
		next_visual._display_color,
		Config.data.color_display[OrbTypes.OrbColor.PURPLE],
		"NEXT renders purple"
	)
	assert_eq(
		then_visual._display_color,
		Config.data.color_display[OrbTypes.OrbColor.CYAN],
		"THEN renders cyan"
	)
	var eight_candidates: Array[Dictionary] = []
	for index: int in range(8):
		eight_candidates.append({"color": index % 6, "level": 1})
	hud._on_preview_changed([
		eight_candidates,
		eight_candidates,
	])
	var next_count_label: Label = main.get_node("UI/Hud/NextCountLabel") as Label
	var then_count_label: Label = main.get_node("UI/Hud/ThenCountLabel") as Label
	assert_eq(hud._next_preview.get_child_count(), 5, "NEXT renders at most five orbs")
	assert_true(next_count_label.visible, "large NEXT count label is visible")
	assert_eq(next_count_label.text, "×8", "large NEXT count label")
	assert_eq(hud._then_preview.get_child_count(), 5, "THEN renders at most five orbs")
	assert_true(then_count_label.visible, "large THEN count label is visible")
	assert_eq(then_count_label.text, "×8", "large THEN count label")
	manager._physics_process(1.5)
	assert_eq(manager.state, BlitzManager.State.RUNNING, "main starts blitz after ready")
	manager.play_time_elapsed = 120.0
	hud._on_time_changed(manager.remaining_time)
	var drain_label: Label = main.get_node("UI/Hud/DrainRateLabel") as Label
	assert_true(drain_label.visible, "survival ramp appears from 1.1x")
	assert_eq(drain_label.text, "×1.2", "survival ramp uses one decimal")
	manager.on_swipe(Vector2i.RIGHT)
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_eq(chain_label.text, "CHAIN 1", "blitz HUD uses chain label")
	assert_eq(multiplier_label.text, "×1.25", "blitz HUD uses large multiplier")
	manager._finish_game()
	await tree.process_frame
	var panel: GameOverPanel = main.get_node("UI/Hud/GameOverPanel") as GameOverPanel
	var title: Label = panel.get_node("Margin/Content/ResultTitle") as Label
	var detail: Label = panel.get_node("Margin/Content/GameOverBlocked") as Label
	var survived: Label = panel.get_node("Margin/Content/SurvivedTimeLabel") as Label
	var result_chain: Label = panel.get_node("Margin/Content/GameOverMaxCombo") as Label
	var dimmer: ColorRect = main.get_node("UI/Hud/ResultDimmer") as ColorRect
	var panel_style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert_true(panel.visible, "time-up result panel visible")
	assert_true(dimmer.visible, "time-up dims the whole screen")
	assert_near(dimmer.color.a, 0.6, TOLERANCE, "time-up dim alpha")
	assert_true(panel_style != null, "time-up panel has a flat opaque style")
	if panel_style != null:
		assert_true(panel_style.bg_color.a >= 0.92, "time-up panel opacity")
	assert_eq(title.text, "TIME UP", "blitz result title")
	assert_eq(result_chain.text, "MAX CHAIN 1", "result uses maximum chain label")
	assert_eq(detail.text, "BLAST 0   FEVER 0", "blitz result counters")
	assert_true(survived.visible, "survival result shows elapsed time")
	assert_eq(survived.text, "버틴 시간 2:00", "survived time uses m:ss")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = original_mode
	Config.data.blitz_ready_time = original_ready_time


func _create_fixture(
	seed: int,
	initial_occupancy: float = 0.0,
	ready_time: float = 0.0
) -> Dictionary:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	Config.data.blitz_duration = 90.0
	Config.data.blitz_spawn_interval = 1000.0
	Config.data.blitz_initial_occupancy = initial_occupancy
	Config.data.blitz_ready_time = ready_time
	var root: Node = Node.new()
	root.name = "BlitzFixture"
	var board: Board = BOARD_SCENE.instantiate() as Board
	board.name = "Board"
	board.unique_name_in_owner = true
	root.add_child(board)
	board.owner = root
	var spawner: Spawner = SPAWNER_SCRIPT.new() as Spawner
	spawner.name = "Spawner"
	spawner.unique_name_in_owner = true
	root.add_child(spawner)
	spawner.owner = root
	var resolver: CollisionResolver = RESOLVER_SCRIPT.new() as CollisionResolver
	resolver.name = "CollisionResolver"
	resolver.unique_name_in_owner = true
	root.add_child(resolver)
	resolver.owner = root
	var score: ScoreManager = SCORE_SCRIPT.new() as ScoreManager
	score.name = "ScoreManager"
	score.unique_name_in_owner = true
	score.save_path = ""
	root.add_child(score)
	score.owner = root
	var manager: BlitzManager = BLITZ_SCRIPT.new() as BlitzManager
	manager.name = "BlitzManager"
	manager.unique_name_in_owner = true
	root.add_child(manager)
	manager.owner = root
	tree.root.add_child(root)
	await tree.process_frame
	spawner.set_blitz_mode(true)
	spawner.init_rng(seed)
	spawner.spawn_initial(board, Vector2i.DOWN)
	spawner.orb_spawned.connect(score.on_orb_spawned)
	manager.reaction_ready.connect(score.on_reaction)
	manager.start_game()
	manager.set_physics_process(false)
	return {
		"root": root,
		"board": board,
		"spawner": spawner,
		"resolver": resolver,
		"score": score,
		"manager": manager,
		"snapshot": snapshot,
	}


func _cleanup_fixture(fixture: Dictionary) -> void:
	InputRouter.set_locked(false)
	_restore_config(fixture["snapshot"] as Dictionary)
	(fixture["root"] as Node).queue_free()
	await tree.process_frame


func _reaction(type: ReactionRules.Type, level: int) -> Dictionary:
	var levels: Array[int] = [level, level]
	return {
		"type": type,
		"levels": levels,
		"result_level": mini(level + 1, Config.data.orb_max_level),
		"occupancy": 0.2,
	}


func _merge_result_reaction(result_level: int) -> Dictionary:
	var source_level: int = maxi(result_level - 1, 1)
	var levels: Array[int] = [source_level, source_level]
	return {
		"type": ReactionRules.Type.MERGE,
		"levels": levels,
		"result_level": result_level,
		"occupancy": 0.2,
	}


func _create_score_manager(path: String) -> ScoreManager:
	var manager: ScoreManager = SCORE_SCRIPT.new() as ScoreManager
	manager.save_path = path
	tree.root.add_child(manager)
	await tree.process_frame
	return manager


func _remove_test_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _snapshot_config() -> Dictionary:
	return {
		"game_mode": Config.data.game_mode,
		"blitz_duration": Config.data.blitz_duration,
		"blitz_survival_enabled": Config.data.blitz_survival_enabled,
		"blitz_drain_ramp_per_minute": Config.data.blitz_drain_ramp_per_minute,
		"blitz_spawn_on_swipe": Config.data.blitz_spawn_on_swipe,
		"blitz_min_spawn_per_swipe": Config.data.blitz_min_spawn_per_swipe,
		"blitz_max_spawn_per_swipe": Config.data.blitz_max_spawn_per_swipe,
		"blitz_spawn_interval": Config.data.blitz_spawn_interval,
		"blitz_initial_occupancy": Config.data.blitz_initial_occupancy,
		"blitz_target_occupancy": Config.data.blitz_target_occupancy,
		"blitz_refill_interval": Config.data.blitz_refill_interval,
		"blitz_ready_time": Config.data.blitz_ready_time,
		"blitz_finale_interval": Config.data.blitz_finale_interval,
		"blitz_swipe_cooldown": Config.data.blitz_swipe_cooldown,
		"blitz_swipe_buffer_enabled": Config.data.blitz_swipe_buffer_enabled,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.game_mode = snapshot["game_mode"] as GameConfig.GameMode
	Config.data.blitz_duration = float(snapshot["blitz_duration"])
	Config.data.blitz_survival_enabled = bool(snapshot["blitz_survival_enabled"])
	Config.data.blitz_drain_ramp_per_minute = float(
		snapshot["blitz_drain_ramp_per_minute"]
	)
	Config.data.blitz_spawn_on_swipe = bool(snapshot["blitz_spawn_on_swipe"])
	Config.data.blitz_min_spawn_per_swipe = int(snapshot["blitz_min_spawn_per_swipe"])
	Config.data.blitz_max_spawn_per_swipe = int(snapshot["blitz_max_spawn_per_swipe"])
	Config.data.blitz_spawn_interval = float(snapshot["blitz_spawn_interval"])
	Config.data.blitz_initial_occupancy = float(snapshot["blitz_initial_occupancy"])
	Config.data.blitz_target_occupancy = float(snapshot["blitz_target_occupancy"])
	Config.data.blitz_refill_interval = float(snapshot["blitz_refill_interval"])
	Config.data.blitz_ready_time = float(snapshot["blitz_ready_time"])
	Config.data.blitz_finale_interval = float(snapshot["blitz_finale_interval"])
	Config.data.blitz_swipe_cooldown = float(snapshot["blitz_swipe_cooldown"])
	Config.data.blitz_swipe_buffer_enabled = bool(snapshot["blitz_swipe_buffer_enabled"])


func _productive_swipe(manager: BlitzManager, direction: Vector2i) -> Dictionary:
	manager.on_swipe(direction)
	var reaction: Dictionary = _reaction(ReactionRules.Type.MERGE, 2)
	manager.on_reaction(reaction)
	return reaction


func _next_direction(current: Vector2i, index: int) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for direction: Vector2i in OrbTypes.DIRECTIONS:
		if direction != current:
			candidates.append(direction)
	return candidates[index % candidates.size()]


func _occupancy(board: Board) -> float:
	var occupied_area: float = 0.0
	for orb: Orb in board.get_orbs():
		var radius: float = Config.data.radius_for_level(orb.level)
		occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _clear_board(board: Board) -> void:
	for orb: Orb in board.get_orbs():
		board.remove_orb(orb)


func _add_level_orbs(board: Board, count: int, level: int) -> void:
	for index: int in range(count):
		board.spawn_orb(
			OrbTypes.OrbColor.RED,
			level,
			Vector2(float(index) * 2.0, 0.0)
		)


func _candidate_batch_occupancy(batch: Array) -> float:
	var occupied_area: float = 0.0
	for candidate: Dictionary in batch:
		var radius: float = Config.data.radius_for_level(int(candidate["level"]))
		occupied_area += PI * radius * radius
	return occupied_area / (Config.data.board_size * Config.data.board_size)


func _maximum_overlap(board: Board) -> float:
	var maximum: float = 0.0
	var orbs: Array[Orb] = board.get_orbs()
	for first_index: int in range(orbs.size()):
		for second_index: int in range(first_index + 1, orbs.size()):
			var first: Orb = orbs[first_index]
			var second: Orb = orbs[second_index]
			maximum = maxf(
				maximum,
				first.get_radius() + second.get_radius()
				- first.position.distance_to(second.position)
			)
	return maximum
