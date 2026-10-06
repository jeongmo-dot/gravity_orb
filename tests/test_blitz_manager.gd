extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SCORE_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const BLITZ_SCRIPT: Script = preload("res://scripts/core/BlitzManager.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const BEST_SAVE_PATH: String = "user://test_blitz_best.cfg"
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


func test_swipe_changes_gravity_immediately_with_cooldown_and_same_direction_ignore() -> void:
	var fixture: Dictionary = await _create_fixture(3101)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
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
	assert_eq(manager.gravity, Vector2i.RIGHT, "cooldown ignores rapid swipe")
	assert_eq(manager.spawn_count, 1, "cooldown rejection does not spawn")
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.spawn_count, 1, "same direction rejection does not spawn")
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.gravity, Vector2i.UP, "swipe after cooldown applies")
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.accepted_swipes, 2, "same direction ignored")
	assert_eq(manager.spawn_count, 2, "only accepted swipes spawn")
	await _cleanup_fixture(fixture)


func test_disabled_swipe_spawn_preserves_time_refill_and_blocked_tick() -> void:
	var fixture: Dictionary = await _create_fixture(3102)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	Config.data.blitz_spawn_on_swipe = false
	Config.data.blitz_spawn_interval = 0.8
	Config.data.blitz_refill_interval = 0.15
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
	await _cleanup_fixture(fixture)


func test_blocked_swipe_changes_gravity_without_consuming_next() -> void:
	var fixture: Dictionary = await _create_fixture(3105)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	var spawner: Spawner = fixture["spawner"] as Spawner
	manager.on_swipe(Vector2i.RIGHT)
	var waiting: Orb = board.get_orbs()[-1]
	waiting.enter_entrance_wait(waiting.position, manager.gravity)
	var next_before: Array[Dictionary] = spawner.peek_next()
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.gravity, Vector2i.UP, "blocked swipe still changes gravity")
	assert_eq(manager.accepted_swipes, 2, "blocked swipe remains accepted")
	assert_eq(manager.spawn_count, 1, "blocked entrance skips spawn")
	assert_eq(manager.skipped_spawn_ticks, 1, "blocked spawn is counted")
	assert_eq(spawner.peek_next(), next_before, "blocked spawn keeps NEXT")
	await _cleanup_fixture(fixture)


func test_speed_chain_productive_miss_idle_fever_and_time_bonus_cap() -> void:
	var fixture: Dictionary = await _create_fixture(3103)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
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
	for index: int in range(12):
		manager._physics_process(Config.data.blitz_swipe_cooldown)
		_productive_swipe(manager, _next_direction(manager.gravity, index))
	assert_eq(manager.chain, 12, "productive swipes build chain")
	assert_eq(manager.max_chain, 12, "maximum chain tracks board run")
	assert_eq(manager.fever_count, 2, "chain six and twelve trigger fever")
	assert_near(
		manager.fever_remaining,
		Config.data.blitz_fever_duration,
		TOLERANCE,
		"chain twelve refreshes fever"
	)
	var passive: Dictionary = _reaction(ReactionRules.Type.MERGE, 2)
	manager.on_reaction(passive)
	assert_eq(manager.chain, 12, "reaction without swipe does not raise chain")
	assert_eq(manager.passive_reaction_count, 1, "reaction without swipe is counted")
	assert_eq(bool(passive["productive_swipe"]), false, "reaction records passive state")
	assert_near(float(passive["combo_multiplier"]), 4.0, TOLERANCE, "passive reaction uses current chain")
	for index: int in range(4):
		manager._physics_process(Config.data.blitz_swipe_cooldown)
		_productive_swipe(manager, _next_direction(manager.gravity, index))
	assert_near(manager.current_combo_multiplier(), 5.0, TOLERANCE, "chain multiplier cap")
	manager._physics_process(Config.data.blitz_chain_idle)
	assert_eq(manager.chain, 0, "two seconds without swipe resets chain")
	for _index: int in range(25):
		manager.on_reaction(_reaction(ReactionRules.Type.BLAST, 4))
	manager.on_reaction(_reaction(ReactionRules.Type.MAX_CLEAR, 7))
	assert_near(manager.time_bonus_total, 20.0, TOLERANCE, "time bonus is capped")
	await _cleanup_fixture(fixture)


func test_time_up_locks_input_and_finale_blasts_largest_first() -> void:
	var fixture: Dictionary = await _create_fixture(3104)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	Config.data.blitz_duration = 0.05
	Config.data.blitz_finale_interval = 0.1
	board.spawn_orb(0, 4, Vector2(-180.0, 0.0)).exit_ghost_state()
	board.spawn_orb(1, 5, Vector2(180.0, 0.0)).exit_ghost_state()
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
	assert_eq(finale_levels, [5, 4], "finale orders large levels first")
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
	turn_score.queue_free()
	await tree.process_frame
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var blitz_score: ScoreManager = await _create_score_manager(BEST_SAVE_PATH)
	assert_eq(blitz_score.best_score, 0, "blitz does not load turn best")
	blitz_score.on_reaction(_reaction(ReactionRules.Type.MERGE, 4))
	var saved_blitz_best: int = blitz_score.best_score
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
	manager._physics_process(1.5)
	assert_eq(manager.state, BlitzManager.State.RUNNING, "main starts blitz after ready")
	manager.on_swipe(Vector2i.RIGHT)
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_eq(chain_label.text, "CHAIN 1 (x1.25)", "blitz HUD uses chain label")
	manager._finish_game()
	await tree.process_frame
	var panel: GameOverPanel = main.get_node("UI/Hud/GameOverPanel") as GameOverPanel
	var title: Label = panel.get_node("Margin/Content/ResultTitle") as Label
	var detail: Label = panel.get_node("Margin/Content/GameOverBlocked") as Label
	var result_chain: Label = panel.get_node("Margin/Content/GameOverMaxCombo") as Label
	assert_true(panel.visible, "time-up result panel visible")
	assert_eq(title.text, "TIME UP", "blitz result title")
	assert_eq(result_chain.text, "MAX CHAIN 1", "result uses maximum chain label")
	assert_eq(detail.text, "BLAST 0   FEVER 0", "blitz result counters")
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
		"blitz_spawn_on_swipe": Config.data.blitz_spawn_on_swipe,
		"blitz_spawn_interval": Config.data.blitz_spawn_interval,
		"blitz_initial_occupancy": Config.data.blitz_initial_occupancy,
		"blitz_target_occupancy": Config.data.blitz_target_occupancy,
		"blitz_refill_interval": Config.data.blitz_refill_interval,
		"blitz_ready_time": Config.data.blitz_ready_time,
		"blitz_finale_interval": Config.data.blitz_finale_interval,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.game_mode = snapshot["game_mode"] as GameConfig.GameMode
	Config.data.blitz_duration = float(snapshot["blitz_duration"])
	Config.data.blitz_spawn_on_swipe = bool(snapshot["blitz_spawn_on_swipe"])
	Config.data.blitz_spawn_interval = float(snapshot["blitz_spawn_interval"])
	Config.data.blitz_initial_occupancy = float(snapshot["blitz_initial_occupancy"])
	Config.data.blitz_target_occupancy = float(snapshot["blitz_target_occupancy"])
	Config.data.blitz_refill_interval = float(snapshot["blitz_refill_interval"])
	Config.data.blitz_ready_time = float(snapshot["blitz_ready_time"])
	Config.data.blitz_finale_interval = float(snapshot["blitz_finale_interval"])


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
