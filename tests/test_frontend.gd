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
	var blitz_name: Label = start_screen.get_node("Content/BlitzNameLabel") as Label
	var classic_name: Label = start_screen.get_node("Content/ClassicNameLabel") as Label
	var blitz_description: Label = start_screen.get_node("Content/BlitzDescriptionLabel") as Label
	assert_true(start_screen.visible, "start screen is shown without --mode")
	assert_true(not hud.visible, "game HUD stays hidden on start screen")
	assert_eq(blitz_best.text, "BEST 6,789", "survival BLITZ record text")
	assert_eq(classic_best.text, "BEST 1,234", "CLASSIC record text")
	assert_eq(blitz_name.text, "BLITZ", "BLITZ name is separate from description")
	assert_eq(classic_name.text, "CLASSIC", "CLASSIC name is separate from description")
	assert_eq(blitz_description.text, "시간 버티기", "survival subtitle")
	assert_true(
		blitz_name.get_theme_color("font_color").is_equal_approx(Color("#FFB020")),
		"BLITZ name stays amber even when not selected"
	)
	assert_true(
		classic_name.get_theme_color("font_color").is_equal_approx(Color("#BFE9FF")),
		"CLASSIC name stays cyan even when not selected"
	)
	assert_true(blitz_button.button_pressed, "last BLITZ mode is highlighted")
	assert_true(not classic_button.button_pressed, "other mode is not highlighted")
	assert_true(blitz_button.size.y >= 120.0, "BLITZ touch target height")
	assert_true(classic_button.size.y >= 120.0, "CLASSIC touch target height")
	assert_true(sound_button.size.y >= 88.0, "sound touch target height")
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
	(start_screen.get_node("Content/BlitzButton") as Button).pressed.emit()
	await tree.create_timer(0.30).timeout
	start_screen.prepare_to_show()
	(start_screen.get_node("Content/ClassicButton") as Button).pressed.emit()
	await tree.create_timer(0.30).timeout
	start_screen.prepare_to_show()
	(start_screen.get_node("Content/SlimeButton") as Button).pressed.emit()
	await tree.create_timer(0.30).timeout
	assert_eq(selected_modes.size(), 3, "all three mode buttons emit")
	if selected_modes.size() == 3:
		assert_eq(selected_modes[0], GameConfig.GameMode.BLITZ, "BLITZ button mode")
		assert_eq(selected_modes[1], GameConfig.GameMode.TURN, "CLASSIC button mode")
		assert_eq(selected_modes[2], GameConfig.GameMode.SLIME, "SLIME button mode")
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


func test_mode_argument_parser_accepts_turn_blitz_slime_and_jelly() -> void:
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
		main._mode_from_arguments(PackedStringArray(["--mode=slime"])),
		int(GameConfig.GameMode.SLIME),
		"SLIME argument"
	)
	assert_eq(
		main._mode_from_arguments(PackedStringArray(["--mode=jelly"])),
		int(GameConfig.GameMode.JELLY),
		"JELLY argument"
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
	assert_eq(start_button.text, "", "start sound button uses no emoji text")
	assert_true(start_button.icon.resource_path.ends_with("speaker_on.svg"), "start vector sound icon")
	assert_eq(hud_button.text, "", "HUD sound button does not use emoji text")
	assert_true(hud_button.icon != null, "HUD sound button uses a vector icon")
	assert_true(
		hud_button.icon.resource_path.ends_with("speaker_on.svg"),
		"HUD sound icon starts on"
	)

	start_button.pressed.emit()
	assert_true(bank.is_muted(), "start button mutes bank")
	assert_true(AudioServer.is_bus_mute(bus_index), "start button mutes SFX bus")
	assert_true(start_button.icon.resource_path.ends_with("speaker_off.svg"), "start icon updates")
	assert_true(
		hud_button.icon.resource_path.ends_with("speaker_off.svg"),
		"HUD vector icon updates"
	)
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
	assert_true(
		(reloaded.get_node("UI/StartScreen/Content/StartSoundButton") as Button).icon.resource_path.ends_with(
			"speaker_off.svg"
		),
		"reloaded start icon"
	)
	assert_eq(
		(reloaded.get_node("UI/Hud/HudSoundButton") as Button).icon.resource_path,
		"res://assets/ui/speaker_off.svg",
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
	assert_eq(actions, ["retry"], "result panel accepts only the first duplicate action")
	InputRouter.restart_requested.disconnect(retry_recorder)
	result_panel.mode_select_requested.disconnect(mode_recorder)
	await _cleanup_main(main)
	Config.data.game_mode = original_mode


func test_settings_symbol_toggle_saves_and_updates_orbit_stage_immediately() -> void:
	var original_symbols: bool = Config.data.orb_symbols_enabled
	Config.data.orb_symbols_enabled = true
	_remove_save()
	_write_save(0, 0, "turn", false)
	var main: Main = _new_main(SAVE_PATH)
	tree.root.add_child(main)
	await tree.process_frame
	var settings_button: Button = main.get_node(
		"UI/StartScreen/Content/StartSettingsButton"
	) as Button
	settings_button.pressed.emit()
	await tree.create_timer(0.30).timeout
	var settings: SettingsPanel = main.get_node("UI/SettingsPanel") as SettingsPanel
	assert_true(settings.visible, "settings opens over the start screen")
	var stage: OrbitStage = main.get_node("UI/StartScreen/Content/OrbitStage") as OrbitStage
	var hero_symbol: MeshInstance3D = stage.get_node("HeroViewport/HeroSymbol") as MeshInstance3D
	assert_true(stage.uses_celestial_shader(), "orbit-stage hero uses CelestialOrbArt shader")
	assert_eq(OrbitStage.HERO_LEVEL, 5, "start hero uses the L5 Earth detail profile")
	var hero_body: MeshInstance3D = stage.get_node("HeroViewport/HeroBody") as MeshInstance3D
	var hero_material: ShaderMaterial = hero_body.material_override as ShaderMaterial
	assert_eq(
		int(hero_material.get_shader_parameter("color_id")),
		OrbTypes.OrbColor.BLUE,
		"start hero is Earth"
	)
	assert_eq(stage._orbiter_one.celestial_level(), 1, "outer orbiter is L1")
	assert_eq(stage._orbiter_one.symbol_color(), OrbTypes.OrbColor.RED, "outer orbiter is Mars")
	assert_eq(stage._orbiter_two.celestial_level(), 2, "inner orbiter is L2")
	assert_eq(stage._orbiter_two.symbol_color(), OrbTypes.OrbColor.CYAN, "inner orbiter is Mercury")
	assert_true(hero_symbol.visible, "orbit-stage hero initially shows its color symbol")
	var symbols_button: Button = settings.get_node(
		"SettingsPanelBody/Margin/Content/SettingsSymbolsToggle"
	) as Button
	symbols_button.pressed.emit()
	assert_true(not Config.data.orb_symbols_enabled, "symbol setting applies immediately")
	assert_true(not hero_symbol.visible, "orbit-stage hero updates immediately")
	var saved: ConfigFile = ConfigFile.new()
	assert_eq(saved.load(SAVE_PATH), OK, "symbol setting save reloads")
	assert_true(
		not bool(saved.get_value("settings", "orb_symbols_enabled", true)),
		"symbol setting is persisted under the one new settings key"
	)
	(settings.get_node("SettingsPanelBody/Margin/Content/SettingsCloseButton") as Button).pressed.emit()
	await tree.create_timer(0.30).timeout
	assert_true(not settings.visible, "settings slides closed")
	await _cleanup_main(main)
	Config.data.orb_symbols_enabled = original_symbols
	_remove_save()


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
