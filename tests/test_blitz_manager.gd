extends TestCase

const BOARD_SCENE: PackedScene = preload("res://scenes/Board.tscn")
const SPAWNER_SCRIPT: Script = preload("res://scripts/core/Spawner.gd")
const RESOLVER_SCRIPT: Script = preload("res://scripts/core/CollisionResolver.gd")
const SCORE_SCRIPT: Script = preload("res://scripts/core/ScoreManager.gd")
const BLITZ_SCRIPT: Script = preload("res://scripts/core/BlitzManager.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const BEST_SAVE_PATH: String = "user://test_blitz_best.cfg"
const TOLERANCE: float = 0.001


func test_swipe_changes_gravity_immediately_with_cooldown_and_same_direction_ignore() -> void:
	var fixture: Dictionary = await _create_fixture(3101)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	manager.on_swipe(Vector2i.RIGHT)
	assert_eq(manager.gravity, Vector2i.RIGHT, "first swipe applies immediately")
	assert_eq(manager.accepted_swipes, 1, "first swipe accepted")
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.gravity, Vector2i.RIGHT, "cooldown ignores rapid swipe")
	manager._physics_process(Config.data.blitz_swipe_cooldown)
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.gravity, Vector2i.UP, "swipe after cooldown applies")
	manager.on_swipe(Vector2i.UP)
	assert_eq(manager.accepted_swipes, 2, "same direction ignored")
	await _cleanup_fixture(fixture)


func test_time_spawn_uses_blitz_weights_and_skips_blocked_entrance_tick() -> void:
	var fixture: Dictionary = await _create_fixture(3102)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var board: Board = fixture["board"] as Board
	Config.data.blitz_spawn_interval = 0.5
	var initial_count: int = board.get_orbs().size()
	manager._physics_process(Config.data.blitz_spawn_interval)
	assert_eq(manager.spawn_count, 1, "first interval spawns one")
	assert_eq(board.get_orbs().size(), initial_count + 1, "one orb entered board")
	var waiting: Orb = board.get_orbs()[0]
	waiting.enter_entrance_wait(waiting.position, manager.gravity)
	manager._physics_process(Config.data.blitz_spawn_interval)
	assert_eq(manager.spawn_count, 1, "blocked interval does not accumulate spawn")
	assert_eq(manager.skipped_spawn_ticks, 1, "blocked interval counted once")
	waiting.exit_ghost_state()
	manager._physics_process(Config.data.blitz_spawn_interval)
	assert_eq(manager.spawn_count, 2, "next clear interval spawns once")
	var preview: Array = (fixture["spawner"] as Spawner).peek_preview()
	assert_eq(preview.size(), 2, "blitz keeps NEXT and THEN")
	assert_eq((preview[0] as Array).size(), 1, "NEXT is one timed spawn")
	assert_eq((preview[1] as Array).size(), 1, "THEN is one timed spawn")
	await _cleanup_fixture(fixture)


func test_speed_combo_window_multiplier_cap_fever_and_time_bonuses() -> void:
	var fixture: Dictionary = await _create_fixture(3103)
	var manager: BlitzManager = fixture["manager"] as BlitzManager
	var first: Dictionary = _reaction(ReactionRules.Type.MERGE, 2)
	manager.on_reaction(first)
	manager._physics_process(1.0)
	var second: Dictionary = _reaction(ReactionRules.Type.MERGE, 2)
	manager.on_reaction(second)
	assert_eq(manager.turn_combo, 2, "reaction inside window continues combo")
	assert_near(float(second["combo_multiplier"]), 1.2, TOLERANCE, "combo step")
	for _index: int in range(6):
		manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_eq(manager.turn_combo, 8, "fever threshold reached")
	assert_eq(manager.fever_count, 1, "first fever counted")
	assert_true(manager.fever_remaining > 0.0, "fever active")
	var fever_reaction: Dictionary = _reaction(ReactionRules.Type.MERGE, 2)
	manager.on_reaction(fever_reaction)
	assert_true(bool(fever_reaction["fever"]), "fever flag reaches score manager")
	manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_near(manager.time_bonus_total, 2.0, TOLERANCE, "combo ten adds two seconds")
	manager.on_reaction(_reaction(ReactionRules.Type.BLAST, 4))
	manager.on_reaction(_reaction(ReactionRules.Type.MAX_CLEAR, 7))
	assert_near(manager.time_bonus_total, 10.0, TOLERANCE, "all three bonuses add")
	for _index: int in range(20):
		manager.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_near(manager.current_combo_multiplier(), 5.0, TOLERANCE, "combo multiplier cap")
	manager._physics_process(Config.data.blitz_fever_duration)
	assert_near(manager.fever_remaining, 0.0, TOLERANCE, "fever expires")
	assert_near(manager.fever_total_time, 6.0, TOLERANCE, "fever active time accumulated")
	manager._physics_process(Config.data.blitz_combo_window + 0.01)
	assert_eq(manager.turn_combo, 0, "combo resets after empty window")
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
	manager._physics_process(0.1)
	manager._physics_process(0.1)
	assert_eq(finale_levels, [5, 4], "finale orders large levels first")
	manager._physics_process(Config.data.blitz_combo_window + 0.01)
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
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	var main: Main = MAIN_SCENE.instantiate() as Main
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	score.save_path = ""
	tree.root.add_child(main)
	await tree.process_frame
	var manager: BlitzManager = main.get_node("BlitzManager") as BlitzManager
	var turn_manager: TurnManager = main.get_node("TurnManager") as TurnManager
	assert_eq(manager.state, BlitzManager.State.RUNNING, "main starts blitz manager")
	assert_true(not turn_manager.is_physics_processing(), "turn manager disabled in blitz")
	assert_true(
		InputRouter.debug_toggle_game_mode.is_connected(Callable(main, "_toggle_game_mode")),
		"F4 toggle is bound to main restart path"
	)
	var timer_label: Label = main.get_node("UI/Hud/TimerLabel") as Label
	var blocked_label: Label = main.get_node("UI/Hud/BlockedLabel") as Label
	assert_true(timer_label.visible, "blitz timer is visible")
	assert_true(not blocked_label.visible, "turn blocked label is hidden")
	manager._finish_game()
	await tree.process_frame
	var panel: GameOverPanel = main.get_node("UI/Hud/GameOverPanel") as GameOverPanel
	var title: Label = panel.get_node("Margin/Content/ResultTitle") as Label
	var detail: Label = panel.get_node("Margin/Content/GameOverBlocked") as Label
	assert_true(panel.visible, "time-up result panel visible")
	assert_eq(title.text, "TIME UP", "blitz result title")
	assert_eq(detail.text, "BLAST 0   FEVER 0", "blitz result counters")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = original_mode


func _create_fixture(seed: int) -> Dictionary:
	var snapshot: Dictionary = _snapshot_config()
	Config.data.game_mode = GameConfig.GameMode.BLITZ
	Config.data.blitz_duration = 90.0
	Config.data.blitz_spawn_interval = 1000.0
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
		"blitz_spawn_interval": Config.data.blitz_spawn_interval,
		"blitz_finale_interval": Config.data.blitz_finale_interval,
	}


func _restore_config(snapshot: Dictionary) -> void:
	Config.data.game_mode = snapshot["game_mode"] as GameConfig.GameMode
	Config.data.blitz_duration = float(snapshot["blitz_duration"])
	Config.data.blitz_spawn_interval = float(snapshot["blitz_spawn_interval"])
	Config.data.blitz_finale_interval = float(snapshot["blitz_finale_interval"])
