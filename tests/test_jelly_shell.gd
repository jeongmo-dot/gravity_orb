extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SAVE_PATH: String = "res://tests/test_jelly_shell.tmp.cfg"


func test_jelly_save_rankings_and_last_mode_are_separate() -> void:
	_remove_save()
	SaveStore.add_ranking(
		SAVE_PATH,
		GameConfig.GameMode.TURN,
		9000,
		{"max_combo": 3, "turns": 18, "max_level": 5},
		"2026-10-23 09:00"
	)
	var result: Dictionary = SaveStore.add_ranking(
		SAVE_PATH,
		GameConfig.GameMode.JELLY,
		12345,
		{"max_combo": 7, "turns": 42, "max_level": 6, "final_moves": 2},
		"2026-10-23 10:00"
	)
	assert_eq(int(result["rank"]), 1, "first JELLY result ranks first")
	var rankings: Array[Dictionary] = SaveStore.load_rankings(
		SAVE_PATH, GameConfig.GameMode.JELLY
	)
	assert_eq(rankings.size(), 1, "JELLY ranking has its own entry")
	assert_eq(int(rankings[0]["max_combo"]), 7, "JELLY ranking stores combo")
	assert_eq(int(rankings[0]["final_moves"]), 2, "JELLY ranking stores survived FINAL MOVEs")
	assert_eq(
		SaveStore.load_best_score(SAVE_PATH, GameConfig.GameMode.TURN),
		9000,
		"CLASSIC score remains separate"
	)
	assert_eq(
		SaveStore.ranking_key_for_mode(GameConfig.GameMode.JELLY),
		"jelly",
		"JELLY ranking key"
	)
	SaveStore.save_last_mode(SAVE_PATH, GameConfig.GameMode.JELLY)
	assert_eq(
		SaveStore.load_last_mode(SAVE_PATH, GameConfig.GameMode.TURN),
		GameConfig.GameMode.JELLY,
		"JELLY last mode round-trips"
	)
	_remove_save()


func test_jelly_start_card_and_ranking_tab() -> void:
	_remove_save()
	SaveStore.add_ranking(
		SAVE_PATH,
		GameConfig.GameMode.JELLY,
		9876,
		{"max_combo": 5, "turns": 31, "max_level": 5, "final_moves": 3},
		"2026-10-23 11:22"
	)
	var main: Main = _new_menu_main()
	tree.root.add_child(main)
	await tree.process_frame
	var start: StartScreen = main.get_node("UI/StartScreen") as StartScreen
	var jelly_button: Button = start.get_node("Content/JellyButton") as Button
	assert_eq((start.get_node("Content/JellyNameLabel") as Label).text, "JELLY", "JELLY card name")
	assert_eq(
		(start.get_node("Content/JellyDescriptionLabel") as Label).text,
		"작은 것도 먹고 자라요",
		"JELLY card description"
	)
	assert_eq((start.get_node("Content/JellyBestLabel") as Label).text, "BEST 9,876", "JELLY BEST")
	assert_true(jelly_button.size.y >= 88.0, "JELLY card is a touch target")
	var jelly_description: Label = start.get_node("Content/JellyDescriptionLabel") as Label
	assert_true(
		jelly_button.get_global_rect().encloses(jelly_description.get_global_rect()),
		"JELLY description stays inside its card: card=%s description=%s" % [
			jelly_button.get_global_rect(), jelly_description.get_global_rect()
		]
	)
	var slime_button: Button = start.get_node("Content/SlimeButton") as Button
	var slime_description: Label = start.get_node("Content/SlimeDescriptionLabel") as Label
	assert_eq(slime_description.text, "크기 상관없이 흡수", "SLIME card description")
	assert_eq(
		jelly_description.get_theme_font_size("font_size"),
		(start.get_node("Content/BlitzDescriptionLabel") as Label).get_theme_font_size("font_size"),
		"JELLY description matches upper-card font size"
	)
	assert_eq(
		slime_description.get_theme_font_size("font_size"),
		(start.get_node("Content/ClassicDescriptionLabel") as Label).get_theme_font_size("font_size"),
		"SLIME description matches upper-card font size"
	)
	assert_true(
		slime_button.get_global_rect().encloses(slime_description.get_global_rect()),
		"SLIME description stays inside its card: card=%s description=%s" % [
			slime_button.get_global_rect(), slime_description.get_global_rect()
		]
	)
	assert_true(
		(start.get_node("Content/JellyNameLabel") as Label).get_theme_color("font_color").is_equal_approx(
			Color("ff7595")
		),
		"JELLY card uses pink accent"
	)
	var ranking: RankingPanel = (main.get_node("UI") as DebugHud).ranking_panel()
	ranking.open(GameConfig.GameMode.JELLY, 1)
	await tree.process_frame
	assert_eq(ranking.current_mode(), GameConfig.GameMode.JELLY, "JELLY ranking tab opens")
	assert_eq(
		(ranking.get_node("Panel/Content/Rows/RankingRow1/Text/Columns/Stat") as Label).text,
		"콤보 5",
		"JELLY ranking keeps CLASSIC combo column"
	)
	assert_eq(
		(ranking.get_node("Panel/Content/Rows/RankingRow1/Text/Columns/Turns") as Label).text,
		"3",
		"JELLY ranking adds FINAL MOVE count"
	)
	main.queue_free()
	await tree.process_frame
	_remove_save()


func test_jelly_result_ranking_restart_and_mode_selection_round_trip() -> void:
	_remove_save()
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var main: Main = MAIN_SCENE.instantiate() as Main
	(main.get_node("ScoreManager") as ScoreManager).save_path = SAVE_PATH
	main.launch_immediately(GameConfig.GameMode.JELLY)
	tree.root.add_child(main)
	await tree.process_frame
	var manager: TurnManager = main.get_node("TurnManager") as TurnManager
	var score: ScoreManager = main.get_node("ScoreManager") as ScoreManager
	manager.turn_index = 44
	manager.max_combo = 6
	manager.final_move_count = 4
	manager.final_move_success_count = 3
	score.score = 34567
	score.best_score = 34567
	score.max_level_reached = 6
	manager.game_over_details = {
		"direction": Vector2i.LEFT,
		"final_moves": 4,
		"final_move_successes": 3,
	}
	manager.game_over_details["ranking"] = manager._commit_completed_ranking()
	manager.game_over.emit()
	await tree.create_timer(0.85).timeout
	var panel: GameOverPanel = main.get_node("UI/Hud/GameOverPanel") as GameOverPanel
	assert_true(panel.visible, "JELLY result opens")
	assert_eq((panel.get_node("Margin/Content/GameOverBlocked") as Label).text, "최고 젤리", "JELLY result level label")
	assert_eq((panel.get_node("Margin/Content/GameOverBlockedValue") as Label).text, "L6", "JELLY result non-MAX level")
	assert_eq((panel.get_node("Margin/Content/ResultExtraLabel") as Label).text, "FINAL MOVE", "result label")
	assert_eq((panel.get_node("Margin/Content/ResultExtraValue") as Label).text, "3번 버팀", "result survived count")
	score.max_level_reached = Config.data.orb_max_level
	panel._set_stat_text(false)
	assert_eq((panel.get_node("Margin/Content/GameOverBlockedValue") as Label).text, "L7 MAX", "JELLY result MAX level")
	assert_eq(
		SaveStore.load_rankings(SAVE_PATH, GameConfig.GameMode.JELLY).size(),
		1,
		"JELLY result saves once"
	)
	(panel.get_node("Margin/Content/ResultRankingButton") as Button).pressed.emit()
	await tree.create_timer(0.30).timeout
	var ranking: RankingPanel = (main.get_node("UI") as DebugHud).ranking_panel()
	assert_true(ranking.visible, "result opens ranking")
	assert_eq(ranking.current_mode(), GameConfig.GameMode.JELLY, "result opens JELLY tab")
	(ranking.get_node("Panel/Content/RankingCloseButton") as Button).pressed.emit()
	await tree.create_timer(0.30).timeout
	assert_true(panel.visible, "ranking close returns to result")
	var restart_count: Array[int] = [0]
	var restart_recorder: Callable = func() -> void: restart_count[0] += 1
	InputRouter.restart_requested.disconnect(Callable(main, "restart"))
	InputRouter.restart_requested.connect(restart_recorder)
	(panel.get_node("Margin/Content/RestartButton") as Button).pressed.emit()
	assert_eq(restart_count[0], 1, "JELLY restart uses shared request")
	InputRouter.restart_requested.disconnect(restart_recorder)
	panel.restore_actions_after_ranking()
	var mode_select_count: Array[int] = [0]
	var mode_select_recorder: Callable = func() -> void: mode_select_count[0] += 1
	panel.mode_select_requested.disconnect(Callable(main, "_show_mode_selection"))
	panel.mode_select_requested.connect(mode_select_recorder)
	(panel.get_node("Margin/Content/ModeSelectButton") as Button).pressed.emit()
	assert_eq(mode_select_count[0], 1, "JELLY mode selection uses shared request")
	main.queue_free()
	await tree.process_frame
	Config.data.game_mode = original_mode
	_remove_save()


func _new_menu_main() -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	(main.get_node("ScoreManager") as ScoreManager).save_path = SAVE_PATH
	main.set("_embedded_launch_mode", Main.NO_MODE)
	return main


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
