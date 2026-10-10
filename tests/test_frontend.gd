extends TestCase

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SAVE_PATH: String = "res://tests/test_frontend.tmp.cfg"


func test_start_screen_shows_records_last_mode_and_touch_targets() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	_remove_save()
	_write_save(1234, 5678, "blitz", false)
	var main: Main = _new_main(SAVE_PATH)
	tree.root.add_child(main)
	await tree.process_frame

	var start_screen: StartScreen = main.get_node("UI/StartScreen") as StartScreen
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var blitz_button: Button = start_screen.get_node("Content/BlitzButton") as Button
	var classic_button: Button = start_screen.get_node("Content/ClassicButton") as Button
	var sound_button: Button = start_screen.get_node("Content/StartSoundButton") as Button
	var blitz_best: Label = start_screen.get_node("Content/BlitzBestLabel") as Label
	var classic_best: Label = start_screen.get_node("Content/ClassicBestLabel") as Label
	assert_true(start_screen.visible, "start screen is shown without --mode")
	assert_true(not hud.visible, "game HUD stays hidden on start screen")
	assert_eq(blitz_best.text, "BEST  6789", "survival BLITZ record text")
	assert_eq(classic_best.text, "BEST  1234", "CLASSIC record text")
	assert_eq(blitz_button.text, "BLITZ\n버티기 타임어택", "survival subtitle")
	assert_true(blitz_button.button_pressed, "last BLITZ mode is highlighted")
	assert_true(not classic_button.button_pressed, "other mode is not highlighted")
	assert_true(blitz_button.size.y >= 120.0, "BLITZ touch target height")
	assert_true(classic_button.size.y >= 120.0, "CLASSIC touch target height")
	assert_true(sound_button.size.y >= 120.0, "sound touch target height")
	assert_eq(start_screen.mouse_filter, Control.MOUSE_FILTER_STOP, "start screen blocks play input")
	assert_true(not (main.get_node("TurnManager") as TurnManager).is_physics_processing(), "turn manager waits")
	assert_true(not (main.get_node("BlitzManager") as BlitzManager).is_physics_processing(), "BLITZ waits")

	await _cleanup_main(main)
	Config.data.game_mode = original_mode
	_remove_save()


func test_mode_buttons_emit_modes_and_direct_launch_skips_start_screen() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	_remove_save()
	var menu_main: Main = _new_main(SAVE_PATH)
	tree.root.add_child(menu_main)
	await tree.process_frame
	var start_screen: StartScreen = menu_main.get_node("UI/StartScreen") as StartScreen
	start_screen.mode_selected.disconnect(Callable(menu_main, "_on_mode_selected"))
	var selected_modes: Array[GameConfig.GameMode] = []
	var recorder: Callable = func(mode: GameConfig.GameMode) -> void:
		selected_modes.append(mode)
	start_screen.mode_selected.connect(recorder)
	(start_screen.get_node("Content/BlitzButton") as Button).pressed.emit()
	(start_screen.get_node("Content/ClassicButton") as Button).pressed.emit()
	assert_eq(selected_modes.size(), 2, "both mode buttons emit")
	if selected_modes.size() == 2:
		assert_eq(selected_modes[0], GameConfig.GameMode.BLITZ, "BLITZ button mode")
		assert_eq(selected_modes[1], GameConfig.GameMode.TURN, "CLASSIC button mode")
	await _cleanup_main(menu_main)

	var turn_main: Main = _new_main("")
	turn_main.launch_immediately(GameConfig.GameMode.TURN)
	tree.root.add_child(turn_main)
	await tree.process_frame
	assert_true(not (turn_main.get_node("UI/StartScreen") as StartScreen).visible, "turn launch skips menu")
	assert_true((turn_main.get_node("UI/Hud") as Hud).visible, "turn HUD is visible")
	assert_true((turn_main.get_node("TurnManager") as TurnManager).is_physics_processing(), "turn manager starts")
	await _cleanup_main(turn_main)

	var original_ready_time: float = Config.data.blitz_ready_time
	Config.data.blitz_ready_time = 1.5
	var blitz_main: Main = _new_main("")
	blitz_main.launch_immediately(GameConfig.GameMode.BLITZ)
	tree.root.add_child(blitz_main)
	await tree.process_frame
	assert_true(not (blitz_main.get_node("UI/StartScreen") as StartScreen).visible, "BLITZ launch skips menu")
	assert_eq(
		(blitz_main.get_node("BlitzManager") as BlitzManager).state,
		BlitzManager.State.READY,
		"BLITZ manager starts"
	)
	await _cleanup_main(blitz_main)
	Config.data.blitz_ready_time = original_ready_time
	Config.data.game_mode = original_mode
	_remove_save()


func test_mode_argument_parser_accepts_turn_and_blitz_only() -> void:
	var main: Main = MAIN_SCENE.instantiate() as Main
	assert_eq(
		main._mode_from_arguments(PackedStringArray(["--mode=turn"])),
		int(GameConfig.GameMode.TURN),
		"turn argument"
	)
	assert_eq(
		main._mode_from_arguments(PackedStringArray(["--mode=BLITZ"])),
		int(GameConfig.GameMode.BLITZ),
		"BLITZ argument is case insensitive"
	)
	assert_eq(
		main._mode_from_arguments(PackedStringArray(["--mode=unknown"])),
		Main.NO_MODE,
		"unknown mode keeps menu"
	)
	main.free()


func test_sound_buttons_m_key_bus_and_save_share_one_state() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	_remove_save()
	_write_save(41, 82, "turn", false)
	var main: Main = _new_main(SAVE_PATH)
	tree.root.add_child(main)
	await tree.process_frame
	var bank: SfxBank = main.get_node("FeedbackDirector/SfxBank") as SfxBank
	var start_button: Button = main.get_node("UI/StartScreen/Content/StartSoundButton") as Button
	var hud_button: Button = main.get_node("UI/Hud/HudSoundButton") as Button
	var bus_index: int = AudioServer.get_bus_index(SfxBank.SFX_BUS)
	assert_true(not bank.is_muted(), "saved unmuted state loads")
	assert_eq(start_button.text, "🔊", "start sound icon")
	assert_eq(hud_button.text, "🔊", "HUD sound icon")

	start_button.pressed.emit()
	assert_true(bank.is_muted(), "start button mutes bank")
	assert_true(AudioServer.is_bus_mute(bus_index), "start button mutes SFX bus")
	assert_eq(start_button.text, "🔇", "start icon updates")
	assert_eq(hud_button.text, "🔇", "HUD icon updates")
	InputRouter.debug_toggle_sfx_mute.emit()
	assert_true(not bank.is_muted(), "M signal unmutes bank")
	assert_true(not AudioServer.is_bus_mute(bus_index), "M signal unmutes SFX bus")
	hud_button.pressed.emit()
	assert_true(bank.is_muted(), "HUD button remutes bank")
	await _cleanup_main(main)

	var saved: ConfigFile = ConfigFile.new()
	assert_eq(saved.load(SAVE_PATH), OK, "saved settings reload")
	assert_eq(saved.get_value("records", "best_score", 0), 41, "turn record preserved")
	assert_eq(saved.get_value("records", "blitz_best_score", 0), 82, "BLITZ record preserved")
	assert_true(bool(saved.get_value("settings", "sfx_muted", false)), "muted setting saved")

	var reloaded: Main = _new_main(SAVE_PATH)
	tree.root.add_child(reloaded)
	await tree.process_frame
	var reloaded_bank: SfxBank = reloaded.get_node("FeedbackDirector/SfxBank") as SfxBank
	assert_true(reloaded_bank.is_muted(), "muted state survives scene recreation")
	assert_eq(
		(reloaded.get_node("UI/StartScreen/Content/StartSoundButton") as Button).text,
		"🔇",
		"reloaded start icon"
	)
	assert_eq(
		(reloaded.get_node("UI/Hud/HudSoundButton") as Button).text,
		"🔇",
		"reloaded HUD icon"
	)
	await _cleanup_main(reloaded)
	Config.data.game_mode = original_mode
	_remove_save()


func test_gameplay_hud_only_stops_pointer_on_sound_and_result_buttons() -> void:
	var original_mode: GameConfig.GameMode = Config.data.game_mode
	var main: Main = _new_main("")
	main.launch_immediately(GameConfig.GameMode.TURN)
	tree.root.add_child(main)
	await tree.process_frame
	var hud: Hud = main.get_node("UI/Hud") as Hud
	var sound_button: Button = hud.get_node("HudSoundButton") as Button
	var result_panel: GameOverPanel = hud.get_node("GameOverPanel") as GameOverPanel
	var retry_button: Button = result_panel.get_node("Margin/Content/RestartButton") as Button
	var mode_button: Button = result_panel.get_node("Margin/Content/ModeSelectButton") as Button
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "HUD outside buttons keeps swipes")
	assert_eq(sound_button.mouse_filter, Control.MOUSE_FILTER_STOP, "sound button consumes pointer")
	assert_eq(retry_button.mouse_filter, Control.MOUSE_FILTER_STOP, "retry consumes pointer")
	assert_eq(mode_button.mouse_filter, Control.MOUSE_FILTER_STOP, "mode select consumes pointer")
	assert_eq(retry_button.text, "다시 하기", "retry label")
	assert_eq(mode_button.text, "모드 선택", "mode select label")
	assert_true(retry_button.size.y >= 120.0, "retry touch target height")
	assert_true(mode_button.size.y >= 120.0, "mode-select touch target height")
	assert_true(
		InputRouter.restart_requested.is_connected(Callable(main, "restart")),
		"retry action is connected to same-mode restart"
	)
	assert_true(
		result_panel.mode_select_requested.is_connected(Callable(main, "_show_mode_selection")),
		"mode-select action returns to menu"
	)
	InputRouter.restart_requested.disconnect(Callable(main, "restart"))
	result_panel.mode_select_requested.disconnect(Callable(main, "_show_mode_selection"))
	var actions: Array[String] = []
	var retry_recorder: Callable = func() -> void: actions.append("retry")
	var mode_recorder: Callable = func() -> void: actions.append("mode")
	InputRouter.restart_requested.connect(retry_recorder)
	result_panel.mode_select_requested.connect(mode_recorder)
	retry_button.pressed.emit()
	mode_button.pressed.emit()
	assert_eq(actions, ["retry", "mode"], "result buttons emit separate actions")
	InputRouter.restart_requested.disconnect(retry_recorder)
	result_panel.mode_select_requested.disconnect(mode_recorder)
	await _cleanup_main(main)
	Config.data.game_mode = original_mode


func _new_main(save_path: String) -> Main:
	var main: Main = MAIN_SCENE.instantiate() as Main
	(main.get_node("ScoreManager") as ScoreManager).save_path = save_path
	(main.get_node("FeedbackDirector/SfxBank") as SfxBank).save_path = save_path
	return main


func _write_save(
	turn_best: int,
	blitz_best: int,
	last_mode: String,
	sfx_muted: bool
) -> void:
	var save_file: ConfigFile = ConfigFile.new()
	save_file.set_value("records", "best_score", turn_best)
	save_file.set_value("records", "blitz_best_score", blitz_best)
	save_file.set_value("records", "blitz_survival_best_score", 6789)
	save_file.set_value("settings", "last_mode", last_mode)
	save_file.set_value("settings", "sfx_muted", sfx_muted)
	assert_eq(save_file.save(SAVE_PATH), OK, "save fixture writes")


func _cleanup_main(main: Main) -> void:
	main.queue_free()
	await tree.process_frame
	InputRouter.set_locked(false)


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
