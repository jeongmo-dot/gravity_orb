extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SAVE_PATH: String = "res://tests/test_rankings.tmp.cfg"


func test_rankings_sort_ties_cap_and_sync_best() -> void:
	_remove_save()
	var scores: Array[int] = [500, 700, 700, 1000, 900, 800, 600, 400, 300, 200, 100]
	var last_result: Dictionary = {}
	for index: int in range(scores.size()):
		last_result = SaveStore.add_ranking(
			SAVE_PATH,
			GameConfig.GameMode.BLITZ,
			scores[index],
			{"max_chain": index, "blasts": index + 1, "fevers": index + 2},
			"2026-10-09 12:%02d" % index
		)
	var rankings: Array[Dictionary] = SaveStore.load_rankings(
		SAVE_PATH,
		GameConfig.GameMode.BLITZ
	)
	assert_eq(rankings.size(), 10, "ranking keeps ten entries")
	assert_eq(
		_ranking_scores(rankings),
		[1000, 900, 800, 700, 700, 600, 500, 400, 300, 200],
		"scores sort descending and discard eleventh"
	)
	assert_eq(str(rankings[3]["date"]), "2026-10-09 12:01", "older equal score stays first")
	assert_eq(str(rankings[4]["date"]), "2026-10-09 12:02", "new equal score stays below")
	assert_eq(int(last_result["rank"]), 0, "eleventh-place score reports outside ranking")
	assert_eq(
		SaveStore.load_best_score(SAVE_PATH, GameConfig.GameMode.BLITZ),
		1000,
		"BEST matches first place"
	)
	_remove_save()


func test_legacy_best_migrates_and_corrupt_entries_are_skipped() -> void:
	_remove_save()
	var legacy: ConfigFile = ConfigFile.new()
	legacy.set_value("records", "best_score", 777)
	assert_eq(legacy.save(SAVE_PATH), OK, "legacy fixture saved")
	var migrated: Array[Dictionary] = SaveStore.load_rankings(
		SAVE_PATH,
		GameConfig.GameMode.TURN
	)
	assert_eq(migrated.size(), 1, "legacy BEST becomes one ranking")
	assert_eq(int(migrated[0]["score"]), 777, "legacy score preserved")
	assert_eq(str(migrated[0]["date"]), "-", "legacy date is unknown")
	assert_eq(int(migrated[0]["max_combo"]), 0, "legacy missing stat defaults to zero")
	var persisted: ConfigFile = ConfigFile.new()
	assert_eq(persisted.load(SAVE_PATH), OK, "migrated file reloads")
	assert_true(persisted.has_section_key("rankings", "turn"), "migration is persisted")

	var valid_entry: Dictionary = {
		"score": 420,
		"date": "2026-10-09 13:00",
		"max_combo": 4,
		"turns": 33,
		"max_level": 5,
	}
	persisted.set_value("rankings", "turn", [
		valid_entry,
		{"score": "bad", "date": "-", "max_combo": 1, "turns": 1, "max_level": 1},
		{"score": 300, "date": "-", "max_combo": 1},
		{"score": 250, "date": "2026-13-40 25:99", "max_combo": 1, "turns": 1, "max_level": 1},
		42,
	])
	assert_eq(persisted.save(SAVE_PATH), OK, "corrupt fixture saved")
	var recovered: Array[Dictionary] = SaveStore.load_rankings(
		SAVE_PATH,
		GameConfig.GameMode.TURN
	)
	assert_eq(recovered.size(), 1, "valid ranking survives corrupt neighbors")
	assert_eq(recovered[0], valid_entry, "valid ranking fields stay intact")
	_remove_save()


func test_abandoned_game_is_not_recorded_and_completed_fields_are_saved() -> void:
	_remove_save()
	var abandoned: ScoreManager = await _create_score_manager(SAVE_PATH)
	abandoned.on_reaction(_reaction(ReactionRules.Type.MERGE, 2))
	assert_true(abandoned.best_score > 0, "active run updates in-memory BEST")
	abandoned.queue_free()
	await tree.process_frame
	assert_true(
		SaveStore.load_rankings(SAVE_PATH, GameConfig.GameMode.TURN).is_empty(),
		"abandoned run creates no ranking"
	)
	assert_eq(
		SaveStore.load_best_score(SAVE_PATH, GameConfig.GameMode.TURN),
		0,
		"abandoned run does not persist BEST"
	)

	var completed: ScoreManager = await _create_score_manager(SAVE_PATH)
	completed.score = 321
	completed.best_score = 321
	completed.max_level_reached = 6
	var result: Dictionary = completed.commit_ranking(
		GameConfig.GameMode.TURN,
		{"max_combo": 7, "turns": 88, "max_level": 6},
		"2026-10-09 14:15"
	)
	assert_eq(int(result["rank"]), 1, "completed run reaches first place")
	var turn_record: Dictionary = SaveStore.load_rankings(
		SAVE_PATH,
		GameConfig.GameMode.TURN
	)[0]
	assert_eq(int(turn_record["score"]), 321, "turn score saved")
	assert_eq(int(turn_record["max_combo"]), 7, "turn max combo saved")
	assert_eq(int(turn_record["turns"]), 88, "turn count saved")
	assert_eq(int(turn_record["max_level"]), 6, "turn max level saved")
	completed.queue_free()
	await tree.process_frame
	_remove_save()


func test_turn_and_blitz_managers_commit_mode_specific_finished_fields() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	_remove_save()
	var turn_main: Main = _new_main(SAVE_PATH)
	turn_main.launch_immediately(GameConfig.GameMode.TURN)
	tree.root.add_child(turn_main)
	await tree.process_frame
	var turn_manager: TurnManager = turn_main.get_node("TurnManager") as TurnManager
	var turn_score: ScoreManager = turn_main.get_node("ScoreManager") as ScoreManager
	turn_manager.set_physics_process(false)
	turn_manager.turn_index = 42
	turn_manager.max_combo = 6
	turn_score.score = 1234
	turn_score.best_score = 1234
	turn_score.max_level_reached = 5
	var turn_result: Dictionary = turn_manager._commit_completed_ranking()
	assert_eq(int(turn_result["rank"]), 1, "turn manager commits completed run")
	var turn_record: Dictionary = SaveStore.load_rankings(
		SAVE_PATH,
		GameConfig.GameMode.TURN
	)[0]
	assert_eq(int(turn_record["max_combo"]), 6, "turn manager max combo field")
	assert_eq(int(turn_record["turns"]), 42, "turn manager turn field")
	assert_eq(int(turn_record["max_level"]), 5, "turn manager max level field")
	await _cleanup_main(turn_main)

	var blitz_main: Main = _new_main(SAVE_PATH)
	blitz_main.launch_immediately(GameConfig.GameMode.BLITZ)
	tree.root.add_child(blitz_main)
	await tree.process_frame
	var blitz_manager: BlitzManager = blitz_main.get_node("BlitzManager") as BlitzManager
	var blitz_score: ScoreManager = blitz_main.get_node("ScoreManager") as ScoreManager
	blitz_manager.set_physics_process(false)
	blitz_manager.max_combo = 12
	blitz_manager.blast_count = 4
	blitz_manager.fever_count = 3
	blitz_score.score = 5678
	blitz_score.best_score = 5678
	var blitz_result: Dictionary = blitz_manager._commit_completed_ranking()
	assert_eq(int(blitz_result["rank"]), 1, "BLITZ manager commits completed run")
	var blitz_record: Dictionary = SaveStore.load_rankings(
		SAVE_PATH,
		GameConfig.GameMode.BLITZ
	)[0]
	assert_eq(int(blitz_record["max_chain"]), 12, "BLITZ max chain field")
	assert_eq(int(blitz_record["blasts"]), 4, "BLITZ blast field")
	assert_eq(int(blitz_record["fevers"]), 3, "BLITZ fever field")
	await _cleanup_main(blitz_main)
	Config.data.game_mode = original_mode
	_remove_save()


func test_ranking_screen_tabs_rows_highlight_and_touch_filters() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	_remove_save()
	SaveStore.save_last_mode(SAVE_PATH, GameConfig.GameMode.BLITZ)
	for index: int in range(4):
		SaveStore.add_ranking(
			SAVE_PATH,
			GameConfig.GameMode.BLITZ,
			4000 - index * 500,
			{"max_chain": 12 - index, "blasts": 4, "fevers": 2},
			"2026-10-09 1%d:0%d" % [index, index]
		)
	var main: Main = _new_main(SAVE_PATH)
	tree.root.add_child(main)
	await tree.process_frame
	var ui: DebugHud = main.get_node("UI") as DebugHud
	var start: StartScreen = ui.start_screen()
	var ranking: RankingPanel = ui.ranking_panel()
	var start_button: Button = start.get_node("Content/StartRankingButton") as Button
	assert_true(start_button.size.y >= 120.0, "start ranking touch target")
	assert_eq(start_button.mouse_filter, Control.MOUSE_FILTER_STOP, "ranking button consumes pointer")
	assert_eq(ranking.mouse_filter, Control.MOUSE_FILTER_IGNORE, "ranking background passes pointer")
	start_button.pressed.emit()
	assert_true(ranking.visible, "start ranking button opens panel")
	assert_eq(ranking.current_mode(), GameConfig.GameMode.BLITZ, "last selected mode opens first")
	var first_rank: Label = ranking.get_node(
		"Panel/Content/Rows/RankingRow1/Text/Columns/Rank"
	) as Label
	var first_score: Label = ranking.get_node(
		"Panel/Content/Rows/RankingRow1/Text/Columns/Score"
	) as Label
	var second_rank: Label = ranking.get_node(
		"Panel/Content/Rows/RankingRow2/Text/Columns/Rank"
	) as Label
	var fourth_row: PanelContainer = ranking.get_node("Panel/Content/Rows/RankingRow4") as PanelContainer
	assert_eq(first_score.text, "4,000", "ranking row shows formatted score")
	assert_true(first_rank.get_theme_color("font_color") != second_rank.get_theme_color("font_color"), "top ranks use distinct colors")
	_assert_ranking_columns_align(ranking)
	_assert_mode_selection_styles_match(start, ranking)
	ui.show_ranking(GameConfig.GameMode.BLITZ, 4)
	assert_eq(ranking.highlighted_rank(), 4, "latest ranked row is highlighted")
	assert_true(
		fourth_row.get_theme_stylebox("panel") == ranking.highlight_style,
		"highlight row uses bright border style"
	)
	(ranking.get_node("Panel/Content/Tabs/RankingClassicTab") as Button).pressed.emit()
	assert_eq(ranking.current_mode(), GameConfig.GameMode.TURN, "CLASSIC tab switches mode")
	assert_eq(ranking.highlighted_rank(), 0, "highlight stays with recorded mode")
	var empty_rank: Label = ranking.get_node(
		"Panel/Content/Rows/RankingRow1/Text/Columns/Rank"
	) as Label
	var empty_score: Label = ranking.get_node(
		"Panel/Content/Rows/RankingRow1/Text/Columns/Score"
	) as Label
	assert_eq(empty_rank.text, "1", "empty row keeps rank in rank column")
	assert_eq(empty_score.text, "—", "empty row puts dash in score column")
	_assert_ranking_columns_align(ranking)
	var close_button: Button = ranking.get_node("Panel/Content/RankingCloseButton") as Button
	assert_true(close_button.size.y >= 120.0, "close touch target")
	close_button.pressed.emit()
	assert_true(start.visible, "close returns to previous start screen")
	await _cleanup_main(main)
	Config.data.game_mode = original_mode
	_remove_save()


func test_result_panel_rank_messages_buttons_and_ranking_highlight() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	_remove_save()
	var main: Main = _new_main(SAVE_PATH)
	main.launch_immediately(GameConfig.GameMode.BLITZ)
	tree.root.add_child(main)
	await tree.process_frame
	var manager: BlitzManager = main.get_node("BlitzManager") as BlitzManager
	manager.set_physics_process(false)
	var panel: GameOverPanel = main.get_node("UI/Hud/GameOverPanel") as GameOverPanel
	var rank_label: Label = panel.get_node("Margin/Content/RankingResultLabel") as Label
	var ranking_button: Button = panel.get_node("Margin/Content/ResultRankingButton") as Button
	manager.game_over_details = {"ranking": {"rank": 1, "record": {}}}
	manager.game_over.emit()
	assert_eq(rank_label.text, "최고 기록!", "first place message")
	assert_true(rank_label.visible, "ranked result message visible")
	manager.game_over_details = {"ranking": {"rank": 4, "record": {}}}
	manager.game_over.emit()
	assert_eq(rank_label.text, "새 기록! 4위", "non-first ranked message")
	assert_true(ranking_button.size.y >= 120.0, "result ranking touch target")
	assert_eq(ranking_button.mouse_filter, Control.MOUSE_FILTER_STOP, "result ranking consumes pointer")
	ranking_button.pressed.emit()
	var ranking: RankingPanel = (main.get_node("UI") as DebugHud).ranking_panel()
	assert_true(ranking.visible, "result ranking button opens panel")
	assert_eq(ranking.current_mode(), GameConfig.GameMode.BLITZ, "result opens matching mode")
	assert_eq(ranking.highlighted_rank(), 4, "result opens latest rank highlight")
	(ranking.get_node("Panel/Content/RankingCloseButton") as Button).pressed.emit()
	assert_true(panel.visible, "close returns to result panel")
	manager.game_over_details = {"ranking": {"rank": 0, "record": {}}}
	manager.game_over.emit()
	assert_true(not rank_label.visible, "outside top ten has no new-record message")
	await _cleanup_main(main)
	Config.data.game_mode = original_mode
	_remove_save()


func _ranking_scores(rankings: Array[Dictionary]) -> Array[int]:
	var scores: Array[int] = []
	for ranking: Dictionary in rankings:
		scores.append(int(ranking["score"]))
	return scores


func _assert_ranking_columns_align(ranking: RankingPanel) -> void:
	var header_path: String = "Panel/Content/RankingHeader/Columns/"
	for column_name: String in RankingPanel.COLUMN_NAMES:
		var header: Label = ranking.get_node(header_path + column_name) as Label
		for rank: int in range(1, SaveStore.RANKING_LIMIT + 1):
			var cell: Label = ranking.get_node(
				"Panel/Content/Rows/RankingRow%d/Text/Columns/%s" % [rank, column_name]
			) as Label
			assert_near(
				cell.get_global_rect().position.x,
				header.get_global_rect().position.x,
				2.0,
				"%s column x aligns for row %d" % [column_name, rank]
			)
	var score_header: Label = ranking.get_node(header_path + "Score") as Label
	assert_eq(
		score_header.horizontal_alignment,
		HORIZONTAL_ALIGNMENT_RIGHT,
		"score header is right aligned"
	)
	for rank: int in range(1, SaveStore.RANKING_LIMIT + 1):
		var score: Label = ranking.get_node(
			"Panel/Content/Rows/RankingRow%d/Text/Columns/Score" % rank
		) as Label
		assert_eq(
			score.horizontal_alignment,
			HORIZONTAL_ALIGNMENT_RIGHT,
			"score row %d is right aligned" % rank
		)


func _assert_mode_selection_styles_match(
	start: StartScreen,
	ranking: RankingPanel
) -> void:
	var start_selected: Button = start.get_node("Content/BlitzButton") as Button
	var start_unselected: Button = start.get_node("Content/ClassicButton") as Button
	var ranking_selected: Button = ranking.get_node(
		"Panel/Content/Tabs/RankingBlitzTab"
	) as Button
	var ranking_unselected: Button = ranking.get_node(
		"Panel/Content/Tabs/RankingClassicTab"
	) as Button
	assert_true(start_selected.button_pressed, "start selected mode is pressed")
	assert_true(ranking_selected.button_pressed, "ranking selected tab is pressed")
	assert_true(not start_unselected.button_pressed, "start other mode is unselected")
	assert_true(not ranking_unselected.button_pressed, "ranking other tab is unselected")
	assert_eq(
		start_selected.get_theme_color("font_pressed_color"),
		ranking_selected.get_theme_color("font_pressed_color"),
		"selected mode text color is shared"
	)
	assert_eq(
		start_unselected.get_theme_color("font_color"),
		ranking_unselected.get_theme_color("font_color"),
		"unselected mode text color is shared"
	)
	var selected_style: StyleBoxFlat = start_selected.get_theme_stylebox(
		"pressed"
	) as StyleBoxFlat
	var ranking_selected_style: StyleBoxFlat = ranking_selected.get_theme_stylebox(
		"pressed"
	) as StyleBoxFlat
	var unselected_style: StyleBoxFlat = start_unselected.get_theme_stylebox(
		"normal"
	) as StyleBoxFlat
	var ranking_unselected_style: StyleBoxFlat = ranking_unselected.get_theme_stylebox(
		"normal"
	) as StyleBoxFlat
	assert_eq(
		selected_style.bg_color,
		ranking_selected_style.bg_color,
		"selected mode background is shared"
	)
	assert_eq(
		unselected_style.bg_color,
		ranking_unselected_style.bg_color,
		"unselected mode background is shared"
	)
	assert_true(
		selected_style.bg_color.get_luminance() > unselected_style.bg_color.get_luminance(),
		"selected background is brighter"
	)
	assert_eq(
		start_selected.get_theme_color("font_pressed_color"),
		Color(1.0, 0.85, 0.35, 1.0),
		"selected text is yellow"
	)


func _reaction(type: ReactionRules.Type, result_level: int) -> Dictionary:
	return {
		"type": type,
		"levels": [maxi(result_level - 1, 1), maxi(result_level - 1, 1)],
		"result_level": result_level,
		"occupancy": 0.0,
		"combo": 1,
	}


func _new_main(save_path: String) -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	(main.get_node("ScoreManager") as ScoreManager).save_path = save_path
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = save_path
	return main


func _create_score_manager(path: String) -> ScoreManager:
	var manager: ScoreManager = ScoreManager.new()
	manager.save_path = path
	tree.root.add_child(manager)
	await tree.process_frame
	return manager


func _cleanup_main(main: Main) -> void:
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
