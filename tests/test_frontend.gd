extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SAVE_PATH: String = "res://tests/test_frontend.tmp.cfg"


func test_start_screen_is_one_large_jelly_action() -> void:
	_remove_save()
	_write_save()
	var main: Main = _new_main(SAVE_PATH)
	tree.root.add_child(main)
	await tree.process_frame
	var start: StartScreen = main.get_node("UI/StartScreen") as StartScreen
	var jelly: Button = start.get_node("Content/JellyButton") as Button
	var best: Label = start.get_node("Content/JellyBestLabel") as Label
	assert_true(start.visible, "start screen is shown without --mode")
	assert_true(not (main.get_node("UI/Hud") as Hud).visible, "game HUD stays hidden")
	assert_true(start.get_node_or_null("Content/ClassicButton") == null, "CLASSIC card is absent")
	assert_true(start.get_node_or_null("Content/BlitzButton") == null, "legacy card is absent")
	assert_true(start.get_node_or_null("Content/SlimeButton") == null, "legacy card is absent")
	assert_eq(best.text, "BEST 4,321", "JELLY record text")
	assert_true(jelly.size.y >= 200.0, "JELLY action is 200px tall at baseline")
	assert_true(jelly.size.x >= 936.0, "JELLY action spans the old two-card width")
	assert_true(not (main.get_node("TurnManager") as TurnManager).is_physics_processing(), "game waits")
	await _cleanup_main(main)
	_remove_save()


func test_only_jelly_mode_argument_and_launch_path_are_available() -> void:
	var parser: Main = MAIN_SCENE.instantiate() as Main
	assert_eq(
		parser._mode_from_arguments(PackedStringArray(["--mode=jelly"])),
		int(GameConfig.GameMode.JELLY),
		"JELLY argument"
	)
	for removed: String in ["turn", "blitz", "slime", "unknown"]:
		assert_eq(
			parser._mode_from_arguments(PackedStringArray(["--mode=%s" % removed])),
			Main.NO_MODE,
			"removed mode argument stays unavailable"
		)
	parser.free()

	var main: Main = _new_main("")
	main.launch_immediately(GameConfig.GameMode.TURN)
	tree.root.add_child(main)
	await tree.process_frame
	assert_eq(Config.data.game_mode, GameConfig.GameMode.JELLY, "direct launch is forced to JELLY")
	assert_true(not (main.get_node("UI/StartScreen") as StartScreen).visible, "launch skips menu")
	assert_true((main.get_node("TurnManager") as TurnManager).is_physics_processing(), "JELLY manager starts")
	await _cleanup_main(main)


func test_result_returns_to_first_screen_and_legacy_save_keys_survive() -> void:
	_remove_save()
	_write_save()
	var main: Main = _new_main(SAVE_PATH)
	main.launch_immediately(GameConfig.GameMode.JELLY)
	tree.root.add_child(main)
	await tree.process_frame
	var result: GameOverPanel = main.get_node("UI/Hud/GameOverPanel") as GameOverPanel
	var first_screen: Button = result.get_node("Margin/Content/ModeSelectButton") as Button
	assert_eq(first_screen.text, "처음 화면", "result action label")
	var saved: ConfigFile = ConfigFile.new()
	assert_eq(saved.load(SAVE_PATH), OK, "save fixture reloads")
	assert_eq(saved.get_value("records", "best_score", 0), 111, "CLASSIC key remains")
	assert_eq(saved.get_value("records", "blitz_best_score", 0), 222, "legacy key remains")
	assert_eq(saved.get_value("records", "slime_best_score", 0), 333, "legacy key remains")
	await _cleanup_main(main)
	_remove_save()


func _new_main(save_path: String) -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	(main.get_node("ScoreManager") as ScoreManager).save_path = save_path
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = save_path
	return main


func _write_save() -> void:
	var save_file: ConfigFile = ConfigFile.new()
	save_file.set_value("records", "best_score", 111)
	save_file.set_value("records", "blitz_best_score", 222)
	save_file.set_value("records", "slime_best_score", 333)
	save_file.set_value("records", "jelly_best_score", 4321)
	save_file.set_value("settings", "last_mode", "turn")
	assert_eq(save_file.save(SAVE_PATH), OK, "save fixture writes")


func _cleanup_main(main: Main) -> void:
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)
	Config.data.game_mode = GameConfig.GameMode.TURN


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
