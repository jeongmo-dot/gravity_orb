extends TestCase

const SLIME_SCENE: PackedScene = preload("res://scenes/SlimeMain.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SAVE_PATH: String = "res://tests/test_slime_shell.tmp.cfg"


func test_slime_save_rankings_records_last_mode_and_corruption_fallback() -> void:
	_remove_save()
	var first: Dictionary = SaveStore.add_ranking(
		SAVE_PATH,
		GameConfig.GameMode.SLIME,
		12345,
		{"turns": 18, "max_chain": 4, "max_colors": 3},
		"2026-10-17 10:00"
	)
	SaveStore.add_ranking(
		SAVE_PATH,
		GameConfig.GameMode.SLIME,
		11000,
		{"turns": 25, "max_chain": 7, "max_colors": 5},
		"2026-10-17 10:01"
	)
	assert_eq(int(first["rank"]), 1, "first SLIME result ranks first")
	var rankings: Array[Dictionary] = SaveStore.load_rankings(
		SAVE_PATH, GameConfig.GameMode.SLIME
	)
	assert_eq(rankings.size(), 2, "SLIME ranking keeps entries")
	assert_eq(int(rankings[0]["turns"]), 18, "SLIME ranking stores turns")
	assert_eq(int(rankings[0]["max_chain"]), 4, "SLIME ranking stores chain")
	assert_eq(int(rankings[0]["max_colors"]), 3, "SLIME ranking stores MAX colors")
	var records: Dictionary = SaveStore.load_slime_records(SAVE_PATH)
	assert_eq(int(records["score"]), 12345, "SLIME all-time score")
	assert_eq(int(records["turns"]), 25, "SLIME all-time turns")
	assert_eq(int(records["max_chain"]), 7, "SLIME all-time chain")
	for index: int in range(10):
		SaveStore.add_ranking(
			SAVE_PATH,
			GameConfig.GameMode.SLIME,
			30000 - index * 1000,
			{"turns": 20 + index, "max_chain": 3, "max_colors": 4},
			"2026-10-17 12:%02d" % index
		)
	var outside: Dictionary = SaveStore.add_ranking(
		SAVE_PATH,
		GameConfig.GameMode.SLIME,
		1,
		{"turns": 99, "max_chain": 12, "max_colors": 6},
		"2026-10-17 12:30"
	)
	assert_eq(int(outside["rank"]), 0, "outside TOP 10 is not ranked")
	records = SaveStore.load_slime_records(SAVE_PATH)
	assert_eq(int(records["turns"]), 99, "all-time turns include unranked games")
	assert_eq(int(records["max_chain"]), 12, "all-time chain includes unranked games")
	SaveStore.save_last_mode(SAVE_PATH, GameConfig.GameMode.SLIME)
	assert_eq(
		SaveStore.load_last_mode(SAVE_PATH, GameConfig.GameMode.TURN),
		GameConfig.GameMode.SLIME,
		"SLIME last mode round-trips"
	)

	var corrupt: ConfigFile = ConfigFile.new()
	corrupt.set_value("rankings", "slime", [{"score": "broken"}])
	corrupt.set_value("records", "slime_best_score", "broken")
	corrupt.set_value("records", "slime_best_turns", -9)
	corrupt.set_value("records", "slime_best_chain", "broken")
	corrupt.save(SAVE_PATH)
	assert_true(
		SaveStore.load_rankings(SAVE_PATH, GameConfig.GameMode.SLIME).is_empty(),
		"corrupt SLIME ranking falls back to empty"
	)
	records = SaveStore.load_slime_records(SAVE_PATH)
	assert_eq(records, {"score": 0, "turns": 0, "max_chain": 0}, "corrupt records become zero")
	_remove_save()


func test_start_card_and_ranking_panel_expose_slime_mode() -> void:
	_remove_save()
	SaveStore.add_ranking(
		SAVE_PATH,
		GameConfig.GameMode.SLIME,
		9876,
		{"turns": 31, "max_chain": 6, "max_colors": 4},
		"2026-10-17 11:22"
	)
	var main: Main = MAIN_SCENE.instantiate() as Main
	(main.get_node("ScoreManager") as ScoreManager).save_path = SAVE_PATH
	main.set("_embedded_launch_mode", Main.NO_MODE)
	tree.root.add_child(main)
	await tree.process_frame
	var start: StartScreen = main.get_node("UI/StartScreen") as StartScreen
	var slime_button: Button = start.get_node("Content/SlimeButton") as Button
	assert_eq((start.get_node("Content/SlimeNameLabel") as Label).text, "SLIME", "SLIME card name")
	assert_eq(
		(start.get_node("Content/SlimeDescriptionLabel") as Label).text,
		"크기 상관없이 흡수",
		"SLIME card description"
	)
	assert_eq((start.get_node("Content/SlimeBestLabel") as Label).text, "BEST 9,876", "SLIME card BEST")
	assert_true(slime_button.size.y >= 88.0, "SLIME card is a touch target")
	var ranking: RankingPanel = (main.get_node("UI") as DebugHud).ranking_panel()
	ranking.open(GameConfig.GameMode.SLIME, 1)
	await tree.process_frame
	assert_eq(ranking.current_mode(), GameConfig.GameMode.SLIME, "SLIME ranking tab opens")
	assert_eq(
		(ranking.get_node("Panel/Content/Rows/RankingRow1/Text/Columns/Turns") as Label).text,
		"31",
		"SLIME ranking shows turns"
	)
	assert_eq(
		(ranking.get_node("Panel/Content/Rows/RankingRow1/Text/Columns/Max") as Label).text,
		"4/7",
		"SLIME ranking shows MAX"
	)
	main.queue_free()
	await tree.process_frame
	_remove_save()


func test_slime_result_commits_once_and_round_trips_ranking() -> void:
	_remove_save()
	var game: SlimeGame = SLIME_SCENE.instantiate() as SlimeGame
	game.save_path = SAVE_PATH
	tree.root.add_child(game)
	await tree.process_frame
	var sim: SlimeSim = game.get_sim()
	sim.score = 45678
	sim.turn = 42
	sim.run_best_chain = 8
	sim.completed_colors = {0: true, 2: true, 4: true}
	sim.game_over = true
	game._commit_game_over_once()
	game._commit_game_over_once()
	await tree.create_timer(0.85).timeout
	var rankings: Array[Dictionary] = SaveStore.load_rankings(
		SAVE_PATH, GameConfig.GameMode.SLIME
	)
	assert_eq(rankings.size(), 1, "game over saves exactly once")
	var panel: GameOverPanel = game.game_over_panel()
	assert_true(panel.visible, "shared GameOverPanel opens after feedback")
	assert_eq((panel.get_node("Margin/Content/SurvivedTimeValue") as Label).text, "42", "result turn")
	assert_eq((panel.get_node("Margin/Content/GameOverMaxComboValue") as Label).text, "8", "result chain")
	assert_eq((panel.get_node("Margin/Content/GameOverBlockedValue") as Label).text, "3/7", "result MAX")
	(panel.get_node("Margin/Content/ResultRankingButton") as Button).pressed.emit()
	await tree.create_timer(0.30).timeout
	assert_true(game.ranking_panel().visible, "result opens SLIME ranking")
	(game.ranking_panel().get_node("Panel/Content/RankingCloseButton") as Button).pressed.emit()
	await tree.create_timer(0.30).timeout
	assert_true(panel.visible, "ranking close returns to result")
	var restart_count: Array[int] = [0]
	var restart_recorder: Callable = func() -> void: restart_count[0] += 1
	InputRouter.restart_requested.disconnect(Callable(game, "_on_restart_requested"))
	InputRouter.restart_requested.connect(restart_recorder)
	(panel.get_node("Margin/Content/RestartButton") as Button).pressed.emit()
	assert_eq(restart_count[0], 1, "result retry requests SLIME reload")
	InputRouter.restart_requested.disconnect(restart_recorder)
	panel.restore_actions_after_ranking()
	var mode_select_count: Array[int] = [0]
	var mode_select_recorder: Callable = func() -> void: mode_select_count[0] += 1
	panel.mode_select_requested.disconnect(Callable(game, "_on_mode_select_requested"))
	panel.mode_select_requested.connect(mode_select_recorder)
	(panel.get_node("Margin/Content/ModeSelectButton") as Button).pressed.emit()
	assert_eq(mode_select_count[0], 1, "result mode select returns through shared signal")
	game.queue_free()
	await tree.process_frame
	_remove_save()


func test_slime_turn_indicator_and_haptics_follow_busy_ready_rejected_states() -> void:
	_remove_save()
	var game: SlimeGame = SLIME_SCENE.instantiate() as SlimeGame
	game.save_path = SAVE_PATH
	tree.root.add_child(game)
	await tree.process_frame
	var sim: SlimeSim = game.get_sim()
	var indicator: TurnInputIndicator = game.turn_input_indicator()
	assert_true(indicator.is_busy_cue(), "initial admission shows busy cue")
	assert_true(not indicator.uses_direction_arrows(), "SLIME suppresses direction arrows")
	var viewport_size: Vector2 = tree.root.get_visible_rect().size
	var expected_orbit_rect := Rect2(
		(viewport_size - SlimeGame.CONTENT_SIZE * SlimeGame.CONTENT_SCALE) * 0.5
			+ sim.config.board_rect.position * SlimeGame.CONTENT_SCALE,
		sim.config.board_rect.size * SlimeGame.CONTENT_SCALE
	)
	assert_eq(
		indicator.orbit_path_rect(indicator._projected_board_rect()),
		expected_orbit_rect,
		"SLIME orbit light follows the board border without outside growth"
	)
	var safety: int = 0
	while sim.moving and safety < 300:
		game.advance_elapsed(1.0 / 60.0)
		safety += 1
	assert_true(indicator.is_ready_cue(), "settled SLIME shows ready cue")
	assert_eq(game.haptics().last_duration_ms(), 5, "ready cue requests 5ms haptic")
	for direction: Vector2i in SlimeSim.DIRECTIONS:
		assert_true(
			indicator.arrow_color(direction).is_equal_approx(TurnInputIndicator.READY_COLOR),
			"SLIME never uses blocked arrows"
		)
	InputRouter.swipe.emit(Vector2i.LEFT)
	assert_true(indicator.is_busy_cue(), "accepted swipe shows busy cue")
	assert_eq(game.haptics().last_duration_ms(), 8, "accepted swipe requests 8ms haptic")
	var rejected_before: int = indicator.rejection_flash_count()
	InputRouter.swipe_rejected.emit(Vector2i.UP)
	assert_eq(
		indicator.rejection_flash_count(),
		rejected_before + 1,
		"busy swipe shows rejected flash"
	)
	var rejected_color: Color = indicator.current_border_color()
	assert_near(rejected_color.r, TurnInputIndicator.REJECTED_COLOR.r, 0.001, "rejected border red")
	assert_near(rejected_color.g, TurnInputIndicator.REJECTED_COLOR.g, 0.001, "rejected border green")
	assert_near(rejected_color.b, TurnInputIndicator.REJECTED_COLOR.b, 0.001, "rejected border blue")
	assert_eq(indicator.rejected_direction(), Vector2i.ZERO, "SLIME rejection has no arrow")
	game.sound_button().pressed.emit()
	assert_true(SaveStore.load_sfx_muted(SAVE_PATH), "SLIME sound button shares saved mute")
	game.queue_free()
	await tree.process_frame
	_remove_save()


func test_slime_orbit_progress_uses_lock_clock_and_never_rewinds() -> void:
	_remove_save()
	var game: SlimeGame = SLIME_SCENE.instantiate() as SlimeGame
	game.save_path = SAVE_PATH
	tree.root.add_child(game)
	await tree.process_frame
	game.set_physics_process(false)
	var sim: SlimeSim = game.get_sim()
	var indicator: TurnInputIndicator = game.turn_input_indicator()
	var entries: Array[Dictionary] = [
		{"delay": 0.0},
		{"delay": 0.3},
		{"delay": 0.6},
	]
	sim.intro_queue.assign(entries)
	sim.moving = true
	sim.intro_elapsed = 0.0
	sim.simulation_elapsed = 0.0
	game._begin_lock_orbit_clock()
	game._sync_input_lock()
	assert_near(indicator.orbit_progress(), 0.0, 0.001, "three-entry turn starts at zero")

	sim.intro_elapsed = 0.6
	game._sync_input_lock()
	var queue_empty_progress: float = 0.6 / (0.6 + sim.config.max_simulation_time)
	assert_near(
		indicator.orbit_progress(),
		queue_empty_progress,
		0.001,
		"scheduled final entry reaches the expected progress"
	)
	sim.intro_queue.clear()
	game._sync_input_lock()
	assert_near(
		indicator.orbit_progress(),
		queue_empty_progress,
		0.001,
		"queue-empty moment preserves progress"
	)
	sim.simulation_elapsed = sim.config.max_simulation_time
	game._sync_input_lock()
	assert_near(indicator.orbit_progress(), 1.0, 0.001, "lock cap completes one orbit")

	sim.moving = false
	game._sync_input_lock()
	sim.moving = true
	sim.intro_queue.assign(entries)
	sim.intro_elapsed = 1.0
	sim.simulation_elapsed = 0.0
	game._begin_lock_orbit_clock()
	game._sync_input_lock()
	var delayed_progress: float = indicator.orbit_progress()
	game._sync_input_lock()
	assert_near(
		indicator.orbit_progress(),
		delayed_progress,
		0.001,
		"repeating the same busy state does not reset progress"
	)
	sim.intro_queue.clear()
	game._sync_input_lock()
	assert_true(
		indicator.orbit_progress() >= delayed_progress,
		"actual delayed queue-empty time does not rewind progress"
	)

	sim.moving = false
	game._sync_input_lock()
	sim.moving = true
	sim.intro_elapsed = 0.0
	sim.simulation_elapsed = sim.config.max_simulation_time * 0.5
	sim.intro_queue.clear()
	game._begin_lock_orbit_clock()
	game._sync_input_lock()
	assert_near(indicator.orbit_progress(), 0.5, 0.001, "FINAL MOVE uses simulation clock")
	game.queue_free()
	await tree.process_frame
	_remove_save()


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
