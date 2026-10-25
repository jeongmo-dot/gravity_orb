extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SAVE_PATH: String = "res://tests/test_rankings.tmp.cfg"


func test_jelly_rankings_sort_cap_and_keep_legacy_keys() -> void:
	_remove_save()
	var save_file: ConfigFile = ConfigFile.new()
	save_file.set_value("records", "best_score", 101)
	save_file.set_value("records", "blitz_best_score", 202)
	save_file.set_value("records", "slime_best_score", 303)
	assert_eq(save_file.save(SAVE_PATH), OK, "legacy fixture writes")
	for index: int in range(12):
		SaveStore.add_ranking(
			SAVE_PATH,
			GameConfig.GameMode.JELLY,
			1000 - index * 10,
			{"max_combo": index + 1, "final_moves": index % 4},
			"2026-10-%02d 12:00" % (index + 1)
		)
	var rankings: Array[Dictionary] = SaveStore.load_rankings(
		SAVE_PATH, GameConfig.GameMode.JELLY
	)
	assert_eq(rankings.size(), SaveStore.RANKING_LIMIT, "ranking is capped")
	assert_eq(int(rankings[0]["score"]), 1000, "highest score comes first")
	var persisted: ConfigFile = ConfigFile.new()
	assert_eq(persisted.load(SAVE_PATH), OK, "rankings reload")
	assert_eq(persisted.get_value("records", "best_score", 0), 101, "CLASSIC key unchanged")
	assert_eq(persisted.get_value("records", "blitz_best_score", 0), 202, "legacy key unchanged")
	assert_eq(persisted.get_value("records", "slime_best_score", 0), 303, "legacy key unchanged")
	_remove_save()


func test_ranking_panel_is_jelly_only_without_tabs() -> void:
	_remove_save()
	SaveStore.add_ranking(
		SAVE_PATH,
		GameConfig.GameMode.JELLY,
		7654,
		{"max_combo": 8, "final_moves": 3},
		"2026-10-25 10:30"
	)
	var main: Main = MAIN_SCENE.instantiate() as Main
	(main.get_node("ScoreManager") as ScoreManager).save_path = SAVE_PATH
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = SAVE_PATH
	tree.root.add_child(main)
	await tree.process_frame
	var panel: RankingPanel = main.get_node("UI/RankingPanel") as RankingPanel
	panel.bind(SAVE_PATH)
	panel.open(GameConfig.GameMode.TURN, 1)
	await tree.create_timer(0.30).timeout
	assert_eq(panel.current_mode(), GameConfig.GameMode.JELLY, "ranking always shows JELLY")
	assert_true(panel.get_node_or_null("Panel/Content/Tabs") == null, "mode tabs are absent")
	var row: Label = panel.get_node("Panel/Content/Rows/RankingRow1/Text") as Label
	var columns: HBoxContainer = row.get_node("Columns") as HBoxContainer
	assert_eq((columns.get_node("Score") as Label).text, "7,654", "score renders")
	assert_eq((columns.get_node("Stat") as Label).text, "콤보 8", "combo renders")
	assert_eq((columns.get_node("Turns") as Label).text, "3", "FINAL MOVE renders")
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.TURN
	_remove_save()


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
